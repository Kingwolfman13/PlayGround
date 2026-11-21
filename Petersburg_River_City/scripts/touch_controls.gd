extends CanvasLayer

signal move_vector_changed(value: Vector2)
signal look_delta(value: Vector2)

var stick_origin := Vector2(120, 560)
var stick_pos := stick_origin
var joystick_touch := -1
var look_touch := -1
var look_last := Vector2.ZERO

func _ready():
	visible = DisplayServer.is_touchscreen_available()

func _draw():
	draw_circle(stick_origin, 65, Color(0.05, 0.05, 0.06, 0.55))
	draw_circle(stick_pos, 28, Color(0.35, 0.55, 0.85, 0.85))

func _process(_delta):
	queue_redraw()

func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().size.x * 0.45 and joystick_touch == -1:
				joystick_touch = event.index
				stick_origin = event.position
				stick_pos = event.position
			elif look_touch == -1:
				look_touch = event.index
				look_last = event.position
		else:
			if event.index == joystick_touch:
				joystick_touch = -1
				stick_pos = stick_origin
				move_vector_changed.emit(Vector2.ZERO)
			elif event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch:
			var delta := event.position - stick_origin
			if delta.length() > 65: delta = delta.normalized() * 65
			stick_pos = stick_origin + delta
			move_vector_changed.emit(Vector2(delta.x / 65.0, delta.y / 65.0))
		elif event.index == look_touch:
			look_delta.emit(event.relative)

func add_action_button(text: String, action: String, position: Vector2):
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = Vector2(88, 88)
	button.pressed.connect(func():
		if action == "restart": get_tree().reload_current_scene()
		else:
			Input.action_press(action)
			var timer := get_tree().create_timer(0.12)
			await timer.timeout
			Input.action_release(action)
	)
	add_child(button)
