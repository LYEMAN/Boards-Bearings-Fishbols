extends RigidBody2D
## Example fishball that cooks while it's in the oil.
## Add the RigidBody2D to the "fishball" group (or change interact_group on the oil).

signal cooked_state_changed(state: String)

@export var cook_time_golden: float = 6.0   # seconds in oil to reach golden
@export var cook_time_burnt: float = 14.0   # seconds in oil to burn

@export var raw_color: Color = Color("f2efe6")
@export var golden_color: Color = Color("d9962b")
@export var burnt_color: Color = Color("2b1a0e")

var cook_progress: float = 0.0
var state: String = "raw"
var _oil: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("fishball")
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY  # stops tunnelling through the wok walls
	sprite.modulate = raw_color


func enter_oil(oil: Node2D) -> void:
	_oil = oil


func exit_oil(oil: Node2D) -> void:
	if _oil == oil:
		_oil = null


func _physics_process(delta: float) -> void:
	if _oil == null:
		return

	# Cook faster or slower depending on the oil's heat.
	cook_progress += delta * _oil.heat

	# Cooked fishballs get lighter and float up, like the real thing.
	var cooked: float = clampf(cook_progress / cook_time_golden, 0.0, 1.0)
	gravity_scale = lerpf(1.0, 0.6, cooked)

	_update_look()


func _update_look() -> void:
	var new_state: String = "raw"
	
	if cook_progress < cook_time_golden: 
		new_state = "raw"
		sprite.modulate = raw_color.lerp(golden_color, cook_progress / cook_time_golden)
	elif cook_progress >= cook_time_burnt:
		new_state = "burnt"
		sprite.modulate = burnt_color
	else:
		new_state = "golden"
		var t: float = inverse_lerp(cook_time_golden, cook_time_burnt, cook_progress)
		sprite.modulate = golden_color.lerp(burnt_color, t)

	if new_state != state:
		state = new_state
		cooked_state_changed.emit(state)
