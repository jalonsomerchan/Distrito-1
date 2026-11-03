extends Node2D

signal level_started
signal failed
const Fugitive = preload("res://scripts/fugitive.gd")
const COLOR := Color("ee806d")
var game: Node2D
var city: Node2D
var car: CharacterBody2D
var roads: Node2D
var target: CharacterBody2D
var phase := "inactive"
var level := 1
var arrest := 0.0
var lost_time := 0.0
var transition := 0.0
var reason := ""
var path := PackedVector2Array()
var path_index := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 10
	rng.randomize()
	target = Fugitive.new()
	target.mission = self
	add_child(target)
	stop()

func difficulty() -> float:
	return float(level - 1) / (level + 5.0)

func flee_speed() -> float:
	return 220 + 290 * difficulty()

func flee_acceleration() -> float:
	return 150 + 160 * difficulty()

func resistance() -> float:
	return 55 + 180 * difficulty()

func arrest_duration() -> float:
	return 2 + 2 * difficulty()

func escape_grace() -> float:
	return 10 - 5 * difficulty()

func is_active() -> bool:
	return phase == "active" and game.playing and not game.paused

func stop() -> void:
	phase = "inactive"
	set_target_visible(false)
	hide()
	queue_redraw()

func set_target_visible(active: bool) -> void:
	target.visible = active
	target.collision_layer = 4 if active else 0
	target.collision_mask = 7 if active else 0

func start() -> void:
	roads.build_routes()
	level = 1
	reason = ""
	start_level()

func start_level() -> void:
	phase = "active"
	arrest = 0
	lost_time = 0
	transition = 0
	var candidates: Array[int] = []
	var distance_min := 600 + 700 * difficulty()
	for id in roads.stops:
		var at: Vector2 = roads.graph.get_point_position(id)
		if car.position.distance_to(at) < distance_min or car.position.distance_to(at) > distance_min + 450: continue
		var clear := true
		for vehicle in game.traffic.cars:
			if vehicle.position.distance_to(at) < vehicle.body_radius() + 110: clear = false
		if clear: candidates.append(id)
	# The street network surrounds the player; use its nearest node as fallback.
	var id: int = candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else roads.stops.back()
	target.position = roads.graph.get_point_position(id)
	target.max_health = resistance()
	target.health = target.max_health
	target.speed = 0
	target.velocity = Vector2.ZERO
	target.impact_cooldown = 0
	target.update_sprite()
	plan_escape()
	target.rotation = target.position.direction_to(path[path_index]).angle() + PI / 2
	set_target_visible(true)
	show()
	level_started.emit()

func plan_escape() -> void:
	var origin: int = roads.graph.get_closest_point(target.position)
	var best := origin
	var score := -INF
	# Pick a distant reachable destination favouring separation from the police.
	for i in range(30):
		var id: int = roads.stops[rng.randi_range(0, roads.stops.size() - 1)]
		var at: Vector2 = roads.graph.get_point_position(id)
		var distance := target.position.distance_to(at)
		if distance < 1200 or distance > 5000: continue
		var value := at.distance_to(car.position) + rng.randf_range(0, 800)
		if value > score:
			score = value
			best = id
	if best == origin:
		for id in roads.stops:
			if roads.graph.get_point_position(id).distance_to(target.position) > 1500:
				best = id
				break
	path = roads.graph.get_point_path(origin, best)
	path_index = 1 if path.size() > 1 and target.position.distance_to(path[0]) < 8 else 0

func tick(delta: float) -> void:
	if phase == "caught":
		transition = maxf(0, transition - delta)
		if transition <= 0:
			level += 1
			car.restore()
			start_level()
	elif phase == "active":
		if car.health <= 0:
			finish("PATRULLA DESTROZADA")
			return
		var distance := car.position.distance_to(target.position)
		lost_time = lost_time + delta if distance > 2500 else 0.0
		if lost_time >= escape_grace():
			finish("EL FUGITIVO HA ESCAPADO")
			return
		var query := PhysicsRayQueryParameters2D.create(car.position, target.position, 1)
		var clear: bool = car.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
		if distance < 145 and absf(car.speed) < 45 and target.speed < 20 and clear:
			arrest += delta
			if arrest >= arrest_duration():
				arrest = arrest_duration()
				phase = "caught"
				transition = 3
				target.speed = 0
				target.velocity = Vector2.ZERO
				game._toast("¡Fugitivo detenido! Preparando siguiente nivel…")
		else:
			arrest = 0
	queue_redraw()

func finish(message: String) -> void:
	phase = "failed"
	reason = message
	failed.emit()
	queue_redraw()

func _draw() -> void:
	if phase not in ["active", "caught"]: return
	draw_arc(target.position, 58, 0, TAU, 40, COLOR, 3, true)
	if car.position.distance_to(target.position) > 220:
		var direction := car.position.direction_to(target.position)
		var tip := car.position + direction * 190
		draw_colored_polygon(PackedVector2Array([tip + direction * 18, tip - direction.rotated(0.8) * 16, tip - direction.rotated(-0.8) * 16]), COLOR)
	var flash := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	draw_circle(car.position + Vector2(-10, 0).rotated(car.rotation), 5, Color("5eaeff") if flash else Color("fa6c6c"))
	draw_circle(car.position + Vector2(10, 0).rotated(car.rotation), 5, Color("fa6c6c") if flash else Color("5eaeff"))

func serialize() -> Dictionary:
	var points: Array = []
	for point in path: points.append(roads.graph.get_closest_point(point))
	return {"phase": phase, "level": level, "arrest": arrest, "lost_time": lost_time, "transition": transition, "reason": reason, "x": target.position.x, "y": target.position.y, "angle": target.rotation, "health": target.health, "speed": target.speed, "path": points, "path_index": path_index}

func valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("phase") not in ["active", "caught", "failed"]: return false
	for key in ["level", "arrest", "lost_time", "transition", "x", "y", "angle", "health", "speed", "path_index"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])): return false
	if data.level < 1 or data.level > 1000000 or floorf(data.level) != data.level: return false
	var factor: float = (data.level - 1.0) / (data.level + 5.0)
	if data.health < 0 or data.health > 55 + 180 * factor + 0.001 or data.speed < 0 or data.speed > 220 + 290 * factor + 0.001: return false
	if data.arrest < 0 or data.arrest > 2 + 2 * factor + 0.001 or data.lost_time < 0 or data.lost_time > 11 or data.transition < 0 or data.transition > 3: return false
	if data.get("reason") not in ["", "PATRULLA DESTROZADA", "EL FUGITIVO HA ESCAPADO"]: return false
	if not city.street_clear(Vector2(data.x, data.y), 35): return false
	if not data.get("path") is Array or data.path.is_empty() or data.path.size() > 5000: return false
	if data.path_index < 0 or data.path_index >= data.path.size() or floorf(data.path_index) != data.path_index: return false
	roads.build_routes()
	for id in data.path:
		if not (id is float or id is int) or not is_finite(float(id)) or floorf(float(id)) != float(id) or int(id) not in roads.stops: return false
	for i in range(1, data.path.size()):
		if data.path[i-1] != data.path[i] and not roads.graph.are_points_connected(int(data.path[i-1]), int(data.path[i])): return false
	return true

func clear_target_traffic() -> void:
	# Traffic is redistributed on load; leave room around the saved suspect too.
	for vehicle in game.traffic.cars:
		if vehicle.position.distance_to(target.position) >= vehicle.body_radius() + 110: continue
		for attempt in range(24):
			vehicle.place(vehicle.progress + vehicle.route_length * 0.137)
			var clear: bool = vehicle.position.distance_to(target.position) > vehicle.body_radius() + 110 and vehicle.position.distance_to(car.position) > vehicle.body_radius() + car.body_radius() + 80
			for other in game.traffic.cars:
				if other != vehicle and other.position.distance_to(vehicle.position) < other.body_radius() + vehicle.body_radius() + 30: clear = false
			if clear: break

func restore(data: Dictionary) -> void:
	phase = data.phase
	level = int(data.level)
	arrest = float(data.arrest)
	lost_time = float(data.lost_time)
	transition = float(data.transition)
	reason = data.reason
	target.position = Vector2(data.x, data.y)
	target.rotation = float(data.angle)
	target.max_health = resistance()
	target.health = minf(target.max_health, float(data.health))
	target.speed = float(data.speed)
	target.velocity = Vector2.ZERO
	target.impact_cooldown = 0.4
	target.update_sprite()
	path.clear()
	for id in data.path: path.append(roads.graph.get_point_position(int(id)))
	path_index = int(data.path_index)
	clear_target_traffic()
	set_target_visible(true)
	show()
	queue_redraw()
