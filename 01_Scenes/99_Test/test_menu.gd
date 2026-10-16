extends Control
@onready var host: Button = $MarginContainer/VBoxContainer/HOST
@onready var join: Button = $MarginContainer/VBoxContainer/JOIN
@onready var id_prompt: LineEdit = $MarginContainer/VBoxContainer/ID_prompt
const TEST_MENU_AUDIO = preload("uid://cvppsq20d7hl2")

func _ready() -> void:
	GlobalData.is_on_menu = true

func _on_host_pressed() -> void:
	SteamManager.host_lobby()


func _on_join_pressed() -> void:
	get_tree().change_scene_to_file("res://01_Scenes/99_Test/main_test.tscn")
	SteamManager.join_lobby(id_prompt.text.to_int())

func _on_id_prompt_text_changed(new_text: String) -> void:
	join.disbale = (new_text.length() == 0)


func _on_ajustes_pressed() -> void:
	var audio_menu = TEST_MENU_AUDIO.instantiate()
	call_deferred("add_child", audio_menu)
	
