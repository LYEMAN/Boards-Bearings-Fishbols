class_name CustomerSpawner
extends Node2D
## Sends customers to the stall every so often. Each customer gets a random order.
## Stall spots are the children Marker2Ds named Spot*, or a default row if there are none.

@export var customer_scene: PackedScene = preload("res://customers/customer.tscn")
@export var spawn_interval := Vector2(7.0, 14.0)
@export var first_customer_delay: float = 2.0
## Where customers walk in from (world x).
@export var enter_x: float = 2300.0
@export var enabled: bool = true

const NAMES := [
	"Mang Boy", "Inday Lorna", "Dodong", "Ate Joy", "Kuya Ben", "Nong Pido", "Day Marites",
	"Jun-jun", "Bebeng", "Toto", "Ate Cha", "Kuya Rex", "Lola Pacing", "Migs", "Bea",
]
const SHIRT_COLORS := [
	Color("e63946"), Color("f4a261"), Color("2a9d8f"), Color("457b9d"), Color("8338ec"),
	Color("ffbe0b"), Color("fb5607"), Color("3a86ff"), Color("06d6a0"),
]

var _spots: Array[Vector2] = []
var _occupied: Dictionary = {}  # spot index -> Order standing there
var _timer: float = 0.0


func _ready() -> void:
	for child in get_children():
		if child is Marker2D:
			_spots.append(child.global_position)
	if _spots.is_empty():
		for i in 3:
			_spots.append(global_position + Vector2(i * 400.0, 0))
	_timer = first_customer_delay
	# Free the spot as soon as a customer starts leaving so the next one can come.
	OrderManager.order_accepted.connect(_free_spot_of)
	OrderManager.order_failed.connect(func(o: Order, _reason: String): _free_spot_of(o))


func _process(delta: float) -> void:
	if not enabled or OrderManager.paused:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(spawn_interval.x, spawn_interval.y)
		spawn_customer()


func spawn_customer() -> Customer:
	var free_spot: int = -1
	for i in _spots.size():
		if not _occupied.has(i):
			free_spot = i
			break
	if free_spot == -1:
		return null

	var order := OrderManager.create_random_order(NAMES.pick_random(), SHIRT_COLORS.pick_random())
	var customer: Customer = customer_scene.instantiate()
	customer.setup(order, Vector2(enter_x, _spots[free_spot].y), _spots[free_spot])
	_occupied[free_spot] = order
	get_parent().add_child.call_deferred(customer)
	return customer


func _free_spot_of(order: Order) -> void:
	for i in _occupied.keys():
		if _occupied[i] == order:
			_occupied.erase(i)
