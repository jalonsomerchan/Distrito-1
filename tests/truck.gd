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

func footprint(position: Vector2, rotation: float, dimensions: Vector2) -> PackedVector2Array:
	var half := dimensions / 2
	var corners := PackedVector2Array()
	for point in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		corners.append(position + point.rotated(rotation))
	return corners

func clear_of_blocks(city: Node2D, polygon: PackedVector2Array) -> bool:
	for point in polygon:
		if not city.WORLD_BOUNDS.has_point(point): return false
	for block in city.blocks:
		var rectangle := PackedVector2Array([block.position, Vector2(block.end.x, block.position.y), block.end, Vector2(block.position.x, block.end.y)])
		if not Geometry2D.intersect_polygons(polygon, rectangle).is_empty(): return false
	return true

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.truck-save.json"
	app.traffic.simulate_all = true
	for i in range(Catalog.ids().size()):
		if app.car.vehicle_id == "cargo_truck": break
		app.cycle_car()
	check(app.car.vehicle_id == "cargo_truck" and app.car_button.text.contains("CAMIÓN"), "Truck appears in the vehicle selector")
	app.start_new_game()
	check(app.car.collision_shape.shape.size == Vector2(48, 134), "Truck has its own large physical collision shape")
	check(app.car.sprite.texture.get_size() * app.car.sprite.scale == Vector2(58, 148), "Truck renders at 58 x 148, versus car 36 x 66")
	check(app.car.max_health == 280 and app.car.vehicle_data.max_speed == 360, "Truck uses its health and handling from catalog")
	var seen := {}
	for level in [280.0, 210.0, 140.0, 70.0, 0.0]:
		app.car.health = level
		seen[app.car.sprite.texture.resource_path] = true
	check(seen.size() == 5, "Truck has five distinct sprites from pristine to wrecked")
	app.car.health = 140
	await process_frame
	await process_frame
	check(app.health_label.text == "50%" and app.car.damage_stage() == 2, "Truck damage and HUD use its own health percentage")
	app.car.health = 218.5
	app.save_game()
	app.car.set_vehicle("muscle_red")
	app.load_game()
	check(app.car.vehicle_id == "cargo_truck" and app.car.health == 218.5, "Saving restores truck identity, size and damage")
	var trucks := []
	for driver in app.traffic.cars:
		if driver.vehicle_id == "cargo_truck": trucks.append(driver)
	check(not trucks.is_empty(), "AI traffic actually includes trucks")
	var initial_position: Vector2 = app.car.position
	var nearby_truck = trucks[0]
	app.car.position = nearby_truck.position
	app.traffic.clear_near_player()
	check(nearby_truck.position.distance_to(app.car.position) > nearby_truck.body_radius() + app.car.body_radius() + 80, "Recovery clears large AI vehicles using actual body dimensions")
	app.car.position = initial_position
	var routes_fit := true
	for driver in trucks:
		for at in range(0, int(driver.route_length), 20):
			var polygon := footprint(driver.sample(at), driver.direction_at(at).angle() + PI / 2, Catalog.vector(driver.vehicle_data.collision_size))
			routes_fit = routes_fit and clear_of_blocks(app.city, polygon)
	check(routes_fit, "Full oriented truck footprint fits every turn and road on its AI routes")
	app.car.restore()
	app.car.enabled = false
	Engine.time_scale = 5
	var driving_clear := true
	for frame in range(360):
		await physics_frame
		if frame % 15 == 0:
			for driver in trucks:
				driving_clear = driving_clear and clear_of_blocks(app.city, footprint(driver.position, driver.rotation, Catalog.vector(driver.vehicle_data.collision_size)))
	Engine.time_scale = 1
	check(driving_clear, "Moving trucks do not cut through sidewalks or buildings")
	var moving_trucks := 0
	for driver in trucks:
		if driver.travelled > 150: moving_trucks += 1
	check(moving_trucks == trucks.size(), "Every spawned truck drives autonomously")
	# The long truck must meet a wall with its bumper, not its centre.
	app.traffic.set_physics_process(false)
	app.traffic.set_active(false)
	app.car.restore()
	app.car.position = Vector2(-100, 165)
	app.car.rotation = PI / 2
	app.car.speed = 200
	app.car.velocity = Vector2.RIGHT * 200
	app.car.enabled = true
	await frames(60)
	check(app.car.health < 280 and app.car.position.x <= -21, "Truck collision stops its actual long body and applies damage")
	app.car.position = app.SPAWN
	app.car.rotation = 0
	app.car.restore()
	app.car.health = 190
	app.car.enabled = false
	app.car.camera.position = Vector2.ZERO
	app.car.camera.reset_smoothing()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/truck-game.png")
	DirAccess.remove_absolute(app.save_path)
	print("TRUCK RESULT: ", failures, " failures; ", trucks.size(), " AI trucks")
	quit(1 if failures else 0)
