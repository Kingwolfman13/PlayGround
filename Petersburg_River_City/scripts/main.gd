extends Node3D

const PLAYER_POS := Vector3(0, 1.1, 0)
var mission_active := false
var has_package := false
var time_left := 180.0
var cash := 0
var wanted := 0
var heat := 0.0
var pickup: StaticBody3D
var dropoff: Area3D
var car: VehicleBody3D
var player: CharacterBody3D
var hud: Label
var marker: MeshInstance3D
var wanted_timer := 0.0

func _ready():
	_build_world()
	_build_missions()
	_build_hud()
	_build_touch_controls()
	_load_save()
	start_mission()

func add_box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position = pos
	var mesh := BoxMesh.new(); mesh.size = size
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mesh.material = mat
	var mi := MeshInstance3D.new(); mi.mesh = mesh; body.add_child(mi)
	var shape := BoxShape3D.new(); shape.size = size
	var col := CollisionShape3D.new(); col.shape = shape; body.add_child(col)
	parent.add_child(body)
	return body

func _build_world():
	var env := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true; environment.fog_density = 0.002
	env.environment = environment; add_child(env)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55, -35, 0); light.shadow_enabled = true; add_child(light)
	add_box(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200), Color(0.30, 0.34, 0.29))
	add_box(self, Vector3(0, 0.015, 0), Vector3(200, 0.04, 8), Color(0.15, 0.15, 0.17))
	add_box(self, Vector3(0, 0.015, 0), Vector3(8, 0.04, 200), Color(0.15, 0.15, 0.17))
	add_box(self, Vector3(-84, -0.35, 0), Vector3(30, 0.3, 200), Color(0.10, 0.28, 0.40))
	var colors := [Color(0.55,0.24,0.17), Color(0.62,0.34,0.24), Color(0.42,0.28,0.22)]
	var xs := [-52,-38,-24,24,38,52]; var zs := [-52,-38,-24,24,38,52]
	for x in xs:
		for z in zs:
			if abs(x) < 15 and abs(z) < 15: continue
			var h := 7.0 + fmod(abs(x*z), 9.0)
			add_box($Buildings if has_node("Buildings") else self, Vector3(x,h*0.5,z), Vector3(11,h,11), colors[(abs(x)+abs(z)) % colors.size()])
	if not has_node("Buildings"):
		var buildings := Node3D.new(); buildings.name="Buildings"; add_child(buildings)
	# Add street furniture and river edge
	add_box(self, Vector3(-72,0.4,0), Vector3(1.2,0.8,190), Color(0.25,0.23,0.20))
	_build_player()
	_build_car()

func _build_player():
	var packed := load("res://scenes/player.tscn")
	player = packed.instantiate(); player.name="Player"; player.position=PLAYER_POS; add_child(player)

func _build_car():
	car = VehicleBody3D.new(); car.name="Sedan"; car.position=Vector3(8,0.7,6)
	var mesh:=BoxMesh.new(); mesh.size=Vector3(2.2,0.7,4.2)
	var mi:=MeshInstance3D.new(); mi.mesh=mesh
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color(0.15,0.25,0.50); mi.material_override=mat
	car.add_child(mi)
	var shape:=BoxShape3D.new(); shape.size=Vector3(2.2,0.7,4.2)
	var col:=CollisionShape3D.new(); col.shape=shape; car.add_child(col)
	car.set_meta("on_interact",Callable(self,"enter_car"))
	add_child(car)
	for i in range(4):
		var wheel:=VehicleWheel3D.new(); wheel.position=Vector3(-1.05 if i%2==0 else 1.05, -0.45, -1.35 if i<2 else 1.35); wheel.use_as_traction=true if i>=2 else false; wheel.use_as_steering=true if i<2 else false; car.add_child(wheel)

func enter_car(_body: Node):
	if player.global_position.distance_to(car.global_position)>4.0: return
	player.visible=false; player.controls_enabled=false
	var cam:=Camera3D.new(); cam.name="ChaseCamera"; cam.position=Vector3(0,4.5,7); cam.look_at(car.global_position); cam.current=true; car.add_child(cam)
	car.set_meta("on_interact",Callable(self,"exit_car"))

func exit_car(_body: Node):
	if car.has_node("ChaseCamera"):
		var cam:=car.get_node("ChaseCamera"); cam.queue_free()
	player.visible=true; player.controls_enabled=true
	player.global_position=car.global_position+Vector3(3,1,0)
	if player.get_node_or_null("Head/Camera3D"):
		player.get_node("Head/Camera3D").current=true
	car.set_meta("on_interact",Callable(self,"enter_car"))

func _build_missions():
	pickup=add_box(self,Vector3(-18,0.4,-15),Vector3(0.8,0.8,0.8),Color(0.95,0.72,0.12)); pickup.set_meta("on_interact",Callable(self,"pick_up"))
	dropoff=Area3D.new(); dropoff.position=Vector3(0,1.5,30)
	var shape:=BoxShape3D.new(); shape.size=Vector3(6,3,6)
	var col:=CollisionShape3D.new(); col.shape=shape; dropoff.add_child(col)
	dropoff.body_entered.connect(_dropoff_entered); add_child(dropoff)
	var m:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(6,0.05,6); m.mesh=box
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color(0.1,0.85,0.25); mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color.a=0.55; m.material_override=mat
	dropoff.add_child(m)

func start_mission():
	mission_active=true; has_package=false; time_left=180; pickup.visible=true; pickup.set_meta("on_interact",Callable(self,"pick_up"))

func pick_up(_body: Node):
	if has_package or not mission_active:return
	has_package=true; pickup.visible=false; pickup.remove_meta("on_interact")

func _dropoff_entered(body:Node):
	if mission_active and has_package and (body is CharacterBody3D or body is VehicleBody3D): complete_mission()

func complete_mission():
	mission_active=false; cash+=250; _save(); start_mission()

func fail_mission():
	mission_active=false; start_mission()

func _process(delta):
	if mission_active:
		time_left-=delta
		if time_left<=0: fail_mission()
	wanted_timer-=delta
	if wanted>0 and wanted_timer<=0:
		wanted_timer=5
		if heat>0: heat=max(0,heat-delta*0.3)
		else: wanted=max(0,wanted-1)
	_update_hud()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode==KEY_R: get_tree().reload_current_scene()
	if event.is_action_pressed("exit_vehicle") and player and not player.controls_enabled: exit_car(player)

func _build_hud():
	var layer:=CanvasLayer.new(); add_child(layer); hud=Label.new(); hud.position=Vector2(24,24); hud.add_theme_font_size_override("font_size",20); hud.add_theme_color_override("font_outline_color",Color.BLACK); hud.add_theme_constant_override("outline_size",6); layer.add_child(hud)

func _update_hud():
	var status="Pickup crate: warehouse (-18, -15)" if not has_package else "Deliver to green zone: Market Street (0, 30)"
	hud.text="PETERSBURG: RIVER CITY\n%s\nTime %03d  Cash $%d  Wanted %d/5" %[status,ceil(time_left),cash,wanted]

func _build_touch_controls():
	var tc_script:=load("res://scripts/touch_controls.gd")
	var tc:=tc_script.new(); tc.name="TouchControls"; add_child(tc)
	tc.add_action_button("JUMP","jump",Vector2(1180,520))
	tc.add_action_button("E","interact",Vector2(1080,520))
	tc.add_action_button("F","exit_vehicle",Vector2(1180,620))
	tc.add_action_button("R","restart",Vector2(1080,620))

func _save():
	var data={"cash":cash}
	var file:=FileAccess.open("user://petersburg_save.json",FileAccess.WRITE); file.store_string(JSON.stringify(data))

func _load_save():
	if not FileAccess.file_exists("user://petersburg_save.json"): return
	var file:=FileAccess.open("user://petersburg_save.json",FileAccess.READ)
	var data=JSON.parse_string(file.get_as_text())
	if typeof(data)==TYPE_DICTIONARY and data.has("cash"): cash=int(data.cash)
