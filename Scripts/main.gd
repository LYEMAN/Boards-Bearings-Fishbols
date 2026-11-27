extends Node2D
## Cooking station scene.

## Testing only: force a campaign day (1-9) when running cooking.tscn by itself. 0 = use PlayerData.day.
@export_range(0, 9) var debug_day: int = 0

@onready var kitchen: KitchenInput = $KitchenInput
@onready var wok: Node2D = $Wok


func _enter_tree() -> void:
	# Runs before the children's _ready, so the shelf/orders see the right day.
	FoodCatalog.day_override = debug_day


func _unhandled_input(event: InputEvent) -> void:
	# Debug: Space / Enter drops a random unlocked raw food into the wok.
	if event.is_action_pressed("ui_accept"):
		var food: FoodData = FoodCatalog.unlocked().pick_random()
		kitchen.spawn_food(food, wok.global_position + Vector2(randf_range(200, 1000), -150))
