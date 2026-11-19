class_name FoodData
extends Resource
## Everything that makes one street food different from another.
## Make one .tres per food in res://cooking/foods/ and add it to FoodCatalog.

@export var id: StringName = &"fishball"
@export var display_name: String = "Fishball"

@export_group("Look")
@export var texture: Texture2D = preload("res://fishball.png")
## Size of ONE piece in the world, in pixels (x = length, y = thickness).
## Equal x and y = a round piece (circle collider), otherwise a capsule lying flat.
@export var size: Vector2 = Vector2(40, 40)
## How many pixels wide the food actually is inside the texture (fishball.png has padding).
@export var texture_visible_size: float = 37.0
## Shifts the texture so the visible food is centred on the collider.
@export var texture_offset: Vector2 = Vector2(-1, 4)
@export var raw_color: Color = Color("f2efe6")
@export var golden_color: Color = Color("d9962b")
@export var burnt_color: Color = Color("2b1a0e")

@export_group("Cooking")
## Seconds at heat 1.0 (Medium), facing down, for ONE side to turn golden.
@export var cook_time_golden: float = 6.0
## Seconds at heat 1.0, facing down, for one side to burn.
@export var cook_time_burnt: float = 16.0
## How fast the side facing UP cooks compared to the side facing down (0..1).
## Low values mean the piece must be flipped / stirred to cook evenly.
@export_range(0.0, 1.0) var top_side_rate: float = 0.5
## How strongly a cooked piece floats up in the oil (fishballs float when done!). 0 = never.
@export var float_strength: float = 0.5
@export var mass: float = 0.1
## How much the oil temperature drops when a raw piece goes in.
@export var oil_cooling: float = 0.02

@export_group("Selling")
## Price per piece, in pesos.
@export var price: int = 1
@export var order_min: int = 5
@export var order_max: int = 10
## Quantities come in steps of this (e.g. 5 = fishballs sold per stick of 5).
@export var order_step: int = 5
## Relative chance customers pick this food.
@export var order_weight: float = 1.0


func is_round() -> bool:
	return is_equal_approx(size.x, size.y)


func random_quantity() -> int:
	var step: int = maxi(order_step, 1)
	var steps: int = maxi((order_max - order_min) / step, 0)
	return order_min + randi_range(0, steps) * step
