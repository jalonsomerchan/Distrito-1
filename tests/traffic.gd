extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.traffic-save.json"
	app.traffic.simulate_all = true
	check(app.traffic.cars.size() == app.traffic.MAX_VEHICLES and not app.traffic.visible, "Capped AI fleet, hidden and non-colliding in menu")
	app.start_new_game()
	await frames(3)
	var routes_safe := true
	var spawn_safe := true
	for driver in app.traffic.cars:
		spawn_safe = spawn_safe and driver.position.distance_to(app.car.position) > 180
		for at in range(0, int(driver.route_length), 30):
			var point: Vector2 = driver.sample(at)
			routes_safe = routes_safe and app.city.WORLD_BOUNDS.grow(-34).has_point(point)
			for block in app.city.blocks:
				if block.grow(34).has_point(point): routes_safe = false
	check(routes_safe, "All routes and rounded corners fit the roads with full-car clearance")
	check(spawn_safe, "Traffic does not spawn on the player's vehicle")
	await frames(120)
	var moving := 0
	for driver in app.traffic.cars:
		if driver.travelled > 30: moving += 1
	check(moving > 30, "AI traffic drives autonomously across the city")
	app.paused = true
	app.car.enabled = false
	await frames(2)
	var positions := []
	for driver in app.traffic.cars: positions.append(driver.position)
	await frames(20)
	var frozen := true
	for i in range(positions.size()):
		frozen = frozen and app.traffic.cars[i].position == positions[i]
	check(frozen, "Pause freezes every AI vehicle")
	app.resume_game()
	# Isolate one driver to verify braking and collision behaviour reproducibly.
	var driver = app.traffic.cars[0]
	for other in app.traffic.cars:
		if other != driver:
			other.set_physics_process(false)
			other.collision_layer = 0
	driver.place(200)
	driver.speed = 180
	app.car.position = driver.sample(345)
	app.car.enabled = false
	app.car.velocity = Vector2.ZERO
	app.car.restore()
	await frames(90)
	check(driver.speed < 1 and driver.position.distance_to(app.car.position) >= 65 and app.car.health == 100, "AI brakes before a stationary player without hitting it")
	app.car.position = app.SPAWN
	var stopped_at: Vector2 = driver.position
	await frames(60)
	check(driver.position.distance_to(stopped_at) > 40, "AI resumes driving when its lane clears")
	driver.place(200)
	driver.speed = 250
	app.car.position = driver.sample(270)
	app.car.restore()
	await frames(12)
	check(app.car.health < 100, "An unavoidable moving AI collision damages a stationary player")
	driver.place(350)
	driver.speed = 0
	driver.set_physics_process(false)
	app.car.position = driver.sample(200)
	app.car.rotation = driver.direction_at(200).angle() + PI / 2
	app.car.restore()
	app.car.speed = 450
	app.car.velocity = driver.direction_at(200) * 450
	app.car.enabled = true
	await frames(40)
	check(app.car.health < 100, "Player collides with AI vehicles and loses health")
	for other in app.traffic.cars: other.set_physics_process(true)
	app.start_new_game()
	Engine.time_scale = 6
	var off_road := 0
	for frame in range(600):
		await physics_frame
		if frame % 20 == 0:
			for other in app.traffic.cars:
				if app.city.is_sidewalk(other.position): off_road += 1
	Engine.time_scale = 1
	check(off_road == 0, "One simulated minute of traffic stays on the roads")
	app.traffic.reset()
	await frames(90)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/traffic.png")
	app.show_menu()
	check(not app.traffic.visible, "Returning to menu removes traffic from the preview")
	DirAccess.remove_absolute(app.save_path)
	print("TRAFFIC RESULT: ", failures, " failures")
	quit(1 if failures else 0)
