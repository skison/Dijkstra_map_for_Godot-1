extends Node

const GRIDMAP_C_SHARP_SCRIPT = "res://addons/dijkstra-map/visualization_demo/gridmap_c_sharp.cs"
## Whether to use the C# implementation or the GDScript one.
@export var use_c_sharp: bool = false
## Get a reference to the gridmap object which will use either a GDScript or C# script at runtime.
@onready var gridmap: Node2D = %Gridmap

@onready var terrain_selection_item_list: ItemList = %TerrainSelectionItemList
@onready var visualization_selection_item_list: ItemList = %VisualizationSelectionItemList


## On ready, setup only the required gridmap script.
func _ready():
	terrain_selection_item_list.select(0)
	visualization_selection_item_list.select(0)

	if use_c_sharp:
		gridmap.set_script(load(GRIDMAP_C_SHARP_SCRIPT))
		gridmap.Setup()
	else:
		gridmap.setup()


## Pass the terrain item selection signal on to the correct gridmap node.
func _on_terrain_selection_item_selected(index):
	if use_c_sharp:
		gridmap.OnTerrainSelectionItemSelected(index)
	else:
		gridmap.on_terrain_selection_item_selected(index)


## Pass the visualization item selection signal on to the correct gridmap node.
func _on_visualization_selection_item_selected(index):
	if use_c_sharp:
		gridmap.OnVisualizationSelectionItemSelected(index)
	else:
		gridmap.on_visualization_selection_item_selected(index)
