extends Node3D

const CHARACTER_TEST = preload("uid://bxi31xk3ylcxn")

@onready var spawnpoint: Node3D = %Spawnpoint
@onready var server_id_text: Label = %SERVER_ID_TEXT


func _ready() -> void:
	server_id_text.text = "ID DEL SERVIDOR: " + str(SteamManager.lobby_id)

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is CharacterBody3D:
		SteamManager.initialize_player(node, spawnpoint.global_position)
