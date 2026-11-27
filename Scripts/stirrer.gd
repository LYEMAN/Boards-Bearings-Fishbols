class_name Stirrer
extends AnimatableBody2D
## A skimmer (salok) that follows the mouse while stirring and physically pushes food around.
## One piece of food can stick to the skimmer at a time so you can scoop it out onto the tray or trash.
## Lives on physics layer 3 ("utensil"); food collides with it but the wok doesn't.

signal item_stuck(item: FriedItem)
signal item_released(item: FriedItem)

@export var radius: float = 26.0
## Extra reach beyond `radius` for catching a piece of food onto the skimmer.
@export var stick_margin: float = 8.0

var active: bool = false
var target: Vector2 = Vector2.ZERO
var stuck_item: FriedItem = null
var _shape: CollisionShape2D


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 4
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	_shape.disabled = true
	add_child(_shape)
	visible = false


func start(at: Vector2) -> void:
	active = true
	target = at
	global_position = at
	_shape.set_deferred("disabled", false)
	visible = true


func stop() -> FriedItem:
	active = false
	_shape.set_deferred("disabled", true)
	visible = false
	return release_stuck()


func release_stuck() -> FriedItem:
	var item := stuck_item
	stuck_item = null
	if is_instance_valid(item):
		item.release()
		item_released.emit(item)
		return item
	return null


func _physics_process(_delta: float) -> void:
	if not active:
		return
	global_position = target

	if stuck_item and not is_instance_valid(stuck_item):
		stuck_item = null

	if stuck_item:
		stuck_item.hold_target = global_position
	else:
		var candidate := _find_item_to_stick()
		if candidate:
			_stick(candidate)


func _stick(item: FriedItem) -> void:
	stuck_item = item
	item.hold()
	# Don't collide with the stirrer itself while stuck to it.
	item.collision_mask = 2
	item.hold_target = global_position
	item_stuck.emit(item)


func _find_item_to_stick() -> FriedItem:
	var shape := CircleShape2D.new()
	shape.radius = radius + stick_margin
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var best: FriedItem = null
	var best_dist: float = INF
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body = hit.collider
		if body is FriedItem and not body.is_queued_for_deletion() and not body.is_plated and not body.is_held:
			var d: float = body.global_position.distance_squared_to(global_position)
			if d < best_dist:
				best_dist = d
				best = body
	return best


func _draw() -> void:
	# Mesh skimmer head + bamboo handle.
	draw_line(Vector2(radius * 0.6, -radius * 0.6), Vector2(radius * 4.0, -radius * 7.0), Color("c8a165"), 10)
	draw_circle(Vector2.ZERO, radius, Color(0.75, 0.75, 0.75, 0.55))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color("9a9a9a"), 4)
