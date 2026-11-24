extends Node
## Autoload "PlayerData": stores persistent player progress (stats, day, money)
## and saves/loads it as XML at user://player_save.xml.

signal data_changed

const SAVE_PATH := "user://player_save.xml"

const STAT_DEFS := {
	"skate_speed": {
		"name": "Bearings (Skate Speed)",
		"description": "Increases top skate speed and push power.",
		"base_cost": 25,
		"cost_step": 20,
		"max_level": 5,
	},
	"ollie_height": {
		"name": "Deck Pop (Ollie Height)",
		"description": "Increases ollie jump height for bigger tricks.",
		"base_cost": 25,
		"cost_step": 20,
		"max_level": 5,
	},
	"stove_heat": {
		"name": "Burner Power (Stove Heat)",
		"description": "Heats oil faster and increases cooking speed.",
		"base_cost": 30,
		"cost_step": 25,
		"max_level": 5,
	},
	"customer_patience": {
		"name": "Stall Appeal (Patience)",
		"description": "Customers wait longer before losing patience.",
		"base_cost": 30,
		"cost_step": 25,
		"max_level": 5,
	},
}

var day: int = 0
var money: int = 0
var stats: Dictionary = {}

var _syncing_money: bool = false

const DAY_0_SCENE := "res://Scenes/intro.tscn"
const DAY_1_SCENE := "res://Scenes/Day 1.tscn"


func _ready() -> void:
	_init_default_stats()
	load_data()
	sync_to_order_manager()
	OrderManager.money_changed.connect(_on_order_manager_money_changed)


func _init_default_stats() -> void:
	stats.clear()
	for stat_id in STAT_DEFS:
		stats[stat_id] = 0


func get_stat_level(stat_id: String) -> int:
	return int(stats.get(stat_id, 0))


func get_max_level(stat_id: String) -> int:
	if stat_id not in STAT_DEFS:
		return 0
	return int(STAT_DEFS[stat_id]["max_level"])


func is_maxed(stat_id: String) -> bool:
	return get_stat_level(stat_id) >= get_max_level(stat_id)


func get_upgrade_cost(stat_id: String) -> int:
	if stat_id not in STAT_DEFS:
		return 0
	var def: Dictionary = STAT_DEFS[stat_id]
	return int(def["base_cost"]) + get_stat_level(stat_id) * int(def["cost_step"])


func can_upgrade(stat_id: String) -> bool:
	if stat_id not in STAT_DEFS or is_maxed(stat_id):
		return false
	return money >= get_upgrade_cost(stat_id)


func buy_upgrade(stat_id: String) -> bool:
	if not can_upgrade(stat_id):
		return false
	money -= get_upgrade_cost(stat_id)
	stats[stat_id] = get_stat_level(stat_id) + 1
	sync_to_order_manager()
	save_data()
	data_changed.emit()
	return true


func advance_day() -> void:
	day += 1
	save_data()
	data_changed.emit()


func sync_from_order_manager() -> void:
	money = maxi(0, OrderManager.money)


func sync_to_order_manager() -> void:
	_syncing_money = true
	OrderManager.set_money(money)
	_syncing_money = false
	apply_stats_to_order_manager()


func apply_stats_to_order_manager() -> void:
	var patience_lv: int = get_stat_level("customer_patience")
	OrderManager.wait_patience = Vector2(28.0 + patience_lv * 4.0, 40.0 + patience_lv * 5.0)
	OrderManager.delivery_time_base = 60.0 + patience_lv * 10.0


func apply_stats_to_stove(stove: Stove) -> void:
	if stove == null:
		return
	var heat_lv: int = get_stat_level("stove_heat")
	var mult: float = 1.0 + heat_lv * 0.1
	stove.heat_up_rate = 0.25 + heat_lv * 0.08
	stove.level_heat = PackedFloat32Array([0.0, 0.55 * mult, 1.0 * mult, 1.7 * mult])


func apply_stats_to_player(player: Node) -> void:
	if player == null:
		return
	var speed_lv: int = get_stat_level("skate_speed")
	var ollie_lv: int = get_stat_level("ollie_height")
	if "max_speed" in player:
		player.max_speed = 400.0 + speed_lv * 60.0
	if "push_impulse" in player:
		player.push_impulse = 120.0 + speed_lv * 20.0
	if "ollie_force" in player:
		player.ollie_force = 550.0 + ollie_lv * 55.0


func save_data() -> Error:
	var lines := PackedStringArray([
		'<?xml version="1.0" encoding="UTF-8"?>',
		"<PlayerData>",
		"\t<Day>%d</Day>" % day,
		"\t<Money>%d</Money>" % money,
		"\t<Stats>",
	])
	for stat_id in STAT_DEFS:
		lines.append('\t\t<Stat id="%s" level="%d" />' % [stat_id.xml_escape(true), get_stat_level(stat_id)])
	lines.append("\t</Stats>")
	lines.append("</PlayerData>")

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return OK


func load_data() -> Error:
	if not FileAccess.file_exists(SAVE_PATH):
		return ERR_FILE_NOT_FOUND
	var parser := XMLParser.new()
	var err: Error = parser.open(SAVE_PATH)
	if err != OK:
		return err

	var current_tag: String = ""
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				current_tag = parser.get_node_name()
				if current_tag == "Stat":
					var stat_id: String = parser.get_named_attribute_value_safe("id")
					var level_str: String = parser.get_named_attribute_value_safe("level")
					if stat_id in STAT_DEFS and level_str.is_valid_int():
						stats[stat_id] = clampi(level_str.to_int(), 0, get_max_level(stat_id))
			XMLParser.NODE_TEXT:
				var text: String = parser.get_node_data().strip_edges()
				if text.is_empty():
					continue
				if current_tag == "Day" and text.is_valid_int():
					day = maxi(0, text.to_int())
				elif current_tag == "Money" and text.is_valid_int():
					money = maxi(0, text.to_int())
			XMLParser.NODE_ELEMENT_END:
				current_tag = ""

	data_changed.emit()
	return OK


func reset_data() -> void:
	day = 0
	money = 0
	_init_default_stats()
	sync_to_order_manager()
	save_data()
	data_changed.emit()


func _on_order_manager_money_changed(total: int) -> void:
	if _syncing_money:
		return
	money = maxi(0, total)
	data_changed.emit()


func switch_day_scene() -> void:
	var target_scene: String

	if day == 0:
		target_scene = DAY_0_SCENE
	else:
		target_scene = DAY_1_SCENE

	get_tree().change_scene_to_file(target_scene)
