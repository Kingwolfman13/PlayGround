class_name VehicleModel
extends RefCounted

## Procedural vehicle art. Every car is assembled from original primitives so
## the project has no third-party or Rockstar-owned model data.

const TYPES := {
	"sedan": {"w": 1.90, "l": 4.45, "wheel": 0.34, "wheelbase": 2.62, "track": 1.60, "roof": 1.42},
	"taxi": {"w": 1.90, "l": 4.45, "wheel": 0.34, "wheelbase": 2.62, "track": 1.60, "roof": 1.42},
	"police": {"w": 1.94, "l": 4.55, "wheel": 0.35, "wheelbase": 2.66, "track": 1.62, "roof": 1.46},
	"pickup": {"w": 2.02, "l": 5.25, "wheel": 0.42, "wheelbase": 3.10, "track": 1.70, "roof": 1.78},
	"van": {"w": 2.12, "l": 5.35, "wheel": 0.38, "wheelbase": 3.18, "track": 1.76, "roof": 2.12}
}

static func build(parent: Node3D, type: String, color: Color) -> Dictionary:
	var spec: Dictionary = TYPES.get(type, TYPES["sedan"])
	var w: float = spec["w"]
	var l: float = spec["l"]
	var wheel_r: float = spec["wheel"]
	var wheelbase: float = spec["wheelbase"]
	var track: float = spec["track"]
	var ride := wheel_r + 0.10

	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)

	var body_mat := Humanoid.make_mat(color, 0.28, 0.45)
	var body_dark := Humanoid.make_mat(color.darkened(0.30), 0.38, 0.35)
	var trim := Humanoid.make_mat(Color(0.035, 0.04, 0.045), 0.55, 0.2)
	var chrome := Humanoid.make_mat(Color(0.62, 0.65, 0.68), 0.22, 0.9)
	var glass := Humanoid.make_mat(Color(0.035, 0.065, 0.09), 0.12, 0.65)
	var rubber := Humanoid.make_mat(Color(0.025, 0.025, 0.028), 0.95, 0.0)
	var rim := Humanoid.make_mat(Color(0.66, 0.68, 0.70), 0.22, 0.92)
	var headlight := Humanoid.make_mat(Color(0.95, 0.92, 0.78), 0.15, 0.1, Color(1.0, 0.93, 0.75), 1.6)
	var taillight := Humanoid.make_mat(Color(0.55, 0.04, 0.03), 0.25, 0.1, Color(1.0, 0.04, 0.02), 1.4)
	var amber := Humanoid.make_mat(Color(0.9, 0.38, 0.03), 0.3, 0.1, Color(1.0, 0.35, 0.02), 0.8)
	var plate_mat := Humanoid.make_mat(Color(0.86, 0.86, 0.78), 0.6, 0.0)

	var data := {
		"model": model, "steer_wheels": [], "spin_wheels": [], "headlights": [],
		"taillights": [], "siren_red": null, "siren_blue": null, "size": Vector3(w, ride + 1.02, l),
		"wheel_radius": wheel_r, "wheelbase": wheelbase
	}

	if type == "van":
		_box(model, Vector3(0, ride + 0.55, 0), Vector3(w, 1.05, l * 0.94), body_mat)
		_box(model, Vector3(0, ride + 1.08, l * 0.05), Vector3(w * 0.96, 0.10, l * 0.9), body_dark)
		_box(model, Vector3(0, ride + 0.42, -l * 0.46), Vector3(w * 0.94, 0.18, 0.12), trim)
		_box(model, Vector3(0, ride + 0.42, l * 0.46), Vector3(w * 0.94, 0.18, 0.12), trim)
		_box(model, Vector3(0, ride + 0.78, -l * 0.475), Vector3(w * 0.68, 0.34, 0.025), glass)
		_box(model, Vector3(0, ride + 0.78, l * 0.475), Vector3(w * 0.68, 0.34, 0.025), glass)
		for side in [-1.0, 1.0]:
			_box(model, Vector3(side * w * 0.501, ride + 0.80, -l * 0.18), Vector3(0.02, 0.32, l * 0.30), glass)
			_box(model, Vector3(side * w * 0.501, ride + 0.80, l * 0.16), Vector3(0.02, 0.32, l * 0.25), glass)
			_box(model, Vector3(side * w * 0.51, ride + 0.42, 0.0), Vector3(0.03, 0.08, l * 0.60), body_dark)
			_box(model, Vector3(side * w * 0.51, ride + 0.55, -l * 0.10), Vector3(0.04, 0.035, 0.16), chrome)
	elif type == "pickup":
		_box(model, Vector3(0, ride + 0.20, 0), Vector3(w, 0.40, l * 0.94), body_mat)
		_box(model, Vector3(0, ride + 0.45, -l * 0.34), Vector3(w * 0.96, 0.20, l * 0.25), body_mat)
		_box(model, Vector3(0, ride + 0.70, -l * 0.18), Vector3(w * 0.80, 0.52, l * 0.30), body_mat)
		_box(model, Vector3(0, ride + 0.98, -l * 0.18), Vector3(w * 0.76, 0.06, l * 0.28), body_dark)
		_box(model, Vector3(0, ride + 0.78, -l * 0.325), Vector3(w * 0.67, 0.30, 0.025), glass)
		_box(model, Vector3(0, ride + 0.78, -l * 0.035), Vector3(w * 0.67, 0.28, 0.025), glass)
		for side in [-1.0, 1.0]:
			_box(model, Vector3(side * w * 0.401, ride + 0.78, -l * 0.18), Vector3(0.02, 0.28, l * 0.24), glass)
			_box(model, Vector3(side * w * 0.50, ride + 0.55, l * 0.12), Vector3(0.06, 0.44, l * 0.36), body_mat)
			_box(model, Vector3(side * w * 0.50, ride + 0.72, l * 0.12), Vector3(0.07, 0.08, l * 0.36), body_dark)
		_box(model, Vector3(0, ride + 0.52, l * 0.30), Vector3(w * 0.94, 0.34, 0.06), body_mat)
		_box(model, Vector3(0, ride + 0.28, l * 0.46), Vector3(w * 0.94, 0.16, 0.12), trim)
	else:
		# Sedan / taxi / police lower body, hood, trunk and cabin.
		_box(model, Vector3(0, ride + 0.22, 0), Vector3(w, 0.44, l * 0.92), body_mat)
		_box(model, Vector3(0, ride + 0.45, -l * 0.34), Vector3(w * 0.93, 0.16, l * 0.24), body_mat)
		_box(model, Vector3(0, ride + 0.44, l * 0.35), Vector3(w * 0.93, 0.14, l * 0.22), body_mat)
		_box(model, Vector3(0, ride + 0.67, 0.01), Vector3(w * 0.78, 0.46, l * 0.36), body_mat)
		_box(model, Vector3(0, ride + 0.92, 0.01), Vector3(w * 0.72, 0.07, l * 0.30), body_dark)
		# Slanted windshield and rear glass.
		var windshield := _box(model, Vector3(0, ride + 0.72, -l * 0.175), Vector3(w * 0.67, 0.34, 0.025), glass)
		windshield.rotation.x = -0.42
		var rear_glass := _box(model, Vector3(0, ride + 0.72, l * 0.185), Vector3(w * 0.64, 0.30, 0.025), glass)
		rear_glass.rotation.x = 0.38
		for side in [-1.0, 1.0]:
			_box(model, Vector3(side * w * 0.391, ride + 0.70, 0.01), Vector3(0.02, 0.31, l * 0.31), glass)
			_box(model, Vector3(side * w * 0.42, ride + 0.57, -l * 0.10), Vector3(0.03, 0.035, 0.16), chrome)
			_box(model, Vector3(side * w * 0.42, ride + 0.57, l * 0.13), Vector3(0.03, 0.035, 0.16), chrome)
			_box(model, Vector3(side * w * 0.51, ride + 0.56, -l * 0.03), Vector3(0.18, 0.075, 0.12), body_dark)
			_box(model, Vector3(side * w * 0.58, ride + 0.57, -l * 0.03), Vector3(0.10, 0.045, 0.06), trim)
		# Bumpers, grille and plates.
		_box(model, Vector3(0, ride + 0.26, -l * 0.48), Vector3(w * 0.94, 0.16, 0.12), trim)
		_box(model, Vector3(0, ride + 0.26, l * 0.48), Vector3(w * 0.94, 0.16, 0.12), trim)
		_box(model, Vector3(0, ride + 0.47, -l * 0.485), Vector3(w * 0.38, 0.16, 0.04), trim)
		_box(model, Vector3(0, ride + 0.28, l * 0.486), Vector3(0.38, 0.12, 0.02), plate_mat)
		_box(model, Vector3(0, ride + 0.28, -l * 0.486), Vector3(0.38, 0.12, 0.02), plate_mat)
		# Headlights and tail lights.
		for side in [-1.0, 1.0]:
			var hl := _box(model, Vector3(side * w * 0.29, ride + 0.49, -l * 0.474), Vector3(w * 0.19, 0.10, 0.035), headlight)
			data["headlights"].append(hl)
			var tl := _box(model, Vector3(side * w * 0.30, ride + 0.49, l * 0.474), Vector3(w * 0.19, 0.09, 0.035), taillight)
			data["taillights"].append(tl)

	if type == "taxi":
		_box(model, Vector3(0, ride + 0.99, 0.01), Vector3(0.62, 0.13, 0.28), Humanoid.make_mat(Color(0.95, 0.78, 0.14), 0.55))
		var sign_label := Label3D.new()
		sign_label.text = "TAXI"
		sign_label.font_size = 36
		sign_label.pixel_size = 0.0035
		sign_label.modulate = Color(0.05, 0.05, 0.05)
		sign_label.position = Vector3(0, ride + 1.065, -0.14)
		sign_label.rotation.y = 0.0
		model.add_child(sign_label)
	if type == "police":
		for side in [-1.0, 1.0]:
			_box(model, Vector3(side * w * 0.501, ride + 0.52, 0.01), Vector3(0.02, 0.34, l * 0.30), Humanoid.make_mat(Color(0.88, 0.88, 0.84), 0.45))
			_box(model, Vector3(side * w * 0.512, ride + 0.55, 0.01), Vector3(0.015, 0.06, l * 0.28), Humanoid.make_mat(Color(0.06, 0.12, 0.30), 0.4))
		_box(model, Vector3(0, ride + 0.99, 0.01), Vector3(w * 0.62, 0.055, 0.20), trim)
		var red := _box(model, Vector3(-w * 0.17, ride + 1.05, 0.01), Vector3(w * 0.22, 0.10, 0.17), Humanoid.make_mat(Color(0.65, 0.03, 0.02), 0.2, 0.0, Color(1.0, 0.02, 0.01), 2.0))
		var blue := _box(model, Vector3(w * 0.17, ride + 1.05, 0.01), Vector3(w * 0.22, 0.10, 0.17), Humanoid.make_mat(Color(0.03, 0.10, 0.65), 0.2, 0.0, Color(0.02, 0.12, 1.0), 2.0))
		data["siren_red"] = red
		data["siren_blue"] = blue
		# Push bar.
		_box(model, Vector3(0, ride + 0.36, -l * 0.54), Vector3(w * 0.72, 0.08, 0.06), trim)
		_box(model, Vector3(0, ride + 0.22, -l * 0.54), Vector3(w * 0.72, 0.06, 0.06), trim)
		_box(model, Vector3(-w * 0.28, ride + 0.29, -l * 0.54), Vector3(0.05, 0.20, 0.05), trim)
		_box(model, Vector3(w * 0.28, ride + 0.29, -l * 0.54), Vector3(0.05, 0.20, 0.05), trim)
		# Door shield.
		var shield := _box(model, Vector3(w * 0.514, ride + 0.53, -l * 0.05), Vector3(0.012, 0.16, 0.16), Humanoid.make_mat(Color(0.82, 0.66, 0.18), 0.3, 0.5))
		shield.rotation.z = 0.0

	# Wheels: steer pivot -> spin pivot -> cylinder.
	for side in [-1.0, 1.0]:
		for axle in [-1.0, 1.0]:
			var steer := Node3D.new()
			steer.position = Vector3(side * track * 0.5, wheel_r, axle * wheelbase * 0.5)
			model.add_child(steer)
			var spin := Node3D.new()
			steer.add_child(spin)
			var tire := MeshInstance3D.new()
			var tire_mesh := CylinderMesh.new()
			tire_mesh.top_radius = wheel_r
			tire_mesh.bottom_radius = wheel_r
			tire_mesh.height = 0.26
			tire_mesh.radial_segments = 18
			tire.mesh = tire_mesh
			tire.material_override = rubber
			tire.rotation.z = PI * 0.5
			spin.add_child(tire)
			var rim_mesh := MeshInstance3D.new()
			var rim_cyl := CylinderMesh.new()
			rim_cyl.top_radius = wheel_r * 0.60
			rim_cyl.bottom_radius = wheel_r * 0.60
			rim_cyl.height = 0.275
			rim_cyl.radial_segments = 14
			rim_mesh.mesh = rim_cyl
			rim_mesh.material_override = rim
			rim_mesh.rotation.z = PI * 0.5
			spin.add_child(rim_mesh)
			var hub := MeshInstance3D.new()
			var hub_cyl := CylinderMesh.new()
			hub_cyl.top_radius = wheel_r * 0.18
			hub_cyl.bottom_radius = wheel_r * 0.18
			hub_cyl.height = 0.29
			hub_cyl.radial_segments = 10
			hub.mesh = hub_cyl
			hub.material_override = trim
			hub.rotation.z = PI * 0.5
			spin.add_child(hub)
			for spoke_i in range(5):
				var spoke := _box(spin, Vector3(0, 0, 0), Vector3(0.285, wheel_r * 1.05, 0.035), rim)
				spoke.rotation.x = float(spoke_i) * TAU / 5.0
			data["steer_wheels"].append(steer)
			data["spin_wheels"].append(spin)

	# Underbody and exhaust.
	_box(model, Vector3(0, ride - 0.02, 0), Vector3(w * 0.72, 0.10, l * 0.72), trim)
	for side in [-1.0, 1.0]:
		_box(model, Vector3(side * w * 0.26, ride - 0.03, l * 0.47), Vector3(0.07, 0.07, 0.14), chrome)
	# Small blue Virginia-style plate stripe.
	_box(model, Vector3(0, ride + 0.285, l * 0.498), Vector3(0.10, 0.04, 0.005), Humanoid.make_mat(Color(0.12, 0.22, 0.55), 0.5))

	return data

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
