extends CanvasLayer
class_name GameHUD

signal resume_requested
signal restart_requested
signal quit_requested
signal new_game_requested
signal touch_toggle_requested

const GOLD := Color("#e7b45b")
const CREAM := Color("#f2e8d2")
const MUTED := Color("#b9c4bf")
const RED := Color("#e2685b")
const GREEN := Color("#8fe3bd")
const PANEL_BG := Color(0.045, 0.075, 0.085, 0.86)

var main: Node
var player: Node3D
var mission_manager: MissionManager
var wanted_system: WantedSystem

var root: Control
var district_label: Label
var cash_label: Label
var mission_panel: PanelContainer
var mission_title: Label
var mission_client: Label
var mission_objective: Label
var mission_distance: Label
var mission_time_label: Label
var mission_time_bar: ProgressBar
var heat_box: VBoxContainer
var heat_boxes: Array[ColorRect] = []
var radar: GameRadar
var speed_box: VBoxContainer
var speed_label: Label
var speed_car_label: Label
var speed_mode_label: Label
var prompt_label: Label
var hint_label: Label
var banner_panel: PanelContainer
var banner_title: Label
var banner_subtitle: Label
var toast_label: Label
var busted_overlay: ColorRect
var pause_overlay: ColorRect
var touch_button: Button
var crosshair: Control

var banner_timer := 0.0
var toast_timer := 0.0
var heat_pulse := 0.0
var current_heat := 0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if GameState:
		GameState.cash_changed.connect(_on_cash_changed)
		GameState.deliveries_changed.connect(_on_deliveries_changed)
		_on_cash_changed(GameState.cash)

func setup(main_node: Node, player_node: Node3D, mission_node: MissionManager, wanted_node: WantedSystem) -> void:
	main = main_node
	player = player_node
	mission_manager = mission_node
	wanted_system = wanted_node
	if radar:
		radar.setup(main, player, mission_manager, wanted_system)
	_update_cash(GameState.cash if GameState else 0)
	set_wanted(0)
	set_speed(0.0, "", "")
	set_prompt("")

func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	district_label = _label(root, "OLD TOWNE", 30, GOLD)
	district_label.position = Vector2(24, 16)
	district_label.add_theme_constant_override("outline_size", 6)
	district_label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.06, 0.95))

	cash_label = _label(root, "$0", 22, CREAM)
	cash_label.position = Vector2(26, 54)
	cash_label.add_theme_constant_override("outline_size", 5)
	cash_label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.06, 0.95))

	_build_mission_panel()
	_build_heat()
	_build_radar()
	_build_speed()
	_build_center()
	_build_pause()
	_build_crosshair()

func _build_mission_panel() -> void:
	mission_panel = PanelContainer.new()
	mission_panel.name = "MissionPanel"
	mission_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mission_panel.position = Vector2(22, 92)
	mission_panel.custom_minimum_size = Vector2(382, 0)
	mission_panel.add_theme_stylebox_override("panel", _panel(PANEL_BG, Color(0.91, 0.71, 0.36, 0.75), 10))
	mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.visible = false
	root.add_child(mission_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 13)
	mission_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	mission_title = _label(column, "COURIER ROUTE", 21, GOLD)
	mission_client = _label(column, "", 13, MUTED)
	mission_objective = _label(column, "", 17, CREAM)
	mission_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_objective.custom_minimum_size = Vector2(340, 0)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 10)
	column.add_child(time_row)
	mission_time_bar = ProgressBar.new()
	mission_time_bar.show_percentage = false
	mission_time_bar.custom_minimum_size = Vector2(0, 9)
	mission_time_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_time_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mission_time_bar.add_theme_stylebox_override("background", _flat(Color(0.02, 0.04, 0.05, 0.9), 5))
	mission_time_bar.add_theme_stylebox_override("fill", _flat(GOLD, 5))
	time_row.add_child(mission_time_bar)
	mission_time_label = _label(time_row, "", 15, CREAM)
	mission_time_label.custom_minimum_size = Vector2(52, 0)
	mission_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mission_distance = _label(column, "", 12, MUTED)

func _build_heat() -> void:
	heat_box = VBoxContainer.new()
	heat_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	heat_box.position = Vector2(-244, 18)
	heat_box.add_theme_constant_override("separation", 4)
	heat_box.visible = false
	root.add_child(heat_box)
	var title := _label(heat_box, "HEAT", 14, RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 5)
	heat_box.add_child(row)
	for i in range(5):
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(22, 12)
		box.color = Color(0.22, 0.25, 0.26, 0.85)
		row.add_child(box)
		heat_boxes.append(box)

func _build_radar() -> void:
	radar = GameRadar.new()
	radar.name = "Radar"
	radar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -238
	radar.offset_top = 92
	radar.offset_right = -22
	radar.offset_bottom = 308
	root.add_child(radar)

func _build_speed() -> void:
	speed_box = VBoxContainer.new()
	speed_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_box.offset_left = -274
	speed_box.offset_top = -132
	speed_box.offset_right = -24
	speed_box.offset_bottom = -22
	speed_box.custom_minimum_size = Vector2(250, 0)
	speed_box.alignment = BoxContainer.ALIGNMENT_END
	speed_box.add_theme_constant_override("separation", 0)
	speed_box.visible = false
	root.add_child(speed_box)
	speed_label = _label(speed_box, "0", 46, CREAM)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.add_theme_constant_override("outline_size", 6)
	speed_label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.06, 0.95))
	speed_car_label = _label(speed_box, "", 14, GOLD)
	speed_car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_mode_label = _label(speed_box, "", 11, MUTED)
	speed_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_center() -> void:
	banner_panel = PanelContainer.new()
	banner_panel.name = "Banner"
	banner_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_panel.offset_left = -340
	banner_panel.offset_top = 208
	banner_panel.offset_right = 340
	banner_panel.offset_bottom = 296
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.visible = false
	root.add_child(banner_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	banner_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	banner_title = _label(column, "", 32, GOLD)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_subtitle = _label(column, "", 15, CREAM)
	banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	toast_label = _label(root, "", 17, CREAM)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -520
	toast_label.offset_right = 520
	toast_label.offset_top = -166
	toast_label.offset_bottom = -134
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_constant_override("outline_size", 7)
	toast_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.96))
	toast_label.visible = false

	prompt_label = _label(root, "", 17, CREAM)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -420
	prompt_label.offset_right = 420
	prompt_label.offset_top = -104
	prompt_label.offset_bottom = -76
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_constant_override("outline_size", 7)
	prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.96))

	hint_label = _label(root, "WASD move   ·   Shift sprint   ·   Space jump   ·   E interact   ·   Esc menu", 12, Color(0.85, 0.86, 0.8, 0.62))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(24, -32)

	busted_overlay = ColorRect.new()
	busted_overlay.name = "BustedOverlay"
	busted_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	busted_overlay.color = Color(0.55, 0.06, 0.05, 0.0)
	busted_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(busted_overlay)

func _build_pause() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.015, 0.03, 0.038, 0.78)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pause_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -235
	panel.offset_top = -272
	panel.offset_right = 235
	panel.offset_bottom = 272
	panel.add_theme_stylebox_override("panel", _panel(Color(0.04, 0.07, 0.08, 0.97), Color(0.91, 0.71, 0.36, 0.85), 16, 2))
	pause_overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := _label(column, "PETERSBURG", 34, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(column, "RIVER CITY  ·  COURIER SHIFT", 13, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_spacer(8))
	_pause_button(column, "Resume", _emit_resume)
	_pause_button(column, "New Game", _emit_new_game)
	_pause_button(column, "Restart Route", _emit_restart)
	touch_button = _pause_button(column, "Touch Controls: OFF", _emit_touch)
	_pause_button(column, "Save & Quit", _emit_quit)
	column.add_child(_spacer(10))
	var note := _label(column, "Progress saves locally to user://petersburg_save.json", 11, Color(0.72, 0.75, 0.72, 0.72))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(380, 0)

func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -3
	crosshair.offset_top = -3
	crosshair.offset_right = 3
	crosshair.offset_bottom = 3
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	var dot := ColorRect.new()
	dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dot.color = Color(0.95, 0.93, 0.85, 0.75)
	crosshair.add_child(dot)

func _pause_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(380, 46)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color("#fff6df"))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("normal", _panel(Color(0.08, 0.13, 0.145, 0.95), Color(0.3, 0.42, 0.44, 0.8), 8))
	button.add_theme_stylebox_override("hover", _panel(Color(0.12, 0.2, 0.21, 0.98), GOLD, 8))
	button.add_theme_stylebox_override("pressed", _panel(Color(0.16, 0.24, 0.24, 1.0), GOLD, 8))
	button.add_theme_stylebox_override("focus", _panel(Color(0, 0, 0, 0), GOLD, 8, 1))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _process(delta: float) -> void:
	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			banner_panel.visible = false
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.visible = false
	heat_pulse += delta
	if heat_box and heat_box.visible and current_heat > 0:
		var pulse := 0.65 + sin(heat_pulse * 6.0) * 0.35
		for i in range(heat_boxes.size()):
			if i < current_heat:
				heat_boxes[i].color = Color(0.88, 0.28, 0.22, 0.55 + pulse * 0.45)
			else:
				heat_boxes[i].color = Color(0.22, 0.25, 0.26, 0.85)

func set_district(name: String) -> void:
	if district_label:
		district_label.text = name

func set_mission(title: String, objective: String, time_left: float, total_time: float, distance: float, has_package: bool, client: String) -> void:
	if mission_panel == null:
		return
	mission_panel.visible = true
	mission_title.text = title
	mission_client.text = ("CLIENT  ·  " + client) if not client.is_empty() else "COURIER ROUTE"
	mission_objective.text = ("● " if not has_package else "◆ ") + objective
	mission_objective.add_theme_color_override("font_color", CREAM if not has_package else GREEN)
	if distance >= 0.0:
		mission_distance.text = "%d m to objective" % int(distance)
	else:
		mission_distance.text = ""
	var show_timer := time_left >= 0.0 and total_time > 0.0
	mission_time_bar.visible = show_timer
	mission_time_label.visible = show_timer
	if show_timer:
		mission_time_bar.max_value = total_time
		mission_time_bar.value = clampf(time_left, 0.0, total_time)
		mission_time_label.text = _fmt_time(time_left)
		var ratio := clampf(time_left / total_time, 0.0, 1.0)
		var fill := GOLD if ratio > 0.3 else RED
		mission_time_bar.add_theme_stylebox_override("fill", _flat(fill, 5))
		mission_time_label.add_theme_color_override("font_color", CREAM if ratio > 0.3 else RED)

func show_banner(title: String, subtitle: String, color: Color, duration: float) -> void:
	if banner_panel == null:
		return
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_subtitle.text = subtitle
	banner_panel.add_theme_stylebox_override("panel", _panel(Color(0.03, 0.055, 0.065, 0.9), Color(color.r, color.g, color.b, 0.8), 12))
	banner_panel.visible = true
	banner_timer = duration
	banner_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(banner_panel, "modulate:a", 1.0, 0.22)

func show_toast(text: String, duration: float, color: Color = Color(0.94, 0.91, 0.83)) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.visible = true
	toast_timer = duration
	toast_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast_label, "modulate:a", 1.0, 0.18)

func set_wanted(heat: int) -> void:
	current_heat = clampi(heat, 0, 5)
	if heat_box:
		heat_box.visible = current_heat > 0
	for i in range(heat_boxes.size()):
		heat_boxes[i].color = Color(0.88, 0.28, 0.22, 0.9) if i < current_heat else Color(0.22, 0.25, 0.26, 0.85)

func set_speed(mph: float, car_name: String, camera_mode: String) -> void:
	if speed_box == null:
		return
	var driving := not car_name.is_empty()
	speed_box.visible = driving
	if not driving:
		return
	speed_label.text = "%d" % int(round(mph))
	speed_car_label.text = car_name
	speed_mode_label.text = camera_mode + "  ·  MPH"

func set_prompt(text: String) -> void:
	if prompt_label:
		prompt_label.text = text

func set_driving(driving: bool) -> void:
	if speed_box:
		speed_box.visible = driving
	if crosshair:
		crosshair.visible = not driving
	if hint_label:
		hint_label.text = "W/S throttle   ·   A/D steer   ·   F exit   ·   H horn   ·   V camera   ·   L lights" if driving else "WASD move   ·   Shift sprint   ·   Space jump   ·   E interact   ·   Esc menu"

func show_busted() -> void:
	if busted_overlay == null:
		return
	busted_overlay.color = Color(0.55, 0.06, 0.05, 0.62)
	var tween := create_tween()
	tween.tween_property(busted_overlay, "color:a", 0.0, 1.4)

func set_paused(paused: bool) -> void:
	if pause_overlay:
		pause_overlay.visible = paused
	if crosshair:
		crosshair.visible = not paused and not (main and main.is_player_driving())

func set_touch_enabled(enabled: bool) -> void:
	if touch_button:
		touch_button.text = "Touch Controls: " + ("ON" if enabled else "OFF")

func _on_cash_changed(amount: int) -> void:
	_update_cash(amount)

func _on_deliveries_changed(_total: int) -> void:
	_update_cash(GameState.cash)

func _update_cash(amount: int) -> void:
	if cash_label:
		cash_label.text = "$%d" % amount

func _emit_resume() -> void:
	resume_requested.emit()

func _emit_restart() -> void:
	restart_requested.emit()

func _emit_quit() -> void:
	quit_requested.emit()

func _emit_new_game() -> void:
	new_game_requested.emit()

func _emit_touch() -> void:
	touch_toggle_requested.emit()

func _fmt_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _panel(bg: Color, border: Color, radius: int = 10, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _flat(color: Color, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
