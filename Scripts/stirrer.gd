class_name Stirrer
extends AnimatableBody2D
## A skimmer (salok) that follows the mouse while stirring and physically pushes food around.
## Lives on physics layer 3 ("utensil"); food collides with it but the wok doesn't.

@export var radius: float = 26.0

var active: bool = false
var target: Vector2 = Vector2.ZERO
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


func stop() -> void:
	active = false
	_shape.set_deferred("disabled", true)
	visible = false


func _physics_process(_delta: float) -> void:
	if active:
		global_position = target


func _draw() -> void:
	# Mesh skimmer head + bamboo handle.
	draw_line(Vector2(radius * 0.6, -radius * 0.6), Vector2(radius * 4.0, -radius * 7.0), Color("c8a165"), 10)
	draw_circle(Vector2.ZERO, radius, Color(0.75, 0.75, 0.75, 0.55))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color("9a9a9a"), 4)
