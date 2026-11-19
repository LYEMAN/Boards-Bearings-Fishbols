

extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trick_label: Label = $TrickLabel
@onready var score_label: Label = $ScoreLabel

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
var score: int = 0
var combo_multiplier: int = 1

var last_trick_name: String = ""
var current_trick_name: String = ""

@export_group("Scoring")
@export var max_combo_multiplier: int = 5

func _ready():
	sprite.play("ride")
	sprite.animation_finished.connect(_on_animation_finished)
	trick_label.text = ""

func _physics_process(delta: float):

	push_cooldown = maxf(push_cooldown - delta, 0.0)

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
	if Input.is_action_pressed("push"):
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
		mouse_flick = Vector2.ZERO
		trick_selected = false
		trick_label.text = ""
		sprite.play("ride")

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



func recognize_trick():
	trick_selected = true
	var direction = mouse_flick.normalized()

	# Convert mouse direction relative to skater facing direction
	var x = direction.x * facing_direction
	var y = direction.y
	var trick_name = ""
	var animation_name = ""

	# DIAGONAL FLICKS
	if absf(x) > 0.5 and absf(y) > 0.5:
		if x > 0 and y < 0:
			trick_name = "Kickflip"
			animation_name = "kickflip"
		
		elif x < 0 and y < 0:
			trick_name = "Heelflip"
			animation_name = "heelflip"

	# HORIZONTAL FLICKS
	elif absf(x) > absf(y):
		if x > 0:
			trick_name = "Pop Shove-it"
			animation_name = "pop_shove_it"
		else:
			trick_name = "Frontside Shove-it"
			animation_name = "frontside_shove_it"

	# VERTICAL FLICKS
	else:
		if y < 0:
			trick_name = "Upward flick"
		else:
			trick_name = "Downward flick"

	if animation_name != "":
		sprite.play(animation_name)
		trick_label.text = trick_name
	
	print("TRICK DETECTED: ", trick_name)
