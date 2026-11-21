extends Node
class_name MissionManager

signal mission_started(title: String)
signal mission_completed(title: String, reward: int, seconds: float)
signal mission_failed(title: String)

var main: Node
var player: Node3D
var hud: Node
var mission_index := 0
var next_index := 0
var active := false
var has_package := false
var time_left := 0.0
var total_time := 0.0
var current: Dictionary = {}
var retry_timer := 0.0
var marker_root: Node3D
var pickup_marker: Node3D
var pickup_body: StaticBody3D
var pickup_visual: Node3D
var pickup_ring: MeshInstance3D
var pickup_diamond: MeshInstance3D
var drop_marker: Node3D
var drop_ring: MeshInstance3D
var drop_disc: MeshInstance3D
var anim_time := 0.0
var sfx: AudioStreamPlayer
var completed_this_run := 0

func _ready() -> void:
	marker_root = Node3D.new()
	marker_root.name = "MissionMarkers"
	add_child(marker_root)
	sfx = AudioStreamPlayer.new()
	sfx.name = "MissionSFX"
	add_child(sfx)

func setup(main_node: Node, player_node: Node3D, hud_node: Node) -> void:
	main = main_node
	player = player_node
	hud = hud_node

func begin() -> void:
	start_mission(GameState.deliveries_completed % WorldData.MISSIONS.size())

func start_mission(index: int) -> void:
	clear_markers()
	mission_index = index % WorldData.MISSIONS.size()
	next_index = (mission_index + 1) % WorldData.MISSIONS.size()
	current = (WorldData.MISSIONS[mission_index] as Dictionary).duplicate(true)
	active = true
	has_package = false
	time_left = float(current.time)
	total_time = time_left
	retry_timer = 0.0
	_build_pickup_marker(current.pickup as Vector3)
	_build_drop_marker(current.drop as Vector3)
	drop_marker.visible = false
	var bonus := GameState.deliveries_completed >= WorldData.MISSIONS.size()
	var title := str(current.title)
	if bonus:
		title = "BONUS · " + title
	mission_started.emit(title)
	if hud:
		hud.show_banner(title, "%s · %s" % [current.client, current.pickup_hint], Color("#e7b45b"), 4.0)
		hud.set_mission(title, "Pick up the parcel", -1.0, total_time, distance_to_objective(), false, str(current.client))
		hud.show_toast("New route: " + str(current.brief), 5.0)

func try_pickup() -> bool:
	if not active or has_package:
		return false
	if distance_to_objective() > 5.5:
		return false
	has_package = true
	if pickup_marker:
		pickup_marker.queue_free()
		pickup_marker = null
		pickup_body = null
		pickup_visual = null
		pickup_ring = null
		pickup_diamond = null
	if drop_marker:
		drop_marker.visible = true
	time_left = total_time
	_play_sound("pickup")
	if hud:
		hud.show_toast("Parcel secured. Drop it at " + str(current.drop_hint) + ".", 4.5, Color("#8fe3bd"))
	return true

func _process(delta: float) -> void:
	anim_time += delta
	_animate_markers(delta)
	if active:
		if has_package:
			time_left -= delta
			if time_left <= 0.0:
				_fail()
				return
		if has_package and distance_to_objective() < 4.0:
			_complete()
			return
		if hud:
			var objective := "Pick up the parcel" if not has_package else "Deliver to " + str(current.drop_hint)
			hud.set_mission(str(current.title) if GameState.deliveries_completed < 4 else "BONUS · " + str(current.title), objective, time_left if has_package else -1.0, total_time, distance_to_objective(), has_package, str(current.client))
	elif retry_timer > 0.0:
		retry_timer -= delta
		if hud:
			var objective := "Next route in %d..." % int(ceil(retry_timer))
			hud.set_mission(str(current.get("title", "Courier shift")), objective, -1.0, total_time, distance_to_objective(), false, str(current.get("client", "Mara")))
		if retry_timer <= 0.0:
			start_mission(next_index)

func _complete() -> void:
	if not active:
		return
	active = false
	has_package = false
	var used := total_time - time_left
	var reward := int(current.reward)
	var title := str(current.title)
	GameState.complete_delivery(title, reward, used)
	completed_this_run += 1
	_play_sound("success")
	clear_markers()
	if hud:
		hud.show_banner("DELIVERY COMPLETE", "+$%d   ·   %s" % [reward, _fmt_time(used)], Color("#e7b45b"), 5.0)
		if completed_this_run >= 4:
			hud.show_toast("All four routes cleared. Mara's kiosk now offers bonus shifts.", 6.0, Color("#f0d38a"))
		else:
			hud.show_toast("Cash saved locally. The next parcel is being prepared.", 4.0)
	mission_completed.emit(title, reward, used)
	next_index = (mission_index + 1) % WorldData.MISSIONS.size()
	retry_timer = 5.0

func _fail() -> void:
	if not active:
		return
	active = false
	has_package = false
	time_left = 0.0
	clear_markers()
	_play_sound("fail")
	if hud:
		hud.show_banner("TIME EXPIRED", "The parcel returned to the pickup. Retrying...", Color("#e2685b"), 4.0)
		hud.show_toast("No penalty. The route will restart in a few seconds.", 4.0, Color("#f0a096"))
	mission_failed.emit(str(current.get("title", "Delivery")))
	next_index = mission_index
	retry_timer = 4.0

func start_bonus() -> void:
	if active or retry_timer > 0.0:
		return
	if GameState.deliveries_completed >= WorldData.MISSIONS.size():
		start_mission(randi() % WorldData.MISSIONS.size())
	else:
		start_mission(GameState.deliveries_completed % WorldData.MISSIONS.size())

func distance_to_objective() -> float:
	if current.is_empty() or main == null:
		return 0.0
	var pos: Vector3 = current.pickup if not has_package else current.drop
	var from: Vector3 = main.get_player_position()
	return from.distance_to(pos)

func objective_position() -> Vector3:
	if current.is_empty():
		return WorldData.SPAWN_POINT
	return current.pickup if not has_package else current.drop

func _build_pickup_marker(pos: Vector3) -> void:
	pickup_body = StaticBody3D.new()
	pickup_body.name = "MissionPickup"
	pickup_body.position = pos
	pickup_body.collision_layer = 16
	pickup_body.collision_mask = 0
	pickup_body.set_meta("interact_id", "pickup")
	pickup_marker = pickup_body
	marker_root.add_child(pickup_body)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.4, 1.5, 1.4)
	shape.shape = box_shape
	shape.position.y = 0.75
	pickup_body.add_child(shape)
	pickup_visual = Node3D.new()
	pickup_visual.position.y = 0.0
	pickup_body.add_child(pickup_visual)
	var crate := _box(pickup_visual, Vector3(0, 0.72, 0), Vector3(1.0, 0.9, 0.82), _mat(Color("#b9834f"), 0.85))
	_box(pickup_visual, Vector3(0, 0.72, 0), Vector3(1.04, 0.12, 0.86), _emissive(Color("#d8aa54"), 0.6))
	_box(pickup_visual, Vector3(0, 1.18, 0), Vector3(1.02, 0.05, 0.84), _emissive(Color("#f0cd7a"), 0.5))
	var label := Label3D.new()
	label.text = "PARCEL"
	label.font_size = 56
	label.pixel_size = 0.005
	label.modulate = Color("#fff0c8")
	label.outline_size = 8
	label.outline_modulate = Color("#3a2414")
	label.position = Vector3(0, 0.78, -0.45)
	label.rotation.y = PI
	label.double_sided = true
	pickup_visual.add_child(label)
	pickup_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.3
	torus.rings = 32
	torus.ring_segments = 8
	pickup_ring.mesh = torus
	pickup_ring.position.y = 0.12
	pickup_ring.material_override = _glow(Color("#e8b95a"), 0.85)
	pickup_visual.add_child(pickup_ring)
	pickup_diamond = _box(pickup_visual, Vector3(0, 2.4, 0), Vector3(0.38, 0.38, 0.38), _emissive(Color("#ffe0a0"), 2.0))
	pickup_diamond.rotation = Vector3(0.0, PI / 4.0, PI / 4.0)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.5, 0)
	light.light_color = Color("#ffcf7a")
	light.light_energy = 1.5
	light.omni_range = 7.0
	light.shadow_enabled = false
	pickup_visual.add_child(light)

func _build_drop_marker(pos: Vector3) -> void:
	drop_marker = Node3D.new()
	drop_marker.name = "MissionDrop"
	drop_marker.position = pos
	marker_root.add_child(drop_marker)
	drop_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.6
	disc.bottom_radius = 3.6
	disc.height = 0.08
	disc.radial_segments = 48
	drop_disc.mesh = disc
	drop_disc.position.y = 0.07
	drop_disc.material_override = _glow(Color("#4fd6a4"), 0.38)
	drop_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drop_marker.add_child(drop_disc)
	drop_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.45
	torus.outer_radius = 3.7
	torus.rings = 48
	torus.ring_segments = 8
	drop_ring.mesh = torus
	drop_ring.position.y = 0.14
	drop_ring.material_override = _emissive(Color("#75f0be"), 1.2)
	drop_marker.add_child(drop_ring)
	var label := Label3D.new()
	label.text = "DROP"
	label.font_size = 80
	label.pixel_size = 0.007
	label.modulate = Color("#c9ffe8")
	label.outline_size = 10
	label.outline_modulate = Color("#0c3b2d")
	label.position = Vector3(0, 4.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	drop_marker.add_child(label)

func _animate_markers(delta: float) -> void:
	if pickup_visual:
		pickup_visual.position.y = sin(anim_time * 2.2) * 0.06
	if pickup_ring:
		pickup_ring.rotation.y += delta * 1.3
	if pickup_diamond:
		pickup_diamond.rotation.y += delta * 2.0
		pickup_diamond.position.y = 2.4 + sin(anim_time * 2.6) * 0.12
	if drop_marker and drop_marker.visible:
		if drop_ring:
			drop_ring.rotation.y += delta * 0.8
		if drop_disc:
			var pulse := 1.0 + sin(anim_time * 2.0) * 0.04
			drop_disc.scale = Vector3(pulse, 1.0, pulse)

func clear_markers() -> void:
	if pickup_marker and is_instance_valid(pickup_marker):
		pickup_marker.queue_free()
	if drop_marker and is_instance_valid(drop_marker):
		drop_marker.queue_free()
	pickup_marker = null
	pickup_body = null
	pickup_visual = null
	pickup_ring = null
	pickup_diamond = null
	drop_marker = null
	drop_ring = null
	drop_disc = null

func _play_sound(name: String) -> void:
	var path := "res://assets/audio/%s.wav" % name
	if ResourceLoader.exists(path):
		sfx.stream = load(path)
		sfx.play()

func _fmt_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

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

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _beam_material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := _glow(color, alpha)
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return m
