extends Node
## This sample demonstrates the application of both DijkstraMap and the built-in AStar classes
## (specifically AStar2D and AStarGrid2D) to solve a common problem: pathfinding through a maze.
## The calculations of both implementations are timed, so you can see how the performance of each
## varies if this is of concern to you (most use cases can use either approach without worry).
## Please note that DijkstraMap and AStar do not offer the same set of features, so be sure to take
## this into account if deciding whether to use one or the other for a more complex project.
##
## Note about "Grid Methods" and performance impacts: both DijkstraMap and AStar have shortcut
## implementations for setting up a uniform grid of nodes for pathfinding, but they are used very
## differently:
## - DijkstraMap allows for pathfinding with different terrain weights per node, so in this example,
##   we keep every wall node intact but set their weight to INF, so that pathfinding will only
##   consider the path nodes. You could change the weight of wall nodes to a lower value to allow
##   pathfinding to go through them when it would be faster. This flexibility may lead to worse
##   performance than the normal method.
## - AStarGrid2D requires disabling each point that is not used for pathfinding, so we do that in
##   this example (there is no concept of terrain weights here). As a result, it is far less
##   flexible than DijkstraMap, but may lead to greater performance especially over the AStar2D
##   counterpart.
## The implementation of the grid methods here are not tuned for maximum performance - if you want a
## more performant DijkstraMap grid method solution, you should instead use the remove_point or
## disable_point method for each wall node on the grid so they won't be checked during pathfinding,
## but this may not be any faster overall than the regular non-grid setup. You could also consider
## rewriting this GDScript code in C# or C++ for better performance.

## List all types of tiles used in the example.
enum Tiles { GROUND, WALL, PATH, START, END }
## The TileMap utilizes three layers: one for wall & ground tiles, one for start & end points, and
## one for path tiles between points.
enum Layers { MAIN, PATH, POINTS }
## Known tile positions within the TileSet atlas.
const TILE_ATLAS_COORDS = {
	Tiles.GROUND: Vector2i(0, 0),
	Tiles.WALL: Vector2i(1, 0),
	Tiles.PATH: Vector2i(2, 0),
	Tiles.START: Vector2i(3, 0),
	Tiles.END: Vector2i(4, 0),
}
const TILE_SET_SOURCE_ID = 0  ## ID of the TileSetSource used in our TileSet to provide tile options
## Maze node dimensions are not exactly the same as the tilemap cell dimensions; for the purposes of
## generating a maze with square tiles, we need to have buffer tiles around each maze node so that
## we can then break away walls to create connections to neighbor nodes. So the tilemap's dimensions
## will always be this value multiplied by 2, plus 1.

var maze_dimensions := Vector2i(9, 9)
var maze_nodes: Array[Array] = []  ## 2D array initialized to false values, set to true once visited
var start_point := Vector2i(NAN, NAN)  ## Point to pathfind from
var end_points: Array[Vector2i]  ## Point or points to pathfind to

## Store references to the tilemap and certain UI inputs and labels.
@onready var tilemap: TileMap = $TileMap
@onready var seed_input: SpinBox = %SeedInput
@onready var width_input: SpinBox = %WidthInput
@onready var height_input: SpinBox = %HeightInput
@onready var start_pos_coords_label: Label = %StartPosCoordsLabel
@onready var end_pos_list_label: Label = %EndPosListLabel
@onready var use_grid_methods_button: CheckButton = %UseGridMethodsButton
@onready var dijkstra_graph_setup_time_label: Label = %DijkstraGraphSetupTimeLabel
@onready var a_star_graph_setup_time_label: Label = %AStarGraphSetupTimeLabel
@onready var dijkstra_solve_step_time_label: Label = %DijkstraSolveStepTimeLabel
@onready var a_star_solve_step_time_label: Label = %AStarSolveStepTimeLabel
@onready var dijkstra_total_time_label: Label = %DijkstraTotalTimeLabel
@onready var a_star_total_time_label: Label = %AStarTotalTimeLabel

@onready var initial_dimensions := maze_dimensions  ## Save this so we can scale the map size later


## On ready, generate an initial maze to use.
func _ready():
	width_input.value = maze_dimensions.x
	height_input.value = maze_dimensions.y
	generate_maze()


## React to click events to try to select points on the tilemap.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse_button"):
		var pos: Vector2 = tilemap.get_local_mouse_position()
		var cell: Vector2 = tilemap.local_to_map(pos)
		_tilemap_cell_selected(cell)


## Use a maze generation algorithm to create a new maze of a given size.
## Reference: https://www.algosome.com/articles/maze-generation-depth-first.html
func generate_maze():
	seed(int(seed_input.value))  # Update randomization with the specified seed
	# Reset TileMap and related maze vars to a blank state, and update UI
	tilemap.clear()
	start_point = Vector2i(NAN, NAN)
	end_points = []
	_updated_map_points()
	# Set maze to an empty rectangle of the needed size
	maze_dimensions = Vector2i(int(width_input.value), int(height_input.value))
	var tilemap_dimensions := maze_dimensions * 2 + Vector2i.ONE
	for i in tilemap_dimensions.x:
		for j in tilemap_dimensions.y:
			tilemap.set_cell(
				Layers.MAIN, Vector2i(i, j), TILE_SET_SOURCE_ID, TILE_ATLAS_COORDS[Tiles.WALL]
			)

	# Scale visually to fit new maze size comfortably on the screen
	var new_scale := Vector2(initial_dimensions) / Vector2(maze_dimensions)
	new_scale = Vector2(min(new_scale.x, new_scale.y), min(new_scale.x, new_scale.y))
	tilemap.scale = new_scale

	# Set up initial state of unvisited maze nodes and carve out a tile for each one on the tilemap
	maze_nodes.resize(maze_dimensions.x)
	for i in maze_nodes.size():
		var maze_nodes_inner: Array[bool] = []
		maze_nodes_inner.resize(maze_dimensions.y)
		maze_nodes_inner.fill(false)
		maze_nodes[i] = maze_nodes_inner

		for j in maze_nodes_inner.size():
			tilemap.set_cell(
				Layers.MAIN,
				Vector2i((i * 2) + 1, (j * 2) + 1),  # Adjust maze node pos to tilemap cell pos
				TILE_SET_SOURCE_ID,
				TILE_ATLAS_COORDS[Tiles.GROUND]
			)

	# Start maze generation algorithm by determining a random node to start with + an empty queue
	var current_node := Vector2i(
		randi_range(0, maze_dimensions.x - 1), randi_range(0, maze_dimensions.y - 1)
	)
	var node_queue: Array[Vector2i] = []
	var maze_gen_complete := false
	# Loop until whole maze is generated
	while !maze_gen_complete:
		node_queue.push_back(current_node)
		maze_nodes[current_node.x][current_node.y] = true
		# Check for any unvisited neihbores
		var unvisited_neighbor_offsets := _get_unvisited_neighbor_offsets(current_node)
		# If there are neighbors to visit, pick one at random, connect to it, and check that node
		if unvisited_neighbor_offsets.size() > 0:
			var neighbor_offset := unvisited_neighbor_offsets[randi_range(
				0, unvisited_neighbor_offsets.size() - 1
			)]
			var neighbor_node := current_node + neighbor_offset
			# Open the wall between both nodes, adjusting for tilemap position
			tilemap.set_cell(
				Layers.MAIN,
				Vector2i((current_node.x * 2) + 1, (current_node.y * 2) + 1) + neighbor_offset,
				TILE_SET_SOURCE_ID,
				TILE_ATLAS_COORDS[Tiles.GROUND]
			)

			current_node = neighbor_node
		# There are no neighbors to visit, so pop a node off the queue until one of those can be
		# visited, or until all nodes have been checked.
		else:
			while node_queue.size() > 0:
				var new_test_node: Vector2i = node_queue.pop_front()
				unvisited_neighbor_offsets = _get_unvisited_neighbor_offsets(new_test_node)
				if unvisited_neighbor_offsets.size() > 0:
					current_node = new_test_node
					break

			if node_queue.size() == 0:  # No more nodes on the queue to check, so the maze is ready
				maze_gen_complete = true


## Used during maze generation to retrieve a list of neighbor positions that have not been visited
## yet.
func _get_unvisited_neighbor_offsets(origin_node_pos: Vector2i) -> Array[Vector2i]:
	var unvisited_neighbor_offsets: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var new_pos := origin_node_pos + offset
		if (
			new_pos.x < 0
			|| new_pos.x >= maze_dimensions.x
			|| new_pos.y < 0
			|| new_pos.y >= maze_dimensions.y
		):
			continue
		# Check the bool 2D array representing maze nodes to see which neighbors have been visited
		if !maze_nodes[new_pos.x][new_pos.y]:
			unvisited_neighbor_offsets.push_back(offset)

	return unvisited_neighbor_offsets


## When a valid tilemap cell is selected, attempt to update the start/end positions accordingly.
## 1. If this cell is empty and there is no start point, make it the start point
## 2. If this cell is empty and there is a start point already, make it an end point
## 3. If this cell is a start or end point, remove it
func _tilemap_cell_selected(cell: Vector2i) -> void:
	if tilemap.get_cell_atlas_coords(Layers.MAIN, cell) != TILE_ATLAS_COORDS[Tiles.GROUND]:
		return  # Not a valid cell

	var existing_cell_atlas_coords := tilemap.get_cell_atlas_coords(Layers.POINTS, cell)
	if existing_cell_atlas_coords == Vector2i(-1, -1):  # Empty cell
		if start_point == Vector2i(NAN, NAN):
			start_point = cell
			tilemap.set_cell(
				Layers.POINTS, cell, TILE_SET_SOURCE_ID, TILE_ATLAS_COORDS[Tiles.START]
			)
		else:
			end_points.push_back(cell)
			tilemap.set_cell(Layers.POINTS, cell, TILE_SET_SOURCE_ID, TILE_ATLAS_COORDS[Tiles.END])
	else:  # Start or end point is already here
		if existing_cell_atlas_coords == TILE_ATLAS_COORDS[Tiles.START]:
			start_point = Vector2i(NAN, NAN)
		else:
			end_points.erase(cell)
		tilemap.erase_cell(Layers.POINTS, cell)

	_updated_map_points()


## Whenever the start or end points are updated, update the UI labels to match.
func _updated_map_points() -> void:
	start_pos_coords_label.text = "%s" % start_point if start_point else "-"
	if end_points.size() == 0:
		end_pos_list_label.text = "-"
	else:
		end_pos_list_label.text = "\n".join(end_points)


## Solve the maze with both AStar and DijkstraMap, from scratch.
func solve_maze() -> void:
	tilemap.clear_layer(Layers.PATH)

	if start_point == Vector2i(NAN, NAN) || end_points.is_empty():
		return

	_solve_maze_for_dijkstra()
	_solve_maze_for_astar()


## Use DijkstraMap to solve the maze (either the normal method of solving or the grid shortcut
## method)
func _solve_maze_for_dijkstra() -> void:
	var tilemap_dimensions := maze_dimensions * 2 + Vector2i.ONE
	var use_grid_methods = use_grid_methods_button.button_pressed

	var dijkstra_init_time_marker := Time.get_ticks_msec()

	# Dijkstra Step 1: set up the DijkstraMap (graph)

	var dijkstra_map = DijkstraMap.new()
	var dijkstra_start_point: int
	var dijkstra_end_points := PackedInt32Array()

	# If using the grid shortcut method, we must store the points in a dictionary so we know how
	# they map to cell positions.
	var dijkstra_grid_points_to_ids := {}
	var dijkstra_grid_ids_to_points := {}

	# Set up & solve DijkstraMap using the grid shortcut method
	if use_grid_methods:
		dijkstra_grid_points_to_ids = dijkstra_map.add_square_grid(
			Rect2(0, 0, tilemap_dimensions.x, tilemap_dimensions.y), -1, 1.0, INF
		)
		# Update terrains for walls and ground tiles so pathfinding will be accurate
		for pos in dijkstra_grid_points_to_ids.keys():
			var id: int = dijkstra_grid_points_to_ids[pos]
			var terrain_id: int = get_tile_type_from_cell_position(pos)
			dijkstra_map.set_terrain_for_point(id, terrain_id)
			# Set reverse mapping for convenience.
			dijkstra_grid_ids_to_points[id] = pos
		# Get start & end points
		dijkstra_start_point = dijkstra_grid_points_to_ids[Vector2(start_point)]
		for end_point in end_points:
			dijkstra_end_points.push_back(dijkstra_grid_points_to_ids[Vector2(end_point)])
		# Run pathfinding
		(
			dijkstra_map
			. recalculate(
				dijkstra_start_point,
				{
					"input_is_destination": false,
					"terrain_weights":
					{
						Tiles.GROUND: 1.0,
						Tiles.WALL: INF,
					}
				}
			)
		)

	# Set up & solve DijkstraMap using the normal method
	else:
		# Iterate through entire map, adding points for each normal tile, and making connections to
		# adjacent normal ones.
		# We iterate through columns then rows, from left -> right, top -> bottom. For each tile, we
		# check the top and left neighbors, then create bidirectional connections if valid.
		for i in tilemap_dimensions.x - 1:
			for j in tilemap_dimensions.y - 1:
				var tilemap_coords := Vector2i(i, j)
				var tile_atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(
					Layers.MAIN, tilemap_coords
				)
				var tile_type: int = TILE_ATLAS_COORDS.find_key(tile_atlas_coords)

				if tile_type == Tiles.GROUND:
					var dijkstra_id := tilemap_coords_to_dijkstra_id(
						tilemap_coords, tilemap_dimensions.x
					)
					dijkstra_map.add_point(dijkstra_id, tile_type)

					# Check top and left neighbors and create connections if possible
					var top_and_left_neighbor_coords := [
						tilemap_coords - Vector2i(1, 0), tilemap_coords - Vector2i(0, 1)
					]
					for neighbor_coords: Vector2i in top_and_left_neighbor_coords:
						var neighbor_id := tilemap_coords_to_dijkstra_id(
							neighbor_coords, tilemap_dimensions.x
						)
						if dijkstra_map.has_point(neighbor_id):
							dijkstra_map.connect_points(dijkstra_id, neighbor_id, 1.0, true)
		# Get start & end points
		dijkstra_start_point = tilemap_coords_to_dijkstra_id(start_point, tilemap_dimensions.x)
		for end_point in end_points:
			dijkstra_end_points.push_back(
				tilemap_coords_to_dijkstra_id(end_point, tilemap_dimensions.x)
			)
		# Run pathfinding
		(
			dijkstra_map
			. recalculate(
				dijkstra_start_point,
				{
					"input_is_destination": false,
					"terrain_weights":
					{
						Tiles.GROUND: 1.0,
					}
				}
			)
		)

	var dijkstra_setup_time_marker := Time.get_ticks_msec()

	# Dijkstra Step 2: Solve for each path

	var solved_paths: Array[PackedInt32Array] = []
	for dijkstra_end_point in dijkstra_end_points:
		solved_paths.push_back(dijkstra_map.get_shortest_path_from_point(dijkstra_end_point))

	var dijkstra_solve_time_marker := Time.get_ticks_msec()

	# Bonus non-timed step: color in the paths visually by updating the tilemap
	for solved_path in solved_paths:
		for dijkstra_id in solved_path:
			var cell_pos: Vector2i
			if use_grid_methods:
				cell_pos = Vector2i(dijkstra_grid_ids_to_points[dijkstra_id])
			else:
				cell_pos = dijkstra_id_to_tilemap_coords(dijkstra_id, tilemap_dimensions.x)
			tilemap.set_cell(
				Layers.PATH, cell_pos, TILE_SET_SOURCE_ID, TILE_ATLAS_COORDS[Tiles.PATH]
			)

	var dijkstra_setup_time := dijkstra_setup_time_marker - dijkstra_init_time_marker
	var dijkstra_solve_time := dijkstra_solve_time_marker - dijkstra_setup_time_marker
	var dijkstra_total_time := dijkstra_setup_time + dijkstra_solve_time

	dijkstra_graph_setup_time_label.text = "%dms" % dijkstra_setup_time
	dijkstra_solve_step_time_label.text = "%dms" % dijkstra_solve_time
	dijkstra_total_time_label.text = "%dms" % dijkstra_total_time


## Use AStar to solve the maze (either the normal AStar2D class or the AStarGrid2D shortcut class)
func _solve_maze_for_astar() -> void:
	var tilemap_dimensions := maze_dimensions * 2 + Vector2i.ONE
	var use_grid_methods = use_grid_methods_button.button_pressed

	var astar_init_time_marker := Time.get_ticks_msec()
	var astar_setup_time_marker: int
	var astar_solve_time_marker: int

	# Use the AStarGrid2D implementation
	if use_grid_methods:
		# AStar Step 1: set up the AStarGrid2D (graph)
		var astar_grid = AStarGrid2D.new()
		astar_grid.region = Rect2i(0, 0, tilemap_dimensions.x, tilemap_dimensions.y)
		astar_grid.cell_size = tilemap.tile_set.tile_size
		astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar_grid.update()

		# Update all solid points on the grid (walls)
		for i in tilemap_dimensions.x:
			for j in tilemap_dimensions.y:
				var tilemap_coords := Vector2i(i, j)
				var tile_atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(
					Layers.MAIN, tilemap_coords
				)
				var tile_type: int = TILE_ATLAS_COORDS.find_key(tile_atlas_coords)
				if tile_type == Tiles.WALL:
					astar_grid.set_point_solid(tilemap_coords, true)

		astar_setup_time_marker = Time.get_ticks_msec()

		# AStar Step 2: Solve for each path

		var solved_paths: Array[Array] = []
		for end_point in end_points:
			solved_paths.push_back(astar_grid.get_id_path(start_point, end_point))

		astar_solve_time_marker = Time.get_ticks_msec()

	# Use the AStar2D implementation
	else:
		# AStar Step 1: set up the AStar2D (graph)
		var astar = AStar2D.new()

		# Iterate through entire map, adding points for each normal tile, and making connections to
		# adjacent normal ones.
		# We iterate through columns then rows, from left -> right, top -> bottom. For each tile, we
		# check the top and left neighbors, then create bidirectional connections if valid.
		for i in tilemap_dimensions.x - 1:
			for j in tilemap_dimensions.y - 1:
				var tilemap_coords := Vector2i(i, j)
				var tile_atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(
					Layers.MAIN, tilemap_coords
				)
				var tile_type = TILE_ATLAS_COORDS.find_key(tile_atlas_coords)

				if tile_type == Tiles.GROUND:
					var astar_id := tilemap_coords_to_dijkstra_id(
						tilemap_coords, tilemap_dimensions.x
					)
					astar.add_point(astar_id, tilemap_coords)

					# Check top and left neighbors and create connections if possible
					var top_and_left_neighbor_coords := [
						tilemap_coords - Vector2i(1, 0), tilemap_coords - Vector2i(0, 1)
					]
					for neighbor_coords: Vector2i in top_and_left_neighbor_coords:
						var neighbor_id := tilemap_coords_to_dijkstra_id(
							neighbor_coords, tilemap_dimensions.x
						)
						if astar.has_point(neighbor_id):
							astar.connect_points(astar_id, neighbor_id, true)

		var astar_start_point := tilemap_coords_to_dijkstra_id(start_point, tilemap_dimensions.x)
		var astar_end_points: Array[int] = []
		for end_point in end_points:
			astar_end_points.push_back(
				tilemap_coords_to_dijkstra_id(end_point, tilemap_dimensions.x)
			)

		astar_setup_time_marker = Time.get_ticks_msec()

		# AStar Step 2: Solve for each path

		var solved_paths: Array[PackedInt64Array] = []
		for astar_end_point in astar_end_points:
			solved_paths.push_back(astar.get_id_path(astar_start_point, astar_end_point))

		astar_solve_time_marker = Time.get_ticks_msec()

	var astar_setup_time := astar_setup_time_marker - astar_init_time_marker
	var astar_solve_time := astar_solve_time_marker - astar_setup_time_marker
	var astar_total_time := astar_setup_time + astar_solve_time

	a_star_graph_setup_time_label.text = "%dms" % astar_setup_time
	a_star_solve_step_time_label.text = "%dms" % astar_solve_time
	a_star_total_time_label.text = "%dms" % astar_total_time


## Convert a coordinate pair on the tilemap to a unique integer index that can be used with a
## DijsktraMap.
func tilemap_coords_to_dijkstra_id(coords: Vector2i, map_width: int) -> int:
	return coords.x + map_width * coords.y


## Convert a DijkstraMap point id back into a tilemap coordinate pair.
func dijkstra_id_to_tilemap_coords(id: int, map_width: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(id % map_width, id / map_width)


## If possible, get the tile type given a cell position within the tilemap.
## Returns -1 if the type isn't found.
func get_tile_type_from_cell_position(cell_pos: Vector2i) -> int:
	var tile_type: int = TILE_ATLAS_COORDS.find_key(
		tilemap.get_cell_atlas_coords(Layers.MAIN, cell_pos)
	)
	# Explicit null check to include 0 case
	return tile_type if tile_type != null else -1


## Generate a new random seed on button press.
func _on_random_seed_button_pressed() -> void:
	seed_input.value = randi_range(int(seed_input.min_value), int(seed_input.max_value))
