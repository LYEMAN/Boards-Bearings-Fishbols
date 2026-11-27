extends Control

const DAY_SCENE_PATH := "res://Scenes/Day 1.tscn"

@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var money_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/MoneyLabel
@onready var upgrades_list: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/UpgradesList
@onready var status_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var next_day_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/NextDayButton


func _ready() -> void:
	PlayerData.data_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	title_label.text = "End of Day %d - Upgrades" % PlayerData.day
	money_label.text = "Money: P %d" % PlayerData.money
	next_day_button.text = "Start Day %d" % (PlayerData.day + 1)

	for child in upgrades_list.get_children():
		child.queue_free()

	for stat_id in PlayerData.STAT_DEFS:
		upgrades_list.add_child(_create_upgrade_row(stat_id))


func _create_upgrade_row(stat_id: String) -> Control:
	var def: Dictionary = PlayerData.STAT_DEFS[stat_id]
	var level: int = PlayerData.get_stat_level(stat_id)
	var max_level: int = PlayerData.get_max_level(stat_id)
	var maxed: bool = PlayerData.is_maxed(stat_id)
	var cost: int = PlayerData.get_upgrade_cost(stat_id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = "%s  (Lv. %d / %d)" % [def["name"], level, max_level]
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = str(def["description"])
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	info.add_child(desc_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(150, 42)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.text = "MAXED" if maxed else "Upgrade (P %d)" % cost
	buy_button.disabled = not PlayerData.can_upgrade(stat_id)
	buy_button.pressed.connect(_on_buy_pressed.bind(stat_id))
	row.add_child(buy_button)

	return row


func _on_buy_pressed(stat_id: String) -> void:
	if PlayerData.buy_upgrade(stat_id):
		var stat_name: String = str(PlayerData.STAT_DEFS[stat_id]["name"])
		status_label.text = "Upgraded %s! Progress saved." % stat_name


func _on_next_day_button_pressed() -> void:
	PlayerData.advance_day()
	get_tree().change_scene_to_file(DAY_SCENE_PATH)
