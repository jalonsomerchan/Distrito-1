extends Node2D

signal changed
signal expired

const REACH_RADIUS := 100.0
const LINK_RADIUS := 480.0
const STEP := 160.0
const PICKUP_COLOR := Color("f2c66b")
const DROPOFF_COLOR := Color("8cdac0")

var city: Node2D
var car: CharacterBody2D
var graph := AStar2D.new()
var stops: Array[int] = []
var phase := "inactive"
var delivered := 0
var remaining := 0.0
var allowance := 0.0
var target_id := -1
var destination_id := -1
var route := PackedVector2Array()
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 10
	rng.randomize()

# Sample street centre lines; join only segments with room for the cargo truck.
# This also links offset junctions and the five bridges without crossing water.
func build_routes() -> void:
	if graph.get_point_count() > 0: return
	var buckets := {}
	var roads: Array[Rect2] = []
	roads.append_array(city.vertical_roads)
	roads.append_array(city.horizontal_roads)
	var samples := PackedVector2Array()
	for road in roads:
		var vertical := road.size.y > road.size.x
		var length := road.size.y if vertical else road.size.x
		var count := maxi(1, ceili(length / STEP))
		for i in range(count + 1):
			samples.append(road.position + (Vector2(road.size.x / 2, length * i / count) if vertical else Vector2(length * i / count, road.size.y / 2)))
	# Railings overlap the avenues. Add room to round their ends rather than
	# forcing a centre-line route through a railing at a bridge entrance.
	for bridge in city.bridges:
		var horizontal: bool = bridge.size.x > bridge.size.y
		var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
		var side := axis.rotated(PI / 2)
		var half_length: float = (bridge.size.x if horizontal else bridge.size.y) / 2
		var half_width: float = (bridge.size.y if horizontal else bridge.size.x) / 2
		for sign_value in [-1, 1]:
			var entrance: Vector2 = bridge.get_center() + axis * sign_value * (half_length + 110)
			for offset in [-1, 0, 1]: samples.append(entrance + side * offset * (half_width + 110))
	# Keep legacy IDs stable; new bypass points are appended after old samples.
	for island in city.roundabouts:
		var center := Vector2(island.center[0], island.center[1])
		for i in range(16):
			samples.append(center + Vector2.from_angle(TAU * i / 16) * (float(island.radius) + 115))
	var legacy_sample_count := samples.size()
	# Append rural nodes after the original city IDs so old jobs keep their targets.
	for trail in city.wilderness.trails:
		for i in range(1, trail.points.size()):
			var a := Vector2(trail.points[i-1][0], trail.points[i-1][1])
			var b := Vector2(trail.points[i][0], trail.points[i][1])
			var count := maxi(1, ceili(a.distance_to(b) / STEP))
			for j in range(count + 1): samples.append(a.lerp(b, float(j) / count))
	for sample_index in range(samples.size()):
		var at: Vector2 = samples[sample_index]
		if sample_index < legacy_sample_count and not city.URBAN_BOUNDS.grow(-76).has_point(at): continue
		if not city.street_clear(at, 76, true): continue
		var id := graph.get_available_point_id()
		graph.add_point(id, at)
		graph.set_point_disabled(id, not city.street_clear(at, 76))
		var cell := Vector2i(floori(at.x / LINK_RADIUS), floori(at.y / LINK_RADIUS))
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other in buckets.get(cell + Vector2i(x, y), []):
					var point := graph.get_point_position(other)
					if at.distance_to(point) <= LINK_RADIUS and segment_clear(at, point):
						graph.connect_points(id, other)
		if not buckets.has(cell): buckets[cell] = []
		buckets[cell].append(id)
	# Retain only the component reachable from the starting avenue.
	var first := graph.get_closest_point(Vector2(765, 1240))
	var visited := {first: true}
	stops.append(first)
	var cursor := 0
	while cursor < stops.size():
		for next in graph.get_point_connections(stops[cursor]):
			if not graph.is_point_disabled(next) and not visited.has(next):
				visited[next] = true
				stops.append(next)
		cursor += 1

func segment_clear(a: Vector2, b: Vector2) -> bool:
	var count := maxi(1, ceili(a.distance_to(b) / 40.0))
	for i in range(count + 1):
		if not city.street_clear(a.lerp(b, float(i) / count), 76): return false
	return true

func start() -> void:
	build_routes()
	delivered = 0
	next_package()

func stop() -> void:
	phase = "inactive"
	route.clear()
	queue_redraw()

func path_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, points.size()): length += points[i - 1].distance_to(points[i])
	return length

func choose_stop(from: Vector2) -> int:
	var origin := graph.get_closest_point(from)
	var minimum := minf(4200, 1000 + delivered * 240)
	var maximum := minimum + 2000
	var candidates: Array[int] = []
	for id in stops:
		var distance := from.distance_to(graph.get_point_position(id))
		if distance >= minimum and distance <= maximum: candidates.append(id)
	if candidates.is_empty():
		for id in stops:
			if from.distance_to(graph.get_point_position(id)) > REACH_RADIUS * 3: candidates.append(id)
	# Every candidate belongs to the starting connected component.
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else origin

func next_package() -> void:
	target_id = choose_stop(car.position)
	destination_id = choose_stop(graph.get_point_position(target_id))
	phase = "pickup"
	begin_leg(car.position)

func time_budget(distance: float, turns: int) -> float:
	# Cruising below top speed leaves room for traffic, braking and acceleration.
	var cruise := float(car.vehicle_data.max_speed) * 0.62
	var slack := 1.0 + 0.9 / (1.0 + delivered * 0.16)
	return ceilf((distance / cruise + turns * 0.9 + 6.0) * slack)

func begin_leg(from: Vector2) -> void:
	var origin := graph.get_closest_point(from)
	route = graph.get_point_path(origin, target_id)
	var turns := 0
	for i in range(2, route.size()):
		var before := (route[i - 1] - route[i - 2]).normalized()
		var after := (route[i] - route[i - 1]).normalized()
		if before.dot(after) < 0.85: turns += 1
	allowance = time_budget(path_length(route) + from.distance_to(graph.get_point_position(origin)), turns)
	remaining = allowance
	changed.emit()
	queue_redraw()

func target_position() -> Vector2:
	return graph.get_point_position(target_id) if target_id >= 0 else Vector2.ZERO

func tick(delta: float) -> void:
	if phase != "pickup" and phase != "dropoff": return
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		phase = "failed"
		route.clear()
		expired.emit()
	elif car.health > 0 and car.position.distance_to(target_position()) <= REACH_RADIUS and absf(car.speed) <= 65:
		if phase == "pickup":
			phase = "dropoff"
			target_id = destination_id
			begin_leg(car.position)
		else:
			delivered += 1
			next_package()
	queue_redraw()

func serialize() -> Dictionary:
	return {"phase": phase, "delivered": delivered, "remaining": remaining, "allowance": allowance, "target": target_id, "destination": destination_id}

func valid_save(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("phase") not in ["pickup", "dropoff", "failed"]: return false
	for key in ["delivered", "remaining", "allowance", "target", "destination"]:
		if not (data.get(key) is float or data.get(key) is int): return false
		if not is_finite(float(data[key])) or float(data[key]) < 0: return false
	for key in ["delivered", "target", "destination"]:
		if float(data[key]) != floorf(float(data[key])): return false
	if data.allowance <= 0 or data.remaining > data.allowance: return false
	if (data.phase == "failed") != (data.remaining == 0): return false
	build_routes()
	return int(data.target) in stops and int(data.destination) in stops

func restore(data: Dictionary) -> void:
	phase = data.phase
	delivered = int(data.delivered)
	remaining = float(data.remaining)
	allowance = float(data.allowance)
	target_id = int(data.target)
	destination_id = int(data.destination)
	route = graph.get_point_path(graph.get_closest_point(car.position), target_id) if phase != "failed" else PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	if phase not in ["pickup", "dropoff"] or not visible: return
	var at := target_position()
	var color := PICKUP_COLOR if phase == "pickup" else DROPOFF_COLOR
	draw_circle(at, REACH_RADIUS, Color(color, 0.18))
	draw_arc(at, REACH_RADIUS, 0, TAU, 64, color, 5, true)
	draw_rect(Rect2(at - Vector2(18, 18), Vector2(36, 36)), color, false, 4)
	# A nearby arrow always points towards the objective, even off screen.
	var direction := car.position.direction_to(at)
	if car.position.distance_to(at) > 220:
		var tip := car.position + direction * 190
		draw_colored_polygon(PackedVector2Array([tip + direction * 18, tip - direction.rotated(0.8) * 16, tip - direction.rotated(-0.8) * 16]), color)
