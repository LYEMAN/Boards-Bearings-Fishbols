class_name Skater
extends CharacterBody2D
## Skater. Pops ollies, flicks the mouse in the air for tricks, grinds rails and chains combos.
##
## COMBO & TIER SYSTEM (C -> B -> A -> S):
##   Every trick in your line adds points and builds your Style Tier based on how many
##   *different* tricks you perform in the same combo.
##   Higher tiers multiply your combo score and award flat style bonus points.
##   Your combo stays alive across the park until you either:
##     - Deliver an order (cashes in the combo for score + peso tips!), or
##     - Bail (land mid-flip or bump into an obstacle).
##
## FUTURE RAIL ANIMATION NAMES (add to AnimatedSprite2D SpriteFrames when ready):
##   "grind_50_50"  -> 50-50 Grind
##   "boardslide"   -> Boardslide
##   "five_o_grind" -> 5-0 Grind
##   "nosegrind"    -> Nosegrind

signal trick_landed(trick_name: String, points: int)
signal gesture_matched(trick_name: String, stroke_points: PackedVector2Array)
signal combo_changed(tricks: Array, points: int, multiplier: float, tier: String)
signal combo_banked(points: int, tricks: Array, tier: String)
signal combo_lost(points: int, reason: String)

## Base points per trick.
const TRICK_POINTS := {
	"Ollie": 10,
	"Backside Pop-shuvit": 55,
	"Frontside Pop-shuvit": 55,
	"Kickflip": 75,
	"Heelflip": 75,
	"360 Flip": 115,
	"Laserflip": 115,
	"50-50 Grind": 50,
	"5-0 Grind": 65,
	"Nosegrind": 65,
	"Boardslide": 80,
}

## Combo Tier multipliers & bonus style points based on unique tricks in the current line.
const TIER_MULTIPLIERS := {
	"": 1.0,
	"E": 1.15,
	"D": 1.35,
	"C": 1.60,
	"B": 1.90,
	"A": 2.35,
	"S": 3.00,
}
const TIER_STYLE_BONUS := {
	"": 0,
	"E": 40,
	"D": 90,
	"C": 160,
	"B": 260,
	"A": 420,
	"S": 700,
}
const TIER_COLORS := {
	"": Color.WHITE,
	"E": Color("adb5bd"),
	"D": Color("70e000"),
	"C": Color("4cc9f0"),
	"B": Color("9d4edd"),
	"A": Color("ff9f1c"),
	"S": Color("ff3366"),
}

## Animations that must finish before landing on the ground (otherwise you bail).
const TRICK_ANIMATIONS := [&"kickflip", &"heelflip", &"pop_shove_it", &"frontside_pop_shuvit", &"360_flip", &"laserflip"]
## Optional animation names played while grinding if present in SpriteFrames.
const GRIND_ANIMATIONS := {
	"50-50 Grind": &"grind_50_50",
	"Boardslide": &"boardslide",
	"5-0 Grind": &"five_o_grind",
	"Nosegrind": &"nosegrind",
}

const SCORE_FONT: Font = preload("res://Fonts/Bangers-Regular.ttf")

const SFX_INITIAL_PUSH: AudioStream = preload("res://Sounds/initial_push.mp3")
const SFX_CONTINUE_PUSH: AudioStream = preload("res://Sounds/continue_push.mp3")
const SFX_OLLIE: AudioStream = preload("res://Sounds/ollie2.mp3")
const SFX_LANDING_1: AudioStream = preload("res://Sounds/landing1.mp3")
const SFX_LANDING_2: AudioStream = preload("res://Sounds/landing2.mp3")
const SFX_INITIAL_RAIL: AudioStream = preload("res://Sounds/initial_rail.mp3")
const SFX_RAIL_LOOP: AudioStream = preload("res://Sounds/rail.mp3")
const SFX_BUMP: AudioStream = preload("res://Sounds/Combo/bump.mp3")
const SFX_BAIL: AudioStream = preload("res://Sounds/Combo/bail.mp3")
const COMBO_TIER_SFX := {
	"E": preload("res://Sounds/Combo/combo_e.mp3"),
	"D": preload("res://Sounds/Combo/combo_d.mp3"),
	"C": preload("res://Sounds/Combo/combo_c.mp3"),
	"B": preload("res://Sounds/Combo/combo_b.mp3"),
	"A": preload("res://Sounds/Combo/combo_a.mp3"),
	"S": preload("res://Sounds/Combo/combo_s.mp3"),
}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trick_label: Label = $TrickLabel
@onready var score_label: Label = get_node_or_null("ScoreLabel")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var camera: Camera2D = get_node_or_null("Camera2D")

# SKATEBOARD SETTINGS
@export_group("Skateboard")
@export var push_impulse: float = 120.0
@export var max_speed: float = 400.0
@export var push_interval: float = 0.55
## Seconds of continuous ground movement before `continue_push` starts playing.
@export var continue_push_delay: float = 2.0
## When holding the opposite direction, you brake until slower than this, then push the new way.
@export var push_turnaround_speed: float = 40.0

# MOMENTUM
@export_group("Momentum")
@export var rolling_resistance: float = 80.0
@export var braking_force: float = 700.0

# CAMERA & SPEED FX
@export_group("Camera & Speed FX")
## Zoomed-out camera scale when stationary / starting out.
@export var camera_min_zoom: float = 0.85
## Zoomed-in camera scale at full momentum.
@export var camera_max_zoom: float = 1.42
## Horizontal speed at which the camera reaches `camera_max_zoom`.
@export var camera_zoom_full_speed: float = 480.0
@export var camera_zoom_smoothing: float = 3.2
## Horizontal speed at which speed lines appear behind the skater.
@export var speed_lines_threshold: float = 280.0

# OLLIE SETTINGS
@export_group("Tricks")
@export var ollie_force: float = 550.0

# RAIL GRIND SETTINGS
@export_group("Rail Grinding")
@export var rail_snap_distance: float = 18.0
@export var min_grind_speed: float = 380.0
@export var rail_speed_boost: float = 120.0
@export var max_grind_speed: float = 640.0
@export var grind_friction: float = 4.0
@export var grind_points_per_second: float = 30.0
@export var grind_flick_cooldown_time: float = 0.25

# BUMPING SETTINGS
@export_group("Bumping")
## Instant horizontal separation when bumping into an obstacle so you never stick to it.
@export var bump_separation: float = 16.0
## Backward rebound speed when bumping into an obstacle (creates room to set up an ollie).
@export var bump_knockback_speed: float = 190.0
@export var bump_hop_force: float = 95.0
@export var bump_cooldown_time: float = 0.45

# PHYSICS
@export_group("Physics")
@export var gravity: float = 1200.0

# INTERNAL VARIABLES
var push_cooldown: float = 0.0
var facing_direction: float = 1.0
var is_airborne: bool = false
var bump_cooldown: float = 0.0

# RAIL STATE
var is_grinding: bool = false
var current_rail: GrindRail = null
var current_grind_trick: String = ""
var rail_regrab_cooldown: float = 0.0
var grind_flick_cooldown: float = 0.0

# TRICK STICK GESTURE INPUT
var trick_selected: bool = false
var stick_input_enabled: bool = true
var gesture := TrickGestureRecognizer.new()

@export_group("Trick Stick")
## Mouse pixels needed to push the virtual stick from center to the rim of the circle.
@export var stick_sensitivity_px: float = 72.0
## Gesture template matching tolerance (higher = more forgiving, lower = stricter).
@export_range(0.20, 0.65) var gesture_match_tolerance: float = 0.42

# SCORING & TIER SYSTEM
@export_group("Scoring")
## Unique trick counts needed to reach each Combo Tier (E -> D -> C -> B -> A -> S).
@export var tier_e_unique_tricks: int = 3
@export var tier_d_unique_tricks: int = 5
@export var tier_c_unique_tricks: int = 6
@export var tier_b_unique_tricks: int = 7
@export var tier_a_unique_tricks: int = 9
@export var tier_s_unique_tricks: int = 10
## Multiplier added for every *different* trick in the combo.
@export var variety_bonus: float = 0.35
## Multiplier added for every trick in the combo (rewards long chains).
@export var chain_bonus: float = 0.08
## Each repeat of the same trick in one combo is worth this fraction of the previous one.
@export_range(0.0, 1.0) var repeat_decay: float = 0.5
@export var max_combo_multiplier: float = 4.0
## Seconds of riding/idling on the ground without doing a trick before the combo ends.
@export var combo_idle_timeout: float = 3.0
@export var bail_duration: float = 0.55

## Total points banked this session.
var score: int = 0
var combo_tricks: Array[String] = []
var combo_raw_points: float = 0.0
var combo_active: bool = false
var combo_idle_timer: float = 0.0
var bail_timer: float = 0.0

var _board_bottom_offset: float = 35.0
var _jump_trick: String = ""
var _jump_counted: bool = false
var _last_emitted_combo_points: int = -1
var _last_combo_tier: String = ""
var _spark_time: float = 0.0
var _speed_fx_time: float = 0.0
var _showing_speed_lines: bool = false
var _ground_move_time: float = 0.0
var _was_stopped_on_ground: bool = true
var _score_label_tween: Tween

var _initial_push_sfx: AudioStreamPlayer
var _continue_push_sfx: AudioStreamPlayer
var _ollie_sfx: AudioStreamPlayer
var _land_sfx: AudioStreamPlayer
var _rail_hit_sfx: AudioStreamPlayer
var _rail_loop_sfx: AudioStreamPlayer
var _combo_tier_sfx: AudioStreamPlayer
var _bump_sfx: AudioStreamPlayer
var _bail_sfx: AudioStreamPlayer


func _ready():
	add_to_group("skater")
	floor_snap_length = 12.0
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect := collision_shape.shape as RectangleShape2D
		_board_bottom_offset = collision_shape.position.y + rect.size.y * 0.5
	_setup_audio()
	if camera:
		camera.zoom = Vector2(camera_min_zoom, camera_min_zoom)
	visibility_changed.connect(_on_visibility_changed)
	sprite.play("ride")
	sprite.animation_finished.connect(_on_animation_finished)
	if trick_label:
		trick_label.text = ""
		trick_label.visible = false
	if score_label:
		score_label.add_theme_font_override("font", SCORE_FONT)
		score_label.text = ""


func _setup_audio() -> void:
	_initial_push_sfx = _make_sfx_player()
	_initial_push_sfx.stream = SFX_INITIAL_PUSH
	_continue_push_sfx = _make_sfx_player()
	_continue_push_sfx.stream = SFX_CONTINUE_PUSH
	_continue_push_sfx.finished.connect(func():
		if _ground_move_time >= continue_push_delay and is_on_floor() and not is_airborne and not is_grinding and is_visible_in_tree():
			_continue_push_sfx.play()
	)
	_ollie_sfx = _make_sfx_player()
	_ollie_sfx.stream = SFX_OLLIE
	_land_sfx = _make_sfx_player()
	_rail_hit_sfx = _make_sfx_player()
	_rail_hit_sfx.stream = SFX_INITIAL_RAIL
	_rail_loop_sfx = _make_sfx_player()
	_rail_loop_sfx.stream = SFX_RAIL_LOOP
	_rail_loop_sfx.finished.connect(func(): if is_grinding and is_visible_in_tree(): _rail_loop_sfx.play())
	_combo_tier_sfx = _make_sfx_player()
	_bump_sfx = _make_sfx_player()
	_bump_sfx.stream = SFX_BUMP
	_bail_sfx = _make_sfx_player()
	_bail_sfx.stream = SFX_BAIL


func _make_sfx_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_stop_rail_sfx()
		_stop_ground_roll_sfx()


func _physics_process(delta: float):

	push_cooldown = maxf(push_cooldown - delta, 0.0)
	rail_regrab_cooldown = maxf(rail_regrab_cooldown - delta, 0.0)
	grind_flick_cooldown = maxf(grind_flick_cooldown - delta, 0.0)
	bump_cooldown = maxf(bump_cooldown - delta, 0.0)
	gesture.sensitivity_px = stick_sensitivity_px
	gesture.max_match_distance = gesture_match_tolerance
	gesture.tick(delta)

	# BAIL RECOVERY
	if bail_timer > 0.0:
		bail_timer -= delta
		if bail_timer <= 0.0:
			sprite.play("ride")

	# RAIL GRINDING
	if is_grinding:
		_stop_ground_roll_sfx()
		_process_grind(delta)
		return
	else:
		_stop_rail_sfx()

	var prev_feet_y: float = global_position.y + _board_bottom_offset

	var direction: float = 0.0
	if bail_timer <= 0.0:
		direction = Input.get_axis("move_left", "move_right")

	# UPDATE FACING DIRECTION (locked during bail knockback so you stay facing the obstacle)
	if direction != 0.0:
		facing_direction = direction
		sprite.flip_h = facing_direction < 0

	# PREPARE CROUCH POSE (holding S or pulling the Trick Stick down pre-loads crouch)
	var preparing = (
		Input.is_action_pressed("prepare")
		and is_on_floor()
		and not is_airborne
		and bail_timer <= 0.0
	)
	var stick_crouch := (
		gesture.is_holding_down()
		and is_on_floor()
		and not is_airborne
		and bail_timer <= 0.0
	)

	if preparing or stick_crouch:
		if sprite.animation != "crouch":
			sprite.play("crouch")

	elif sprite.animation == "crouch":
		sprite.play("ride")

	# OLLIE (Space pops immediately; preserves pre-loaded stick pull so Down -> Space -> Flick works!)
	if (
		Input.is_action_just_pressed("ollie")
		and is_on_floor()
		and not is_airborne
		and bail_timer <= 0.0
	):
		velocity.y = -ollie_force
		is_airborne = true
		trick_selected = false
		_jump_trick = ""
		_jump_counted = false
		sprite.play("ollie")
		_play_ollie_sfx()
		var preloaded := gesture.recognize_air_trick()
		if preloaded != "":
			_apply_air_trick(preloaded)

	# AUTOMATIC BRAKING & ROLLING RESISTANCE
	var moving_opposite = (
		direction != 0.0
		and velocity.x != 0.0
		and signf(direction) != signf(velocity.x)
	)

	if moving_opposite:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			braking_force * delta
		)

	elif direction == 0.0:
		# Slightly higher drag during bail slide so knockback settles smoothly.
		var drag: float = rolling_resistance * (2.2 if bail_timer > 0.0 else 1.0)
		velocity.x = move_toward(
			velocity.x,
			0.0,
			drag * delta
		)

	# PUSH: holding A / D kicks the board along in that direction (one kick every push_interval).
	if direction != 0.0 and bail_timer <= 0.0 and not preparing:
		if push_cooldown <= 0.0 and is_on_floor() and not is_airborne:
			if absf(velocity.x) < push_turnaround_speed or signf(velocity.x) == signf(direction):
				if absf(velocity.x) < max_speed or signf(velocity.x) != signf(direction):
					velocity.x = clampf(
						velocity.x + signf(direction) * push_impulse,
						-max_speed,
						max_speed
					)

					push_cooldown = push_interval
					sprite.play("push")
					if _was_stopped_on_ground:
						_was_stopped_on_ground = false
						if _initial_push_sfx:
							_initial_push_sfx.pitch_scale = randf_range(0.97, 1.03)
							_initial_push_sfx.play()

	# GRAVITY
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if not is_airborne and velocity.y > 0.0:
			velocity.y = 0.0

	var pre_move_vel_x: float = velocity.x
	var attempted_dir: float = direction

	# MOVEMENT
	move_and_slide()

	# CHECK BUMPING INTO OBSTACLES / WALLS
	if _check_obstacle_bump(pre_move_vel_x, attempted_dir):
		return

	# ROLLING OFF A LEDGE / STAIR DROP
	if not is_on_floor() and not is_airborne and bail_timer <= 0.0 and velocity.y > 60.0:
		is_airborne = true
		trick_selected = false
		_jump_trick = ""
		_jump_counted = true

	# CHECK RAIL LOCK-ON (while airborne and descending / near apex)
	if is_airborne and rail_regrab_cooldown <= 0.0 and bail_timer <= 0.0 and velocity.y >= -40.0:
		if _try_lock_rail(prev_feet_y):
			return

	# AIRBORNE ANIMATION
	if is_airborne and not is_on_floor():
		if not trick_selected:
			if sprite.animation != "ollie" and sprite.animation != "air":
				sprite.play("air")

	# LANDING (never bails on normal ground touch, even mid-trick!)
	if is_airborne and is_on_floor():
		is_airborne = false
		_on_landed()
		gesture.clear_stroke(false)
		trick_selected = false
		trick_label.text = ""
		sprite.play("ride")

	# GROUND MOVEMENT SFX: play `continue_push` once moving forward on the ground for 2+ seconds.
	var moving_on_ground: bool = is_on_floor() and not is_airborne and bail_timer <= 0.0 and absf(velocity.x) > 20.0
	if moving_on_ground:
		_ground_move_time += delta
		if _ground_move_time >= continue_push_delay and _continue_push_sfx and not _continue_push_sfx.playing:
			_continue_push_sfx.play()
	else:
		if is_on_floor() and absf(velocity.x) <= 20.0:
			_was_stopped_on_ground = true
		_stop_ground_roll_sfx()

	# COMBO IDLE TIMEOUT: end & remove the combo after 3s of idling or just rolling on the board.
	if combo_active and not is_airborne and not is_grinding:
		combo_idle_timer -= delta
		if combo_idle_timer <= 0.0:
			bank_combo()

	_update_camera_and_fx(delta)


func _input(event):
	if not (event is InputEventMouseMotion):
		return
	if not stick_input_enabled or not is_visible_in_tree():
		return

	gesture.feed_mouse_delta(event.relative)

	# RAIL GRIND TRICK INPUT
	if is_grinding:
		if grind_flick_cooldown <= 0.0:
			var gtrick := gesture.recognize_grind_trick(facing_direction)
			if gtrick != "":
				_apply_grind_trick_switch(gtrick)
		return

	# AIR TRICK GESTURE INPUT
	if is_airborne and not trick_selected:
		var atrick := gesture.recognize_air_trick()
		if atrick != "":
			_apply_air_trick(atrick)


func _on_animation_finished():
	if is_grinding:
		return

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


func _apply_air_trick(trick_name: String) -> void:
	trick_selected = true
	var stroke_pts := gesture.get_stroke_points()
	gesture.clear_stroke(false)

	var animation_name := ""
	var reversed := false
	match trick_name:
		"Kickflip":
			animation_name = "kickflip"
		"Heelflip":
			animation_name = "heelflip"
		"Backside Pop-shuvit":
			animation_name = "pop_shove_it"
		"Frontside Pop-shuvit":
			if sprite.sprite_frames.has_animation("frontside_pop_shuvit"):
				animation_name = "frontside_pop_shuvit"
			else:
				animation_name = "pop_shove_it"
				reversed = true
		"360 Flip":
			animation_name = "360_flip" if sprite.sprite_frames.has_animation("360_flip") else "kickflip"
		"Laserflip":
			animation_name = "laserflip" if sprite.sprite_frames.has_animation("laserflip") else "heelflip"

	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		if reversed:
			sprite.play_backwards(animation_name)
		else:
			sprite.play(animation_name)

	_jump_trick = trick_name
	_jump_counted = false
	gesture_matched.emit(trick_name, stroke_pts)
	print("TRICK DETECTED: ", trick_name)


# ---------------------------------------------------------------- bumping

func _check_obstacle_bump(pre_vel_x: float, attempted_dir: float) -> bool:
	if bump_cooldown > 0.0:
		return false

	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var normal := col.get_normal()
		# Only horizontal side impacts count as bumps (flat tops and stair slopes have normal.y < -0.85).
		if absf(normal.x) <= 0.72:
			continue
		var collider := col.get_collider()
		var is_park_object: bool = collider is SkateObstacle or collider is StairSet
		var moving_into: bool = (
			(absf(pre_vel_x) > 15.0 and signf(pre_vel_x) == -signf(normal.x))
			or (attempted_dir != 0.0 and signf(attempted_dir) == -signf(normal.x))
		)
		if is_park_object and moving_into:
			_trigger_bump(normal.x)
			return true
		elif not is_park_object and absf(pre_vel_x) > 100.0 and signf(pre_vel_x) == -signf(normal.x):
			# Hard slam into outer park wall.
			_trigger_bump(normal.x)
			return true
	return false


func _trigger_bump(normal_x: float) -> void:
	var push_dir: float = signf(normal_x)
	if push_dir == 0.0:
		push_dir = -facing_direction

	bump_cooldown = bump_cooldown_time
	is_airborne = false
	gesture.clear_stroke(false)
	trick_selected = false
	_jump_trick = ""
	_jump_counted = true
	trick_label.text = ""

	# Separate from the obstacle and rebound backward so the skater has room to push & ollie over it.
	global_position.x += push_dir * bump_separation
	velocity.x = push_dir * bump_knockback_speed
	velocity.y = -bump_hop_force
	if _bump_sfx:
		_bump_sfx.pitch_scale = randf_range(0.96, 1.04)
		_bump_sfx.play()
	_bail("BUMP!")


# ---------------------------------------------------------------- rail grinding

func _try_lock_rail(prev_feet_y: float) -> bool:
	var curr_feet_x: float = global_position.x
	var curr_feet_y: float = global_position.y + _board_bottom_offset
	var best_rail: GrindRail = null
	var best_dist: float = INF

	for node in get_tree().get_nodes_in_group("grind_rail"):
		var rail := node as GrindRail
		if rail == null or not rail.is_visible_in_tree():
			continue
		if not rail.contains_global_x(curr_feet_x):
			continue
		var rail_y: float = rail.get_y_at_global_x(curr_feet_x)
		var crossed: bool = prev_feet_y <= rail_y + rail_snap_distance and curr_feet_y >= rail_y - rail_snap_distance
		if crossed:
			var d: float = absf(curr_feet_y - rail_y)
			if d < best_dist:
				best_dist = d
				best_rail = rail

	if best_rail == null:
		return false

	# Even if mid-flip/shove-it, automatically lock onto the rail and count the trick!
	if not _jump_counted:
		_add_trick(_jump_trick if _jump_trick != "" else "Ollie")
		_jump_counted = true

	_start_grind(best_rail)
	return true


func _start_grind(rail: GrindRail) -> void:
	is_grinding = true
	is_airborne = false
	current_rail = rail
	current_grind_trick = "50-50 Grind"
	gesture.clear_stroke(true)
	trick_selected = false
	grind_flick_cooldown = 0.12
	velocity.y = 0.0

	var dir: float = signf(velocity.x) if absf(velocity.x) > 15.0 else facing_direction
	facing_direction = dir
	sprite.flip_h = facing_direction < 0
	var target_speed: float = clampf(maxf(absf(velocity.x) + rail_speed_boost, min_grind_speed), min_grind_speed, max_grind_speed)
	velocity.x = dir * target_speed

	global_position.y = rail.get_y_at_global_x(global_position.x) - _board_bottom_offset
	sprite.rotation = rail.get_slope_angle()
	_start_rail_sfx()
	_add_trick(current_grind_trick)
	_apply_grind_visuals()
	queue_redraw()


func _process_grind(delta: float) -> void:
	if not is_instance_valid(current_rail):
		_exit_rail_to_air()
		return

	_spark_time += delta

	# OLLIE OUT OF THE RAIL (Space pops immediately; S still crouches if held)
	var preparing_out: bool = Input.is_action_pressed("prepare") and bail_timer <= 0.0
	if Input.is_action_just_pressed("ollie") and bail_timer <= 0.0:
		_ollie_off_rail()
		return

	if preparing_out:
		if sprite.animation != "crouch":
			sprite.play("crouch")
	elif sprite.animation == "crouch":
		_apply_grind_visuals()

	# SLIDE ALONG THE RAIL
	var slope_angle: float = current_rail.get_slope_angle()
	velocity.x += sin(slope_angle) * gravity * 0.65 * delta
	velocity.x = move_toward(velocity.x, 0.0, grind_friction * delta)
	velocity.x = clampf(velocity.x, -max_grind_speed, max_grind_speed)
	if absf(velocity.x) > 10.0:
		facing_direction = signf(velocity.x)
		sprite.flip_h = facing_direction < 0

	global_position.x += velocity.x * delta

	if not current_rail.contains_global_x(global_position.x) or absf(velocity.x) < 12.0:
		_exit_rail_to_air()
		return

	global_position.y = current_rail.get_y_at_global_x(global_position.x) - _board_bottom_offset
	sprite.rotation = slope_angle

	# CONTINUOUS GRIND POINTS
	combo_idle_timer = combo_idle_timeout
	combo_raw_points += grind_points_per_second * delta
	var pts: int = get_combo_points()
	if pts != _last_emitted_combo_points:
		_last_emitted_combo_points = pts
		_show_combo()
		combo_changed.emit(combo_tricks, pts, get_combo_multiplier(), get_combo_tier())

	_update_camera_and_fx(delta)
	queue_redraw()


func _apply_grind_trick_switch(trick_name: String) -> void:
	var stroke_pts := gesture.get_stroke_points()
	gesture.clear_stroke(true)
	grind_flick_cooldown = grind_flick_cooldown_time
	if trick_name != current_grind_trick:
		current_grind_trick = trick_name
		_add_trick(trick_name)
		_apply_grind_visuals()
		gesture_matched.emit(trick_name, stroke_pts)
		print("GRIND TRICK DETECTED: ", trick_name)


func _apply_grind_visuals() -> void:
	var anim: StringName = GRIND_ANIMATIONS.get(current_grind_trick, &"")
	if anim != &"" and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		sprite.play("ride")


func _ollie_off_rail() -> void:
	is_grinding = false
	_stop_rail_sfx()
	current_rail = null
	current_grind_trick = ""
	rail_regrab_cooldown = 0.25
	sprite.rotation = 0.0

	velocity.y = -ollie_force
	is_airborne = true
	trick_selected = false
	_jump_trick = ""
	_jump_counted = false
	trick_label.text = ""
	sprite.play("ollie")
	_play_ollie_sfx()
	var preloaded := gesture.recognize_air_trick()
	if preloaded != "":
		_apply_air_trick(preloaded)
	queue_redraw()


func _exit_rail_to_air() -> void:
	is_grinding = false
	_stop_rail_sfx()
	current_rail = null
	current_grind_trick = ""
	rail_regrab_cooldown = 0.2
	sprite.rotation = 0.0

	is_airborne = true
	gesture.clear_stroke(false)
	trick_selected = false
	_jump_trick = ""
	_jump_counted = true
	trick_label.text = ""
	sprite.play("air")
	queue_redraw()


func _update_camera_and_fx(delta: float) -> void:
	var speed: float = absf(velocity.x)
	if camera:
		var t: float = clampf(speed / maxf(camera_zoom_full_speed, 1.0), 0.0, 1.0)
		# Smooth ease-in-out momentum curve.
		var curved_t: float = t * t * (3.0 - 2.0 * t)
		var target_z: float = lerpf(camera_min_zoom, camera_max_zoom, curved_t)
		var weight: float = 1.0 - exp(-camera_zoom_smoothing * delta)
		var z: float = lerpf(camera.zoom.x, target_z, weight)
		camera.zoom = Vector2(z, z)

	var fast_enough: bool = speed >= speed_lines_threshold
	if fast_enough:
		_speed_fx_time += delta
		_showing_speed_lines = true
		queue_redraw()
	elif _showing_speed_lines:
		_showing_speed_lines = false
		queue_redraw()


func _draw() -> void:
	# Speed lines trailing behind the skater when moving fast enough.
	var speed: float = absf(velocity.x)
	if speed >= speed_lines_threshold:
		var ratio: float = clampf((speed - speed_lines_threshold) / maxf(max_speed - speed_lines_threshold, 1.0), 0.15, 1.45)
		var move_back: float = -signf(velocity.x) if speed > 5.0 else -facing_direction
		var y_offsets := [-30.0, -21.0, -12.0, -3.0, 6.0, 15.0, 24.0, 31.0]
		for i in y_offsets.size():
			var rate: float = 7.5 + float(i % 3) * 2.4
			var phase: float = fmod(_speed_fx_time * rate + float(i) * 0.19, 1.0)
			var start_dist: float = 24.0 + float((i * 7) % 14) + phase * 42.0
			var line_len: float = (22.0 + float((i * 11) % 24)) * ratio * (1.0 - phase * 0.45)
			var y: float = y_offsets[i]
			var p1 := Vector2(move_back * start_dist, y)
			var p2 := Vector2(move_back * (start_dist + line_len), y)
			var alpha: float = clampf(ratio, 0.0, 1.0) * (1.0 - phase) * 0.78
			var thickness: float = 2.4 if i % 2 == 0 else 1.5
			draw_line(p1, p2, Color(0.86, 0.96, 1.0, alpha), thickness, true)

	if not is_grinding:
		return
	# Subtle sparks under the board while grinding.
	var back_dir: float = -facing_direction
	var origin := Vector2(0.0, _board_bottom_offset - 2.0)
	for i in 5:
		var phase: float = fmod(_spark_time * 9.0 + float(i) * 0.21, 1.0)
		var spread_y: float = -6.0 - float(i % 3) * 6.0
		var p1 := origin + Vector2(back_dir * (4.0 + phase * 22.0), spread_y * phase + phase * phase * 10.0)
		var p2 := p1 + Vector2(back_dir * 7.0, -2.0 + phase * 4.0)
		var c := Color(1.0, 0.88, 0.35, 1.0 - phase)
		draw_line(p1, p2, c, 2.0)


# ---------------------------------------------------------------- combo & tier scoring

func _on_landed() -> void:
	_play_landing_sfx()
	if not _jump_counted:
		_add_trick(_jump_trick if _jump_trick != "" else "Ollie")
		_jump_counted = true
	combo_idle_timer = combo_idle_timeout


func _stop_ground_roll_sfx() -> void:
	_ground_move_time = 0.0
	if _continue_push_sfx and _continue_push_sfx.playing:
		_continue_push_sfx.stop()


func _play_ollie_sfx() -> void:
	_stop_ground_roll_sfx()
	if _initial_push_sfx and _initial_push_sfx.playing:
		_initial_push_sfx.stop()
	if _ollie_sfx:
		_ollie_sfx.pitch_scale = randf_range(0.97, 1.04)
		_ollie_sfx.play()


func _play_landing_sfx() -> void:
	if _land_sfx:
		_land_sfx.stream = SFX_LANDING_1 if randf() < 0.5 else SFX_LANDING_2
		_land_sfx.pitch_scale = randf_range(0.96, 1.04)
		_land_sfx.play()


func _start_rail_sfx() -> void:
	_stop_ground_roll_sfx()
	if _initial_push_sfx and _initial_push_sfx.playing:
		_initial_push_sfx.stop()
	if _rail_hit_sfx:
		_rail_hit_sfx.pitch_scale = randf_range(0.97, 1.04)
		_rail_hit_sfx.play()
	if _rail_loop_sfx and not _rail_loop_sfx.playing:
		_rail_loop_sfx.play()


func _stop_rail_sfx() -> void:
	if _rail_hit_sfx and _rail_hit_sfx.playing:
		_rail_hit_sfx.stop()
	if _rail_loop_sfx and _rail_loop_sfx.playing:
		_rail_loop_sfx.stop()


func _add_trick(trick_name: String) -> void:
	var uses: int = combo_tricks.count(trick_name)
	var points: float = TRICK_POINTS.get(trick_name, 10) * pow(repeat_decay, uses)
	combo_tricks.append(trick_name)
	combo_raw_points += points
	combo_active = true
	combo_idle_timer = combo_idle_timeout
	var total_pts: int = get_combo_points()
	var tier: String = get_combo_tier()
	if tier != _last_combo_tier and tier != "":
		_last_combo_tier = tier
		_play_combo_tier_sfx(tier)
	_last_emitted_combo_points = total_pts
	trick_landed.emit(trick_name, roundi(points))
	_show_combo()
	combo_changed.emit(combo_tricks, total_pts, get_combo_multiplier(), tier)


func _play_combo_tier_sfx(tier: String) -> void:
	if _combo_tier_sfx == null:
		return
	var stream: AudioStream = COMBO_TIER_SFX.get(tier, null)
	if stream:
		_combo_tier_sfx.stream = stream
		_combo_tier_sfx.pitch_scale = 1.0
		_combo_tier_sfx.play()


func get_unique_trick_count() -> int:
	var unique := {}
	for t in combo_tricks:
		unique[t] = true
	return unique.size()


func get_combo_tier() -> String:
	var n: int = get_unique_trick_count()
	if n >= tier_s_unique_tricks:
		return "S"
	if n >= tier_a_unique_tricks:
		return "A"
	if n >= tier_b_unique_tricks:
		return "B"
	if n >= tier_c_unique_tricks:
		return "C"
	if n >= tier_d_unique_tricks:
		return "D"
	if n >= tier_e_unique_tricks:
		return "E"
	return ""


func get_tier_color(tier: String = "") -> Color:
	var t: String = tier if tier != "" else get_combo_tier()
	return TIER_COLORS.get(t, Color.WHITE)


func get_combo_multiplier() -> float:
	if combo_tricks.is_empty():
		return 1.0
	var unique_count: int = get_unique_trick_count()
	var base_mult: float = minf(
		1.0 + variety_bonus * (unique_count - 1) + chain_bonus * (combo_tricks.size() - 1),
		max_combo_multiplier
	)
	return base_mult * TIER_MULTIPLIERS.get(get_combo_tier(), 1.0)


func get_combo_points() -> int:
	if not combo_active:
		return 0
	var tier: String = get_combo_tier()
	return roundi(combo_raw_points * get_combo_multiplier()) + TIER_STYLE_BONUS.get(tier, 0)


## Ends the current combo and adds it to the score (called on successful delivery).
## Also counts any mid-air trick so delivering mid-jump works seamlessly.
func bank_combo() -> int:
	if is_airborne and not _jump_counted and bail_timer <= 0.0:
		_add_trick(_jump_trick if _jump_trick != "" else "Ollie")
		_jump_counted = true
	if not combo_active:
		return 0
	var points: int = get_combo_points()
	var tier: String = get_combo_tier()
	var tricks := combo_tricks.duplicate()
	var color: Color = get_tier_color(tier)
	score += points
	_reset_combo()
	_flash_score_label("+%d pts!" % points, color)
	combo_banked.emit(points, tricks, tier)
	return points


func _bail(label_text: String = "BAIL!") -> void:
	_stop_rail_sfx()
	_stop_ground_roll_sfx()
	var lost: int = get_combo_points()
	var had_combo: bool = combo_active
	_reset_combo()
	bail_timer = bail_duration
	if label_text == "BAIL!":
		velocity.x *= 0.3
	if (had_combo or label_text == "BAIL!") and _bail_sfx:
		_bail_sfx.pitch_scale = randf_range(0.97, 1.03)
		_bail_sfx.play()
	if sprite.sprite_frames.has_animation("fall"):
		sprite.play("fall")
	_flash_score_label(label_text, Color("ff6b6b"))
	if had_combo or label_text != "BAIL!":
		combo_lost.emit(lost, label_text)


func reset_for_new_park(spawn_global_pos: Vector2) -> void:
	_stop_rail_sfx()
	is_grinding = false
	is_airborne = false
	current_rail = null
	current_grind_trick = ""
	bail_timer = 0.0
	bump_cooldown = 0.0
	rail_regrab_cooldown = 0.0
	velocity = Vector2.ZERO
	sprite.rotation = 0.0
	global_position = spawn_global_pos
	_showing_speed_lines = false
	if camera:
		camera.zoom = Vector2(camera_min_zoom, camera_min_zoom)
	gesture.clear_stroke(true)
	_reset_combo()
	trick_label.text = ""
	if score_label:
		score_label.add_theme_font_override("font", SCORE_FONT)
		score_label.text = ""
	sprite.play("ride")
	queue_redraw()


func _reset_combo() -> void:
	combo_tricks.clear()
	combo_raw_points = 0.0
	combo_active = false
	combo_idle_timer = 0.0
	_last_combo_tier = ""
	_last_emitted_combo_points = -1


func _show_combo() -> void:
	if score_label == null:
		return
	if _score_label_tween:
		_score_label_tween.kill()
	score_label.modulate = Color.WHITE
	var shown := combo_tricks.slice(maxi(combo_tricks.size() - 3, 0))
	var prefix := "... + " if combo_tricks.size() > 3 else ""
	score_label.text = "%s%s\n%d pts" % [
		prefix, " + ".join(PackedStringArray(shown)), get_combo_points()
	]


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
