class_name Stove
extends Node2D
## The burner under the wok. The player picks a heat level; the oil temperature slowly
## moves toward it, and dropping in cold raw food cools the oil down a little.
## The oil's `heat` (cooking speed multiplier) is the current temperature.

signal level_changed(level: Level)

enum Level { OFF, LOW, MEDIUM, HIGH }
const LEVEL_NAMES := ["Off", "Low", "Medium", "High"]

@export var oil_node: Node2D
## Target oil heat for Off / Low / Medium / High. 1.0 = the cook times written in FoodData.
@export var level_heat := PackedFloat32Array([0.0, 0.55, 1.0, 1.7])
@export var start_level: Level = Level.MEDIUM
@export var start_temperature: float = 0.7
## Heat gained / lost per second while moving toward the target.
@export var heat_up_rate: float = 0.25
@export var cool_down_rate: float = 0.15
@export var burner_width: float = 320.0

var level: Level = Level.MEDIUM
var temperature: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	level = start_level
	temperature = start_temperature
	if oil_node:
		oil_node.body_entered_oil.connect(_on_body_entered_oil)
		oil_node.heat = temperature


func set_level(new_level: Level) -> void:
	new_level = clampi(new_level, Level.OFF, Level.HIGH) as Level
	if new_level == level:
		return
	level = new_level
	level_changed.emit(level)


func get_target_heat() -> float:
	return level_heat[level]


## 0..1 for UI bars (1 = as hot as High gets).
func get_temperature_ratio() -> float:
	return clampf(temperature / level_heat[Level.HIGH], 0.0, 1.0)


func get_temperature_label() -> String:
	if temperature < 0.2:
		return "Cold"
	if temperature < 0.75:
		return "Warm"
	if temperature < 1.3:
		return "Hot"
	return "Very hot!"


func _process(delta: float) -> void:
	_time += delta
	var target: float = get_target_heat()
	var rate: float = heat_up_rate if target > temperature else cool_down_rate
	temperature = move_toward(temperature, target, rate * delta)
	if oil_node:
		oil_node.heat = temperature
	queue_redraw()


func _on_body_entered_oil(body: Node2D) -> void:
	# Cold, raw pieces steal heat from the oil. Crowding the wok slows everything down.
	if body is FriedItem and body.get_cooked_amount() < 0.3:
		temperature = maxf(0.0, temperature - body.food.oil_cooling)


func _draw() -> void:
	var half: float = burner_width * 0.5
	# Burner ring
	draw_rect(Rect2(-half, 0, burner_width, 22), Color("2d2d2d"))
	draw_rect(Rect2(-half + 20, -8, burner_width - 40, 10), Color("4a4a4a"))
	if level == Level.OFF:
		return
	# Flames: taller and bluer the higher the level.
	var flame_h: float = [0.0, 35.0, 60.0, 95.0][level]
	var count: int = 9
	for i in count:
		var x: float = lerpf(-half + 35, half - 35, float(i) / (count - 1))
		var flicker: float = 0.75 + 0.25 * sin(_time * 18.0 + i * 1.7)
		var h: float = flame_h * flicker
		var outer := PackedVector2Array([Vector2(x - 14, -8), Vector2(x + 14, -8), Vector2(x, -8 - h)])
		var inner := PackedVector2Array([Vector2(x - 7, -8), Vector2(x + 7, -8), Vector2(x, -8 - h * 0.55)])
		draw_colored_polygon(outer, Color(0.25, 0.45, 1.0, 0.85))
		draw_colored_polygon(inner, Color(0.7, 0.9, 1.0, 0.9))
