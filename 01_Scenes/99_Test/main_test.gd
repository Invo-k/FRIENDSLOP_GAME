extends Node2D

const CHARACTER_TEST = preload("uid://bnr8cpkdbnw2m")


var players: Array[CharacterBody2D]

func _ready() -> void:
	SteamNetworking.host_created.connect(on_host_created)

func on_host_created() -> void:
	#Hace spawnear el jugador al server
	spawn_player(multiplayer.get_unique_id())
	multiplayer.peer_connected.connect(spawn_player)

##Spawnea en el servidor el jugador que acaba de unirse
func spawn_player(peer_id:int) -> void:
	var new_player := CHARACTER_TEST.instantiate() as CharacterBody2D
	new_player.name = str(peer_id)
	add_child(new_player)
	initialize_player(new_player)

func initialize_player(player: CharacterBody2D) -> void:
	player.position = %Spawnpoint.position
	for other in players:
		player.add_collision_exception_with(other)
	players.append(player)


func _on_host_pressed() -> void:
	SteamNetworking.host_lobby()
	%CanvasLayer.hide()


func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is CharacterBody2D:
		initialize_player(node)
