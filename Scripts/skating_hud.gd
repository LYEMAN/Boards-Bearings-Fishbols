class_name SkatingHUD
extends CanvasLayer
## Screen-space UI for the skatepark: money, trick tip pool, current combo, deliveries.
## Built in code (like CookingHUD). Owned and fed by SkatingArea.

var _money_label: Label
var _pool_label: Label
var _deliveries_label: Label
var _combo_label: Label
var _combo_tween: Tween
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top right: money, tips, deliveries.
	var panel := _panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_top = 6
	panel.offset_right = -6
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(260, 0)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_money_label = _label("P %d" % OrderManager.money, 22, Color("ffd166"))
	vbox.add_child(_money_label)
	_pool_label = _label("", 15, Color("8cff8c"))
	vbox.add_child(_pool_label)
	vbox.add_child(_label("Deliveries", 16, Color("ffd166")))
	_deliveries_label = _label("", 13)
	vbox.add_child(_deliveries_label)

	# Center top: current combo.
	_combo_label = _label("", 26, Color.WHITE)
	_combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_combo_label.offset_top = 60
	_combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_combo_label)

	# Toast under the combo.
	_toast = _label("", 20)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 140
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast)

	# Bottom: controls hint.
	var hint := _label(
		"A/D steer   Shift: push   Hold S + Space: ollie   Flick mouse in the air: tricks\n"
		+ "Chain jumps within a moment of landing for combos - mix DIFFERENT tricks for bigger tips!",
		13, Color(1, 1, 1, 0.75))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_bottom = -8
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

	OrderManager.money_changed.connect(set_money)
	set_pool(0, false)


func set_money(total: int) -> void:
	_money_label.text = "P %d" % total


func set_pool(pesos: int, carrying: bool) -> void:
	if carrying:
		_pool_label.text = "Trick tips: +P%d" % pesos
		_pool_label.add_theme_color_override("font_color", Color("8cff8c"))
	elif pesos > 0:
		_pool_label.text = "Trick tips: +P%d (saved for next bag)" % pesos
		_pool_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	else:
		_pool_label.text = "Carry a bag to earn trick tips"
		_pool_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))


func set_deliveries(text: String) -> void:
	_deliveries_label.text = text


func show_combo(tricks: Array, points: int, multiplier: float, pesos: int, carrying: bool) -> void:
	if _combo_tween:
		_combo_tween.kill()
	_combo_label.modulate = Color.WHITE
	var shown: Array = tricks.slice(maxi(tricks.size() - 4, 0))
	var names := PackedStringArray()
	for t in shown:
		names.append(str(t))
	var prefix := "... + " if tricks.size() > 4 else ""
	var money := "   (+P%d)" % pesos if carrying else ""
	_combo_label.text = "%s%s\nx%.1f   %d pts%s" % [prefix, " + ".join(names), multiplier, points, money]


func end_combo(text: String, color: Color) -> void:
	if _combo_tween:
		_combo_tween.kill()
	_combo_label.text = text
	_combo_label.modulate = color
	_combo_tween = create_tween()
	_combo_tween.tween_interval(1.2)
	_combo_tween.tween_property(_combo_label, "modulate:a", 0.0, 0.5)


func show_toast(text: String, color: Color = Color.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
