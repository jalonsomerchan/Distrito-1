extends CharacterBody2D

signal destroyed

const Catalog = preload("res://scripts/vehicle_catalog.gd")

var vehicle_id := Catalog.default_id()
var vehicle_data: Dictionary = Catalog.get_vehicle(vehicle_id)
var damage_rules: Dictionary = Catalog.damage()
var max_health: float:
	get: return float(vehicle_data.max_health)
var health: float = float(vehicle_data.max_health):
	set(value):
		var was_alive := health > 0.0
		health = clampf(value, 0.0, max_health)
		_update_damage_sprite()
		if health <= 0.0:
			speed = 0.0
			velocity = Vector2.ZERO
			if was_alive: destroyed.emit()

var collision_shape: CollisionShape2D
var impact_cooldown := 0.0
var speed := 0.0
var distance_driven := 0.0
var enabled := false
var camera: Camera2D
var sprite: Sprite2D
var on_sidewalk := false

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 5
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	add_child(collision_shape)
	sprite = Sprite2D.new()
	add_child(sprite)
	set_vehicle(vehicle_id)
	z_index = 5
	camera = Camera2D.new()
	camera.ignore_rotation = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)

func configure_world_bounds(bounds: Rect2) -> void:
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)

func set_vehicle(id: String) -> bool:
	var definition := Catalog.get_vehicle(id)
	if definition.is_empty() or not definition.player_allowed: return false
	vehicle_id = id
	vehicle_data = definition
	if collision_shape != null:
		collision_shape.shape.size = Catalog.vector(vehicle_data.collision_size)
	restore()
	return true

func health_ratio() -> float:
	return health / max_health

func body_radius() -> float:
	return Catalog.vector(vehicle_data.collision_size).length() / 2

func damage_stage() -> int:
	for stage in range(damage_rules.thresholds.size()):
		if health_ratio() > float(damage_rules.thresholds[stage]): return stage
	return 4

func damage_name() -> String:
	return str(damage_rules.names[damage_stage()])

func _update_damage_sprite() -> void:
	if sprite == null: return
	sprite.texture = load(vehicle_data.sprites[damage_stage()])
	sprite.scale = Catalog.vector(vehicle_data.draw_size) / sprite.texture.get_size()

func select_next_vehicle() -> String:
	var available := Catalog.ids()
	set_vehicle(available[(available.find(vehicle_id) + 1) % available.size()])
	return vehicle_id

func vehicle_name() -> String:
	return str(vehicle_data.name)

func restore() -> void:
	health = max_health
	impact_cooldown = 0.0
	speed = 0.0
	velocity = Vector2.ZERO

func take_impact(normal_speed: float) -> float:
	# Only the velocity into the wall counts. Fast glancing contact is less damaging.
	if health <= 0.0 or impact_cooldown > 0.0 or normal_speed < float(damage_rules.min_impact_speed):
		return 0.0
	var damage := minf(max_health, float(damage_rules.base_damage) * float(vehicle_data.damage_multiplier) * pow(normal_speed / float(damage_rules.reference_speed), float(damage_rules.exponent)))
	var previous_health := health
	health -= damage
	impact_cooldown = float(damage_rules.cooldown)
	return previous_health - health

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	impact_cooldown = maxf(impact_cooldown - delta, 0.0)
	if health <= 0.0:
		return
	var throttle := _shape_analog(Input.get_action_strength("accelerate"))
	var brake := _shape_analog(Input.get_action_strength("brake"))
	var steer := _shape_analog(Input.get_axis("steer_left", "steer_right"))
	var handbrake := Input.is_action_pressed("handbrake")
	var max_speed := float(vehicle_data.sidewalk_max_speed if on_sidewalk else vehicle_data.max_speed)
	if throttle > 0.01:
		speed = move_toward(speed, max_speed * throttle, float(vehicle_data.acceleration) * delta)
	elif brake > 0.01:
		speed = move_toward(speed, -float(vehicle_data.reverse_speed) * brake, float(vehicle_data.braking if speed > 5 else vehicle_data.reverse_acceleration) * delta)
	else:
		speed = move_toward(speed, 0.0, float(vehicle_data.coast_deceleration) * delta)
	if handbrake:
		speed = move_toward(speed, 0.0, float(vehicle_data.handbrake_deceleration) * delta)
	if absf(speed) > 4.0:
		rotation += steer * signf(speed) * minf(absf(speed) / float(vehicle_data.steering_response_speed), 1.0) * float(vehicle_data.handbrake_steering_rate if handbrake else vehicle_data.steering_rate) * delta
	var forward := Vector2.UP.rotated(rotation)
	velocity = velocity.lerp(forward * speed, minf(delta * float(vehicle_data.drift_grip if handbrake else vehicle_data.grip), 1.0))
	var previous := position
	var impact_velocity := velocity
	if move_and_slide():
		var normal_speed := 0.0
		for i in range(get_slide_collision_count()):
			var collision := get_slide_collision(i)
			var relative_velocity := impact_velocity - collision.get_collider_velocity()
			var impact := maxf(0, -relative_velocity.dot(collision.get_normal()))
			normal_speed = maxf(normal_speed, impact)
			var other = collision.get_collider()
			if other.has_method("take_pursuit_impact"): other.take_pursuit_impact(impact)
		take_impact(normal_speed)
		speed *= 0.6
		velocity *= 0.6
	distance_driven += position.distance_to(previous)
	camera.position = camera.position.lerp(Vector2(0, -absf(speed) * 0.17).rotated(rotation), delta * 2.0)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * lerpf(1.0, 0.84, clampf(absf(speed) / float(vehicle_data.max_speed), 0, 1)), delta * 2.0)

func _shape_analog(value: float) -> float:
	# Ease partial stick/trigger travel without changing full keyboard or button input.
	return signf(value) * pow(absf(value), 1.5)
