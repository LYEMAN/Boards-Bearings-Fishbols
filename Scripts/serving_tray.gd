class_name ServingTray
extends Node2D
## Drop cooked food here. Pieces on the tray stop cooking and wait to be bagged for an order.
## Origin = bottom-centre of the tray.

signal contents_changed

@export var size: Vector2 = Vector2(620, 40)
## Extra height above the tray that still counts as "dropping onto the tray".
@export var drop_height: float = 260.0
@export var max_rows: int = 4
@export var gap: float = 8.0

var items: Array[FriedItem] = []
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.text = "SERVING TRAY"
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_label.position = Vector2(-size.x * 0.5 + 16, -size.y + 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func contains_point(global_point: Vector2) -> bool:
	var p: Vector2 = to_local(global_point)
	return Rect2(-size.x * 0.5, -size.y - drop_height, size.x, size.y + drop_height + 10).has_point(p)


func add_item(item: FriedItem) -> bool:
	if item in items:
		return true
	items.append(item)
	item.set_plated(true)
	var on_exiting := _on_item_tree_exiting.bind(item)
	if not item.tree_exiting.is_connected(on_exiting):
		item.tree_exiting.connect(on_exiting)
	if not _layout():
		# No room left: refuse it.
		items.erase(item)
		if item.tree_exiting.is_connected(on_exiting):
			item.tree_exiting.disconnect(on_exiting)
		item.set_plated(false)
		_layout()
		return false
	contents_changed.emit()
	return true


func remove_item(item: FriedItem) -> void:
	if item not in items:
		return
	items.erase(item)
	var on_exiting := _on_item_tree_exiting.bind(item)
	if item.tree_exiting.is_connected(on_exiting):
		item.tree_exiting.disconnect(on_exiting)
	item.set_plated(false)
	_layout()
	contents_changed.emit()


func count(food_id: StringName) -> int:
	var n: int = 0
	for item in items:
		if item.food.id == food_id:
			n += 1
	return n


## Removes `qty` pieces of a food (best quality first) and returns them. Empty if not enough.
func take_items(food_id: StringName, qty: int) -> Array[FriedItem]:
	var matching: Array[FriedItem] = []
	for item in items:
		if item.food.id == food_id:
			matching.append(item)
	if matching.size() < qty:
		return []
	matching.sort_custom(func(a: FriedItem, b: FriedItem): return a.get_quality() > b.get_quality())
	var taken: Array[FriedItem] = matching.slice(0, qty)
	for item in taken:
		remove_item(item)
	return taken


## Arranges pieces left-to-right in rows. Returns false if they don't fit.
func _layout() -> bool:
	var left: float = -size.x * 0.5 + 20.0
	var right: float = size.x * 0.5 - 20.0
	var x: float = left
	var row_y: float = -size.y
	var row_h: float = 0.0
	var rows: int = 1
	for item in items:
		var w: float = item.food.size.x
		var h: float = item.food.size.y
		if x + w > right and x > left:
			x = left
			row_y -= row_h + gap
			row_h = 0.0
			rows += 1
			if rows > max_rows:
				return false
		item.global_rotation = 0.0
		item.global_position = to_global(Vector2(x + w * 0.5, row_y - h * 0.5))
		x += w + gap
		row_h = maxf(row_h, h)
	return true


func _on_item_tree_exiting(item: FriedItem) -> void:
	items.erase(item)
	contents_changed.emit()


func _draw() -> void:
	var r := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	# Banana-leaf lined tray.
	draw_rect(r.grow(6), Color("6b4a2b"))
	draw_rect(r, Color("3f8f3a"))
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color("2f6f2b"), 4)
	# Faint drop zone hint.
	draw_rect(Rect2(r.position.x, -size.y - drop_height, size.x, drop_height), Color(1, 1, 1, 0.04))
