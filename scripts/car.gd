extends VehicleBody3D
class_name RiverCar

signal entered(car: RiverCar)
signal exited(car: RiverCar)
signal honked(car: RiverCar)

@export var display_name := "Market Coupe"
@export var body_color := Color("#4d8693")
@export var is_police := false
@export var ai_driver := false

@onready var driver_seat: Marker3D = $DriverSeat
@onready var driver_camera: Camera3D = $DriverCamera
@onready var chase_camera: Camera3D = $ChaseCamera
@onready var engine_audio: AudioStreamPlayer3D = $EngineAudio
@onready var horn_audio: AudioStreamPlayer3D = $HornAudio

var main: Node
var driver: Node3D
var target: Node3D
var active := false
var ai_active := false
var chase_mode := true
var chase_position := Vector3.ZERO
var chase_initialized := false
var stuck_time := 0.0
var reverse_time := 0.0
var flip_time := 0.0
var honk_cooldown := 0.0
var headlights_on := true
var visual_root: Node3D
var headlight_lights: Array[SpotLight3D] = []
var avoid_rays: Array[RayCast3D] = []
var engine_looping := false

func _ready() -> void:
	mass = 1100.0
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.12, 0.0)
	_setup_wheels()
	_build_visuals()
	driver_camera.current = false
	chase_camera.top_level = true
	chase_camera.current = false
	if ResourceLoader.exists("res://assets/audio/engine.wav"):
		engine_audio.stream = load("res://assets/audio/engine.wav")
		engine_audio.finished.connect(_restart_engine_loop)
	if ResourceLoader.exists("res://assets/audio/horn.wav"):
		horn_audio.stream = load("res://assets/audio/horn.wav")
	if ai_driver:
		_build_avoidance_rays()

func _setup_wheels() -> void:
	var wheels := [$WheelFL, $WheelFR, $WheelRL, $WheelRR]
	for i in range(wheels.size()):
		var wheel := wheels[i] as VehicleWheel3D
		if wheel == null:
			continue
		wheel.wheel_radius = 0.38
		wheel.wheel_rest_length = 0.18
		wheel.suspension_travel = 0.24
		wheel.suspension_stiffness = 42.0
		wheel.damping_compression = 2.1
		wheel.damping_relaxation = 2.5
		wheel.use_as_steering = i < 2
		wheel.use_as_traction = i >= 2
		if wheel.get_child_count() == 0:
			_add_wheel_mesh(wheel)

func _add_wheel_mesh(wheel: VehicleWheel3D) -> void:
	var tire := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.38
	cylinder.bottom_radius = 0.38
	cylinder.height = 0.27
	cylinder.radial_segments = 18
	tire.mesh = cylinder
	tire.position.y = -0.18
	tire.rotation.z = PI / 2.0
	tire.material_override = _mat(Color("#202326"), 0.95)
	wheel.add_child(tire)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.18
	hub_mesh.bottom_radius = 0.18
	hub_mesh.height = 0.29
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	hub.position.y = -0.18
	hub.rotation.z = PI / 2.0
	hub.material_override = _mat(Color("#9aa3a5"), 0.35, 0.5)
	wheel.add_child(hub)

func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)
	var paint := _mat(body_color, 0.32, 0.25)
	var paint_dark := _mat(body_color.darkened(0.24), 0.42, 0.2)
	var dark := _mat(Color("#1b2024"), 0.85)
	var rubber := _mat(Color("#171a1c"), 0.95)
	var glass := _mat(Color("#314d55"), 0.14, 0.35, Color("#5f95a5"), 0.1)
	var chrome := _mat(Color("#c2c9c6"), 0.22, 0.75)
	var warm := _emissive(Color("#ffe6b8"), 1.5)
	var red := _emissive(Color("#d24538"), 1.1)
	# Underbody and main hull.
	_box(visual_root, Vector3(0, -0.12, 0), Vector3(1.78, 0.16, 3.72), rubber)
	_box(visual_root, Vector3(0, 0.02, 0), Vector3(1.9, 0.5, 4.0), paint)
	_box(visual_root, Vector3(0, -0.06, 0), Vector3(1.94, 0.16, 3.5), paint_dark)
	# Hood, trunk and subtle shoulder line.
	var hood := _box(visual_root, Vector3(0, 0.25, -1.42), Vector3(1.8, 0.14, 1.12), paint)
	hood.rotation.x = deg_to_rad(-2.5)
	_box(visual_root, Vector3(0, 0.27, 1.62), Vector3(1.8, 0.14, 0.7), paint)
	_box(visual_root, Vector3(0, 0.2, 0.0), Vector3(1.93, 0.04, 3.2), paint_dark)
	# Cabin, pillars and glass.
	_box(visual_root, Vector3(0, 0.54, 0.12), Vector3(1.56, 0.4, 1.9), glass)
	_box(visual_root, Vector3(0, 0.79, 0.12), Vector3(1.5, 0.1, 1.66), paint)
	_box(visual_root, Vector3(0, 0.54, -0.82), Vector3(1.48, 0.36, 0.05), glass)
	_box(visual_root, Vector3(0, 0.54, 1.13), Vector3(1.48, 0.36, 0.05), glass)
	_box(visual_root, Vector3(0, 0.35, 1.28), Vector3(1.54, 0.05, 0.05), paint_dark)
	for x in [-0.77, 0.77]:
		for z in [-0.78, 0.96]:
			_box(visual_root, Vector3(x, 0.55, z), Vector3(0.07, 0.4, 0.1), paint)
		_box(visual_root, Vector3(x * 1.02, 0.56, 0.12), Vector3(0.04, 0.28, 1.55), glass)
		_box(visual_root, Vector3(x * 1.02, 0.18, 0.0), Vector3(0.03, 0.09, 2.45), paint_dark)
		_box(visual_root, Vector3(x * 1.03, 0.4, 0.35), Vector3(0.03, 0.045, 0.16), chrome)
		_box(visual_root, Vector3(x * 1.02, 0.58, -0.62), Vector3(0.14, 0.09, 0.26), chrome)
		# Dark wheel wells behind the tires.
		for z in [-1.28, 1.28]:
			_box(visual_root, Vector3(x * 1.0, 0.12, z), Vector3(0.02, 0.5, 0.92), dark)
	# Bumpers, grille and lights.
	_box(visual_root, Vector3(0, -0.04, -2.02), Vector3(1.98, 0.17, 0.14), chrome)
	_box(visual_root, Vector3(0, -0.04, 2.02), Vector3(1.98, 0.17, 0.14), chrome)
	_box(visual_root, Vector3(0, 0.1, -2.03), Vector3(0.92, 0.18, 0.05), dark)
	for x in [-0.64, 0.64]:
		_box(visual_root, Vector3(x, 0.1, -2.04), Vector3(0.32, 0.14, 0.04), warm)
		_box(visual_root, Vector3(x, 0.12, 2.04), Vector3(0.3, 0.12, 0.04), red)
	_box(visual_root, Vector3(0, -0.09, 2.09), Vector3(0.48, 0.13, 0.03), _mat(Color("#e7dfc6"), 0.6))
	var plate := Label3D.new()
	plate.text = "RVA 0417"
	plate.font_size = 28
	plate.pixel_size = 0.004
	plate.modulate = Color("#2b2b2b")
	plate.position = Vector3(0, -0.09, 2.115)
	visual_root.add_child(plate)
	_add_headlight(Vector3(0.64, 0.12, -2.0))
	_add_headlight(Vector3(-0.64, 0.12, -2.0))

func _add_headlight(pos: Vector3) -> void:
	var light := SpotLight3D.new()
	light.position = pos
	light.rotation_degrees = Vector3(-4, 0, 0)
	light.light_color = Color("#ffe3b0")
	light.light_energy = 2.6
	light.spot_range = 26.0
	light.spot_angle = 34.0
	light.shadow_enabled = false
	visual_root.add_child(light)
	headlight_lights.append(light)

func _build_avoidance_rays() -> void:
	for data in [Vector3(0, 0.2, -9), Vector3(-2.2, 0.2, -6), Vector3(2.2, 0.2, -6)]:
		var ray := RayCast3D.new()
		ray.target_position = data
		ray.collision_mask = 1
		ray.add_exception(self)
		add_child(ray)
		avoid_rays.append(ray)

func _process(delta: float) -> void:
	honk_cooldown = maxf(0.0, honk_cooldown - delta)
	var moving := active or ai_active
	if moving:
		var speed := linear_velocity.length()
		if engine_audio.stream and not engine_audio.playing:
			engine_audio.play()
		engine_audio.pitch_scale = clampf(0.68 + speed / 28.0, 0.68, 1.9)
		engine_audio.volume_db = -13.0
	else:
		if engine_audio.playing:
			engine_audio.stop()
	if active:
		driver_camera.current = not chase_mode
		chase_camera.current = chase_mode
		if chase_mode:
			_update_chase_camera(delta)
	if not active:
		driver_camera.current = false
		chase_camera.current = false
	_check_flip(delta)

func _update_chase_camera(delta: float) -> void:
	var desired := global_position + global_transform.basis.z * 7.4 + Vector3(0, 3.3, 0)
	if not chase_initialized:
		chase_position = desired
		chase_initialized = true
	else:
		chase_position = chase_position.lerp(desired, 1.0 - exp(-5.5 * delta))
	chase_camera.global_position = chase_position
	var look_point := global_position + Vector3(0, 1.2, 0) + (-global_transform.basis.z) * 1.5
	chase_camera.look_at(look_point, Vector3.UP)

func _physics_process(delta: float) -> void:
	if active and driver != null:
		_drive_player(delta)
	elif ai_driver and ai_active and is_instance_valid(target):
		_drive_ai(delta)
	else:
		engine_force = 0.0
		brake = 5.0
		steering = move_toward(steering, 0.0, delta * 3.0)

func _drive_player(delta: float) -> void:
	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var steer_input := Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	var forward_speed := linear_velocity.dot(-global_transform.basis.z)
	if throttle < 0.0 and forward_speed > 1.5:
		engine_force = 0.0
		brake = 18.0
	else:
		engine_force = throttle * (3800.0 if throttle >= 0.0 else 2200.0)
		brake = 0.0 if absf(throttle) > 0.05 else 6.0
	if forward_speed > 31.0:
		engine_force = 0.0
	steering = move_toward(steering, steer_input * 0.5, delta * 2.2)

func _drive_ai(delta: float) -> void:
	if not is_instance_valid(target):
		ai_active = false
		return
	var target_pos := target.global_position
	var local := to_local(target_pos)
	local.y = 0.0
	var distance := global_position.distance_to(target_pos)
	if distance < 7.0:
		engine_force = 0.0
		brake = 12.0
		steering = move_toward(steering, 0.0, delta * 4.0)
		return
	var desired_steer := clampf(local.x / maxf(absf(local.z), 3.5), -0.55, 0.55)
	var throttle := 1.0
	if local.z > 2.0:
		throttle = -0.65
		desired_steer = -desired_steer
	if avoid_rays.size() == 3:
		var front := avoid_rays[0]
		var left := avoid_rays[1]
		var right := avoid_rays[2]
		if front.is_colliding():
			if not left.is_colliding():
				desired_steer = -0.5
			elif not right.is_colliding():
				desired_steer = 0.5
			else:
				throttle = -0.7
				desired_steer = -desired_steer
	if absf(linear_velocity.length()) < 1.0 and throttle > 0.0:
		stuck_time += delta
	else:
		stuck_time = 0.0
	if stuck_time > 1.4:
		reverse_time = 1.2
		stuck_time = 0.0
	if reverse_time > 0.0:
		reverse_time -= delta
		engine_force = -850.0
		steering = move_toward(steering, -desired_steer, delta * 3.0)
	else:
		engine_force = throttle * 3400.0
		steering = move_toward(steering, desired_steer, delta * 2.6)
	brake = 0.0
	if linear_velocity.length() > 34.0:
		engine_force = 0.0

func _check_flip(delta: float) -> void:
	if not (active or ai_active):
		return
	if global_transform.basis.y.y < 0.25:
		flip_time += delta
		if flip_time > 1.6:
			flip_time = 0.0
			var yaw := rotation.y
			global_transform.basis = Basis(Vector3.UP, yaw)
			global_position.y += 1.3
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	else:
		flip_time = 0.0

func enter(player: Node3D) -> bool:
	if active or is_police or player == null:
		return false
	driver = player
	active = true
	chase_initialized = false
	if player.has_method("enter_vehicle"):
		player.enter_vehicle(self)
	if not DisplayServer.is_touchscreen_available() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	entered.emit(self)
	return true

func exit_vehicle() -> void:
	if not active:
		return
	var at := _safe_exit_position()
	var yaw := rotation.y
	if driver and driver.has_method("exit_vehicle"):
		driver.exit_vehicle(at, yaw)
	driver = null
	active = false
	chase_initialized = false
	driver_camera.current = false
	chase_camera.current = false
	engine_force = 0.0
	brake = 6.0
	if engine_audio.playing:
		engine_audio.stop()
	exited.emit(self)

func _safe_exit_position() -> Vector3:
	var side := global_transform.basis.x
	var candidates := [side * 2.4, -side * 2.4, global_transform.basis.z * 3.0]
	var space := get_world_3d().direct_space_state
	for offset_variant in candidates:
		var offset: Vector3 = offset_variant
		var from := global_position + Vector3(0, 0.8, 0)
		var to := global_position + offset + Vector3(0, 0.8, 0)
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return global_position + offset + Vector3(0, 0.15, 0)
	return global_position + Vector3(0, 1.4, 0)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("exit_vehicle"):
		exit_vehicle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("honk"):
		honk()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_camera"):
		chase_mode = not chase_mode
		chase_initialized = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("headlights"):
		headlights_on = not headlights_on
		for light in headlight_lights:
			light.visible = headlights_on
		get_viewport().set_input_as_handled()

func honk() -> void:
	if honk_cooldown > 0.0:
		return
	honk_cooldown = 0.65
	if horn_audio.stream:
		horn_audio.play()
	honked.emit(self)

func get_drive_prompt() -> String:
	if is_police or active:
		return ""
	return "[E] Drive " + display_name

func get_speed_mph() -> float:
	return linear_velocity.length() * 2.23694

func set_ai_target(node: Node3D) -> void:
	target = node
	ai_active = node != null
	ai_driver = true

func clear_ai() -> void:
	ai_active = false
	target = null

func _restart_engine_loop() -> void:
	if (active or ai_active) and engine_audio.stream:
		engine_audio.play()

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _mat(color: Color, roughness: float = 0.7, metallic: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color, 0.3, 0.0, color, energy)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
