extends Control

# Функция для кнопки "Начать"
func _on_start_button_pressed():
	# ВАЖНО: замени "res://Main.tscn" на реальный путь к твоей игровой сцене!
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# Функция для кнопки "Выход"
func _on_quit_button_pressed():
	get_tree().quit()
