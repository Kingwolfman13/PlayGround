class_name Vehicle
extends CharacterBody3D

## Arcade vehicle: readable handling, real collisions, animated wheels and
## optional AI driving. The same body is used for parked cars, traffic and
## police units.

var game: Node
var vehicle_type := "sedan"
var body_color := Color(0.2, 0.3, 0.5)
var is_police := false
var is_taxi := false
var driver: Node = null
var parked := true
var autopilot := false
var is_player_driven := false

var speed := 0.0
var max_speed := 25.0
var reverse_speed := 9.0
var accel := 11.0
var brake_force := 24.0
var steer_rate := 1.9
var wheel_spin := 0.0
var wheel_radius := 0.34
var health := 100.0
var night := false

var model_data: Dictionary = {}
var steer_wheels: Array = []
var spin_wheels: Array = []
var chase_camera: Camera3D
var headlight_spot: SpotLight3D
var engine_audio: AudioStreamPlayer3D
var siren_audio: AudioStreamPlayer3D
var siren_red: MeshInstance3D
var siren_blue: MeshInstance3D
var siren_time := 0.0
var horn_cooldown := 0.0
var crash_cooldown := 0.0
var route: Array = []
var route_index := 0
var ai_target: Node3D = null
var ai_stuck := 0.0

func setup(g: Node, type: String, color: Color, opts := {}) -> void:
	game = g
	vehicle_type = type
	body_color = color
	is_police = bool(opts.get("police", false))
	is_taxi = type == "taxi"
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	up_direction = Vector3.UP
	floor_snap_length = 0.4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	model_data = VehicleModel.build(self, type, color)
	var size: Vector3 = model_data.get("size", Vector3(1.9, 1.4, 4.4))
	wheel_radius = float(model_data.get("wheel_radius", 0.34))
	steer_wheels = model_data.get("steer_wheels", [])
	spin_wheels = model_data.get("spin_wheels", [])
	siren_red = model_data.get("siren_red", null)
	siren_blue = model_data.get("siren_blue", null)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, maxf(0.9, size.y * 0.82), size.z)
	col.shape = shape
	col.position.y = shape.size.y * 0.5 + 0.05
	add_child(col)

	chase_camera = Camera3D.new()
	chase_camera.name = "ChaseCamera"
	chase_camera.position = Vector3(0, 3.25, 7.0)
	chase_camera.rotation_degrees.x = -14.0
	chase_camera.fov = 70.0
	chase_camera.far = 500.0
	chase_camera.current = false
	add_child(chase_camera)

	headlight_spot = SpotLight3D.new()
	headlight_spot.position = Vector3(0, 0.85, -size.z * 0.48)
	headlight_spot.rotation_degrees.x = -6.0
	headlight_spot.spot_range = 28.0
	headlight_spot.spot_angle = 38.0
	headlight_spot.light_energy = 0.0
	headlight_spot.shadow_enabled = false
	add_child(headlight_spot)

	engine_audio = AudioStreamPlayer3D.new()
	var engine_stream = load("res://assets/audio/engine_loop.wav")
	if engine_stream:
		if engine_stream is AudioStreamWAV:
			engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			engine_stream.loop_end = int(engine_stream.get_length() * engine_stream.mix_rate)
		engine_audio.stream = engine_stream
	engine_audio.unit_size = 7.0
	engine_audio.max_distance = 50.0
	engine_audio.volume_db = -18.0
	add_child(engine_audio)

	siren_audio = AudioStreamPlayer3D.new()
	var siren_stream = load("res://assets/audio/siren_loop.wav")
	if siren_stream:
		if siren_stream is AudioStreamWAV:
			siren_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			siren_stream.loop_end = int(siren_stream.get_length() * siren_stream.mix_rate)
		siren_audio.stream = siren_stream
	siren_audio.unit_size = 12.0
	siren_audio.max_distance = 90.0
	siren_audio.volume_db = -12.0
	add_child(siren_audio)

	add_to_group("vehicles")
	set_physics_process(true)
	parked = true
	speed = 0.0
	velocity = Vector3.ZERO

func enter(by: Node) -> void:
	driver = by
	parked = false
	is_player_driven = true
	autopilot = false
	chase_camera.current = true
	if engine_audio and engine_audio.stream:
		engine_audio.play()
	if is_police and siren_audio and siren_audio.stream:
		siren_audio.play()

func exit_vehicle() -> void:
	driver = null
	parked = false
	is_player_driven = false
	speed = 0.0
	velocity = Vector3.ZERO
	if chase_camera:
		chase_camera.current = false
	if engine_audio:
		engine_audio.stop()
	if siren_audio:
		siren_audio.stop()

func honk() -> void:
	if horn_cooldown > 0.0:
		return
	horn_cooldown = 0.35
	if game and game.audio:
		game.audio.play_horn(global_position)

func _process(delta: float) -> void:
	horn_cooldown = maxf(0.0, horn_cooldown - delta)
	crash_cooldown = maxf(0.0, crash_cooldown - delta)
	if is_police and siren_red and siren_blue:
		siren_time += delta
		var phase := fmod(siren_time, 0.48)
		siren_red.visible = phase < 0.24
		siren_blue.visible = phase >= 0.24
	if headlight_spot:
		headlight_spot.light_energy = 4.0 if night else 0.0

func _physics_process(delta: float) -> void:
	if parked:
		return
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.2

	if driver == null and not autopilot:
		speed = move_toward(speed, 0.0, brake_force * delta)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var throttle := 0.0
	var steer_input := 0.0
	var handbrake := false
	if driver != null:
		throttle = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		steer_input = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		handbrake = Input.is_action_pressed("sprint")
		if game and game.touch_move.length() > 0.12:
			throttle = -game.touch_move.y
			steer_input = -game.touch_move.x
	else:
		var ai := _ai_controls(delta)
		throttle = ai.x
		steer_input = ai.y

	var target_speed := 0.0
	if throttle > 0.04:
		target_speed = max_speed * clampf(throttle, 0.0, 1.0)
	elif throttle < -0.04:
		target_speed = reverse_speed * clampf(throttle, -1.0, 0.0)
	if handbrake:
		target_speed = 0.0
	var rate := brake_force if absf(target_speed) < absf(speed) else accel
	speed = move_toward(speed, target_speed, rate * delta)
	if handbrake:
		speed = move_toward(speed, 0.0, brake_force * 1.4 * delta)

	var grip := clampf(absf(speed) / 5.0, 0.0, 1.0)
	var steer_amount := steer_input * steer_rate * grip * signf(speed)
	rotate_y(steer_amount * delta)

	velocity.x = -global_transform.basis.z.x * speed
	velocity.z = -global_transform.basis.z.z * speed
	var before := global_position
	move_and_slide()
	if get_slide_collision_count() > 0:
		var impact := speed
		speed *= 0.42
		if impact > 7.0 and crash_cooldown <= 0.0:
			crash_cooldown = 0.5
			if game and game.audio:
				game.audio.play_crash(global_position, clampf(impact / 20.0, 0.2, 1.0))
		if absf(impact) > 12.0:
			health = maxf(0.0, health - absf(impact) * 0.25)
	if global_position.distance_to(before) < 0.005 and absf(speed) > 1.0:
		ai_stuck += delta
	else:
		ai_stuck = 0.0

	wheel_spin += speed * delta / maxf(wheel_radius, 0.1)
	for wheel in spin_wheels:
		wheel.rotation.x = wheel_spin
	for wheel in steer_wheels:
		wheel.rotation.y = steer_input * 0.46

	if chase_camera:
		var target_fov := 68.0 + clampf(absf(speed) / max_speed, 0.0, 1.0) * 8.0
		chase_camera.fov = lerpf(chase_camera.fov, target_fov, clampf(delta * 3.0, 0.0, 1.0))
		chase_camera.position.z = lerpf(chase_camera.position.z, 6.8 + absf(speed) * 0.035, clampf(delta * 2.0, 0.0, 1.0))

	if engine_audio and engine_audio.playing:
		engine_audio.pitch_scale = 0.72 + clampf(absf(speed) / max_speed, 0.0, 1.0) * 0.85
		engine_audio.volume_db = -18.0 if is_player_driven else -26.0

	if is_player_driven and absf(speed) > 4.0 and game:
		game.check_car_ped_collisions(self)

func _ai_controls(_delta: float) -> Vector2:
	return Vector2.ZERO

func drive_towards(target: Vector3, delta: float, desired_speed := 11.0) -> Vector2:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 1.2:
		return Vector2(0.0, 0.0)
	var desired_yaw := atan2(-to.x, -to.z)
	var diff := wrapf(desired_yaw - rotation.y, -PI, PI)
	var steer := clampf(diff * 1.9, -1.0, 1.0)
	var throttle := 1.0
	if absf(diff) > 1.15:
		throttle = 0.38
	if dist < 10.0:
		throttle = clampf(dist / 10.0, 0.0, 0.6)
	if absf(speed) > desired_speed:
		throttle = -0.35
	if _forward_blocked(5.0 + absf(speed) * 0.25) and absf(diff) < 0.55:
		throttle = -0.7
	return Vector2(throttle, steer)

func _forward_blocked(distance: float) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3(0, 0.75, 0) - global_transform.basis.z * 1.8
	var to := from - global_transform.basis.z * distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4 | 8, [get_rid()])
	var hit := space.intersect_ray(query)
	return not hit.is_empty()

func get_exit_position() -> Vector3:
	var space := get_world_3d().direct_space_state
	for side in [1.0, -1.0]:
		var offset := global_transform.basis.x * 2.3 * side
		var from := global_position + Vector3(0, 0.8, 0)
		var to := from + offset
		var query := PhysicsRayQueryParameters3D.create(from, to, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return global_position + offset + Vector3(0, 0.08, 0)
	return global_position + Vector3(0, 0.15, 0)

func set_night(value: bool) -> void:
	night = value
	if headlight_spot:
		headlight_spot.light_energy = 4.0 if night else 0.0

func get_speed_mph() -> float:
	return absf(speed) * 2.23694

func get_display_name() -> String:
	if is_police:
		return "RIVER CITY POLICE"
	if is_taxi:
		return "RIVER CITY TAXI"
	return vehicle_type.to_upper()
