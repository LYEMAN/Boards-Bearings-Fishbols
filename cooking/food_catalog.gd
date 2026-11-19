class_name FoodCatalog
extends RefCounted
## The menu. Add a FoodData .tres here to make it orderable and show up in the ingredient bins.

const FOODS := [
	preload("res://cooking/foods/fishball.tres"),
	preload("res://cooking/foods/kwek_kwek.tres"),
	preload("res://cooking/foods/tempura.tres"),
	preload("res://cooking/foods/turon.tres"),
	preload("res://cooking/foods/banana_cue.tres"),
	preload("res://cooking/foods/kamote_cue.tres"),
	preload("res://cooking/foods/pinaypay.tres"),
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
