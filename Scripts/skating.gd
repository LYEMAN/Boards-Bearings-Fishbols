class_name SkatingArea
extends Node2D
## Skatepark side of the delivery loop.
##
##   Customer accepts at the stall  -> OrderManager.order_accepted -> a DeliveryNPC appears here.
##   Order is bagged in the kitchen -> OrderManager.order_ready    -> NPC waves for the bag.
##   Skater touches the NPC          -> OrderManager.deliver(order, trick_tips) -> money + order done.
##
## Trick combos landed while carrying a bag (any READY order) are converted into a peso tip pool
## (points * pesos_per_point) which is paid out with the next delivery.

@export var player_path: NodePath = ^"Node2D/CharacterBody2D"
## Local y of the ground surface (NPC feet stand here).
@export var ground_y: float = 93.0
## Local x range where NPCs may appear.
@export var spawn_x_range := Vector2(-1000.0, 1000.0)
@export var min_distance_from_player: float = 300.0
@export var min_npc_spacing: float = 160.0
## How close the skater must get to hand over the bag (x: horizontal, y: height above the NPC's feet).
## The height is generous so you can deliver mid-trick.
@export var delivery_reach := Vector2(55.0, 175.0)
## Pesos earned per trick point (75-pt kickflip = P3.75 before combo multipliers).
@export var pesos_per_point: float = 0.05
## Pixels per "meter" for the distance readout in the HUD.
@export var pixels_per_meter: float = 50.0

var player: Skater
var tip_pool: float = 0.0

var _npcs: Dictionary = {}  # Order -> DeliveryNPC
var _hud: SkatingHUD


func _ready() -> void:
	player = get_node_or_null(player_path) as Skater

	_hud = SkatingHUD.new()
	add_child(_hud)
	visibility_changed.connect(_sync_hud_visibility)
	_sync_hud_visibility()

	if player:
		player.combo_changed.connect(_on_combo_changed)
		player.combo_banked.connect(_on_combo_banked)
		player.combo_lost.connect(_on_combo_lost)

	OrderManager.order_accepted.connect(_on_order_accepted)
	OrderManager.order_ready.connect(_on_order_ready)
	OrderManager.order_delivered.connect(_on_order_delivered)
	OrderManager.order_failed.connect(_on_order_failed)

	# Orders accepted before this scene loaded still need someone to deliver to.
	for order in OrderManager.orders:
		if order.state == Order.State.ACCEPTED or order.state == Order.State.READY:
			_spawn_npc(order)
	_refresh_pool()


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


# ---------------------------------------------------------------- delivery

func _carrying() -> bool:
	return not OrderManager.get_orders(Order.State.READY).is_empty()


func _deliver(order: Order) -> void:
	# Cash in whatever combo is in progress (even mid-air) before paying.
	if player:
		player.bank_combo()
	var bonus: int = roundi(tip_pool)
	tip_pool = 0.0
	OrderManager.deliver(order, bonus)


func _spawn_npc(order: Order) -> void:
	if _npcs.has(order):
		return
	var npc := DeliveryNPC.new()
	npc.setup(order, Vector2(_pick_spawn_x(), ground_y))
	add_child(npc)
	move_child(npc, 0)  # draw behind the skater
	_npcs[order] = npc


func _pick_spawn_x() -> float:
	var player_x: float = to_local(player.global_position).x if player else 0.0
	var best_x: float = randf_range(spawn_x_range.x, spawn_x_range.y)
	var best_score: float = -INF
	for i in 30:
		var x: float = randf_range(spawn_x_range.x, spawn_x_range.y)
		var nearest: float = absf(x - player_x) / maxf(min_distance_from_player, 1.0)
		for npc in _npcs.values():
			if is_instance_valid(npc):
				nearest = minf(nearest, absf(x - npc.position.x) / maxf(min_npc_spacing, 1.0))
		if nearest >= 1.0:
			return x
		if nearest > best_score:
			best_score = nearest
			best_x = x
	return best_x


func _exit_x_for(npc: DeliveryNPC) -> float:
	var mid: float = (spawn_x_range.x + spawn_x_range.y) * 0.5
	return spawn_x_range.x - 200.0 if npc.position.x < mid else spawn_x_range.y + 200.0


# ---------------------------------------------------------------- order signals

func _on_order_accepted(order: Order) -> void:
	_spawn_npc(order)
	_hud.show_toast("%s is waiting at the skatepark for order #%d." % [order.customer_name, order.id])


func _on_order_ready(order: Order) -> void:
	_hud.show_toast("Order #%d bagged! Skate it to %s - land tricks on the way for tips!" % [order.id, order.customer_name], Color("8cff8c"))
	_refresh_pool()


func _on_order_delivered(order: Order) -> void:
	var npc: DeliveryNPC = _npcs.get(order)
	_npcs.erase(order)
	if is_instance_valid(npc):
		npc.celebrate("Salamat! +P%d" % order.payment, _exit_x_for(npc))
	var stars := "★".repeat(order.rating) + "☆".repeat(5 - order.rating)
	var tricks := "  (tricks +P%d)" % order.trick_bonus if order.trick_bonus > 0 else ""
	_hud.show_toast("%s %s  \"%s\"  +P%d%s" % [order.customer_name, stars, order.feedback, order.payment, tricks], Color("b8f5b0"))
	_refresh_pool()


func _on_order_failed(order: Order, reason: String) -> void:
	var npc: DeliveryNPC = _npcs.get(order)
	_npcs.erase(order)
	if is_instance_valid(npc):
		npc.storm_off(reason, _exit_x_for(npc))
		_hud.show_toast("%s left: \"%s\"" % [order.customer_name, reason], Color("ffb3b3"))
	_refresh_pool()


# ---------------------------------------------------------------- combo signals

func _on_combo_changed(tricks: Array, points: int, multiplier: float) -> void:
	_hud.show_combo(tricks, points, multiplier, roundi(points * pesos_per_point), _carrying())


func _on_combo_banked(points: int, _tricks: Array) -> void:
	if _carrying():
		var pesos: float = points * pesos_per_point
		tip_pool += pesos
		_hud.end_combo("+%d pts   ->   +P%d tip" % [points, roundi(pesos)], Color("8cff8c"))
	else:
		_hud.end_combo("+%d pts   (no bag, no tip)" % points, Color.WHITE)
	_refresh_pool()


func _on_combo_lost(points: int) -> void:
	_hud.end_combo("BAIL!   -%d pts" % points, Color("ff6b6b"))


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
		var status := "READY" if order.state == Order.State.READY else "cooking"
		lines.append("#%d %s  [%s]  %s %dm  %ds" % [
			order.id, order.customer_name, status, arrow,
			roundi(absf(dx) / pixels_per_meter), ceili(order.delivery_time_left)])
	if lines.is_empty():
		_hud.set_deliveries("No one waiting.\nAccept orders at the stall!")
	else:
		_hud.set_deliveries("\n".join(lines))


func _sync_hud_visibility() -> void:
	if _hud:
		_hud.visible = is_visible_in_tree()
