@tool
class_name IngredientShelf
extends Node2D
## A wooden shelf that holds IngredientContainers. If `auto_fill` is on, it creates one container
## per food in FoodCatalog and lays them out in a grid; otherwise it just arranges the
## IngredientContainer children you placed yourself (so artists can hand-place them).
## Origin = top-left of the shelf.

@export var auto_fill: bool = true
@export var columns: int = 2
@export var cell_size: Vector2 = Vector2(260, 230)
@export var container_size: Vector2 = Vector2(220, 110)
@export var wood_color: Color = Color("5a3a1e")
@export_tool_button("Rebuild Shelf") var rebuild_button: Callable = rebuild


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	if auto_fill:
		for child in get_children():
			if child is IngredientContainer:
				remove_child(child)
				child.queue_free()
		for food in FoodCatalog.all():
			var c := IngredientContainer.new()
			c.name = "%sContainer" % str(food.id).to_pascal_case()
			c.food = food
			c.size = container_size
			add_child(c)
	_layout()
	queue_redraw()


func get_containers() -> Array[IngredientContainer]:
	var result: Array[IngredientContainer] = []
	for child in get_children():
		if child is IngredientContainer:
			result.append(child)
	return result


func _layout() -> void:
	var i: int = 0
	for c in get_containers():
		var col: int = i % columns
		var row: int = i / columns
		# Container origin is its bottom-centre; leave room for its label below.
		c.position = Vector2((col + 0.5) * cell_size.x, (row + 1) * cell_size.y - 50)
		i += 1


func _rows() -> int:
	return ceili(float(get_containers().size()) / maxi(columns, 1))


func _draw() -> void:
	var rows: int = maxi(_rows(), 1)
	var w: float = columns * cell_size.x
	var h: float = rows * cell_size.y
	# Back panel + side posts + one plank under each row.
	draw_rect(Rect2(0, 0, w, h), wood_color.darkened(0.35))
	draw_rect(Rect2(-14, -10, 14, h + 20), wood_color)
	draw_rect(Rect2(w, -10, 14, h + 20), wood_color)
	for r in rows:
		var y: float = (r + 1) * cell_size.y - 50
		draw_rect(Rect2(-14, y, w + 28, 14), wood_color.lightened(0.15))
