extends Node2D

const CHUNK_SIZE := 1024.0
const LOOKUP_SIZE := 256.0
const LOAD_RADIUS := 2
var city: Node2D
var game: Node2D
var data: Dictionary
var forests: Array = []
var trails: Array = []
var oceans: Array[Rect2] = []
var vegetation: Array = []
var segments: Array = []
var trail_index := {}
var plant_index := {}
var chunk_plants := {}
var loaded_chunks := {}
var current_chunk := Vector2i(999999, 999999)

func _ready() -> void:
	forests = data.forests
	trails = data.trails
	vegetation = data.vegetation
	for ocean in data.oceans:
		var rect: Rect2 = city.as_rect(ocean.rect)
		oceans.append(rect)
		city.add_tiled(city.nature.water, rect, 1)
		city.add_collider(rect)
	build_indices()
	build_ground()

func cell(at: Vector2, step: float) -> Vector2i:
	return Vector2i(floori(at.x / step), floori(at.y / step))

func plant_position(entry: Array) -> Vector2:
	return Vector2(entry[0], entry[1])

func plant_radius(entry: Array) -> float:
	return float(entry[3]) * (0.13 if entry[2] == "tree" else 0.22) if entry[2] != "shrub" else 0.0

func build_indices() -> void:
	for trail in trails:
		for i in range(1, trail.points.size()):
			var a := Vector2(trail.points[i-1][0], trail.points[i-1][1])
			var b := Vector2(trail.points[i][0], trail.points[i][1])
			var index := segments.size()
			segments.append([a, b, float(trail.width) / 2])
			var rect := Rect2(a, Vector2.ZERO).expand(b).grow(float(trail.width) / 2)
			var first := cell(rect.position, CHUNK_SIZE)
			var last := cell(rect.end, CHUNK_SIZE)
			for x in range(first.x, last.x + 1):
				for y in range(first.y, last.y + 1):
					var key := Vector2i(x, y)
					if not trail_index.has(key): trail_index[key] = []
					trail_index[key].append(index)
	for i in range(vegetation.size()):
		var at := plant_position(vegetation[i])
		var lookup := cell(at, LOOKUP_SIZE)
		if not plant_index.has(lookup): plant_index[lookup] = []
		plant_index[lookup].append(i)
		var key := cell(at, CHUNK_SIZE)
		if not chunk_plants.has(key): chunk_plants[key] = []
		chunk_plants[key].append(i)

func on_trail(at: Vector2, clearance := 0.0) -> bool:
	var origin := cell(at, CHUNK_SIZE)
	var candidates: Array = trail_index.get(origin, [])
	if clearance < 0:
		var unique := {}
		for x in range(-1, 2):
			for y in range(-1, 2):
				for index in trail_index.get(origin + Vector2i(x, y), []): unique[index] = true
		candidates = unique.keys()
	for index in candidates:
		var segment: Array = segments[index]
		var nearest := Geometry2D.get_closest_point_to_segment(at, segment[0], segment[1])
		if at.distance_to(nearest) <= float(segment[2]) - clearance: return true
	return false

func is_clear(at: Vector2, clearance := 0.0) -> bool:
	var origin := cell(at, LOOKUP_SIZE)
	var reach := maxi(1, ceili((clearance + 40) / LOOKUP_SIZE))
	for x in range(-reach, reach + 1):
		for y in range(-reach, reach + 1):
			for index in plant_index.get(origin + Vector2i(x, y), []):
				var entry: Array = vegetation[index]
				var radius := plant_radius(entry)
				if radius > 0 and at.distance_to(plant_position(entry)) < radius + clearance: return false
	return true

func build_ground() -> void:
	# Assemble existing generated terrain outside the original urban rectangle.
	for rect in city.subtract_rect(city.WORLD_BOUNDS, city.URBAN_BOUNDS):
		city.add_tiled(city.nature.grass, rect)
	for trail in trails:
		var points := PackedVector2Array()
		for point in trail.points: points.append(Vector2(point[0], point[1]))
		# World-space UVs keep the existing dirt texture continuous at bends.
		for outline in Geometry2D.offset_polyline(points, float(trail.width) / 2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			var ground := Polygon2D.new()
			ground.polygon = outline
			ground.uv = outline
			ground.texture = city.nature.dirt
			ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
			ground.z_index = 3
			add_child(ground)

func refresh(at: Vector2) -> void:
	var center := cell(at, CHUNK_SIZE)
	if center == current_chunk: return
	current_chunk = center
	var wanted := {}
	for x in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for y in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := center + Vector2i(x, y)
			if not chunk_plants.has(key): continue
			wanted[key] = true
			if not loaded_chunks.has(key): load_chunk(key)
	for key in loaded_chunks.keys():
		if wanted.has(key): continue
		var node: Node2D = loaded_chunks[key]
		remove_child(node)
		node.queue_free()
		loaded_chunks.erase(key)

func load_chunk(key: Vector2i) -> void:
	var chunk := Node2D.new()
	chunk.position = Vector2(key) * CHUNK_SIZE
	chunk.z_index = 3
	var body := StaticBody2D.new()
	chunk.add_child(body)
	var groups := {"tree": [], "shrub": [], "rocks": []}
	for index in chunk_plants[key]: groups[vegetation[index][2]].append(index)
	for kind in groups:
		var entries: Array = groups[kind]
		if entries.is_empty(): continue
		var batch := MultiMeshInstance2D.new()
		batch.texture = city.nature[kind]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_2D
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		multi.mesh = quad
		multi.instance_count = entries.size()
		for i in range(entries.size()):
			var entry: Array = vegetation[entries[i]]
			var point := plant_position(entry) - chunk.position
			var transform := Transform2D(float(entry[4]), point)
			transform.x *= float(entry[3])
			transform.y *= float(entry[3])
			multi.set_instance_transform_2d(i, transform)
			var radius := plant_radius(entry)
			if radius > 0:
				var collision := CollisionShape2D.new()
				collision.shape = CircleShape2D.new()
				collision.shape.radius = radius
				collision.position = point
				body.add_child(collision)
		batch.multimesh = multi
		chunk.add_child(batch)
	add_child(chunk)
	loaded_chunks[key] = chunk

func _process(_delta: float) -> void:
	if game != null and game.car != null: refresh(game.car.position)

func district_at(at: Vector2) -> String:
	for beach in data.beaches:
		if city.as_rect(beach.rect).has_point(at): return beach.name
	for forest in forests:
		if city.as_rect(forest.rect).has_point(at): return forest.name
	return "CAMPIÑA" if not city.URBAN_BOUNDS.has_point(at) else ""
