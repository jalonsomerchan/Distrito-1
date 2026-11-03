extends Node2D

signal level_started
signal failed
const Police = preload("res://scripts/police_chaser.gd")
const COLOR := Color("76b8ff")
var game: Node2D
var city: Node2D
var car: CharacterBody2D
var roads: Node2D
var patrols: Array[CharacterBody2D] = []
var phase := "inactive"
var level := 1
var escape_time := 0.0
var arrest := 0.0
var transition := 0.0
var reason := ""

func _ready() -> void:
	z_index = 10
	stop()

func difficulty() -> float:
	return float(level - 1) / (level + 4.0)

func police_count() -> int:
	return mini(6, 2 + (level - 1) / 2)

func police_speed() -> float:
	return 260 + 280 * difficulty()

func police_acceleration() -> float:
	return 170 + 180 * difficulty()

func police_health() -> float:
	return 90 + 150 * difficulty()

func escape_distance() -> float:
	return 1800 + 400 * difficulty()

func escape_duration() -> float:
	return 8 + 4 * difficulty()

func arrest_duration() -> float:
	return 3 - 1.3 * difficulty()

func is_active() -> bool:
	return phase == "active" and game.playing and not game.paused

func set_patrols_visible(active: bool) -> void:
	for patrol in patrols:
		patrol.visible = active
		patrol.collision_layer = 4 if active else 0
		patrol.collision_mask = 7 if active else 0

func clear_patrols() -> void:
	for patrol in patrols:
		remove_child(patrol)
		patrol.queue_free()
	patrols.clear()

func stop() -> void:
	phase = "inactive"
	clear_patrols()
	hide()
	queue_redraw()

func start() -> void:
	roads.build_routes()
	level = 1
	reason = ""
	start_level()

func add_patrol(at: Vector2) -> CharacterBody2D:
	var patrol := Police.new()
	patrol.mission = self
	patrol.collision_layer = 4
	patrol.collision_mask = 7
	patrol.position = at
	patrol.max_health = police_health()
	patrol.health = patrol.max_health
	add_child(patrol)
	patrols.append(patrol)
	patrol.rotation = at.direction_to(car.position).angle() + PI / 2
	return patrol

func start_level() -> void:
	clear_patrols()
	phase = "active"
	escape_time = 0
	arrest = 0
	transition = 0
	var candidates: Array[int] = []
	var minimum := 650 - 200 * difficulty()
	for id in roads.stops:
		var point: Vector2 = roads.graph.get_point_position(id)
		var distance := car.position.distance_to(point)
		if distance < minimum or distance > minimum + 500: continue
		var clear := true
		for vehicle in game.traffic.cars:
			if point.distance_to(vehicle.position) < vehicle.body_radius() + 110: clear = false
		if clear: candidates.append(id)
	candidates.shuffle()
	for id in candidates:
		var at: Vector2 = roads.graph.get_point_position(id)
		var clear := true
		for patrol in patrols:
			if at.distance_to(patrol.position) < 230: clear = false
		if not clear: continue
		add_patrol(at)
		if patrols.size() == police_count(): break
	# Fall back to more distant safe streets if the immediate area is crowded.
	if patrols.size() < police_count():
		for id in roads.stops:
			var at: Vector2 = roads.graph.get_point_position(id)
			if at.distance_to(car.position) < minimum or at.distance_to(car.position) >= escape_distance() - 100: continue
			var clear := true
			for patrol in patrols:
				if at.distance_to(patrol.position) < 230: clear = false
			for vehicle in game.traffic.cars:
				if at.distance_to(vehicle.position) < vehicle.body_radius() + 110: clear = false
			if clear: add_patrol(at)
			if patrols.size() == police_count(): break
	show()
	level_started.emit()

func clear_view(a: Vector2, b: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(a, b, 1)
	return car.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func nearest_distance() -> float:
	var distance := INF
	for patrol in patrols:
		if patrol.health > 0: distance = minf(distance, patrol.position.distance_to(car.position))
	return distance

func tick(delta: float) -> void:
	if phase == "escaped":
		transition = maxf(0, transition - delta)
		if transition <= 0:
			level += 1
			car.restore()
			start_level()
	elif phase == "active":
		if car.health <= 0:
			finish("COCHE DESTROZADO")
			return
		var surrounded := false
		for patrol in patrols:
			if patrol.health > 0 and patrol.speed < 60 and car.position.distance_to(patrol.position) < 145 and clear_view(car.position, patrol.position): surrounded = true
		arrest = minf(arrest_duration(), arrest + delta) if surrounded and absf(car.speed) < 40 else 0.0
		if arrest >= arrest_duration():
			finish("TE HAN DETENIDO")
			return
		escape_time = minf(escape_duration(), escape_time + delta) if nearest_distance() >= escape_distance() else 0.0
		if escape_time >= escape_duration():
			phase = "escaped"
			transition = 3
			set_patrols_visible(false)
			game._toast("¡Has escapado! Preparando siguiente nivel…")
	queue_redraw()

func finish(message: String) -> void:
	phase = "failed"
	reason = message
	failed.emit()
	queue_redraw()

func _draw() -> void:
	if phase != "active": return
	var flash := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	for patrol in patrols:
		if patrol.health <= 0: continue
		draw_arc(patrol.position, 53, 0, TAU, 32, COLOR, 2, true)
		for side in [-1, 1]:
			var color := Color("5eaeff") if (side < 0) == flash else Color("fa6c6c")
			draw_circle(patrol.position + Vector2(side * 10, 0).rotated(patrol.rotation), 5, color)

func serialize() -> Dictionary:
	var police: Array = []
	for patrol in patrols:
		police.append({"x": patrol.position.x, "y": patrol.position.y, "angle": patrol.rotation, "health": patrol.health, "speed": patrol.speed})
	return {"phase": phase, "level": level, "escape_time": escape_time, "arrest": arrest, "transition": transition, "reason": reason, "patrols": police}

func valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("phase") not in ["active", "escaped", "failed"]: return false
	for key in ["level", "escape_time", "arrest", "transition"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])) or data[key] < 0: return false
	if data.level < 1 or data.level > 1000000 or floorf(data.level) != data.level: return false
	var factor: float = (data.level - 1) / (data.level + 4.0)
	if data.escape_time > 8 + 4 * factor + 0.001 or data.arrest > 3 - 1.3 * factor + 0.001 or data.transition > 3: return false
	if data.get("reason") not in ["", "COCHE DESTROZADO", "TE HAN DETENIDO"]: return false
	if (data.phase == "failed") != (data.reason != ""): return false
	if not data.get("patrols") is Array or data.patrols.size() != mini(6, 2 + (int(data.level) - 1) / 2): return false
	for patrol in data.patrols:
		if not patrol is Dictionary: return false
		for key in ["x", "y", "angle", "health", "speed"]:
			if not (patrol.get(key) is float or patrol.get(key) is int) or not is_finite(float(patrol[key])): return false
		if patrol.health < 0 or patrol.health > 90 + 150 * factor + 0.001 or patrol.speed < 0 or patrol.speed > 260 + 280 * factor + 0.001: return false
		if not city.is_safe_position(Vector2(patrol.x, patrol.y)): return false
	return true

func restore(data: Dictionary) -> void:
	roads.build_routes()
	clear_patrols()
	phase = data.phase
	level = int(data.level)
	escape_time = float(data.escape_time)
	arrest = float(data.arrest)
	transition = float(data.transition)
	reason = data.reason
	for entry in data.patrols:
		var patrol := add_patrol(Vector2(entry.x, entry.y))
		patrol.rotation = float(entry.angle)
		patrol.health = minf(police_health(), float(entry.health))
		patrol.speed = float(entry.speed)
		patrol.impact_cooldown = 0.4
		patrol.update_sprite()
	# Traffic is redistributed on load. Check the whole fleet together so
	# clearing one saved patrol never places traffic on another patrol.
	for vehicle in game.traffic.cars:
		for attempt in range(32):
			var clear: bool = vehicle.position.distance_to(car.position) > vehicle.body_radius() + car.body_radius() + 80
			for patrol in patrols:
				if vehicle.position.distance_to(patrol.position) < vehicle.body_radius() + 110: clear = false
			if clear: break
			vehicle.place(vehicle.progress + vehicle.route_length * 0.137)
	set_patrols_visible(phase != "escaped")
	show()
	queue_redraw()
