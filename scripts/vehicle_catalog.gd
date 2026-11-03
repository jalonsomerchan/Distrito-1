extends RefCounted

const DATA_PATH := "res://data/vehicles.json"
const POSITIVE_FIELDS := ["max_speed", "acceleration", "reverse_speed", "reverse_acceleration", "braking", "coast_deceleration", "sidewalk_max_speed", "grip", "drift_grip", "steering_rate", "handbrake_steering_rate", "steering_response_speed", "handbrake_deceleration", "max_health", "damage_multiplier"]
static var _loaded := false
static var _vehicles: Dictionary = {}
static var _order: Array[String] = []
static var _document: Dictionary = {}

static func merge_values(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides:
		if overrides[key] is Dictionary and result.get(key) is Dictionary:
			result[key] = merge_values(result[key], overrides[key])
		else:
			result[key] = overrides[key].duplicate(true) if overrides[key] is Array or overrides[key] is Dictionary else overrides[key]
	return result

static func positive(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) > 0

static func validate_document(document: Variant, check_assets := true) -> PackedStringArray:
	var errors := PackedStringArray()
	if not document is Dictionary:
		errors.append("El catálogo debe ser un objeto JSON.")
		return errors
	if not (document.get("version") is float or document.get("version") is int) or float(document.version) != 1: errors.append("Versión de catálogo no compatible.")
	if not document.get("defaults") is Dictionary or not document.get("vehicles") is Array:
		errors.append("Faltan defaults o vehicles.")
		return errors
	var ids := {}
	var players := 0
	for entry in document.vehicles:
		if not entry is Dictionary:
			errors.append("Cada vehículo debe ser un objeto.")
			continue
		var vehicle := merge_values(document.defaults, entry)
		var id: Variant = vehicle.get("id")
		if not id is String or id.is_empty() or ids.has(id):
			errors.append("ID de vehículo vacío, duplicado o inválido.")
			continue
		ids[id] = true
		if not vehicle.get("name") is String or str(vehicle.get("name", "")).is_empty(): errors.append(id + ": falta nombre.")
		for field in POSITIVE_FIELDS:
			if not positive(vehicle.get(field)): errors.append(id + ": " + field + " debe ser positivo y finito.")
		for flag in ["player_allowed", "bots_allowed"]:
			if not vehicle.get(flag) is bool: errors.append(id + ": " + flag + " debe ser booleano.")
		if vehicle.get("player_allowed") is bool and vehicle.player_allowed: players += 1
		var valid_dimensions := true
		for field in ["draw_size", "collision_size"]:
			var dimensions: Variant = vehicle.get(field)
			if not dimensions is Array or dimensions.size() != 2:
				errors.append(id + ": " + field + " debe contener dos dimensiones.")
				valid_dimensions = false
			elif not positive(dimensions[0]) or not positive(dimensions[1]):
				errors.append(id + ": dimensiones inválidas.")
				valid_dimensions = false
		if valid_dimensions:
			if vehicle.collision_size[0] > vehicle.draw_size[0] or vehicle.collision_size[1] > vehicle.draw_size[1]: errors.append(id + ": la colisión no debe ser mayor que el sprite.")
		var sprites: Variant = vehicle.get("sprites")
		if not sprites is Array or sprites.size() != 5:
			errors.append(id + ": necesita cinco sprites, de nuevo a destrozado.")
		else:
			var paths := {}
			for path in sprites:
				if not path is String:
					errors.append(id + ": la ruta de sprite debe ser texto.")
					continue
				if not path.begins_with("res://") or paths.has(path): errors.append(id + ": sprite inválido o repetido.")
				elif check_assets and not ResourceLoader.exists(path): errors.append(id + ": sprite no encontrado: " + path)
				paths[path] = true
		var ai: Variant = vehicle.get("ai")
		if not ai is Dictionary:
			errors.append(id + ": falta configuración de IA.")
		else:
			for field in ["cruise_min", "cruise_max", "acceleration", "braking", "corner_speed", "follow_distance", "corner_lookahead", "lane_offset", "turn_radius"]:
				if not positive(ai.get(field)): errors.append(id + ": ai." + field + " inválido.")
			if not (ai.get("spawn_weight") is int or ai.get("spawn_weight") is float) or not is_finite(float(ai.get("spawn_weight", 0))) or ai.get("spawn_weight", -1) < 0:
				errors.append(id + ": peso de tráfico inválido.")
			elif vehicle.get("bots_allowed") is bool and vehicle.bots_allowed and ai.spawn_weight <= 0: errors.append(id + ": un coche de IA necesita peso positivo.")
			if positive(ai.get("cruise_min")) and positive(ai.get("cruise_max")) and positive(vehicle.get("max_speed")):
				if ai.cruise_min > ai.cruise_max or ai.cruise_max > vehicle.max_speed: errors.append(id + ": velocidades de IA incoherentes.")
	if players == 0: errors.append("Debe existir al menos un coche para el jugador.")
	if not document.get("default_vehicle_id") is String or not ids.has(document.default_vehicle_id): errors.append("El coche por defecto no existe.")
	else:
		for entry in document.vehicles:
			if entry is Dictionary and entry.get("id") is String and entry.id == document.default_vehicle_id:
				var selectable: Variant = merge_values(document.defaults, entry).get("player_allowed")
				if not selectable is bool or not selectable: errors.append("El coche por defecto debe ser seleccionable.")
	var units: Variant = document.get("units")
	if not units is Dictionary or not positive(units.get("speed_to_kmh")) or not positive(units.get("distance_units_per_km")): errors.append("Unidades inválidas.")
	var damage: Variant = document.get("damage")
	if not damage is Dictionary:
		errors.append("Falta configuración de daño.")
	else:
		for field in ["min_impact_speed", "cooldown", "reference_speed", "base_damage", "exponent"]:
			if not positive(damage.get(field)): errors.append("Daño: " + field + " inválido.")
		if not damage.get("thresholds") is Array or damage.thresholds.size() != 4:
			errors.append("Se necesitan cuatro umbrales de daño.")
		else:
			var previous := 1.0
			for threshold in damage.thresholds:
				if not (threshold is float or threshold is int) or not is_finite(float(threshold)) or threshold < 0 or threshold >= previous:
					errors.append("Los umbrales deben descender desde menos de 1 hasta 0.")
					break
				previous = float(threshold)
			var last: Variant = damage.thresholds.back()
			if not (last is float or last is int) or float(last) != 0: errors.append("El último umbral debe ser cero.")
		if not damage.get("names") is Array or damage.names.size() != 5: errors.append("Se necesitan cinco nombres de estado.")
	return errors

static func _ensure_loaded() -> void:
	if _loaded: return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var errors := validate_document(parsed)
	if not errors.is_empty():
		push_error("Catálogo de coches inválido: " + "; ".join(errors))
		return
	_document = parsed
	for entry in _document.vehicles:
		var vehicle := merge_values(_document.defaults, entry)
		_vehicles[vehicle.id] = vehicle
		_order.append(vehicle.id)

static func default_id() -> String:
	_ensure_loaded()
	return str(_document.get("default_vehicle_id", ""))

static func get_vehicle(id: String) -> Dictionary:
	_ensure_loaded()
	return _vehicles.get(id, {}).duplicate(true)

static func ids(for_bots := false) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for id in _order:
		if _vehicles[id]["bots_allowed" if for_bots else "player_allowed"]: result.append(id)
	return result

static func traffic_id(seed_value: int) -> String:
	var allowed := ids(true)
	if allowed.is_empty(): return ""
	var total := 0.0
	for id in allowed: total += float(_vehicles[id].ai.spawn_weight)
	var ticket := fposmod(seed_value * 0.61803398875, 1.0) * total
	for id in allowed:
		ticket -= float(_vehicles[id].ai.spawn_weight)
		if ticket < 0: return id
	return allowed.back()

static func units() -> Dictionary:
	_ensure_loaded()
	return _document.get("units", {}).duplicate(true)

static func damage() -> Dictionary:
	_ensure_loaded()
	return _document.get("damage", {}).duplicate(true)

static func vector(dimensions: Array) -> Vector2:
	return Vector2(float(dimensions[0]), float(dimensions[1]))
