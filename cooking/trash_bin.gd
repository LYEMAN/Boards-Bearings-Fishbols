class_name TrashBin
extends Node2D
## Drop burnt or unwanted food here to throw it away. Origin = bottom-centre.

@export var size: Vector2 = Vector2(200, 220)


func _ready() -> void:
	var label := Label.new()
	label.text = "TRASH"
	label.add_theme_font_size_override("font_size", 36)
	label.position = Vector2(-size.x * 0.5 + 40, -size.y * 0.6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func contains_point(global_point: Vector2) -> bool:
	var p: Vector2 = to_local(global_point)
	return Rect2(-size.x * 0.5 - 20, -size.y - 80, size.x + 40, size.y + 80).has_point(p)


func _draw() -> void:
	var body := PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y), Vector2(size.x * 0.5, -size.y),
		Vector2(size.x * 0.4, 0), Vector2(-size.x * 0.4, 0),
	])
	draw_colored_polygon(body, Color("5c6770"))
	draw_rect(Rect2(-size.x * 0.5 - 10, -size.y - 18, size.x + 20, 18), Color("3d454c"))
