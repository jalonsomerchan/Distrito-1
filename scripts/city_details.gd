extends Node2D

var city: Node2D
var game: Node2D
var data: Dictionary
var signals: Array = []
var clock := 0.0
var signal_sprite: Texture2D

func _ready() -> void:
	z_index = 2
	signal_sprite = load("res://assets/environment/traffic_signal.png")
	for entry in data.signals:
		var point: Vector2 = Vector2(entry.center[0], entry.center[1])
		if city.street_clear(point, 38) and not city.near_roundabout(point): signals.append(entry)
	build_beaches()
	build_roundabouts()
	queue_redraw()

func sprite(texture: Texture2D, at: Vector2, dimensions: Vector2, angle := 0.0) -> void:
	var node := Sprite2D.new()
	node.texture = texture
	node.position = at
	node.scale = dimensions / texture.get_size()
	node.rotation = angle
	node.z_index = 1
	add_child(node)

func build_beaches() -> void:
	var sand: Texture2D = load("res://assets/environment/sand.png")
	var umbrella: Texture2D = load("res://assets/environment/beach_umbrella.png")
	var lounger: Texture2D = load("res://assets/environment/beach_lounger.png")
	var bench: Texture2D = load("res://assets/environment/bench.png")
	for beach in city.beaches:
		city.add_tiled(sand, beach, 2)
		city.add_tiled(city.nature.stone, Rect2(beach.position, Vector2(80, beach.size.y)), 2)
		for y in range(int(beach.position.y + 120), int(beach.end.y - 90), 240):
			var offsets := [230.0]
			if beach.size.x > 800: offsets.append_array([800.0, beach.size.x - 280])
			for offset in offsets:
				var at := Vector2(beach.position.x + float(offset), y)
				if city.wilderness.on_trail(at, -130) or city.wilderness.on_trail(at + Vector2(90, 12), -130): continue
				sprite(umbrella, at, Vector2(100, 100))
				sprite(lounger, at + Vector2(90, 12), Vector2(45, 90), 0.15)
				city.add_collider(Rect2(at - Vector2.ONE * 10, Vector2.ONE * 20))
				city.add_collider(Rect2(at + Vector2(73, -20), Vector2(34, 66)))
			var bench_at := Vector2(beach.position.x + 40, y + 95)
			if not city.wilderness.on_trail(bench_at, -50):
				sprite(bench, bench_at, Vector2(65, 30), PI / 2)
				city.add_collider(Rect2(bench_at - Vector2(13, 31), Vector2(26, 62)))
			var shrub_at := Vector2(beach.position.x + 40, y - 75)
			if (y - int(beach.position.y + 120)) % 480 == 0 and not city.wilderness.on_trail(shrub_at, -90):
				sprite(city.nature.shrub, shrub_at, Vector2(60, 55))

func textured_disc(texture: Texture2D, at: Vector2, radius: float) -> void:
	var polygon := Polygon2D.new()
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for i in range(64):
		var point: Vector2 = Vector2.from_angle(TAU * i / 64) * radius
		points.append(point)
		uv.append((point / (radius * 2) + Vector2.ONE / 2) * texture.get_size())
	polygon.polygon = points
	polygon.uv = uv
	polygon.texture = texture
	polygon.position = at
	add_child(polygon)

func build_roundabouts() -> void:
	for island in city.roundabouts:
		var at := Vector2(island.center[0], island.center[1])
		var radius := float(island.radius)
		textured_disc(city.nature.stone, at, radius)
		textured_disc(city.nature.grass, at, radius - 9)
		sprite(city.nature.shrub, at, Vector2(75, 70))
		var body := StaticBody2D.new()
		body.position = at
		var collision := CollisionShape2D.new()
		collision.shape = CircleShape2D.new()
		collision.shape.radius = radius
		body.add_child(collision)
		add_child(body)

func _process(delta: float) -> void:
	if game != null and game.playing and not game.paused:
		clock = fposmod(clock + delta, 32)
		queue_redraw()

# 12 s green, 2 s amber and 2 s clearance per axis; never two greens.
func light(index: int, axis: int) -> String:
	var time := fposmod(clock + index * 3 - axis * 16, 32)
	return "green" if time < 12 else ("amber" if time < 14 else "red")

func should_stop(at: Vector2, heading: Vector2, speed: float, length: float) -> bool:
	var axis := 0 if absf(heading.y) > absf(heading.x) else 1
	var nose := at + heading * (length / 2)
	for i in range(signals.size()):
		var entry: Dictionary = signals[i]
		var center: Vector2 = Vector2(entry.center[0], entry.center[1])
		var along := (center - nose).dot(heading)
		var lateral := absf((at - center).cross(heading))
		var half_crossing := float(entry.depth if axis == 0 else entry.width) / 2
		var half_width := float(entry.width if axis == 0 else entry.depth) / 2
		var ahead := along - half_crossing - 28
		if lateral > half_width + 15 or ahead < -12 or ahead > 45 + speed * speed / 480: continue
		var state := light(i, axis)
		# Clear the junction rather than braking too late at amber.
		if state == "red" or (state == "amber" and ahead > speed * speed / 700): return true
	return false

func _draw() -> void:
	var paint := Color("eee8d7b0")
	for i in range(signals.size()):
		var entry: Dictionary = signals[i]
		var at := Vector2(entry.center[0], entry.center[1])
		for axis in range(2):
			var along := Vector2.DOWN if axis == 0 else Vector2.RIGHT
			var side := along.orthogonal()
			var half_crossing := float(entry.depth if axis == 0 else entry.width) / 2
			var half_width := float(entry.width if axis == 0 else entry.depth) / 2
			for sign_value in [-1, 1]:
				var approach: Vector2 = at + along * sign_value * (half_crossing + 80)
				if city.is_sidewalk(approach) or city.is_water(approach): continue
				var center: Vector2 = at + along * sign_value * (half_crossing + 12)
				# Native road paint, matching the existing lane markings.
				for stripe in range(int(-half_width + 25), int(half_width - 20), 26):
					var point: Vector2 = center + side * stripe
					if city.is_sidewalk(point) or city.is_water(point): continue
					draw_line(point - along * 12, point + along * 12, paint, 12)
				var stop: Vector2 = at + along * sign_value * (half_crossing + 38)
				draw_line(stop - side * (half_width - 20), stop + side * (half_width - 20), paint, 4)
				var head: Vector2 = at + along * sign_value * (half_crossing + 65) + side * sign_value * (half_width - 14)
				var transform := Transform2D(side.angle(), head)
				draw_set_transform_matrix(transform)
				draw_texture_rect(signal_sprite, Rect2(-14, -32, 28, 64), false)
				var state := light(i, axis)
				for lens in range(3):
					var colors := [Color("f06759"), Color("f4c86b"), Color("7cd59d")]
					var enabled: bool = state == ["red", "amber", "green"][lens]
					draw_circle(Vector2(0, -17 + lens * 17), 5, colors[lens] if enabled else Color("283331"))
				draw_set_transform_matrix(Transform2D.IDENTITY)
	for island in city.roundabouts:
		var at := Vector2(island.center[0], island.center[1])
		var radius := float(island.radius)
		draw_arc(at, radius + 5, 0, TAU, 64, Color("ede3c8"), 3, true)
		for i in range(16):
			var angle := TAU * i / 16
			draw_arc(at, radius + 115, angle, angle + 0.16, 8, Color("d9d5bd9a"), 3, true)
		for angle in [0.0, PI / 2, PI, PI * 1.5]:
			var point: Vector2 = at + Vector2.from_angle(angle) * (radius + 95)
			var direction := Vector2.from_angle(angle - PI / 2)
			draw_line(point - direction * 17, point + direction * 17, paint, 4, true)
			draw_line(point + direction * 17, point + direction * 4 + direction.orthogonal() * 10, paint, 4, true)
