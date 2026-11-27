class_name TrickStickUI
extends Control
## Bottom-left virtual analog stick circle UI with a visible virtual cursor and glowing light trail.
## Lets the player see their mouse movements inside the circle instead of a free screen cursor.

@export var circle_radius: float = 74.0
@export var trail_lifetime: float = 0.42

var stick_pos: Vector2 = Vector2.ZERO

var _trail: Array[Dictionary] = []        # { "p": Vector2 (local px), "age": float }
var _echo_pts := PackedVector2Array()     # Normalized [-1..1] points of last matched trick
var _echo_timer: float = 0.0
var _echo_duration: float = 0.60
var _title_label: Label
var _title_reset_timer: float = 0.0


func get_panel_size() -> Vector2:
	return Vector2(circle_radius * 2.0 + 28.0, circle_radius * 2.0 + 52.0)


func _ready() -> void:
	var psize := get_panel_size()
	custom_minimum_size = psize
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_title_label = Label.new()
	_title_label.text = "TRICK STICK"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0.0, 2.0)
	_title_label.size = Vector2(psize.x, 22.0)
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.95))
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_label.add_theme_constant_override("outline_size", 5)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)


func _circle_center() -> Vector2:
	var psize := get_panel_size()
	return Vector2(psize.x * 0.5, 30.0 + circle_radius)


func update_stick(norm_pos: Vector2, delta: float) -> void:
	stick_pos = norm_pos.limit_length(1.0)
	var center := _circle_center()
	var px_pos := center + stick_pos * (circle_radius - 7.0)

	# Age & prune existing trail points.
	var i: int = 0
	while i < _trail.size():
		_trail[i]["age"] = float(_trail[i]["age"]) + delta
		if float(_trail[i]["age"]) >= trail_lifetime:
			_trail.remove_at(i)
		else:
			i += 1

	# Append new trail points (interpolating fast flicks so curved arcs stay smooth).
	if _trail.is_empty():
		if stick_pos.length() > 0.02:
			_trail.append({ "p": px_pos, "age": 0.0 })
	else:
		var prev_p: Vector2 = _trail.back()["p"]
		var dist: float = prev_p.distance_to(px_pos)
		if dist >= 1.5:
			var steps: int = mini(int(dist / 4.5) + 1, 10)
			for s in range(1, steps + 1):
				var interp := prev_p.lerp(px_pos, float(s) / float(steps))
				_trail.append({ "p": interp, "age": 0.0 })

	if _echo_timer > 0.0:
		_echo_timer = maxf(_echo_timer - delta, 0.0)

	if _title_reset_timer > 0.0:
		_title_reset_timer -= delta
		if _title_reset_timer <= 0.0 and _title_label:
			_title_label.text = "TRICK STICK"
			_title_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.95))

	queue_redraw()


func flash_recognized(trick_name: String, stroke_norm_points: PackedVector2Array = PackedVector2Array()) -> void:
	_echo_pts = stroke_norm_points.duplicate()
	_echo_timer = _echo_duration
	if _title_label:
		_title_label.text = trick_name.to_upper()
		_title_label.add_theme_color_override("font_color", Color("ffd166"))
		_title_reset_timer = 1.1
	queue_redraw()


func _draw() -> void:
	var c := _circle_center()
	var r := circle_radius
	var inner_r := r - 7.0

	# Drop shadow + dark matte circle background so the trail and cursor pop against any scene.
	draw_circle(c + Vector2(0.0, 4.0), r + 5.0, Color(0.0, 0.0, 0.0, 0.55))
	draw_circle(c, r + 2.0, Color(0.14, 0.18, 0.24, 0.95))
	draw_circle(c, r, Color(0.04, 0.05, 0.08, 0.94))

	# Center neutral ring & subtle crosshairs.
	draw_arc(c, inner_r * 0.20, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.14), 1.5, true)
	draw_line(c + Vector2(-inner_r * 0.88, 0.0), c + Vector2(inner_r * 0.88, 0.0), Color(1.0, 1.0, 1.0, 0.07), 1.0)
	draw_line(c + Vector2(0.0, -inner_r * 0.88), c + Vector2(0.0, inner_r * 0.88), Color(1.0, 1.0, 1.0, 0.07), 1.0)

	# 8 directional rim ticks (cardinals & diagonals).
	for k in 8:
		var ang: float = float(k) * (TAU / 8.0)
		var dir := Vector2.from_angle(ang)
		var tick_len: float = 7.0 if k % 2 == 0 else 4.5
		var col := Color(1.0, 1.0, 1.0, 0.30 if k % 2 == 0 else 0.16)
		draw_line(c + dir * (r - tick_len - 2.0), c + dir * (r - 2.0), col, 1.6, true)

	# Outer rim border (flashes gold when a trick gesture is recognized).
	var flash_ratio: float = clampf(_echo_timer / _echo_duration, 0.0, 1.0)
	var rim_col := Color(0.58, 0.76, 0.94, 0.92).lerp(Color("ffd166"), flash_ratio)
	draw_arc(c, r, 0.0, TAU, 64, rim_col, 2.8 + flash_ratio * 1.6, true)

	# Golden echo of the just-matched gesture curve.
	if flash_ratio > 0.0 and _echo_pts.size() >= 2:
		for i in range(1, _echo_pts.size()):
			var a := c + _echo_pts[i - 1].limit_length(1.0) * inner_r
			var b := c + _echo_pts[i].limit_length(1.0) * inner_r
			draw_line(a, b, Color(1.0, 0.84, 0.35, flash_ratio * 0.60), 5.5, true)

	# Glowing multi-layer light trail following mouse motion.
	if _trail.size() >= 2:
		for i in range(1, _trail.size()):
			var p0: Vector2 = _trail[i - 1]["p"]
			var p1: Vector2 = _trail[i]["p"]
			var age: float = float(_trail[i]["age"])
			var life: float = pow(clampf(1.0 - age / trail_lifetime, 0.0, 1.0), 1.25)
			if life <= 0.01:
				continue
			draw_line(p0, p1, Color(0.20, 0.80, 1.0, life * 0.30), 15.0 * life + 2.0, true)
			draw_line(p0, p1, Color(0.55, 0.93, 1.0, life * 0.72), 7.0 * life + 1.4, true)
			draw_line(p0, p1, Color(1.0, 1.0, 1.0, life * 0.96), 3.0 * life + 0.9, true)
