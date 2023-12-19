extends Node2D
## Simple Knight character that attempts to follow a path of nodes to a target position. It
## requests a path to a location from the ExampleDijkstraTileMap node whenever it sees that a cell
## on the map was clicked, so long as the cell is within the known move range and movement isn't
## already in progress.

@export var energy: float = 10.0  ## Defines how far the knight can move within a turn
@export var speed: float = 30.0  ## Speed multiplier during movement
@export var map: ExampleDijkstraTileMap  ## Base tilemap that the knight navigates within
## Define weights for terrain types, so certain terrains can be passed through more or less easily.
## A value of INF means that the terrain type cannot be moved through.
@export var tile_terrain_weights := {
	ExampleDijkstraTileMap.Tiles.GRASS: 1.0,
	ExampleDijkstraTileMap.Tiles.WATER: INF,
	ExampleDijkstraTileMap.Tiles.BUSHES: 3.0,
	ExampleDijkstraTileMap.Tiles.ROAD: 0.7
}

## Track a list of world positions that the knight should try to walk through.
var path: Array = []


## On ready, start listening to TileMap cell selection events, and find the initial moveable area.
func _ready() -> void:
	map.cell_selected.connect(_on_dijkstra_tile_map_cell_selected)
	_update_moveable_area()


## If a path is defined, move along it, then find the new moveable area once the end is reached.
func _process(delta: float) -> void:
	if !path.is_empty():
		var direction: Vector2 = position.direction_to(path[-1])

		# Apply speed modifier and move the character.
		var terrain_type = map.get_tile_type_from_world_position(position)
		var speed_modifier: float = 1.0 / tile_terrain_weights.get(terrain_type, 1.0)
		position += direction * delta * speed * speed_modifier

		# Check if target position has been reached.
		if position.distance_to(path[-1]) <= delta * speed * speed_modifier:
			position = path.pop_back()

		if path.is_empty():
			_update_moveable_area()


## Make the DijkstraMap calculate & show the knight's moveable area.
func _update_moveable_area():
	map.calculate_moveable_area(position, energy, tile_terrain_weights, true)


## When a cell on the tilemap is selected, if the knight isn't moving and the tile is within
## movement range, find a path to it.
func _on_dijkstra_tile_map_cell_selected(
	cell_pos: Vector2i, _main_tile_type: int, is_in_highlight_area: bool
):
	if !path.is_empty() or !is_in_highlight_area:
		return

	# Calculate the moveable path to this cell
	path = map.calculate_path_to_cell(cell_pos)
	# Change the highlight for target point only
	map.highlight_cell_area([cell_pos])
