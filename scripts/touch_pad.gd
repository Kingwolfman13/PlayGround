extends Control
class_name TouchPad

var controller: TouchControls
var main: Node
var player: FPSPlayer
var driving := false

var joystick_touch := -1
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var look_touch := -1
var sprint_touch := -1
var mouse_joystick := false
var mouse_look := false
var last_mouse := Vector2.ZERO
var button_touches: Dictionary = {}
var enabled := false

const JOY_RADIUS := 78.0
const JOY_KNOB := 34.0
const DEAD_ZONE := 8.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if not value:
		_reset_all()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not enabled or not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(event.position, event.index)
		else:
			_handle_release(event.position, event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch:
			_update_joystick(event.position)
		elif event.index == look_touch:
			_apply_look(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_press(event.position)
		else:
			_handle_mouse_release()
	elif event is InputEventMouseMotion:
		if mouse_joystick:
			_update_joystick(event.position)
		elif mouse_look:
			_apply_look(event.relative)

func _handle_press(pos: Vector2, index: int) -> void:
	if _joystick_center().distance_to(pos) < JOY_RADIUS + 18.0:
		joystick_touch = index
		joystick_origin = _joystick_center()
		_update_joystick(pos)
		return
	var hit := _button_at(pos)
	if not hit.is_empty():
		button_touches[index] = hit.name
		_activate_button(hit.name)
		queue_redraw()
		return
	if pos.x > size.x * 0.38:
		look_touch = index

func _handle_release(_pos: Vector2, index: int) -> void:
	if index == joystick_touch:
		joystick_touch = -1
		joystick_vector = Vector2.ZERO
		_release_move()
	elif index == look_touch:
		look_touch = -1
	if button_touches.has(index):
		var name := str(button_touches[index])
		button_touches.erase(index)
		if name == "sprint":
			sprint_touch = -1
			Input.action_release("sprint")
		queue_redraw()

func _handle_mouse_press(pos: Vector2) -> void:
	if _joystick_center().distance_to(pos) < JOY_RADIUS + 18.0:
		mouse_joystick = true
		joystick_origin = _joystick_center()
		_update_joystick(pos)
		return
	var hit := _button_at(pos)
	if not hit.is_empty():
		_activate_button(hit.name)
		queue_redraw()
		return
	if pos.x > size.x * 0.38:
		mouse_look = true
		last_mouse = pos

func _handle_mouse_release() -> void:
	if mouse_joystick:
		mouse_joystick = false
		joystick_vector = Vector2.ZERO
		_release_move()
	mouse_look = false
	if sprint_touch == -2:
		sprint_touch = -1
		Input.action_release("sprint")

func _update_joystick(pos: Vector2) -> void:
	var offset := pos - joystick_origin
	if offset.length() > JOY_RADIUS:
		offset = offset.normalized() * JOY_RADIUS
	joystick_vector = offset / JOY_RADIUS
	var x := joystick_vector.x if absf(joystick_vector.x) > 0.12 else 0.0
	var y := joystick_vector.y if absf(joystick_vector.y) > 0.12 else 0.0
	_set_action("move_right", maxf(0.0, x))
	_set_action("move_left", maxf(0.0, -x))
	_set_action("move_back", maxf(0.0, y))
	_set_action("move_forward", maxf(0.0, -y))
	queue_redraw()

func _set_action(action: String, strength: float) -> void:
	if strength > 0.06:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)

func _release_move() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		if InputMap.has_action(action):
			Input.action_release(action)

func _apply_look(relative: Vector2) -> void:
	if player:
		player.add_touch_look(relative)

func _activate_button(name: String) -> void:
	match name:
		"jump":
			_pulse_action("jump")
		"interact":
			if player and player.interactor:
				player.interactor.force_interact()
		"sprint":
			sprint_touch = -2
			Input.action_press("sprint")
		"horn":
			if main and main.is_player_driving():
				main.current_vehicle.honk()
		"exit":
			if main and main.is_player_driving():
				main.current_vehicle.exit_vehicle()

func _pulse_action(action: String) -> void:
	Input.action_press(action)
	await get_tree().create_timer(0.12, true).timeout
	Input.action_release(action)

func _reset_all() -> void:
	joystick_touch = -1
	look_touch = -1
	sprint_touch = -1
	mouse_joystick = false
	mouse_look = false
	button_touches.clear()
	joystick_vector = Vector2.ZERO
	_release_move()
	if InputMap.has_action("sprint"):
		Input.action_release("sprint")

func _joystick_center() -> Vector2:
	return Vector2(138.0, size.y - 138.0)

func _button_list() -> Array:
	var list: Array = [
		{"name": "jump", "pos": Vector2(size.x - 88.0, size.y - 106.0), "r": 42.0, "label": "JUMP"},
		{"name": "interact", "pos": Vector2(size.x - 196.0, size.y - 106.0), "r": 38.0, "label": "USE"},
		{"name": "sprint", "pos": Vector2(size.x - 88.0, size.y - 212.0), "r": 38.0, "label": "RUN"},
		{"name": "horn", "pos": Vector2(size.x - 196.0, size.y - 212.0), "r": 34.0, "label": "HORN"}
	]
	if driving:
		list.append({"name": "exit", "pos": Vector2(size.x - 300.0, size.y - 106.0), "r": 34.0, "label": "EXIT"})
	return list

func _button_at(pos: Vector2) -> Dictionary:
	for button in _button_list():
		if (button.pos as Vector2).distance_to(pos) <= float(button.r) + 10.0:
			return button
	return {}

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	var base := Color(0.04, 0.08, 0.09, 0.36)
	var border := Color(0.92, 0.82, 0.63, 0.42)
	var active := Color(0.92, 0.72, 0.37, 0.45)
	var text_color := Color(0.97, 0.93, 0.82, 0.88)
	var font := ThemeDB.fallback_font

	var center := _joystick_center()
	draw_circle(center, JOY_RADIUS, base)
	draw_arc(center, JOY_RADIUS, 0.0, TAU, 48, border, 2.0, true)
	draw_circle(center, JOY_RADIUS - 16.0, Color(0.03, 0.06, 0.07, 0.18))
	var knob := center + joystick_vector * (JOY_RADIUS - JOY_KNOB - 8.0)
	draw_circle(knob, JOY_KNOB, Color(0.8, 0.78, 0.66, 0.24))
	draw_arc(knob, JOY_KNOB, 0.0, TAU, 32, Color(0.97, 0.9, 0.74, 0.6), 2.0, true)
	_draw_centered(font, "MOVE", center + Vector2(0, JOY_RADIUS + 20.0), 12, Color(0.9, 0.87, 0.78, 0.55))

	for button in _button_list():
		var p: Vector2 = button.pos
		var r: float = button.r
		var pressed: bool = str(button.name) == "sprint" and sprint_touch == -2
		draw_circle(p, r, active if pressed else base)
		draw_arc(p, r, 0.0, TAU, 32, border, 2.0, true)
		_draw_centered(font, str(button.label), p + Vector2(0, 5), 13, text_color)

	if look_touch < 0 and not mouse_look:
		_draw_centered(font, "DRAG TO LOOK", Vector2(size.x - 200.0, size.y - 306.0), 12, Color(0.9, 0.87, 0.78, 0.5))

func _draw_centered(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center - Vector2(width * 0.5, -font_size * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
