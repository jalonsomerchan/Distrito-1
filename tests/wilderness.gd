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

func capture(filename: String, at: Vector2, zoom := 1.0) -> void:
	if DisplayServer.get_name() == "headless": return
	app.car.position = at
	app.car.rotation = 0
	app.car.restore()
	app.car.enabled = false
	app.city.wilderness.refresh(at)
	app.car.camera.position = Vector2.ZERO
	app.car.camera.zoom = Vector2.ONE * zoom
	app.car.camera.reset_smoothing()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.wilderness-save.json"
	app.start_new_game()
	app.car.enabled = false
	app.traffic.set_physics_process(false)
	app.traffic.set_active(false)
	var city: Node2D = app.city
	var wild: Node2D = city.wilderness
	check(city.WORLD_BOUNDS.get_area() >= city.URBAN_BOUNDS.get_area() * 4.8, "World is nearly five times the previous area")
	check(city.blocks.size() == 149 and city.buildings.size() == 473 and city.is_safe_position(app.SPAWN), "Original city and spawn are preserved")
	check(wild.forests.size() == 4 and wild.vegetation.size() > 6000 and wild.trails.size() >= 20, "Four forests have thousands of plants and many dirt roads")
	var beach_area := 0.0
	for beach in city.beaches: beach_area += beach.get_area()
	check(city.beaches.size() == 4 and beach_area > 40000000, "Three new coastal beaches greatly expand usable sand")
	check(city.is_water(Vector2(23000, 0)) and not city.is_safe_position(Vector2(23000, 0)), "Coastal sea remains physically blocked")
	check(city.district_at(Vector2(20000, -5000)) == "PLAYA DEL FARO" and city.district_at(Vector2(-4000, -4000)) == "BOSQUE DEL NORTE", "HUD resolves the new forest and beach names")
	var trails_clear := true
	for trail in wild.trails:
		for i in range(1, trail.points.size()):
			var a := Vector2(trail.points[i-1][0], trail.points[i-1][1])
			var b := Vector2(trail.points[i][0], trail.points[i][1])
			var count := maxi(1, ceili(a.distance_to(b) / 100))
			for j in range(count + 1):
				var point := a.lerp(b, float(j) / count)
				if not city.street_clear(point, 76): trails_clear = false
	check(trails_clear, "Every dirt road fits a full truck without trees or beach furniture blocking it")
	app.delivery.build_routes()
	check(app.delivery.graph.get_point_position(2149).distance_to(Vector2(7580, 3510)) < 0.01, "Original navigation point IDs retain their exact coordinates")
	var connected := true
	for trail in wild.trails:
		var point: Array = trail.points.back()
		var id: int = app.delivery.graph.get_closest_point(Vector2(point[0], point[1]))
		if id not in app.delivery.stops: connected = false
	check(connected, "All forests, coast roads and beach access roads connect to city missions")
	# An ordinary version-4 save retains its stable navigation IDs exactly.
	app.start_new_game("delivery")
	var target: int = app.delivery.target_id
	var saved: Dictionary = app.read_save()
	saved.city_version = 4
	var file := FileAccess.open(app.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	app.load_game()
	check(app.delivery.target_id == target and app.game_mode == "delivery", "Existing mission save loads with identical destination IDs")
	app.start_new_game()
	app.car.enabled = false
	app.traffic.set_active(false)
	# Streamed physics uses the same indexed blockers as save validation.
	var tree: Array = []
	for entry in wild.vegetation:
		if entry[2] == "tree": tree = entry; break
	var tree_at: Vector2 = wild.plant_position(tree)
	check(not city.is_safe_position(tree_at), "Tree trunks reject unsafe saved positions even when unloaded")
	app.car.position = tree_at + Vector2(0, 170)
	app.car.rotation = 0
	app.car.restore()
	wild.refresh(app.car.position)
	app.car.speed = 400
	app.car.velocity = Vector2(0, -400)
	app.car.enabled = true
	Input.action_press("accelerate")
	await frames(45)
	Input.action_release("accelerate")
	check(app.car.health < app.car.max_health and app.car.position.distance_to(tree_at) > 30, "Streamed tree trunks physically stop and damage the car")
	app.car.enabled = false
	wild.refresh(Vector2(-4000, -4000))
	var before_chunks: Array = wild.loaded_chunks.keys()
	wild.refresh(Vector2(17000, 14000))
	var old_unloaded := true
	for key in before_chunks:
		if wild.loaded_chunks.has(key): old_unloaded = false
	check(old_unloaded and wild.loaded_chunks.size() <= 25, "Distant vegetation unloads and nearby streaming stays bounded")
	# Save/load in a distant forest path refreshes collision and camera bounds.
	app.car.position = Vector2(19400, 9000)
	app.car.restore()
	check(app.save_game(), "Faraway rural positions save normally")
	app.show_menu()
	app.load_game()
	check(app.car.position == Vector2(19400, 9000) and wild.current_chunk == wild.cell(app.car.position, wild.CHUNK_SIZE), "Loading a distant road restores position and nearby collision")
	app.car.enabled = false
	app.traffic.set_active(false)
	await capture("world-forest.png", Vector2(900, -3400), 0.85)
	await capture("world-west-trail.png", Vector2(-3500, 2000), 0.85)
	await capture("world-coast.png", Vector2(21100, -4500), 0.8)
	await capture("world-big-beach.png", Vector2(20080, -3400), 0.8)
	DirAccess.remove_absolute(app.save_path)
	print("WILDERNESS RESULT: ", failures, " failures; ", wild.vegetation.size(), " plants; ", app.delivery.graph.get_point_count(), " navigation nodes")
	quit(1 if failures else 0)
