extends Node3D
class_name CityBuilder

var rng := RandomNumberGenerator.new()
var mat_cache: Dictionary = {}
var brick_tex: ImageTexture
var concrete_tex: ImageTexture
var asphalt_tex: ImageTexture
var wood_tex: ImageTexture
var water_normal: ImageTexture
var water_material: StandardMaterial3D
var reserved: Array[Rect2] = []
var buildings_root: Node3D
var props_root: Node3D
var time := 0.0
var riverboat: Node3D
var lamp_lights := 0
var building_names := [
	"RIVER & RYE", "PENNY POST", "MILLER BOOKS", "JUNIPER", "THE FOUNDRY",
	"MARA'S COURIER", "NORTH BANK", "LANTERN", "PETERS", "CORNER", "MARKET HALL",
	"STUDIO", "BELLWEATHER", "APPOMATTOX OUTFITTERS", "OLD TOWNE CAFE",
	"SOUTHSIDE RECORDS", "HALIFAX HARDWARE", "BLANDFORD BAKERY", "WALNUT HILL BOOKS",
	"RIVER CITY PRESS", "THE PADDLEWHEEL", "BRICK & BRINE", "SEVENTH STREET"
]
var brick_colors := [
	Color("#a9533c"), Color("#b97752"), Color("#8f4e3e"), Color("#cf9b6f"),
	Color("#a55d4e"), Color("#c28a63"), Color("#9a584b"), Color("#d2a16d"),
	Color("#bd7957"), Color("#85534c"), Color("#b56f52"), Color("#8b554a")
]

func _ready() -> void:
	rng.seed = 20261121
	reserved.clear()
	for rect_variant in WorldData.RESERVED_RECTS:
		reserved.append(rect_variant as Rect2)
	reserved.append(Rect2(34.0, -38.0, 18.0, 18.0))
	reserved.append(Rect2(-52.0, 30.0, 18.0, 20.0))
	reserved.append(Rect2(-60.0, -44.0, 24.0, 20.0))
	buildings_root = Node3D.new()
	buildings_root.name = "Buildings"
	add_child(buildings_root)
	props_root = Node3D.new()
	props_root.name = "StreetProps"
	add_child(props_root)
	_make_textures()
	_build_ground()
	_build_roads()
	_build_sidewalks()
	_build_river()
	_build_buildings()
	_build_outer_districts()
	_build_landmarks()
	_build_street_props()
	_build_riverfront_props()
	_build_boundaries()

func _process(delta: float) -> void:
	time += delta
	if water_material:
		water_material.uv1_offset = Vector3(time * 0.012, time * 0.018, 0.0)
	if riverboat:
		riverboat.position.y = -0.05 + sin(time * 0.7) * 0.035
		riverboat.rotation.z = sin(time * 0.5) * 0.004

func _make_textures() -> void:
	brick_tex = _make_brick_texture()
	concrete_tex = _make_concrete_texture()
	asphalt_tex = _make_asphalt_texture()
	wood_tex = _make_wood_texture()
	water_normal = _make_water_normal()

func _make_brick_texture() -> ImageTexture:
	var img := Image.create(256, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0.55, 0.52, 0.48))
	var brick_h := 12
	var brick_w := 28
	for row in range(int(128.0 / brick_h) + 1):
		var offset := 0 if row % 2 == 0 else brick_w / 2
		for col in range(-1, int(256.0 / brick_w) + 2):
			var x0 := col * brick_w + offset
			var y0 := row * brick_h
			var v := rng.randf_range(0.72, 0.9)
			var color := Color(v, v * 0.96, v * 0.9)
			for y in range(y0 + 1, mini(y0 + brick_h - 1, 128)):
				for x in range(maxi(x0 + 1, 0), mini(x0 + brick_w - 1, 256)):
					var n := rng.randf_range(-0.035, 0.035)
					img.set_pixel(x, y, Color(color.r + n, color.g + n, color.b + n))
	for i in range(1800):
		var x := rng.randi_range(0, 255)
		var y := rng.randi_range(0, 127)
		var c := img.get_pixel(x, y)
		var n := rng.randf_range(-0.05, 0.05)
		img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	return ImageTexture.create_from_image(img)

func _make_concrete_texture() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var v := 0.72 + rng.randf_range(-0.07, 0.07)
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.95))
	for i in range(12):
		var x := rng.randi_range(0, 255)
		var y := rng.randi_range(0, 255)
		for j in range(rng.randi_range(10, 50)):
			var px := clampi(x + j, 0, 255)
			var py := clampi(y + int(sin(float(j) * 0.5) * 4.0), 0, 255)
			img.set_pixel(px, py, Color(0.48, 0.47, 0.45))
	for y in range(0, 256, 64):
		for x in range(256):
			img.set_pixel(x, y, Color(0.46, 0.45, 0.43))
	for x in range(0, 256, 64):
		for y in range(256):
			img.set_pixel(x, y, Color(0.46, 0.45, 0.43))
	return ImageTexture.create_from_image(img)

func _make_asphalt_texture() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var v := 0.26 + rng.randf_range(-0.06, 0.06)
			img.set_pixel(x, y, Color(v, v, v * 1.03))
	for i in range(2600):
		var x := rng.randi_range(0, 255)
		var y := rng.randi_range(0, 255)
		var v := rng.randf_range(0.18, 0.42)
		img.set_pixel(x, y, Color(v, v, v))
	for i in range(18):
		var x := rng.randi_range(0, 255)
		var y := rng.randi_range(0, 255)
		for j in range(rng.randi_range(6, 20)):
			img.set_pixel(clampi(x + j, 0, 255), clampi(y + j / 2, 0, 255), Color(0.12, 0.12, 0.13))
	return ImageTexture.create_from_image(img)

func _make_wood_texture() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in range(128):
		for x in range(128):
			var plank := int(y / 16)
			var base := 0.58 + (plank % 3) * 0.04
			var grain := sin(float(x) * 0.35 + plank * 2.0) * 0.035
			var v := base + grain + rng.randf_range(-0.025, 0.025)
			img.set_pixel(x, y, Color(v, v * 0.82, v * 0.62))
	for y in range(0, 128, 16):
		for x in range(128):
			img.set_pixel(x, y, Color(0.28, 0.22, 0.16))
	return ImageTexture.create_from_image(img)

func _make_water_normal() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var hx := cos(float(x) * 0.12 + sin(float(y) * 0.07) * 3.0) * 0.12
			var hy := cos(float(y) * 0.19 + float(x) * 0.03) * 0.1
			var n := Vector3(-hx, -hy, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return ImageTexture.create_from_image(img)

func _tex_mat(tex: Texture2D, color: Color, scale: float, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "tex_%s_%s_%s_%s" % [tex.get_instance_id(), color.to_html(), scale, roughness]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = color
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = roughness
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_cache[key] = m
	return m

func _brick_mat(color: Color) -> StandardMaterial3D:
	var key := "brick_%s" % color.to_html()
	if mat_cache.has(key):
		return mat_cache[key]
	var m := _tex_mat(brick_tex, color, 0.55, 0.9)
	mat_cache[key] = m
	return m

func _concrete_mat(color: Color) -> StandardMaterial3D:
	return _tex_mat(concrete_tex, color, 0.42, 0.92)

func _asphalt_mat() -> StandardMaterial3D:
	if mat_cache.has("asphalt"):
		return mat_cache["asphalt"]
	var m := _tex_mat(asphalt_tex, Color("#7a7f80"), 0.16, 0.96)
	mat_cache["asphalt"] = m
	return m

func _wood_mat() -> StandardMaterial3D:
	if mat_cache.has("wood"):
		return mat_cache["wood"]
	var m := _tex_mat(wood_tex, Color("#b58a5c"), 0.8, 0.85)
	mat_cache["wood"] = m
	return m

func _mat(color: Color, roughness: float = 0.8, metallic: float = 0.0, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var key := "mat_%s_%s_%s_%s_%s" % [color.to_html(), roughness, metallic, emission.to_html(), energy]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	mat_cache[key] = m
	return m

func _glass_mat(color: Color, lit: bool) -> StandardMaterial3D:
	var key := "glass_%s_%s" % [color.to_html(), lit]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.12
	m.metallic = 0.45
	if lit:
		m.emission_enabled = true
		m.emission = Color("#ffd9a0")
		m.emission_energy_multiplier = 0.85
	mat_cache[key] = m
	return m

func _emissive(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m := _mat(color, 0.35, 0.0, color, energy)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _build_ground() -> void:
	var grass := _tex_mat(concrete_tex, Color("#5d715d"), 0.28, 0.95)
	_static_box("Ground", Vector3(0, -0.5, 0), Vector3(300, 1, 300), grass)
	_mesh_box("Riverbed", Vector3(0, -1.2, -104), Vector3(300, 0.4, 92), _mat(Color("#253d45"), 0.95))

func _build_roads() -> void:
	var asphalt := _asphalt_mat()
	_mesh_box("Main Street", Vector3(0, 0.015, 48), Vector3(14, 0.05, 188), asphalt)
	_mesh_box("Market Street", Vector3(0, 0.02, WorldData.MARKET_Z), Vector3(284, 0.05, 12), asphalt)
	_mesh_box("Halifax Avenue", Vector3(-100, 0.018, 51), Vector3(10, 0.05, 182), asphalt)
	_mesh_box("Blandford Avenue", Vector3(100, 0.019, 51), Vector3(10, 0.05, 182), asphalt)
	_mesh_box("Southside Boulevard", Vector3(0, 0.021, 104), Vector3(284, 0.05, 10), asphalt)
	for z in range(-42, 140, 9):
		if z < -2 or z > 18:
			_mesh_box("Main center dash", Vector3(0, 0.055, z), Vector3(0.16, 0.02, 4.0), _mat(Color("#d9c27a"), 0.8))
	for x in range(-138, 140, 10):
		if absf(x) > 12:
			_mesh_box("Market center dash", Vector3(x, 0.056, WorldData.MARKET_Z), Vector3(4.5, 0.02, 0.15), _mat(Color("#d9c27a"), 0.8))
	for z in range(-42, 140, 10):
		for x in [-6.5, 6.5]:
			_mesh_box("Main edge line", Vector3(x, 0.057, z), Vector3(0.1, 0.02, 5.0), _mat(Color("#d8d2bd"), 0.85))
	for x in range(-138, 140, 10):
		for z in [2.7, 13.3]:
			_mesh_box("Market edge line", Vector3(x, 0.058, z), Vector3(5.0, 0.02, 0.09), _mat(Color("#d8d2bd"), 0.85))
	_build_crosswalk(Vector3(0, 0.06, 0.0), true)
	_build_crosswalk(Vector3(0, 0.061, 16.0), true)
	_build_crosswalk(Vector3(-9.0, 0.062, 8.0), false)
	_build_crosswalk(Vector3(9.0, 0.063, 8.0), false)
	for i in range(14):
		var x := rng.randf_range(-130.0, 130.0)
		var z := rng.randf_range(-40.0, 138.0)
		if absf(x) < 12.0 or absf(z - 8.0) < 10.0:
			continue
		var pothole := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = rng.randf_range(0.35, 0.9)
		disc.bottom_radius = disc.top_radius
		disc.height = 0.02
		pothole.mesh = disc
		pothole.position = Vector3(x, 0.045, z)
		pothole.material_override = _mat(Color("#23282a"), 0.95)
		add_child(pothole)
	for pos in [Vector3(-3, 0.06, 26), Vector3(3.2, 0.06, -8), Vector3(-2, 0.06, 54), Vector3(22, 0.06, 8), Vector3(-40, 0.06, 8)]:
		var manhole := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.45
		disc.bottom_radius = 0.45
		disc.height = 0.025
		manhole.mesh = disc
		manhole.position = pos
		manhole.material_override = _mat(Color("#4b4e4e"), 0.6, 0.4)
		add_child(manhole)

func _build_crosswalk(center: Vector3, across_main: bool) -> void:
	for i in range(8):
		var offset := (float(i) - 3.5) * 1.15
		if across_main:
			_mesh_box("Crosswalk stripe", center + Vector3(offset, 0.0, 0), Vector3(0.55, 0.022, 4.8), _mat(Color("#ded8c8"), 0.85))
		else:
			_mesh_box("Crosswalk stripe", center + Vector3(0, 0.0, offset), Vector3(4.8, 0.022, 0.55), _mat(Color("#ded8c8"), 0.85))

func _build_sidewalks() -> void:
	var walk := _concrete_mat(Color("#b8b0a1"))
	_mesh_box("Main west sidewalk", Vector3(-9.5, 0.07, 48), Vector3(5, 0.12, 188), walk)
	_mesh_box("Main east sidewalk", Vector3(9.5, 0.07, 48), Vector3(5, 0.12, 188), walk)
	_mesh_box("Market north sidewalk", Vector3(0, 0.071, -0.5), Vector3(284, 0.12, 5), walk)
	_mesh_box("Market south sidewalk", Vector3(0, 0.072, 16.5), Vector3(284, 0.12, 5), walk)
	_mesh_box("Halifax west sidewalk", Vector3(-105.5, 0.073, 51), Vector3(3, 0.12, 182), walk)
	_mesh_box("Halifax east sidewalk", Vector3(-94.5, 0.074, 51), Vector3(3, 0.12, 182), walk)
	_mesh_box("Blandford west sidewalk", Vector3(94.5, 0.075, 51), Vector3(3, 0.12, 182), walk)
	_mesh_box("Blandford east sidewalk", Vector3(105.5, 0.076, 51), Vector3(3, 0.12, 182), walk)
	_mesh_box("Southside north sidewalk", Vector3(0, 0.077, 98.5), Vector3(284, 0.12, 3), walk)
	_mesh_box("Southside south sidewalk", Vector3(0, 0.078, 109.5), Vector3(284, 0.12, 3), walk)
	var curb := _mat(Color("#8d8a80"), 0.9)
	for x in [-7.1, 7.1]:
		_mesh_box("Curb", Vector3(x, 0.11, 48), Vector3(0.22, 0.2, 188), curb)
	for z in [2.2, 13.8]:
		_mesh_box("Curb", Vector3(0, 0.112, z), Vector3(284, 0.2, 0.22), curb)
	for i in range(18):
		var x := rng.randf_range(-130.0, 130.0)
		var z := 0.0 if i % 2 == 0 else 16.5
		_mesh_box("Sidewalk joint", Vector3(x, 0.135, z), Vector3(0.08, 0.02, 5.0), _mat(Color("#8f897d"), 0.9))

func _build_river() -> void:
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color("#1c5668")
	water_material.roughness = 0.46
	water_material.metallic = 0.0
	water_material.normal_enabled = true
	water_material.normal_texture = water_normal
	water_material.normal_scale = 1.15
	water_material.uv1_scale = Vector3(0.16, 0.16, 1.0)
	water_material.emission_enabled = true
	water_material.emission = Color("#123a46")
	water_material.emission_energy_multiplier = 0.18
	water_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var water := _mesh_box("Appomattox River", Vector3(0, -0.22, -104), Vector3(300, 0.12, 92), water_material)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stone := _concrete_mat(Color("#8a8273"))
	_static_box("River retaining wall", Vector3(0, 0.24, -58.6), Vector3(300, 0.48, 1.2), stone)
	_mesh_box("Riverwalk paving", Vector3(0, 0.08, -52), Vector3(300, 0.12, 12), _concrete_mat(Color("#b3a88f")))
	for x in range(-148, 150, 8):
		_mesh_box("Riverwalk paving band", Vector3(x, 0.145, -52), Vector3(0.1, 0.02, 12), _mat(Color("#998f79"), 0.9))
	var rail := _mat(Color("#2c363b"), 0.6, 0.4)
	for x in range(-148, 150, 4):
		_mesh_box("River rail post", Vector3(x, 0.75, -58.0), Vector3(0.12, 1.5, 0.12), rail)
	for y in [0.72, 1.38]:
		_mesh_box("River rail", Vector3(0, y, -58.0), Vector3(300, 0.08, 0.08), rail)
	var bank := _tex_mat(concrete_tex, Color("#526b52"), 0.3, 0.95)
	_mesh_box("Far bank", Vector3(0, -0.6, -158), Vector3(300, 1.4, 26), bank)
	for i in range(12):
		var x := rng.randf_range(-140.0, 140.0)
		var z := rng.randf_range(-168.0, -148.0)
		var hill := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(8.0, 18.0)
		sphere.height = sphere.radius * 1.1
		hill.mesh = sphere
		hill.position = Vector3(x, -4.0, z)
		hill.scale = Vector3(1.6, 0.55, 1.0)
		hill.material_override = _mat(Color("#3f5947"), 1.0)
		add_child(hill)
	for i in range(24):
		var x := rng.randf_range(-140.0, 140.0)
		var z := rng.randf_range(-148.0, -140.0)
		_tree(Vector3(x, 0.2, z), rng.randf_range(0.8, 1.5))

func _mesh_box(name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	add_child(mesh)
	return mesh

func _static_box(name: String, pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body

func _build_buildings() -> void:
	var rows := [
		{"start": -44.0, "end": -4.0, "front": -11.0, "axis": "z", "facing": Vector3(1, 0, 0), "depth": 14.0},
		{"start": -44.0, "end": -4.0, "front": 11.0, "axis": "z", "facing": Vector3(-1, 0, 0), "depth": 14.0},
		{"start": 20.0, "end": 70.0, "front": -11.0, "axis": "z", "facing": Vector3(1, 0, 0), "depth": 14.0},
		{"start": 20.0, "end": 70.0, "front": 11.0, "axis": "z", "facing": Vector3(-1, 0, 0), "depth": 14.0},
		{"start": -66.0, "end": -14.0, "front": -2.0, "axis": "x", "facing": Vector3(0, 0, 1), "depth": 13.0},
		{"start": 14.0, "end": 66.0, "front": -2.0, "axis": "x", "facing": Vector3(0, 0, 1), "depth": 13.0},
		{"start": -66.0, "end": -14.0, "front": 18.0, "axis": "x", "facing": Vector3(0, 0, -1), "depth": 13.0},
		{"start": 14.0, "end": 66.0, "front": 18.0, "axis": "x", "facing": Vector3(0, 0, -1), "depth": 13.0},
		{"start": 78.0, "end": 136.0, "front": -11.0, "axis": "z", "facing": Vector3(1, 0, 0), "depth": 14.0},
		{"start": 78.0, "end": 136.0, "front": 11.0, "axis": "z", "facing": Vector3(-1, 0, 0), "depth": 14.0},
		{"start": -136.0, "end": -74.0, "front": -2.0, "axis": "x", "facing": Vector3(0, 0, 1), "depth": 13.0},
		{"start": 74.0, "end": 136.0, "front": -2.0, "axis": "x", "facing": Vector3(0, 0, 1), "depth": 13.0}
	]
	for row in rows:
		_build_row(row)

func _build_row(row: Dictionary) -> void:
	var start := float(row.start)
	var end := float(row.end)
	var front := float(row.front)
	var axis := str(row.axis)
	var facing: Vector3 = row.facing
	var depth := float(row.depth)
	var cursor := start
	var name_index := rng.randi_range(0, building_names.size() - 1)
	while cursor < end - 4.0:
		var width := rng.randf_range(8.2, 12.6)
		if cursor + width > end:
			width = end - cursor
		if width < 5.0:
			break
		var along := cursor + width * 0.5
		var front_center := Vector3(front, 0, along) if axis == "z" else Vector3(along, 0, front)
		var center := front_center - facing * (depth * 0.5)
		var rect: Rect2
		if axis == "z":
			rect = Rect2(center.x - depth * 0.5, center.z - width * 0.5, depth, width)
		else:
			rect = Rect2(center.x - width * 0.5, center.z - depth * 0.5, width, depth)
		var blocked := false
		for r in reserved:
			if rect.grow(0.4).intersects(r):
				blocked = true
				break
		if blocked:
			cursor += 4.0
			continue
		var height := rng.randf_range(8.5, 15.0)
		var color: Color = brick_colors[rng.randi_range(0, brick_colors.size() - 1)]
		var sign: String = str(building_names[name_index % building_names.size()])
		name_index += 1
		var yaw := atan2(-facing.x, -facing.z)
		_building(center, width, depth, height, color, sign, yaw, rng.randi_range(0, 3))
		cursor += width + rng.randf_range(0.5, 1.3)
		if rng.randf() < 0.12:
			cursor += 2.2

func _building(center: Vector3, width: float, depth: float, height: float, color: Color, sign_text: String, yaw: float, style: int) -> void:
	var pivot := Node3D.new()
	pivot.name = "Storefront_" + sign_text.replace(" ", "_")
	pivot.position = center
	pivot.rotation.y = yaw
	buildings_root.add_child(pivot)
	var brick := _brick_mat(color)
	var trim := _mat(Color("#e5d3b2"), 0.8)
	var dark := _mat(Color("#2d3437"), 0.85)
	var wood := _wood_mat()
	var brick_dark := _brick_mat(color.darkened(0.18))
	var stone := _concrete_mat(Color("#9b9485"))
	_static_box_in(pivot, Vector3(0, height * 0.5, 0), Vector3(width, height, depth), brick)
	_box_in(pivot, Vector3(0, 0.42, -depth * 0.5 - 0.06), Vector3(width, 0.84, 0.12), stone)
	_box_in(pivot, Vector3(0, 1.6, -depth * 0.5 - 0.09), Vector3(width * 0.78, 2.9, 0.16), dark)
	for i in range(3):
		var x := -width * 0.24 + i * width * 0.24
		var lit := rng.randf() < 0.42
		_box_in(pivot, Vector3(x, 1.65, -depth * 0.5 - 0.18), Vector3(width * 0.19, 2.3, 0.08), _glass_mat(Color("#5d858c"), lit))
		_box_in(pivot, Vector3(x - width * 0.11, 1.65, -depth * 0.5 - 0.23), Vector3(0.07, 2.5, 0.08), trim)
	_box_in(pivot, Vector3(width * 0.31, 1.38, -depth * 0.5 - 0.2), Vector3(1.1, 2.7, 0.14), wood)
	_box_in(pivot, Vector3(width * 0.31, 1.42, -depth * 0.5 - 0.29), Vector3(0.08, 0.08, 0.04), _mat(Color("#d5b25f"), 0.3, 0.7))
	_box_in(pivot, Vector3(0, 3.25, -depth * 0.5 - 0.58), Vector3(width * 0.82, 0.18, 1.15), _mat(Color("#5f8a7d") if style % 2 == 0 else Color("#b5624c"), 0.85))
	for i in range(6):
		var stripe_x := -width * 0.34 + i * width * 0.136
		_box_in(pivot, Vector3(stripe_x, 3.35, -depth * 0.5 - 0.58), Vector3(width * 0.07, 0.03, 1.12), trim)
	_box_in(pivot, Vector3(0, 4.02, -depth * 0.5 - 0.17), Vector3(width * 0.84, 0.64, 0.14), dark)
	_label_in(pivot, sign_text, Vector3(0, 4.02, -depth * 0.5 - 0.26), 0.0052, Color("#f1d089"), 58, PI)
	_label_in(pivot, str(100 + (abs(int(center.x)) + abs(int(center.z))) % 800), Vector3(-width * 0.34, 2.95, -depth * 0.5 - 0.28), 0.0032, Color("#d9cba9"), 42, PI)
	_box_in(pivot, Vector3(-width * 0.43, 2.75, -depth * 0.5 - 0.18), Vector3(0.16, 0.4, 0.12), _emissive(Color("#ffd28a"), 1.2))
	_box_in(pivot, Vector3(width * 0.43, 2.75, -depth * 0.5 - 0.18), Vector3(0.16, 0.4, 0.12), _emissive(Color("#ffd28a"), 1.2))
	var floors := 2 if height < 11.8 else 3
	for floor in range(floors):
		var wy := 5.55 + floor * 2.75
		if wy + 1.2 > height - 0.4:
			break
		var count := clampi(int(width / 3.1), 2, 4)
		var spacing := width / float(count + 1)
		for i in range(count):
			var wx := -width * 0.5 + spacing * (i + 1)
			var lit := rng.randf() < 0.33
			_box_in(pivot, Vector3(wx, wy, -depth * 0.5 - 0.07), Vector3(1.38, 2.0, 0.1), trim)
			_box_in(pivot, Vector3(wx, wy, -depth * 0.5 - 0.15), Vector3(1.08, 1.7, 0.08), _glass_mat(Color("#648b91"), lit))
			_box_in(pivot, Vector3(wx, wy - 1.04, -depth * 0.5 - 0.17), Vector3(1.52, 0.12, 0.3), trim)
			_box_in(pivot, Vector3(wx, wy + 1.04, -depth * 0.5 - 0.14), Vector3(1.52, 0.1, 0.24), trim)
			if style == 1:
				for side in [-1, 1]:
					_box_in(pivot, Vector3(wx + side * 0.78, wy, -depth * 0.5 - 0.12), Vector3(0.16, 1.85, 0.08), _mat(Color("#5a6d63"), 0.9))
	_box_in(pivot, Vector3(0, height - 0.18, 0), Vector3(width + 0.55, 0.5, depth + 0.55), trim)
	_box_in(pivot, Vector3(0, height + 0.36, -depth * 0.5 + 0.22), Vector3(width + 0.2, 0.72, 0.38), brick_dark)
	_box_in(pivot, Vector3(0, height + 0.08, 0), Vector3(width - 0.25, 0.2, depth - 0.25), dark)
	_box_in(pivot, Vector3(width * 0.22, height + 0.55, 0.55), Vector3(1.3, 0.8, 1.0), _mat(Color("#7f8889"), 0.6, 0.2))
	_cylinder_in(pivot, Vector3(width * 0.22, height + 0.96, 0.55), 0.32, 0.05, dark, 24)
	if style == 2:
		_cylinder_in(pivot, Vector3(-width * 0.25, height + 1.45, 0.2), 0.95, 1.7, wood, 20)
		for lx in [-0.55, 0.55]:
			for lz in [-0.55, 0.55]:
				_box_in(pivot, Vector3(-width * 0.25 + lx, height + 0.55, 0.2 + lz), Vector3(0.08, 1.0, 0.08), dark)
	if style == 0 or style == 3:
		for level in [5.55, 8.25]:
			if level + 1.0 > height:
				continue
			_box_in(pivot, Vector3(0, level, -depth * 0.5 - 0.55), Vector3(minf(width * 0.46, 3.0), 0.08, 1.0), dark)
			_box_in(pivot, Vector3(0, level + 0.55, -depth * 0.5 - 1.02), Vector3(minf(width * 0.46, 3.0), 0.06, 0.06), dark)
			for side in [-1, 1]:
				_box_in(pivot, Vector3(side * minf(width * 0.23, 1.5), level + 0.3, -depth * 0.5 - 0.55), Vector3(0.05, 0.55, 0.05), dark)
			_box_in(pivot, Vector3(0, level + 0.65, -depth * 0.5 - 0.55), Vector3(0.05, 1.3, 0.05), dark)
	if style == 1:
		_box_in(pivot, Vector3(0, 5.05, -depth * 0.5 - 0.48), Vector3(2.3, 0.12, 0.95), stone)
		for side in [-1, 1]:
			_box_in(pivot, Vector3(side * 1.05, 5.5, -depth * 0.5 - 0.88), Vector3(0.06, 0.85, 0.06), dark)
		_box_in(pivot, Vector3(0, 5.9, -depth * 0.5 - 0.9), Vector3(2.2, 0.07, 0.07), dark)
	if style == 2:
		var mural_colors := [Color("#3e8b9a"), Color("#e0a64e"), Color("#c95f4e")]
		for i in range(3):
			_box_in(pivot, Vector3(width * 0.5 + 0.02, 5.8 + i * 1.1, -1.0 + i * 1.1), Vector3(0.04, 0.9, 1.0), _mat(mural_colors[i], 0.8))
	_box_in(pivot, Vector3(0, 0.06, -depth * 0.5 - 0.45), Vector3(width * 0.8, 0.12, 0.9), stone)

func _simple_building(center: Vector3, size: Vector3, color: Color, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = center
	pivot.rotation.y = yaw
	buildings_root.add_child(pivot)
	var brick := _brick_mat(color)
	var trim := _mat(Color("#d9c9ad"), 0.85)
	var dark := _mat(Color("#31383b"), 0.85)
	_static_box_in(pivot, Vector3(0, size.y * 0.5, 0), size, brick)
	_box_in(pivot, Vector3(0, size.y - 0.2, 0), Vector3(size.x + 0.4, 0.4, size.z + 0.4), trim)
	for floor in range(2):
		for i in range(3):
			var x := -size.x * 0.3 + i * size.x * 0.3
			_box_in(pivot, Vector3(x, 3.4 + floor * 2.5, -size.z * 0.5 - 0.06), Vector3(1.1, 1.5, 0.08), _glass_mat(Color("#5e858c"), rng.randf() < 0.3))
	_box_in(pivot, Vector3(0, 1.3, -size.z * 0.5 - 0.1), Vector3(size.x * 0.62, 2.3, 0.12), dark)
	_box_in(pivot, Vector3(0, 3.0, -size.z * 0.5 - 0.55), Vector3(size.x * 0.7, 0.15, 1.0), _mat(Color("#8b6c54"), 0.9))
	_label_in(pivot, building_names[rng.randi_range(0, building_names.size() - 1)], Vector3(0, 3.55, -size.z * 0.5 - 0.18), 0.0045, Color("#e7c987"), 50, PI)

func _build_outer_districts() -> void:
	var palette := [Color("#8f5b4b"), Color("#a97958"), Color("#7d5b50"), Color("#b18a67"), Color("#6e5b55")]
	var zones := [
		Rect2(-140, 20, 28, 70), Rect2(-140, 114, 28, 24), Rect2(112, 20, 28, 70),
		Rect2(112, 114, 28, 24), Rect2(-68, 112, 60, 26), Rect2(8, 112, 60, 26),
		Rect2(-68, -46, 50, 28), Rect2(-140, -46, 28, 24), Rect2(112, -46, 28, 24)
	]
	for zone_variant in zones:
		var zone: Rect2 = zone_variant
		for i in range(3):
			var w := rng.randf_range(9.0, 14.0)
			var d := rng.randf_range(10.0, 15.0)
			var x: float = zone.position.x + 6.0 + i * (zone.size.x - 12.0) / 2.6
			var z: float = zone.position.y + rng.randf_range(5.0, zone.size.y - 5.0)
			var center := Vector3(x, 0, z)
			var rect := Rect2(center.x - w * 0.5, center.z - d * 0.5, w, d)
			var blocked := false
			for r in reserved:
				if rect.intersects(r):
					blocked = true
					break
			if blocked:
				continue
			var h := rng.randf_range(7.0, 13.0)
			_simple_building(center + Vector3(0, 0, 0), Vector3(w, h, d), palette[rng.randi_range(0, palette.size() - 1)], atan2(-1, 0) if i % 2 == 0 else atan2(1, 0))
	# District gateway signs.
	for d in WorldData.DISTRICTS:
		if d.name == "OLD TOWNE":
			continue
		_district_sign(d.name, d.pos)

func _district_sign(text: String, pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	_box_in(pivot, Vector3(0, 2.2, 0), Vector3(0.35, 4.4, 0.35), _mat(Color("#3b4548"), 0.8))
	_box_in(pivot, Vector3(0, 4.25, 0), Vector3(6.4, 0.9, 0.25), _mat(Color("#2c5f6a"), 0.7))
	_label_in(pivot, text, Vector3(0, 4.25, 0.15), 0.006, Color("#f0d38a"), 52, 0.0)
	_label_in(pivot, "PETERSBURG", Vector3(0, 3.65, 0.15), 0.0032, Color("#cfe1df"), 34, 0.0)
func _build_landmarks() -> void:
	_courtyards()
	_old_towne_arch(Vector3(0, 0, -45))
	_clock_tower(Vector3(43, 0, -31))
	_church(Vector3(-43, 0, 40))
	_riverboat(Vector3(8, 0, -78))
	_bridge(Vector3(78, 0, -88))
	_kiosk(WorldData.KIOSK_POS)
	_fountain(Vector3(-20, 0, 35))
	_warehouse(Vector3(-44, 0, -28))
	_foundry(Vector3(39, 0, -31))
	_studio(Vector3(39, 0, 35))
	_riverwalk_sign(Vector3(-21, 0, -55.5))
	_alley_paving(Rect2(-25, -28, 14, 8))
	_alley_paving(Rect2(-24, 21, 13, 7))
	_alley_paving(Rect2(11, -29, 15, 7))
	_alley_paving(Rect2(11, 29, 17, 7))
	_string_lights(-2.0, -9.0, 9.0, 6.2)
	_string_lights(16.0, -9.0, 9.0, 6.4)
	_string_lights(34.0, -9.0, 9.0, 6.2)

func _old_towne_arch(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var brick := _brick_mat(Color("#9a584b"))
	var iron := _mat(Color("#293338"), 0.55, 0.45)
	var gold := _emissive(Color("#e7b45b"), 1.3)
	for x in [-8.4, 8.4]:
		_static_box_in(pivot, Vector3(x, 4.2, 0), Vector3(1.5, 8.4, 1.5), brick)
		_box_in(pivot, Vector3(x, 8.55, 0), Vector3(2.0, 0.35, 2.0), _mat(Color("#d8c39d"), 0.8))
	_box_in(pivot, Vector3(0, 8.4, 0), Vector3(18.4, 1.0, 1.0), iron)
	_box_in(pivot, Vector3(0, 9.15, 0.62), Vector3(7.2, 1.1, 0.24), _mat(Color("#223e46"), 0.7))
	_label_in(pivot, "OLD TOWNE", Vector3(0, 9.15, 0.76), 0.006, Color("#f0d38a"), 60, 0.0)
	_label_in(pivot, "PETERSBURG  ·  EST. 1750", Vector3(0, 8.35, 0.76), 0.0032, Color("#d5c6a6"), 34, 0.0)
	for i in range(10):
		var x := -8.0 + i * 1.75
		var y := 8.95 - sin(float(i) / 9.0 * PI) * 0.5
		_box_in(pivot, Vector3(x, y, 0.55), Vector3(0.16, 0.16, 0.16), gold)
	_box_in(pivot, Vector3(0, 8.95, 0.55), Vector3(17.0, 0.04, 0.04), iron)

func _clock_tower(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var brick := _brick_mat(Color("#a55d4e"))
	var trim := _mat(Color("#e3d0ad"), 0.8)
	var dark := _mat(Color("#263236"), 0.8)
	_static_box_in(pivot, Vector3(0, 8.0, 0), Vector3(6.4, 16.0, 6.4), brick)
	for y in [4.0, 8.0, 12.0, 16.0]:
		_box_in(pivot, Vector3(0, y, 0), Vector3(7.0, 0.35, 7.0), trim)
	for x in [-2.6, 2.6]:
		for z in [-2.6, 2.6]:
			_box_in(pivot, Vector3(x, 13.0, z), Vector3(0.5, 2.0, 0.5), dark)
	var face := _cylinder_in(pivot, Vector3(0, 13.2, 3.25), 1.7, 0.12, _mat(Color("#efe7d4"), 0.7), 32, Vector3(PI / 2.0, 0, 0))
	_box_in(pivot, Vector3(0, 13.2, 3.36), Vector3(0.12, 1.1, 0.04), dark)
	_box_in(pivot, Vector3(0.45, 13.45, 3.36), Vector3(0.8, 0.1, 0.04), dark)
	_label_in(pivot, "RIVER CITY", Vector3(0, 10.6, 3.35), 0.0032, Color("#f0d38a"), 34, 0.0)
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 4.6
	cone.height = 4.2
	cone.radial_segments = 4
	roof.mesh = cone
	roof.position = Vector3(0, 18.1, 0)
	roof.rotation.y = PI / 4.0
	roof.material_override = _mat(Color("#3d5357"), 0.7)
	pivot.add_child(roof)
	_box_in(pivot, Vector3(0, 20.6, 0), Vector3(0.15, 1.6, 0.15), _emissive(Color("#e7b45b"), 1.0))

func _church(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var brick := _brick_mat(Color("#8f4e3e"))
	var roof_mat := _mat(Color("#3e4b4e"), 0.8)
	var trim := _mat(Color("#d9c8a8"), 0.8)
	_static_box_in(pivot, Vector3(0, 5.0, 0), Vector3(11.0, 10.0, 17.0), brick)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(11.6, 3.2, 17.4)
	roof.mesh = prism
	roof.position = Vector3(0, 11.5, 0)
	roof.material_override = roof_mat
	pivot.add_child(roof)
	_static_box_in(pivot, Vector3(0, 10.0, -8.0), Vector3(4.2, 20.0, 4.2), brick)
	var spire := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 3.0
	cone.height = 7.0
	cone.radial_segments = 4
	spire.mesh = cone
	spire.position = Vector3(0, 23.5, -8.0)
	spire.rotation.y = PI / 4.0
	spire.material_override = roof_mat
	pivot.add_child(spire)
	_box_in(pivot, Vector3(0, 27.4, -8.0), Vector3(0.16, 1.6, 0.16), _mat(Color("#d8c7a2"), 0.5, 0.5))
	_box_in(pivot, Vector3(0, 27.6, -8.0), Vector3(0.8, 0.14, 0.14), _mat(Color("#d8c7a2"), 0.5, 0.5))
	for z in [-5.0, 0.0, 5.0]:
		_box_in(pivot, Vector3(0, 4.0, z), Vector3(0.16, 5.0, 2.0), _glass_mat(Color("#5f7e8a"), false))
	_box_in(pivot, Vector3(0, 2.0, -10.2), Vector3(2.2, 4.0, 0.2), _wood_mat())
	_label_in(pivot, "ST. LUKE'S", Vector3(0, 6.8, -10.35), 0.004, Color("#e7d3a5"), 42, PI)

func _warehouse(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = -PI / 2.0
	add_child(pivot)
	var brick := _brick_mat(Color("#8b554a"))
	var metal := _mat(Color("#556568"), 0.65, 0.3)
	_static_box_in(pivot, Vector3(0, 5.0, 0), Vector3(16.0, 10.0, 12.0), brick)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(16.8, 2.4, 12.8)
	roof.mesh = prism
	roof.position = Vector3(0, 11.2, 0)
	roof.material_override = metal
	pivot.add_child(roof)
	_box_in(pivot, Vector3(0, 2.8, -6.2), Vector3(5.0, 5.0, 0.3), _mat(Color("#394346"), 0.8))
	_box_in(pivot, Vector3(0, 5.55, -6.35), Vector3(5.6, 0.3, 0.3), _emissive(Color("#ffd38a"), 0.7))
	_label_in(pivot, "FOUNDRY WAREHOUSE", Vector3(0, 6.5, -6.4), 0.0045, Color("#e7c987"), 46, PI)
	for i in range(7):
		var x := -6.0 + i * 2.0
		_box_in(pivot, Vector3(x, 0.35, -7.0), Vector3(1.1, 0.7, 1.0), _wood_mat())

func _foundry(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = PI / 2.0
	add_child(pivot)
	var brick := _brick_mat(Color("#7d5b50"))
	var metal := _mat(Color("#48585c"), 0.6, 0.35)
	_static_box_in(pivot, Vector3(0, 6.5, 0), Vector3(18.0, 13.0, 13.0), brick)
	for i in range(4):
		_cylinder_in(pivot, Vector3(-6.0 + i * 4.0, 14.0, 0), 0.8, 3.5, metal, 12)
	_box_in(pivot, Vector3(0, 2.6, -6.7), Vector3(4.2, 5.2, 0.3), _mat(Color("#2d383b"), 0.8))
	_label_in(pivot, "OLD FOUNDRY", Vector3(0, 7.0, -6.85), 0.005, Color("#e7c987"), 50, PI)
	_box_in(pivot, Vector3(0, 9.2, -6.9), Vector3(12.0, 0.35, 0.3), _emissive(Color("#e7b45b"), 0.7))

func _studio(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = PI / 2.0
	add_child(pivot)
	var brick := _brick_mat(Color("#a97958"))
	var trim := _mat(Color("#e1cfad"), 0.8)
	_static_box_in(pivot, Vector3(0, 5.0, 0), Vector3(15.0, 10.0, 12.0), brick)
	_box_in(pivot, Vector3(0, 9.8, 0), Vector3(15.6, 0.4, 12.6), trim)
	_box_in(pivot, Vector3(0, 2.8, -6.15), Vector3(6.0, 5.0, 0.25), _glass_mat(Color("#5d858c"), true))
	_label_in(pivot, "SOUTHSIDE STUDIO", Vector3(0, 6.2, -6.3), 0.0045, Color("#e7c987"), 44, PI)
	var colors := [Color("#3e8b9a"), Color("#e0a64e"), Color("#c95f4e")]
	for i in range(3):
		_box_in(pivot, Vector3(-3.0 + i * 3.0, 8.0, -6.3), Vector3(2.4, 2.0, 0.06), _mat(colors[i], 0.8))
	_cylinder_in(pivot, Vector3(5.0, 11.0, 0), 0.7, 2.0, _mat(Color("#6b7b7d"), 0.6, 0.3), 12)

func _kiosk(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = PI
	add_child(pivot)
	var teal := _mat(Color("#2f7381"), 0.7)
	var gold := _emissive(Color("#e7b45b"), 1.0)
	var body := StaticBody3D.new()
	body.name = "CourierKiosk"
	body.position = Vector3(0, 1.25, 0)
	body.collision_layer = 16
	body.collision_mask = 0
	body.set_meta("interact_id", "mission_board")
	pivot.add_child(body)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.2, 2.5, 1.8)
	shape.shape = box_shape
	body.add_child(shape)
	_box_in(body, Vector3(0, 0, 0), Vector3(2.2, 2.5, 1.8), teal)
	_box_in(body, Vector3(0, 1.3, 0), Vector3(2.5, 0.2, 2.1), _mat(Color("#d8c39d"), 0.8))
	_box_in(body, Vector3(0, 0.55, -0.93), Vector3(1.6, 0.9, 0.08), _mat(Color("#e7ddc8"), 0.8))
	_label_in(body, "MARA'S COURIER", Vector3(0, 1.45, -0.98), 0.0045, Color("#ffe1a0"), 46, PI)
	_label_in(body, "PARCELS · RIVER CITY", Vector3(0, 1.08, -0.98), 0.0028, Color("#d6ece8"), 30, PI)
	for i in range(3):
		_box_in(body, Vector3(-0.4 + i * 0.4, 0.6, -0.99), Vector3(0.28, 0.4, 0.02), _mat(Color("#f4ecd8"), 0.8))
	_box_in(pivot, Vector3(0, 2.8, 0), Vector3(2.6, 0.15, 2.2), gold)
	_box_in(pivot, Vector3(0, 2.3, -0.7), Vector3(1.8, 0.08, 0.08), gold)

func _fountain(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var stone := _concrete_mat(Color("#b7ad98"))
	var water := _mat(Color("#3c7f8f"), 0.15, 0.4, Color("#3c7f8f"), 0.2)
	var basin := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 3.4
	cylinder.bottom_radius = 3.6
	cylinder.height = 0.65
	cylinder.radial_segments = 32
	basin.mesh = cylinder
	basin.position.y = 0.32
	basin.material_override = stone
	pivot.add_child(basin)
	var water_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.0
	disc.bottom_radius = 3.0
	disc.height = 0.08
	disc.radial_segments = 32
	water_disc.mesh = disc
	water_disc.position.y = 0.66
	water_disc.material_override = water
	pivot.add_child(water_disc)
	_cylinder_in(pivot, Vector3(0, 1.3, 0), 0.35, 1.4, stone, 16)
	_cylinder_in(pivot, Vector3(0, 2.0, 0), 0.08, 1.2, _emissive(Color("#bfe9ef"), 1.0), 8)
	for i in range(8):
		var a := float(i) / 8.0 * TAU
		_box_in(pivot, Vector3(cos(a) * 4.1, 0.55, sin(a) * 4.1), Vector3(0.5, 1.1, 0.5), stone)

func _riverwalk_sign(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var wood := _wood_mat()
	_box_in(pivot, Vector3(-2.4, 1.4, 0), Vector3(0.25, 2.8, 0.25), wood)
	_box_in(pivot, Vector3(2.4, 1.4, 0), Vector3(0.25, 2.8, 0.25), wood)
	_box_in(pivot, Vector3(0, 2.3, 0), Vector3(5.6, 1.1, 0.2), _mat(Color("#2c5f6a"), 0.8))
	_label_in(pivot, "APPOMATTOX RIVERWALK", Vector3(0, 2.3, 0.16), 0.0045, Color("#f0d38a"), 42, 0.0)
	_label_in(pivot, "PETERSBURG · VIRGINIA", Vector3(0, 1.75, 0.16), 0.0028, Color("#d7e4df"), 28, 0.0)

func _courtyards() -> void:
	var stone := _concrete_mat(Color("#8f8676"))
	var trim := _mat(Color("#6f6759"), 0.92)
	_plaza(Vector3(-24.0, 0.05, -24.0), Vector2(19.0, 19.0), stone, trim)
	_plaza(Vector3(-26.0, 0.05, 25.0), Vector2(13.0, 9.0), stone, trim)
	_plaza(Vector3(24.0, 0.05, -26.0), Vector2(13.0, 11.0), stone, trim)
	_plaza(Vector3(26.0, 0.05, 32.0), Vector2(13.0, 10.0), stone, trim)
	_planter(Vector3(-31.0, 0.0, -31.0))
	_planter(Vector3(-17.0, 0.0, -31.0))
	_bench(Vector3(-31.5, 0.0, -24.0), PI / 2.0)
	_bench(Vector3(-16.5, 0.0, -24.0), -PI / 2.0)
	_planter(Vector3(-31.0, 0.0, 28.0))
	_planter(Vector3(19.0, 0.0, -30.0))
	_planter(Vector3(29.0, 0.0, 28.0))
	var wood := _wood_mat()
	var steel := _mat(Color("#4b595c"), 0.6, 0.3)
	for i in range(4):
		var cx := -30.0 + (i % 2) * 1.15
		var cz := -29.5 + int(i / 2) * 1.15
		_box_in(self, Vector3(cx, 0.4, cz), Vector3(1.0, 0.8, 0.9), wood)
		_box_in(self, Vector3(cx, 0.82, cz), Vector3(1.02, 0.05, 0.92), _mat(Color("#c8a166"), 0.8))
	_box_in(self, Vector3(-28.6, 0.55, -25.2), Vector3(1.8, 1.1, 1.2), steel)
	_box_in(self, Vector3(-28.6, 1.14, -25.2), Vector3(1.85, 0.08, 1.25), _mat(Color("#2b3537"), 0.8))
	_box_in(self, Vector3(-27.6, 0.55, -25.2), Vector3(0.04, 1.0, 1.1), _mat(Color("#6b7a7c"), 0.6, 0.3))

func _plaza(center: Vector3, size: Vector2, stone: Material, trim: Material) -> void:
	_mesh_box("Courtyard paving", center, Vector3(size.x, 0.08, size.y), stone)
	for i in range(1, int(size.x / 3.0)):
		_mesh_box("Courtyard joint", center + Vector3(-size.x * 0.5 + i * 3.0, 0.045, 0), Vector3(0.06, 0.02, size.y), trim)
	for i in range(1, int(size.y / 3.0)):
		_mesh_box("Courtyard joint", center + Vector3(0, 0.046, -size.y * 0.5 + i * 3.0), Vector3(size.x, 0.02, 0.06), trim)

func _alley_paving(rect: Rect2) -> void:
	var center := Vector3(rect.position.x + rect.size.x * 0.5, 0.05, rect.position.y + rect.size.y * 0.5)
	_mesh_box("Alley paving", center, Vector3(rect.size.x, 0.1, rect.size.y), _concrete_mat(Color("#9f9480")))
	for i in range(4):
		var x := rect.position.x + 2.0 + i * (rect.size.x - 4.0) / 3.0
		_mesh_box("Alley light", Vector3(x, 3.2, rect.position.y + rect.size.y * 0.5), Vector3(0.12, 0.12, 0.12), _emissive(Color("#ffd38a"), 1.2))

func _riverboat(pos: Vector3) -> void:
	riverboat = Node3D.new()
	riverboat.position = pos
	add_child(riverboat)
	var hull := _mat(Color("#5d3f34"), 0.85)
	var white := _mat(Color("#e5ddc8"), 0.7)
	var red := _mat(Color("#9e3f35"), 0.7)
	var dark := _mat(Color("#2e3639"), 0.7)
	_box_in(riverboat, Vector3(0, 0.4, 0), Vector3(18.0, 1.6, 5.0), hull)
	_box_in(riverboat, Vector3(0, 1.35, 0), Vector3(15.0, 0.5, 4.6), white)
	_box_in(riverboat, Vector3(-2.0, 2.3, 0), Vector3(10.0, 1.6, 3.8), white)
	_box_in(riverboat, Vector3(-2.0, 3.2, 0), Vector3(10.6, 0.25, 4.2), red)
	for i in range(5):
		_box_in(riverboat, Vector3(-6.0 + i * 2.0, 2.5, -1.95), Vector3(1.1, 0.8, 0.06), _emissive(Color("#ffd9a0"), 0.8))
	_cylinder_in(riverboat, Vector3(2.0, 4.2, 0), 0.55, 3.2, dark, 12)
	_cylinder_in(riverboat, Vector3(4.0, 4.2, 0), 0.55, 3.2, dark, 12)
	_cylinder_in(riverboat, Vector3(2.0, 5.9, 0), 0.7, 0.2, red, 12)
	_cylinder_in(riverboat, Vector3(4.0, 5.9, 0), 0.7, 0.2, red, 12)
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.7
	torus.outer_radius = 2.3
	torus.rings = 24
	torus.ring_segments = 8
	wheel.mesh = torus
	wheel.position = Vector3(-9.6, 1.8, 0)
	wheel.rotation.y = PI / 2.0
	wheel.material_override = red
	riverboat.add_child(wheel)
	_label_in(riverboat, "RIVER QUEEN", Vector3(-2.0, 2.6, -2.0), 0.0038, Color("#3a2b24"), 42, PI)

func _bridge(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var steel := _mat(Color("#5a6769"), 0.6, 0.4)
	var dark := _mat(Color("#323d40"), 0.8)
	_box_in(pivot, Vector3(0, 3.2, 0), Vector3(8.0, 0.6, 64.0), steel)
	for z in [-28.0, -10.0, 8.0, 26.0]:
		_cylinder_in(pivot, Vector3(-3.0, 1.0, z), 0.7, 6.0, dark, 10)
		_cylinder_in(pivot, Vector3(3.0, 1.0, z), 0.7, 6.0, dark, 10)
	for z in [-30.0, -10.0, 10.0, 30.0]:
		_box_in(pivot, Vector3(0, 7.0, z), Vector3(0.25, 7.0, 0.25), steel)
	for z in [-30.0, -10.0, 10.0, 30.0]:
		_box_in(pivot, Vector3(0, 6.8, z), Vector3(8.2, 0.16, 0.16), steel)
	for i in range(8):
		_box_in(pivot, Vector3(0, 5.6, -30.0 + i * 8.0), Vector3(0.08, 2.5, 0.08), steel)
func _build_street_props() -> void:
	for i in range(14):
		var z := -38.0 + i * 12.5
		var side := -9.6 if i % 2 == 0 else 9.6
		_street_lamp(Vector3(side, 0, z), lamp_lights < 10)
	for i in range(12):
		var x := -128.0 + i * 22.0
		var z := -0.8 if i % 2 == 0 else 16.8
		_street_lamp(Vector3(x, 0, z), lamp_lights < 10)
	for i in range(10):
		var x := -120.0 + i * 27.0
		if absf(x) < 12.0:
			continue
		_planter(Vector3(x, 0, 0.4))
		_planter(Vector3(x, 0, 15.6))
	for i in range(12):
		var z := -34.0 + i * 13.0
		var x := -9.6 if i % 2 == 0 else 9.6
		_tree(Vector3(x, 0, z), rng.randf_range(0.8, 1.15))
	for i in range(9):
		var x := -112.0 + i * 28.0
		if absf(x) < 14.0:
			continue
		_tree(Vector3(x, 0, -1.8), rng.randf_range(0.75, 1.05))
		_tree(Vector3(x, 0, 17.8), rng.randf_range(0.75, 1.05))
	for pos in [Vector3(-9.2, 0, 24), Vector3(9.2, 0, 12), Vector3(-9.2, 0, -18), Vector3(9.2, 0, 32), Vector3(-9.2, 0, 46), Vector3(9.2, 0, 56)]:
		_bench(pos, PI / 2.0 if pos.x > 0 else -PI / 2.0)
	for pos in [Vector3(-9.2, 0, 36), Vector3(9.2, 0, 44), Vector3(-9.2, 0, 52), Vector3(9.2, 0, -22)]:
		_trash(pos)
	for pos in [Vector3(-9.2, 0, 30), Vector3(9.2, 0, 20), Vector3(-9.2, 0, 10), Vector3(9.2, 0, -4)]:
		_hydrant(pos)
	for i in range(8):
		_bollard(Vector3(-5.2 + i * 1.5, 0, 15.4))
	for pos in [Vector3(-9.0, 0, 33), Vector3(9.0, 0, 27), Vector3(-9.0, 0, 15)]:
		_newspaper_box(pos, Color("#2f6d7b"))
	_parking_meter(Vector3(-8.9, 0, 25))
	_parking_meter(Vector3(8.9, 0, 23))
	_bike_rack(Vector3(-8.8, 0, 26))
	_bus_stop(Vector3(-8.9, 0, 40))
	_cafe_set(Vector3(-8.8, 0, 12), 0.0)
	_cafe_set(Vector3(8.8, 0, 18), PI)
	_cafe_set(Vector3(8.8, 0, -14), PI)
	_cafe_set(Vector3(-8.8, 0, 48), 0.0)

func _build_riverfront_props() -> void:
	for i in range(9):
		var x := -128.0 + i * 32.0
		_street_lamp(Vector3(x, 0, -48.0), lamp_lights < 14)
	for i in range(8):
		var x := -112.0 + i * 32.0
		_bench(Vector3(x, 0, -49.0), PI)
	for i in range(7):
		var x := -100.0 + i * 34.0
		_tree(Vector3(x, 0, -46.5), rng.randf_range(0.8, 1.15))
	for i in range(12):
		var x := -132.0 + i * 24.0
		_planter(Vector3(x, 0, -45.6))
	_pergola(Vector3(-30, 0, -53))
	_pier(Vector3(18, 0, -64))
	for i in range(6):
		_bollard(Vector3(-10.0 + i * 4.0, 0, -45.2))
	for i in range(8):
		var x := -140.0 + i * 40.0
		_trash(Vector3(x, 0, -47.0))

func _build_boundaries() -> void:
	_invisible_wall(Vector3(149.0, 6.0, 0), Vector3(2.0, 14.0, 300.0))
	_invisible_wall(Vector3(-149.0, 6.0, 0), Vector3(2.0, 14.0, 300.0))
	_invisible_wall(Vector3(0, 6.0, 149.0), Vector3(300.0, 14.0, 2.0))
	_invisible_wall(Vector3(0, 6.0, -149.0), Vector3(300.0, 14.0, 2.0))

func _tree(pos: Vector3, scale: float = 1.0) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.scale = Vector3(scale, scale, scale)
	add_child(pivot)
	var trunk := _cylinder_in(pivot, Vector3(0, 2.0, 0), 0.28, 4.0, _mat(Color("#6f5039"), 0.95), 10)
	var body := StaticBody3D.new()
	body.position = Vector3(0, 2.0, 0)
	body.collision_layer = 1
	body.collision_mask = 0
	pivot.add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = 4.0
	shape.shape = cylinder
	body.add_child(shape)
	for i in range(3):
		var canopy := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(1.7, 2.4)
		sphere.height = sphere.radius * 1.7
		canopy.mesh = sphere
		canopy.position = Vector3(rng.randf_range(-0.7, 0.7), 4.6 + i * 0.9, rng.randf_range(-0.7, 0.7))
		canopy.material_override = _mat(Color("#4f7658").lerp(Color("#6b8b5e"), rng.randf()), 1.0)
		pivot.add_child(canopy)
	_box_in(pivot, Vector3(0, 0.02, 0), Vector3(2.0, 0.05, 2.0), _mat(Color("#3d4438"), 1.0))

func _street_lamp(pos: Vector3, with_light: bool) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var dark := _mat(Color("#263136"), 0.55, 0.4)
	var gold := _emissive(Color("#ffd18a"), 1.4)
	_cylinder_in(pivot, Vector3(0, 2.7, 0), 0.09, 5.4, dark, 8)
	_cylinder_in(pivot, Vector3(0, 0.1, 0), 0.28, 0.2, dark, 8)
	_box_in(pivot, Vector3(0.45, 5.3, 0), Vector3(1.1, 0.08, 0.08), dark)
	_box_in(pivot, Vector3(0.9, 5.1, 0), Vector3(0.55, 0.35, 0.55), dark)
	_box_in(pivot, Vector3(0.9, 4.95, 0), Vector3(0.36, 0.18, 0.36), gold)
	if with_light:
		var light := OmniLight3D.new()
		light.position = Vector3(0.9, 4.8, 0)
		light.light_color = Color("#ffd29a")
		light.light_energy = 1.2
		light.omni_range = 10.0
		light.shadow_enabled = false
		pivot.add_child(light)
		lamp_lights += 1
	var banner := _box_in(pivot, Vector3(0, 4.1, 0), Vector3(0.55, 1.2, 0.04), _mat(Color("#2f6d7b"), 0.8))
	banner.rotation.y = PI / 2.0

func _bench(pos: Vector3, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	add_child(pivot)
	var wood := _wood_mat()
	var metal := _mat(Color("#2d3639"), 0.6, 0.4)
	for i in range(3):
		_box_in(pivot, Vector3(0, 0.52, -0.15 + i * 0.16), Vector3(1.9, 0.08, 0.13), wood)
	for i in range(2):
		_box_in(pivot, Vector3(0, 0.86 + i * 0.18, 0.22), Vector3(1.9, 0.08, 0.12), wood)
	for x in [-0.78, 0.78]:
		_box_in(pivot, Vector3(x, 0.27, 0), Vector3(0.08, 0.54, 0.5), metal)
		_box_in(pivot, Vector3(x, 0.9, 0.24), Vector3(0.08, 0.9, 0.08), metal)

func _planter(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	_box_in(pivot, Vector3(0, 0.35, 0), Vector3(1.5, 0.7, 1.5), _concrete_mat(Color("#9d9584")))
	_box_in(pivot, Vector3(0, 0.72, 0), Vector3(1.3, 0.08, 1.3), _mat(Color("#3f3024"), 0.95))
	for i in range(3):
		_sphere_in(pivot, Vector3(rng.randf_range(-0.35, 0.35), 1.05, rng.randf_range(-0.35, 0.35)), rng.randf_range(0.3, 0.5), _mat(Color("#547b58"), 1.0))

func _hydrant(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var red := _mat(Color("#b4473c"), 0.7)
	_cylinder_in(pivot, Vector3(0, 0.42, 0), 0.17, 0.84, red, 10)
	_cylinder_in(pivot, Vector3(0, 0.9, 0), 0.24, 0.12, red, 10)
	for x in [-0.22, 0.22]:
		_cylinder_in(pivot, Vector3(x, 0.58, 0), 0.09, 0.18, red, 8, Vector3(0, 0, PI / 2.0))

func _trash(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var metal := _mat(Color("#3e4c4d"), 0.65, 0.3)
	_cylinder_in(pivot, Vector3(0, 0.55, 0), 0.36, 1.1, metal, 12)
	_cylinder_in(pivot, Vector3(0, 1.13, 0), 0.4, 0.08, _mat(Color("#263234"), 0.7), 12)

func _bollard(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var dark := _mat(Color("#2d383b"), 0.6, 0.35)
	_cylinder_in(pivot, Vector3(0, 0.45, 0), 0.1, 0.9, dark, 8)
	_cylinder_in(pivot, Vector3(0, 0.92, 0), 0.13, 0.1, _emissive(Color("#e7b45b"), 0.8), 8)

func _cafe_set(pos: Vector3, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	add_child(pivot)
	var metal := _mat(Color("#3a4447"), 0.6, 0.4)
	var cloth := _mat(Color("#d9c9a8"), 0.8)
	_cylinder_in(pivot, Vector3(0, 0.72, 0), 0.48, 0.08, cloth, 16)
	_cylinder_in(pivot, Vector3(0, 0.35, 0), 0.06, 0.7, metal, 8)
	for x in [-0.75, 0.75]:
		_box_in(pivot, Vector3(x, 0.3, 0), Vector3(0.42, 0.06, 0.42), _wood_mat())
		_box_in(pivot, Vector3(x, 0.58, 0.22), Vector3(0.42, 0.5, 0.06), _wood_mat())
		for lx in [-0.15, 0.15]:
			for lz in [-0.15, 0.15]:
				_box_in(pivot, Vector3(x + lx, 0.15, lz), Vector3(0.04, 0.3, 0.04), metal)
	_cylinder_in(pivot, Vector3(0, 1.7, 0), 0.06, 2.0, metal, 8)
	var umbrella := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.45
	cone.height = 0.6
	cone.radial_segments = 8
	umbrella.mesh = cone
	umbrella.position = Vector3(0, 2.65, 0)
	umbrella.material_override = _mat(Color("#c56e55"), 0.8)
	pivot.add_child(umbrella)

func _bus_stop(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var metal := _mat(Color("#39484b"), 0.6, 0.3)
	var glass := _glass_mat(Color("#8db2b6"), false)
	_box_in(pivot, Vector3(0, 2.3, 0), Vector3(3.6, 0.15, 1.8), metal)
	for x in [-1.7, 1.7]:
		_box_in(pivot, Vector3(x, 1.15, 0), Vector3(0.1, 2.3, 0.1), metal)
	_box_in(pivot, Vector3(0, 1.2, 0.85), Vector3(3.4, 2.2, 0.05), glass)
	_box_in(pivot, Vector3(0, 0.45, 0.3), Vector3(3.0, 0.1, 0.5), _wood_mat())
	_box_in(pivot, Vector3(0, 0.7, 0.5), Vector3(2.8, 0.06, 0.45), _wood_mat())
	_label_in(pivot, "RIVER CITY TRANSIT", Vector3(0, 2.75, -0.2), 0.003, Color("#f0d38a"), 30, PI)

func _newspaper_box(pos: Vector3, color: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	_box_in(pivot, Vector3(0, 0.55, 0), Vector3(0.45, 1.1, 0.45), _mat(color, 0.7))
	_box_in(pivot, Vector3(0, 0.85, -0.23), Vector3(0.32, 0.3, 0.02), _mat(Color("#e7e0cc"), 0.8))

func _parking_meter(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	_cylinder_in(pivot, Vector3(0, 0.6, 0), 0.05, 1.2, _mat(Color("#3a4447"), 0.6, 0.4), 8)
	_box_in(pivot, Vector3(0, 1.25, 0), Vector3(0.22, 0.36, 0.18), _mat(Color("#4a5b5d"), 0.6, 0.4))
	_box_in(pivot, Vector3(0, 1.28, -0.1), Vector3(0.12, 0.14, 0.02), _emissive(Color("#ffd18a"), 0.6))

func _bike_rack(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var metal := _mat(Color("#4c5c60"), 0.5, 0.5)
	for i in range(3):
		var x := -0.5 + i * 0.5
		_box_in(pivot, Vector3(x, 0.35, 0), Vector3(0.05, 0.7, 0.05), metal)
		_box_in(pivot, Vector3(x, 0.7, 0), Vector3(0.05, 0.05, 0.8), metal)
		_box_in(pivot, Vector3(x, 0.7, 0.4), Vector3(0.05, 0.6, 0.05), metal)
		_box_in(pivot, Vector3(x, 0.7, -0.4), Vector3(0.05, 0.6, 0.05), metal)

func _string_lights(z: float, x_start: float, x_end: float, y: float) -> void:
	var length := x_end - x_start
	for i in range(13):
		var t := float(i) / 12.0
		var x := x_start + length * t
		var sag := sin(t * PI) * 0.7
		var bulb := _sphere_in(self, Vector3(x, y - sag, z), 0.1, _emissive(Color("#ffd18a"), 1.6))
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(6):
		var t := float(i) / 5.0
		var x := x_start + length * t
		var sag := sin(t * PI) * 0.7
		_box_in(self, Vector3(x, y - sag + 0.15, z), Vector3(length / 5.0, 0.02, 0.02), _mat(Color("#252a2b"), 0.9))

func _pergola(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var wood := _wood_mat()
	for x in [-2.2, 2.2]:
		for z in [-1.8, 1.8]:
			_box_in(pivot, Vector3(x, 1.4, z), Vector3(0.2, 2.8, 0.2), wood)
	for x in [-2.4, 2.4]:
		_box_in(pivot, Vector3(x, 2.85, 0), Vector3(0.18, 0.18, 4.2), wood)
	for i in range(6):
		_box_in(pivot, Vector3(-2.2 + i * 0.88, 3.0, 0), Vector3(0.1, 0.1, 4.0), wood)
	for i in range(8):
		var t := float(i) / 7.0
		_sphere_in(pivot, Vector3(-2.0 + t * 4.0, 2.6 - sin(t * PI) * 0.3, 1.7), 0.08, _emissive(Color("#ffd18a"), 1.4))
	_bench(pivot.position + Vector3(0, 0, -1.0), 0.0)

func _pier(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var wood := _wood_mat()
	_box_in(pivot, Vector3(0, 0.05, 0), Vector3(6.0, 0.18, 16.0), wood)
	for z in [-7.0, -3.0, 1.0, 5.0, 7.0]:
		for x in [-2.7, 2.7]:
			_cylinder_in(pivot, Vector3(x, -1.2, z), 0.2, 3.0, _mat(Color("#4a3a2d"), 0.9), 8)
	for z in [-6.0, 0.0, 6.0]:
		_box_in(pivot, Vector3(0, 0.7, z), Vector3(6.0, 0.08, 0.08), _mat(Color("#4a3a2d"), 0.9))
	_bench(pivot.position + Vector3(0, 0.2, -6.2), 0.0)

func _foundry_yard(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	_box_in(pivot, Vector3(0, 0.02, 0), Vector3(10.0, 0.04, 8.0), _concrete_mat(Color("#8f8778")))
	_label_in(pivot, "FOUNDRY LOADING YARD", Vector3(0, 3.6, -3.6), 0.004, Color("#e7c987"), 36, PI)
	for i in range(6):
		var x := -3.0 + (i % 3) * 2.2
		var z := -1.8 + int(i / 3) * 1.6
		_box_in(pivot, Vector3(x, 0.35, z), Vector3(1.0, 0.7, 0.8), _wood_mat())
	for i in range(3):
		_cylinder_in(pivot, Vector3(-4.0 + i * 1.0, 0.4, 3.0), 0.35, 0.8, _mat(Color("#58676a"), 0.6, 0.3), 12)

func _invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _box_in(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _static_box_in(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body

func _cylinder_in(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, segments: int = 16, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	mesh.mesh = cylinder
	mesh.position = pos
	mesh.rotation = rot
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _sphere_in(parent: Node3D, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _label_in(parent: Node3D, text: String, pos: Vector3, pixel_size: float, color: Color, font_size: int = 64, rot_y: float = 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color("#1c2324")
	label.position = pos
	label.rotation.y = rot_y
	label.double_sided = false
	label.shaded = false
	parent.add_child(label)
	return label
