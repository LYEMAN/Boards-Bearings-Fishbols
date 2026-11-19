class_name Customer
extends Node2D
## A customer who walks up to the stall, shows their order in a speech bubble and waits.
## Click "Accept" to take the order; they then head off to the skatepark to wait for delivery.
## Placeholder art is drawn in _draw(); swap it for a Sprite2D/AnimatedSprite2D later.
## Origin = the customer's feet.

signal left_stall(customer: Customer)

enum Mode { ENTERING, WAITING, LEAVING }

@export var walk_speed: float = 420.0
@export var body_height: float = 300.0
@export var font_size: int = 30

var order: Order
var mode: Mode = Mode.ENTERING
var spot: Vector2
var exit_x: float = 0.0
var skin_color: Color

var _walk_time: float = 0.0
var _bubble: PanelContainer
var _patience_bar: ProgressBar
var _accept_button: Button
var _speech: Label


func setup(new_order: Order, start_pos: Vector2, stall_spot: Vector2) -> void:
	order = new_order
	position = start_pos
	spot = stall_spot
	skin_color = [Color("f1c27d"), Color("e0ac69"), Color("c68642"), Color("8d5524")].pick_random()


func _ready() -> void:
	if order == null:
		return
	_build_bubble()
	_build_speech()
	_bubble.visible = false
	OrderManager.order_failed.connect(_on_order_failed)


func _process(delta: float) -> void:
	if order == null:
		return
	match mode:
		Mode.ENTERING:
			if _walk_to(spot.x, delta):
				mode = Mode.WAITING
				_bubble.visible = true
		Mode.WAITING:
			var ratio: float = order.time_ratio()
			_patience_bar.value = ratio
			_patience_bar.modulate = Color.RED.lerp(Color.GREEN, ratio)
		Mode.LEAVING:
			if _walk_to(exit_x, delta):
				left_stall.emit(self)
				queue_free()
	queue_redraw()


## Moves toward x; returns true on arrival.
func _walk_to(x: float, delta: float) -> bool:
	_walk_time += delta
	position.x = move_toward(position.x, x, walk_speed * delta)
	return is_equal_approx(position.x, x)


func leave(toward_x: float) -> void:
	mode = Mode.LEAVING
	exit_x = toward_x
	_bubble.visible = false


func say(text: String, seconds: float = 2.5) -> void:
	_speech.text = text
	_speech.visible = true
	_speech.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_speech, "modulate:a", 0.0, 0.4)


func _on_accept_pressed() -> void:
	if order.state != Order.State.PENDING:
		return
	OrderManager.accept(order)
	say("Salamat! Adto ra ko sa bowl. (I'll wait at the bowl!)")
	leave(-1400.0)  # heads off toward the skatepark


func _on_order_failed(failed: Order, reason: String) -> void:
	if failed == order and mode != Mode.LEAVING:
		say(reason)
		leave(2600.0)


# ---------------------------------------------------------------- UI

func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(16)
	style.border_color = Color(0.15, 0.15, 0.15)
	style.set_border_width_all(4)
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.z_index = 10  # above the wok and food, even though the body stands behind the counter
	add_child(_bubble)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_bubble.add_child(vbox)

	var name_label := _make_label("%s:" % order.customer_name, Color(0.3, 0.3, 0.3))
	vbox.add_child(name_label)
	vbox.add_child(_make_label("Boss, pa-order ko!", Color.BLACK))

	for id in order.items:
		var food := FoodCatalog.get_food(id)
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = food.texture
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = food.golden_color.lightened(0.2)
		row.add_child(icon)
		row.add_child(_make_label("%d x %s" % [order.items[id], food.display_name], Color.BLACK))
		vbox.add_child(row)

	_patience_bar = ProgressBar.new()
	_patience_bar.max_value = 1.0
	_patience_bar.show_percentage = false
	_patience_bar.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(_patience_bar)

	_accept_button = Button.new()
	_accept_button.text = "Accept  (P%d)" % order.base_price()
	_accept_button.add_theme_font_size_override("font_size", font_size)
	_accept_button.pressed.connect(_on_accept_pressed)
	vbox.add_child(_accept_button)

	# Sit above the head, centred.
	_bubble.reset_size()
	_bubble.position = Vector2(-_bubble.size.x * 0.5, -body_height - 30 - _bubble.size.y)
	_bubble.resized.connect(func(): _bubble.position = Vector2(-_bubble.size.x * 0.5, -body_height - 30 - _bubble.size.y))


func _build_speech() -> void:
	_speech = _make_label("", Color.WHITE)
	_speech.add_theme_color_override("font_outline_color", Color.BLACK)
	_speech.add_theme_constant_override("outline_size", 10)
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.custom_minimum_size = Vector2(600, 0)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.position = Vector2(-300, -body_height - 110)
	_speech.visible = false
	_speech.z_index = 10
	add_child(_speech)


func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ---------------------------------------------------------------- placeholder art

func _draw() -> void:
	var bob: float = 0.0
	var leg_swing: float = 0.0
	if mode != Mode.WAITING:
		bob = absf(sin(_walk_time * 10.0)) * -8.0
		leg_swing = sin(_walk_time * 10.0) * 14.0
	var h: float = body_height
	var shirt: Color = order.customer_color if order else Color.SKY_BLUE
	# Legs
	draw_line(Vector2(-18, -h * 0.38 + bob), Vector2(-18 + leg_swing, 0), Color("2e3a59"), 22)
	draw_line(Vector2(18, -h * 0.38 + bob), Vector2(18 - leg_swing, 0), Color("2e3a59"), 22)
	# Torso
	var torso := Rect2(-45, -h * 0.75 + bob, 90, h * 0.4)
	draw_rect(torso, shirt)
	# Arms
	draw_line(Vector2(-45, -h * 0.72 + bob), Vector2(-60, -h * 0.45 + bob), shirt.darkened(0.2), 18)
	draw_line(Vector2(45, -h * 0.72 + bob), Vector2(60, -h * 0.45 + bob), shirt.darkened(0.2), 18)
	# Head
	draw_circle(Vector2(0, -h * 0.87 + bob), h * 0.13, skin_color)
	draw_circle(Vector2(-12, -h * 0.88 + bob), 4, Color.BLACK)
	draw_circle(Vector2(12, -h * 0.88 + bob), 4, Color.BLACK)
