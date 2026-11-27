extends Control



func _on_quit_pressed() -> void: 
	get_tree().quit()

func _on_start_pressed() -> void: 
	print("Toink")
	PlayerData.switch_day_scene()
