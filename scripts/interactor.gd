extends RayCast3D

signal interacted(target: Node3D)

const REACH := 3.4

func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -REACH)
	enabled = true
	collide_with_bodies = true
	collide_with_areas = false
	collision_mask = 1 | 4 | 16
	var node: Node = get_parent()
	while node and not (node is CharacterBody3D):
		node = node.get_parent()
	if node:
		add_exception(node)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not get_tree().paused:
		if force_interact():
			get_viewport().set_input_as_handled()

func force_interact() -> bool:
	if not is_colliding():
		return false
	var target := get_collider() as Node3D
	if target == null:
		return false
	interacted.emit(target)
	return true

func get_prompt() -> String:
	if not is_colliding():
		return ""
	var target := get_collider() as Node3D
	if target == null:
		return ""
	if target.has_method("get_drive_prompt"):
		return str(target.get_drive_prompt())
	var id := str(target.get_meta("interact_id", ""))
	match id:
		"pickup":
			return "[E] Pick up the parcel"
		"mission_board":
			return "[E] Read Mara's courier board"
		_:
			return ""
