extends CanvasLayer

var joystick_base: Control
var joystick_knob: Control
var stick_center := Vector2.ZERO
var stick_active := false
var stick_value := Vector2.ZERO

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	_build_button("Jump", Vector2(1120, 590), KEY_SPACE)
	_build_button("Sprint", Vector2(1120, 500), KEY_SHIFT)
	_build_button("E", Vector2(1020, 590), KEY_E)
	_build_button("F", Vector2(1020, 500), KEY_F)
	_build_joystick()

func _build_joystick() -> void:
	joystick_base = Control.new()
	joystick_base.position = Vector2(50, 470)
	joystick_base.size = Vector2(220, 220)
	add_child(joystick_base)
	var style_base := StyleBoxFlat.new()
	style_base.bg_color = Color(0.1, 0.1, 0.1, 0.45)
	style_base.set_corner_radius_all(110)
	joystick_base.add_theme_stylebox_override("panel", style_base)
	stick_center = joystick_base.position + Vector2(110, 110)

func _build_button(label_text: String, pos: Vector2, keycode: Key) -> void:
	var button := Button.new()
	button.text = label_text
	button.position = pos
	button.size = Vector2(80, 80)
	button.pressed.connect(func(): _press_key(keycode))
	add_child(button)

func _press_key(keycode: Key) -> void:
	var event_down := InputEventKey.new()
	event_down.pressed = true
	event_down.keycode = keycode
	var event_up := InputEventKey.new()
	event_up.pressed = false
	event_up.keycode = keycode
	Input.parse_input_event(event_down)
	Input.parse_input_event(event_up)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.position.x < 300:
			stick_active = event.pressed
			stick_value = Vector2.ZERO
	elif event is InputEventScreenDrag and stick_active:
		var delta := event.position - stick_center
		if delta.length() > 100:
			delta = delta.normalized() * 100
		stick_value = delta / 100.0
		_apply_movement()

func _process(_delta: float) -> void:
	if stick_active:
		_apply_movement()

func _apply_movement() -> void:
	_set_action("move_forward", stick_value.y < -0.25)
	_set_action("move_back", stick_value.y > 0.25)
	_set_action("move_left", stick_value.x < -0.25)
	_set_action("move_right", stick_value.x > 0.25)

func _set_action(action: StringName, active: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = active
	Input.parse_input_event(event)
