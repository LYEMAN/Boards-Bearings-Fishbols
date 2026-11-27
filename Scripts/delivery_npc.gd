class_name DeliveryNPC
extends Node2D
## A customer waiting in the skatepark for their bagged order.
## Spawned by SkatingArea when an order is accepted; the skater delivers by rolling into them.
## Placeholder art is drawn in _draw() (same style as Customer, skater-sized).
## Origin = the NPC's feet.

enum Mode { WAITING, HAPPY, UPSET, LEAVING }

@export var body_height: float = 90.0
@export var font_size: int = 12
@export var walk_speed: float = 160.0

var order: Order
var mode: Mode = Mode.WAITING
var skin_color: Color = Color("e0ac69")

var _time: float = 0.0
var _exit_x: float = 0.0
var _info: Label
var _ui_box: VBoxContainer
var _status: Label
var _timer_bar: ProgressBar
var _speech: Label
var _speech_tween: Tween
var _say_cooldown: float = 0.0


func setup(new_order: Order, feet_position: Vector2) -> void:
	order = new_order
	position = feet_position
	skin_color = [Color("f1c27d"), Color("e0ac69"), Color("c68642"), Color("8d5524")].pick_random()


func _ready() -> void:
	if order == null:
		return
	_build_ui()
	# Pop in.
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	if order == null:
		return
	_time += delta
	_say_cooldown = maxf(_say_cooldown - delta, 0.0)
	match mode:
		Mode.WAITING:
			_update_status()
		Mode.LEAVING:
			position.x = move_toward(position.x, _exit_x, walk_speed * delta)
			if is_equal_approx(position.x, _exit_x):
				queue_free()
	queue_redraw()


func is_ready_for_pickup() -> bool:
	return mode == Mode.WAITING and order != null and order.state == Order.State.READY


func say(text: String, seconds: float = 2.5) -> void:
	if _speech == null:
		return
	_speech.text = text
	# Fixed-size, bottom-aligned box so 1-3 lines always end just above the head / info box.
	var top: float = _ui_box.position.y if _ui_box.visible else -body_height - 8.0
	_speech.position = Vector2(-110, top - 4.0 - _speech.size.y)
	_speech.modulate.a = 1.0
	_speech.visible = true
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(seconds)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.4)


## Says something, but not more than once every few seconds (for "not ready yet" nagging).
func say_throttled(text: String) -> void:
	if _say_cooldown > 0.0:
		return
	_say_cooldown = 3.0
	say(text)


## Order received: cheer, then walk off.
func celebrate(text: String, exit_x: float) -> void:
	mode = Mode.HAPPY
	_set_ui_visible(false)
	say(text, 2.0)
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 24.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y - 16.0, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.2)
	tw.tween_callback(leave.bind(exit_x))


## Order failed / cancelled: complain, then walk off.
func storm_off(text: String, exit_x: float) -> void:
	mode = Mode.UPSET
	_set_ui_visible(false)
	say(text, 2.0)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(leave.bind(exit_x))


func leave(exit_x: float) -> void:
	mode = Mode.LEAVING
	_exit_x = exit_x
	_set_ui_visible(false)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.custom_minimum_size = Vector2(160, 0)
	_ui_box = box
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 5
	add_child(box)

	_info = _make_label("#%d %s\n%s" % [order.id, order.customer_name, order.describe()], Color.WHITE)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)

	_status = _make_label("", Color("ffd166"))
	box.add_child(_status)

	_timer_bar = ProgressBar.new()
	_timer_bar.max_value = 1.0
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(70, 5)
	_timer_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_timer_bar)

	_speech = _make_label("", Color.WHITE)
	_speech.custom_minimum_size = Vector2(220, 0)
	_speech.size = Vector2(220, 48)
	_speech.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_speech.clip_text = false
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.position = Vector2(-110, -body_height - 110)
	_speech.visible = false
	_speech.z_index = 6
	add_child(_speech)

	# Keep the info box sitting just above the head, whatever its height.
	box.resized.connect(_place_ui_box)
	_place_ui_box.call_deferred()


func _place_ui_box() -> void:
	_ui_box.position = Vector2(-80, -body_height - 8 - _ui_box.size.y)


func _update_status() -> void:
	var ratio: float = order.time_ratio()
	_timer_bar.value = ratio
	_timer_bar.modulate = Color.RED.lerp(Color.GREEN, ratio)
	if order.state == Order.State.READY:
		_status.text = "Bag is ready - skate it over!"
		_status.add_theme_color_override("font_color", Color("8cff8c"))
	else:
		_status.text = "Waiting... (still cooking)"
		_status.add_theme_color_override("font_color", Color("ffd166"))


func _set_ui_visible(on: bool) -> void:
	if _info:
		_info.get_parent().visible = on


func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ---------------------------------------------------------------- placeholder art

func _draw() -> void:
	var h: float = body_height
	var bob: float = 0.0
	var leg_swing: float = 0.0
	var arm_raise: float = 0.0
	match mode:
		Mode.LEAVING:
			bob = absf(sin(_time * 10.0)) * -3.0
			leg_swing = sin(_time * 10.0) * 5.0
		Mode.HAPPY:
			arm_raise = 1.0
		Mode.WAITING:
			if order and order.state == Order.State.READY:
				# Waving for the skater.
				arm_raise = 0.5 + 0.5 * sin(_time * 8.0)
	var shirt: Color = order.customer_color if order else Color.SKY_BLUE
	# Legs
	draw_line(Vector2(-6, -h * 0.38 + bob), Vector2(-6 + leg_swing, 0), Color("2e3a59"), 7)
	draw_line(Vector2(6, -h * 0.38 + bob), Vector2(6 - leg_swing, 0), Color("2e3a59"), 7)
	# Torso
	draw_rect(Rect2(-15, -h * 0.75 + bob, 30, h * 0.4), shirt)
	# Arms (right arm waves when the bag is ready)
	draw_line(Vector2(-15, -h * 0.72 + bob), Vector2(-20, -h * 0.45 + bob), shirt.darkened(0.2), 6)
	var hand := Vector2(20, -h * 0.45 + bob).lerp(Vector2(24, -h * 1.0 + bob), arm_raise)
	draw_line(Vector2(15, -h * 0.72 + bob), hand, shirt.darkened(0.2), 6)
	# Head
	draw_circle(Vector2(0, -h * 0.87 + bob), h * 0.13, skin_color)
	draw_circle(Vector2(-4, -h * 0.88 + bob), 1.5, Color.BLACK)
	draw_circle(Vector2(4, -h * 0.88 + bob), 1.5, Color.BLACK)
	# Bouncing "deliver here" arrow above the info box
	if mode == Mode.WAITING and order and order.state == Order.State.READY:
		var top: float = _ui_box.position.y if _ui_box else -h - 70.0
		var y: float = top - 4.0 + sin(_time * 6.0) * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(-8, y - 10), Vector2(8, y - 10), Vector2(0, y)]), Color("8cff8c"))
