extends CharacterBody3D

signal hit_by_car(ped: Node3D, car: Node3D)

@export var person_name := "Riverside Walker"
@export var shirt_color := Color("#557c9a")
@export var pants_color := Color("#2f3539")
@export var skin_color := Color("#a16d4f")
@export var hat_color := Color("#e6ddca")

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var main: Node
var player: Node3D
var home := Vector3.ZERO
var wander_target := Vector3.ZERO
var wait_timer := 0.0
var walk_time := 0.0
var flee_timer := 0.0
var stuck_timer := 0.0
var hit_cooldown := 0.0
var visual: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var alert_label: Label3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("pedestrians")
	rng.seed = hash(person_name) + int(global_position.x * 13.0) + int(global_position.z * 7.0)
	home = global_position
	_build_visual()
	_pick_new_target()

func set_world(main_node: Node, player_node: Node3D) -> void:
	main = main_node
	player = player_node

func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var shirt := _mat(shirt_color, 0.85)
	var pants := _mat(pants_color, 0.9)
	var skin := _mat(skin_color, 0.8)
	var hat := _mat(hat_color, 0.75)
	var dark := _mat(Color("#24282b"), 0.9)
	_box(visual, Vector3(0, 1.18, 0), Vector3(0.5, 0.66, 0.28), shirt)
	_box(visual, Vector3(0, 0.82, 0), Vector3(0.44, 0.2, 0.26), pants)
	_box(visual, Vector3(0, 1.5, 0), Vector3(0.16, 0.14, 0.16), skin)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.19
	sphere.height = 0.4
	head.mesh = sphere
	head.position = Vector3(0, 1.7, 0)
	head.material_override = skin
	visual.add_child(head)
	var cap := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.2
	cylinder.height = 0.09
	cap.mesh = cylinder
	cap.position = Vector3(0, 1.87, 0)
	cap.material_override = hat
	visual.add_child(cap)
	_box(visual, Vector3(0, 1.83, -0.13), Vector3(0.34, 0.035, 0.25), hat)
	for x in [-0.065, 0.065]:
		_box(visual, Vector3(x, 1.72, -0.18), Vector3(0.035, 0.035, 0.02), dark)
	_box(visual, Vector3(0, 1.66, -0.2), Vector3(0.05, 0.06, 0.04), skin)
	left_leg = Node3D.new()
	left_leg.position = Vector3(-0.13, 0.8, 0)
	visual.add_child(left_leg)
	_box(left_leg, Vector3(0, -0.35, 0), Vector3(0.16, 0.68, 0.18), pants)
	_box(left_leg, Vector3(0, -0.72, -0.04), Vector3(0.17, 0.1, 0.26), dark)
	right_leg = Node3D.new()
	right_leg.position = Vector3(0.13, 0.8, 0)
	visual.add_child(right_leg)
	_box(right_leg, Vector3(0, -0.35, 0), Vector3(0.16, 0.68, 0.18), pants)
	_box(right_leg, Vector3(0, -0.72, -0.04), Vector3(0.17, 0.1, 0.26), dark)
	left_arm = Node3D.new()
	left_arm.position = Vector3(-0.33, 1.44, 0)
	visual.add_child(left_arm)
	_box(left_arm, Vector3(0, -0.3, 0), Vector3(0.12, 0.6, 0.14), shirt)
	_box(left_arm, Vector3(0, -0.62, 0), Vector3(0.11, 0.12, 0.12), skin)
	right_arm = Node3D.new()
	right_arm.position = Vector3(0.33, 1.44, 0)
	visual.add_child(right_arm)
	_box(right_arm, Vector3(0, -0.3, 0), Vector3(0.12, 0.6, 0.14), shirt)
	_box(right_arm, Vector3(0, -0.62, 0), Vector3(0.11, 0.12, 0.12), skin)
	if hash(person_name) % 3 == 0:
		_box(visual, Vector3(0.36, 1.0, 0.12), Vector3(0.18, 0.3, 0.12), _mat(Color("#6f5741"), 0.9))
	alert_label = Label3D.new()
	alert_label.text = "!"
	alert_label.font_size = 96
	alert_label.pixel_size = 0.006
	alert_label.modulate = Color("#ffd36a")
	alert_label.position = Vector3(0, 2.35, 0)
	alert_label.visible = false
	visual.add_child(alert_label)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	flee_timer = maxf(0.0, flee_timer - delta)
	wait_timer = maxf(0.0, wait_timer - delta)
	var car := _current_car()
	var threat := false
	var car_speed := 0.0
	if car:
		car_speed = car.linear_velocity.length()
		var d := global_position.distance_to(car.global_position)
		if d < 16.0 and car_speed > 4.0:
			threat = true
		if d < 2.3 and car_speed > 2.4 and hit_cooldown <= 0.0:
			hit_cooldown = 6.0
			flee_timer = 5.0
			hit_by_car.emit(self, car)
	if threat:
		flee_timer = maxf(flee_timer, 1.2)
	var moving := false
	if flee_timer > 0.0 and car:
		var away := global_position - car.global_position
		away.y = 0.0
		if away.length() < 0.2:
			away = Vector3(1, 0, 0)
		_move_in(away.normalized(), 4.6, delta)
		moving = true
		alert_label.visible = true
	else:
		alert_label.visible = false
		if wait_timer <= 0.0:
			var to_target := wander_target - global_position
			to_target.y = 0.0
			if to_target.length() < 0.8:
				wait_timer = rng.randf_range(0.8, 2.8)
				_pick_new_target()
			else:
				_move_in(to_target.normalized(), 1.25, delta)
				moving = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	move_and_slide()
	if moving and absf(velocity.x) + absf(velocity.z) < 0.1:
		stuck_timer += delta
		if stuck_timer > 1.2:
			stuck_timer = 0.0
			_pick_new_target()
	else:
		stuck_timer = 0.0
	if global_position.y < -3.0:
		global_position = home + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO
	_animate(delta, moving)

func _move_in(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * speed, delta * 10.0)
	velocity.z = move_toward(velocity.z, dir.z * speed, delta * 10.0)
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, delta * 7.0)

func _animate(delta: float, moving: bool) -> void:
	if moving:
		walk_time += delta * (10.0 if flee_timer > 0.0 else 6.5)
		visual.position.y = absf(sin(walk_time)) * 0.035
		var swing := sin(walk_time) * (0.65 if flee_timer > 0.0 else 0.4)
		left_leg.rotation.x = swing
		right_leg.rotation.x = -swing
		left_arm.rotation.x = -swing * 0.8
		right_arm.rotation.x = swing * 0.8
	else:
		visual.position.y = lerpf(visual.position.y, 0.0, delta * 8.0)
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, delta * 8.0)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, delta * 8.0)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, delta * 8.0)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, delta * 8.0)

func _pick_new_target() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(3.0, 12.0)
	wander_target = home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	wander_target.x = clampf(wander_target.x, -WorldData.WORLD_HALF + 4.0, WorldData.WORLD_HALF - 4.0)
	wander_target.z = clampf(wander_target.z, -WorldData.WORLD_HALF + 4.0, WorldData.WORLD_HALF - 4.0)

func _current_car() -> Node3D:
	if main and main.get("current_vehicle") != null:
		return main.current_vehicle as Node3D
	return null

func scare() -> void:
	flee_timer = 3.5
	if alert_label:
		alert_label.visible = true

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _mat(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
