extends SceneTree

const Catalog = preload("res://scripts/vehicle_catalog.gd")
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

func write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Catalog.DATA_PATH))
	check(Catalog.validate_document(document).is_empty(), "Catalog schema, fields and all vehicle sprites are valid")
	var expected_players := 0
	var expected_bots := 0
	for entry in document.vehicles:
		var definition := Catalog.merge_values(document.defaults, entry)
		if definition.player_allowed: expected_players += 1
		if definition.bots_allowed: expected_bots += 1
	check(Catalog.ids().size() == expected_players and Catalog.ids(true).size() == expected_bots and Catalog.ids().has("cargo_truck"), "Catalog selection adapts to model count and includes truck")
	var filtered := true
	for i in range(300):
		filtered = filtered and Catalog.traffic_id(i) != "classic_green"
	check(filtered, "Weighted traffic selection never uses a bot-forbidden model")
	var sedan := Catalog.get_vehicle("sedan_blue")
	check(sedan.ai.spawn_weight == 4 and sedan.ai.braking == 420, "Nested AI overrides inherit remaining default fields")
	sedan.max_speed = 1
	check(Catalog.get_vehicle("sedan_blue").max_speed == 520, "Callers cannot accidentally mutate the shared catalog")
	var invalid := document.duplicate(true)
	invalid.vehicles[1].id = invalid.vehicles[0].id
	check(not Catalog.validate_document(invalid).is_empty(), "Duplicate IDs rejected")
	invalid = document.duplicate(true)
	invalid.vehicles[0].acceleration = -1
	check(not Catalog.validate_document(invalid).is_empty(), "Invalid statistics rejected")
	invalid = document.duplicate(true)
	invalid.vehicles[0].grip = NAN
	check(not Catalog.validate_document(invalid).is_empty(), "Non-finite statistics rejected")
	invalid = document.duplicate(true)
	invalid.vehicles[0].bots_allowed = "yes"
	check(not Catalog.validate_document(invalid).is_empty(), "Invalid bot permission rejected")
	invalid = document.duplicate(true)
	invalid.vehicles[0].sprites[0] = "res://missing.png"
	check(not Catalog.validate_document(invalid).is_empty(), "Missing artwork rejected")
	invalid = document.duplicate(true)
	invalid.vehicles[0].collision_size = [1000, 1000]
	check(not Catalog.validate_document(invalid).is_empty(), "Collision dimensions larger than sprite rejected")
	invalid = document.duplicate(true)
	for entry in invalid.vehicles: entry.bots_allowed = false
	check(Catalog.validate_document(invalid).is_empty(), "Catalog can intentionally disable all bot models")
	var app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.catalog-save.json"
	app.start_new_game()
	app.traffic.set_physics_process(false)
	app.traffic.set_active(false)
	Engine.time_scale = 6
	var speeds := {}
	for id in ["sedan_blue", "compact_yellow"]:
		app.car.set_vehicle(id)
		app.car.position = app.SPAWN
		app.car.rotation = 0
		Input.action_press("accelerate")
		await frames(20)
		Input.action_release("accelerate")
		speeds[id] = app.car.speed
		check(app.car.speed <= float(app.car.vehicle_data.max_speed), "Model speed cap respected: " + id)
	Engine.time_scale = 1
	check(speeds.compact_yellow > speeds.sedan_blue + 20, "Catalog acceleration changes actual driving behaviour")
	var lateral := {}
	app.car.enabled = false
	for id in ["compact_yellow", "classic_green"]:
		app.car.set_vehicle(id)
		app.car.position = app.SPAWN
		app.car.rotation = 0
		app.car.velocity = Vector2.RIGHT * 100
		app.car.enabled = true
		app.car._physics_process(1.0 / 60)
		app.car.enabled = false
		lateral[id] = app.car.velocity.x
	check(lateral.compact_yellow < lateral.classic_green, "Catalog grip affects lateral slip")
	app.car.set_vehicle("wagon_silver")
	app.car.position = app.SPAWN
	app.car.health = 75
	await process_frame
	await process_frame
	check(app.car.max_health == 150 and app.health_label.text == "50%" and app.car.damage_stage() == 2, "HUD and damage sprites use percentage of model-specific total health")
	app.car.health = 132.5
	check(app.save_game(), "Non-default vehicle and health above 100 save successfully")
	app.car.set_vehicle("muscle_red")
	app.load_game()
	check(app.car.vehicle_id == "wagon_silver" and app.car.health == 132.5 and app.car.max_health == 150, "Load restores vehicle ID, statistics and health together")
	var data: Dictionary = app.read_save()
	data.erase("vehicle_id")
	data.health = 72
	write_save(app.save_path, data)
	app.load_game()
	check(app.car.vehicle_id == Catalog.default_id() and app.car.health == 72, "Old saves without model ID still load")
	data.vehicle_id = "unknown_car"
	write_save(app.save_path, data)
	check(app.read_save().is_empty(), "Unknown saved model IDs rejected safely")
	var ai_valid := true
	for driver in app.traffic.cars:
		ai_valid = ai_valid and driver.vehicle_data.bots_allowed and driver.cruise_speed <= float(driver.vehicle_data.max_speed)
		ai_valid = ai_valid and driver.get_child(0).shape.size == Catalog.vector(driver.vehicle_data.collision_size)
	check(ai_valid, "AI uses catalog eligibility, dimensions and model-specific speeds")
	DirAccess.remove_absolute(app.save_path)
	print("CATALOG RESULT: ", failures, " failures")
	quit(1 if failures else 0)
