extends Node2D

const LAYOUT_VERSION := 6
const Wilderness = preload("res://scripts/wilderness.gd")
const Details = preload("res://scripts/city_details.gd")
const URBAN_BOUNDS := Rect2(-400, -400, 14800, 13200)
const WORLD_BOUNDS := Rect2(-8400, -8400, 32800, 29200)
const BUILDING_MARGIN := 45.0
const BUILDING_GAP := 60.0
const WALL_THICKNESS := 160.0

var game: Node2D
var city_id := "barcelona"
var profile: Dictionary = {}
var details: Node2D
var wilderness: Node2D
var beach_names: Array[String] = []
var beaches: Array[Rect2] = []
var roundabouts: Array = []
var blocks: Array[Rect2] = []
var block_kinds: Array[String] = []
var block_angles: Array[float] = []
var buildings: Array[Rect2] = []
var block_building_counts: Array[int] = []
var vertical_roads: Array[Rect2] = []
var horizontal_roads: Array[Rect2] = []
var rivers: Array[Rect2] = []
var bridges: Array[Rect2] = []
var bridge_drives: Array[Rect2] = []
var parks: Array[Rect2] = []
var vacant_lots: Array[Rect2] = []
var solid_obstacles: Array[Rect2] = []
var boundary_walls: Array[Rect2] = []
var districts: Array = []
var traffic_blocks: Array[Rect2] = []
var nature: Dictionary = {}

func as_rect(data: Array) -> Rect2:
	return Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3]))

func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cities.json"))
	if game != null: city_id = str(game.selected_city)
	profile = catalog.cities.get(city_id, catalog.cities.barcelona)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/city_layout_%s.json" % city_id))
	var extras: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/city_details_%s.json" % city_id))
	var countryside: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wilderness.json"))
	if profile.get("coastal", true):
		var coast_names: Array = profile.beaches
		for i in range(countryside.beaches.size()):
			var beach: Dictionary = countryside.beaches[i]
			beaches.append(as_rect(beach.rect))
			beach_names.append(str(coast_names[i]) if i < coast_names.size() else beach.name)
	roundabouts = extras.roundabouts
	districts = layout.districts
	for name in ["grass", "dirt", "water", "stone", "tree", "shrub", "rocks", "table", "bridge"]:
		nature[name] = load("res://assets/environment/" + name + ".png")
	for entry in layout.rivers: rivers.append(as_rect(entry.rect))
	for entry in layout.bridges:
		var rect := as_rect(entry.rect)
		bridges.append(rect)
		bridge_drives.append(Rect2(rect.position + Vector2(0,24), rect.size - Vector2(0,48)) if entry.axis == "horizontal" else Rect2(rect.position + Vector2(24,0), rect.size - Vector2(48,0)))
	var pavements: Array[Texture2D] = [load("res://assets/sprites/sidewalk.png")]
	for i in range(2,5): pavements.append(load("res://assets/sprites/sidewalk_%02d.png" % i))
	var rooftops: Array[Texture2D] = []
	for path in profile.buildings: rooftops.append(load("res://" + str(path)))
	# The original centre is preserved; new neighbourhoods occupy both river banks.
	var columns: Array = layout.columns
	var raw_vertical: Array[Rect2] = []
	for side in [[0,6,URBAN_BOUNDS.position.x,6200.0], [6,12,7100.0,URBAN_BOUNDS.end.x]]:
		var previous := float(side[2])
		for index in range(int(side[0]), int(side[1])):
			var column: Dictionary = columns[index]
			raw_vertical.append(Rect2(previous, URBAN_BOUNDS.position.y, float(column.x)-previous, URBAN_BOUNDS.size.y))
			previous = float(column.x) + float(column.width)
		raw_vertical.append(Rect2(previous, URBAN_BOUNDS.position.y, float(side[3])-previous, URBAN_BOUNDS.size.y))
	var raw_horizontal: Array[Rect2] = []
	for column in columns:
		var previous_bottom := URBAN_BOUNDS.position.y
		for entry in column.blocks:
			var rect := Rect2(float(column.x), float(entry.y), float(column.width), float(entry.height))
			raw_horizontal.append(Rect2(rect.position.x, previous_bottom, rect.size.x, rect.position.y-previous_bottom))
			previous_bottom = rect.end.y
			blocks.append(rect)
			block_kinds.append(entry.kind)
			var pavement: Texture2D = pavements[int(entry.get("sidewalk", 0)) % pavements.size()]
			var angle := deg_to_rad(float(entry.get("angle", 0)))
			block_angles.append(angle)
			# The pavement always fills the whole block so every building sits over sidewalk.
			add_sidewalk(pavement, rect)
			if entry.kind == "park":
				parks.append(rect)
				block_building_counts.append(0)
				populate_park(rect, blocks.size()-1, pavement, int(columns.find(column)), int(column.blocks.find(entry)))
			elif entry.kind == "vacant":
				vacant_lots.append(rect)
				block_building_counts.append(0)
				add_tiled(nature.dirt, rect.grow(-25))
			else: populate_block(rect, blocks.size()-1, rooftops)
			var clear := true
			for river in rivers:
				if rect.grow(145).intersects(river): clear = false
			if clear: traffic_blocks.append(rect)
		raw_horizontal.append(Rect2(float(column.x), previous_bottom, float(column.width), URBAN_BOUNDS.end.y-previous_bottom))
	for rect in raw_vertical: vertical_roads.append_array(subtract_all(rect, rivers))
	for rect in raw_horizontal: horizontal_roads.append_array(subtract_all(rect, rivers))
	wilderness = Wilderness.new()
	wilderness.city = self
	wilderness.game = game
	wilderness.data = countryside
	add_child(wilderness)
	build_rivers_and_bridges()
	build_boundary()
	details = Details.new()
	details.city = self
	details.game = game
	details.data = extras
	add_child(details)
	queue_redraw()

func subtract_rect(rect: Rect2, cut: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not rect.intersects(cut): return [rect]
	var overlap := rect.intersection(cut)
	for piece in [Rect2(rect.position,Vector2(rect.size.x,overlap.position.y-rect.position.y)), Rect2(Vector2(rect.position.x,overlap.end.y),Vector2(rect.size.x,rect.end.y-overlap.end.y)), Rect2(Vector2(rect.position.x,overlap.position.y),Vector2(overlap.position.x-rect.position.x,overlap.size.y)), Rect2(Vector2(overlap.end.x,overlap.position.y),Vector2(rect.end.x-overlap.end.x,overlap.size.y))]:
		if piece.size.x > 0.1 and piece.size.y > 0.1: result.append(piece)
	return result

func subtract_all(rect: Rect2, cuts: Array[Rect2]) -> Array[Rect2]:
	var pieces: Array[Rect2] = [rect]
	for cut in cuts:
		var next: Array[Rect2] = []
		for piece in pieces: next.append_array(subtract_rect(piece,cut))
		pieces = next
	return pieces

func add_tiled(texture: Texture2D, rect: Rect2, layer := 0) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	if texture == nature.get("water"): sprite.modulate = Color(str(profile.water))
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO,rect.size)
	sprite.centered = false
	sprite.position = rect.position
	sprite.z_index = layer
	add_child(sprite)

func add_sidewalk(texture: Texture2D, rect: Rect2, angle := 0.0, inset_scale := 1.0) -> void:
	var pavement := NinePatchRect.new()
	pavement.texture = texture
	pavement.size = rect.size * inset_scale
	pavement.position = rect.get_center() - pavement.size / 2
	pavement.pivot_offset = pavement.size / 2
	pavement.rotation = angle
	pavement.patch_margin_left = 36
	pavement.patch_margin_right = 36
	pavement.patch_margin_top = 36
	pavement.patch_margin_bottom = 36
	pavement.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	pavement.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	pavement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pavement)

func populate_park(rect: Rect2, index: int, pavement: Texture2D, grid_column := -1, grid_row := -1) -> void:
	for landmark in profile.landmarks:
		if landmark.block == [grid_column, grid_row]:
			populate_landmark(rect, landmark)
			return
	add_tiled(nature.grass,rect.grow(-25))
	add_sidewalk(pavement,Rect2(rect.position.x+25,rect.get_center().y-26,rect.size.x-50,52))
	add_sidewalk(pavement,Rect2(rect.get_center().x-26,rect.position.y+25,52,rect.size.y-50))
	for x in range(int(rect.position.x+95),int(rect.end.x-70),170):
		for y in range(int(rect.position.y+95),int(rect.end.y-70),175):
			var point := Vector2(x,y)
			if absf(point.x-rect.get_center().x)<95 or absf(point.y-rect.get_center().y)<95: continue
			add_sprite(nature.tree,point,Vector2(140,140),Color.WHITE)
			add_collider(Rect2(point-Vector2.ONE*18,Vector2.ONE*36))
	var table_at := rect.get_center()+Vector2(75,70)
	add_sprite(nature.table,table_at,Vector2(65,55),Color.WHITE)
	add_collider(Rect2(table_at-Vector2(24,18),Vector2(48,36)))
	add_sprite(nature.shrub,rect.position+Vector2(75,rect.size.y-65),Vector2(85,65),Color.WHITE)

func populate_landmark(rect: Rect2, landmark: Dictionary) -> void:
	add_tiled(nature.grass, rect.grow(-25))
	var center := rect.get_center()
	var footpath := Rect2(center - Vector2(18, rect.size.y * 0.34), Vector2(36, rect.size.y * 0.68))
	add_sidewalk(load("res://assets/sprites/sidewalk.png"), footpath)
	var texture: Texture2D = load("res://" + str(landmark.sprite))
	var max_size := rect.size * 0.8
	var asset_scale := minf(max_size.x / texture.get_width(), max_size.y / texture.get_height())
	var footprint := Vector2(texture.get_size()) * asset_scale
	add_sprite(texture, center, footprint, Color.WHITE)
	add_collider(Rect2(center - footprint * 0.32, footprint * 0.64))

func populate_block(rect: Rect2, index: int, textures: Array[Texture2D]) -> void:
	var angle := block_angles[index]
	var work_size := rect.size * (0.78 if angle != 0.0 else 1.0)
	var columns := clampi(roundi((work_size.x-60)/300),1,3)
	var rows := clampi(roundi((work_size.y-60)/300),1,4)
	var slot := (work_size-Vector2.ONE*BUILDING_MARGIN*2-Vector2(columns-1,rows-1)*BUILDING_GAP)/Vector2(columns,rows)
	var footprint := Vector2(minf(slot.x,280),minf(slot.y,300))
	block_building_counts.append(columns*rows)
	for row in range(rows):
		for col in range(columns):
			var local_center := rect.get_center() - work_size / 2 + Vector2.ONE*BUILDING_MARGIN+slot/2+Vector2(col,row)*(slot+Vector2.ONE*BUILDING_GAP)
			var center := rect.get_center() + (local_center - rect.get_center()).rotated(angle)
			var building := Rect2(center-footprint/2,footprint)
			buildings.append(building)
			var tint := Color.from_hsv(0.07+float((index+col)%3)*0.015,0.08+float(row%2)*0.07,0.82+float((index+row)%3)*0.08)
			var texture := textures[(index*7+col*5+row*3)%textures.size()]
			add_sprite(texture,center+Vector2(9,12),footprint+Vector2(10,10),Color(0,0,0,0.25),angle)
			add_sprite(texture,center,footprint,tint,angle)
			add_collider(building, angle)

func build_rivers_and_bridges() -> void:
	# Water is solid except for the exact bridge openings, including at junctions.
	for river in rivers:
		add_tiled(nature.water,river,1)
		var water_cuts: Array[Rect2] = bridges.duplicate()
		water_cuts.append_array(beaches)
		for piece in subtract_all(river,water_cuts): add_collider(piece)
		var banks: Array[Rect2] = []
		if river.size.y > river.size.x:
			banks = [Rect2(river.position-Vector2(25,0),Vector2(25,river.size.y)),Rect2(Vector2(river.end.x,river.position.y),Vector2(25,river.size.y))]
		else:
			banks = [Rect2(river.position-Vector2(0,25),Vector2(river.size.x,25)),Rect2(Vector2(river.position.x,river.end.y),Vector2(river.size.x,25))]
		for bank in banks:
			var cuts: Array[Rect2] = []
			cuts.append_array(bridges)
			cuts.append_array(rivers)
			cuts.append_array(beaches)
			for piece in subtract_all(bank,cuts):
				add_tiled(nature.stone,piece,2)
				add_collider(piece)
	for bridge in bridges:
		var horizontal := bridge.size.x > bridge.size.y
		var image := Sprite2D.new()
		image.texture = nature.bridge
		image.position = bridge.get_center()
		image.rotation = 0 if horizontal else PI/2
		image.scale = (bridge.size if horizontal else Vector2(bridge.size.y,bridge.size.x))/image.texture.get_size()
		image.z_index = 2
		add_child(image)
		if horizontal:
			add_collider(Rect2(bridge.position,Vector2(bridge.size.x,22)))
			add_collider(Rect2(bridge.position+Vector2(0,bridge.size.y-22),Vector2(bridge.size.x,22)))
			horizontal_roads.append(Rect2(bridge.position+Vector2(0,24),bridge.size-Vector2(0,48)))
		else:
			add_collider(Rect2(bridge.position,Vector2(22,bridge.size.y)))
			add_collider(Rect2(bridge.position+Vector2(bridge.size.x-22,0),Vector2(22,bridge.size.y)))
			vertical_roads.append(Rect2(bridge.position+Vector2(24,0),bridge.size-Vector2(48,0)))

func build_boundary() -> void:
	var pos := WORLD_BOUNDS.position
	var end := WORLD_BOUNDS.end
	boundary_walls = [Rect2(pos-Vector2.ONE*WALL_THICKNESS,Vector2(WORLD_BOUNDS.size.x+WALL_THICKNESS*2,WALL_THICKNESS)),Rect2(Vector2(pos.x-WALL_THICKNESS,end.y),Vector2(WORLD_BOUNDS.size.x+WALL_THICKNESS*2,WALL_THICKNESS)),Rect2(Vector2(pos.x-WALL_THICKNESS,pos.y),Vector2(WALL_THICKNESS,WORLD_BOUNDS.size.y)),Rect2(Vector2(end.x,pos.y),Vector2(WALL_THICKNESS,WORLD_BOUNDS.size.y))]
	for wall in boundary_walls:
		add_tiled(nature.stone,wall,3)
		add_collider(wall)
	# Rock outcrops outside the wall make the closed perimeter part of the terrain.
	for x in range(int(pos.x),int(end.x),450):
		add_sprite(nature.rocks,Vector2(x,pos.y-260),Vector2(190,150),Color.WHITE)
		add_sprite(nature.shrub,Vector2(x,end.y+235),Vector2(150,120),Color.WHITE)

func add_sprite(texture: Texture2D, at: Vector2, dimensions: Vector2, tint: Color, angle := 0.0) -> void:
	var image := Sprite2D.new()
	image.texture = texture
	image.position = at
	image.scale = dimensions/texture.get_size()
	image.modulate = tint
	image.rotation = angle
	add_child(image)

func add_collider(rect: Rect2, angle := 0.0) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.rotation = angle
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	solid_obstacles.append(rect)

func is_sidewalk(at: Vector2) -> bool:
	if not URBAN_BOUNDS.has_point(at): return not wilderness.on_trail(at)
	for beach in beaches:
		if beach.has_point(at): return true
	for block in blocks:
		if block.has_point(at): return true
	return false

func is_water(at: Vector2) -> bool:
	if wilderness != null:
		for ocean in wilderness.oceans:
			if ocean.has_point(at): return true
	for beach in beaches:
		if beach.has_point(at): return false
	for bridge in bridge_drives:
		if bridge.has_point(at): return false
	for river in rivers:
		if river.has_point(at): return true
	return false

func is_safe_position(at: Vector2) -> bool:
	if not WORLD_BOUNDS.has_point(at): return false
	if wilderness != null and not wilderness.is_clear(at, 3): return false
	for island in roundabouts:
		if at.distance_to(Vector2(island.center[0], island.center[1])) < float(island.radius) + 3: return false
	for obstacle in solid_obstacles:
		if obstacle.grow(3).has_point(at): return false
	return true

func street_clear(at: Vector2, clearance := 38.0, ignore_roundabouts := false) -> bool:
	if not URBAN_BOUNDS.has_point(at):
		if wilderness == null or not wilderness.on_trail(at, clearance) or not wilderness.is_clear(at, clearance): return false
	if not ignore_roundabouts:
		for island in roundabouts:
			if at.distance_to(Vector2(island.center[0], island.center[1])) < float(island.radius) + clearance: return false
	if not WORLD_BOUNDS.grow(-clearance).has_point(at): return false
	var on_bridge := false
	for bridge in bridge_drives:
		if bridge.grow(-clearance).has_point(at): on_bridge = true
	for river in rivers:
		if river.grow(clearance+25).has_point(at) and not on_bridge: return false
	for block in blocks:
		if block.grow(clearance).has_point(at): return false
	for obstacle in solid_obstacles:
		if obstacle.grow(clearance).has_point(at): return false
	return true

func district_at(at: Vector2) -> String:
	for i in range(beaches.size()):
		if beaches[i].has_point(at): return beach_names[i]
	if wilderness != null:
		var rural: String = wilderness.district_at(at)
		if not rural.is_empty(): return rural
	for bridge in bridges:
		if bridge.has_point(at): return "LOS PUENTES"
	for district in districts:
		if as_rect(district.rect).has_point(at): return str(district.name)
	return "RIBERA"

func _draw() -> void:
	draw_rect(WORLD_BOUNDS.grow(1200),Color(str(profile.ground)))
	draw_rect(URBAN_BOUNDS,Color(str(profile.urban)))
	var paint := Color("e6d8bf72")
	for road in vertical_roads:
		var x := road.get_center().x
		for y in range(int(road.position.y+36),int(road.end.y-36),64):
			if not is_water(Vector2(x,y)) and not near_roundabout(Vector2(x,y)): draw_line(Vector2(x,y),Vector2(x,y+26),paint,3)
	for road in horizontal_roads:
		var y := road.get_center().y
		for x in range(int(road.position.x+70),int(road.end.x-70),64):
			if not is_water(Vector2(x,y)) and not near_roundabout(Vector2(x,y)): draw_line(Vector2(x,y),Vector2(x+26,y),paint,3)

func near_roundabout(at: Vector2) -> bool:
	for island in roundabouts:
		if at.distance_to(Vector2(island.center[0], island.center[1])) < float(island.radius) + 145: return true
	return false

func traffic_should_stop(at: Vector2, heading: Vector2, speed: float, length: float) -> bool:
	return details.should_stop(at, heading, speed, length) if details != null else false
