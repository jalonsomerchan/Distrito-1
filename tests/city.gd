extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss = false
	root.add_child(app)
	app.save_path = "res://tests/.city-save.json"
	await process_frame
	var city = app.city
	var dimensions := {}
	var quantities := {}
	var contained := true
	var no_overlap := true
	var roads_clear := true
	for block in city.blocks:
		dimensions[block.size] = true
	for count in city.block_building_counts:
		quantities[count] = true
	for i in range(city.buildings.size()):
		var building: Rect2 = city.buildings[i]
		var owners := 0
		for block in city.blocks:
			if block.grow(-30).encloses(building): owners += 1
		contained = contained and owners == 1
		for j in range(i):
			no_overlap = no_overlap and not building.intersects(city.buildings[j])
	for road in city.horizontal_roads + city.vertical_roads:
		for block in city.blocks:
			roads_clear = roads_clear and not road.intersects(block)
	check(dimensions.size() >= 15, "Different block widths and lengths")
	check(quantities.has(1) and quantities.has(9) and quantities.size() >= 5, "Blocks range from 1 to 9 buildings with several densities")
	check(contained and no_overlap, "All buildings fit inside one sidewalk, without overlap")
	check(roads_clear, "Road markings/corridors do not cross sidewalks")
	check(city.is_safe_position(app.SPAWN) and not city.is_sidewalk(app.SPAWN), "Spawn is clear and on a road")
	# Flood-fill the actual free street space with a car-sized clearance.
	var step_size := 80.0
	var origin: Vector2 = city.WORLD_BOUNDS.position + Vector2.ONE * step_size / 2
	var free := {}
	for x in range(ceili(city.WORLD_BOUNDS.size.x / step_size)):
		for y in range(ceili(city.WORLD_BOUNDS.size.y / step_size)):
			var point: Vector2 = origin + Vector2(x, y) * step_size
			if city.street_clear(point, 35): free[Vector2i(x, y)] = true
	var start := Vector2i(((app.SPAWN - origin) / step_size).round())
	var reachable := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + step
			if free.has(next) and not reachable.has(next):
				reachable[next] = true
				queue.append(next)
	var connected := reachable.size() == free.size()
	for road in city.horizontal_roads + city.vertical_roads:
		var cell := Vector2i(((road.get_center() - origin) / step_size).round())
		# A long avenue's geometric centre can be on a bridge approach railing.
		# Check a free point in the corridor, then require the entire free street grid.
		var accessible := false
		for dx in range(-2,3):
			for dy in range(-2,3):
				var candidate := cell+Vector2i(dx,dy)
				if road.has_point(origin+Vector2(candidate)*step_size) and reachable.has(candidate): accessible=true
		connected = connected and accessible
	check(connected, "Every avenue and side street is reachable with clearance for the car")
	var data := {"version": 1, "x": 1020.0, "y": 730.0, "angle": 1.0, "distance": 1234.5, "health": 42.0}
	check(not city.is_safe_position(Vector2(data.x, data.y)), "Migration fixture is a road in the old city and a building in the new one")
	write_save(app.save_path, data)
	app.load_game()
	check(app.car.position == app.SPAWN and app.car.health == 42 and app.car.distance_driven == 1234.5, "Old save on a new building moves to avenue while preserving health/progress")
	data.city_version = city.LAYOUT_VERSION
	write_save(app.save_path, data)
	check(app.read_save().is_empty(), "New saves cannot place a car inside a building")
	data.erase("city_version")
	data.x = -50000
	write_save(app.save_path, data)
	check(app.read_save().is_empty(), "Out-of-bounds saves remain invalid")
	DirAccess.remove_absolute(app.save_path)
	if DisplayServer.get_name() != "headless":
		var overview := SubViewport.new()
		overview.size = Vector2i(1024, 1024)
		overview.world_2d = app.get_world_2d()
		overview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(overview)
		var camera := Camera2D.new()
		camera.position = city.WORLD_BOUNDS.get_center()
		camera.zoom = Vector2.ONE * minf(1024.0 / (city.WORLD_BOUNDS.size.x+600), 1024.0 / (city.WORLD_BOUNDS.size.y+600))
		overview.add_child(camera)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		overview.get_texture().get_image().save_png("res://docs/city-overview.png")
		overview.queue_free()
	print("CITY RESULT: ", failures, " failures; ", city.blocks.size(), " blocks; ", city.buildings.size(), " buildings")
	quit(1 if failures else 0)
