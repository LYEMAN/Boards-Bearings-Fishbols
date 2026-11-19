class_name Skater
extends CharacterBody2D
## Skater. Pops ollies, flicks the mouse in the air for tricks and chains them into combos.
##
## COMBOS: every jump adds one trick (the flicked trick, or a plain "Ollie").
## Land and pop again within `combo_window` seconds to keep the combo going.
## Different tricks raise the multiplier, repeating the same trick is worth less each time.
## When the combo ends it is "banked" -> combo_banked(points, tricks). The skating area turns
## banked points into a peso tip that is paid when the bag is delivered.

signal trick_landed(trick_name: String, points: int)
signal combo_changed(tricks: Array, points: int, multiplier: float)
signal combo_banked(points: int, tricks: Array)
signal combo_lost(points: int)

## Base points per trick.
const TRICK_POINTS := {
	"Ollie": 10,
	"Upward flick": 20,
	"Downward flick": 20,
	"Pop Shove-it": 40,
	"Frontside Shove-it": 40,
	"Kickflip": 75,
	"Heelflip": 75,
}
## Animations that must finish before landing (otherwise you bail).
const TRICK_ANIMATIONS := [&"kickflip", &"heelflip", &"pop_shove_it"]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trick_label: Label = $TrickLabel
@onready var score_label: Label = get_node_or_null("ScoreLabel")

# SKATEBOARD SETTINGS
@export_group("Skateboard")
@export var push_impulse: float = 120.0
@export var max_speed: float = 400.0
@export var push_interval: float = 0.55

# MOMENTUM
@export_group("Momentum")
@export var rolling_resistance: float = 80.0
@export var braking_force: float = 700.0

# OLLIE SETTINGS
@export_group("Tricks")
@export var ollie_force: float = 550.0

# PHYSICS
@export_group("Physics")
@export var gravity: float = 1200.0

# INTERNAL VARIABLES
var push_cooldown: float = 0.0
var facing_direction: float = 1.0
var is_airborne: bool = false

# TRICK INPUT
var mouse_flick: Vector2 = Vector2.ZERO
var trick_selected: bool = false

@export_group("Trick Input")
@export var flick_min_distance: float = 80.0

# SCORING SYSTEM
@export_group("Scoring")
## Seconds after landing to pop the next ollie and keep the combo alive.
@export var combo_window: float = 1.25
## Multiplier added for every *different* trick in the combo.
@export var variety_bonus: float = 0.5
## Multiplier added for every trick in the combo (rewards long chains).
@export var chain_bonus: float = 0.1
## Each repeat of the same trick in one combo is worth this fraction of the previous one.
@export_range(0.0, 1.0) var repeat_decay: float = 0.5
@export var max_combo_multiplier: float = 5.0
## Landing before a flip/shove-it animation finishes = bail, and the combo is lost.
@export var bail_on_unfinished_trick: bool = true
@export var bail_duration: float = 0.6

## Total points banked this session.
var score: int = 0
var combo_tricks: Array[String] = []
var combo_raw_points: float = 0.0
var combo_active: bool = false
var combo_timer: float = 0.0
var bail_timer: float = 0.0

var _jump_trick: String = ""
var _jump_counted: bool = false
var _score_label_tween: Tween


func _ready():
	add_to_group("skater")
	sprite.play("ride")
	sprite.animation_finished.connect(_on_animation_finished)
	trick_label.text = ""
	if score_label:
		score_label.text = ""


func _physics_process(delta: float):

	push_cooldown = maxf(push_cooldown - delta, 0.0)

	# BAIL RECOVERY
	if bail_timer > 0.0:
		bail_timer -= delta
		if bail_timer <= 0.0:
			sprite.play("ride")

	var direction = Input.get_axis(
		"move_left",
		"move_right"
	)

	# UPDATE FACING DIRECTION
	if direction != 0:
		facing_direction = direction
		sprite.flip_h = facing_direction < 0

	# PREPARE OLLIE
	var preparing = (
		Input.is_action_pressed("prepare")
		and is_on_floor()
		and not is_airborne
		and bail_timer <= 0.0
	)

	if preparing:
		if sprite.animation != "crouch":
			sprite.play("crouch")

	elif sprite.animation == "crouch":
		sprite.play("ride")

	# OLLIE
	if (
		Input.is_action_just_pressed("ollie")
		and preparing
	):
		velocity.y = -ollie_force
		is_airborne = true
		mouse_flick = Vector2.ZERO
		trick_selected = false
		_jump_trick = ""
		_jump_counted = false
		sprite.play("ollie")

	# AUTOMATIC BRAKING
	var moving_opposite = (
		direction != 0
		and velocity.x != 0
		and signf(direction) != signf(velocity.x)
	)

	if moving_opposite:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			braking_force * delta
		)

	elif direction == 0:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			rolling_resistance * delta
		)

	# PUSH
	if Input.is_action_pressed("push") and bail_timer <= 0.0:
		if push_cooldown <= 0.0 and is_on_floor():
			if velocity.x == 0 or signf(velocity.x) == facing_direction:
				if absf(velocity.x) < max_speed:
					velocity.x = clampf(
						velocity.x + facing_direction * push_impulse,
						-max_speed,
						max_speed
					)

					push_cooldown = push_interval
					sprite.play("push")

	# GRAVITY
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if not is_airborne:
			velocity.y = 0.0

	# MOVEMENT
	move_and_slide()

	# AIRBORNE ANIMATION
	if is_airborne and not is_on_floor():
		if not trick_selected:
			if sprite.animation != "ollie" and sprite.animation != "air":
				sprite.play("air")

	# LANDING
	if is_airborne and is_on_floor():
		is_airborne = false
		var bailed := _on_landed()
		mouse_flick = Vector2.ZERO
		trick_selected = false
		trick_label.text = ""
		if not bailed:
			sprite.play("ride")

	# COMBO TIMER (only runs while rolling on the ground)
	if combo_active and not is_airborne:
		combo_timer -= delta
		if combo_timer <= 0.0:
			bank_combo()


func _input(event):
	# Only record mouse movement while airborne
	if not is_airborne or trick_selected:
		return

	if event is InputEventMouseMotion:
		mouse_flick += event.relative
		# Check if the flick is long enough
		if mouse_flick.length() >= flick_min_distance:
			recognize_trick()


func _on_animation_finished():
	if sprite.animation == "push":
		sprite.play("ride")

	elif sprite.animation == "ollie":
		if is_airborne:
			sprite.play("air")
		else:
			sprite.play("ride")

	elif sprite.animation in TRICK_ANIMATIONS and is_airborne:
		# Trick finished cleanly - safe to land.
		sprite.play("air")


func recognize_trick():
	trick_selected = true
	var direction = mouse_flick.normalized()

	# Convert mouse direction relative to skater facing direction
	var x = direction.x * facing_direction
	var y = direction.y
	var trick_name = ""
	var animation_name = ""
	var reversed := false

	# DIAGONAL FLICKS
	if absf(x) > 0.5 and absf(y) > 0.5:
		if x > 0 and y < 0:
			trick_name = "Kickflip"
			animation_name = "kickflip"

		elif x < 0 and y < 0:
			trick_name = "Heelflip"
			animation_name = "heelflip"

		elif y > 0:
			# Downward diagonals count as a downward flick
			trick_name = "Downward flick"

	# HORIZONTAL FLICKS
	elif absf(x) > absf(y):
		if x > 0:
			trick_name = "Pop Shove-it"
			animation_name = "pop_shove_it"
		else:
			trick_name = "Frontside Shove-it"
			# No dedicated animation yet: spin the shove-it the other way.
			animation_name = "pop_shove_it"
			reversed = true

	# VERTICAL FLICKS
	else:
		if y < 0:
			trick_name = "Upward flick"
		else:
			trick_name = "Downward flick"

	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		if reversed:
			sprite.play_backwards(animation_name)
		else:
			sprite.play(animation_name)

	_jump_trick = trick_name
	trick_label.text = "%s (%d)" % [trick_name, TRICK_POINTS.get(trick_name, 10)]
	print("TRICK DETECTED: ", trick_name)


# ---------------------------------------------------------------- combo scoring

## Returns true if the landing was a bail.
func _on_landed() -> bool:
	if bail_on_unfinished_trick and sprite.is_playing() and sprite.animation in TRICK_ANIMATIONS:
		_bail()
		return true
	if not _jump_counted:
		_add_trick(_jump_trick if _jump_trick != "" else "Ollie")
		_jump_counted = true
	combo_timer = combo_window
	return false


func _add_trick(trick_name: String) -> void:
	var uses: int = combo_tricks.count(trick_name)
	var points: float = TRICK_POINTS.get(trick_name, 10) * pow(repeat_decay, uses)
	combo_tricks.append(trick_name)
	combo_raw_points += points
	combo_active = true
	trick_landed.emit(trick_name, roundi(points))
	_show_combo()
	combo_changed.emit(combo_tricks, get_combo_points(), get_combo_multiplier())


func get_combo_multiplier() -> float:
	if combo_tricks.is_empty():
		return 1.0
	var unique := {}
	for t in combo_tricks:
		unique[t] = true
	var mult: float = 1.0 + variety_bonus * (unique.size() - 1) + chain_bonus * (combo_tricks.size() - 1)
	return minf(mult, max_combo_multiplier)


func get_combo_points() -> int:
	return roundi(combo_raw_points * get_combo_multiplier())


## Ends the current combo and adds it to the score. Also counts a trick that is still
## in the air (so delivering mid-trick works). Returns the banked points.
func bank_combo() -> int:
	if is_airborne and not _jump_counted and bail_timer <= 0.0:
		_add_trick(_jump_trick if _jump_trick != "" else "Ollie")
		_jump_counted = true
	if not combo_active:
		return 0
	var points: int = get_combo_points()
	var tricks := combo_tricks.duplicate()
	score += points
	_reset_combo()
	_flash_score_label("+%d pts" % points, Color("ffd166"))
	combo_banked.emit(points, tricks)
	return points


func _bail() -> void:
	var lost: int = get_combo_points()
	_reset_combo()
	bail_timer = bail_duration
	velocity.x *= 0.3
	if sprite.sprite_frames.has_animation("fall"):
		sprite.play("fall")
	_flash_score_label("BAIL!", Color("ff6b6b"))
	combo_lost.emit(lost)


func _reset_combo() -> void:
	combo_tricks.clear()
	combo_raw_points = 0.0
	combo_active = false
	combo_timer = 0.0


func _show_combo() -> void:
	if score_label == null:
		return
	if _score_label_tween:
		_score_label_tween.kill()
	score_label.modulate = Color.WHITE
	var shown := combo_tricks.slice(maxi(combo_tricks.size() - 3, 0))
	var prefix := "... + " if combo_tricks.size() > 3 else ""
	score_label.text = "%s%s\nx%.1f  =  %d" % [prefix, " + ".join(PackedStringArray(shown)), get_combo_multiplier(), get_combo_points()]


func _flash_score_label(text: String, color: Color) -> void:
	if score_label == null:
		return
	if _score_label_tween:
		_score_label_tween.kill()
	score_label.text = text
	score_label.modulate = color
	_score_label_tween = create_tween()
	_score_label_tween.tween_interval(1.0)
	_score_label_tween.tween_property(score_label, "modulate:a", 0.0, 0.4)
