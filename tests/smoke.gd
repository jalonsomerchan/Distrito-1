extends SceneTree

var failures := 0
var app: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
	else:
		print("PASS: ", message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.smoke-save.json"
	await frames(3)
	app.show_menu()
	await frames(3)
	check(app.menu.visible and not app.car.enabled, "Main menu starts with driving disabled")
	check(app.city.blocks.size() > 140 and app.city.buildings.size() > 350, "Large city with varied blocks and building colliders")
	check(app.load_button.disabled, "No save disables load")
	await capture("menu.png")
	app.start_new_game()
	await frames(3)
	check(app.playing and app.car.enabled and app.hud.visible, "New game enters driving")
	await capture("game.png")
	var initial: Vector2 = app.car.position
	Input.action_press("accelerate")
	await frames(80)
	Input.action_release("accelerate")
	check(app.car.position.distance_to(initial) > 100, "Car accelerates and moves along avenue")
	check(app.car.speed > 0, "Forward speed")
	Input.action_press("steer_right")
	await frames(30)
	Input.action_release("steer_right")
	check(app.car.rotation > 0.1, "Steering rotates a moving car")
	var saved_position: Vector2 = app.car.position
	var saved_angle: float = app.car.rotation
	check(app.save_game(), "Save writes successfully")
	app.show_menu()
	check(not app.load_button.disabled, "Saved game enables load")
	app.load_game()
	check(app.car.position.distance_to(saved_position) < 0.01 and absf(app.car.rotation - saved_angle) < 0.001, "Load restores position and orientation")
	check(app.car.speed == 0, "Load safely stops car")
	Input.action_press("brake")
	await frames(40)
	Input.action_release("brake")
	check(app.car.speed < 0, "Brake becomes reverse at rest")
	app.start_new_game()
	app.car.position = Vector2(0, 165)
	app.car.rotation = PI / 2
	await frames(3)
	Input.action_press("accelerate")
	await frames(100)
	Input.action_release("accelerate")
	check(app.car.position.x < 22, "Building collision prevents driving through roof")
	app.start_new_game()
	var trigger := InputEventJoypadMotion.new()
	trigger.device = 0
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	Input.parse_input_event(trigger)
	await frames(40)
	check(app.car.speed > 40, "Right gamepad trigger accelerates")
	trigger.axis_value = 0
	Input.parse_input_event(trigger)
	var pause_event := InputEventJoypadButton.new()
	pause_event.device = 0
	pause_event.button_index = JOY_BUTTON_START
	pause_event.pressed = true
	Input.parse_input_event(pause_event)
	await frames(3)
	check(app.paused and not app.car.enabled, "Start button opens pause")
	app.save_game()
	await capture("pause.png")
	var parked: Vector2 = app.car.position
	await frames(10)
	check(app.car.position == parked, "Pause freezes vehicle")
	app.resume_game()
	check(app.car.enabled and not app.pause_panel.visible, "Continue resumes driving")
	app.autosave_timer = 31
	await frames(3)
	check(app.autosave_timer < 1, "Autosave runs after 30 seconds")
	var file := FileAccess.open(app.save_path, FileAccess.WRITE)
	file.store_string('{"version":1,"x":"invalid"}')
	file.close()
	check(app.read_save().is_empty(), "Corrupt save rejected safely")
	DirAccess.remove_absolute(app.save_path)
	print("SMOKE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
