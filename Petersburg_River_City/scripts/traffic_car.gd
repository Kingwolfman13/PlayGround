class_name TrafficCar
extends Vehicle

## A loop-driving civilian car. It yields to obstacles and recovers if wedged.

var route_points: Array = []
var route_cursor := 0

func setup_traffic(g: Node, type: String, color: Color, points: Array) -> void:
	setup(g, type, color)
	route_points = points.duplicate()
	autopilot = true
	parked = false
	max_speed = 10.5
	accel = 7.5
	brake_force = 16.0
	route_cursor = 0
	if route_points.size() > 0:
		global_position = route_points[0] + Vector3(0, 0.05, 0)
		route_cursor = 1 % route_points.size()
		var next: Vector3 = route_points[route_cursor]
		var d := next - global_position
		d.y = 0.0
		if d.length() > 0.1:
			rotation.y = atan2(-d.x, -d.z)

func _ai_controls(delta: float) -> Vector2:
	if route_points.is_empty():
		return Vector2.ZERO
	var target: Vector3 = route_points[route_cursor]
	var flat_dist := Vector2(global_position.x - target.x, global_position.z - target.z).length()
	if flat_dist < 4.0:
		route_cursor = (route_cursor + 1) % route_points.size()
		target = route_points[route_cursor]
	if ai_stuck > 2.8:
		ai_stuck = 0.0
		return Vector2(-1.0, 0.25)
	var controls := drive_towards(target, delta, 8.5)
	# Yield to the player if they are directly ahead.
	if game and game.player:
		var to_player: Vector3 = game.player.global_position - global_position
		to_player.y = 0.0
		var forward := -global_transform.basis.z
		if to_player.length() < 8.0 and forward.dot(to_player.normalized()) > 0.86:
			controls.x = -0.7
	return controls
