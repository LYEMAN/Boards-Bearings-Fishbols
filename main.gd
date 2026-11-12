extends Node2D

const FISHBALL_SCENE: PackedScene = preload("res://fishball.tscn")

@onready var wok: Node2D = $Wok

func spawn_fishball() -> void:
	print("spawning fishball")
	var fishball := FISHBALL_SCENE.instantiate()
	add_child(fishball)
	fishball.global_position = wok.global_position + Vector2(randf_range(100, 1000), -150)
	print("spawned at ", fishball.global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Space / Enter, for testing
		spawn_fishball()
