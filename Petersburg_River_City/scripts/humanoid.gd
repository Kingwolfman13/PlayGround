class_name Humanoid
extends Node3D

## Original low-poly humanoid built from primitives. No external art or
## celebrity likeness is used. Outfits are configurable so every pedestrian
## and the player can read as a distinct person.

static var _mat_cache: Dictionary = {}

var config: Dictionary = {}
var model: Node3D
var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var walk_phase := 0.0
var idle_phase := 0.0
var base_hip_y := 0.92
var carrying := false
var dead := false
var punch_timer := 0.0

const SKIN_TONES := [
	Color(0.36, 0.22, 0.15), Color(0.48, 0.30, 0.20), Color(0.62, 0.42, 0.29),
	Color(0.75, 0.55, 0.40), Color(0.86, 0.68, 0.53), Color(0.28, 0.17, 0.12)
]

const HAIR_COLORS := [
	Color(0.05, 0.04, 0.035), Color(0.12, 0.08, 0.055), Color(0.24, 0.14, 0.08),
	Color(0.45, 0.31, 0.17), Color(0.68, 0.62, 0.55)
]

const SHIRT_COLORS := [
	Color(0.08, 0.09, 0.11), Color(0.16, 0.22, 0.30), Color(0.42, 0.12, 0.10),
	Color(0.55, 0.42, 0.18), Color(0.18, 0.30, 0.22), Color(0.68, 0.66, 0.60),
	Color(0.30, 0.12, 0.28), Color(0.62, 0.35, 0.16)
]

const PANTS_COLORS := [
	Color(0.08, 0.09, 0.12), Color(0.13, 0.15, 0.20), Color(0.20, 0.20, 0.18),
	Color(0.26, 0.20, 0.15), Color(0.10, 0.12, 0.10)
]

static func make_mat(color: Color, roughness := 0.82, metallic := 0.0, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f" % [color.to_html(), roughness, metallic, emission.to_html(), emission_energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	_mat_cache[key] = mat
	return mat

static func random_config(rng: RandomNumberGenerator, variant := -1) -> Dictionary:
	var skin: Color = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
	var hair: Color = HAIR_COLORS[rng.randi() % HAIR_COLORS.size()]
	var shirt: Color = SHIRT_COLORS[rng.randi() % SHIRT_COLORS.size()]
	var pants: Color = PANTS_COLORS[rng.randi() % PANTS_COLORS.size()]
	var shoes := Color(0.06, 0.06, 0.07)
	if rng.randf() < 0.28:
		shoes = Color(0.86, 0.84, 0.78)
	return {
		"skin": skin, "hair": hair, "shirt": shirt, "pants": pants, "shoes": shoes,
		"accent": Color(0.72, 0.55, 0.18), "hoodie": rng.randf() < 0.55,
		"chain": rng.randf() < 0.35, "hat": ["", "", "", "cap", "beanie"][rng.randi() % 5],
		"glasses": rng.randf() < 0.22, "beard": rng.randf() < 0.35,
		"backpack": rng.randf() < 0.18, "vest": rng.randf() < 0.08,
		"height": rng.randf_range(0.94, 1.06), "width": rng.randf_range(0.94, 1.06),
		"female": rng.randf() < 0.45
	}

func setup(cfg: Dictionary) -> void:
	config = cfg.duplicate(true)
	build()

func build() -> void:
	for child in get_children():
		child.queue_free()
	model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3(float(config.get("width", 1.0)), float(config.get("height", 1.0)), float(config.get("width", 1.0)))
	add_child(model)

	var skin: Color = config.get("skin", SKIN_TONES[2])
	var hair: Color = config.get("hair", HAIR_COLORS[0])
	var shirt: Color = config.get("shirt", SHIRT_COLORS[0])
	var pants: Color = config.get("pants", PANTS_COLORS[0])
	var shoes: Color = config.get("shoes", Color(0.05, 0.05, 0.06))
	var accent: Color = config.get("accent", Color(0.72, 0.55, 0.18))
	var hoodie: bool = config.get("hoodie", true)
	var vest: bool = config.get("vest", false)
	var skin_mat := make_mat(skin, 0.72)
	var shirt_mat := make_mat(shirt, 0.9)
	var shirt_dark := make_mat(shirt.darkened(0.22), 0.92)
	var pants_mat := make_mat(pants, 0.94)
	var shoe_mat := make_mat(shoes, 0.55, 0.05)
	var hair_mat := make_mat(hair, 0.78)
	var accent_mat := make_mat(accent, 0.32, 0.65)
	var dark_mat := make_mat(Color(0.025, 0.025, 0.03), 0.65)
	var white_mat := make_mat(Color(0.9, 0.9, 0.86), 0.7)
	var mouth_mat := make_mat(Color(0.18, 0.07, 0.06), 0.8)

	# Soft contact shadow helps the character sit on the pavement.
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.38
	shadow_mesh.bottom_radius = 0.38
	shadow_mesh.height = 0.008
	shadow_mesh.radial_segments = 16
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.mesh = shadow_mesh
	shadow.material_override = shadow_mat
	shadow.position.y = 0.012
	model.add_child(shadow)

	hips = Node3D.new()
	hips.position.y = base_hip_y
	model.add_child(hips)
	_box(hips, Vector3(0, 0, 0), Vector3(0.38, 0.22, 0.27), pants_mat)
	_box(hips, Vector3(0, 0.09, 0), Vector3(0.41, 0.055, 0.29), dark_mat)

	torso = Node3D.new()
	torso.position.y = 0.08
	hips.add_child(torso)
	_box(torso, Vector3(0, 0.30, 0), Vector3(0.48, 0.56, 0.29), shirt_mat)
	if hoodie:
		_box(torso, Vector3(0, 0.24, 0.02), Vector3(0.53, 0.45, 0.33), shirt_dark)
		_box(torso, Vector3(0, 0.30, -0.155), Vector3(0.22, 0.20, 0.025), shirt_dark)
		# Hood folded behind the neck.
		var hood := _sphere(torso, Vector3(0, 0.59, 0.14), 0.19, shirt_dark)
		hood.scale = Vector3(1.25, 0.72, 1.0)
	if vest:
		_box(torso, Vector3(0, 0.28, -0.16), Vector3(0.46, 0.42, 0.035), make_mat(Color(0.92, 0.62, 0.08), 0.75))
		_box(torso, Vector3(0, 0.30, -0.181), Vector3(0.42, 0.055, 0.01), white_mat)
		_box(torso, Vector3(0, 0.20, -0.181), Vector3(0.42, 0.035, 0.01), white_mat)
	if bool(config.get("chain", false)):
		var chain := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.095
		torus.outer_radius = 0.125
		torus.rings = 16
		torus.ring_segments = 6
		chain.mesh = torus
		chain.material_override = accent_mat
		chain.position = Vector3(0, 0.53, -0.06)
		chain.rotation.x = 0.2
		torso.add_child(chain)
		_box(torso, Vector3(0, 0.43, -0.17), Vector3(0.045, 0.075, 0.012), accent_mat)

	# Neck and head.
	_cylinder(torso, Vector3(0, 0.62, 0), 0.07, 0.10, skin_mat)
	head = Node3D.new()
	head.position.y = 0.67
	torso.add_child(head)
	var skull := _sphere(head, Vector3(0, 0.13, 0), 0.148, skin_mat)
	skull.scale = Vector3(0.94, 1.05, 0.92)
	var jaw := _sphere(head, Vector3(0, 0.045, -0.018), 0.095, skin_mat)
	jaw.scale = Vector3(1.02, 0.82, 0.95)
	_sphere(head, Vector3(-0.147, 0.12, 0.0), 0.031, skin_mat)
	_sphere(head, Vector3(0.147, 0.12, 0.0), 0.031, skin_mat)
	_sphere(head, Vector3(-0.055, 0.145, -0.132), 0.019, white_mat)
	_sphere(head, Vector3(0.055, 0.145, -0.132), 0.019, white_mat)
	_sphere(head, Vector3(-0.055, 0.145, -0.148), 0.010, dark_mat)
	_sphere(head, Vector3(0.055, 0.145, -0.148), 0.010, dark_mat)
	_box(head, Vector3(-0.055, 0.176, -0.132), Vector3(0.052, 0.012, 0.018), hair_mat)
	_box(head, Vector3(0.055, 0.176, -0.132), Vector3(0.052, 0.012, 0.018), hair_mat)
	_sphere(head, Vector3(0, 0.112, -0.153), 0.028, make_mat(skin.darkened(0.08), 0.75))
	_box(head, Vector3(0, 0.052, -0.143), Vector3(0.062, 0.014, 0.014), mouth_mat)
	if bool(config.get("beard", false)):
		_box(head, Vector3(0, 0.025, -0.118), Vector3(0.13, 0.065, 0.045), hair_mat)

	# Hair or headwear.
	var hat: String = config.get("hat", "")
	if hat == "cap":
		_cylinder(head, Vector3(0, 0.245, 0.005), 0.155, 0.075, make_mat(shirt.darkened(0.1), 0.8))
		_box(head, Vector3(0, 0.225, -0.13), Vector3(0.27, 0.022, 0.16), make_mat(shirt.darkened(0.1), 0.8))
	elif hat == "beanie":
		_cylinder(head, Vector3(0, 0.255, 0.005), 0.155, 0.13, make_mat(shirt.darkened(0.2), 0.95))
	else:
		var cap := _hemisphere(head, Vector3(0, 0.195, 0.008), 0.157, hair_mat)
		cap.scale = Vector3(1.02, 0.75, 1.02)
		# Sideburns / hairline.
		_box(head, Vector3(-0.13, 0.12, -0.04), Vector3(0.025, 0.10, 0.10), hair_mat)
		_box(head, Vector3(0.13, 0.12, -0.04), Vector3(0.025, 0.10, 0.10), hair_mat)
	if bool(config.get("glasses", false)):
		_box(head, Vector3(-0.057, 0.145, -0.157), Vector3(0.065, 0.045, 0.012), dark_mat)
		_box(head, Vector3(0.057, 0.145, -0.157), Vector3(0.065, 0.045, 0.012), dark_mat)
		_box(head, Vector3(0, 0.145, -0.157), Vector3(0.035, 0.01, 0.01), dark_mat)

	# Arms.
	arm_l = _make_arm(torso, -0.30, shirt_mat, skin_mat, shirt_dark)
	arm_r = _make_arm(torso, 0.30, shirt_mat, skin_mat, shirt_dark)

	# Legs.
	leg_l = _make_leg(hips, -0.12, pants_mat, shoe_mat, white_mat)
	leg_r = _make_leg(hips, 0.12, pants_mat, shoe_mat, white_mat)

	if bool(config.get("backpack", false)):
		_box(torso, Vector3(0, 0.29, 0.20), Vector3(0.36, 0.44, 0.18), make_mat(accent.darkened(0.35), 0.9))
		_box(torso, Vector3(-0.13, 0.42, -0.08), Vector3(0.045, 0.35, 0.03), dark_mat)
		_box(torso, Vector3(0.13, 0.42, -0.08), Vector3(0.045, 0.35, 0.03), dark_mat)

func _make_arm(parent: Node3D, x: float, sleeve: Material, skin: Material, cuff: Material) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(x, 0.50, 0)
	parent.add_child(shoulder)
	_sphere(shoulder, Vector3(0, 0, 0), 0.10, sleeve)
	_box(shoulder, Vector3(0, -0.16, 0), Vector3(0.135, 0.34, 0.16), sleeve)
	_box(shoulder, Vector3(0, -0.325, 0), Vector3(0.145, 0.055, 0.17), cuff)
	var elbow := Node3D.new()
	elbow.position.y = -0.35
	shoulder.add_child(elbow)
	_box(elbow, Vector3(0, -0.15, 0), Vector3(0.115, 0.30, 0.14), sleeve)
	_sphere(elbow, Vector3(0, -0.32, 0), 0.062, skin)
	if x < 0:
		elbow_l = elbow
	else:
		elbow_r = elbow
	return shoulder

func _make_leg(parent: Node3D, x: float, pants: Material, shoe: Material, sole: Material) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, -0.02, 0)
	parent.add_child(hip)
	_box(hip, Vector3(0, -0.22, 0), Vector3(0.165, 0.44, 0.19), pants)
	var knee := Node3D.new()
	knee.position.y = -0.44
	hip.add_child(knee)
	_box(knee, Vector3(0, -0.20, 0), Vector3(0.145, 0.40, 0.17), pants)
	_box(knee, Vector3(0, -0.42, -0.055), Vector3(0.17, 0.105, 0.31), shoe)
	_box(knee, Vector3(0, -0.477, -0.055), Vector3(0.18, 0.035, 0.32), sole)
	if x < 0:
		knee_l = knee
	else:
		knee_r = knee
	return hip

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _hemisphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius
	mesh.is_hemisphere = true
	mesh.radial_segments = 14
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func animate(delta: float, speed: float, grounded := true) -> void:
	if dead:
		return
	idle_phase += delta
	var amp := clampf(speed / 6.0, 0.0, 1.0)
	if speed > 0.08 and grounded:
		walk_phase += delta * (5.2 + speed * 1.15)
		var s := sin(walk_phase)
		var s2 := sin(walk_phase * 2.0)
		leg_l.rotation.x = s * 0.70 * amp
		leg_r.rotation.x = -s * 0.70 * amp
		knee_l.rotation.x = maxf(0.0, -s) * 0.62 * amp
		knee_r.rotation.x = maxf(0.0, s) * 0.62 * amp
		if carrying:
			arm_l.rotation.x = -1.05
			arm_r.rotation.x = -1.05
			elbow_l.rotation.x = -0.5
			elbow_r.rotation.x = -0.5
		else:
			arm_l.rotation.x = -s * 0.58 * amp
			arm_r.rotation.x = s * 0.58 * amp
			elbow_l.rotation.x = -0.20 - maxf(0.0, s) * 0.18
			elbow_r.rotation.x = -0.20 - maxf(0.0, -s) * 0.18
		hips.position.y = base_hip_y + absf(s2) * 0.027 * amp
		torso.rotation.z = s * 0.035 * amp
		head.rotation.z = -s * 0.02 * amp
	else:
		var k := clampf(delta * 9.0, 0.0, 1.0)
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, k)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, k)
		knee_l.rotation.x = lerpf(knee_l.rotation.x, 0.0, k)
		knee_r.rotation.x = lerpf(knee_r.rotation.x, 0.0, k)
		arm_l.rotation.x = lerpf(arm_l.rotation.x, sin(idle_phase * 1.5) * 0.025, k)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, sin(idle_phase * 1.5 + 1.0) * 0.025, k)
		elbow_l.rotation.x = lerpf(elbow_l.rotation.x, -0.15, k)
		elbow_r.rotation.x = lerpf(elbow_r.rotation.x, -0.15, k)
		hips.position.y = base_hip_y + sin(idle_phase * 1.6) * 0.006
		torso.rotation.z = lerpf(torso.rotation.z, 0.0, k)
		head.rotation.z = lerpf(head.rotation.z, 0.0, k)
		torso.rotation.x = sin(idle_phase * 1.3) * 0.012
	if punch_timer > 0.0:
		punch_timer = maxf(0.0, punch_timer - delta)
		var p := 1.0 - punch_timer / 0.30
		var swing := sin(clampf(p, 0.0, 1.0) * PI)
		arm_r.rotation.x = -0.2 - swing * 1.45
		elbow_r.rotation.x = -0.15 - swing * 0.35
		torso.rotation.y = -swing * 0.18

func punch() -> void:
	punch_timer = 0.30

func set_carrying(value: bool) -> void:
	carrying = value

func fall_down() -> void:
	dead = true
	if model:
		model.rotation_degrees.z = -88.0
		model.position.y = 0.12
		model.position.z = -0.35

func get_eye_position() -> Vector3:
	return head.global_position + Vector3(0, 0.12, 0) if head else global_position + Vector3(0, 1.6, 0)
