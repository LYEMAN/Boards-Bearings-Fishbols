extends Node
## Autoload "OrderManager": the single source of truth for orders and money.
##
## Flow:  create_random_order() -> PENDING  (customer waits at the stall)
##        accept(order)         -> ACCEPTED (cook it!)
##        bag(order, tray)      -> READY    (bagged, waiting to be delivered by skateboard)
##        deliver(order)        -> DELIVERED (paid)   ... or FAILED if a timer runs out.
##
## SKATEBOARDING: SkatingArea (Scripts/skating.gd) spawns a DeliveryNPC in the skatepark on
## `order_accepted`. When the skater reaches that NPC with a READY bag it calls
## OrderManager.deliver(order, trick_bonus), where trick_bonus = pesos earned from trick combos.

signal order_created(order: Order)
signal order_accepted(order: Order)
signal order_ready(order: Order)
signal order_delivered(order: Order)
signal order_failed(order: Order, reason: String)
signal money_changed(total: int)

## Seconds a customer waits at the stall before giving up (random in range).
var wait_patience := Vector2(28.0, 40.0)
## Delivery time = base + per piece.
var delivery_time_base: float = 60.0
var delivery_time_per_piece: float = 4.0
var max_foods_per_order: int = 3
## Pause all order timers (e.g. during a cutscene).
var paused: bool = false

var orders: Array[Order] = []
var money: int = 0
var _next_id: int = 1


func create_random_order(customer_name: String, customer_color: Color) -> Order:
	var order := Order.new()
	order.id = _next_id
	_next_id += 1
	order.customer_name = customer_name
	order.customer_color = customer_color

	# 1 food is most common, sometimes 2-3 different foods.
	var kinds: int = 1
	var roll: float = randf()
	if roll > 0.9:
		kinds = 3
	elif roll > 0.55:
		kinds = 2
	kinds = mini(kinds, max_foods_per_order)

	var pool: Array[FoodData] = FoodCatalog.all()
	for i in kinds:
		if pool.is_empty():
			break
		var food := _pick_weighted(pool)
		pool.erase(food)
		order.items[food.id] = food.random_quantity()

	order.wait_time_total = randf_range(wait_patience.x, wait_patience.y)
	order.wait_time_left = order.wait_time_total
	order.delivery_time_total = delivery_time_base + delivery_time_per_piece * order.total_pieces()
	order.delivery_time_left = order.delivery_time_total

	orders.append(order)
	order_created.emit(order)
	return order


func accept(order: Order) -> void:
	if order.state != Order.State.PENDING:
		return
	order.state = Order.State.ACCEPTED
	order_accepted.emit(order)


## True if the tray holds enough of every food in the order.
func can_bag(order: Order, tray: ServingTray) -> bool:
	if order.state != Order.State.ACCEPTED or tray == null:
		return false
	for id in order.items:
		if tray.count(id) < order.items[id]:
			return false
	return true


## Takes the food off the tray, grades it and marks the order READY for delivery.
func bag(order: Order, tray: ServingTray) -> bool:
	if not can_bag(order, tray):
		return false
	var total_quality: float = 0.0
	var pieces: int = 0
	order.burnt_count = 0
	order.raw_count = 0
	for id in order.items:
		for item in tray.take_items(id, order.items[id]):
			total_quality += item.get_quality()
			pieces += 1
			if item.doneness == FriedItem.Doneness.BURNT:
				order.burnt_count += 1
			elif item.get_quality() < 0.6:
				order.raw_count += 1
			item.queue_free()
	order.quality = total_quality / maxf(pieces, 1)
	order.state = Order.State.READY
	order_ready.emit(order)
	return true


## Call this when the bag reaches the customer. `bonus` = extra pesos (e.g. from skate tricks).
func deliver(order: Order, bonus: int = 0) -> void:
	if order.state != Order.State.READY:
		return
	var time_left: float = clampf(order.delivery_time_left / order.delivery_time_total, 0.0, 1.0)
	# Bad food pays less, fast delivery earns a tip, tricks on the way earn a bonus.
	order.trick_bonus = maxi(bonus, 0)
	order.payment = roundi(order.base_price() * (0.4 + 0.6 * order.quality) * (1.0 + 0.25 * time_left)) + order.trick_bonus
	order.rating = clampi(roundi((order.quality * 0.8 + time_left * 0.2) * 5.0), 1, 5)
	order.feedback = _feedback_for(order, time_left)
	order.state = Order.State.DELIVERED
	orders.erase(order)
	add_money(order.payment)
	order_delivered.emit(order)


func fail(order: Order, reason: String) -> void:
	if not order.is_active():
		return
	order.state = Order.State.FAILED
	order.rating = 1
	order.feedback = reason
	orders.erase(order)
	order_failed.emit(order, reason)


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func set_money(amount: int) -> void:
	money = maxi(0, amount)
	money_changed.emit(money)


func clear_orders() -> void:
	orders.clear()


func get_orders(state: Order.State) -> Array[Order]:
	var result: Array[Order] = []
	for o in orders:
		if o.state == state:
			result.append(o)
	return result


func _process(delta: float) -> void:
	if paused:
		return
	# Iterate over a copy: failing an order removes it from the list.
	for order in orders.duplicate():
		match order.state:
			Order.State.PENDING:
				order.wait_time_left -= delta
				if order.wait_time_left <= 0.0:
					fail(order, "Dugay kaayo! (Too slow!)")
			Order.State.ACCEPTED, Order.State.READY:
				order.delivery_time_left -= delta
				if order.delivery_time_left <= 0.0:
					fail(order, "Asa na akong order? (Where's my order?)")


func _pick_weighted(pool: Array[FoodData]) -> FoodData:
	var total: float = 0.0
	for f in pool:
		total += f.order_weight
	var r: float = randf() * total
	for f in pool:
		r -= f.order_weight
		if r <= 0.0:
			return f
	return pool.back()


func _feedback_for(order: Order, time_left: float) -> String:
	if order.burnt_count > 0 and order.quality < 0.6:
		return "Nasunog man ni, boss! (This is burnt!)"
	if order.raw_count > 0 and order.quality < 0.6:
		return "Hilaw pa man! (It's still raw!)"
	if order.trick_bonus >= 20:
		return "Astig kaayo ka mag-skate! (Sick tricks, boss!)"
	if order.quality >= 0.85 and time_left > 0.3:
		return "Lami kaayo! Salamat, boss! (Delicious! Thanks!)"
	if time_left < 0.15:
		return "Dugay pero okay ra. (Slow, but okay.)"
	return "Okay ra. (It's alright.)"
