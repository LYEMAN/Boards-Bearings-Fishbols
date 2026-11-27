extends Node2D

@onready var cooking: Node2D = $Cooking
@onready var skating: SkatingArea = $Skating
@onready var cooking_hud: CookingHUD = $Cooking/HUD
@onready var cooking_camera: Camera2D = $Cooking/Camera2D
@onready var skating_camera: Camera2D = $Skating/Node2D/CharacterBody2D/Camera2D
@onready var cooking_button: Button = $SceneSwitcher/HBoxContainer/CookingButton
@onready var skating_button: Button = $SceneSwitcher/HBoxContainer/SkatingButton
@onready var reset_park_button: Button = $SceneSwitcher/HBoxContainer/ResetParkButton

var current_day: int = 1


func _ready() -> void:
	_update_day_button_text()
	show_scene(cooking)


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
