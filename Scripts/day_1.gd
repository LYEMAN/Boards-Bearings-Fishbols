extends Node2D

@onready var cooking: Node2D = $Cooking
@onready var skating: Node2D = $Skating
@onready var cooking_hud: CanvasLayer = $Cooking/HUD
@onready var cooking_camera: Camera2D = $Cooking/Camera2D
@onready var skating_camera: Camera2D = $Skating/Node2D/CharacterBody2D/Camera2D
@onready var cooking_button: Button = $SceneSwitcher/HBoxContainer/CookingButton
@onready var skating_button: Button = $SceneSwitcher/HBoxContainer/SkatingButton


func _ready() -> void:
	show_scene(cooking)


func show_scene(scene: Node2D) -> void:
	var is_cooking := scene == cooking

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
