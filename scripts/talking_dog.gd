extends CharacterBody3D
class_name TalkingDog

signal conversation_advanced

const DIALOGUE := [
	["Pip", "You smell like unfinished errands. Mine are simple: snacks, naps, and justice."],
	["Pip", "The old warehouses have excellent acoustics. And excellent dropped fries."],
	["Pip", "Police cruisers are too noisy to sneak around. Humans call that a clue."],
	["Pip", "Between you and me, Mara pays in money. I work exclusively in biscuits."]
]

var main: Node
var player: Node3D
var follow_player := false
var dialogue_index := 0
var bark_timer := 0.0
var tail: Node3D
var left_leg: Node3D
var right_leg: Node3D
var head: Node3D
var speech: Label3D
var visual: Node3D
var elapsed := 0.0
var home := Vector3(-5.5, 0.1, 27.0)

func _ready() -> void:
	add_to_group("talking_dog")
	collision_layer = 1
	collision_mask = 1
	global_position = home
	_build_visual()

func setup(main_node: Node, player_node: Node3D) -> void:
	main = main_node
	player = player_node

func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var tan := StandardMaterial3D.new()
	tan.albedo_color = Color("#b46f45")
	tan.roughness = 0.9
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color("#ead7b5")
	tan.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#24282b")

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.78, 0.48, 1.05)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.58, 0)
	body.material_override = tan
	visual.add_child(body)

	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.55, 0.4, 0.25)
	chest.mesh = chest_mesh
	chest.position = Vector3(0, 0.62, -0.48)
	chest.material_override = cream
	visual.add_child(chest)

	head = Node3D.new()
	head.position = Vector3(0, 0.82, -0.72)
	visual.add_child(head)
	var skull := MeshInstance3D.new()
	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = 0.34
	skull_mesh.height = 0.58
	skull.mesh = skull_mesh
	skull.material_override = tan
	head.add_child(skull)
	var snout := MeshInstance3D.new()
	var snout_mesh := BoxMesh.new()
	snout_mesh.size = Vector3(0.38, 0.24, 0.26)
	snout.mesh = snout_mesh
	snout.position = Vector3(0, -0.1, -0.28)
	snout.material_override = cream
	head.add_child(snout)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := BoxMesh.new()
		ear_mesh.size = Vector3(0.16, 0.38, 0.12)
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.26, 0.22, 0)
		ear.rotation.z = side * 0.12
		ear.material_override = tan
		head.add_child(ear)
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.12, 0.08, -0.31)
		eye.material_override = dark
		head.add_child(eye)

	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.29, 0.42, -0.34 if side < 0 else 0.34)
		visual.add_child(leg)
		var leg_mesh := MeshInstance3D.new()
		var leg_box := BoxMesh.new()
		leg_box.size = Vector3(0.16, 0.48, 0.16)
		leg_mesh.mesh = leg_box
		leg_mesh.position.y = -0.18
		leg_mesh.material_override = tan
		leg.add_child(leg_mesh)
		if side < 0:
			left_leg = leg
		else:
			right_leg = leg

	tail = Node3D.new()
	tail.position = Vector3(0, 0.68, 0.58)
	visual.add_child(tail)
	var tail_mesh := MeshInstance3D.new()
	var tail_box := BoxMesh.new()
	tail_box.size = Vector3(0.13, 0.13, 0.75)
	tail_mesh.mesh = tail_box
	tail_mesh.position.z = 0.28
	tail_mesh.rotation.x = -0.42
	tail_mesh.material_override = tan
	tail.add_child(tail_mesh)

	speech = Label3D.new()
	speech.font_size = 48
	speech.pixel_size = 0.006
	speech.position = Vector3(0, 1.55, 0)
	speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech.modulate = Color("#fff0ba")
	speech.outline_modulate = Color("#182126")
	speech.outline_size = 10
	speech.visible = false
	visual.add_child(speech)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.05
	collision.shape = shape
	collision.position = Vector3(0, 0.62, 0)
	collision.rotation.z = PI * 0.5
	add_child(collision)

func interact() -> void:
	follow_player = not follow_player
	var line_index := dialogue_index % DIALOGUE.size()
	dialogue_index += 1
	var line := DIALOGUE[line_index][1]
	if follow_player:
		line += " [following]"
	else:
		line += " [waiting]"
	_say(line, 5.0)
	conversation_advanced.emit()
	bark_timer = 5.0

func get_interact_prompt() -> String:
	return "[E] Talk to Pip" if follow_player else "[E] Greet Pip"

func get_prompt() -> String:
	return get_interact_prompt()

func _say(text: String, seconds: float) -> void:
	if is_instance_valid(speech):
		speech.text = "Pip: " + text
		speech.visible = true
		bark_timer = seconds

func _physics_process(delta: float) -> void:
	elapsed += delta
	bark_timer = maxf(0.0, bark_timer - delta)
	if bark_timer <= 0.0:
		if speech:
			speech.visible = false

	var target_pos: Vector3
	var moving := false
	if follow_player and is_instance_valid(player):
		var offset := Vector3(1.7, 0.0, 1.7)
		target_pos = player.global_position - player.global_transform.basis.z.normalized() * 2.0 + offset
	else:
		target_pos = home

	var to_target := target_pos - global_position
	to_target.y = 0.0
	if to_target.length() > 1.15:
		var dir := to_target.normalized()
		velocity.x = move_toward(velocity.x, dir.x * 3.2, delta * 8.0)
		velocity.z = move_toward(velocity.z, dir.z * 3.2, delta * 8.0)
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 7.0)
		moving = true
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()

	if tail:
		tail.rotation.x = sin(elapsed * (11.0 if follow_player else 4.0)) * 0.5
	if moving:
		var swing := sin(elapsed * 9.0) * 0.55
		if left_leg: left_leg.rotation.x = swing
		if right_leg: right_leg.rotation.x = -swing
	if head:
		head.rotation.z = sin(elapsed * 2.0) * 0.035
