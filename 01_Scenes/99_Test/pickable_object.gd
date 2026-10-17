extends RigidBody3D
class_name PickableObject

const REACH := 5.0              # distancia máxima para agarrar
const MAX_IMPULSE := 60.0       # límite de seguridad del lanzamiento
const MAX_DROP_SPEED := 30.0
const RELEASE_GRACE := 0.4      # segundos sin colisión con quien lo acaba de soltar
const BREAK_GRACE := 1.0        # no se comprueba el atasco hasta pasado este tiempo desde que se coge

@export_group("Agarre")
## Con qué fuerza tira hacia la mano. Más alto = más rígido y rápido.
@export var follow_speed: float = 20.0
## Velocidad máxima (m/s) con la que se acerca a la mano.
@export var max_follow_speed: float = 15.0
## Con qué fuerza recupera su orientación. Más alto = gira antes.
@export var turn_speed: float = 15.0
## Velocidad máxima de giro (rad/s).
@export var max_turn_speed: float = 20.0
## Si queda más lejos que esto de la mano (atascado), se suelta.
@export var break_distance: float = 2.5

## ID del peer que lo sujeta (0 = nadie). Lo replica el servidor.
var holder_id := 0:
	set(value):
		if value == holder_id:
			return
		holder_id = value
		if is_node_ready():
			_apply_hold_state()

var _hand: Node3D = null
var _holder_body = null          # cuerpo de quien lo sujeta (sin tipo: puede liberarse)
var _grab_rot_offset := Basis.IDENTITY   # orientación al cogerlo, relativa a la mano
var _hold_time := 0.0
var _transform_sync: MultiplayerSynchronizer

func _ready() -> void:
	add_to_group("pickable")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_create_synchronizers()
	_apply_hold_state()

func _create_synchronizers() -> void:
	# 1) Quién lo sujeta
	var state_cfg := SceneReplicationConfig.new()
	_add_prop(state_cfg, ":holder_id")
	var state_sync := MultiplayerSynchronizer.new()
	state_sync.name = "StateSync"
	state_sync.replication_config = state_cfg
	add_child(state_sync)

	# 2) Posición y rotación: las envía el servidor a todos
	var tr_cfg := SceneReplicationConfig.new()
	_add_prop(tr_cfg, ":position")
	_add_prop(tr_cfg, ":quaternion")
	_transform_sync = MultiplayerSynchronizer.new()
	_transform_sync.name = "TransformSync"
	_transform_sync.replication_config = tr_cfg
	add_child(_transform_sync)

func _add_prop(cfg: SceneReplicationConfig, path: String) -> void:
	var p := NodePath(path)
	cfg.add_property(p)
	cfg.property_set_spawn(p, false)
	cfg.property_set_replication_mode(p, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

func _physics_process(delta: float) -> void:
	_update_freeze()
	if holder_id == 0:
		return
	var is_server := multiplayer.is_server()
	# Solo el servidor y quien lo sujeta necesitan la excepción de colisión con el jugador
	if not is_server and holder_id != multiplayer.get_unique_id():
		return
	var player := _get_player(holder_id)
	if player == null:
		if is_server:
			_server_release(Vector3.ZERO, Vector3.ZERO)   # el que lo sujetaba se desconectó
		return
	_bind_holder(player)
	if not is_server:
		return
	if not is_instance_valid(_hand):
		_hand = _get_hand_of(player)
	_hold_time += delta
	# Si se ha atascado lejos de la mano, se suelta
	if _hand != null and _hold_time > BREAK_GRACE \
			and global_position.distance_to(_hand.global_position) > break_distance:
		_server_release(Vector3.ZERO, Vector3.ZERO)

func _update_freeze() -> void:
	# Solo el servidor simula la física; los clientes reciben posición y rotación
	freeze = not multiplayer.is_server()

## El servidor guía el objeto hacia la mano usando velocidades; el resto lo hace el motor
## (choques, apoyos, rozamientos), por eso al chocar cambia de rotación.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if holder_id == 0 or not multiplayer.is_server():
		return
	if not is_instance_valid(_hand):
		_hand = _get_hand_of(_get_player(holder_id))
	if _hand == null:
		return

	# Posición: se acerca a la mano
	var to_hand := _hand.global_position - state.transform.origin
	state.linear_velocity = (to_hand * follow_speed).limit_length(max_follow_speed)

	# Rotación: tiende a la orientación con la que lo cogiste (relativa a la mano)
	var target_basis := _hand.global_basis.orthonormalized() * _grab_rot_offset
	var target := Quaternion(target_basis.orthonormalized())
	var current := Quaternion(state.transform.basis.orthonormalized())
	var diff := target * current.inverse()
	if diff.w < 0.0:
		diff = -diff   # camino de giro más corto
	diff = diff.normalized()
	state.angular_velocity = (diff.get_axis() * diff.get_angle() * turn_speed).limit_length(max_turn_speed)

func _apply_hold_state() -> void:
	var held := holder_id != 0
	can_sleep = not held        # un cuerpo dormido dejaría de seguir la mano
	_hand = null
	_hold_time = 0.0
	if not held:
		_unbind_holder()
	_update_freeze()
	if held:
		sleeping = false

# ---------- Colisión con quien lo sujeta ----------

func _bind_holder(body) -> void:
	if not is_instance_valid(body) or not body is PhysicsBody3D:
		return
	if body == _holder_body:
		return
	_holder_body = body
	add_collision_exception_with(body)

func _unbind_holder() -> void:
	var body = _holder_body
	_holder_body = null
	if is_instance_valid(body):
		# Mantenemos la excepción un instante para que no te golpee al salir
		get_tree().create_timer(RELEASE_GRACE).timeout.connect(_remove_exception.bind(body))

func _remove_exception(body) -> void:
	if not is_instance_valid(body):
		return
	if body == _holder_body:
		return   # lo ha vuelto a coger antes de que acabara el margen
	remove_collision_exception_with(body)

# ---------- Peticiones de los jugadores (las valida el servidor) ----------

@rpc("any_peer", "call_local", "reliable")
func request_pick() -> void:
	if not multiplayer.is_server() or holder_id != 0:
		return
	var sender := _sender_id()
	var player := _get_player(sender)
	var hand := _get_hand_of(player)
	if hand == null:
		return
	if hand.global_position.distance_to(global_position) > REACH:
		return
	# Conserva la orientación que tenía, relativa a la mano
	_grab_rot_offset = hand.global_basis.orthonormalized().inverse() * global_basis.orthonormalized()
	_bind_holder(player)
	holder_id = sender

# El primer parámetro (transform) ya no se usa, pero se mantiene para no tocar el personaje
@rpc("any_peer", "call_local", "reliable")
func request_release(_t: Transform3D, drop_velocity: Vector3, impulse: Vector3) -> void:
	if not multiplayer.is_server() or holder_id == 0 or holder_id != _sender_id():
		return
	_server_release(drop_velocity, impulse)

func _server_release(drop_velocity: Vector3, impulse: Vector3) -> void:
	holder_id = 0   # devuelve la física normal y quita la excepción pasado un instante
	linear_velocity = drop_velocity.limit_length(MAX_DROP_SPEED)
	angular_velocity = Vector3.ZERO
	if impulse != Vector3.ZERO:
		apply_central_impulse(impulse.limit_length(MAX_IMPULSE))

func _sender_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()

func _get_player(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("players"):
		if p.name == str(id):
			return p as Node3D
	return null

func _get_hand_of(player: Node3D) -> Node3D:
	if player == null:
		return null
	return player.get("hand") as Node3D
