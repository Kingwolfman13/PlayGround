extends RayCast3D

const REACH := 3.0
var player_body: CharacterBody3D

func _ready() -> void:
	target_position = Vector3(0, 0, -REACH)
	enabled = true
	collide_with_bodies = true
	var node: Node = self
	while node and not node is CharacterBody3D:
		node = node.get_parent()
	player_body = node as CharacterBody3D
	if player_body:
		add_exception(player_body)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not is_colliding():
		return
	var target := get_collider()
	if target and target.has_meta("on_interact"):
		var callback: Callable = target.get_meta("on_interact")
		callback.call(player_body)
		get_viewport().set_input_as_handled()
