extends TileMap
## GDScript implementation of the DijkstraMap visualization example.
## In this visualization, you can select different tile types to draw with, each representing a
## different DijkstraMap terrain; just click/drag your mouse over the tilemap to activate it. This
## includes examples of different terrain costs, a terrain type with infinite cost (essentially non-
## navigable, e.g. walls), and an origin point which can represent the target goal for pathfinding.

## The TileMap utilizes three layers: one for base tiles, one for a cost map (using gradient tiles),
## and one for a direction map (using arrow tiles).
enum Layers { MAIN, COSTS, DIRECTIONS }
## We use 2 separate atlases for the TileSet used in this TileMap. The first contains all the base
## tiles + arrow tiles, the second contains all gradient number tiles.
enum TileAtlases { MAIN, GRADIENT }
## List all base tiles that can be placed down in the order they appear in the atlas.
enum MainTiles { SMOOTH_TERRAIN, ROUGH_TERRAIN, WALL, ORIGIN }
## List each arrow tile (direction) in the order they appear in the atlas.
enum ArrowTiles { RIGHT, UP_RIGHT, DOWN, DOWN_RIGHT, LEFT, DOWN_LEFT, UP, UP_LEFT }
## Terrain weights for the different main tile types.
const TERRAIN_WEIGHTS = {
	MainTiles.SMOOTH_TERRAIN: 1.0,
	MainTiles.ROUGH_TERRAIN: 4.0,
	MainTiles.WALL: INF,
	MainTiles.ORIGIN: 1.0
}
## Map Vector2i directions (TileMap neighbor offsets) to their arrow tile representations.
const ARROW_DIRECTIONS = {
	Vector2i(1, 0): ArrowTiles.RIGHT,
	Vector2i(1, -1): ArrowTiles.UP_RIGHT,
	Vector2i(0, 1): ArrowTiles.DOWN,
	Vector2i(1, 1): ArrowTiles.DOWN_RIGHT,
	Vector2i(-1, 0): ArrowTiles.LEFT,
	Vector2i(-1, 1): ArrowTiles.DOWN_LEFT,
	Vector2i(0, -1): ArrowTiles.UP,
	Vector2i(-1, -1): ArrowTiles.UP_LEFT
}
## We only have so many gradient tiles to represent a cost value, so we define the index limit here.
const MAX_VISUAL_COST = 31

## Defines the bounds of the TileMap - in this example, we assume there is no offset and that all
## tiles are at non-negative positions.
const TILEMAP_RECT: Rect2 = Rect2(0, 0, 23, 19)

var dijkstramap: DijkstraMap = DijkstraMap.new()  ## DijkstraMap object to be visualized
var id_to_pos: Dictionary = {}  ## Mapping of Dijkstra node ids to TileMap cell coordinates
var pos_to_id: Dictionary = {}  ## Reverse mapping of TileMap cell coordinates to Dijkstra node ids
var tile_to_draw: int = 0  ## Index of the main tile type to draw (terrain)
var dragging: bool = false  ## True when the user's mouse is clicking & dragging


## On startup, make sure there is an input mapped for mouse clicks, and set up the DijkstraMap.
func _ready() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.has_action("left_mouse_button"):
		InputMap.add_action("left_mouse_button")
	InputMap.action_add_event("left_mouse_button", event)

	# TODO: remove optional params once Rust API allows it
	pos_to_id = dijkstramap.add_square_grid(TILEMAP_RECT, -1, 1.0, INF)
	for pos in pos_to_id:
		id_to_pos[pos_to_id[pos]] = pos
	update_terrain_ids()
	recalculate()


## Recalculate the DijsktraMap, calculating the costs/directions for each point in the map, and
## update the TileMap representation.
func recalculate() -> void:
	# Find all origin positions to calculate from
	var targets: Array = get_used_cells_by_id(
		Layers.MAIN, TileAtlases.MAIN, get_main_tileset_atlas_pos(MainTiles.ORIGIN)
	)
	var target_ids: Array = []
	for pos: Vector2 in targets:
		target_ids.push_back(pos_to_id[pos])
	dijkstramap.recalculate(target_ids, {"terrain_weights": TERRAIN_WEIGHTS})

	# Visualize costs map
	var costs: Dictionary = dijkstramap.get_cost_map()
	clear_layer(Layers.COSTS)

	for id in costs.keys():
		# Get the cost value at this location, and limit to the visible range available.
		var cost: int = clamp(int(costs[id]), 0, MAX_VISUAL_COST)
		set_cell(
			Layers.COSTS,
			id_to_pos[id],
			TileAtlases.GRADIENT,
			get_tileset_atlas_pos_for_cost_value(cost)
		)

	# Visualize directions map
	var dir_ids: Dictionary = dijkstramap.get_direction_map()
	clear_layer(Layers.DIRECTIONS)

	for id in dir_ids.keys():
		var pos: Vector2i = Vector2i(id_to_pos[id])
		var dir: Vector2i = Vector2i(id_to_pos.get(dir_ids[id], Vector2i(NAN, NAN))) - pos
		set_cell(
			Layers.DIRECTIONS,
			id_to_pos[id],
			TileAtlases.MAIN,
			get_arrow_tile_atlas_pos_for_direction(dir)
		)


## Ensure the DijkstraMap has the correct terrain type set at each node.
func update_terrain_ids() -> void:
	for id in id_to_pos.keys():
		var pos: Vector2 = id_to_pos[id]
		dijkstramap.set_terrain_for_point(id, get_tile_type_from_cell_position(pos))


## Get the expected tile coordinates of a main tile type within its atlas.
func get_main_tileset_atlas_pos(main_tile_type: int) -> Vector2i:
	return Vector2i(main_tile_type, 0)


## Get the main tile type from a cell position in the tilemap.
func get_tile_type_from_cell_position(cell_pos: Vector2i) -> int:
	return get_cell_atlas_coords(Layers.MAIN, cell_pos).x


## Convert a cost value into atlas coordinates within the gradient tileset.
func get_tileset_atlas_pos_for_cost_value(cost: int) -> Vector2i:
	return Vector2i(clamp(cost, 0, MAX_VISUAL_COST), 0)


## Convert a TileMap direction offset to an arrow tile index.
func get_arrow_tile_type_for_direction(dir: Vector2i) -> int:
	return ARROW_DIRECTIONS.get(dir, 0)


## Convert an arrow tile index into an atlas coordinate.
func get_arrow_tile_atlas_pos_for_type(arrow_tile_type: int) -> Vector2i:
	return Vector2i(arrow_tile_type, 1)


## Convert a TileMap direction offset to an arrow tile atlas coordinate.
func get_arrow_tile_atlas_pos_for_direction(dir: Vector2i) -> Vector2i:
	return get_arrow_tile_atlas_pos_for_type(get_arrow_tile_type_for_direction(dir))


## Listen for updates from the UI to select which tile to draw with.
func on_terrain_selection_item_selected(index: int) -> void:
	tile_to_draw = index


## Optionally show an overlay over the main layer.
func on_visualization_selection_item_selected(index: int) -> void:
	for layer in [Layers.COSTS, Layers.DIRECTIONS]:
		set_layer_enabled(layer, index == layer)


## Let the user draw new tiles onto the board, automatically recalculating the DijkstraMap.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse_button"):
		dragging = true
	if event.is_action_released("left_mouse_button"):
		dragging = false

	if (event is InputEventMouseMotion or event is InputEventMouseButton) and dragging:
		var pos: Vector2 = get_local_mouse_position()
		var cell: Vector2 = local_to_map(pos)
		if (
			cell.x >= 0
			and cell.x < TILEMAP_RECT.size.x
			and cell.y >= 0
			and cell.y < TILEMAP_RECT.size.y
		):
			set_cell(Layers.MAIN, cell, TileAtlases.MAIN, get_main_tileset_atlas_pos(tile_to_draw))
			dijkstramap.set_terrain_for_point(pos_to_id[cell], tile_to_draw)
			recalculate()
