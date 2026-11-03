extends SceneTree
var failures := 0
var app: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func capture(filename: String, at: Vector2) -> void:
	if DisplayServer.get_name() == "headless": return
	app.car.position = at
	app.car.rotation = 0
	app.car.restore()
	app.car.camera.position = Vector2.ZERO
	app.car.camera.reset_smoothing()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename)

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(app.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.city-details-save.json"
	app.start_new_game()
	app.car.enabled = false
	app.traffic.set_physics_process(false)
	app.traffic.set_active(false)
	var city: Node2D = app.city
	var details: Node2D = city.details
	check(city.beaches.size() >= 4 and city.roundabouts.size() == 3 and details.signals.size() >= 10, "Beach, three roundabouts and city traffic signals exist")
	check(not city.is_water(Vector2(6220, 3600)) and city.is_safe_position(Vector2(6220, 3600)), "Beach sand replaces water with an accessible shore")
	check(city.is_water(Vector2(6650, 3600)) and not city.is_safe_position(Vector2(6650, 3600)), "Water beyond the beach remains solid")
	check(city.is_sidewalk(Vector2(6220, 3600)) and city.district_at(Vector2(6220, 3600)) == "PLAYA DEL COBRE", "Beach has a district name and low-speed terrain")
	var safe_cycles := true
	for time in range(32):
		details.clock = time
		for i in range(details.signals.size()):
			if details.light(i, 0) == "green" and details.light(i, 1) == "green": safe_cycles = false
	check(safe_cycles, "Opposing signal axes never have green together")
	details.clock = 16
	var entry: Dictionary = details.signals[0]
	var center := Vector2(entry.center[0], entry.center[1])
	var approach := center + Vector2(0, float(entry.depth) / 2 + 28 + 33 + 30)
	check(details.should_stop(approach, Vector2.UP, 100, 66), "Traffic brakes before the stop line on red")
	details.clock = 0
	check(not details.should_stop(approach, Vector2.UP, 100, 66), "Traffic may proceed on green")
	details.clock = 16
	check(not details.should_stop(center, Vector2.UP, 100, 66), "Cars already inside a junction continue clearing it")
	# Exercise an actual driver on the north approach, not just signal queries.
	details.set_process(false)
	var driver: CharacterBody2D = app.traffic.cars[0]
	var best_progress := 0.0
	var best_distance := INF
	for progress in range(0, int(driver.route_length), 5):
		var distance: float = driver.sample(progress).distance_to(Vector2(695, 400))
		if distance < best_distance:
			best_distance = distance
			best_progress = progress
	driver.place(best_progress)
	driver.cruise_speed = 180
	driver.speed = 100
	driver.enabled = true
	driver.collision_layer = 4
	driver.collision_mask = 7
	details.clock = 16
	await frames(120)
	check(driver.speed < 1 and driver.position.y < 620, "Actual AI driver stops before the red signal")
	var stopped_progress: float = driver.travelled
	details.clock = 0
	await frames(120)
	check(driver.travelled > stopped_progress + 80, "Actual AI driver resumes after green")
	driver.enabled = false
	driver.collision_layer = 0
	details.set_process(true)
	app.paused = true
	var before: float = details.clock
	details._process(2)
	check(details.clock == before, "Pause freezes signal clock")
	app.paused = false
	details._process(0.25)
	check(details.clock > before, "Signals advance during gameplay")
	app.car.position = app.SPAWN
	check(app.save_game(), "Signal clock saves with game")
	var saved_time: float = details.clock
	app.show_menu()
	app.load_game()
	check(is_equal_approx(details.clock, saved_time), "Load restores signal cycle")
	app.car.enabled = false
	app.traffic.set_active(false)
	app.delivery.build_routes()
	var bypasses := true
	for island in city.roundabouts:
		var at := Vector2(island.center[0], island.center[1])
		if city.is_safe_position(at) or city.street_clear(at, 35): bypasses = false
		for i in range(16):
			var point := at + Vector2.from_angle(TAU * i / 16) * (float(island.radius) + 115)
			if not city.street_clear(point, 76): bypasses = false
	check(bypasses, "Roundabout islands block entry and the full ring fits the truck")
	var all_reachable := true
	for island in city.roundabouts:
		var at := Vector2(island.center[0], island.center[1])
		var a: int = app.delivery.graph.get_closest_point(at + Vector2.UP * 450)
		var b: int = app.delivery.graph.get_closest_point(at + Vector2.DOWN * 450)
		var route: PackedVector2Array = app.delivery.graph.get_point_path(a, b)
		if route.size() < 2: all_reachable = false
		for i in range(1, route.size()):
			if not app.delivery.segment_clear(route[i-1], route[i]): all_reachable = false
	check(all_reachable, "Mission routes drive around every island rather than through it")
	# Physical high-speed impact cannot pass through the central island.
	app.car.set_vehicle("cargo_truck")
	app.car.position = Vector2(7400, 3260)
	app.car.rotation = PI
	app.car.restore()
	app.car.speed = 360
	app.car.velocity = Vector2(0, 360)
	app.car.enabled = true
	Input.action_press("accelerate")
	await frames(70)
	Input.action_release("accelerate")
	check(app.car.position.y < 3450 and app.car.health < app.car.max_health, "Roundabout island physically stops and damages the truck")
	app.car.enabled = false
	# Old free-drive saves overlapping a new island preserve progress safely.
	var old := {"version":1, "city_version":3, "x":7400.0, "y":3510.0, "angle":0.0, "distance":123.0, "health":50.0}
	write_save(old)
	app.load_game()
	check(app.car.position == app.SPAWN and app.car.distance_driven == 123 and app.car.health == 50, "Old save inside an island moves safely while preserving progress")
	# Find a legacy navigation point that is now inside an island.
	var blocked := -1
	for id in app.delivery.graph.get_point_ids():
		if app.delivery.graph.is_point_disabled(id): blocked = id; break
	check(blocked >= 0, "Legacy graph IDs remain available for map migration")
	if blocked >= 0:
		old = {"version":1, "city_version":3, "x":765.0, "y":1240.0, "angle":0.0, "distance":123.0, "mode":"delivery", "delivery":{"phase":"pickup", "delivered":4, "remaining":30.0, "allowance":60.0, "target":blocked, "destination":blocked}}
		write_save(old)
		app.load_game()
		check(app.game_mode == "delivery" and app.delivery.delivered == 4 and app.delivery.remaining == 30 and app.delivery.target_id in app.delivery.stops, "Old delivery destinations move off new islands without losing progress")
	app.start_new_game("pursuit")
	var old_pursuit: Dictionary = app.read_save()
	old_pursuit.city_version = 3
	old_pursuit.pursuit.x = 7400.0
	old_pursuit.pursuit.y = 3510.0
	write_save(old_pursuit)
	app.load_game()
	check(app.game_mode == "pursuit" and city.street_clear(app.pursuit.target.position, 35) and app.pursuit.phase == "active", "Old fugitive moves off a new island and replans its route")
	app.start_new_game("escape")
	var old_escape: Dictionary = app.read_save()
	old_escape.city_version = 3
	old_escape.escape.patrols[0].x = 7400.0
	old_escape.escape.patrols[0].y = 3510.0
	write_save(old_escape)
	app.load_game()
	check(app.game_mode == "escape" and city.street_clear(app.escape.patrols[0].position, 35) and app.escape.phase == "active", "Old escape police move safely off new islands")
	app.start_new_game()
	app.car.enabled = false
	app.traffic.set_physics_process(false)
	app.traffic.set_active(false)
	await capture("city-beach.png", Vector2(6110, 4050))
	await capture("city-roundabout.png", Vector2(7400, 3760))
	details.clock = 16
	await capture("city-signals.png", Vector2(765, 800))
	DirAccess.remove_absolute(app.save_path)
	print("CITY DETAILS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
