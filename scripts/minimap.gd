extends Control

var car: CharacterBody2D
var city: Node2D
var traffic: Node2D
var delivery: Node2D
var pursuit: Node2D
var escape: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	var bounds: Rect2 = city.WORLD_BOUNDS
	var factor := minf((size.x - 24) / bounds.size.x, (size.y - 24) / bounds.size.y)
	var offset := (size-bounds.size*factor)/2 - bounds.position*factor
	draw_rect(Rect2(offset + bounds.position * factor, bounds.size * factor), Color("59764d"))
	draw_rect(Rect2(offset + city.URBAN_BOUNDS.position * factor, city.URBAN_BOUNDS.size * factor), Color("293238"))
	for forest in city.wilderness.forests:
		var rect: Rect2 = city.as_rect(forest.rect)
		draw_rect(Rect2(offset + rect.position * factor, rect.size * factor), Color("3d6749"))
	for ocean in city.wilderness.oceans:
		draw_rect(Rect2(offset + ocean.position * factor, ocean.size * factor), Color("287a87"))
	for i in range(city.blocks.size()):
		var block: Rect2 = city.blocks[i]
		var kind: String = city.block_kinds[i]
		var color := Color("4c8456") if kind == "park" else (Color("967c54") if kind == "vacant" else Color("65766f"))
		var angle: float = city.block_angles[i]
		if angle == 0.0 or kind != "buildings":
			draw_rect(Rect2(offset+block.position*factor,block.size*factor),color)
		else:
			var center := offset + block.get_center() * factor
			var half := block.size * factor * 0.39
			var corners := PackedVector2Array()
			for corner in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
				corners.append(center + corner.rotated(angle))
			draw_colored_polygon(corners,color)
	for river in city.rivers:
		draw_rect(Rect2(offset+river.position*factor,river.size*factor),Color("287a87"))
	for beach in city.beaches:
		draw_rect(Rect2(offset + beach.position * factor, beach.size * factor), Color("d8c18c"))
	for trail in city.wilderness.trails:
		for i in range(1, trail.points.size()):
			var a := Vector2(trail.points[i-1][0], trail.points[i-1][1])
			var b := Vector2(trail.points[i][0], trail.points[i][1])
			draw_line(offset + a * factor, offset + b * factor, Color("b59b6b"), 1.2, true)
	for island in city.roundabouts:
		var at := Vector2(island.center[0], island.center[1])
		draw_circle(offset + at * factor, 3, Color("92bc7a"))
	for bridge in city.bridges:
		draw_rect(Rect2(offset+bridge.position*factor,bridge.size*factor),Color("c7bd9f"))
	draw_rect(Rect2(offset+bounds.position*factor,bounds.size*factor),Color("a6aaa0"),false,2)
	if traffic != null and traffic.visible:
		for vehicle in traffic.cars:
			if vehicle.enabled: draw_circle(offset + vehicle.position * factor, 1.3, Color("c1cdc1"))
	if delivery != null and delivery.visible and delivery.phase in ["pickup", "dropoff"]:
		var color: Color = delivery.PICKUP_COLOR if delivery.phase == "pickup" else delivery.DROPOFF_COLOR
		for i in range(1, delivery.route.size()):
			draw_line(offset + delivery.route[i - 1] * factor, offset + delivery.route[i] * factor, Color(color, 0.65), 2, true)
		var target: Vector2 = offset + delivery.target_position() * factor
		draw_circle(target, 6, color)
		draw_arc(target, 9, 0, TAU, 24, color, 2, true)
	if pursuit != null and pursuit.visible and pursuit.phase in ["active", "caught"]:
		var target: Vector2 = offset + pursuit.target.position * factor
		draw_circle(target, 5, pursuit.COLOR)
		draw_arc(target, 9, 0, TAU, 24, pursuit.COLOR, 2, true)
	if escape != null and escape.visible and escape.phase == "active":
		for patrol in escape.patrols:
			if patrol.health <= 0: continue
			var at: Vector2 = offset + patrol.position * factor
			draw_circle(at, 4, escape.COLOR)
			draw_arc(at, 7, 0, TAU, 20, escape.COLOR, 1.5, true)
	var point: Vector2 = offset + car.position * factor
	draw_circle(point, 5, Color("f3a263"))
	draw_line(point, point + Vector2.UP.rotated(car.rotation) * 14, Color("fff1da"), 3, true)

func _panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("18252a")
	box.border_color = Color("526058")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	return box
