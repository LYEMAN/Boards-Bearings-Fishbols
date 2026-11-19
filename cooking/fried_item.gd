class_name FriedItem
extends RigidBody2D
## One piece of street food in the wok.
##
## Cooks one SIDE at a time while touching the oil: the side facing down cooks at full heat,
## the side facing up cooks at food.top_side_rate. Flip it (right-click) or stir it to cook evenly.
## Side A = top half of the sprite, side B = bottom half.

signal doneness_changed(item: FriedItem, doneness: Doneness)

enum Doneness { RAW, COOKED, BURNT }

const SIDE_A := 0
const SIDE_B := 1
const DONENESS_NAMES := ["Raw", "Golden", "Burnt"]

@export var food: FoodData

## How hard the piece follows the mouse while held.
@export var hold_stiffness: float = 22.0
@export var hold_max_speed: float = 4500.0
@export var flip_duration: float = 0.35
@export var flip_hop: float = 420.0

## Cooking progress (seconds at heat 1.0) for side A and side B.
var side_progress := PackedFloat32Array([0.0, 0.0])
var doneness: Doneness = Doneness.RAW
var is_held: bool = false
var is_plated: bool = false
var hold_target: Vector2 = Vector2.ZERO

var _oil: Node2D = null
var _flip_time_left: float = 0.0
var _flip_target: float = 0.0
var _was_perfect: bool = false
var _material: ShaderMaterial
var _smoke: CPUParticles2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if food == null:
		food = FoodCatalog.get_food(&"fishball")
	add_to_group(&"fryable")
	collision_layer = 2          # food
	collision_mask = 1 | 2 | 4   # world, food, utensil
	mass = food.mass
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	_build_shape()
	_build_sprite()
	_build_smoke()
	_update_look()


func _build_shape() -> void:
	if food.is_round():
		var circle := CircleShape2D.new()
		circle.radius = food.size.x * 0.5
		collision.shape = circle
		collision.rotation = 0.0
	else:
		# Capsules are vertical by default; lay it flat so it has two sides to rest on.
		var capsule := CapsuleShape2D.new()
		capsule.radius = food.size.y * 0.5
		capsule.height = food.size.x
		collision.shape = capsule
		collision.rotation = PI * 0.5


func _build_sprite() -> void:
	sprite.texture = food.texture
	sprite.offset = food.texture_offset
	sprite.scale = food.size / food.texture_visible_size
	_material = (sprite.material as ShaderMaterial).duplicate()
	sprite.material = _material


func _build_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.emitting = false
	_smoke.amount = 10
	_smoke.lifetime = 1.2
	_smoke.local_coords = false
	_smoke.direction = Vector2.UP
	_smoke.spread = 20.0
	_smoke.gravity = Vector2(0, -60)
	_smoke.initial_velocity_min = 30.0
	_smoke.initial_velocity_max = 70.0
	_smoke.scale_amount_min = 8.0
	_smoke.scale_amount_max = 16.0
	_smoke.color = Color(0.25, 0.25, 0.25, 0.55)
	_smoke.top_level = true  # don't spin with the body
	add_child(_smoke)


# ---------------------------------------------------------------- oil callbacks (from oil.gd)

func enter_oil(oil_node: Node2D) -> void:
	_oil = oil_node


func exit_oil(oil_node: Node2D) -> void:
	if _oil == oil_node:
		_oil = null


func is_in_oil() -> bool:
	return _oil != null


# ---------------------------------------------------------------- cooking

func _physics_process(delta: float) -> void:
	if global_position.y > 4000.0:
		queue_free()
		return

	_smoke.global_position = global_position
	_smoke.emitting = doneness == Doneness.BURNT and _oil != null

	if _oil == null or is_plated:
		return
	var heat: float = _oil.heat
	if heat <= 0.0:
		return

	# Local +Y of the sprite is side B. cos(rotation) = 1 when side B points straight down.
	var b_down: float = (cos(rotation) + 1.0) * 0.5
	var top: float = food.top_side_rate
	side_progress[SIDE_B] += delta * heat * lerpf(top, 1.0, b_down)
	side_progress[SIDE_A] += delta * heat * lerpf(top, 1.0, 1.0 - b_down)
	_update_look()


func get_side_doneness(side: int) -> Doneness:
	var p: float = side_progress[side]
	if p >= food.cook_time_burnt:
		return Doneness.BURNT
	if p >= food.cook_time_golden:
		return Doneness.COOKED
	return Doneness.RAW


## 0 (raw) .. 1 (golden). Average of both sides, used for floating.
func get_cooked_amount() -> float:
	var avg: float = (side_progress[SIDE_A] + side_progress[SIDE_B]) * 0.5
	return clampf(avg / food.cook_time_golden, 0.0, 1.0)


## 0..1 score of one side: rises to 1 at golden, stays perfect for a while, then drops off and burns.
func get_side_quality(side: int) -> float:
	var p: float = side_progress[side]
	var g: float = food.cook_time_golden
	var b: float = food.cook_time_burnt
	if p < g:
		return lerpf(0.0, 0.6, p / g)
	if p >= b:
		return 0.05
	var t: float = inverse_lerp(g, b, p)
	return 1.0 if t < 0.6 else lerpf(1.0, 0.6, (t - 0.6) / 0.4)


## The worse side decides how good the piece is. 1.0 = perfect.
func get_quality() -> float:
	return minf(get_side_quality(SIDE_A), get_side_quality(SIDE_B))


func get_doneness_label() -> String:
	var a := get_side_doneness(SIDE_A)
	var b := get_side_doneness(SIDE_B)
	if a == Doneness.BURNT or b == Doneness.BURNT:
		return "Burnt"
	if a == Doneness.COOKED and b == Doneness.COOKED:
		return "Perfect!" if get_quality() >= 0.95 else "Golden"
	if a == Doneness.COOKED or b == Doneness.COOKED:
		return "Flip me!"
	return "Raw" if get_quality() < 0.3 else "Undercooked"


func get_side_color(side: int) -> Color:
	var p: float = side_progress[side]
	if p < food.cook_time_golden:
		return food.raw_color.lerp(food.golden_color, p / food.cook_time_golden)
	var t: float = clampf(inverse_lerp(food.cook_time_golden, food.cook_time_burnt, p), 0.0, 1.0)
	# Stay golden for the first part of the window, then darken quickly.
	return food.golden_color.lerp(food.burnt_color, t * t)


func _update_look() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("side_a_color", get_side_color(SIDE_A))
	_material.set_shader_parameter("side_b_color", get_side_color(SIDE_B))

	var a := get_side_doneness(SIDE_A)
	var b := get_side_doneness(SIDE_B)
	var new_doneness: Doneness = Doneness.RAW
	if a == Doneness.BURNT or b == Doneness.BURNT:
		new_doneness = Doneness.BURNT
	elif a == Doneness.COOKED and b == Doneness.COOKED:
		new_doneness = Doneness.COOKED
	if new_doneness != doneness:
		doneness = new_doneness
		doneness_changed.emit(self, doneness)
		if doneness == Doneness.COOKED:
			_pulse()


## Little white flash + pop when both sides turn golden, so the player notices.
func _pulse() -> void:
	if _was_perfect:
		return
	_was_perfect = true
	var base_scale: Vector2 = sprite.scale
	var tw := create_tween().set_parallel()
	tw.tween_method(func(v: float): _material.set_shader_parameter("flash", v), 0.8, 0.0, 0.4)
	tw.tween_property(sprite, "scale", base_scale * 1.25, 0.1)
	tw.chain().tween_property(sprite, "scale", base_scale, 0.15)


# ---------------------------------------------------------------- player interaction

func flip() -> void:
	if is_plated or is_held:
		return
	_flip_target = wrapf(rotation + PI, -PI, PI)
	_flip_time_left = flip_duration
	sleeping = false
	apply_central_impulse(Vector2.UP * mass * flip_hop)


func hold() -> void:
	is_held = true
	_flip_time_left = 0.0
	gravity_scale = 0.0
	collision_mask = 2 | 4  # pass through the wok walls while carried, still pushes other food
	sleeping = false


func release() -> void:
	is_held = false
	gravity_scale = 1.0
	collision_mask = 1 | 2 | 4


func set_plated(plated: bool) -> void:
	is_plated = plated
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = plated


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if is_plated:
		return

	if is_held:
		var to_target: Vector2 = hold_target - state.transform.origin
		state.linear_velocity = (to_target * hold_stiffness).limit_length(hold_max_speed)
		state.angular_velocity *= 0.85
		return

	if _flip_time_left > 0.0:
		_flip_time_left -= state.step
		var diff: float = angle_difference(state.transform.get_rotation(), _flip_target)
		state.angular_velocity = diff / maxf(_flip_time_left, state.step)

	# Cooked pieces get lighter and float, like real fishballs. Force scales with how much is submerged.
	if _oil != null and food.float_strength > 0.0:
		var surface_y: float = _oil.get_surface_global_y()
		var r: float = food.size.y * 0.5
		var submerged: float = clampf((state.transform.origin.y - surface_y + r) / (2.0 * r), 0.0, 1.0)
		var g: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
		state.apply_central_force(Vector2.UP * mass * g * food.float_strength * get_cooked_amount() * submerged)
