@tool
class_name GrindRail
extends Node2D
## A grindable rail in the background. Has no solid collision so the skater can
## roll past it on the ground and lock onto the bar when jumping/falling onto it.
## Supports both flat rails (end_height < 0) and sloped stair handrails.
## Origin = bottom-left base of the rail.

## Horizontal length of the rail.
@export var length: float = 240.0:
	set(value):
		length = maxf(value, 32.0)
		queue_redraw()

## Height of the left end of the bar above this node's y = 0.
@export var height: float = 44.0:
	set(value):
		height = maxf(value, 12.0)
		queue_redraw()

## Vertical offset of the right end relative to the left end (0 = flat, positive = slopes down to the right).
@export var end_y_offset: float = 0.0:
	set(value):
		end_y_offset = value
		queue_redraw()

## Local y where the right-most support post meets the ground/stairs (0 = flat ground).
@export var right_base_y: float = 0.0:
	set(value):
		right_base_y = value
		queue_redraw()

@export var thickness: float = 6.0:
	set(value):
		thickness = maxf(value, 2.0)
		queue_redraw()

@export var rail_color: Color = Color("d9e2ec"):
	set(value):
		rail_color = value
		queue_redraw()

@export var post_color: Color = Color("627d98"):
	set(value):
		post_color = value
		queue_redraw()


func _ready() -> void:
	z_index = -1
	if not Engine.is_editor_hint():
		add_to_group("grind_rail")


func get_start_local() -> Vector2:
	return Vector2(0.0, -height)


func get_end_local() -> Vector2:
	return Vector2(length, -height + end_y_offset)


func get_start_global() -> Vector2:
	return to_global(get_start_local())


func get_end_global() -> Vector2:
	return to_global(get_end_local())


func get_slope_angle() -> float:
	return (get_end_local() - get_start_local()).angle()


func contains_global_x(gx: float, margin: float = 0.0) -> bool:
	var a := get_start_global()
	var b := get_end_global()
	var min_x: float = minf(a.x, b.x) - margin
	var max_x: float = maxf(a.x, b.x) + margin
	return gx >= min_x and gx <= max_x


func get_y_at_global_x(gx: float) -> float:
	var a := get_start_global()
	var b := get_end_global()
	if is_equal_approx(a.x, b.x):
		return minf(a.y, b.y)
	var t: float = clampf((gx - a.x) / (b.x - a.x), 0.0, 1.0)
	return lerpf(a.y, b.y, t)


func _draw() -> void:
	var start := get_start_local()
	var finish := get_end_local()
	var post_inset: float = minf(18.0, length * 0.2)
	var post_count: int = maxi(2, int(length / 180.0) + 1)

	# Vertical support posts.
	for i in post_count:
		var t: float = float(i) / float(post_count - 1)
		var px: float = lerpf(post_inset, length - post_inset, t)
		var rail_t: float = px / length
		var top_y: float = lerpf(start.y, finish.y, rail_t)
		var base_y: float = lerpf(0.0, right_base_y, rail_t)
		draw_line(Vector2(px, top_y), Vector2(px, base_y), post_color, maxf(thickness * 0.75, 3.0))
		# Small base plate.
		draw_rect(Rect2(px - 6.0, base_y - 3.0, 12.0, 3.0), post_color.darkened(0.25))

	# Main rail bar (dark outline + metallic top highlight).
	draw_line(start, finish, rail_color.darkened(0.45), thickness + 3.0, true)
	draw_line(start, finish, rail_color, thickness, true)
	draw_line(start + Vector2(0.0, -thickness * 0.25), finish + Vector2(0.0, -thickness * 0.25), Color(1, 1, 1, 0.65), maxf(thickness * 0.3, 1.5), true)
	# Rounded end caps.
	draw_circle(start, thickness * 0.5, rail_color)
	draw_circle(finish, thickness * 0.5, rail_color)
