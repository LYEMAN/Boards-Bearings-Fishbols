class_name CookingHUD
extends CanvasLayer
## Screen-space UI for the cooking station: ingredient bins, order tickets, stove knob, money.
## Built in code so it adapts to the FoodCatalog and to live orders.

@export var kitchen: KitchenInput
@export var tray: ServingTray
@export var stove: Stove
## Show a debug "Deliver" button on ready orders until the skateboarding part is hooked up.
@export var debug_deliver_button: bool = true

var _money_label: Label
var _toast: Label
var _tickets_box: VBoxContainer
var _ticket_bars: Dictionary = {}  # Order -> ProgressBar
var _heat_buttons: Array[Button] = []
var _temp_bar: ProgressBar
var _temp_label: Label
var _toast_tween: Tween


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top_bar(root)
	_build_ingredients(root)
	_build_tickets(root)
	_build_stove(root)

	OrderManager.money_changed.connect(func(total: int): _money_label.text = "P %d" % total)
	OrderManager.order_accepted.connect(func(_o): _rebuild_tickets())
	OrderManager.order_ready.connect(_on_order_ready)
	OrderManager.order_delivered.connect(_on_order_delivered)
	OrderManager.order_failed.connect(_on_order_failed)
	if tray:
		tray.contents_changed.connect(_rebuild_tickets)
	_rebuild_tickets()


func _process(_delta: float) -> void:
	for order in _ticket_bars:
		var bar: ProgressBar = _ticket_bars[order]
		var ratio: float = order.time_ratio()
		bar.value = ratio
		bar.modulate = Color.RED.lerp(Color.GREEN, ratio)
	if stove:
		_temp_bar.value = stove.get_temperature_ratio()
		_temp_bar.modulate = Color(0.4, 0.6, 1.0).lerp(Color(1.0, 0.3, 0.1), stove.get_temperature_ratio())
		_temp_label.text = "Oil: %s" % stove.get_temperature_label()


# ---------------------------------------------------------------- building

func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_top_bar(root: Control) -> void:
	var panel := _panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 6
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	panel.add_child(hbox)
	_money_label = _label("P %d" % OrderManager.money, 22, Color("ffd166"))
	hbox.add_child(_money_label)
	hbox.add_child(_label("LMB drag: move food / stir    RMB: flip    Drop on tray, then Bag it", 14, Color(1, 1, 1, 0.7)))

	_toast = _label("", 20)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 52
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	root.add_child(_toast)


func _build_ingredients(root: Control) -> void:
	var panel := _panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 6
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_child(_label("Ingredients", 16, Color("ffd166")))
	vbox.add_child(_label("(drag into wok)", 12, Color(1, 1, 1, 0.6)))
	for food in FoodCatalog.all():
		var button := Button.new()
		button.text = food.display_name
		button.icon = food.texture
		button.expand_icon = true
		button.custom_minimum_size = Vector2(150, 40)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 36)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			button.add_theme_color_override(state, food.raw_color)
		button.tooltip_text = "P%d each" % food.price
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(func(): if kitchen: kitchen.start_drag_new(food))
		vbox.add_child(button)


func _build_tickets(root: Control) -> void:
	var panel := _panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_top = 6
	panel.offset_right = -6
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(240, 0)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_child(_label("Orders", 16, Color("ffd166")))
	_tickets_box = VBoxContainer.new()
	_tickets_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_tickets_box)


func _build_stove(root: Control) -> void:
	var panel := _panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_bottom = -6
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)
	hbox.add_child(_label("Stove:", 16, Color("ffd166")))
	var group := ButtonGroup.new()
	for i in Stove.LEVEL_NAMES.size():
		var b := Button.new()
		b.text = Stove.LEVEL_NAMES[i]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = stove != null and stove.level == i
		b.pressed.connect(func(): if stove: stove.set_level(i))
		hbox.add_child(b)
		_heat_buttons.append(b)
	_temp_label = _label("Oil: -", 14)
	_temp_label.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(_temp_label)
	_temp_bar = ProgressBar.new()
	_temp_bar.max_value = 1.0
	_temp_bar.show_percentage = false
	_temp_bar.custom_minimum_size = Vector2(140, 18)
	_temp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_temp_bar)


# ---------------------------------------------------------------- tickets

func _rebuild_tickets() -> void:
	if not is_inside_tree() or _tickets_box == null:
		return
	for child in _tickets_box.get_children():
		child.queue_free()
	_ticket_bars.clear()

	var shown: Array[Order] = OrderManager.get_orders(Order.State.ACCEPTED)
	shown.append_array(OrderManager.get_orders(Order.State.READY))
	if shown.is_empty():
		_tickets_box.add_child(_label("No orders yet.\nAccept one from a customer!", 13, Color(1, 1, 1, 0.6)))
		return
	for order in shown:
		_tickets_box.add_child(_make_ticket(order))


func _make_ticket(order: Order) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff3d6") if order.state == Order.State.ACCEPTED else Color("d6ffd9")
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	style.border_color = order.customer_color
	style.border_width_left = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	vbox.add_child(_label("#%d  %s" % [order.id, order.customer_name], 14, Color.BLACK))

	if order.state == Order.State.ACCEPTED:
		for id in order.items:
			var food := FoodCatalog.get_food(id)
			var have: int = tray.count(id) if tray else 0
			var need: int = order.items[id]
			var color := Color("1b7a2a") if have >= need else Color("8a1c1c")
			vbox.add_child(_label("  %s  %d / %d on tray" % [food.display_name, mini(have, need), need], 13, color))
	else:
		vbox.add_child(_label("  Bagged: %s" % order.describe(), 13, Color.BLACK))
		vbox.add_child(_label("  Ready for delivery!", 13, Color("1b7a2a")))

	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(bar)
	_ticket_bars[order] = bar

	if order.state == Order.State.ACCEPTED:
		var bag := Button.new()
		bag.text = "Bag it"
		bag.focus_mode = Control.FOCUS_NONE
		bag.disabled = not OrderManager.can_bag(order, tray)
		bag.pressed.connect(func(): OrderManager.bag(order, tray))
		vbox.add_child(bag)
	elif debug_deliver_button:
		var deliver := Button.new()
		deliver.text = "Deliver (debug - skate later)"
		deliver.focus_mode = Control.FOCUS_NONE
		deliver.pressed.connect(func(): OrderManager.deliver(order))
		vbox.add_child(deliver)
	return panel


# ---------------------------------------------------------------- feedback

func _on_order_ready(order: Order) -> void:
	show_toast("Order #%d bagged! Deliver it to %s at the skatepark." % [order.id, order.customer_name])
	_rebuild_tickets()


func _on_order_delivered(order: Order) -> void:
	var stars := "★".repeat(order.rating) + "☆".repeat(5 - order.rating)
	show_toast("%s %s  \"%s\"  +P%d" % [order.customer_name, stars, order.feedback, order.payment], Color("b8f5b0"))
	_rebuild_tickets()


func _on_order_failed(order: Order, reason: String) -> void:
	if order.state == Order.State.FAILED:
		show_toast("%s left: \"%s\"" % [order.customer_name, reason], Color("ffb3b3"))
	_rebuild_tickets()


func show_toast(text: String, color: Color = Color.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(4.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
