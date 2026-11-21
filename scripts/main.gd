extends Node3D

const SAVE_PATH := "user://petersburg_save.json"
const MISSION_LIMIT := 180.0

var mission_active := false
var package_picked := false
var time_left := MISSION_LIMIT
var mission_index := 0
var cash := 0
var wanted := 0.0
var player: CharacterBody3D
var pickup: StaticBody3D
var dropoff: Area3D
var hud: Label
var status_text := ""
var mission_points := [
	{"pickup": Vector3(-18, 0.4, -15), "dropoff": Vector3(0, 1.5, 30), "reward": 250},
	{"pickup": Vector3(32, 0.4, -28), "dropoff": Vector3(-38, 1.5, 18), "reward": 350},
	{"pickup": Vector3(-45, 0.4, 42), "dropoff": Vector3(38, 1.5, -42), "reward": 500},
	{"pickup": Vector3(55, 0.4, 12), "dropoff": Vector3(-55, 1.5, -22), "reward": 650}
]

func _ready() -> void:
	_load_save()
	_build_world()
	_build_hud()
	start_mission()

func _process(delta: float) -> void:
	if mission_active:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0:
			fail_mission("Time expired. Press R to restart.")
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func add_box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

func _build_world() -> void:
	add_box(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200), Color("484f3d"))
	add_box(self, Vector3(0, 0.03, 0), Vector3(200, 0.06, 8), Color("292d31"))
	add_box(self, Vector3(0, 0.03, 0), Vector3(8, 0.06, 200), Color("292d31"))
	add_box(self, Vector3(-75, -0.38, 0), Vector3(14, 0.2, 200), Color("2c6378"))
	var colors := [Color("8b4838"), Color("70483a"), Color("a05e45"), Color("5f3d35")]
	for x in [-55, -38, -25, 18, 32, 48, 62]:
		for z in [-55, -34, 18, 38, 55]:
			if abs(x) < 12 or abs(z) < 12:
				continue
			var height := 7.0 + (abs(x + z) % 9)
			add_box(self, Vector3(x, height * 0.5, z), Vector3(10, height, 10), colors[abs(int(x + z)) % colors.size()])
	var tree_positions := [Vector3(-10, 1.7, 12), Vector3(12, 1.7, -12), Vector3(-62, 1.7, 35), Vector3(55, 1.7, 48)]
	for p in tree_positions:
		add_box(self, p, Vector3(1.2, 3.4, 1.2), Color("57472d"))
		var crown := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 2.0
		sphere.height = 4.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("365b32")
		sphere.material = mat
		crown.mesh = sphere
		crown.position = p + Vector3(0, 2.8, 0)
		add_child(crown)
	_build_mission_points()
	_build_vehicle()

func _build_mission_points() -> void:
	pickup = add_box(self, Vector3(-18, 0.4, -15), Vector3(0.8, 0.8, 0.8), Color("e7b34c"))
	pickup.set_meta("on_interact", Callable(self, "pick_up_package"))
	dropoff = Area3D.new()
	dropoff.position = Vector3(0, 1.5, 30)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 3, 6)
	collision.shape = shape
	dropoff.add_child(collision)
	add_child(dropoff)
	dropoff.body_entered.connect(_on_dropoff_entered)

func _build_vehicle() -> void:
	var car_scene := load("res://scenes/vehicles/car.tscn")
	if car_scene:
		var car := car_scene.instantiate()
		car.position = Vector3(8, 1.1, 0)
		add_child(car)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(24, 24)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	canvas.add_child(hud)

func _update_hud() -> void:
	var heat := ""
	for i in 5:
		heat += "★" if i < int(wanted) else "☆"
	hud.text = "%s\nTime: %02d s  Cash: $%d  Wanted: %s" % [status_text, ceili(time_left), cash, heat]

func start_mission() -> void:
	mission_active = true
	package_picked = false
	time_left = MISSION_LIMIT
	var point: Dictionary = mission_points[mission_index % mission_points.size()]
	pickup.position = point.pickup
	pickup.visible = true
	pickup.set_meta("on_interact", Callable(self, "pick_up_package"))
	dropoff.position = point.dropoff
	status_text = "Mission %d: Pick up the crate. Press E." % (mission_index + 1)
	_update_hud()

func pick_up_package(_player: Node) -> void:
	if not mission_active or package_picked:
		return
	package_picked = true
	pickup.visible = false
	pickup.remove_meta("on_interact")
	status_text = "Package collected. Deliver it to the marked drop-off."

func _on_dropoff_entered(body: Node3D) -> void:
	if mission_active and package_picked and body is CharacterBody3D:
		complete_mission()

func complete_mission() -> void:
	mission_active = false
	cash += mission_points[mission_index % mission_points.size()].reward
	mission_index += 1
	status_text = "Delivery complete! Press R for the next mission."
	_save_game()
	_update_hud()

func fail_mission(reason: String) -> void:
	mission_active = false
	status_text = reason

func _save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"cash": cash, "mission_index": mission_index}))

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			cash = int(data.get("cash", 0))
			mission_index = int(data.get("mission_index", 0))
