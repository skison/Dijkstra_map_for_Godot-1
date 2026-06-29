class_name ExampleDijkstraTileMap
extends Node2D
## This node is responsible for creating and maintaining a base DijkstraMap object for the TileMap
## it represents.
##
## Note that because there is only a single DijkstraMap used for calculations, it isn't possible to
## represent multiple characters' movements to uniquely different locations simultaneously, so there
## may be unintended side effects if multiple characters (e.g. knights) are present.
## For a solution that works for multiple characters, consider storing duplicated DijkstraMaps
## (derived from the base DijkstraMap) on each character using the duplicate_graph_from method, so
## each one can manage its own state.
## This behavior may be improved by the proposed "remote" DijkstraMap feature that would split up
## the responsibilities of hosting the graph and calculating costs/directions for a user of the
## graph, see: https://github.com/MatejSloboda/Dijkstra_map_for_Godot/issues/98 for details.

## Emitted whenever a cell on the TileMap is selected.
signal cell_selected(cell_pos: Vector2i, main_tile_type: int, is_in_highlight_area: bool)

## List all types of tiles used in the example.
enum Tiles { GRASS, WATER, BUSHES, ROAD, HIGHLIGHT }
## Known tile positions within the TileSet atlas.
const TILE_ATLAS_COORDS: Dictionary[Tiles, Vector2i] = {
	Tiles.GRASS: Vector2i(0, 0),
	Tiles.WATER: Vector2i(1, 0),
	Tiles.BUSHES: Vector2i(2, 0),
	Tiles.ROAD: Vector2i(3, 0),
	Tiles.HIGHLIGHT: Vector2i(0, 1),
}
const TILE_SET_SOURCE_ID = 0 ## ID of the TileSetSource used in a TileSet to provide tile options.

## Store a base DijkstraMap object for pathfinding calculations.
var dijkstra_map := DijkstraMap.new()
var _position_to_id: Dictionary[Vector2i, int] = { } # Maps cell positions to DijkstraMap node ids
var _id_to_position: Dictionary[int, Vector2i] = { } # Reverse mapping of node ids to cell positions

@onready var main_tile_layer: TileMapLayer = %MainTileLayer
@onready var highlight_tile_layer: TileMapLayer = %HighlightTileLayer


## set up the DijkstraMap with terrain values taken from the TileMap.
func _ready() -> void:
	# We need to initialize the dijkstra map with appropriate graph for pathfinding; we will use the
	# "add_square_grid()" method to do this. This acts as a shortcut to create an entire grid node
	# graph covering the tilemap's row/column dimensions, providing a node for every cell, including
	# cells that might not be utilized in pathfinding (e.g. water for characters that cannot swim).
	var rect: Rect2 = main_tile_layer.get_used_rect()
	# - First argument is the dimensions on the map.
	# - Second argument is terrain_id. We can ignore that one, since we will specify terrain later.
	# - Last two arguments are costs for orthogonal/diagonal movement.
	# - The method will return a dictionary of positions to IDs.
	_position_to_id.assign(dijkstra_map.add_square_grid(rect, -1, 1.0, 1.4))

	# Now we will iterate through the positions and change the terrains to the appropriate values.
	for pos in _position_to_id:
		var id := _position_to_id[pos]
		# We will simply use the IDs of the tiles in the tileset.
		var terrain_id := get_tile_type_from_cell_position(pos)
		# DijkstraMap only references points by their ID, it is oblivious to their actual positions.
		dijkstra_map.set_terrain_for_point(id, terrain_id)
		# We also make a _id_to_position dictionary for convenience.
		_id_to_position[id] = pos


## Announce clicked cell positions within the tilemap.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed == false:
		var pos := main_tile_layer.local_to_map(get_local_mouse_position())
		var main_tile_type := get_tile_type_from_cell_position(pos)
		# Check if clicked point is within the highlighted area.
		var is_in_highlight_area := (
				highlight_tile_layer.get_cell_atlas_coords(pos)
				== TILE_ATLAS_COORDS[Tiles.HIGHLIGHT]
		)
		cell_selected.emit(pos, main_tile_type, is_in_highlight_area)


## If possible, get the unique atlas coordinates of a tile type within the tileset.
## Returns a negative coordinate set (-1, -1) if not found.
func get_tileset_atlas_pos(tile_type: int) -> Vector2i:
	return TILE_ATLAS_COORDS.get(tile_type, Vector2i(-1, -1))


## If possible, get the tile type given a cell position within the tilemap.
## Returns -1 if the type isn't found.
func get_tile_type_from_cell_position(cell_pos: Vector2i) -> int:
	var tile_type: Variant = TILE_ATLAS_COORDS.find_key(
		main_tile_layer.get_cell_atlas_coords(cell_pos),
	)
	# Explicit null check to include 0 case.
	return tile_type if tile_type != null else -1


## If possible, get the tile type given a world position that may be within the tilemap's bounds.
## Returns -1 if the type isn't found.
func get_tile_type_from_world_position(world_pos: Vector2) -> int:
	return get_tile_type_from_cell_position(main_tile_layer.local_to_map(world_pos))


## Calculate & save the moveable area within the tilemap given a position, maximum movement cost,
## and a mapping of terrain weights. Note that this will overwrite the previous DijsktraMap costs!
## Optionally highlight the moveable area afterward.
func calculate_moveable_area(
		world_pos: Vector2,
		max_cost: float,
		terrain_weights: Dictionary,
		highlight_area := false,
) -> void:
	# Here we recalculate the DijkstraMap to reflect the movement capacity derived from the given
	# parameters; the location to move from, and the weight of each terrain type to consider.
	var pos := main_tile_layer.local_to_map(world_pos)
	var id := _position_to_id[pos]
	dijkstra_map.recalculate(id, { "terrain_weights": terrain_weights })

	# Get all tiles with cost below "max_cost".
	var point_ids := dijkstra_map.get_all_points_with_cost_between(0.0, max_cost)

	# Now we highlight these cells in the tilemap's highlight layer if desired.
	if highlight_area:
		var cell_positions := PackedVector2Array()
		for point_id in point_ids:
			cell_positions.append(_id_to_position[point_id])
		highlight_cell_area(cell_positions)


## Get the shortest path from the DijkstraMap, and translate it into world positions.
## NOTE: the path is already pre-calculated. This method only fetches the result.
func calculate_path_to_cell(cell_pos: Vector2i) -> PackedVector2Array:
	# All of the actual pathfinding logic should have been performed earlier within the
	# calculate_moveable_area function.
	# NOTE: we cast to Vector2 type since DijsktraMap works with float coordinates.
	var path_ids := dijkstra_map.get_shortest_path_from_point(
		_position_to_id[cell_pos],
	)

	var new_path := PackedVector2Array()
	# NOTE: the selected target point is not included in DijkstraMap's calculated path by default,
	# so we add it in here.
	new_path.push_back(main_tile_layer.map_to_local(cell_pos))
	for id in path_ids:
		new_path.push_back(main_tile_layer.map_to_local(_id_to_position[id]))

	return new_path


## Pass in a defined list of cells to highlight - this will automatically clear the previous area.
func highlight_cell_area(cell_positions: PackedVector2Array) -> void:
	highlight_tile_layer.clear()
	for cell_pos in cell_positions:
		highlight_tile_layer.set_cell(
			cell_pos,
			TILE_SET_SOURCE_ID,
			get_tileset_atlas_pos(Tiles.HIGHLIGHT),
		)
