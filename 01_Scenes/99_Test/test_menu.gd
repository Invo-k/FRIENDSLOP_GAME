extends Control
@onready var host: Button = $MarginContainer/VBoxContainer/HOST
@onready var join: Button = $MarginContainer/VBoxContainer/JOIN
@onready var id_prompt: LineEdit = $MarginContainer/VBoxContainer/ID_prompt

func _on_host_pressed() -> void:
	SteamManager.host_lobby()


func _on_join_pressed() -> void:
	get_tree().change_scene_to_file("res://01_Scenes/99_Test/main_test.tscn")
	SteamManager.join_lobby(id_prompt.text.to_int())

func _on_id_prompt_text_changed(new_text: String) -> void:
	join.disbale = (new_text.length() == 0)
