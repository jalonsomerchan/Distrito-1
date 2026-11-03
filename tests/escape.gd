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
	app.save_path = "res://tests/.escape-save.json"
	app.select_game_mode()
	await capture("game-modes.png")
	app.car.set_vehicle("police_interceptor")
	app.start_new_game("escape")
	var e: Node2D = app.escape
	check(app.game_mode == "escape" and app.car.vehicle_data.category != "police", "Escape gives the player a civilian car")
	check(e.patrols.size() == 2 and e.phase == "active", "Two physical police cars start pursuit")
	var separated := true
	for patrol in e.patrols:
		if patrol.position.distance_to(app.car.position) < 450 or patrol.collision_layer != 4 or patrol.collision_mask != 7: separated = false
	check(separated, "Police spawn with a head start and physical collisions")
	await frames(3)
	await capture("escape.png")
	var first: Vector2 = e.patrols[0].position
	var second: Vector2 = e.patrols[1].position
	await frames(120)
	check(e.patrols[0].position.distance_to(first) + e.patrols[1].position.distance_to(second) > 80, "Police drive autonomously towards the player")
	app.paused = true
	app.car.enabled = false
	var parked: Vector2 = e.patrols[0].position
	var elapsed: float = e.escape_time
	await frames(10)
	check(e.patrols[0].position == parked and e.escape_time == elapsed, "Pause freezes police and escape progress")
	check(app.save_game() and e.valid_save(e.serialize()), "Escape state saves and validates")
	var saved: Dictionary = e.serialize()
	app.show_menu()
	check(not e.patrols[0].visible and e.patrols[0].collision_layer == 0, "Menu hides police and removes collision")
	app.load_game()
	check(e.phase == "active" and e.patrols.size() == 2 and e.patrols[0].position.distance_to(parked) < 0.01, "Load restores each patrol and the escape level")
	var traffic_clear := true
	for patrol in e.patrols:
		for vehicle in app.traffic.cars:
			if vehicle.position.distance_to(patrol.position) < vehicle.body_radius() + 90: traffic_clear = false
	check(traffic_clear, "Loading keeps redistributed traffic clear of every patrol")
	# Freeze AI to isolate the rules for distance, arrest and completed levels.
	for patrol in e.patrols: patrol.set_physics_process(false)
	app.car.enabled = false
	app.car.position = Vector2(765, 1240)
	app.car.speed = 0
	for i in range(e.patrols.size()):
		e.patrols[i].position = Vector2(765, 4500 + i * 500)
		e.patrols[i].speed = 0
	e.tick(1.0)
	check(e.escape_time == 1.0 and e.phase == "active", "Losing every patrol starts a sustained escape countdown")
	e.patrols[0].position = Vector2(765, 1800)
	e.tick(0.1)
	check(e.escape_time == 0, "One returning patrol resets escape progress")
	e.patrols[0].position = Vector2(765, 1350)
	e.tick(0.5)
	check(e.arrest > 0 and e.phase == "active", "Police must hold a stopped player before arrest")
	app.car.speed = 100
	e.tick(0.1)
	check(e.arrest == 0, "Breaking out of a police stop resets arrest")
	app.car.speed = 0
	e.patrols[0].health = 0
	e.tick(0.5)
	check(e.arrest == 0, "Wrecked police cannot arrest the player")
	e.patrols[0].health = e.police_health()
	# A real collision must still damage both cars.
	app.car.position = Vector2(765, 1240)
	app.car.rotation = 0
	app.car.restore()
	app.car.enabled = true
	e.patrols[0].position = Vector2(765, 1100)
	e.patrols[0].rotation = 0
	e.patrols[0].impact_cooldown = 0
	app.car.speed = 500
	app.car.velocity = Vector2(0, -500)
	Input.action_press("accelerate")
	await frames(25)
	Input.action_release("accelerate")
	check(e.patrols[0].health < e.police_health() and app.car.health < app.car.max_health, "Ramming police causes physical damage to both vehicles")
	app.car.restore()
	app.car.enabled = false
	app.car.position = Vector2(765, 1240)
	for i in range(e.patrols.size()): e.patrols[i].position = Vector2(765, 4500 + i * 500)
	e.tick(e.escape_duration())
	check(e.phase == "escaped" and not e.patrols[0].visible and e.patrols[0].collision_layer == 0, "Successful escape clears police and completes level")
	app.paused = true
	await capture("escape-success.png")
	check(app.save_game(), "Successful escape transition saves")
	app.show_menu()
	app.load_game()
	check(e.phase == "escaped" and e.transition > 0, "Load preserves successful escape before next level")
	var old_speed: float = e.police_speed()
	var old_health: float = e.police_health()
	var old_arrest: float = e.arrest_duration()
	var old_escape: float = e.escape_duration()
	e.tick(3.1)
	check(e.level == 2 and e.phase == "active" and e.police_speed() > old_speed and e.police_health() > old_health and e.arrest_duration() < old_arrest and e.escape_duration() > old_escape, "Next level has faster, tougher police and harder escape")
	e.level = 3
	e.start_level()
	check(e.patrols.size() == 3, "Higher levels add police reinforcements")
	# Repairing must not grant escape by teleporting away from existing police.
	var repair := InputEventKey.new()
	repair.physical_keycode = KEY_R
	repair.pressed = true
	e.escape_time = 3
	app._input(repair)
	check(e.phase == "active" and e.escape_time == 0 and e.nearest_distance() < e.escape_distance(), "Repair restarts current level instead of granting free escape")
	for patrol in e.patrols: patrol.set_physics_process(false)
	app.car.enabled = false
	app.car.position = Vector2(765, 1240)
	app.car.speed = 0
	e.patrols[0].position = Vector2(765, 1350)
	e.patrols[0].speed = 0
	e.tick(e.arrest_duration())
	check(e.phase == "failed" and app.paused and app.result_panel.visible, "Police arrest ends escape run")
	await capture("escape-failed.png")
	app.resume_game()
	check(app.paused, "Failed escape cannot resume through pause")
	app.show_menu()
	app.load_game()
	check(e.phase == "failed" and app.result_panel.visible, "Load preserves arrest and failed run")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.patrols[0].x = INF
	check(not e.valid_save(invalid), "Invalid patrol coordinates are rejected")
	invalid = saved.duplicate(true)
	invalid.patrols.clear()
	check(not e.valid_save(invalid), "Missing police fleet is rejected")
	# End-to-end: real police must find and arrest a stationary player, including
	# replanning after the player changes streets, without test-driven arrests.
	app.start_new_game("escape")
	app.car.enabled = false
	app.traffic.set_physics_process(false)
	app.traffic.set_active(false)
	for i in range(e.patrols.size()):
		e.patrols[i].position = Vector2(765, 1900 + i * 500)
		e.patrols[i].replan_timer = 0
	var stayed_safe := true
	for i in range(1200):
		if i == 100: app.car.position = Vector2(765, 600)
		await physics_frame
		for patrol in e.patrols:
			if not app.city.is_safe_position(patrol.position): stayed_safe = false
		if e.phase == "failed": break
	check(stayed_safe and e.phase == "failed" and e.reason == "TE HAN DETENIDO", "Police replan towards moving player and physically complete an arrest")
	app.traffic.set_physics_process(true)
	app.start_new_game("escape")
	app.car.health = 0
	e.tick(0.1)
	check(e.phase == "failed" and e.reason == "COCHE DESTROZADO", "Wrecked getaway car ends run")
	app.start_new_game("free")
	check(e.phase == "inactive" and e.patrols.is_empty(), "Free mode removes all escape police")
	app.start_new_game("pursuit")
	check(e.patrols.is_empty() and app.pursuit.phase == "active", "Pursuit mode remains independent")
	DirAccess.remove_absolute(app.save_path)
	print("ESCAPE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
