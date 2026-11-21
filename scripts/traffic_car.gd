extends Node3D

var path: Array = []
var path_index := 0
var cruise_speed := 6.0
var current_speed := 0.0
var car_color := Color("#7f8d96")
var main: Node
var wheels: Array[Node3D] = []
var spin := 0.0

func setup(points: Array, color: Color, speed: float) -> void:
	path = points.duplicate()
	car_color = color
	cruise_speed = speed

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	var paint := _mat(car_color, 0.4, 0.15)
	var dark := _mat(Color("#24282b"), 0.85)
	var glass := _mat(Color("#9fb7bb"), 0.15, 0.4)
	_box(Vector3(0, 0.55, 0), Vector3(1.78, 0.52, 3.8), paint)
	_box(Vector3(0, 0.24, 0), Vector3(1.68, 0.24, 3.7), dark)
	_box(Vector3(0, 0.92, 0.1), Vector3(1.48, 0.5, 1.7), glass)
	_box(Vector3(0, 1.18, 0.1), Vector3(1.4, 0.07, 1.55), paint)
	_box(Vector3(0, 0.56, -2.02), Vector3(0.6, 0.14, 0.05), _emissive(Color("#ffe4b2"), 1.2))
	_box(Vector3(0, 0.56, 2.02), Vector3(0.6, 0.14, 0.05), _emissive(Color("#c33f35"), 0.8))
	for x in [-0.82, 0.82]:
		for z in [-1.22, 1.22]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, 0.38, z)
			add_child(pivot)
			var tire := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.35
			cylinder.bottom_radius = 0.35
			cylinder.height = 0.24
			cylinder.radial_segments = 14
			tire.mesh = cylinder
			tire.rotation.z = PI / 2.0
			tire.material_override = dark
			pivot.add_child(tire)
			wheels.append(pivot)

func _process(delta: float) -> void:
	if path.size() < 2:
		return
	var target: Vector3 = path[path_index]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.7:
		path_index = (path_index + 1) % path.size()
		target = path[path_index]
		to_target = target - global_position
		to_target.y = 0.0
	var desired_speed := cruise_speed
	if main and main.get("current_vehicle") != null:
		var car: Node3D = main.current_vehicle
		var d := global_position.distance_to(car.global_position)
		if d < 8.0:
			desired_speed = maxf(0.0, (d - 3.0) * 1.4)
	current_speed = move_toward(current_speed, desired_speed, delta * 4.0)
	if to_target.length() > 0.01:
		var dir := to_target.normalized()
		global_position += dir * current_speed * delta
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 4.0)
		spin += current_speed * delta * 2.4
		for wheel in wheels:
			wheel.rotation.x = spin

func _box(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	add_child(mesh)
	return mesh

func _mat(color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color, 0.3)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
