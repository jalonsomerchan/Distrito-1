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

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.pursuit-save.json"
	app.select_game_mode()
	await capture("game-modes.png")
	var p: Node2D = app.pursuit
	p.rng.seed = 42
	app.start_new_game("pursuit")
	check(app.game_mode == "pursuit" and app.car.vehicle_id == "police_interceptor", "Pursuit starts with the police interceptor")
	check(p.phase == "active" and p.target.visible and p.path.size() > 1, "A physical fugitive spawns with a street escape route")
	check(p.target.position.distance_to(app.car.position) >= 600, "Fugitive starts with a fair head start")
	await frames(3)
	await capture("pursuit.png")
	var initial: Vector2 = p.target.position
	await frames(120)
	check(p.target.position.distance_to(initial) > 80, "Fugitive drives autonomously")
	var previous_speed: float = p.flee_speed()
	var previous_health: float = p.resistance()
	var previous_hold: float = p.arrest_duration()
	var previous_grace: float = p.escape_grace()
	p.level += 1
	check(p.flee_speed() > previous_speed and p.resistance() > previous_health and p.arrest_duration() > previous_hold and p.escape_grace() < previous_grace, "Every level raises speed, resistance and arrest difficulty")
	p.level = 1
	app.paused = true
	app.car.enabled = false
	var parked: Vector2 = p.target.position
	var arrest: float = p.arrest
	await frames(10)
	check(p.target.position == parked and p.arrest == arrest, "Pause freezes fugitive and arrest progress")
	check(app.save_game(), "Pursuit progress saves")
	var saved: Dictionary = p.serialize()
	check(p.valid_save(saved), "Live pursuit save is valid")
	app.show_menu()
	check(not p.target.visible and p.target.collision_layer == 0, "Menu removes fugitive visuals and collision")
	app.load_game()
	check(p.phase == "active" and p.target.position.distance_to(parked) < 0.01 and p.level == 1 and p.path_index == saved.path_index, "Load restores fugitive, route and difficulty")
	var traffic_clear := true
	for vehicle in app.traffic.cars:
		if vehicle.position.distance_to(p.target.position) < vehicle.body_radius() + 90: traffic_clear = false
	check(traffic_clear, "Loading leaves room for the suspect among redistributed traffic")
	# Exercise autonomous turns without allowing separation to end the test.
	var moved := 0.0
	var safe := true
	for i in range(600):
		var before: Vector2 = p.target.position
		p.lost_time = 0
		await physics_frame
		moved += p.target.position.distance_to(before)
		if not app.city.street_clear(p.target.position, 35): safe = false
	check(moved > 500 and safe, "Fugitive follows streets and turns without crossing water or buildings")
	# A real police collision damages the suspect's vehicle.
	app.car.position = Vector2(765, 1240)
	app.car.rotation = 0
	app.car.restore()
	app.car.enabled = true
	p.target.position = Vector2(765, 1100)
	p.target.rotation = 0
	p.target.speed = 0
	p.target.health = p.target.max_health
	p.target.impact_cooldown = 0
	p.target.set_physics_process(false)
	app.car.speed = 500
	app.car.velocity = Vector2(0, -500)
	Input.action_press("accelerate")
	await frames(25)
	Input.action_release("accelerate")
	check(p.target.health < p.target.max_health, "Physical police impact damages the fugitive")
	app.car.restore()
	app.car.enabled = false
	p.target.position = Vector2(765, 1100)
	app.car.position = Vector2(765, 1210)
	p.target.health = 0
	p.target.speed = 0
	p.arrest = 0
	p.tick(0.5)
	check(p.phase == "active" and p.arrest > 0, "Immobilised fugitive needs a sustained nearby arrest")
	app.car.speed = 80
	p.tick(0.1)
	check(p.arrest == 0, "Driving past the fugitive cannot complete an arrest")
	app.car.speed = 0
	p.tick(p.arrest_duration())
	check(p.phase == "caught", "Stopping beside the immobilised fugitive completes the arrest")
	app.paused = true
	await capture("pursuit-caught.png")
	check(app.save_game(), "Arrest transition saves")
	app.show_menu()
	app.load_game()
	check(p.phase == "caught" and p.transition > 0, "Load preserves completed arrest before next level")
	app.paused = false
	p.tick(3.1)
	p.target.set_physics_process(true)
	check(p.level == 2 and p.phase == "active" and p.target.health > previous_health and app.car.health == app.car.max_health, "Arrest starts harder level and repairs patrol")
	app.car.position = Vector2(765, 1240)
	p.target.position = Vector2(765, 9500)
	p.tick(p.escape_grace() + 0.1)
	check(p.phase == "failed" and app.result_panel.visible and app.paused, "Sustained separation lets fugitive escape and ends run")
	await capture("pursuit-failed.png")
	app.resume_game()
	check(app.paused, "An escaped fugitive cannot resume through pause")
	app.show_menu()
	app.load_game()
	check(p.phase == "failed" and app.result_panel.visible, "Load preserves failed pursuit")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.health = -1
	check(not p.valid_save(invalid), "Invalid target health is rejected")
	invalid = saved.duplicate(true)
	invalid.path = [-1]
	check(not p.valid_save(invalid), "Invalid escape route is rejected")
	app.start_new_game("pursuit")
	app.car.health = 0
	p.tick(0.1)
	check(p.phase == "failed" and p.reason == "PATRULLA DESTROZADA", "Wrecked patrol ends pursuit")
	app.start_new_game("free")
	check(p.phase == "inactive" and not p.target.visible and p.target.collision_layer == 0, "Free mode removes pursuit and suspect collision")
	app.start_new_game("delivery")
	check(p.phase == "inactive" and app.delivery.phase == "pickup", "Courier mode remains independent")
	DirAccess.remove_absolute(app.save_path)
	print("PURSUIT RESULT: ", failures, " failures")
	quit(1 if failures else 0)
