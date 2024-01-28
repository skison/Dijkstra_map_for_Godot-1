# Temporarily enable tool mode to update the saved DijkstraMap image (not necessary, but allows you
# to properly visualize the shader in the editor before running the project).
#@tool
extends Node
## Main project example scene, acts as a launcher to load up any of the other project demos.
## DijkstraMap is used alongside a TileMap to present some pretty visuals, by procedurally
## highlighting tiles with a shader based on their cost values.

## List all types of tiles used in the example.
enum Tiles { DEFAULT, WALL, ENDPOINT }
const TILE_LAYER = 0  ## This is the only TileMap layer used in this example
const TILE_SET_SOURCE_ID = 1  ## ID of the TileSetSource used in our TileSet to provide tile options
## Known tile positions within the TileSet atlas.
const TILE_ATLAS_COORDS := {
	Tiles.DEFAULT: Vector2i(0, 0),
	Tiles.WALL: Vector2i(2, 0),
	Tiles.ENDPOINT: Vector2i(3, 0)
}
## Available demo project paths mapped to simplified names.
const PROJECT_DEMOS = {
	"visualization_demo": "res://addons/dijkstra-map/visualization_demo/visualization.tscn",
	"turn_based_movement": "res://project_examples/turn_based_example/turn_based_example.tscn",
	"shared_movement": "res://project_examples/shared_movement_example/shared_movement_example.tscn",
	"astar_comparison": "res://project_examples/astar_maze_comparison/astar_maze_comparison.tscn"
}

@export var dijkstra_origin_coords := Vector2i(12, 11) ## Where to start pathfinding from.

var dijkstra_map := DijkstraMap.new() ## DijkstraMap used in this menu for pathfinding
## Sprite2D to render the generated Dijkstra image onto (for debugging purposes).
@onready var dijkstra_image_preview : Sprite2D = $DijkstraImagePreview
@onready var tilemap : TileMap = $TileMap ## TileMap node used as a background visual effect
@onready var map_bounds : Rect2i = tilemap.get_used_rect() ## Just the used portion of the tilemap
@onready var tilemap_shader_mat : ShaderMaterial = tilemap.material ## shader to apply image to


## On ready, generate a DijkstraMap for the tilemap cells, then generate a Dijkstra image that
## represents the cost at each cell, and assign that image to a shader on the tilemap for rendering.
func _ready():
	# Iterate through entire map, adding points for each normal tile, and making connections to
	# adjacent normal ones.
	# We iterate through columns then rows, from left -> right, top -> bottom. For each tile, we
	# check the top and left neighbors, then create bidirectional connections if valid.
	for i in map_bounds.size.x - 1:
		for j in map_bounds.size.y - 1:
			var tilemap_coords := Vector2i(i, j)
			var tile_atlas_coords : Vector2i = tilemap.get_cell_atlas_coords(TILE_LAYER, tilemap_coords)
			var tile_type : int = TILE_ATLAS_COORDS.find_key(tile_atlas_coords)

			if tile_type == Tiles.DEFAULT or tile_type == Tiles.ENDPOINT:
				var dijkstra_id := tilemap_coords_to_dijkstra_id(tilemap_coords)
				dijkstra_map.add_point(dijkstra_id, tile_type)

				# Check top and left neighbors and create connections if possible
				var top_and_left_neighbor_coords := [
					tilemap_coords - Vector2i(1, 0),
					tilemap_coords - Vector2i(0, 1)
				]

				for neighbor_coords in top_and_left_neighbor_coords:
					var neighbor_id := tilemap_coords_to_dijkstra_id(neighbor_coords)
					if dijkstra_map.has_point(neighbor_id):
						dijkstra_map.connect_points(dijkstra_id, neighbor_id, 1.0, true)

	# Run Dijkstra pathfinding to get each node's cost
	dijkstra_map.recalculate(tilemap_coords_to_dijkstra_id(dijkstra_origin_coords), {
		"input_is_destination": true,
		"terrain_weights": {
			Tiles.DEFAULT: 1.0,
			Tiles.ENDPOINT: 1.0
		}
	})

	# Generate the Dijkstra image (with only a red channel).
	# Each byte represents one cell in the tilemap; empty tiles will be set to 0, each other one
	# will track the cost to get there (+1 so there is always a minimum value larger than empty 0s).
	var image_data := PackedByteArray()
	image_data.resize(map_bounds.size.x * map_bounds.size.y)

	var cost_map := dijkstra_map.get_cost_map()
	var max_cost := 0 # Track the maximum Dijkstra cost so the shader can adjust the effect to match
	for point: int in cost_map:
		var cost := int(cost_map[point])
		image_data[point] = cost + 1 # Ensure each point has a value of at least 1
		if cost > max_cost:
			max_cost = cost

	var dijkstra_image := Image.create_from_data(
		map_bounds.size.x, map_bounds.size.y, false, Image.FORMAT_R8, image_data
	)
	var dijkstra_image_texture := ImageTexture.create_from_image(dijkstra_image)

	dijkstra_image_preview.texture = dijkstra_image_texture # Preview image for debugging
	# Update shader parameters to use the generated image & adjust for max cost
	tilemap_shader_mat.set_shader_parameter("dijkstra_image", dijkstra_image_texture)
	tilemap_shader_mat.set_shader_parameter("dijkstra_max_cost", max_cost)


## Convert a coordinate pair on the tilemap to a unique integer index that can be used with a
## DijsktraMap.
func tilemap_coords_to_dijkstra_id(coords: Vector2i) -> int:
	return coords.x + map_bounds.size.x * coords.y


## Convert a DijkstraMap point id back into a tilemap coordinate pair.
func dijkstra_id_to_tilemap_coords(id: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(
		id % map_bounds.size.x,
		id / map_bounds.size.x
	)


## Load up one of the demo projects by name.
func load_project_demo(project_name: String) -> void:
	var project_path : String = PROJECT_DEMOS.get(project_name)
	if project_path:
		get_tree().change_scene_to_file(project_path)
