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
@onready var camera_3d: Camera3D = %Camera3D
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int()) #para determinar la autoridad del personaje a la hora de cargarlo.

func _ready() -> void:
	camera_3d.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_apply_player_color()
	steam_name.text = Steam.getPersonaName()

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


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera_3d.rotate_x(-event.relative.y * SENSITIVITY)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80),deg_to_rad(60))
	
	if Input.is_action_just_pressed("esc"):
		get_tree().quit()

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
