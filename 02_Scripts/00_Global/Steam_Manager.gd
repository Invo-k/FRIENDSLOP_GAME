extends Node

const LOBBY_TYPE := Steam.LOBBY_TYPE_PUBLIC
const MAX_MEMBERS : int = 4
var lobby_id: int = 0
var peer: SteamMultiplayerPeer
var spawnpoint: Vector3 = Vector3(0.0, 5.8, 0.0)
var STEAM_USERNAME : String

var players: Array[CharacterBody3D]
var is_host := false
var is_joining := false
const CHARACTER_TEST = preload("uid://bxi31xk3ylcxn")

const CODE_CHARACTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
var lobby_codes: Dictionary = {}



func _ready() -> void:
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(on_lobby_created)
	Steam.lobby_joined.connect(on_lobby_joined)
	Steam.join_requested.connect(on_join_requested)

func _process(delta: float) -> void:
	Steam.run_callbacks()

##Emite las señales de lobby_created y lobby_joined
func host_lobby() -> void:
	Steam.createLobby(LOBBY_TYPE, MAX_MEMBERS)
	is_host = true

func join_lobby(lobby_id: int):
	is_joining = true
	Steam.joinLobby(lobby_id)

##Se llama cuando se crea un lobby en local.
func on_lobby_created(result: int, lobby_id: int) -> void:
	#crea el lobby como host
	if result == Steam.Result.RESULT_OK:
		self.lobby_id = lobby_id
		
		var code := generate_lobby_code()
		while lobby_codes.has(code):
			code = generate_lobby_code()
		lobby_codes[code] = lobby_id
		Steam.setLobbyData(lobby_id, "join_code", code)
		
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_host()
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(spawn_player)
		multiplayer.peer_disconnected.connect(remove_player)
		get_tree().change_scene_to_file("res://01_Scenes/99_Test/main_test.tscn")
		await get_tree().process_frame
		spawn_player()
		
		print("SE HA CREADO EL LOBBY. Nº DE LOBBY: ", lobby_id)
		print("ID de Steam: ", lobby_id)
		print("Código modificado del lobby: ", code)

##Se llama cuando alguien se une al lobby, después de que se cree el lobby
func on_lobby_joined(lobby_id : int, permissions: int, locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		#comprueba si creamos el lobby y ya estamos hosteando para no crear un nuevo lobby
		if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
			return
		if !is_joining:
			return
		self.lobby_id = lobby_id
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_client(Steam.getLobbyOwner(lobby_id))
		multiplayer.multiplayer_peer = peer
		get_tree().change_scene_to_file("res://01_Scenes/99_Test/main_test.tscn")
		await get_tree().process_frame
		is_joining = false

##Se llama cuando se intenta alguien unir desde la interfaz de steam.
func on_join_requested(lobby_id: int, steam_id: int) -> void:
	is_joining = true
	Steam.joinLobby(lobby_id)

##Spawnea en el servidor el jugador que acaba de unirse
func spawn_player(peer_id: int = 1) -> void:
	var new_player := CHARACTER_TEST.instantiate() as CharacterBody3D
	new_player.name = str(peer_id)
	var main := get_tree().current_scene
	main.add_child(new_player, true)
	initialize_player(new_player, main.get_node("%Spawnpoint").global_position)

##Coloca al jugador que se acaba de unir en el spawn correspondiente
func initialize_player(player: CharacterBody3D, spawnpoint: Vector3) -> void:
	player.position = spawnpoint
	for other in players:
		player.add_collision_exception_with(other)
	players.append(player)

##Para eleminar al jugador cuando se desconecta
func remove_player(id: int):
	if !self.has_node(str(id)):
		return
	
	players.erase(id)
	self.get_node(str(id)).queue_free()

func generate_lobby_code() -> String:
	var code := ""

	for i in range(CODE_LENGTH):
		var index := randi_range(0, CODE_CHARACTERS.length() - 1)
		code += CODE_CHARACTERS[index]

	return code.insert(3, "-")
