extends Node
## Whether to use the C# implementation or the GDScript one.
@export var use_c_sharp: bool = false
## Get easy references to the GDScript and C# gridmap objects.
@onready var gdscript_gridmap = $gridmap
@onready var c_sharp_gridmap = $"gridmap_c#"


## On ready, show only the required gridmap and stop processing the other one.
func _ready():
	gdscript_gridmap.visible = !use_c_sharp
	gdscript_gridmap.process_mode = (
		Node.PROCESS_MODE_INHERIT if !use_c_sharp else Node.PROCESS_MODE_DISABLED
	)
	c_sharp_gridmap.visible = use_c_sharp
	c_sharp_gridmap.process_mode = (
		Node.PROCESS_MODE_INHERIT if use_c_sharp else Node.PROCESS_MODE_DISABLED
	)


## Pass the terrain item selection signal on to the correct gridmap node.
func _on_terrain_selection_item_selected(index):
	if use_c_sharp:
		c_sharp_gridmap.OnTerrainSelectionItemSelected(index)
	else:
		gdscript_gridmap.on_terrain_selection_item_selected(index)


## Pass the visualization item selection signal on to the correct gridmap node.
func _on_visualization_selection_item_selected(index):
	if use_c_sharp:
		c_sharp_gridmap.OnVisualizationSelectionItemSelected(index)
	else:
		gdscript_gridmap.on_visualization_selection_item_selected(index)
