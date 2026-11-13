extends Node3D

func _on_start_button_pressed():
	# Замени путь на свою игровую сцену!
	get_tree().change_scene_to_file("res://scenes/main.tscn") 

func _on_exit_button_pressed():
	get_tree().quit()
