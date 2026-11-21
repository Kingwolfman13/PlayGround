extends RiverCar
class_name PoliceCar

var red_bar: MeshInstance3D
var blue_bar: MeshInstance3D
var red_light: OmniLight3D
var blue_light: OmniLight3D
var siren_audio: AudioStreamPlayer3D
var flash_timer := 0.0
var flash_red := true

func _ready() -> void:
	is_police = true
	ai_driver = true
	display_name = "Petersburg Police"
	body_color = Color("#263f5a")
	super._ready()
	_build_police_kit()

func _build_police_kit() -> void:
	var white := _mat(Color("#e7e3d5"), 0.45)
	var dark := _mat(Color("#161c24"), 0.8)
	for x in [-0.975, 0.975]:
		_box(visual_root, Vector3(x, 0.18, 0.0), Vector3(0.02, 0.34, 2.2), white)
		var label := Label3D.new()
		label.text = "POLICE"
		label.font_size = 48
		label.pixel_size = 0.005
		label.modulate = Color("#1c2a3d")
		label.position = Vector3(x * 1.01, 0.28, 0.0)
		label.rotation.y = PI / 2.0 if x > 0 else -PI / 2.0
		visual_root.add_child(label)
	_box(visual_root, Vector3(0, 0.95, 0.05), Vector3(1.25, 0.12, 0.38), dark)
	red_bar = _box(visual_root, Vector3(-0.38, 1.04, 0.05), Vector3(0.55, 0.14, 0.28), _emissive(Color("#e23c35"), 3.0))
	blue_bar = _box(visual_root, Vector3(0.38, 1.04, 0.05), Vector3(0.55, 0.14, 0.28), _emissive(Color("#2f6cff"), 3.0))
	red_light = OmniLight3D.new()
	red_light.position = Vector3(-0.38, 1.25, 0.05)
	red_light.light_color = Color("#ff3b2f")
	red_light.light_energy = 2.6
	red_light.omni_range = 9.0
	red_light.shadow_enabled = false
	visual_root.add_child(red_light)
	blue_light = OmniLight3D.new()
	blue_light.position = Vector3(0.38, 1.25, 0.05)
	blue_light.light_color = Color("#3d7bff")
	blue_light.light_energy = 2.6
	blue_light.omni_range = 9.0
	blue_light.shadow_enabled = false
	visual_root.add_child(blue_light)
	var push_bar := _box(visual_root, Vector3(0, 0.08, -2.2), Vector3(1.8, 0.28, 0.18), dark)
	push_bar.rotation.x = deg_to_rad(-8.0)
	siren_audio = AudioStreamPlayer3D.new()
	siren_audio.name = "SirenAudio"
	siren_audio.max_distance = 80.0
	siren_audio.unit_size = 10.0
	siren_audio.volume_db = -8.0
	add_child(siren_audio)
	if ResourceLoader.exists("res://assets/audio/siren.wav"):
		siren_audio.stream = load("res://assets/audio/siren.wav")
		siren_audio.finished.connect(_restart_siren)

func _process(delta: float) -> void:
	super._process(delta)
	flash_timer += delta
	if flash_timer >= 0.16:
		flash_timer = 0.0
		flash_red = not flash_red
		if red_bar:
			red_bar.visible = flash_red
		if blue_bar:
			blue_bar.visible = not flash_red
		if red_light:
			red_light.light_energy = 3.0 if flash_red else 0.0
		if blue_light:
			blue_light.light_energy = 0.0 if flash_red else 3.0
	if ai_active:
		if siren_audio and siren_audio.stream and not siren_audio.playing:
			siren_audio.play()
	elif siren_audio and siren_audio.playing:
		siren_audio.stop()

func clear_ai() -> void:
	super.clear_ai()
	if siren_audio:
		siren_audio.stop()

func _restart_siren() -> void:
	if ai_active and siren_audio and siren_audio.stream:
		siren_audio.play()
