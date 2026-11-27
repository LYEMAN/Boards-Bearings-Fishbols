class_name SkatingArea
extends Node2D
## Skatepark side of the delivery loop.
##
##   Customer accepts at the stall  -> OrderManager.order_accepted -> a DeliveryNPC appears here.
##   Order is bagged in the kitchen -> OrderManager.order_ready    -> NPC waves for the bag.
##   Skater touches the NPC          -> cashes in active combo + Style Tier -> OrderManager.deliver().
##
## Procedurally generates a new clustered skatepark layout every day via `regenerate_park()`.

@export var player_path: NodePath = ^"Node2D/CharacterBody2D"
## Local y of the ground surface (NPC feet stand here).
@export var ground_y: float = 93.0
## Number of obstacle clusters generated on each side of the start per day.
@export var clusters_per_side: int = 15
## Clear flat runway on each side of x = 0.
@export var start_clear: float = 350.0
## Flat run-up space (min, max px) between obstacle clusters to build momentum.
@export var cluster_gap_range := Vector2(330.0, 480.0)
## Local x range where NPCs may appear (updated automatically to match generated park).
@export var spawn_x_range := Vector2(-20000.0, 20000.0)
## NPCs appear this far (min, max px) from the skater so a delivery stays reachable.
@export var spawn_distance := Vector2(1200.0, 5000.0)
@export var min_distance_from_player: float = 1000.0
@export var min_npc_spacing: float = 160.0
## How close the skater must get to hand over the bag (x: horizontal, y: height above the NPC's feet).
@export var delivery_reach := Vector2(55.0, 175.0)
## Pesos earned per trick point.
@export var pesos_per_point: float = 0.05
## Pixels per "meter" for the distance readout in the HUD.
@export var pixels_per_meter: float = 50.0

const SFX_DELIVERY_SUCCESS: AudioStream = preload("res://Sounds/Combo/delivery_success.mp3")

var player: Skater
var tip_pool: float = 0.0

var _npcs: Dictionary = {}  # Order -> DeliveryNPC
var _hud: SkatingHUD
var _delivery_sfx: AudioStreamPlayer
var _park_layout: Dictionary = {}
var _player_spawn_local := Vector2.ZERO
var _last_banked_tier: String = ""
var _cursor_freed: bool = false

@onready var _stairs_root: Node2D = get_node_or_null("StairSets")
@onready var _rails_root: Node2D = get_node_or_null("Rails")
@onready var _obstacles_root: Node2D = get_node_or_null("Obstacles")
@onready var _ground_col: CollisionShape2D = get_node_or_null("StaticBody2D/CollisionShape2D")
@onready var _left_wall_col: CollisionShape2D = get_node_or_null("StaticBody2D2/CollisionShape2D")
@onready var _right_wall_col: CollisionShape2D = get_node_or_null("StaticBody2D2/StaticBody2D2/CollisionShape2D")
@onready var _ground_rect: ColorRect = get_node_or_null("ColorRect")


func _ready() -> void:
	player = get_node_or_null(player_path) as Skater
	if player:
		_player_spawn_local = to_local(player.global_position)

	_hud = SkatingHUD.new()
	add_child(_hud)
	_delivery_sfx = AudioStreamPlayer.new()
	_delivery_sfx.stream = SFX_DELIVERY_SUCCESS
	add_child(_delivery_sfx)
	visibility_changed.connect(_sync_hud_visibility)
	_sync_hud_visibility()

	# Generate Day 1 procedural skatepark layout.
	regenerate_park(1, false)

	if player:
		player.combo_changed.connect(_on_combo_changed)
		player.combo_banked.connect(_on_combo_banked)
		player.combo_lost.connect(_on_combo_lost)
		player.gesture_matched.connect(_on_gesture_matched)

	OrderManager.order_accepted.connect(_on_order_accepted)
	OrderManager.order_ready.connect(_on_order_ready)
	OrderManager.order_delivered.connect(_on_order_delivered)
	OrderManager.order_failed.connect(_on_order_failed)

	# Orders accepted before this scene loaded still need someone to deliver to.
	for order in OrderManager.orders:
		if order.state == Order.State.ACCEPTED or order.state == Order.State.READY:
			_spawn_npc(order)
	_refresh_pool()


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		_cursor_freed = not _cursor_freed
		if player:
			player.stick_input_enabled = not _cursor_freed
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _cursor_freed else Input.MOUSE_MODE_CAPTURED
		if _cursor_freed and _hud:
			_hud.show_toast("Cursor freed - click skatepark or press Esc to lock back to Trick Stick", Color("ffd166"))
		get_viewport().set_input_as_handled()
	elif _cursor_freed and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor_freed = false
		if player:
			player.stick_input_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if player and _hud and _hud.stick_ui:
		_hud.stick_ui.update_stick(player.gesture.stick_pos, delta)


func _physics_process(_delta: float) -> void:
	if player:
		for order in _npcs.keys():
			var npc: DeliveryNPC = _npcs[order]
			if not is_instance_valid(npc) or npc.mode != DeliveryNPC.Mode.WAITING:
				continue
			# Player origin is the body centre, NPC origin is its feet.
			var d: Vector2 = player.global_position - npc.global_position
			if absf(d.x) <= delivery_reach.x and d.y <= 0.0 and d.y >= -delivery_reach.y:
				if order.state == Order.State.READY:
					_deliver(order)
				else:
					npc.say_throttled("Wala pa man akong order! (My food isn't ready yet!)")
	_update_deliveries_text()


# ---------------------------------------------------------------- procedural generation

## Resets the skatepark with a brand-new procedurally generated layout (called per day cycle).
func regenerate_park(day_number: int = -1, announce: bool = true) -> void:
	if _stairs_root == null:
		_stairs_root = Node2D.new()
		_stairs_root.name = "StairSets"
		add_child(_stairs_root)
	if _rails_root == null:
		_rails_root = Node2D.new()
		_rails_root.name = "Rails"
		add_child(_rails_root)
	if _obstacles_root == null:
		_obstacles_root = Node2D.new()
		_obstacles_root.name = "Obstacles"
		add_child(_obstacles_root)

	_park_layout = SkateparkGenerator.generate(
		_stairs_root, _rails_root, _obstacles_root,
		ground_y, clusters_per_side, start_clear, cluster_gap_range
	)
	var half_w: float = _park_layout.get("half_width", 20000.0)
	_apply_park_bounds(half_w)

	if player:
		player.reset_for_new_park(to_global(_player_spawn_local))
	if _hud:
		_hud.clear_combo()

	# Keep any waiting delivery NPCs on clean flat surfaces in the new layout.
	for order in _npcs.keys():
		var npc: DeliveryNPC = _npcs[order]
		if is_instance_valid(npc) and npc.mode == DeliveryNPC.Mode.WAITING:
			npc.position = _pick_spawn_position()

	if announce and _hud:
		var prefix := "Day %d: " % day_number if day_number > 0 else ""
		_hud.show_toast("%sNew skatepark layout generated!" % prefix, Color("ffd166"))


func _apply_park_bounds(half_w: float) -> void:
	spawn_x_range = Vector2(-half_w + 400.0, half_w - 400.0)
	if _ground_col and _ground_col.shape is RectangleShape2D:
		(_ground_col.shape as RectangleShape2D).size.x = half_w * 2.0 + 40.0
	if _left_wall_col:
		_left_wall_col.position.x = -half_w - 10.0
	if _right_wall_col:
		_right_wall_col.position.x = half_w + 10.0
	if _ground_rect:
		_ground_rect.offset_left = -half_w
		_ground_rect.offset_right = half_w


# ---------------------------------------------------------------- delivery

func _carrying() -> bool:
	return not OrderManager.get_orders(Order.State.READY).is_empty()


func _deliver(order: Order) -> void:
	_last_banked_tier = ""
	# Cash in whatever combo line is active (even mid-air or mid-grind) before paying!
	if player:
		player.bank_combo()
	var bonus: int = roundi(tip_pool)
	tip_pool = 0.0
	OrderManager.deliver(order, bonus)


func _spawn_npc(order: Order) -> void:
	if _npcs.has(order):
		return
	var npc := DeliveryNPC.new()
	npc.setup(order, _pick_spawn_position())
	add_child(npc)
	move_child(npc, 0)  # draw behind the skater
	_npcs[order] = npc


func _pick_spawn_position() -> Vector2:
	var player_x: float = to_local(player.global_position).x if player else 0.0
	var best_pos := Vector2(_random_x_near(player_x), ground_y)
	var best_score: float = -INF
	var space := get_world_2d().direct_space_state if is_inside_tree() else null
	for i in 50:
		var x: float = _random_x_near(player_x)
		var y: float = _flat_surface_y_at(space, x)
		if is_nan(y):
			continue
		var nearest: float = absf(x - player_x) / maxf(min_distance_from_player, 1.0)
		for npc in _npcs.values():
			if is_instance_valid(npc):
				nearest = minf(nearest, absf(x - npc.position.x) / maxf(min_npc_spacing, 1.0))
		if nearest >= 1.0:
			return Vector2(x, y)
		if nearest > best_score:
			best_score = nearest
			best_pos = Vector2(x, y)
	return best_pos


## Random x a reachable distance from the skater (either side), kept inside the park.
func _random_x_near(player_x: float) -> float:
	var dist: float = randf_range(spawn_distance.x, spawn_distance.y)
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var x: float = player_x + side * dist
	if x < spawn_x_range.x or x > spawn_x_range.y:
		x = player_x - side * dist
	return clampf(x, spawn_x_range.x, spawn_x_range.y)


## Returns local y of a flat walkable surface at local x (ground or stair deck), or NAN if sloped/blocked.
func _flat_surface_y_at(space: PhysicsDirectSpaceState2D, local_x: float) -> float:
	if not _park_layout.is_empty():
		return SkateparkGenerator.get_flat_surface_y(_park_layout, local_x, 28.0)
	if space == null:
		return ground_y
	var center_y: float = _raycast_surface_y(space, local_x)
	if is_nan(center_y):
		return ground_y
	var left_y: float = _raycast_surface_y(space, local_x - 24.0)
	var right_y: float = _raycast_surface_y(space, local_x + 24.0)
	if is_nan(left_y) or is_nan(right_y):
		return NAN
	if absf(left_y - center_y) > 2.0 or absf(right_y - center_y) > 2.0:
		return NAN
	return center_y


func _raycast_surface_y(space: PhysicsDirectSpaceState2D, local_x: float) -> float:
	var from := to_global(Vector2(local_x, -900.0))
	var to := to_global(Vector2(local_x, ground_y + 40.0))
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	var normal: Vector2 = hit.normal
	if normal.y > -0.95:
		return NAN
	if hit.collider is SkateObstacle:
		return NAN
	return to_local(hit.position).y


func _exit_x_for(npc: DeliveryNPC) -> float:
	var mid: float = (spawn_x_range.x + spawn_x_range.y) * 0.5
	return spawn_x_range.x - 200.0 if npc.position.x < mid else spawn_x_range.y + 200.0


# ---------------------------------------------------------------- order signals

func _on_order_accepted(order: Order) -> void:
	_spawn_npc(order)
	_hud.show_toast("%s is waiting at the skatepark for order #%d." % [order.customer_name, order.id])


func _on_order_ready(order: Order) -> void:
	_hud.show_toast("Order #%d bagged! Build a C/B/A/S combo line to %s for big tips!" % [order.id, order.customer_name], Color("8cff8c"))
	_refresh_pool()


func _on_order_delivered(order: Order) -> void:
	if _delivery_sfx:
		_delivery_sfx.play()
	var npc: DeliveryNPC = _npcs.get(order)
	_npcs.erase(order)
	if is_instance_valid(npc):
		npc.celebrate("Salamat! +P%d" % order.payment, _exit_x_for(npc))
	var stars := "★".repeat(order.rating) + "☆".repeat(5 - order.rating)
	var rank_prefix := "[%s-TIER] " % _last_banked_tier if _last_banked_tier != "" else ""
	var tricks := "  (style tips +P%d)" % order.trick_bonus if order.trick_bonus > 0 else ""
	_hud.show_toast("%s%s %s  \"%s\"  +P%d%s" % [rank_prefix, order.customer_name, stars, order.feedback, order.payment, tricks], Color("b8f5b0"))
	_last_banked_tier = ""
	_refresh_pool()


func _on_order_failed(order: Order, reason: String) -> void:
	var npc: DeliveryNPC = _npcs.get(order)
	_npcs.erase(order)
	if is_instance_valid(npc):
		npc.storm_off(reason, _exit_x_for(npc))
		_hud.show_toast("%s left: \"%s\"" % [order.customer_name, reason], Color("ffb3b3"))
	_refresh_pool()


# ---------------------------------------------------------------- combo & tier signals

func _on_combo_changed(tricks: Array, _points: int, _multiplier: float, tier: String) -> void:
	_hud.show_combo_tier(tier, tricks.size())


func _on_combo_banked(points: int, _tricks: Array, tier: String) -> void:
	_last_banked_tier = tier
	if _carrying():
		var pesos: float = points * pesos_per_point
		tip_pool += pesos
	_hud.finish_combo_tier(false)
	_refresh_pool()


func _on_combo_lost(_points: int, _reason: String) -> void:
	_hud.finish_combo_tier(true)


# ---------------------------------------------------------------- HUD

func _refresh_pool() -> void:
	if _hud:
		_hud.set_pool(roundi(tip_pool), _carrying())


func _update_deliveries_text() -> void:
	var lines := PackedStringArray()
	var player_x: float = player.global_position.x if player else global_position.x
	for order in _npcs:
		var npc: DeliveryNPC = _npcs[order]
		if not is_instance_valid(npc) or npc.mode != DeliveryNPC.Mode.WAITING:
			continue
		var dx: float = npc.global_position.x - player_x
		var arrow := "<-" if dx < 0.0 else "->"
		var elev := " (UP)" if npc.position.y < ground_y - 30.0 else ""
		var status := "READY" if order.state == Order.State.READY else "cooking"
		lines.append("#%d %s  [%s]  %s %dm%s  %ds" % [
			order.id, order.customer_name, status, arrow,
			roundi(absf(dx) / pixels_per_meter), elev, ceili(order.delivery_time_left)])
	if lines.is_empty():
		_hud.set_deliveries("No one waiting.\nAccept orders at the stall!")
	else:
		_hud.set_deliveries("\n".join(lines))


func _on_gesture_matched(trick_name: String, stroke_points: PackedVector2Array) -> void:
	if _hud and _hud.stick_ui:
		_hud.stick_ui.flash_recognized(trick_name, stroke_points)


func _sync_hud_visibility() -> void:
	var vis := is_visible_in_tree()
	if _hud:
		_hud.visible = vis
	if vis:
		_cursor_freed = false
		if player:
			player.stick_input_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		if player:
			player.stick_input_enabled = false
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
