extends SceneTree

var failures := 0
var app: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func wall_impact(incoming_speed: float) -> float:
	app.car.restore()
	app.car.position = Vector2(5, 165)
	app.car.rotation = PI / 2
	app.car.speed = incoming_speed
	app.car.velocity = Vector2.RIGHT * incoming_speed
	await frames(20)
	return 100.0 - app.car.health

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(app.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.damage-save.json"
	app.start_new_game()
	await frames(3)
	check(app.car.health == 100 and app.health_label.text == "100%", "New game starts with full health in HUD")
	var catalog = preload("res://scripts/vehicle_catalog.gd")
	var all_states := true
	for id in catalog.ids():
		all_states = all_states and catalog.get_vehicle(id).sprites.size() == 5
	check(not catalog.ids().is_empty() and all_states, "Every catalog vehicle has five damage states")
	var health_levels := [100.0, 75.0, 50.0, 25.0, 0.0]
	var previous_texture: Texture2D
	for stage in range(5):
		app.car.health = health_levels[stage]
		check(app.car.damage_stage() == stage, "Correct sprite at health %s" % health_levels[stage])
		check(app.car.sprite.texture != previous_texture, "Stage %d uses a distinct texture" % stage)
		previous_texture = app.car.sprite.texture
	app.car.restore()
	check(app.car.take_impact(20) == 0 and app.car.health == 100, "Very gentle contact causes no damage")
	var damage: float = app.car.take_impact(350)
	check(damage > 0 and app.car.take_impact(350) == 0, "One impact cannot damage repeatedly in the same contact window")
	var low_damage: float = await wall_impact(120)
	var high_damage: float = await wall_impact(560)
	check(low_damage > 0 and high_damage > low_damage * 3, "Real fast wall impact does more damage than slow impact")
	print("Measured collision damage: slow=", low_damage, ", fast=", high_damage)
	var health_before: float = app.car.health
	Input.action_press("accelerate")
	await frames(90)
	Input.action_release("accelerate")
	check(is_equal_approx(app.car.health, health_before), "Holding accelerator against wall does not apply damage every frame")
	app.car.restore()
	for i in range(6):
		app.car.impact_cooldown = 0
		app.car.take_impact(400)
	check(app.car.health == 0 and app.car.damage_stage() == 4, "Repeated crashes eventually wreck vehicle with health clamped to zero")
	var wreck_position: Vector2 = app.car.position
	Input.action_press("accelerate")
	await frames(20)
	Input.action_release("accelerate")
	check(app.car.position == wreck_position and app.car.speed == 0, "Wreck cannot drive")
	app.car.position = app.SPAWN
	app.car.rotation = 0
	app.car.camera.position = Vector2.ZERO
	app.car.camera.reset_smoothing()
	check(app.save_game(), "Destroyed car can be saved")
	app.car.restore()
	app.load_game()
	await frames(2)
	check(app.car.health == 0 and app.car.damage_stage() == 4, "Loading preserves destroyed health and sprite")
	await capture("car-destroyed.png")
	var reset_event := InputEventKey.new()
	reset_event.physical_keycode = KEY_R
	reset_event.pressed = true
	Input.parse_input_event(reset_event)
	await frames(2)
	check(app.car.health == 100 and app.car.position == app.SPAWN, "R recovers vehicle and repairs it")
	app.car.health = 23.5
	app.save_game()
	app.car.restore()
	app.load_game()
	await frames(2)
	check(app.car.health == 23.5 and app.car.damage_stage() == 3, "Partial health persists exactly across save/load")
	# Multiple physics steps can run before a rendered frame; wait for the HUD update.
	await process_frame
	await process_frame
	check(app.health_label.text == "24%" and is_equal_approx(app.health_bar.value, 23.5), "HUD shows remaining health and bar")
	await capture("car-damaged.png")
	var data: Dictionary = app.read_save()
	data.erase("health")
	write_save(data)
	app.load_game()
	check(app.car.health == 100, "Legacy saves without health remain compatible")
	for invalid in [-1, 101, "broken"]:
		data["health"] = invalid
		write_save(data)
		check(app.read_save().is_empty(), "Invalid health rejected: %s" % invalid)
	DirAccess.remove_absolute(app.save_path)
	print("DAMAGE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
