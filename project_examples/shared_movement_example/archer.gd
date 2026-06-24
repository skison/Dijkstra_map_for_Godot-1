extends CharacterBody2D
## Simple Archer character that attempts to walk to a target position, and will keep requesting
## target positions to move to from the ExampleSharedDijkstraTileMap any time a destination is
## reached or the DijkstraMap is recalculated.

@export var speed: float = 40.0
@export var map: ExampleSharedDijkstraTileMap ## Base tilemap that the archer navigates within

## Track an immediate position to move toward (Vector2; INVALID_POS if no target).
var target_position: Vector2 = ExampleSharedDijkstraTileMap.INVALID_POS


## On ready, start listening to DijkstraMap recalculation events.
func _ready() -> void:
	map.maps_recalculated.connect(_on_dijkstra_maps_recalculated)


func _process(delta: float) -> void:
	if not is_nan(target_position.x):
		# Apply speed modifier and move the character.
		var speed_modifier := map.get_speed_modifier(position)
		# Check if target position has been reached.
		if position.distance_to(target_position) <= delta * speed * speed_modifier:
			target_position = ExampleSharedDijkstraTileMap.INVALID_POS
		else: # Otherwise, move toward target.
			var direction := position.direction_to(target_position)
			velocity = direction * speed * speed_modifier
			move_and_slide()

	# Try to get a new target position if needed.
	if target_position == ExampleSharedDijkstraTileMap.INVALID_POS:
		target_position = map.get_target_for_archer(position)


## Whenever the dijkstramaps are recalculated, see if there is a new target position.
func _on_dijkstra_maps_recalculated() -> void:
	var new_target_pos := map.get_target_for_archer(position)
	# Avoid setting to INVALID_POS so the unit doesn't get stranded in an invalid spot
	if not is_nan(new_target_pos.x):
		target_position = new_target_pos
