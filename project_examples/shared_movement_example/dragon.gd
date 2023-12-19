extends CharacterBody2D
## Simple Dragon character that teleports to a location in an ExampleSharedDijkstraTileMap whenever
## a location on the map is clicked. The dragon can be pushed by external forces.

## Emitted when the dragon moves to a new spot
signal moved

@export var map: ExampleSharedDijkstraTileMap  ## Base tilemap that the dragon navigates within


## On ready, start listening to TileMap cell selection events.
func _ready():
	map.cell_selected.connect(_on_dijkstra_tile_map_cell_selected)


## When a cell on the tilemap is selected, move the dragon over to it.
func _on_dijkstra_tile_map_cell_selected(_cell_pos: Vector2i, world_pos: Vector2):
	position = world_pos
	moved.emit()


## Push the dragon in a given direction.
func push(direction: Vector2, strength: float):
	velocity = direction * strength
	move_and_slide()
