extends CharacterBody2D

const Catalog = preload("res://scripts/vehicle_catalog.gd")
var mission: Node2D
var vehicle_data: Dictionary = Catalog.get_vehicle("sedan_black")
var speed := 0.0
var health := 100.0
var max_health := 100.0
var impact_cooldown := 0.0
var sprite: Sprite2D

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	z_index = 4
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Catalog.vector(vehicle_data.collision_size)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.scale = Catalog.vector(vehicle_data.draw_size) / Vector2(load(vehicle_data.sprites[0]).get_size())
	add_child(sprite)
	update_sprite()

func update_sprite() -> void:
	if sprite == null: return
	var stage := 4 if health <= 0 else mini(3, int((1.0 - health / max_health) * 4))
	sprite.texture = load(vehicle_data.sprites[stage])

func take_pursuit_impact(impact: float) -> void:
	if mission.phase != "active" or impact_cooldown > 0 or impact < 35: return
	health = maxf(0, health - 32 * pow(impact / 300, 1.4))
	impact_cooldown = 0.4
	speed *= 0.35
	update_sprite()

func _physics_process(delta: float) -> void:
	if not mission.is_active():
		velocity = Vector2.ZERO
		return
	impact_cooldown = maxf(0, impact_cooldown - delta)
	if health <= 0:
		speed = 0
		velocity = Vector2.ZERO
		return
	if mission.path_index >= mission.path.size(): mission.plan_escape()
	var waypoint: Vector2 = mission.path[mission.path_index]
	var distance := position.distance_to(waypoint)
	if distance < 8:
		mission.path_index += 1
		if mission.path_index >= mission.path.size(): mission.plan_escape()
		waypoint = mission.path[mission.path_index]
		distance = position.distance_to(waypoint)
	var heading := position.direction_to(waypoint)
	var desired: float = mission.flee_speed()
	if mission.path_index + 1 < mission.path.size():
		var next: Vector2 = (mission.path[mission.path_index + 1] - waypoint).normalized()
		if heading.dot(next) < 0.9 and distance < speed * speed / 600 + 90:
			desired = minf(desired, 125 + 80 * mission.difficulty())
	# Brake for physical traffic and a police roadblock. A stopped car still
	# needs the officer nearby for a sustained arrest, never an automatic win.
	var query := PhysicsRayQueryParameters2D.create(position + heading * 35, position + heading * maxf(36, minf(distance, 70 + speed * speed / 650)), 7, [get_rid()])
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): desired = 0
	speed = move_toward(speed, desired, (500.0 if desired < speed else mission.flee_acceleration()) * delta)
	var motion := heading * minf(distance, speed * delta)
	velocity = heading * speed
	rotation = lerp_angle(rotation, heading.angle() + PI / 2, minf(1, delta * 12))
	var collision := move_and_collide(motion)
	if collision:
		var other = collision.get_collider()
		if other == mission.car:
			var impact := maxf(0, -(velocity - other.velocity).dot(collision.get_normal()))
			take_pursuit_impact(impact)
			other.take_impact(impact)
		speed = 0
		velocity = Vector2.ZERO
