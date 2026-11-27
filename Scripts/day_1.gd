extends Node2D

const UPGRADE_SCENE_PATH := "res://Scenes/upgrade_screen.tscn"

@onready var cooking: Node2D = $Cooking
@onready var skating: SkatingArea = $Skating
@onready var cooking_hud: CookingHUD = $Cooking/HUD
@onready var cooking_camera: Camera2D = $Cooking/Camera2D
@onready var skating_camera: Camera2D = $Skating/Node2D/CharacterBody2D/Camera2D
@onready var stove: Stove = $Cooking/Stove
@onready var skater: CharacterBody2D = $Skating/Node2D/CharacterBody2D
@onready var cooking_button: Button = $SceneSwitcher/HBoxContainer/CookingButton
@onready var skating_button: Button = $SceneSwitcher/HBoxContainer/SkatingButton
@onready var day_timer: Timer = $DayTimer
@onready var day_timer_label: Label = $SceneSwitcher/HBoxContainer/DayTimerLabel
@onready var reset_park_button: Button = $SceneSwitcher/HBoxContainer/ResetParkButton

var current_day: int = 1


func _ready() -> void:
	OrderManager.clear_orders()
	OrderManager.paused = false
	PlayerData.sync_to_order_manager()
	PlayerData.apply_stats_to_stove(stove)
	PlayerData.apply_stats_to_player(skater)
	_update_day_button_text()
	show_scene(cooking)
	_update_timer_label()


func _process(_delta: float) -> void:
	_update_timer_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		show_scene(skating if cooking.visible else cooking)
		get_viewport().set_input_as_handled()


func show_scene(scene: Node2D) -> void:
	var is_cooking := scene == cooking
	if is_cooking:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	cooking.visible = is_cooking
	cooking.process_mode = Node.PROCESS_MODE_INHERIT if is_cooking else Node.PROCESS_MODE_DISABLED
	if cooking_hud:
		cooking_hud.visible = is_cooking

	skating.visible = not is_cooking
	skating.process_mode = Node.PROCESS_MODE_DISABLED if is_cooking else Node.PROCESS_MODE_INHERIT

	if is_cooking and cooking_camera:
		cooking_camera.make_current()
	elif not is_cooking and skating_camera:
		skating_camera.make_current()

	cooking_button.disabled = is_cooking
	skating_button.disabled = not is_cooking


func _update_timer_label() -> void:
	var seconds_left: int = ceili(day_timer.time_left)
	var mins: int = seconds_left / 60
	var secs: int = seconds_left % 60
	day_timer_label.text = "Day %d | %02d:%02d" % [PlayerData.day, mins, secs]


func _on_cooking_button_pressed() -> void:
	show_scene(cooking)


func _on_skating_button_pressed() -> void:
	show_scene(skating)


func _on_reset_park_button_pressed() -> void:
	current_day += 1
	_update_day_button_text()
	if skating:
		skating.regenerate_park(current_day, true)
	if cooking.visible and cooking_hud:
		cooking_hud.show_toast("Day %d: New skatepark layout generated!" % current_day, Color("ffd166"))


func _update_day_button_text() -> void:
	if reset_park_button:
		reset_park_button.text = "New Day: Reset Park (Day %d)" % current_day


func _on_day_timer_timeout() -> void:
	PlayerData.sync_from_order_manager()
	OrderManager.clear_orders()
	OrderManager.paused = true
	PlayerData.save_data()
	get_tree().change_scene_to_file(UPGRADE_SCENE_PATH)
