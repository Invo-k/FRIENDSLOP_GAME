extends Node3D

const CHARACTER_TEST = preload("uid://bxi31xk3ylcxn")

@onready var spawnpoint: Node3D = %Spawnpoint

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is CharacterBody3D:
		SteamManager.initialize_player(node, spawnpoint.global_position)
