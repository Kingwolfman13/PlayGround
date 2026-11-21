extends CanvasLayer
class_name TouchControls

var main: Node
var player: FPSPlayer
var pad: TouchPad
var enabled := false
var paused := false

func _ready() -> void:
	layer = 20
	pad = TouchPad.new()
	pad.name = "TouchPad"
	pad.controller = self
	add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_enabled(false)

func setup(main_node: Node, player_node: FPSPlayer) -> void:
	main = main_node
	player = player_node
	if pad:
		pad.main = main
		pad.player = player

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value and not paused
	if pad:
		pad.set_enabled(value and not paused)

func set_paused(value: bool) -> void:
	paused = value
	visible = enabled and not paused
	if pad:
		pad.set_enabled(enabled and not paused)

func _process(_delta: float) -> void:
	if not enabled or pad == null:
		return
	pad.driving = main != null and main.is_player_driving()
