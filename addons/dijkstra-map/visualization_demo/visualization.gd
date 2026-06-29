extends Node

const DIJKSTRA_TILE_MAP_C_SHARP_SCRIPT = (
		"res://addons/dijkstra-map/visualization_demo/dijkstra_tile_map_c_sharp.cs")
## Whether to use the C# implementation or the GDScript one.
@export var use_c_sharp: bool = false
## Get a reference to the host node which will use either a GDScript or C# script at runtime.
@onready var dijkstra_tile_map_host: Node2D = %DijkstraTileMapHost

@onready var terrain_selection_item_list: ItemList = %TerrainSelectionItemList
@onready var visualization_selection_item_list: ItemList = %VisualizationSelectionItemList


## On ready, setup only the required Dijkstra tile map script.
func _ready():
	terrain_selection_item_list.select(0)
	visualization_selection_item_list.select(0)

	if use_c_sharp:
		dijkstra_tile_map_host.set_script(load(DIJKSTRA_TILE_MAP_C_SHARP_SCRIPT))
		dijkstra_tile_map_host.Setup()
	else:
		dijkstra_tile_map_host.setup()


## Notify the GDScript/C# version of the script about the newly selected terrain option.
func _on_terrain_selection_item_selected(index):
	if use_c_sharp:
		dijkstra_tile_map_host.OnTerrainSelectionItemSelected(index)
	else:
		dijkstra_tile_map_host.on_terrain_selection_item_selected(index)


## Notify the GDScript/C# version of the script about the newly selected visualization option.
func _on_visualization_selection_item_selected(index):
	if use_c_sharp:
		dijkstra_tile_map_host.OnVisualizationSelectionItemSelected(index)
	else:
		dijkstra_tile_map_host.on_visualization_selection_item_selected(index)
