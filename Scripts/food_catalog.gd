class_name FoodCatalog
extends RefCounted
## The menu. Add a FoodData .tres here to make it orderable and show up in the ingredient bins.

const FOODS := [
	preload("res://Resources/Foods/fishball.tres"),
	preload("res://Resources/Foods/kwek_kwek.tres"),
	preload("res://Resources/Foods/tempura.tres"),
	preload("res://Resources/Foods/turon.tres"),
	preload("res://Resources/Foods/banana_cue.tres"),
	preload("res://Resources/Foods/kamote_cue.tres"),
	preload("res://Resources/Foods/pinaypay.tres"),
]


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
