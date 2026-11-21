extends Control
class_name GameRadar

var world: Node
var player: Node3D
var mission_manager: MissionManager
var wanted_system: WantedSystem
var scale_px := 1.12
var flash := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(world_node: Node, player_node: Node3D, mission_node: MissionManager, wanted_node: WantedSystem) -> void:
	world = world_node
	player = player_node
	mission_manager = mission_node
	wanted_system = wanted_node

func _process(delta: float) -> void:
	flash += delta
	queue_redraw()

func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, Color(0.025, 0.05, 0.065, 0.94))
	var map_rect := Rect2(7, 7, size.x - 14, size.y - 14)
	if player == null:
		return
	var center := size * 0.5
	# Building blocks.
	var blocks := [
		Rect2(-66, -46, 55, 44), Rect2(11, -46, 55, 44),
		Rect2(-66, 18, 55, 40), Rect2(11, 18, 55, 40),
		Rect2(-140, 20, 62, 78), Rect2(78, 20, 62, 78),
		Rect2(-140, 112, 128, 28), Rect2(12, 112, 128, 28)
	]
	for block in blocks:
		_draw_world_rect(block, Color(0.18, 0.15, 0.13, 0.95), map_rect, center)
	# River and promenade.
	_draw_world_rect(Rect2(-150, -150, 300, 92), Color(0.1, 0.28, 0.36, 0.95), map_rect, center)
	_draw_world_rect(Rect2(-150, -58, 300, 12), Color(0.43, 0.39, 0.3, 0.95), map_rect, center)
	# Roads.
	var road := Color(0.22, 0.24, 0.25, 0.98)
	_draw_world_rect(Rect2(-7, -46, 14, 186), road, map_rect, center)
	_draw_world_rect(Rect2(-142, 2, 284, 12), road, map_rect, center)
	_draw_world_rect(Rect2(-105, -40, 10, 182), road, map_rect, center)
	_draw_world_rect(Rect2(95, -40, 10, 182), road, map_rect, center)
	_draw_world_rect(Rect2(-142, 99, 284, 10), road, map_rect, center)
	# Objective.
	if mission_manager and not mission_manager.current.is_empty():
		var op := mission_manager.objective_position()
		var p := _to_screen(op, center)
		p.x = clampf(p.x, map_rect.position.x + 7.0, map_rect.end.x - 7.0)
		p.y = clampf(p.y, map_rect.position.y + 7.0, map_rect.end.y - 7.0)
		var gold := Color("#e7b45b")
		var diamond := PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)])
		draw_colored_polygon(diamond, gold)
		draw_arc(p, 10.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.5, 0.5), 1.2)
	# Civilian vehicles.
	var vehicles: Array = world.get("vehicles") if world else []
	for car in vehicles:
		if not is_instance_valid(car):
			continue
		var p := _to_screen(car.global_position, center)
		if map_rect.has_point(p):
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.85, 0.87, 0.82, 0.85))
	# Police.
	if wanted_system:
		var pulse := 0.55 + sin(flash * 9.0) * 0.45
		for pos in wanted_system.get_police_positions():
			var p := _to_screen(pos, center)
			if map_rect.has_point(p):
				draw_circle(p, 4.5, Color(0.9, 0.2, 0.16, pulse))
				draw_circle(p + Vector2(3, 0), 3.0, Color(0.2, 0.45, 1.0, 1.0 - pulse * 0.5))
	# Player arrow.
	var yaw := player.rotation.y
	var arrow := PackedVector2Array([
		Vector2(0, -9).rotated(-yaw), Vector2(6, 7).rotated(-yaw),
		Vector2(0, 4).rotated(-yaw), Vector2(-6, 7).rotated(-yaw)
	])
	for i in range(arrow.size()):
		arrow[i] += center
	draw_colored_polygon(arrow, Color("#f4ead2"))
	draw_polyline(arrow, Color(0.05, 0.08, 0.09, 0.9), 1.4)
	# Border and compass.
	draw_rect(full.grow(-1.0), Color(0.87, 0.7, 0.38, 0.75), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(center.x - 5.0, 20.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.87, 0.7, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, size.y - 10.0), "OLD TOWNE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.72, 0.62, 0.85))

func _draw_world_rect(world_rect: Rect2, color: Color, map_rect: Rect2, center: Vector2) -> void:
	var origin := _to_screen2(Vector2(world_rect.position.x, world_rect.position.y), center)
	var r := Rect2(origin, world_rect.size * scale_px)
	r = r.intersection(map_rect)
	if r.size.x > 0.0 and r.size.y > 0.0:
		draw_rect(r, color)

func _to_screen(world_pos: Vector3, center: Vector2) -> Vector2:
	return center + Vector2((world_pos.x - player.global_position.x) * scale_px, (world_pos.z - player.global_position.z) * scale_px)

func _to_screen2(world_pos: Vector2, center: Vector2) -> Vector2:
	return center + Vector2((world_pos.x - player.global_position.x) * scale_px, (world_pos.y - player.global_position.z) * scale_px)
