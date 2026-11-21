class_name PoliceCar
extends Vehicle

## Fictional River City police cruiser. It pursues, rams, and busts the player
## when the wanted meter is active. No real department is depicted.

var bust_timer := 0.0
var spawn_grace := 2.0

func setup_police(g: Node, spawn_pos: Vector3) -> void:
	setup(g, "police", Color(0.055, 0.065, 0.085), {"police": true})
	autopilot = true
	parked = false
	max_speed = 28.0
	accel = 16.0
	brake_force = 28.0
	global_position = spawn_pos
	spawn_grace = 2.0
	if siren_audio and siren_audio.stream:
		siren_audio.play()
	add_to_group("police")

func _process(delta: float) -> void:
	super._process(delta)
	spawn_grace = maxf(0.0, spawn_grace - delta)
	if game and game.wanted and game.wanted.stars <= 0:
		if siren_audio:
			siren_audio.stop()

func _ai_controls(delta: float) -> Vector2:
	if game == null or game.player == null or game.wanted == null:
		return Vector2.ZERO
	if game.wanted.stars <= 0:
		return Vector2(0.0, 0.0)
	var target: Node3D = game.player
	var player_in_car: bool = game.player.current_vehicle != null
	if player_in_car:
		target = game.player.current_vehicle
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.1:
		return Vector2.ZERO
	var desired_yaw := atan2(-to.x, -to.z)
	var diff := wrapf(desired_yaw - rotation.y, -PI, PI)
	var steer := clampf(diff * 2.1, -1.0, 1.0)
	var throttle := 1.0
	if absf(diff) > 1.3:
		throttle = 0.35
	if _building_blocked(5.5 + absf(speed) * 0.22) and absf(diff) < 0.45:
		throttle = -0.8
	if dist < 6.0:
		throttle = 0.45
	# Bust logic.
	if spawn_grace <= 0.0:
		if not player_in_car and dist < 7.0:
			game.wanted.bust()
		elif player_in_car and dist < 6.0:
			var car: Node = game.player.current_vehicle
			if absf(car.speed) < 2.5:
				bust_timer += delta
				if bust_timer > 1.0:
					game.wanted.bust()
			else:
				bust_timer = 0.0
	return Vector2(throttle, steer)

func _building_blocked(distance: float) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3(0, 0.75, 0) - global_transform.basis.z * 1.7
	var to := from - global_transform.basis.z * distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return not space.intersect_ray(query).is_empty()

func end_chase() -> void:
	autopilot = false
	if siren_audio:
		siren_audio.stop()
	if engine_audio:
		engine_audio.stop()
