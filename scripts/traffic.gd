extends Node2D

const Catalog = preload("res://scripts/vehicle_catalog.gd")
const TrafficCar = preload("res://scripts/traffic_car.gd")
const MAX_VEHICLES := 64
const ACTIVE_DISTANCE := 2500.0

var city: Node2D
var player: CharacterBody2D
var game: Node2D
var cars: Array[CharacterBody2D] = []
var showing := true
var simulate_all := false

func _ready() -> void:
	process_physics_priority = -10
	if Catalog.ids(true).is_empty():
		set_active(false)
		return
	var available: Array[Rect2] = city.traffic_blocks.duplicate()
	if available.is_empty():
		set_active(false)
		return
	var ordered: Array[Rect2] = [available.pop_front()]
	available.sort_custom(func(a: Rect2,b: Rect2): return a.get_center().distance_squared_to(player.position)<b.get_center().distance_squared_to(player.position))
	for i in range(mini(11,available.size())): ordered.append(available.pop_front())
	var slots := mini(MAX_VEHICLES-ordered.size(),available.size())
	for i in range(slots): ordered.append(available[int(float(i)*available.size()/slots)])
	for index in range(ordered.size()):
		for copy in range(1):
			var car := TrafficCar.new()
			car.controller = self
			car.driver_id = cars.size()
			car.vehicle_id = Catalog.traffic_id(car.driver_id)
			var definition := Catalog.get_vehicle(car.vehicle_id)
			car.cruise_speed = lerpf(float(definition.ai.cruise_min), float(definition.ai.cruise_max), fposmod(car.driver_id * 0.37, 1))
			car.route = make_route(ordered[index], definition)
			add_child(car)
			cars.append(car)
			car.place(car.route_length * (0.21 + copy * 0.5))
	set_active(false)

func make_route(block: Rect2, definition: Dictionary = {}) -> PackedVector2Array:
	# Clockwise loops use the right-hand lane on every side of a block.
	# The curve stays outside the sidewalk even with a whole car's clearance.
	if definition.is_empty(): definition = Catalog.get_vehicle(Catalog.default_id())
	var rect := block.grow(float(definition.ai.lane_offset))
	var radius := minf(float(definition.ai.turn_radius), minf(rect.size.x, rect.size.y) / 2 - 1)
	var centers := [Vector2(rect.end.x - radius, rect.position.y + radius),
		Vector2(rect.end.x - radius, rect.end.y - radius),
		Vector2(rect.position.x + radius, rect.end.y - radius),
		Vector2(rect.position.x + radius, rect.position.y + radius)]
	var points := PackedVector2Array()
	for corner in range(4):
		for step in range(7):
			var angle := -PI / 2 + corner * PI / 2 + step * PI / 12
			points.append(centers[corner] + Vector2.from_angle(angle) * radius)
	return points

func reset() -> void:
	for i in range(cars.size()):
		var car = cars[i]
		car.place(car.route_length * (0.13 + fmod(i * 0.173, 0.75)))
		# Never materialise a vehicle on the player's loaded/reset position.
		for attempt in range(12):
			var clear: bool = car.position.distance_to(player.position) > maxf(210, car.body_radius() + player.body_radius() + 80)
			for previous in range(i):
				if car.position.distance_to(cars[previous].position) < car.body_radius() + cars[previous].body_radius() + 44: clear = false
			if clear: break
			car.place(car.progress + car.body_radius() * 2 + 110)

func clear_near_player() -> void:
	for car in cars:
		if car.position.distance_to(player.position) < maxf(170, car.body_radius() + player.body_radius() + 100):
			car.place(car.progress + car.route_length / 2)
			for attempt in range(12):
				var clear: bool = car.position.distance_to(player.position) > car.body_radius() + player.body_radius() + 80
				for other in cars:
					if other != car and car.position.distance_to(other.position) < car.body_radius() + other.body_radius() + 44: clear = false
				if clear: break
				car.place(car.progress + car.body_radius() * 2 + 110)

func set_active(active: bool) -> void:
	showing = active
	visible = active
	for car in cars:
		apply_car_state(car)

func apply_car_state(car: CharacterBody2D) -> void:
	var nearby: bool = simulate_all or car.position.distance_squared_to(player.position)<ACTIVE_DISTANCE*ACTIVE_DISTANCE
	var active: bool = showing and game.playing and nearby
	car.visible = active
	car.collision_layer = 4 if active else 0
	car.collision_mask = 7 if active else 0
	car.enabled = active and not game.paused

func _physics_process(_delta: float) -> void:
	if showing != game.playing: set_active(game.playing)
	for car in cars:
		apply_car_state(car)

func must_yield(driver: CharacterBody2D) -> bool:
	# Fixed priority resolves crossing traffic before both vehicles reach a junction.
	var future: Vector2 = driver.sample(driver.progress + maxf(driver.speed, 90) * 0.8)
	var heading: Vector2 = driver.direction_at(driver.progress)
	for other in cars:
		if other == driver or not other.enabled or other.driver_id > driver.driver_id: continue
		if driver.position.distance_squared_to(other.position) > 320 * 320: continue
		if absf(heading.dot(other.direction_at(other.progress))) > 0.75: continue
		var other_future: Vector2 = other.sample(other.progress + maxf(other.speed, 90) * 0.8)
		var clearance: float = maxf(85, driver.body_radius() + other.body_radius() + 25)
		if future.distance_squared_to(other_future) < clearance * clearance: return true
	return false
