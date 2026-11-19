extends Node2D
## Cooking station test scene.

@onready var kitchen: KitchenInput = $KitchenInput
@onready var wok: Node2D = $Wok


func _unhandled_input(event: InputEvent) -> void:
	# Debug: Space / Enter drops a random raw food into the wok.
	if event.is_action_pressed("ui_accept"):
		var food: FoodData = FoodCatalog.all().pick_random()
		kitchen.spawn_food(food, wok.global_position + Vector2(randf_range(200, 1000), -150))
