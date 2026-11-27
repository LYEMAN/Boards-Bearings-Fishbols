class_name SkatingHUD
extends CanvasLayer
## Clean screen-space UI for the skatepark:
##   - Top right: money, banked tips, deliveries
##   - Top center: order / day notifications only
##   - Bottom left: Trick Stick circle, exaggerated pop-out Combo Tier Letter to its right,
##     and minimal Tab / Esc controls underneath.

const COMBO_FONT: Font = preload("res://Fonts/Bangers-Regular.ttf")

const TIER_COLORS := {
	"": Color.WHITE,
	"E": Color("adb5bd"),
	"D": Color("70e000"),
	"C": Color("4cc9f0"),
	"B": Color("9d4edd"),
	"A": Color("ff9f1c"),
	"S": Color("ff3366"),
}

var stick_ui: TrickStickUI

var _money_label: Label
var _pool_label: Label
var _deliveries_label: Label
var _toast: Label
var _toast_tween: Tween
var _tier_badge: _TierPopBadge


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

	# Top center: toast notifications only (no combo clutter!).
	_toast = _label("", 20)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 44
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast)

	# Bottom-left: Trick Stick circle UI.
	stick_ui = TrickStickUI.new()
	root.add_child(stick_ui)
	var ui_size := stick_ui.get_panel_size()
	stick_ui.anchor_left = 0.0
	stick_ui.anchor_right = 0.0
	stick_ui.anchor_top = 1.0
	stick_ui.anchor_bottom = 1.0
	stick_ui.offset_left = 20.0
	stick_ui.offset_right = 20.0 + ui_size.x
	stick_ui.offset_top = -34.0 - ui_size.y
	stick_ui.offset_bottom = -34.0

	# Bottom-left (directly to the right of Trick Stick): exaggerated pop-out Combo Tier Letter!
	_tier_badge = _TierPopBadge.new()
	root.add_child(_tier_badge)
	var badge_size := Vector2(150.0, 150.0)
	var badge_left: float = 20.0 + ui_size.x + 14.0
	var stick_center_offset_y: float = -34.0 - ui_size.y + 30.0 + stick_ui.circle_radius
	_tier_badge.anchor_left = 0.0
	_tier_badge.anchor_right = 0.0
	_tier_badge.anchor_top = 1.0
	_tier_badge.anchor_bottom = 1.0
	_tier_badge.offset_left = badge_left
	_tier_badge.offset_right = badge_left + badge_size.x
	_tier_badge.offset_top = stick_center_offset_y - badge_size.y * 0.5
	_tier_badge.offset_bottom = stick_center_offset_y + badge_size.y * 0.5
	_tier_badge.setup_base_y(_tier_badge.offset_top, _tier_badge.offset_bottom)

	# Bottom-left underneath Trick Stick: minimal Tab / Esc hint only.
	var hint := _label("Tab: Kitchen / Skatepark   |   Esc: Free Cursor", 13, Color(1, 1, 1, 0.78))
	hint.anchor_left = 0.0
	hint.anchor_right = 0.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 20.0
	hint.offset_right = 380.0
	hint.offset_top = -28.0
	hint.offset_bottom = -6.0
	root.add_child(hint)

	OrderManager.money_changed.connect(set_money)
	set_pool(0, false)


func set_money(total: int) -> void:
	_money_label.text = "P %d" % total


func set_pool(pesos: int, carrying: bool) -> void:
	if carrying:
		_pool_label.text = "Banked trick tips: +P%d" % pesos
		_pool_label.add_theme_color_override("font_color", Color("8cff8c"))
	elif pesos > 0:
		_pool_label.text = "Trick tips: +P%d (saved for next bag)" % pesos
		_pool_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	else:
		_pool_label.text = "Carry a bag & deliver to cash in tricks"
		_pool_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))


func set_deliveries(text: String) -> void:
	_deliveries_label.text = text


func show_combo_tier(tier: String, trick_count: int) -> void:
	if _tier_badge:
		_tier_badge.set_tier(tier, TIER_COLORS.get(tier, Color.WHITE), trick_count)


func finish_combo_tier(bailed: bool) -> void:
	if _tier_badge:
		_tier_badge.finish(bailed)


func clear_combo() -> void:
	if _tier_badge:
		_tier_badge.clear_immediately()


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


# ---------------------------------------------------------------- Exaggerated Tier Pop Badge

class _TierPopBadge extends Control:
	const BADGE_SIZE := Vector2(150.0, 150.0)

	var burst_progress: float = 1.0:
		set(v):
			burst_progress = v
			queue_redraw()
	var glow_strength: float = 0.0:
		set(v):
			glow_strength = v
			queue_redraw()

	var _letter_label: Label
	var _current_tier: String = ""
	var _tier_color: Color = Color.WHITE
	var _last_trick_count: int = 0
	var _flip_sign: float = 1.0
	var _base_top: float = 0.0
	var _base_bottom: float = 0.0
	var _pop_tween: Tween
	var _burst_tween: Tween

	func _ready() -> void:
		custom_minimum_size = BADGE_SIZE
		size = BADGE_SIZE
		pivot_offset = BADGE_SIZE * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

		_letter_label = Label.new()
		_letter_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_letter_label.add_theme_font_override("font", COMBO_FONT)
		_letter_label.add_theme_font_size_override("font_size", 104)
		_letter_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_letter_label.add_theme_constant_override("outline_size", 15)
		_letter_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		_letter_label.add_theme_constant_override("shadow_offset_x", 5)
		_letter_label.add_theme_constant_override("shadow_offset_y", 6)
		_letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_letter_label)

	func setup_base_y(top_off: float, bot_off: float) -> void:
		_base_top = top_off
		_base_bottom = bot_off

	func set_tier(tier: String, color: Color, trick_count: int) -> void:
		if tier == "":
			_current_tier = ""
			_last_trick_count = trick_count
			visible = false
			return

		var tier_changed: bool = (tier != _current_tier)
		var trick_added: bool = (trick_count != _last_trick_count)
		_current_tier = tier
		_tier_color = color
		_last_trick_count = trick_count

		visible = true
		modulate = Color.WHITE
		_letter_label.text = tier
		_letter_label.add_theme_color_override("font_color", color)

		if tier_changed:
			_play_exaggerated_tier_pop(tier)
		elif trick_added:
			_play_trick_thump()

	func _play_exaggerated_tier_pop(tier: String) -> void:
		if _pop_tween:
			_pop_tween.kill()
		if _burst_tween:
			_burst_tween.kill()

		_flip_sign = -_flip_sign
		var peak_scale: float = 2.45
		if tier == "A":
			peak_scale = 2.65
		elif tier == "S":
			peak_scale = 2.95

		# Instant exaggerated impact state: huge scale, dramatic whip-angle, upward punch & bright flash!
		scale = Vector2(peak_scale, peak_scale)
		rotation_degrees = 22.0 * _flip_sign
		offset_top = _base_top - 22.0
		offset_bottom = _base_bottom - 22.0
		_letter_label.self_modulate = Color(2.4, 2.4, 2.4, 1.0)
		glow_strength = 1.0
		burst_progress = 0.0

		_pop_tween = create_tween().set_parallel(true)
		_pop_tween.tween_property(self, "scale", Vector2.ONE, 0.58).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_pop_tween.tween_property(self, "rotation_degrees", -6.0, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pop_tween.tween_property(self, "offset_top", _base_top, 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_pop_tween.tween_property(self, "offset_bottom", _base_bottom, 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_pop_tween.tween_property(_letter_label, "self_modulate", Color.WHITE, 0.28)
		_pop_tween.tween_property(self, "glow_strength", 0.45, 0.55)

		_burst_tween = create_tween()
		_burst_tween.tween_property(self, "burst_progress", 1.0, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _play_trick_thump() -> void:
		if _pop_tween and _pop_tween.is_running():
			return
		scale = Vector2(1.26, 1.26)
		rotation_degrees = -6.0 + randf_range(-5.0, 5.0)
		_pop_tween = create_tween().set_parallel(true)
		_pop_tween.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pop_tween.tween_property(self, "rotation_degrees", -6.0, 0.24)

	func finish(bailed: bool) -> void:
		if not visible:
			_current_tier = ""
			_last_trick_count = 0
			return
		_current_tier = ""
		_last_trick_count = 0
		if _pop_tween:
			_pop_tween.kill()

		_pop_tween = create_tween()
		if bailed:
			_letter_label.add_theme_color_override("font_color", Color("ff4d6d"))
			glow_strength = 0.0
			_pop_tween.tween_property(self, "rotation_degrees", 24.0, 0.08)
			_pop_tween.tween_property(self, "rotation_degrees", -20.0, 0.08)
			_pop_tween.set_parallel(true)
			_pop_tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			_pop_tween.tween_property(self, "modulate:a", 0.0, 0.28)
		else:
			scale = Vector2(1.42, 1.42)
			_pop_tween.set_parallel(true)
			_pop_tween.tween_property(self, "scale", Vector2(0.85, 0.85), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			_pop_tween.tween_property(self, "modulate:a", 0.0, 0.55)
		_pop_tween.chain().tween_callback(func(): visible = false)

	func clear_immediately() -> void:
		if _pop_tween:
			_pop_tween.kill()
		if _burst_tween:
			_burst_tween.kill()
		_current_tier = ""
		_last_trick_count = 0
		visible = false

	func _draw() -> void:
		var c := BADGE_SIZE * 0.5

		# Persistent soft neon aura behind the active tier letter.
		if glow_strength > 0.01:
			draw_circle(c, 48.0, Color(_tier_color.r, _tier_color.g, _tier_color.b, 0.24 * glow_strength))
			draw_circle(c, 32.0, Color(_tier_color.r, _tier_color.g, _tier_color.b, 0.36 * glow_strength))

		# Exaggerated comic starburst + shockwave ring when ranking up a tier!
		if burst_progress < 0.99:
			var life: float = 1.0 - burst_progress
			var ring_r: float = lerpf(24.0, 88.0, burst_progress)
			draw_arc(c, ring_r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, life * 0.85), 5.0 * life + 1.5, true)
			draw_arc(c, ring_r * 0.82, 0.0, TAU, 48, Color(_tier_color.r, _tier_color.g, _tier_color.b, life * 0.9), 4.0 * life + 1.0, true)

			var spikes: int = 12
			var inner_r: float = lerpf(16.0, 44.0, burst_progress)
			var outer_r: float = lerpf(48.0, 102.0, burst_progress)
			for i in spikes:
				var ang: float = float(i) * (TAU / float(spikes)) + burst_progress * 0.35
				var dir := Vector2.from_angle(ang)
				var perp := Vector2(-dir.y, dir.x) * (5.5 * life)
				var pts := PackedVector2Array([
					c + dir * inner_r + perp,
					c + dir * inner_r - perp,
					c + dir * outer_r,
				])
				var col := Color.WHITE if i % 2 == 0 else _tier_color.lightened(0.25)
				col.a = life * 0.92
				draw_colored_polygon(pts, col)
