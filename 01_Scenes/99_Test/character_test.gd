extends CharacterBody3D

@export var SPEED = 5.0
@export var JUMP_VELOCITY = 4.5
@export var SENSITIVITY : float = 0.003
@export var BOB_FREQ = 2.0
@export var BOB_AMP = 0.08
@export var BASE_FOV = 75.0
@export var FOV_CHANGE = 1.5
var T_BOB = 0.0

@onready var steam_name: Label3D = %SteamName
@onready var head: Node3D = %Head
@onready var hand: Node3D = %Hand
@onready var camera_3d: Camera3D = %Camera3D
@onready var ray_cast_object: RayCast3D = %RayCastObject
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var nose: MeshInstance3D = %Nose
const TEST_MENU_AUDIO = preload("uid://cvppsq20d7hl2")

var held_object: RigidBody3D = null

var held_object_collision_layer: int = 1
var held_object_collision_mask: int = 1

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int()) #para determinar la autoridad del personaje a la hora de cargarlo.

func _ready() -> void:
	GlobalData.is_on_menu = false
	camera_3d.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_apply_player_color()
	steam_name.text = Steam.getPersonaName()
	nose.visible = not is_multiplayer_authority()

func _apply_player_color() -> void:
	var mesh := mesh_instance_3d as MeshInstance3D
	var base_mat := mesh.get_active_material(0)
	var new_mat: StandardMaterial3D
	if base_mat is StandardMaterial3D:
		new_mat = base_mat.duplicate() as StandardMaterial3D
	else:
		new_mat = StandardMaterial3D.new()

	new_mat.albedo_color = Color(randf_range(0,1), randf_range(0,1), randf_range(0,1))

	mesh.set_surface_override_material(0, new_mat)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_jump(delta)
	
	move_and_slide()
	
	handle_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera_3d.rotate_x(-event.relative.y * SENSITIVITY)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80),deg_to_rad(60))
	
	if Input.is_action_just_pressed("esc"):
		get_tree().quit()
	
	if Input.is_action_just_pressed("tab"):
		var audio_menu = TEST_MENU_AUDIO.instantiate()
		call_deferred("add_child", audio_menu)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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
	if Input.is_action_just_pressed("interact"):
		if held_object == null:
			try_pick_object()

	if held_object != null:
		if Input.is_action_pressed("interact"):
			update_held_object()
		else:
			drop_object()


func try_pick_object() -> void:
	ray_cast_object.force_raycast_update()

	if not ray_cast_object.is_colliding():
		return

	var object := ray_cast_object.get_collider()

	if not object is RigidBody3D:
		return

	if not object.is_in_group("pickable"):
		return

	held_object = object as RigidBody3D

	held_object_collision_layer = held_object.collision_layer
	held_object_collision_mask = held_object.collision_mask

	# Desactivar la física mientras lo sujetamos.
	held_object.freeze = true
	held_object.linear_velocity = Vector3.ZERO
	held_object.angular_velocity = Vector3.ZERO

	# Evitar colisiones mientras está en la mano.
	held_object.collision_layer = 0
	held_object.collision_mask = 0

	update_held_object()


func update_held_object() -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return

	held_object.global_transform = hand.global_transform


func drop_object() -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return

	var object_to_drop := held_object
	held_object = null

	# Restaurar las colisiones originales.
	object_to_drop.collision_layer = held_object_collision_layer
	object_to_drop.collision_mask = held_object_collision_mask

	# Devolver el control a la física.
	object_to_drop.freeze = false
	object_to_drop.linear_velocity = velocity
	object_to_drop.angular_velocity = Vector3.ZERO
