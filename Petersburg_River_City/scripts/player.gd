class_name Player
extends CharacterBody3D

## Third-person by default so the custom character is always visible.
## V switches to a true first-person view. All animation is procedural.

@export var walk_speed := 4.6
@export var sprint_speed := 8.0
@export var jump_speed := 4.9
@export var mouse_sensitivity := 0.0022

var game: Node
var head: Node3D
var camera: Camera3D
var interactor: RayCast3D
var model: Humanoid
var current_vehicle: Node = null
var controls_enabled := true
var first_person := false
var gravity := 9.8
var stamina := 100.0
var stamina_delay := 0.0
var footstep_timer := 0.0
var punch_timer := 0.0
var punch_cooldown := 0.0
var shake := 0.0
var camera_base := Vector3(0.55, 0.24, 3.35)

func setup(g: Node) -> void:
	game = g
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	up_direction = Vector3.UP
	floor_snap_length = 0.35

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.55
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = camera_base
	camera.fov = 76.0
	camera.near = 0.05
	camera.far = 500.0
	camera.current = true
	head.add_child(camera)

	interactor = RayCast3D.new()
	interactor.name = "Interactor"
	interactor.target_position = Vector3(0, 0, -3.0)
	interactor.collision_mask = 1 | 4 | 8
	interactor.enabled = true
	interactor.add_exception(self)
	camera.add_child(interactor)

	model = Humanoid.new()
	model.name = "Character"
	add_child(model)
	model.setup({
		"skin": Color(0.42, 0.27, 0.18),
		"hair": Color(0.045, 0.038, 0.032),
		"shirt": Color(0.055, 0.058, 0.065),
		"pants": Color(0.06, 0.062, 0.07),
		"shoes": Color(0.045, 0.045, 0.05),
		"accent": Color(0.82, 0.64, 0.24),
		"hoodie": true,
		"chain": true,
		"hat": "",
		"glasses": false,
		"beard": false,
		"backpack": false,
		"vest": false,
		"height": 1.0,
		"width": 1.0
	})
	# White midsole on the black sneakers.
	model.model.scale = Vector3(1.0, 1.0, 1.0)
	set_first_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if game and game.paused:
		return
	if event.is_action_pressed("ui_cancel"):
		if game:
			game.toggle_pause()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not game.is_touch:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not first_person or true:
			attack()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event.is_action_pressed("interact"):
		if game:
			game.try_interact()
	if event.is_action_pressed("exit_vehicle"):
		if game:
			game.request_exit_vehicle()
	if event.is_action_pressed("honk"):
		if current_vehicle and current_vehicle.has_method("honk"):
			current_vehicle.honk()
	if event.is_action_pressed("toggle_view"):
		set_first_person(not first_person)
	if event.is_action_pressed("map"):
		if game and game.hud:
			game.hud.toggle_map()
	if event.is_action_pressed("help"):
		if game and game.hud:
			game.hud.toggle_help()
	if event.is_action_pressed("radio_next"):
		if game and game.audio:
			game.audio.next_station()
	if event.is_action_pressed("restart"):
		if game and game.hud and game.hud.help_visible:
			get_tree().reload_current_scene()

func look(relative: Vector2) -> void:
	if current_vehicle != null or not controls_enabled:
		return
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x - relative.y * mouse_sensitivity, deg_to_rad(-82.0), deg_to_rad(82.0))

func _physics_process(delta: float) -> void:
	if not controls_enabled or current_vehicle != null:
		velocity = Vector3.ZERO
		if model:
			model.animate(delta, 0.0, true)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_speed
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if game and game.touch_move.length() > 0.1:
		input_dir = game.touch_move
	var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and input_dir.length() > 0.1 and stamina > 2.0
	var speed := sprint_speed if sprinting else walk_speed
	if sprinting:
		stamina = maxf(0.0, stamina - 18.0 * delta)
		stamina_delay = 1.0
	else:
		stamina_delay = maxf(0.0, stamina_delay - delta)
		if stamina_delay <= 0.0:
			stamina = minf(100.0, stamina + 14.0 * delta)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	var horiz := Vector2(velocity.x, velocity.z).length()
	if model:
		model.animate(delta, horiz, is_on_floor())
	if horiz > 0.5 and is_on_floor():
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_timer = 0.34 if sprinting else 0.48
			if game and game.audio:
				game.audio.play_footstep(global_position, 0.7 if sprinting else 0.5)
	else:
		footstep_timer = 0.0

func _process(delta: float) -> void:
	if game and game.touch_look.length() > 0.1:
		look(game.touch_look)
		game.touch_look = Vector2.ZERO
	punch_cooldown = maxf(0.0, punch_cooldown - delta)
	shake = maxf(0.0, shake - delta * 2.5)
	if current_vehicle == null and controls_enabled:
		_update_camera(delta)
	# Subtle breathing camera motion.
	if camera and not first_person:
		camera.position.y = camera_base.y + sin(Time.get_ticks_msec() * 0.0014) * 0.012
	if shake > 0.0 and camera:
		camera.h_offset = sin(Time.get_ticks_msec() * 0.09) * shake * 0.08
		camera.v_offset = cos(Time.get_ticks_msec() * 0.11) * shake * 0.08
	elif camera:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _update_camera(delta: float) -> void:
	if not camera or not head:
		return
	if first_person:
		camera.position = camera.position.lerp(Vector3(0, 0, 0), clampf(delta * 12.0, 0.0, 1.0))
		if model:
			model.visible = false
		return
	if model:
		model.visible = true
	var desired := camera_base
	var from := head.global_position
	var desired_global := head.to_global(desired)
	var space := get_world_3d().direct_space_state
	if space:
		var query := PhysicsRayQueryParameters3D.create(from, desired_global, 1, [get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var local_hit: Vector3 = head.to_local(hit.position)
			var dist := local_hit.length()
			if dist < desired.length():
				desired = local_hit.normalized() * maxf(0.45, dist - 0.20)
				if dist < 1.0 and model:
					model.visible = false
	camera.position = camera.position.lerp(desired, clampf(delta * 14.0, 0.0, 1.0))

func set_first_person(value: bool) -> void:
	first_person = value
	if camera:
		camera.position = Vector3(0, 0, 0) if value else camera_base
	if model and current_vehicle == null:
		model.visible = not value
	if game and game.hud:
		game.hud.set_crosshair(value)

func attack() -> void:
	if current_vehicle != null or punch_cooldown > 0.0 or not controls_enabled:
		return
	punch_cooldown = 0.42
	shake = 0.8
	if model:
		model.punch()
	if game and game.audio:
		game.audio.play_whoosh(global_position)
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 2.4
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var query := PhysicsRayQueryParameters3D.create(from, to, 8, [get_rid()])
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var target = hit.collider
		if target and target.has_method("hit_by_player"):
			target.hit_by_player(self)
			if game:
				game.on_assault()
		else:
			if game and game.audio:
				game.audio.play_impact(hit.position, 0.35)

func enter_vehicle(v: Node) -> void:
	current_vehicle = v
	controls_enabled = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if camera:
		camera.current = false
	v.enter(self)

func exit_vehicle(v: Node) -> void:
	current_vehicle = null
	global_position = v.get_exit_position()
	visible = true
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	controls_enabled = true
	if camera:
		camera.current = true
	v.exit_vehicle()
	set_first_person(first_person)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_eye_position() -> Vector3:
	return camera.global_position if camera else global_position + Vector3(0, 1.55, 0)
