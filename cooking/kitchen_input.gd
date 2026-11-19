class_name KitchenInput
extends Node2D
## Mouse controls for the cooking station.
##   Left-drag a piece        -> carry it (drop in the wok, on the tray, or in the trash)
##   Left-drag empty space    -> stir with the skimmer (pushes food around)
##   Right-click a piece      -> flip it
##   Ingredient buttons (HUD) -> call start_drag_new(food) to pull a raw piece out of its bin

signal item_spawned(item: FriedItem)

const FRIED_ITEM_SCENE: PackedScene = preload("res://cooking/fried_item.tscn")

@export var item_parent: Node2D
@export var tray: ServingTray
@export var trash: TrashBin
@export var stirrer: Stirrer
## How close (world px) the mouse has to be to grab a piece.
@export var pick_radius: float = 14.0

var held: FriedItem = null
var hovered: FriedItem = null
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 50  # draw hover info above everything in the world
	if item_parent == null:
		item_parent = get_parent()


func spawn_food(food: FoodData, at: Vector2) -> FriedItem:
	var item: FriedItem = FRIED_ITEM_SCENE.instantiate()
	item.food = food
	item_parent.add_child(item)
	item.global_position = at
	item_spawned.emit(item)
	return item


## Spawns a raw piece under the mouse and starts carrying it.
func start_drag_new(food: FoodData) -> void:
	if held:
		_release_held()
	_grab(spawn_food(food, get_global_mouse_position()))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse: Vector2 = get_global_mouse_position()
		var item := _item_at(mouse)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if item:
				_grab(item)
			elif stirrer:
				stirrer.start(mouse)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and item:
			item.flip()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Releases are caught in _input so they work even when the drag started on a HUD button.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if held:
			_release_held()
		if stirrer and stirrer.active:
			stirrer.stop()


func _physics_process(_delta: float) -> void:
	var mouse: Vector2 = get_global_mouse_position()
	if held and not is_instance_valid(held):
		held = null
	if held:
		held.hold_target = mouse
	if stirrer and stirrer.active:
		stirrer.target = mouse
	var new_hover: FriedItem = held if held else _item_at(mouse)
	if new_hover != hovered:
		hovered = new_hover
	queue_redraw()


func _grab(item: FriedItem) -> void:
	if item.is_plated and tray:
		tray.remove_item(item)
	held = item
	item.hold()


func _release_held() -> void:
	var item := held
	held = null
	if not is_instance_valid(item):
		return
	item.release()
	var mouse: Vector2 = get_global_mouse_position()
	if trash and trash.contains_point(mouse):
		item.queue_free()
	elif tray and tray.contains_point(mouse):
		tray.add_item(item)


func _item_at(pos: Vector2) -> FriedItem:
	var shape := CircleShape2D.new()
	shape.radius = pick_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var best: FriedItem = null
	var best_dist: float = INF
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var body = hit.collider
		if body is FriedItem and not body.is_queued_for_deletion():
			var d: float = body.global_position.distance_squared_to(pos)
			if d < best_dist:
				best_dist = d
				best = body
	return best


func _draw() -> void:
	if hovered == null or not is_instance_valid(hovered):
		return
	# Doneness readout above the hovered piece: one bar per side + a label.
	var item := hovered
	var top: Vector2 = item.global_position - Vector2(0, item.food.size.y * 0.5 + 70)
	var bar_w: float = 120.0
	for side in 2:
		var p: float = item.side_progress[side]
		var y: float = top.y + side * 22
		var r := Rect2(top.x - bar_w * 0.5, y, bar_w, 16)
		draw_rect(r.grow(3), Color(0, 0, 0, 0.6))
		# Golden window highlighted in green.
		var g: float = item.food.cook_time_golden / item.food.cook_time_burnt
		draw_rect(Rect2(r.position.x + r.size.x * g, y, r.size.x * (1.0 - g) * 0.6, 16), Color(0.2, 0.7, 0.3, 0.6))
		var fill: float = clampf(p / item.food.cook_time_burnt, 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x * fill, 16)), item.get_side_color(side))
	var text := "%s - %s" % [item.food.display_name, item.get_doneness_label()]
	var text_pos: Vector2 = top + Vector2(-bar_w * 1.5, -14)
	draw_string_outline(_font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, bar_w * 3, 30, 8, Color.BLACK)
	draw_string(_font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, bar_w * 3, 30)
	draw_arc(item.global_position, item.food.size.x * 0.5 + 10, 0, TAU, 32, Color(1, 1, 1, 0.7), 3)
