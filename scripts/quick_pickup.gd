extends Node2D

signal expired

const REACH_RADIUS := 92.0
const COLOR := Color("f2c66b")

var roads: Node2D
var city: Node2D
var car: CharacterBody2D
var phase := "inactive"
var collected := 0
var target_id := -1
var remaining := 0.0
var allowance := 0.0
var route := PackedVector2Array()
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 10
	rng.randomize()

func start() -> void:
	roads.build_routes()
	collected = 0
	_spawn_coin()

func stop() -> void:
	phase = "inactive"
	target_id = -1
	route.clear()
	queue_redraw()

func _spawn_coin() -> void:
	var origin := roads.graph.get_closest_point(car.position)
	var candidates: Array[int] = []
	var minimum := minf(8000.0, 1500.0 + collected * 180.0)
	var maximum := minimum + 5000.0
	for id in roads.stops:
		var distance := car.position.distance_to(roads.graph.get_point_position(id))
		if distance >= minimum and distance <= maximum:
			candidates.append(id)
	if candidates.is_empty():
		for id in roads.stops:
			if car.position.distance_to(roads.graph.get_point_position(id)) > REACH_RADIUS * 3:
				candidates.append(id)
	target_id = candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else origin
	_begin_leg()

func _begin_leg() -> void:
	var origin := roads.graph.get_closest_point(car.position)
	route = roads.graph.get_point_path(origin, target_id)
	var distance := roads.path_length(route) + car.position.distance_to(roads.graph.get_point_position(origin))
	var turns := 0
	for i in range(2, route.size()):
		var before := (route[i - 1] - route[i - 2]).normalized()
		var after := (route[i] - route[i - 1]).normalized()
		if before.dot(after) < 0.85: turns += 1
	var cruise := float(car.vehicle_data.max_speed) * 0.62
	var slack := 1.55 / (1.0 + collected * 0.10)
	allowance = maxf(18.0, ceilf((distance / cruise + turns * 0.9 + 5.0) * slack))
	remaining = allowance
	phase = "active"
	queue_redraw()

func target_position() -> Vector2:
	return roads.graph.get_point_position(target_id) if target_id >= 0 else Vector2.ZERO

func tick(delta: float) -> void:
	if phase != "active": return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		phase = "failed"
		route.clear()
		expired.emit()
		queue_redraw()
		return
	if car.health > 0 and car.position.distance_to(target_position()) <= REACH_RADIUS:
		collected += 1
		_spawn_coin()
	queue_redraw()

func serialize() -> Dictionary:
	return {"phase": phase, "collected": collected, "target": target_id, "remaining": remaining, "allowance": allowance}

func valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("phase") not in ["active", "failed"]: return false
	for key in ["collected", "target", "remaining", "allowance"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0: return false
	if float(data.collected) != floorf(float(data.collected)) or float(data.target) != floorf(float(data.target)): return false
	if data.allowance <= 0 or data.remaining > data.allowance: return false
	if (data.phase == "failed") != (data.remaining == 0): return false
	roads.build_routes()
	return int(data.target) in roads.stops

func restore(data: Dictionary) -> void:
	phase = str(data.phase)
	collected = int(data.collected)
	target_id = int(data.target)
	remaining = float(data.remaining)
	allowance = float(data.allowance)
	route = roads.graph.get_point_path(roads.graph.get_closest_point(car.position), target_id) if phase == "active" else PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	if phase != "active" or not visible: return
	var at := target_position()
	draw_circle(at, REACH_RADIUS, Color(COLOR, 0.18))
	draw_arc(at, REACH_RADIUS, 0.0, TAU, 48, COLOR, 5.0, true)
	draw_circle(at, 23.0, COLOR)
	draw_circle(at, 14.0, Color("fff1bd"))
	draw_circle(at, 8.0, COLOR)
	var direction := car.position.direction_to(at)
	if car.position.distance_to(at) > 220.0:
		var tip := car.position + direction * 190.0
		draw_colored_polygon(PackedVector2Array([tip + direction * 18.0, tip - direction.rotated(0.8) * 16.0, tip - direction.rotated(-0.8) * 16.0]), COLOR)
