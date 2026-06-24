extends CharacterBody2D
## Simple Pikeman character that attempts to walk to a target position, and will keep requesting
## target positions to move to from the ExampleSharedDijkstraTileMap any time a destination is
## reached or the DijkstraMap is recalculated. The Pikeman will attempt to push other characters
## that are in the way (if they have a 'push' method defined).

@export var speed: float = 40.0
@export var map: ExampleSharedDijkstraTileMap ## Base tilemap that the archer navigates within

## Track an immediate position to move toward (Vector2; INVALID_POS if no target).
var target_position: Vector2 = ExampleSharedDijkstraTileMap.INVALID_POS


## On ready, start listening to DijkstraMap recalculation events.
func _ready() -> void:
	map.maps_recalculated.connect(_on_dijkstra_maps_recalculated)


## If a target position is defined, move toward it, then find a new target once it is reached.
func _process(delta: float) -> void:
	if target_position != ExampleSharedDijkstraTileMap.INVALID_POS:
		var direction := position.direction_to(target_position)

		# Apply speed modifier and move the character.
		var speed_modifier := map.get_speed_modifier(position)
		var collision: KinematicCollision2D = move_and_collide(
			direction * speed * speed_modifier * delta
		)

		# Push the target if it has a defined 'push' method, with direction and strength parameters.
		if collision and collision.get_collider().has_method("push"):
			collision.get_collider().push(-collision.get_normal(), speed * speed_modifier)

		# Check if target position has been reached.
		if position.distance_to(target_position) <= delta * speed * speed_modifier:
			target_position = ExampleSharedDijkstraTileMap.INVALID_POS

	# Try to get a new target position if needed.
	if target_position == ExampleSharedDijkstraTileMap.INVALID_POS:
		target_position = map.get_target_for_pikeman(position)


## Whenever the dijkstramaps are recalculated, see if there is a new target position.
func _on_dijkstra_maps_recalculated() -> void:
	var new_target_pos := map.get_target_for_pikeman(position)
	# Avoid setting to INVALID_POS so the unit doesn't get stranded in an invalid spot
	if new_target_pos != ExampleSharedDijkstraTileMap.INVALID_POS:
		target_position = new_target_pos
