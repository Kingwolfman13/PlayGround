extends Node3D

const CarScene = preload("res://scenes/vehicles/car.tscn")
const PedScene = preload("res://scenes/pedestrian.tscn")
const TrafficScene = preload("res://scenes/vehicles/traffic_car.tscn")

@onready var city: CityBuilder = $City
@onready var vehicles_root: Node3D = $Vehicles
@onready var pedestrians_root: Node3D = $Pedestrians
@onready var traffic_root: Node3D = $Traffic
@onready var player: FPSPlayer = $Player
@onready var mission_manager: MissionManager = $MissionManager
@onready var wanted_system: WantedSystem = $WantedSystem
@onready var hud: GameHUD = $HUD
@onready var touch_controls: TouchControls = $TouchControls

var current_vehicle: RiverCar
var vehicles: Array = []
var pedestrians: Array = []
var traffic: Array = []
var paused := false
var touch_enabled := false
var ambient: AudioStreamPlayer
var capture_mode := false
var capture_done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_map()
	player.global_position = WorldData.SPAWN_POINT
	player.rotation.y = WorldData.SPAWN_YAW
	player.main = self
	if player.interactor and player.interactor.has_signal("interacted"):
		player.interactor.connect("interacted", _on_interact)
	_spawn_vehicles()
	_spawn_pedestrians()
	_spawn_traffic()
	_setup_audio()
	mission_manager.setup(self, player, hud)
	wanted_system.setup(self, player, hud)
	hud.setup(self, player, mission_manager, wanted_system)
	touch_controls.setup(self, player)
	hud.resume_requested.connect(_on_resume)
	hud.restart_requested.connect(_on_restart)
	hud.quit_requested.connect(_on_quit)
	hud.new_game_requested.connect(_on_new_game)
	hud.touch_toggle_requested.connect(_toggle_touch)
	touch_enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	touch_controls.set_enabled(touch_enabled)
	player.set_touch_mode(touch_enabled)
	mission_manager.begin()
	if not touch_enabled and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_banner("PETERSBURG: RIVER CITY", "Old Towne  ·  Appomattox Riverwalk", Color("#e7b45b"), 5.0)
	hud.show_toast("Mara: First parcel is in the warehouse courtyard off Main Street. Take a car if you like.", 7.0)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--shot="):
			capture_mode = true
			call_deferred("_run_capture")
		elif arg == "--selftest":
			call_deferred("_run_selftest")

func _spawn_vehicles() -> void:
	for data in WorldData.PARKED_CARS:
		var car: RiverCar = CarScene.instantiate()
		car.set("display_name", str(data.name))
		car.set("body_color", data.color)
		car.set("main", self)
		car.position = data.pos
		car.rotation.y = float(data.yaw)
		vehicles_root.add_child(car)
		car.entered.connect(_on_car_entered)
		car.exited.connect(_on_car_exited)
		car.honked.connect(_on_car_honked)
		vehicles.append(car)

func _spawn_pedestrians() -> void:
	for data in WorldData.PEDESTRIANS:
		var ped: Node3D = PedScene.instantiate()
		ped.set("person_name", str(data.name))
		ped.set("shirt_color", data.shirt)
		ped.set("pants_color", data.pants)
		ped.set("skin_color", data.skin)
		ped.set("hat_color", data.hat)
		ped.position = data.pos
		pedestrians_root.add_child(ped)
		ped.set_world(self, player)
		ped.hit_by_car.connect(_on_pedestrian_hit)
		pedestrians.append(ped)

func _spawn_traffic() -> void:
	for data in WorldData.TRAFFIC:
		var car: Node3D = TrafficScene.instantiate()
		car.set("main", self)
		car.setup(data.path, data.color, float(data.speed))
		traffic_root.add_child(car)
		car.global_position = data.path[0]
		traffic.append(car)

func _setup_audio() -> void:
	if not ResourceLoader.exists("res://assets/audio/ambient.wav"):
		return
	ambient = AudioStreamPlayer.new()
	ambient.name = "Ambient"
	ambient.stream = load("res://assets/audio/ambient.wav")
	ambient.volume_db = -22.0
	add_child(ambient)
	ambient.finished.connect(_loop_ambient)
	ambient.play()

func _loop_ambient() -> void:
	if ambient:
		ambient.play()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if current_vehicle != null:
		var cp := current_vehicle.global_position
		if cp.y < -5.0 or (cp.z < -59.0 and cp.y < 1.0):
			respawn_player(false)
	elif player.global_position.y < -6.0 or (player.global_position.z < -59.0 and player.global_position.y < 1.2):
		respawn_player(false)
	if current_vehicle != null:
		hud.set_speed(current_vehicle.get_speed_mph(), current_vehicle.display_name, "CHASE" if current_vehicle.chase_mode else "COCKPIT")
		hud.set_prompt("[F] Exit   [H] Horn   [V] Camera   [L] Lights")
	else:
		hud.set_speed(0.0, "", "")
		hud.set_prompt(player.get_interact_prompt())
	hud.set_district(WorldData.district_at(get_player_position()))
	if Input.is_action_just_pressed("restart"):
		_on_restart()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_touch"):
		_toggle_touch()
		get_viewport().set_input_as_handled()

func _on_interact(target: Node3D) -> void:
	if target == null:
		return
	if target is PoliceCar:
		hud.show_toast("That cruiser is locked to the Petersburg Police.", 2.5, Color("#f0a096"))
		return
	if target is RiverCar:
		_try_enter_vehicle(target as RiverCar)
		return
	var id := str(target.get_meta("interact_id", ""))
	match id:
		"pickup":
			if mission_manager.try_pickup():
				pass
		"mission_board":
			if mission_manager.active:
				hud.show_toast("Mara: Finish the route already on your board first.", 3.0)
			else:
				mission_manager.start_bonus()
		_:
			pass

func _try_enter_vehicle(car: RiverCar) -> void:
	if current_vehicle != null:
		return
	if car.enter(player):
		current_vehicle = car
		hud.set_driving(true)
		hud.show_toast("W/S throttle  ·  A/D steer  ·  F exit  ·  H horn  ·  V camera", 5.0)

func _on_car_entered(car: RiverCar) -> void:
	current_vehicle = car
	hud.set_driving(true)
	wanted_system.set_heat(wanted_system.heat)

func _on_car_exited(car: RiverCar) -> void:
	if current_vehicle == car:
		current_vehicle = null
		hud.set_driving(false)

func _on_car_honked(_car: RiverCar) -> void:
	for ped in get_tree().get_nodes_in_group("pedestrians"):
		if is_instance_valid(ped) and ped.global_position.distance_to(get_player_position()) < 26.0:
			ped.scare()

func _on_pedestrian_hit(ped: Node3D, _car: Node3D) -> void:
	if ped.has_method("scare"):
		ped.scare()
	wanted_system.add_heat(1.0, "Civilian struck by a vehicle")

func get_player_position() -> Vector3:
	if current_vehicle != null and is_instance_valid(current_vehicle):
		return current_vehicle.global_position
	return player.global_position

func get_player_node() -> Node3D:
	return player

func is_player_driving() -> bool:
	return current_vehicle != null

func bust_player() -> void:
	if current_vehicle != null:
		current_vehicle.exit_vehicle()
		current_vehicle = null
	hud.set_driving(false)
	player.respawn(WorldData.SPAWN_POINT, WorldData.SPAWN_YAW)
	hud.show_toast("You wake up at the impound lot. Your heat is cleared.", 4.0, Color("#f0a096"))

func respawn_player(_busted: bool) -> void:
	if current_vehicle != null:
		current_vehicle.exit_vehicle()
		current_vehicle = null
		hud.set_driving(false)
	player.respawn(WorldData.SPAWN_POINT, WorldData.SPAWN_YAW)
	wanted_system.reset()
	hud.show_toast("The river is not a shortcut. Back to Old Towne.", 3.0, Color("#8fd3e3"))

func _toggle_pause() -> void:
	_set_paused(not paused)

func _set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	hud.set_paused(value)
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not touch_enabled and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume() -> void:
	_set_paused(false)

func _on_restart() -> void:
	get_tree().paused = false
	GameState.save_game()
	get_tree().reload_current_scene()

func _on_quit() -> void:
	GameState.save_game()
	get_tree().quit()

func _on_new_game() -> void:
	GameState.new_game()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _toggle_touch() -> void:
	touch_enabled = not touch_enabled
	touch_controls.set_enabled(touch_enabled)
	player.set_touch_mode(touch_enabled)
	if touch_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_toast("Touch controls " + ("enabled" if touch_enabled else "disabled") + ".", 2.0)

func _ensure_input_map() -> void:
	_ensure_action("move_forward", [KEY_W, KEY_UP])
	_ensure_action("move_back", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("sprint", [KEY_SHIFT])
	_ensure_action("jump", [KEY_SPACE])
	_ensure_action("interact", [KEY_E])
	_ensure_action("exit_vehicle", [KEY_F])
	_ensure_action("honk", [KEY_H])
	_ensure_action("toggle_camera", [KEY_V])
	_ensure_action("headlights", [KEY_L])
	_ensure_action("restart", [KEY_R])
	_ensure_action("toggle_touch", [KEY_F2])

func _ensure_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()

func _run_capture() -> void:
	if capture_done:
		return
	capture_done = true
	var shot := ""
	var mode := "street"
	var cam := Vector3(38, 28, 58)
	var look := Vector3(0, 3, -2)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.substr(7)
		elif arg.begins_with("--mode="):
			mode = arg.substr(7)
		elif arg.begins_with("--cam="):
			cam = _parse_vec3(arg.substr(6))
		elif arg.begins_with("--look="):
			look = _parse_vec3(arg.substr(7))
	if shot.is_empty():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_controls.set_enabled(false)
	await get_tree().process_frame
	match mode:
		"overview":
			hud.visible = false
			var camera := Camera3D.new()
			camera.fov = 62.0
			camera.position = cam
			add_child(camera)
			camera.look_at(look, Vector3.UP)
			camera.current = true
		"river":
			player.global_position = Vector3(0, 1.0, -50.0)
			player.rotation.y = 0.0
		"drive":
			var car: RiverCar = vehicles[0]
			car.global_position = Vector3(4.6, 0.95, 27.0)
			car.rotation.y = 0.0
			car.enter(player)
			current_vehicle = car
			hud.set_driving(true)
		"mission":
			mission_manager.start_mission(0)
			player.global_position = Vector3(-20.0, 1.0, -19.0)
			player.rotation.y = 0.93
		"street":
			player.global_position = Vector3(0, 1.0, 24.0)
			player.rotation.y = 0.0
		_:
			pass
	await get_tree().create_timer(5.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		print("SHOT_FAILED: no viewport image")
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(shot.get_base_dir())
	var err := image.save_jpg(shot, 0.88)
	print("SHOT_SAVED %s err=%d" % [shot, err])
	get_tree().quit()

func _run_selftest() -> void:
	var passed := 0
	var failed := 0
	print("SELFTEST START")
	await get_tree().create_timer(1.2).timeout

	# --- Walking -------------------------------------------------------
	var start_pos := player.global_position
	Input.action_press("move_forward")
	await _wait_physics(36)
	Input.action_release("move_forward")
	await _wait_physics(4)
	var walked := player.global_position.distance_to(start_pos)
	if _check(walked > 0.8, "walk moved %.2f m" % walked):
		passed += 1
	else:
		failed += 1

	# --- Sprinting -----------------------------------------------------
	start_pos = player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait_physics(30)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _wait_physics(4)
	var sprinted := player.global_position.distance_to(start_pos)
	if _check(sprinted > walked * 1.15, "sprint moved %.2f m vs walk %.2f m" % [sprinted, walked]):
		passed += 1
	else:
		failed += 1

	# --- Jumping -------------------------------------------------------
	player.global_position = WorldData.SPAWN_POINT
	player.velocity = Vector3.ZERO
	await _wait_physics(10)
	var ground_y := player.global_position.y
	Input.action_press("jump")
	await _wait_physics(2)
	Input.action_release("jump")
	var peak := ground_y
	for i in range(30):
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	if _check(peak > ground_y + 0.35, "jump peaked +%.2f m" % (peak - ground_y)):
		passed += 1
	else:
		failed += 1
	await _wait_physics(20)

	# --- Mission pickup and delivery ----------------------------------
	player.global_position = WorldData.SPAWN_POINT
	player.velocity = Vector3.ZERO
	mission_manager.start_mission(0)
	await _wait_physics(3)
	var pickup: Vector3 = mission_manager.current.pickup
	player.global_position = pickup + Vector3(0.0, 0.9, 2.0)
	player.velocity = Vector3.ZERO
	await _wait_physics(4)
	var picked := mission_manager.try_pickup()
	if _check(picked and mission_manager.has_package, "mission pickup accepted"):
		passed += 1
	else:
		failed += 1
	var cash_before := GameState.cash
	var drop: Vector3 = mission_manager.current.drop
	player.global_position = drop + Vector3(0.0, 0.9, 1.6)
	player.velocity = Vector3.ZERO
	await _wait_physics(6)
	var delivered := not mission_manager.active and GameState.cash > cash_before
	if _check(delivered, "mission delivered, cash %d -> %d" % [cash_before, GameState.cash]):
		passed += 1
	else:
		failed += 1

	# --- Wanted system -------------------------------------------------
	wanted_system.add_heat(2.0, "Self-test disturbance")
	await _wait_physics(4)
	var police_ok := wanted_system.heat >= 2 and wanted_system.police_cars.size() >= 2
	if _check(police_ok, "wanted spawned %d police at heat %d" % [wanted_system.police_cars.size(), wanted_system.heat]):
		passed += 1
	else:
		failed += 1
	wanted_system.reset()
	await _wait_physics(4)
	if _check(wanted_system.heat == 0 and wanted_system.police_cars.is_empty(), "wanted reset cleared heat and police"):
		passed += 1
	else:
		failed += 1

	# --- Vehicle enter / drive / exit ----------------------------------
	var car: RiverCar = null
	for candidate in vehicles:
		if is_instance_valid(candidate) and not candidate.is_police:
			car = candidate
			break
	if car:
		player.global_position = car.global_position + Vector3(2.2, 1.0, 0.0)
		player.velocity = Vector3.ZERO
		await _wait_physics(3)
		var entered := car.enter(player)
		await _wait_physics(3)
		var car_start := car.global_position
		Input.action_press("move_forward")
		await _wait_physics(60)
		Input.action_release("move_forward")
		var drove := car.global_position.distance_to(car_start)
		if _check(entered and current_vehicle == car and drove > 1.0, "vehicle drove %.2f m" % drove):
			passed += 1
		else:
			failed += 1
		car.exit_vehicle()
		await _wait_physics(6)
		if _check(current_vehicle == null and player.visible and player.is_physics_processing(), "vehicle exit restored player"):
			passed += 1
		else:
			failed += 1
	else:
		print("SELFTEST FAIL no civilian vehicle found")
		failed += 1

	# --- Touch controls ------------------------------------------------
	touch_controls.set_enabled(true)
	player.set_touch_mode(true)
	await _wait_physics(2)
	var pad: TouchPad = touch_controls.pad
	var touch_ok := touch_controls.enabled and pad != null and pad.visible
	if touch_ok:
		pad._update_joystick(pad._joystick_center() + Vector2(0.0, -60.0))
		touch_ok = Input.get_action_strength("move_forward") > 0.5
		pad._release_move()
	if _check(touch_ok, "touch joystick drives move_forward"):
		passed += 1
	else:
		failed += 1
	touch_controls.set_enabled(false)
	player.set_touch_mode(false)

	# --- Local save round-trip -----------------------------------------
	GameState.save_game()
	var loaded := SaveSystem.load_data()
	var save_ok := not loaded.is_empty() and int(loaded.get("cash", -1)) == GameState.cash
	if _check(save_ok, "save round-trip cash=%d" % GameState.cash):
		passed += 1
	else:
		failed += 1

	# --- Core input actions -------------------------------------------
	var missing: Array = []
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "interact", "exit_vehicle", "honk", "toggle_camera", "headlights"]:
		if not InputMap.has_action(action):
			missing.append(action)
	if _check(missing.is_empty(), "input actions present (%d)" % 11):
		passed += 1
	else:
		failed += 1
		print("SELFTEST FAIL missing actions: ", missing)

	print("SELFTEST DONE pass=%d fail=%d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _wait_physics(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame

func _check(condition: bool, label: String) -> bool:
	if condition:
		print("SELFTEST PASS ", label)
	else:
		print("SELFTEST FAIL ", label)
	return condition

func _parse_vec3(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
