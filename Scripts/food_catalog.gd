class_name FoodCatalog
extends RefCounted
## The menu. Add a FoodData .tres here to make it orderable and show up on the ingredient shelf.
## Each food's `unlock_day` decides when it appears in the campaign.

const FOODS := [
	preload("res://Resources/Foods/fishball.tres"),
	preload("res://Resources/Foods/kwek_kwek.tres"),
	preload("res://Resources/Foods/tempura.tres"),
	preload("res://Resources/Foods/turon.tres"),
	preload("res://Resources/Foods/banana_cue.tres"),
	preload("res://Resources/Foods/kamote_cue.tres"),
	preload("res://Resources/Foods/pinaypay.tres"),
]

## Set above 0 to force a campaign day (For testing cooking.tscn on its own).
static var day_override: int = 0


static func all() -> Array[FoodData]:
	var result: Array[FoodData] = []
	for f in FOODS:
		result.append(f)
	return result


static func get_food(id: StringName) -> FoodData:
	for f in FOODS:
		if f.id == id:
			return f
	return null


## The campaign day used for unlocks (PlayerData.day, but at least 1).
static func current_day() -> int:
	if day_override > 0:
		return day_override
	var tree := Engine.get_main_loop() as SceneTree
	var player_data: Node = tree.root.get_node_or_null("PlayerData") if tree else null
	if player_data:
		return maxi(int(player_data.day), 1)
	return 1


static func is_unlocked(food: FoodData, day: int = -1) -> bool:
	if day < 0:
		day = current_day()
	return food.unlock_day <= day


## Foods available on `day` (defaults to the current campaign day).
static func unlocked(day: int = -1) -> Array[FoodData]:
	if day < 0:
		day = current_day()
	var result: Array[FoodData] = []
	for f in FOODS:
		if f.unlock_day <= day:
			result.append(f)
	return result


## Foods that become available exactly on `day` (for "New on the menu!" messages).
static func newly_unlocked(day: int = -1) -> Array[FoodData]:
	if day < 0:
		day = current_day()
	var result: Array[FoodData] = []
	for f in FOODS:
		if f.unlock_day == day:
			result.append(f)
	return result
