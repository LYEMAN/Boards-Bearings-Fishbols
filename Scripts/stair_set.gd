@tool
class_name StairSet
extends StaticBody2D
## A concrete stair set + raised deck for skatepark verticality.
## Supports short plazas, sheer drop-off ledges (steps = 0), and long elevated upper streets.
## Visually draws crisp steps and architectural retaining-wall bays while using a smooth
## sloped collision polygon so the skater rolls cleanly up and down.
## Origin = bottom-left base (surface level).

@export var height: float = 64.0:
	set(value):
		height = maxf(value, 16.0)
		_rebuild()

@export var deck_length: float = 220.0:
	set(value):
		deck_length = maxf(value, 40.0)
		_rebuild()

## Steps climbing up on the left side (0 = vertical ledge drop).
@export var left_steps: int = 4:
	set(value):
		left_steps = maxi(value, 0)
		_rebuild()

## Steps going down on the right side (0 = vertical ledge drop).
@export var right_steps: int = 4:
	set(value):
		right_steps = maxi(value, 0)
		_rebuild()

@export var step_depth: float = 34.0:
	set(value):
		step_depth = maxf(value, 18.0)
		_rebuild()

@export var concrete_color: Color = Color("8c939a"):
	set(value):
		concrete_color = value
		queue_redraw()

@export var top_color: Color = Color("cfd6dc"):
	set(value):
		top_color = value
		queue_redraw()

var _collider: CollisionPolygon2D


func _ready() -> void:
	z_index = -1
	_rebuild()


func get_left_run() -> float:
	return float(left_steps) * step_depth


func get_right_run() -> float:
	return float(right_steps) * step_depth


func get_total_width() -> float:
	return get_left_run() + deck_length + get_right_run()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _collider == null:
		_collider = get_node_or_null("StairCollider") as CollisionPolygon2D
		if _collider == null:
			_collider = CollisionPolygon2D.new()
			_collider.name = "StairCollider"
			add_child(_collider)

	var left_run := get_left_run()
	var right_run := get_right_run()
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, 0.0))
	if left_steps > 0:
		pts.append(Vector2(left_run, -height))
	else:
		pts.append(Vector2(0.0, -height))
	pts.append(Vector2(left_run + deck_length, -height))
	if right_steps > 0:
		pts.append(Vector2(left_run + deck_length + right_run, 0.0))
	else:
		pts.append(Vector2(left_run + deck_length, 0.0))
	_collider.polygon = pts
	queue_redraw()


func _draw() -> void:
	var left_run := get_left_run()
	var right_run := get_right_run()
	var total_w := get_total_width()
	var shadow := concrete_color.darkened(0.22)
	var recess := concrete_color.darkened(0.11)
	var outline := concrete_color.darkened(0.45)

	# Main center deck retaining wall.
	var deck_rect := Rect2(left_run, -height, deck_length, height)
	draw_rect(deck_rect, concrete_color)

	# Architectural recessed wall bays & pilasters along long elevated decks.
	if deck_length >= 200.0 and height >= 36.0:
		var bay_span: float = 190.0
		var bays: int = maxi(1, int(deck_length / bay_span))
		var actual_span: float = deck_length / float(bays)
		var pad_x: float = 14.0
		var pad_top: float = 14.0
		var pad_bot: float = 8.0
		var panel_h: float = height - pad_top - pad_bot
		if panel_h > 10.0 and actual_span > pad_x * 2.5:
			for b in bays:
				var bx: float = left_run + float(b) * actual_span + pad_x
				var bw: float = actual_span - pad_x * 2.0
				draw_rect(Rect2(bx, -height + pad_top, bw, panel_h), recess)
				draw_rect(Rect2(bx, -height + pad_top, bw, 3.0), shadow)
				draw_rect(Rect2(bx, -height + pad_top, bw, panel_h), outline.lerp(concrete_color, 0.5), false, 1.0)

	# Top coping slab & under-lip shadow.
	draw_rect(Rect2(left_run, -height, deck_length, 7.0), top_color)
	draw_rect(Rect2(left_run, -height + 7.0, deck_length, 4.0), shadow)
	draw_line(Vector2(left_run, -height), Vector2(left_run + deck_length, -height), outline, 2.0)
	if left_steps == 0:
		draw_line(Vector2(0.0, -height), Vector2(0.0, 0.0), outline, 2.0)
	if right_steps == 0:
		draw_line(Vector2(left_run + deck_length, -height), Vector2(left_run + deck_length, 0.0), outline, 2.0)

	# Left ascending steps.
	if left_steps > 0:
		var step_h: float = height / float(left_steps)
		for i in left_steps:
			var sx: float = float(i) * step_depth
			var sy: float = -float(i + 1) * step_h
			var rect := Rect2(sx, sy, step_depth + 1.0, -sy)
			draw_rect(rect, concrete_color)
			draw_rect(Rect2(sx, sy, step_depth, 4.0), top_color)
			draw_rect(Rect2(sx, sy + 4.0, 4.0, step_h - 4.0), shadow)
			draw_line(Vector2(sx, sy), Vector2(sx + step_depth, sy), outline, 1.5)
			draw_line(Vector2(sx, sy), Vector2(sx, sy + step_h), outline, 1.5)

	# Right descending steps.
	if right_steps > 0:
		var step_h: float = height / float(right_steps)
		var start_x: float = left_run + deck_length
		for i in right_steps:
			var sx: float = start_x + float(i) * step_depth
			var sy: float = -float(right_steps - i) * step_h
			var rect := Rect2(sx, sy, step_depth, -sy)
			draw_rect(rect, concrete_color)
			draw_rect(Rect2(sx, sy, step_depth, 4.0), top_color)
			draw_rect(Rect2(sx + step_depth - 4.0, sy + 4.0, 4.0, step_h - 4.0), shadow)
			draw_line(Vector2(sx, sy), Vector2(sx + step_depth, sy), outline, 1.5)
			draw_line(Vector2(sx + step_depth, sy), Vector2(sx + step_depth, sy + step_h), outline, 1.5)

	# Base line.
	draw_line(Vector2(0.0, 0.0), Vector2(total_w, 0.0), outline, 2.0)
