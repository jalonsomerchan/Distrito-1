extends CharacterBody2D

const Catalog = preload("res://scripts/vehicle_catalog.gd")

var vehicle_id := ""
var vehicle_data: Dictionary = {}

var controller: Node2D
var driver_id := 0
var route := PackedVector2Array()
var segment_lengths := PackedFloat32Array()
var route_length := 0.0
var progress := 0.0
var speed := 0.0
var cruise_speed := 0.0
var enabled := false
var travelled := 0.0
var sensor_blocked := false

func _ready() -> void:
	vehicle_data = Catalog.get_vehicle(vehicle_id)
	assert(not vehicle_data.is_empty() and vehicle_data.bots_allowed, "Modelo de tráfico no permitido")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 7
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Catalog.vector(vehicle_data.collision_size)
	collision.shape = rectangle
	add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = load(vehicle_data.sprites[0])
	sprite.scale = Catalog.vector(vehicle_data.draw_size) / sprite.texture.get_size()
	add_child(sprite)
	z_index = 4
	for i in range(route.size()):
		var length := route[i].distance_to(route[(i + 1) % route.size()])
		segment_lengths.append(length)
		route_length += length

func sample(at: float) -> Vector2:
	var remaining := fposmod(at, route_length)
	for i in range(route.size()):
		if remaining <= segment_lengths[i]:
			return route[i].lerp(route[(i + 1) % route.size()], remaining / segment_lengths[i])
		remaining -= segment_lengths[i]
	return route[0]

func body_radius() -> float:
	return Catalog.vector(vehicle_data.collision_size).length() / 2

func direction_at(at: float) -> Vector2:
	return (sample(at + 12) - sample(at)).normalized()

func place(at: float) -> void:
	progress = fposmod(at, route_length)
	position = sample(progress)
	rotation = direction_at(progress).angle() + PI / 2
	speed = 0
	velocity = Vector2.ZERO

func obstacle_ahead() -> bool:
	var forward := direction_at(progress)
	var lookahead := float(vehicle_data.ai.follow_distance) + speed * speed / (2 * minf(float(vehicle_data.braking), float(vehicle_data.ai.braking)))
	var right := forward.orthogonal()
	var half_size := Catalog.vector(vehicle_data.collision_size) / 2
	for offset in [-half_size.x * 0.85, 0.0, half_size.x * 0.85]:
		var start: Vector2 = global_position + right * offset + forward * (half_size.y - 3)
		var query := PhysicsRayQueryParameters2D.create(start, start + forward * lookahead, 7, [get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): return true
	return controller.city.traffic_should_stop(position, forward, speed, half_size.y * 2) or controller.must_yield(self)

func _physics_process(delta: float) -> void:
	if not enabled:
		velocity = Vector2.ZERO
		return
	sensor_blocked = obstacle_ahead()
	var desired_speed := 0.0 if sensor_blocked else minf(cruise_speed, float(vehicle_data.max_speed))
	# Reduce speed around the rounded corners.
	if direction_at(progress).dot(direction_at(progress + float(vehicle_data.ai.corner_lookahead))) < 0.96:
		desired_speed = minf(desired_speed, float(vehicle_data.ai.corner_speed))
	speed = move_toward(speed, desired_speed, minf(float(vehicle_data.braking), float(vehicle_data.ai.braking)) * delta if sensor_blocked else minf(float(vehicle_data.acceleration), float(vehicle_data.ai.acceleration)) * delta)
	var target := sample(progress + speed * delta)
	var motion := target - position
	velocity = motion / delta
	if motion.length_squared() < 0.00001: return
	rotation = lerp_angle(rotation, motion.angle() + PI / 2, minf(delta * float(vehicle_data.grip) * 1.4, 1))
	var collision := move_and_collide(motion)
	if collision:
		var other := collision.get_collider()
		if other == controller.player:
			other.take_impact(maxf(0, -(velocity - other.velocity).dot(collision.get_normal())))
		var moved := collision.get_travel().length()
		progress = fposmod(progress + moved, route_length)
		travelled += moved
		speed = 0
		velocity = Vector2.ZERO
	else:
		progress = fposmod(progress + speed * delta, route_length)
		travelled += motion.length()
