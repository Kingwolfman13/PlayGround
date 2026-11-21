extends VehicleBody3D

@export var engine_force_value := 900.0
@export var brake_force_value := 45.0
@export var steering_limit := 0.45

var player: CharacterBody3D
var occupied := false
var chase_camera: Camera3D

func _ready() -> void:
	set_meta("on_interact", Callable(self, "enter_vehicle"))
	chase_camera = Camera3D.new()
	chase_camera.position = Vector3(0, 3.2, 7.5)
	chase_camera.current = false
	add_child(chase_camera)
	chase_camera.look_at(global_position)

func enter_vehicle(_player: CharacterBody3D) -> void:
	if occupied:
		return
	player = _player
	occupied = true
	player.visible = false
	player.driving = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	chase_camera.current = true
	set_meta("on_interact", Callable(self, "exit_vehicle"))

func exit_vehicle(_player: CharacterBody3D) -> void:
	if not occupied:
		return
	occupied = false
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.driving = false
	player.position = global_position + global_transform.basis.x * 3.0
	player.position.y = 1.0
	player.get_node("Head/Camera3D").current = true
	chase_camera.current = false
	set_meta("on_interact", Callable(self, "enter_vehicle"))

func _physics_process(delta: float) -> void:
	if not occupied:
		engine_force = 0.0
		brake = 0.0
		steering = move_toward(steering, 0.0, 2.0 * delta)
		return
	engine_force = Input.get_axis("move_back", "move_forward") * engine_force_value
	brake = brake_force_value if Input.is_action_pressed("jump") else 0.0
	steering = move_toward(steering, -Input.get_axis("move_left", "move_right") * steering_limit, 2.5 * delta)
	if Input.is_action_just_pressed("exit_vehicle"):
		exit_vehicle(player)
