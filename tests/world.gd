extends SceneTree

var failures := 0
var app: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool,message: String) -> void:
	if condition: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless": return
	app.car.camera.reset_smoothing()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+filename)

func pose(at: Vector2, heading: float, speed: float) -> void:
	app.car.position=at
	app.car.rotation=heading
	app.car.restore()
	app.car.speed=speed
	app.car.velocity=Vector2.UP.rotated(heading)*speed
	app.car.enabled=true
	app.car.camera.position=Vector2.ZERO
	app.car.camera.reset_smoothing()

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	app.pause_on_focus_loss=false
	root.add_child(app)
	app.save_path="res://tests/.world-save.json"
	app.start_new_game()
	app.traffic.set_physics_process(false)
	app.traffic.set_active(false)
	var city=app.city
	check(city.WORLD_BOUNDS.get_area()>4900.0*4900.0*8, "World is over eight times the original area")
	check(city.parks.size()>=20 and city.vacant_lots.size()>=20 and city.rivers.size()==2 and city.bridges.size()==5, "Parks, empty lots, connected river channels and five bridges exist")
	check(city.boundary_walls.size()==4,"Continuous physical perimeter closes all four sides")
	var safe_water := true
	for river in city.rivers:
		var point: Vector2=river.position+Vector2(100,500)
		if river.size.x>river.size.y: point=river.position+Vector2(2300,200)
		safe_water=safe_water and not city.is_safe_position(point)
	check(safe_water,"Water cannot be loaded as a valid vehicle position")
	var bounds: Rect2=city.WORLD_BOUNDS
	var cases=[
		[Vector2(bounds.position.x+130,500),-PI/2],
		[Vector2(21470,500),PI/2],
		[Vector2(765,bounds.position.y+130),0.0],
		[Vector2(765,bounds.end.y-130),PI]]
	for index in range(cases.size()):
		pose(cases[index][0],cases[index][1],610)
		await frames(45)
		check(bounds.has_point(app.car.position) and app.car.health<100,"High-speed crash cannot cross perimeter side %d" % index)
	pose(Vector2(6010,3000),PI/2,610)
	await frames(45)
	check(app.car.position.x<6175 and not city.is_water(app.car.position),"Riverbank physically stops a car outside a bridge")
	app.car.set_vehicle("cargo_truck")
	Engine.time_scale=4
	for index in range(city.bridges.size()):
		var bridge: Rect2=city.bridges[index]
		var horizontal:=bridge.size.x>bridge.size.y
		var start:=Vector2(bridge.position.x-100,bridge.get_center().y) if horizontal else Vector2(bridge.get_center().x,bridge.position.y-100)
		pose(start,PI/2 if horizontal else PI,300)
		Input.action_press("accelerate")
		var crossed:=false
		for frame in range(180):
			await physics_frame
			if (app.car.position.x>bridge.end.x+80 if horizontal else app.car.position.y>bridge.end.y+80):
				crossed=true
				break
		Input.action_release("accelerate")
		check(crossed,"Full-size truck can drive across bridge %d" % index)
	Engine.time_scale=1
	pose(city.bridges[0].get_center(),PI/2,0)
	app.car.enabled=false
	await capture("river-bridge.png")
	pose(city.parks[0].get_center(),0,0)
	app.car.enabled=false
	await capture("city-park.png")
	pose(city.vacant_lots[0].get_center(),0,0)
	app.car.enabled=false
	await capture("city-vacant.png")
	pose(Vector2(-270,500),0,0)
	app.car.enabled=false
	await capture("city-boundary.png")
	# In normal play, remote traffic is dormant instead of simulating the whole map.
	app.traffic.set_physics_process(true)
	app.traffic.set_active(true)
	await frames(2)
	var active:=0
	for driver in app.traffic.cars:
		if driver.enabled: active+=1
	check(active>0 and active<app.traffic.cars.size(),"Only nearby traffic is simulated during normal play")
	DirAccess.remove_absolute(app.save_path)
	print("WORLD RESULT: ",failures," failures; ",city.blocks.size()," blocks; ",city.buildings.size()," buildings; ",city.parks.size()," parks; ",city.vacant_lots.size()," vacant lots")
	quit(1 if failures else 0)
