class_name Order
extends RefCounted
## One customer's order. Created and tracked by the OrderManager autoload.

enum State { PENDING, ACCEPTED, READY, DELIVERED, FAILED }
const STATE_NAMES := ["Waiting", "Cooking", "Ready for delivery", "Delivered", "Failed"]

var id: int = 0
var customer_name: String = ""
var customer_color: Color = Color.WHITE
## food id (StringName) -> quantity
var items: Dictionary = {}
var state: State = State.PENDING

## Time the customer waits at the stall for you to accept.
var wait_time_total: float = 30.0
var wait_time_left: float = 30.0
## Time from accepting until it must be delivered.
var delivery_time_total: float = 90.0
var delivery_time_left: float = 90.0

# Filled in when bagged / delivered.
var quality: float = 0.0        ## 0..1 average quality of the bagged food
var burnt_count: int = 0
var raw_count: int = 0
var payment: int = 0
var rating: int = 0             ## 1..5 stars
var feedback: String = ""


func base_price() -> int:
	var total: int = 0
	for food_id in items:
		var food := FoodCatalog.get_food(food_id)
		if food:
			total += food.price * items[food_id]
	return total


func total_pieces() -> int:
	var n: int = 0
	for food_id in items:
		n += items[food_id]
	return n


func describe() -> String:
	var parts: PackedStringArray = []
	for food_id in items:
		var food := FoodCatalog.get_food(food_id)
		parts.append("%dx %s" % [items[food_id], food.display_name if food else str(food_id)])
	return ", ".join(parts)


## 0..1 of whichever timer is currently running.
func time_ratio() -> float:
	match state:
		State.PENDING:
			return clampf(wait_time_left / wait_time_total, 0.0, 1.0) if wait_time_total > 0.0 else 0.0
		State.ACCEPTED, State.READY:
			return clampf(delivery_time_left / delivery_time_total, 0.0, 1.0) if delivery_time_total > 0.0 else 0.0
	return 0.0


func is_active() -> bool:
	return state in [State.PENDING, State.ACCEPTED, State.READY]
