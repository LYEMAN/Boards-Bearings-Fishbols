@tool
class_name IngredientContainer
extends Node2D
## A container of raw ingredients on the shelf. Click-and-drag from it to pull out a raw piece.
## Locked (not yet unlocked in the campaign) containers are greyed out with the unlock day shown.
## Placeholder art is drawn in _draw(); swap it for a Sprite2D later if you like.
## Origin = bottom-centre of the container.

@export var food: FoodData:
	set(value):
		food = value
		queue_redraw()
## Width / height of the container body.
@export var size: Vector2 = Vector2(220, 110):
	set(value):
		size = value
		queue_redraw()
## Show locked containers (greyed out) instead of hiding them.
@export var show_when_locked: bool = true

var hovered: bool = false:
	set(value):
		if hovered != value:
			hovered = value
			queue_redraw()

var _shake: float = 0.0
## Fixed pseudo-random layout for the pieces poking out of the top.
var _piece_offsets: Array[Vector3] = []


func _ready() -> void:
	add_to_group(&"ingredient_container")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in 6:
		_piece_offsets.append(Vector3(rng.randf_range(-0.38, 0.38), rng.randf_range(0.0, 1.0), rng.randf_range(-0.5, 0.5)))
	refresh()


func refresh() -> void:
	if not Engine.is_editor_hint():
		visible = show_when_locked or is_unlocked()
	queue_redraw()


func is_unlocked() -> bool:
	if food == null:
		return false
	if Engine.is_editor_hint():
		return true
	return FoodCatalog.is_unlocked(food)


func contains_point(global_point: Vector2) -> bool:
	if not visible or food == null:
		return false
	var p: Vector2 = to_local(global_point)
	return Rect2(-size.x * 0.5, -size.y - 60, size.x, size.y + 60).has_point(p)


## Little "nope" wiggle when clicking a locked container.
func shake() -> void:
	var tw := create_tween()
	tw.tween_method(_set_shake, 1.0, 0.0, 0.35)


func _set_shake(v: float) -> void:
	_shake = v
	queue_redraw()


func _draw() -> void:
	if food == null:
		return
	var locked: bool = not is_unlocked()
	var offset := Vector2(sin(_shake * 40.0) * 8.0 * _shake, 0)
	draw_set_transform(offset)

	var tint := Color(0.35, 0.35, 0.35) if locked else Color.WHITE
	var body: Color = food.container_color * tint
	var w: float = size.x
	var h: float = size.y

	if hovered and not locked:
		draw_rect(Rect2(-w * 0.5 - 10, -h - 70, w + 20, h + 80), Color(1, 1, 1, 0.12))

	_draw_back(body, w, h)
	_draw_pieces(tint, w, h)
	_draw_front(body, w, h)

	# Name / lock label under the container.
	var font: Font = ThemeDB.fallback_font
	var text: String = food.display_name if not locked else "Unlocks Day %d" % food.unlock_day
	var pos := Vector2(-w * 0.5 - 40, 34)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w + 80, 26, 6, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w + 80, 26, Color.WHITE if not locked else Color(1, 0.8, 0.5))
	if locked:
		_draw_padlock(Vector2(0, -h * 0.5))
	draw_set_transform(Vector2.ZERO)


func _draw_back(body: Color, w: float, h: float) -> void:
	match food.container_style:
		FoodData.ContainerStyle.BASKET, FoodData.ContainerStyle.CRATE, FoodData.ContainerStyle.TUB:
			# Inside back wall, slightly darker.
			draw_rect(Rect2(-w * 0.5, -h, w, h * 0.35), body.darkened(0.45))


func _draw_front(body: Color, w: float, h: float) -> void:
	match food.container_style:
		FoodData.ContainerStyle.TUB:
			# Plastic tub: trapezoid with a rim.
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w * 0.5, -h * 0.75), Vector2(w * 0.5, -h * 0.75),
				Vector2(w * 0.42, 0), Vector2(-w * 0.42, 0)]), body)
			draw_rect(Rect2(-w * 0.53, -h * 0.8, w * 1.06, 14), body.lightened(0.25))
		FoodData.ContainerStyle.BOWL:
			# Round bowl: half ellipse + foot.
			var pts := PackedVector2Array()
			for i in 17:
				var a: float = PI * float(i) / 16.0
				pts.append(Vector2(cos(a) * w * 0.5, -h * 0.7 + sin(a) * h * 0.62))
			draw_colored_polygon(pts, body)
			draw_rect(Rect2(-w * 0.18, -h * 0.1, w * 0.36, h * 0.1), body.darkened(0.25))
			draw_line(Vector2(-w * 0.5, -h * 0.7), Vector2(w * 0.5, -h * 0.7), body.lightened(0.3), 8)
		FoodData.ContainerStyle.TRAY:
			# Shallow steel tray.
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w * 0.5, -h * 0.3), Vector2(w * 0.5, -h * 0.3),
				Vector2(w * 0.44, 0), Vector2(-w * 0.44, 0)]), body)
			draw_line(Vector2(-w * 0.5, -h * 0.3), Vector2(w * 0.5, -h * 0.3), body.lightened(0.4), 6)
		FoodData.ContainerStyle.PLATE:
			# Flat plate on a small stand.
			draw_rect(Rect2(-w * 0.5, -h * 0.2, w, h * 0.12), body)
			draw_rect(Rect2(-w * 0.3, -h * 0.08, w * 0.6, h * 0.08), body.darkened(0.3))
		FoodData.ContainerStyle.BASKET:
			# Woven bamboo basket (bilao-style).
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w * 0.5, -h * 0.65), Vector2(w * 0.5, -h * 0.65),
				Vector2(w * 0.4, 0), Vector2(-w * 0.4, 0)]), body)
			for i in 6:
				var x: float = lerpf(-w * 0.45, w * 0.45, float(i) / 5.0)
				draw_line(Vector2(x, -h * 0.65), Vector2(x * 0.85, 0), body.darkened(0.3), 4)
			for j in 3:
				var y: float = lerpf(-h * 0.55, -h * 0.12, float(j) / 2.0)
				draw_line(Vector2(-w * 0.47, y), Vector2(w * 0.47, y), body.lightened(0.2), 4)
		FoodData.ContainerStyle.CRATE:
			# Wooden crate with planks.
			draw_rect(Rect2(-w * 0.5, -h * 0.7, w, h * 0.7), body)
			for j in 3:
				var y: float = -h * 0.7 + j * h * 0.235
				draw_line(Vector2(-w * 0.5, y), Vector2(w * 0.5, y), body.darkened(0.35), 4)
			draw_line(Vector2(-w * 0.45, -h * 0.7), Vector2(-w * 0.45, 0), body.darkened(0.35), 6)
			draw_line(Vector2(w * 0.45, -h * 0.7), Vector2(w * 0.45, 0), body.darkened(0.35), 6)


## Raw pieces heaped in the container, drawn between the back and front so they sit inside.
func _draw_pieces(tint: Color, w: float, h: float) -> void:
	if food.texture == null:
		return
	var rim_y: float = -h * 0.7
	match food.container_style:
		FoodData.ContainerStyle.TRAY:
			rim_y = -h * 0.3
		FoodData.ContainerStyle.PLATE:
			rim_y = -h * 0.2
	# Texture has padding around the food; scale so the visible part matches food.size.
	var tex_scale: Vector2 = food.size / food.texture_visible_size
	var tex_size: Vector2 = food.texture.get_size() * tex_scale
	for o in _piece_offsets:
		var center := Vector2(o.x * w, rim_y - o.y * food.size.y * 0.6)
		draw_set_transform(center + Vector2(sin(_shake * 40.0) * 8.0 * _shake, 0), o.z, Vector2.ONE)
		draw_texture_rect(food.texture, Rect2(-tex_size * 0.5 + food.texture_offset * tex_scale, tex_size), false, food.raw_color * tint)
	draw_set_transform(Vector2(sin(_shake * 40.0) * 8.0 * _shake, 0))


func _draw_padlock(center: Vector2) -> void:
	draw_arc(center + Vector2(0, -18), 18, PI, TAU, 16, Color("d9d9d9"), 7)
	draw_rect(Rect2(center + Vector2(-26, -18), Vector2(52, 40)), Color("f2c94c"))
	draw_circle(center + Vector2(0, 0), 6, Color("4a3b00"))
