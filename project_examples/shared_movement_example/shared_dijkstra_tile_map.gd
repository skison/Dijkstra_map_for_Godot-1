class_name ExampleSharedDijkstraTileMap
extends TileMap
## This node is responsible for creating and maintaining DijkstraMap objects for the TileMap it
## represents, one each for pikemen and archers.
##
## Note that because there is only one DijkstraMap for each character type used for calculations, it
## isn't possible to represent multiple characters' movements to uniquely different locations
## simultaneously (i.e. you can't have one pikeman with a different target node than another).
## For a solution that can allow this behavior, consider storing duplicated DijkstraMaps (derived
## from a base DijkstraMap) on each character using the duplicate_graph_from method, so each one can
## manage its own state.

## Emitted whenever a cell on the TileMap is selected.
signal cell_selected(cell_pos: Vector2i, world_pos: Vector2)
## Emitted whenever the DijkstraMaps are recalculated with new values.
signal maps_recalculated

## List all types of tiles used in the example.
enum Tiles { GRASS, WATER, BUSHES, ROAD, HIGHLIGHT }
## Known tile positions within the TileSet atlas.
const TILE_ATLAS_COORDS = {
	Tiles.GRASS: Vector2i(0, 0),
	Tiles.WATER: Vector2i(1, 0),
	Tiles.BUSHES: Vector2i(2, 0),
	Tiles.ROAD: Vector2i(3, 0),
	Tiles.HIGHLIGHT: Vector2i(0, 1)
}
const TILE_LAYER = 0  ## This is the only TileMap layer used in this example
const TILE_SET_SOURCE_ID = 0  ## ID of the TileSetSource used in our TileSet to provide tile options
## For this example, only these tile types will be considered for pathfinding.
const WALKABLE_TILE_TYPES = [Tiles.GRASS, Tiles.BUSHES, Tiles.ROAD]
## Define weights for terrain types, so certain terrains can be passed through more or less easily.
## A value of INF means that the terrain type cannot be moved through.
## In this example, we assume all characters will share the same terrain weight restrictions, but we
## could move these out to the individual character scenes for more customizability.
@export var tile_terrain_weights := {Tiles.GRASS: 1.0, Tiles.BUSHES: 2.0, Tiles.ROAD: 0.5}

@export var dragon: CharacterBody2D  ## Dragon character; when it moves, we recalculate the map

## DijkstraMap shared across Pikemen instances for pathfinding calculations.
var dijkstra_map_for_pikemen: DijkstraMap = DijkstraMap.new()
## DijkstraMap shared across Archer instances for pathfinding calculations.
var dijkstra_map_for_archers: DijkstraMap = DijkstraMap.new()

var _position_to_id: Dictionary = {}  # Mapping of TileMap cell positions to DijkstraMap node ids
var _id_to_position: Dictionary = {}  # Reverse mapping of node ids to cell positions


## Set up the DijkstraMaps with terrain values taken from the TileMap.
func _ready() -> void:
	# For pathfinding, we must first add all points and connections to the dijkstra maps.
	# This only has to be done once, when the project loads.

	# In this example, we collect all walkable tiles from the tilemap and add a node for each one.
	# This approach is more complex than using the add_square_grid shortcut method, but gives us the
	# benefit of leaving out nodes that don't need to be there (e.g. water since our characters
	# can't swim) for a bit less overhead and simpler calculations. Plus we can more easily adjust
	# the parameters to meet our needs. See the turn based example for a shortcut implementation.
	var walkable_tiles: Array = []
	for tile_type in WALKABLE_TILE_TYPES:
		walkable_tiles += get_used_cells_by_id(
			TILE_LAYER, TILE_SET_SOURCE_ID, TILE_ATLAS_COORDS[tile_type]
		)

	# Now we insert the points
	var id: int = 0
	for pos in walkable_tiles:
		id += 1
		_id_to_position[id] = pos
		_position_to_id[pos] = id
		# We also need to specify a terrain type for the tile.
		# Terrain types can then have different weights whenever the DijkstraMap is recalculated.
		var terrain_type: int = get_tile_type_from_cell_position(pos)
		dijkstra_map_for_archers.add_point(id, terrain_type)

	# Now we need to connect the points with connections.
	# Each connection has a source point, target point, and a cost.
	var orthogonal: Array = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
	var diagonal: Array = [
		Vector2i.DOWN + Vector2i.LEFT,
		Vector2i.UP + Vector2i.LEFT,
		Vector2i.DOWN + Vector2i.RIGHT,
		Vector2i.UP + Vector2i.RIGHT
	]
	# Pair the defined directions with a cost value for each; orthogonal nodes will cost 1 unit to
	# move, whereas diagonal ones will cost sqrt(2). This is designed to be easily looped through.
	var directions_costs: Array = [[orthogonal, 1.0], [diagonal, sqrt(2.0)]]

	# Start with the position of each tile.
	for pos in walkable_tiles:
		var id_of_current_tile: int = _position_to_id[pos]

		# We loop through neighboring tiles and add connections for each one.
		# NOTE: costs are a measure of time. They are distance/speed.
		for directions_costs_pair in directions_costs:
			var directions: Array = directions_costs_pair[0]
			var cost: float = directions_costs_pair[1]

			for offset in directions:
				var pos_of_neighbour: Vector2i = pos + offset
				var id_of_neighbour: int = _position_to_id.get(pos_of_neighbour, -1)
				# We skip adding the connection if the point does not exist.
				if id_of_neighbour == -1:
					continue
				# Now we make the connection.
				# NOTE: the last parameter specifies whether to also make the reverse connection.
				# Since we loop through all points and their neighbours in both directions anyway,
				# this would be unnecessary.
				# As a possible efficiency improvement, we could choose to only check half of the
				# connections each time and add bidirectional connections for each, but this is only
				# helpful if we don't need to support unidirectional paths.
				dijkstra_map_for_archers.connect_points(
					id_of_current_tile, id_of_neighbour, cost, false
				)

	# Now we will duplicate the points and connections into dijkstra_map_for_pikemen.
	# This way we dont have to manually add them in again.
	dijkstra_map_for_pikemen.duplicate_graph_from(dijkstra_map_for_archers)

	# Now that points are added and properly connected, we can calculate the dijkstra maps.
	recalculate_dijkstra_maps()

	# Whenever the dragon moves, immediately recalculate the dijkstra maps
	dragon.moved.connect(func(): recalculate_dijkstra_maps())


## Update the DijkstraMaps based on the Dragon's current position with different behaviors for
## pikemen and archers.
func recalculate_dijkstra_maps() -> void:
	# Which node is the dragon currently on?
	var dragon_position_id: int = _position_to_id.get(local_to_map(dragon.position), 0)
	# - We want pikemen to charge the dragon's position head on.
	# - We .recalculate() the DijkstraMap.
	# - First argument is the origin (by default) or destination (i.e. the ID of the point where
	#   dragon_position_id is).
	# - Second argument is a dictionary of optional parameters. For absent entries, default values
	#   are used.
	# - We will specify the terrain weights and specify that input is the destination, not origin.
	var optional_parameters: Dictionary = {
		"terrain_weights": tile_terrain_weights, "input_is_destination": true
	}

	var res: int = dijkstra_map_for_pikemen.recalculate(dragon_position_id, optional_parameters)
	assert(res == 0)
	# Now the map has recalculated for pikemen and we can access the data.

	# - We want archers to stand at safe distance from the dragon, but within firing range.
	# - The dragon can exist anywhere, even on non-walkable tiles, so terrain doesn't matter.
	# - First we recalculate their Dijkstra map with dragon_position_id as the origin.
	# - We also do not need to calculate the entire DijkstraMap, only until we have points at the
	#   required distance
	# - This can be achieved by providing optional parameter "maximum cost".
	res = dijkstra_map_for_archers.recalculate(dragon_position_id, optional_parameters)
	assert(res == 0)
	# Now we get IDs of all points safe distance from dragon_position_id, but within firing range
	var stand_over_here: PackedInt32Array = (
		dijkstra_map_for_archers.get_all_points_with_cost_between(4.0, 5.0)
	)
	optional_parameters = {"terrain_weights": tile_terrain_weights, "input_is_destination": true}
	# And we pass those points as new destinations for the archers to walk towards
	res = dijkstra_map_for_archers.recalculate(
		stand_over_here, {"terrain_weights": tile_terrain_weights}
	)
	assert(res == 0)
	# BTW yes, Dijkstra map works for multiple destination points too; the path will simply lead
	# towards the nearest destination point.

	maps_recalculated.emit()


## If possible, get the unique atlas coordinates of a tile type within the tileset.
## Returns a negative coordinate set (-1, -1) if not found.
func get_tileset_atlas_pos(tile_type: int) -> Vector2i:
	return TILE_ATLAS_COORDS.get(tile_type, Vector2i(-1, -1))


## If possible, get the tile type given a cell position within the tilemap.
## Returns -1 if the type isn't found.
func get_tile_type_from_cell_position(cell_pos: Vector2i) -> int:
	var tile_type = TILE_ATLAS_COORDS.find_key(get_cell_atlas_coords(TILE_LAYER, cell_pos))
	# Explicit null check to include 0 case
	return tile_type if tile_type != null else -1


## If possible, get the tile type given a world position that may be within the tilemap's bounds.
## Returns -1 if the type isn't found.
func get_tile_type_from_world_position(world_pos: Vector2) -> int:
	return get_tile_type_from_cell_position(local_to_map(world_pos))


## Given a world position, calculate a speed multiplier based on the terrain weight for the tile at
## that pos.
func get_speed_modifier(world_pos: Vector2) -> float:
	return 1.0 / tile_terrain_weights.get(get_tile_type_from_world_position(world_pos), 0.5)


## Given the position of a pikeman, find an immediate destination for it to try to move to.
## Returns null if there is no valid target position.
func get_target_for_pikeman(pos: Vector2):
	var map_coords: Vector2i = local_to_map(pos)

	# We look up in the Dijkstra map where the pikeman should go next
	var target_id: int = dijkstra_map_for_pikemen.get_direction_at_point(
		_position_to_id.get(map_coords, 0)
	)
	# If dragon_position_id is inaccessible from current position, then Dijkstra map
	# spits out -1, and we don't move.
	if target_id == -1:
		return null
	var target_coords: Vector2 = _id_to_position[target_id]
	return map_to_local(target_coords)


## Given the position of an archer, find an immediate destination for it to try to move to.
## Returns null if there is no valid target position.
func get_target_for_archer(pos: Vector2):
	var map_coords: Vector2i = local_to_map(pos)

	# We look up in the Dijkstra map where the archer should go next
	var target_id: int = dijkstra_map_for_archers.get_direction_at_point(
		_position_to_id.get(map_coords, 0)
	)
	# If dragon_position_id is inaccessible from current position, then Dijkstra map
	# spits out -1, and we don't move.
	if target_id == -1:
		return null
	var target_coords: Vector2 = _id_to_position[target_id]
	return map_to_local(target_coords)


## Announce clicked cell positions within the tilemap.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed == false:
		var local_pos: Vector2 = get_local_mouse_position()
		var cell_pos: Vector2i = local_to_map(local_pos)
		cell_selected.emit(cell_pos, local_pos)
