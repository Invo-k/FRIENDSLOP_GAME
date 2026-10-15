extends Node

signal host_created()

const LOBBY_TYPE := Steam.LOBBY_TYPE_FRIENDS_ONLY
const MAX_MEMBERS : int = 4

var peer: SteamMultiplayerPeer

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


##Se llama cuando se crea un lobby en local.
func on_lobby_created(connect: int, lobby_id: int) -> void:
	#crea el lobby como host
	if connect == Steam.RESULT_OK:
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_host()
		multiplayer.multiplayer_peer = peer
		host_created.emit()

##Se llama cuando alguien se une al lobby, después de que se cree el lobby
func on_lobby_joined(lobby_id : int, permissions: int, locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		#comprueba si creamos el lobby y ya estamos hosteando para no crear un nuevo lobby
		if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
			return
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_host()
		multiplayer.multiplayer_peer = peer

##Se llama cuando se intenta alguien unir desde la interfaz de steam.
func on_join_requested(lobby_id: int, steam_id: int) -> void:
	Steam.joinLobby(lobby_id)
