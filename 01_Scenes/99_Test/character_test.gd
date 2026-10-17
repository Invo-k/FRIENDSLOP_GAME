extends CharacterBody3D
class_name PlayerCharacter

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 4.5
@export var BOB_FREQ: float = 2.0
@export var BOB_AMP: float = 0.08
@export var BASE_FOV: float = 75.0
@export var FOV_CHANGE: float = 1.5
@export var SENSITIVITY : float = 0.003
var T_BOB = 0.0

@onready var player_ui: CanvasLayer = %PlayerUI
@onready var steam_name: Label3D = %SteamName
@onready var head: Node3D = %Head
@onready var hand: Node3D = %Hand
@onready var camera_3d: Camera3D = %Camera3D
@onready var ray_cast_object: RayCast3D = %RayCastObject
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var nose: MeshInstance3D = %Nose
@onready var throw_charge_bar: ProgressBar = %ThrowChargeBar
const TEST_MENU_AUDIO = preload("uid://cvppsq20d7hl2")

## Se replica desde el dueño del personaje (ver paso del editor más abajo)
@export var player_name := "":
	set(value):
		player_name = value
		if is_instance_valid(steam_name):
			steam_name.text = value

var held_object: PickableObject = null
var audio_menu: Control = null
var is_charging_throw := false
var throw_charge := 0.0
var _released_object: PickableObject = null   # suelta enviada, esperando confirmación

@export_subgroup("LANZAMIENTO ITEMS")
##Al pulsar el botón "throw", es la fuerza minima de lanzamiento.
@export var MIN_THROW_FORCE: float = 3.0
##Al pulsar el botón "throw", es la fuerza máxima de lanzamiento.
@export var MAX_THROW_FORCE: float = 18.0
##Tiempo que tarda en llegar al máximo de lanzaminto.
@export var THROW_CHARGE_TIME: float = 1.5
##Porcentaje de cuanto lanza los objetos al soltarlos solo moviendo la cámara
@export var SWING_MULTIPLIER: float = 1.0   # sube para un efecto más exagerado
 ##Tope de velocidad añadida por el giro de la cámara al soltar un objeto.
@export var MAX_SWING_SPEED: float = 10.0  

var _last_yaw := 0.0
var _last_pitch := 0.0
var _swing_velocity := Vector3.ZERO

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int()) #para determinar la autoridad del personaje a la hora de cargarlo.

func _ready() -> void:
	add_to_group("players")
	var is_mine := is_multiplayer_authority()
	camera_3d.current = is_mine
	player_ui.visible = is_mine
	throw_charge_bar.visible = false
	nose.visible = not is_mine
	ray_cast_object.add_exception(self)
	_apply_player_color()
	if is_mine:
		GlobalData.is_on_menu = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		player_name = Steam.getPersonaName()
	steam_name.text = player_name
	_last_yaw = head.rotation.y
	_last_pitch = camera_3d.rotation.x

func _apply_player_color() -> void:
	var base_mat := mesh_instance_3d.get_active_material(0)
	var new_mat: StandardMaterial3D
	if base_mat is StandardMaterial3D:
		new_mat = base_mat.duplicate() as StandardMaterial3D
	else:
		new_mat = StandardMaterial3D.new()
	# Semilla = ID del jugador: todos los clientes ven el mismo color
	var rng := RandomNumberGenerator.new()
	rng.seed = name.to_int()
	new_mat.albedo_color = Color(rng.randf(), rng.randf(), rng.randf())
	mesh_instance_3d.set_surface_override_material(0, new_mat)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	_update_swing(delta)
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _menu_open():
		if is_on_floor():
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		move_and_jump(delta)
	move_and_slide()
	if not _menu_open():
		handle_interaction()

# _input se ejecuta antes que la interfaz, así Tab también cierra el menú
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("tab"):
		_toggle_audio_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("esc"):
		get_tree().quit()
	if _menu_open():
		return
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera_3d.rotate_x(-event.relative.y * SENSITIVITY)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(60))

func _menu_open() -> bool:
	return is_instance_valid(audio_menu)

func _toggle_audio_menu() -> void:
	if _menu_open():
		audio_menu.queue_free()
		return
	audio_menu = TEST_MENU_AUDIO.instantiate()
	player_ui.add_child(audio_menu)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	audio_menu.tree_exited.connect(_on_audio_menu_closed)

func _on_audio_menu_closed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func move_and_jump(delta):
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if Input.is_action_pressed("ctrl"):
			velocity.y = JUMP_VELOCITY - (JUMP_VELOCITY / 4) 
		else:
			velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():	
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		
		if Input.is_action_pressed("shift"):
			velocity.x = direction.x * (SPEED + (SPEED / 2))
			velocity.z = direction.z * (SPEED + (SPEED / 2))
		
		elif Input.is_action_pressed("ctrl"):
			velocity.x = direction.x * (SPEED - (SPEED / 2))
			velocity.z = direction.z * (SPEED - (SPEED / 2))
			
	else:
		velocity.x = lerp(velocity.x, direction.x * SPEED, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * SPEED, delta * 2.0)
	
	T_BOB += delta * velocity.length() * float(is_on_floor())
	camera_3d.transform.origin = head_bob(T_BOB)
	camera_fov_edit(delta)


func head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	return pos
	
func camera_fov_edit(delta):
	if is_on_floor():
		if Input.is_action_pressed("shift"):
			var velocity_clamped = clamp(velocity.length(), 8.5, (SPEED + (SPEED / 2)) * 2)
			var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
			camera_3d.fov = lerp(camera_3d.fov, target_fov, delta * 8.0)
		
		elif Input.is_action_pressed("ctrl"):
			var target_fov = BASE_FOV / 1.2
			camera_3d.fov = lerp(camera_3d.fov, target_fov , delta * 8.0)
		
		else:
			camera_3d.fov = lerp(camera_3d.fov, BASE_FOV, delta * 8.0)

func handle_interaction() -> void:
	_refresh_held_object()

	if held_object == null:
		_cancel_charge()
		if Input.is_action_just_pressed("interact"):
			try_pick_object()
		return

	if Input.is_action_just_pressed("throw"):
		is_charging_throw = true
		throw_charge = 0.0
		throw_charge_bar.value = 0.0
		throw_charge_bar.visible = true

	if is_charging_throw:
		if Input.is_action_pressed("throw"):
			throw_charge = minf(throw_charge + get_physics_process_delta_time(), THROW_CHARGE_TIME)
			throw_charge_bar.value = (throw_charge / THROW_CHARGE_TIME) * 100.0
		else:
			throw_held_object()   # soltó el botón (no depende de just_released)
			return

	# Si suelta interact sin estar cargando, deja caer el objeto
	if not Input.is_action_pressed("interact") and not is_charging_throw:
		drop_object()

## El servidor decide quién sujeta qué; aquí solo miramos si algo me tiene como dueño
func _refresh_held_object() -> void:
	var my_id := multiplayer.get_unique_id()
	if is_instance_valid(_released_object) and _released_object.holder_id != my_id:
		_released_object = null   # el servidor ya confirmó la suelta
	if is_instance_valid(held_object) and held_object.holder_id == my_id:
		return
	held_object = null
	for obj in get_tree().get_nodes_in_group("pickable"):
		if obj is PickableObject and obj != _released_object and obj.holder_id == my_id:
			held_object = obj
			break

func try_pick_object() -> void:
	ray_cast_object.force_raycast_update()
	if not ray_cast_object.is_colliding():
		return
	var object := ray_cast_object.get_collider() as PickableObject
	if object == null or object.holder_id != 0:
		return
	object.request_pick.rpc_id(1)   # pedimos al servidor; él confirma

func drop_object() -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return
	var swing := (_swing_velocity * SWING_MULTIPLIER).limit_length(MAX_SWING_SPEED)
	held_object.request_release.rpc_id(1, held_object.global_transform, velocity + swing, Vector3.ZERO)
	_released_object = held_object
	held_object = null

func throw_held_object() -> void:
	if not is_instance_valid(held_object):
		held_object = null
		_cancel_charge()
		return
	var charge_ratio := clampf(throw_charge / THROW_CHARGE_TIME, 0.0, 1.0)
	var throw_force := lerpf(MIN_THROW_FORCE, MAX_THROW_FORCE, charge_ratio)
	var throw_direction := -camera_3d.global_transform.basis.z
	held_object.request_release.rpc_id(1, held_object.global_transform, Vector3.ZERO, throw_direction * throw_force)
	_released_object = held_object
	held_object = null
	_cancel_charge()

func _cancel_charge() -> void:
	is_charging_throw = false
	throw_charge = 0.0
	throw_charge_bar.value = 0.0
	throw_charge_bar.visible = false

## Velocidad que aporta el giro de la cámara a la mano (v = ω × r), suavizada
func _update_swing(delta: float) -> void:
	var yaw := head.rotation.y
	var pitch := camera_3d.rotation.x
	var yaw_rate := angle_difference(_last_yaw, yaw) / delta
	var pitch_rate := angle_difference(_last_pitch, pitch) / delta
	_last_yaw = yaw
	_last_pitch = pitch

	var omega := head.global_basis.y * yaw_rate + camera_3d.global_basis.x * pitch_rate
	var r := hand.global_position - camera_3d.global_position
	var raw := omega.cross(r)
	_swing_velocity = _swing_velocity.lerp(raw, clampf(delta * 15.0, 0.0, 1.0))
