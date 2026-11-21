class_name Pedestrian
extends CharacterBody3D

## Sidewalk pedestrian with a simple loop route, fleeing, conversation and a
## non-graphic knockdown state. No gore.

var game: Node
var model: Humanoid
var display_name := "RESIDENT"
var line := "Nice evening, ain't it?"
var voice_index := 0
var route: Array = []
var route_index := 0
var wait_timer := 0.0
var walk_speed := 1.35
var alive := true
var flee_timer := 0.0
var gravity := 9.8
var rng := RandomNumberGenerator.new()

func setup(g: Node, cfg: Dictionary, path: Array, ped_name: String, ped_line: String, voice: int) -> void:
	game = g
	display_name = ped_name
	line = ped_line
	voice_index = voice
	route = path.duplicate()
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	up_direction = Vector3.UP
	floor_snap_length = 0.3
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	rng.randomize()
	walk_speed = rng.randf_range(1.05, 1.65)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.7
	col.shape = capsule
	col.position.y = 0.85
	add_child(col)
	model = Humanoid.new()
	add_child(model)
	model.setup(cfg)
	route_index = rng.randi() % maxi(1, route.size())
	if route.size() > 0:
		global_position = route[route_index] + Vector3(rng.randf_range(-0.6, 0.6), 0.05, rng.randf_range(-0.6, 0.6))
	add_to_group("pedestrians")

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.2
	var target_pos := Vector3.ZERO
	var has_target := false
	flee_timer = maxf(0.0, flee_timer - delta)
	if game and game.player:
		var player_pos: Vector3 = game.player.global_position
		var danger := player_pos.distance_to(global_position) < 9.0
		if game.player.current_vehicle != null:
			var car: Node = game.player.current_vehicle
			if car.global_position.distance_to(global_position) < 11.0 and absf(car.speed) > 4.0:
				danger = true
		if game.wanted and game.wanted.stars >= 2:
			danger = danger or player_pos.distance_to(global_position) < 18.0
		if danger:
			flee_timer = 2.5
	if flee_timer > 0.0 and game and game.player:
		var away: Vector3 = global_position - game.player.global_position
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		target_pos = global_position + away.normalized() * 5.0
		has_target = true
		walk_speed = 3.6
	elif route.size() > 0:
		if wait_timer > 0.0:
			wait_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		else:
			target_pos = route[route_index]
			has_target = true
			if Vector2(global_position.x - target_pos.x, global_position.z - target_pos.z).length() < 1.0:
				route_index = (route_index + 1) % route.size()
				if rng.randf() < 0.30:
					wait_timer = rng.randf_range(0.8, 2.8)
	else:
		walk_speed = 1.0

	if has_target:
		var dir := target_pos - global_position
		dir.y = 0.0
		if dir.length() > 0.2:
			dir = dir.normalized()
			var desired_yaw := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(delta * 7.0, 0.0, 1.0))
			velocity.x = dir.x * walk_speed
			velocity.z = dir.z * walk_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	move_and_slide()
	var horiz := Vector2(velocity.x, velocity.z).length()
	if model:
		model.animate(delta, horiz, is_on_floor())

func talk() -> void:
	if not alive:
		return
	if game:
		if game.hud:
			game.hud.show_subtitle(display_name, line, 4.5)
		if game.audio:
			game.audio.play_npc_voice(voice_index, global_position)

func hit_by_vehicle(v: Node) -> void:
	if not alive:
		return
	alive = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if model:
		model.fall_down()
	set_physics_process(false)
	if game:
		game.on_ped_hit(self, v)

func hit_by_player(_p: Node) -> void:
	if not alive:
		return
	alive = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if model:
		model.fall_down()
	set_physics_process(false)
	if game:
		game.on_ped_assault(self)

func is_alive() -> bool:
	return alive
