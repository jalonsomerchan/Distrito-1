extends "res://scripts/fugitive.gd"

var path := PackedVector2Array()
var path_index := 0
var replan_timer := 0.0

func _ready() -> void:
	vehicle_data = Catalog.get_vehicle("police_sedan")
	super._ready()

func plan_chase() -> void:
	var origin: int = mission.roads.graph.get_closest_point(position)
	var goal: int = mission.roads.graph.get_closest_point(mission.car.position)
	path = mission.roads.graph.get_point_path(origin, goal)
	path_index = 0
	if path.size() > 1 and mission.roads.segment_clear(position, path[1]): path_index = 1
	replan_timer = 0.8 - 0.4 * mission.difficulty()

func _physics_process(delta: float) -> void:
	if not mission.is_active():
		velocity = Vector2.ZERO
		return
	impact_cooldown = maxf(0, impact_cooldown - delta)
	if health <= 0:
		speed = 0
		velocity = Vector2.ZERO
		return
	replan_timer -= delta
	if replan_timer <= 0 or path.is_empty(): plan_chase()
	while path_index < path.size() and position.distance_to(path[path_index]) < 12: path_index += 1
	var distance_to_player := position.distance_to(mission.car.position)
	var direct: bool = distance_to_player < 420 and mission.clear_view(position, mission.car.position)
	var waypoint: Vector2 = mission.car.position if direct else (path[path_index] if path_index < path.size() else position)
	var distance := position.distance_to(waypoint)
	if distance < 2:
		speed = 0
		velocity = Vector2.ZERO
		return
	var heading := position.direction_to(waypoint)
	var desired: float = mission.police_speed()
	if not direct and path_index + 1 < path.size():
		var next: Vector2 = (path[path_index + 1] - waypoint).normalized()
		if heading.dot(next) < 0.9 and distance < speed * speed / 700 + 90: desired = minf(desired, 140 + 90 * mission.difficulty())
	if direct and absf(mission.car.speed) < 45:
		desired = minf(desired, maxf(0, distance_to_player - 80) * 2)
	var query := PhysicsRayQueryParameters2D.create(position + heading * 35, position + heading * maxf(36, minf(distance, 70 + speed * speed / 700)), 7, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	# Police brake for other vehicles but keep approaching the suspect.
	if not hit.is_empty() and hit.collider != mission.car: desired = 0
	speed = move_toward(speed, desired, (550.0 if desired < speed else mission.police_acceleration()) * delta)
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
