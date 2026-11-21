extends Node
class_name WantedSystem

var main: Node
var player: Node3D
var hud: Node
var heat := 0
var heat_points := 0.0
var last_heat_time := -999.0
var police_cars: Array = []
var police_scene: PackedScene
var bust_timer := 0.0
var bust_cooldown := 0.0
var ram_cooldown := 0.0
var teleport_timer := 0.0
var warned_once := false

func _ready() -> void:
	police_scene = load("res://scenes/vehicles/police_car.tscn")

func setup(main_node: Node, player_node: Node3D, hud_node: Node) -> void:
	main = main_node
	player = player_node
	hud = hud_node

func _process(delta: float) -> void:
	if main == null:
		return
	bust_cooldown = maxf(0.0, bust_cooldown - delta)
	ram_cooldown = maxf(0.0, ram_cooldown - delta)
	var now := Time.get_ticks_msec() / 1000.0
	if heat > 0 and now - last_heat_time > 13.0:
		heat_points = maxf(0.0, heat_points - delta * 0.085)
		var new_heat := int(ceil(heat_points))
		if new_heat != heat:
			heat = new_heat
			_sync_police()
			if hud:
				hud.set_wanted(heat)
			if heat == 0:
				bust_timer = 0.0
				warned_once = false
				if hud:
					hud.show_toast("Heat cleared. The neighborhood has settled down.", 3.0, Color("#8fe3bd"))
	_update_police(delta)
	_check_bust(delta)
	_check_ramming()

func add_heat(amount: float, reason: String) -> void:
	if amount <= 0.0:
		return
	last_heat_time = Time.get_ticks_msec() / 1000.0
	var old_heat := heat
	heat_points = clampf(heat_points + amount, 0.0, 5.0)
	heat = int(ceil(heat_points))
	if heat != old_heat:
		_sync_police()
		if hud:
			hud.set_wanted(heat)
			if heat > old_heat:
				hud.show_banner("HEAT LEVEL %d" % heat, reason, Color("#e2685b"), 3.0)
			else:
				hud.show_toast(reason, 3.0, Color("#f0a096"))
	if hud and heat >= 1 and not warned_once:
		warned_once = true
		hud.show_toast("Petersburg Police are responding. Break line of sight or keep driving.", 5.0, Color("#f0b06a"))

func reset() -> void:
	heat = 0
	heat_points = 0.0
	bust_timer = 0.0
	warned_once = false
	last_heat_time = -999.0
	_despawn_all()
	if hud:
		hud.set_wanted(0)

func set_heat(value: int) -> void:
	heat = clampi(value, 0, 5)
	heat_points = float(heat)
	last_heat_time = Time.get_ticks_msec() / 1000.0
	_sync_police()
	if hud:
		hud.set_wanted(heat)

func _sync_police() -> void:
	var desired := mini(heat, 3)
	while police_cars.size() < desired:
		_spawn_police()
	while police_cars.size() > desired:
		var car: Node = police_cars.pop_back()
		if is_instance_valid(car):
			if car.has_method("clear_ai"):
				car.clear_ai()
			car.queue_free()

func _spawn_police() -> void:
	if police_scene == null:
		return
	var car := police_scene.instantiate()
	var from := _player_position()
	var best: Vector3 = WorldData.POLICE_SPAWNS[0]
	var best_score := -1.0
	for point_variant in WorldData.POLICE_SPAWNS:
		var point: Vector3 = point_variant
		var d := point.distance_to(from)
		var score := 1000.0 - absf(d - 38.0)
		if d < 18.0:
			score -= 500.0
		if score > best_score:
			best_score = score
			best = point
	car.position = best
	var to_player := from - best
	car.rotation.y = atan2(-to_player.x, -to_player.z)
	car.set("main", main)
	add_child(car)
	car.set_ai_target(_target_node())
	police_cars.append(car)

func _update_police(delta: float) -> void:
	teleport_timer -= delta
	var target := _target_node()
	for car in police_cars:
		if not is_instance_valid(car):
			continue
		car.set_ai_target(target)
		var distance: float = car.global_position.distance_to(target.global_position)
		if distance > 115.0 or car.global_position.y < -4.0:
			_teleport_police(car)
		elif teleport_timer <= 0.0 and distance > 75.0:
			_teleport_police(car)
	if teleport_timer <= 0.0:
		teleport_timer = 6.0

func _teleport_police(car: Node3D) -> void:
	var target := _target_node()
	var best: Vector3 = WorldData.POLICE_SPAWNS[0]
	var best_score := -1.0
	for point_variant in WorldData.POLICE_SPAWNS:
		var point: Vector3 = point_variant
		var d := point.distance_to(target.global_position)
		var score := 1000.0 - absf(d - 30.0)
		if d < 12.0:
			score -= 400.0
		if score > best_score:
			best_score = score
			best = point
	car.global_position = best
	var to_target := target.global_position - best
	car.rotation.y = atan2(-to_target.x, -to_target.z)
	var body := car as RigidBody3D
	if body:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

func _check_bust(delta: float) -> void:
	if heat <= 0 or bust_cooldown > 0.0:
		return
	var target := _target_node()
	var target_speed := 0.0
	if main.get("current_vehicle") != null:
		target_speed = main.current_vehicle.linear_velocity.length()
	var near := false
	for car in police_cars:
		if is_instance_valid(car) and car.global_position.distance_to(target.global_position) < 6.4:
			near = true
			break
	if near and target_speed < 13.0:
		bust_timer += delta
		if bust_timer > 2.2:
			_bust()
	else:
		bust_timer = maxf(0.0, bust_timer - delta * 2.0)

func _bust() -> void:
	bust_cooldown = 10.0
	bust_timer = 0.0
	GameState.add_cash(-50)
	GameState.save_game()
	if hud:
		hud.show_busted()
	if main.has_method("bust_player"):
		main.bust_player()
	reset()
	if hud:
		hud.show_banner("BUSTED", "Heat cleared. $50 impound fee.", Color("#e2685b"), 5.0)

func _check_ramming() -> void:
	if ram_cooldown > 0.0 or heat >= 5:
		return
	if main.get("current_vehicle") == null:
		return
	var car := main.current_vehicle as VehicleBody3D
	if car == null or car.linear_velocity.length() < 4.0:
		return
	for police in police_cars:
		if is_instance_valid(police) and police.global_position.distance_to(car.global_position) < 3.6:
			ram_cooldown = 4.0
			add_heat(0.5, "Police cruiser rammed")
			return

func _target_node() -> Node3D:
	if main.get("current_vehicle") != null and is_instance_valid(main.current_vehicle):
		return main.current_vehicle as Node3D
	return player

func _player_position() -> Vector3:
	if main and main.has_method("get_player_position"):
		return main.get_player_position()
	return player.global_position if player else Vector3.ZERO

func _despawn_all() -> void:
	for car in police_cars:
		if is_instance_valid(car):
			if car.has_method("clear_ai"):
				car.clear_ai()
			car.queue_free()
	police_cars.clear()

func get_police_positions() -> Array:
	var positions: Array = []
	for car in police_cars:
		if is_instance_valid(car):
			positions.append(car.global_position)
	return positions
