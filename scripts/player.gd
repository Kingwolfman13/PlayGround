extends CharacterBody3D
class_name FPSPlayer

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_speed: float = 4.8
@export var mouse_sensitivity: float = 0.002
@export var touch_look_sensitivity: float = 0.0035

const EYE_HEIGHT := 1.62

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interactor: RayCast3D = $Head/Camera3D/Interactor
@onready var footsteps: AudioStreamPlayer = $Footsteps

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var controls_enabled := true
var touch_mode := false
var main: Node
var bob_time := 0.0
var land_offset := 0.0
var footstep_timer := 0.0
var was_on_floor := true
var saved_layers := 0
var saved_mask := 0

func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if interactor:
		interactor.add_exception(self)
	if footsteps and ResourceLoader.exists("res://assets/audio/footstep.wav"):
		footsteps.stream = load("res://assets/audio/footstep.wav")
	if not touch_mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look(event.relative)

func add_look(relative: Vector2) -> void:
	if not controls_enabled:
		return
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x - relative.y * mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))

func add_touch_look(relative: Vector2) -> void:
	if not controls_enabled:
		return
	rotate_y(-relative.x * touch_look_sensitivity)
	head.rotation.x = clampf(head.rotation.x - relative.y * touch_look_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif was_on_floor == false:
		land_offset = -0.14
	was_on_floor = is_on_floor()

	if controls_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_speed

	var input_dir := Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	direction.y = 0.0
	direction = direction.normalized()

	var sprinting := controls_enabled and Input.is_action_pressed("sprint") and input_dir.length() > 0.1
	var speed := sprint_speed if sprinting else walk_speed
	var target := direction * speed
	var blend := 1.0 - exp(-12.0 * delta)
	velocity.x = lerp(velocity.x, target.x, blend)
	velocity.z = lerp(velocity.z, target.z, blend)
	move_and_slide()

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.4:
		bob_time += delta * (10.0 if sprinting else 7.5)
		land_offset = lerpf(land_offset, 0.0, delta * 8.0)
		head.position.y = EYE_HEIGHT + sin(bob_time) * (0.045 if sprinting else 0.03) + land_offset
		camera.rotation.z = lerpf(camera.rotation.z, sin(bob_time * 0.5) * 0.006, delta * 8.0)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_timer = 0.34 if sprinting else 0.46
			_play_footstep()
	else:
		head.position.y = lerpf(head.position.y, EYE_HEIGHT + land_offset, delta * 10.0)
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, delta * 8.0)
		land_offset = lerpf(land_offset, 0.0, delta * 8.0)
		footstep_timer = 0.0

	var target_fov := 83.0 if sprinting and horizontal_speed > 3.0 else 76.0
	camera.fov = lerpf(camera.fov, target_fov, delta * 5.0)

func _play_footstep() -> void:
	if footsteps and footsteps.stream:
		footsteps.pitch_scale = randf_range(0.88, 1.12)
		footsteps.volume_db = randf_range(-18.0, -13.0)
		footsteps.play()

func enter_vehicle(_car: Node3D) -> void:
	controls_enabled = false
	velocity = Vector3.ZERO
	saved_layers = collision_layer
	saved_mask = collision_mask
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	camera.current = false
	visible = false
	interactor.enabled = false
	set_physics_process(false)

func exit_vehicle(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	collision_layer = saved_layers if saved_layers != 0 else 2
	collision_mask = saved_mask if saved_mask != 0 else 1
	camera.current = true
	visible = true
	interactor.enabled = true
	controls_enabled = true
	set_physics_process(true)
	head.position.y = EYE_HEIGHT
	if not touch_mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func respawn(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	head.rotation.x = 0.0
	head.position.y = EYE_HEIGHT
	velocity = Vector3.ZERO
	camera.current = true
	visible = true
	interactor.enabled = true
	controls_enabled = true
	set_physics_process(true)
	collision_layer = 2
	collision_mask = 1 | 4

func set_touch_mode(enabled: bool) -> void:
	touch_mode = enabled
	if touch_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func get_interact_prompt() -> String:
	if interactor and interactor.has_method("get_prompt"):
		return interactor.get_prompt()
	return ""
