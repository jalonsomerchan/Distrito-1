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

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.delivery-save.json"
	app.select_game_mode()
	check(app.mode_menu.visible and not app.playing, "New game offers mode selection before driving")
	await capture("game-modes.png")
	app.start_new_game("delivery")
	await capture("delivery.png")
	var mission: Node2D = app.delivery
	print("NETWORK: ", mission.graph.get_point_count(), " points; ", mission.stops.size(), " connected stops")
	check(mission.stops.size() > 500, "Delivery network covers the city")
	var east := false
	var south := false
	for id in mission.stops:
		var point: Vector2 = mission.graph.get_point_position(id)
		if point.x > 8000: east = true
		if point.y > 9000 and point.x < 6200: south = true
	check(east and south, "Delivery routes cross both rivers using bridges")
	check(mission.phase == "pickup" and mission.remaining > 0 and mission.route.size() > 1, "Courier starts with reachable pickup and calculated deadline")
	check(mission.remaining > mission.path_length(mission.route) / float(app.car.vehicle_data.max_speed), "Deadline includes driving and manoeuvring margin")
	var initial_budget: float = mission.time_budget(3000, 4)
	mission.delivered = 10
	check(mission.time_budget(3000, 4) < initial_budget, "Each delivery tightens deadline for the same route")
	mission.delivered = 0
	var before: float = mission.remaining
	app.paused = true
	app._process(2)
	check(mission.remaining == before, "Pause freezes delivery clock")
	app.resume_game()
	app.car.position = mission.target_position()
	app.car.speed = 120
	mission.tick(0.1)
	check(mission.phase == "pickup", "Player must slow down to collect")
	app.car.speed = 0
	mission.tick(0.1)
	check(mission.phase == "dropoff" and mission.remaining == mission.allowance, "Pickup starts independent delivery deadline")
	mission.tick(1.25)
	var saved_time: float = mission.remaining
	var saved_target: int = mission.target_id
	check(app.save_game(), "Courier progress saves")
	app.show_menu()
	app.load_game()
	check(app.game_mode == "delivery" and mission.phase == "dropoff" and mission.target_id == saved_target and is_equal_approx(mission.remaining, saved_time), "Load restores package, destination and remaining time")
	app.car.position = mission.target_position()
	mission.tick(0.1)
	check(mission.delivered == 1 and mission.phase == "pickup", "Delivery increments difficulty and creates next package")
	# Exercise many jobs to catch empty candidate sets and unreachable targets.
	for i in range(40):
		check(mission.route.size() > 1 and mission.allowance > 0, "Job %d is reachable" % (i + 1))
		app.car.position = mission.target_position()
		mission.tick(0.01)
	check(mission.delivered == 21, "Successive packages progress without immediate recollection")
	mission.remaining = 0.01
	mission.tick(0.02)
	check(mission.phase == "failed" and app.paused and app.result_panel.visible and not app.car.enabled, "Timeout ends courier run with results")
	await capture("delivery-failed.png")
	app.resume_game()
	check(app.paused, "Failed run cannot resume through pause")
	app.show_menu()
	app.load_game()
	check(app.result_panel.visible and mission.phase == "failed", "Loading an expired run preserves game over")
	var invalid: Dictionary = mission.serialize()
	invalid.target = -1
	check(not mission.valid_save(invalid), "Invalid mission target is rejected")
	invalid = mission.serialize()
	invalid.remaining = INF
	check(not mission.valid_save(invalid), "Invalid mission clock is rejected")
	app.start_new_game("free")
	check(mission.phase == "inactive" and not app.mission_panel.visible and not mission.visible, "Free mode has no objectives or timer")
	var legacy: Dictionary = app.read_save()
	legacy.erase("mode")
	var file := FileAccess.open(app.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	app.load_game()
	check(app.game_mode == "free", "Legacy saves load in free mode")
	DirAccess.remove_absolute(app.save_path)
	print("DELIVERY RESULT: ", failures, " failures")
	quit(1 if failures else 0)
