extends Node2D

const Car = preload("res://scripts/car.gd")
const City = preload("res://scripts/city.gd")
const Minimap = preload("res://scripts/minimap.gd")
const Traffic = preload("res://scripts/traffic.gd")
const Delivery = preload("res://scripts/delivery.gd")
const Pursuit = preload("res://scripts/pursuit.gd")
const Escape = preload("res://scripts/escape.gd")
const QuickPickup = preload("res://scripts/quick_pickup.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
const SAVE_PATH := "user://district_save.json"
const SPAWN := Vector2(765, 1240)
const CREAM := Color("f5eddc")
const ORANGE := Color("f2a16b")
const MUTED := Color("a5b3ae")

@export var pause_on_focus_loss := true

var car: CharacterBody2D
var city: Node2D
var traffic: Node2D
var ui: CanvasLayer
var escape: Node2D
var quick_pickup: Node2D
var pursuit: Node2D
var result_heading: Label
var result_title: Label
var delivery: Node2D
var game_mode := "free"
var mode_menu: Control
var result_panel: Control
var result_label: Label
var mission_panel: Control
var mission_label: Label
var mission_timer: Label
var mission_detail: Label
var menu: Control
var city_select: Control
var hud: Control
var pause_panel: Control
var speed_label: Label
var distance_label: Label
var district_label: Label
var health_label: Label
var health_state: Label
var health_bar: ProgressBar
var status_label: Label
var pause_status: Label
var hints: Label
var load_button: Button
var car_button: Button
var menu_city_name: Label
var menu_location: Label
var playing := false
var paused := false
var using_gamepad := false
var autosave_timer := 0.0
var toast_timer := 0.0
var save_path := SAVE_PATH
var selected_city := "barcelona"
var city_select_from_menu := false
var minimap: Control

func _ready() -> void:
	get_tree().auto_accept_quit = false
	using_gamepad = not Input.get_connected_joypads().is_empty()
	Input.joy_connection_changed.connect(_controller_changed)
	_setup_input()
	_create_world()
	ui = CanvasLayer.new()
	add_child(ui)
	_setup_theme()
	_build_menu()
	_build_city_select()
	_build_hud()
	_build_pause()
	_build_modes()
	_build_result()
	car.destroyed.connect(func(): _toast("Coche destrozado. R / Y para reponerlo."))
	show_city_select(false)

func _create_world() -> void:
	city = City.new()
	city.game = self
	city.city_id = selected_city
	add_child(city)
	car = Car.new()
	car.position = SPAWN
	add_child(car)
	car.configure_world_bounds(city.WORLD_BOUNDS.grow(200))
	traffic = Traffic.new()
	traffic.city = city
	traffic.player = car
	traffic.game = self
	add_child(traffic)
	delivery = Delivery.new()
	delivery.city = city
	delivery.car = car
	add_child(delivery)
	delivery.changed.connect(_delivery_changed)
	delivery.expired.connect(_delivery_failed)
	pursuit = Pursuit.new()
	pursuit.game = self
	pursuit.city = city
	pursuit.car = car
	pursuit.roads = delivery
	add_child(pursuit)
	pursuit.level_started.connect(_pursuit_started)
	pursuit.failed.connect(_pursuit_failed)
	escape = Escape.new()
	escape.game = self
	escape.city = city
	escape.car = car
	escape.roads = delivery
	add_child(escape)
	escape.level_started.connect(_escape_started)
	escape.failed.connect(_escape_failed)
	quick_pickup = QuickPickup.new()
	quick_pickup.roads = delivery
	quick_pickup.city = city
	quick_pickup.car = car
	add_child(quick_pickup)
	quick_pickup.expired.connect(_quick_pickup_failed)
	if minimap != null: _bind_minimap()

func _replace_world() -> void:
	var vehicle_id := car.vehicle_id if car != null else Catalog.default_id()
	for node in [quick_pickup, escape, pursuit, delivery, traffic, car, city]:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	_create_world()
	car.set_vehicle(vehicle_id)
	car.position = SPAWN
	car.destroyed.connect(func(): _toast("Coche destrozado. R / Y para reponerlo."))
	if car_button != null: car_button.text = "COCHE: " + car.vehicle_name() + "   ↻"
	if menu_city_name != null: menu_city_name.text = str(city.profile.name)
	if menu_location != null: menu_location.text = str(city.profile.tagline)
	if menu != null:
		for child in menu.get_children():
			if child is Button and child.text.begins_with("CIUDAD:"):
				child.text = "CIUDAD: " + city.profile.name + "   ↻"

func _bind_minimap() -> void:
	minimap.city = city
	minimap.car = car
	minimap.traffic = traffic
	minimap.delivery = delivery
	minimap.pursuit = pursuit
	minimap.escape = escape
	minimap.quick_pickup = quick_pickup

func _setup_input() -> void:
	_bind("accelerate", [KEY_W, KEY_UP], [JOY_BUTTON_A], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind("brake", [KEY_S, KEY_DOWN], [], JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind("steer_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_bind("steer_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_bind("handbrake", [KEY_SPACE], [JOY_BUTTON_X])
	_bind("pause_game", [KEY_ESCAPE], [JOY_BUTTON_START])
	_bind("reset_car", [KEY_R], [JOY_BUTTON_Y])
	_bind("save_game", [KEY_F5], [])
	_bind("fullscreen", [KEY_F11], [])

func _bind(action: String, keys: Array, buttons: Array, axis := -1, axis_value := 1.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.28 if axis == JOY_AXIS_LEFT_X else (0.12 if axis >= 0 else 0.08))
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
	if axis >= 0:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = axis_value
		InputMap.action_add_event(action, event)

func _setup_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", CREAM)
	theme.set_color("font_focus_color", "Button", CREAM)
	theme.set_color("font_disabled_color", "Button", Color("61706e"))
	theme.set_stylebox("normal", "Button", _box(Color("263639"), 8))
	theme.set_stylebox("hover", "Button", _box(Color("3d504e"), 8))
	theme.set_stylebox("pressed", "Button", _box(Color("876346"), 8))
	var focus := _box(Color.TRANSPARENT, 8)
	focus.border_color = ORANGE
	focus.set_border_width_all(3)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("disabled", "Button", _box(Color("1c282c"), 8))
	var root := Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	ui.add_child(root)

func _box(color: Color, radius := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22
	box.content_margin_right = 22
	return box

func _root() -> Control:
	return ui.get_child(0)

func _layer() -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root().add_child(control)
	return control

func _rect(parent: Node, pos: Vector2, dimensions: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = dimensions
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _label(parent: Node, text: String, pos: Vector2, font_size := 22, color := CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, pos: Vector2, callback: Callable, width := 398.0) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(width, 62)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_menu() -> void:
	menu = _layer()
	_rect(menu, Vector2.ZERO, Vector2(1280, 800), Color(0.04, 0.08, 0.09, 0.35))
	_rect(menu, Vector2.ZERO, Vector2(520, 800), Color("142327"))
	_rect(menu, Vector2(54, 64), Vector2(36, 4), ORANGE)
	_label(menu, "UN JUEGO DE CONDUCCIÓN CENITAL", Vector2(54, 84), 16, MUTED)
	_label(menu, "DISTRITO", Vector2(48, 133), 76)
	_label(menu, "01", Vector2(48, 207), 132, ORANGE)
	_label(menu, "La ciudad es tuya.", Vector2(56, 374), 28)
	_label(menu, "Arranca. Explora. Encuentra tu camino.", Vector2(56, 418), 18, MUTED)
	car_button = _button(menu, "COCHE: " + car.vehicle_name() + "   ↻", Vector2(56, 436), cycle_car)
	_button(menu, "CIUDAD: " + city.profile.name + "   ↻", Vector2(56, 502), func(): show_city_select(true))
	_button(menu, "NUEVA PARTIDA     →", Vector2(56, 568), select_game_mode)
	load_button = _button(menu, "CARGAR PARTIDA", Vector2(56, 634), load_game)
	_button(menu, "SALIR", Vector2(56, 700), quit_game)
	_label(menu, "TECLADO + MANDO  /  1280 × 800", Vector2(56, 750), 15, MUTED)
	menu_city_name = _label(menu, str(city.profile.name), Vector2(952, 54), 24)
	_label(menu, "CALLES · BARRIOS · MONUMENTOS", Vector2(842, 90), 15, CREAM)
	_rect(menu, Vector2(1180, 126), Vector2(44, 3), ORANGE)
	menu_location = _label(menu, str(city.profile.tagline), Vector2(880, 728), 17, ORANGE)

func _build_city_select() -> void:
	city_select = _layer()
	_rect(city_select, Vector2.ZERO, Vector2(1280, 800), Color("142327f5"))
	_label(city_select, "TU PRÓXIMA CIUDAD", Vector2(78, 54), 18, ORANGE)
	_label(city_select, "ELIGE DESTINO", Vector2(74, 87), 46)
	_label(city_select, "Cuatro ciudades. Cuatro mapas y skylines distintos.", Vector2(80, 145), 20, MUTED)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cities.json"))
	var ids := ["barcelona", "paris", "miami", "los_angeles"]
	var positions := [Vector2(78, 205), Vector2(662, 205), Vector2(78, 446), Vector2(662, 446)]
	for i in range(ids.size()):
		var id: String = ids[i]
		var profile: Dictionary = catalog.cities[id]
		var pos: Vector2 = positions[i]
		var button := Button.new()
		button.position = pos
		button.size = Vector2(540, 196)
		button.text = ""
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func(): choose_city(id))
		city_select.add_child(button)
		var icon := TextureRect.new()
		icon.texture = load("res://" + str(profile.landmarks[0].sprite))
		icon.position = Vector2(14, 12)
		icon.size = Vector2(142, 170)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var city_name := _label(button, str(profile.name), Vector2(168, 28), 28)
		city_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var marker := _label(button, str(profile.landmark).to_upper(), Vector2(170, 70), 15, ORANGE)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var description := _label(button, str(profile.summary), Vector2(170, 104), 17, MUTED)
		description.size = Vector2(346, 72)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(city_select, "El mapa y los monumentos cambian con cada destino.", Vector2(82, 734), 16, MUTED)
	_button(city_select, "VOLVER", Vector2(1022, 718), _city_select_back, 180)
	city_select.hide()

func show_city_select(from_menu := false) -> void:
	city_select_from_menu = from_menu
	if menu != null: menu.hide()
	if city_select != null:
		hud.hide()
		mode_menu.hide()
		result_panel.hide()
		pause_panel.hide()
		city_select.show()
		_focus_first(city_select)

func choose_city(id: String) -> void:
	if id not in ["barcelona", "paris", "miami", "los_angeles"]: return
	if id != selected_city:
		selected_city = id
		_replace_world()
	city_select.hide()
	if city_select_from_menu: menu.show(); _focus_first(menu)
	else: show_menu()

func _city_select_back() -> void:
	city_select.hide()
	if city_select_from_menu: menu.show(); _focus_first(menu)
	else: show_menu()

func _build_modes() -> void:
	mode_menu = _layer()
	_rect(mode_menu, Vector2.ZERO, Vector2(1280, 800), Color("142327f5"))
	_label(mode_menu, "NUEVA PARTIDA", Vector2(340, 48), 18, ORANGE)
	_label(mode_menu, "ELIGE CÓMO JUGAR", Vector2(336, 84), 42)
	_button(mode_menu, "REPARTIDOR    →", Vector2(340, 164), func(): start_new_game("delivery"), 600)
	_label(mode_menu, "Recoge y entrega paquetes antes de que acabe el tiempo.", Vector2(340, 234), 18, MUTED)
	_button(mode_menu, "PERSECUCIÓN    →", Vector2(340, 280), func(): start_new_game("pursuit"), 600)
	_label(mode_menu, "Conduce el interceptor policial y detén al fugitivo.", Vector2(340, 350), 18, MUTED)
	_button(mode_menu, "ESCAPE    →", Vector2(340, 396), func(): start_new_game("escape"), 600)
	_label(mode_menu, "La policía te persigue. Pierde a todas las patrullas y huye.", Vector2(340, 466), 18, MUTED)
	_button(mode_menu, "RECOGIDA RÁPIDA    →", Vector2(340, 512), func(): start_new_game("quick_pickup"), 600)
	_label(mode_menu, "Encuentra cada moneda antes de que se agote la cuenta atrás.", Vector2(340, 582), 18, MUTED)
	_button(mode_menu, "MODO LIBRE    →", Vector2(340, 628), func(): start_new_game("free"), 600)
	_label(mode_menu, "Explora la ciudad sin objetivos ni límite de tiempo.", Vector2(340, 698), 18, MUTED)
	_button(mode_menu, "VOLVER", Vector2(340, 738), show_menu, 600)
	mode_menu.hide()

func select_game_mode() -> void:
	menu.hide()
	mode_menu.show()
	_focus_first(mode_menu)

func _build_result() -> void:
	result_panel = _layer()
	_rect(result_panel, Vector2.ZERO, Vector2(1280, 800), Color("142327ef"))
	result_heading = _label(result_panel, "REPARTIDOR / FIN DE PARTIDA", Vector2(340, 190), 20, ORANGE)
	result_title = _label(result_panel, "TIEMPO AGOTADO", Vector2(336, 232), 48)
	result_label = _label(result_panel, "", Vector2(340, 318), 24)
	_button(result_panel, "VOLVER A INTENTAR", Vector2(340, 400), func(): start_new_game(game_mode), 600)
	_button(result_panel, "VOLVER AL MENÚ", Vector2(340, 484), show_menu, 600)
	result_panel.hide()

func _delivery_changed() -> void:
	_toast("Paquete recogido. ¡Llévalo al destino!" if delivery.phase == "dropoff" else ("¡Entrega completada! Siguiente paquete." if delivery.delivered > 0 else "Ve al punto amarillo y frena para recoger."))

func _delivery_failed() -> void:
	paused = true
	car.enabled = false
	result_heading.text = "REPARTIDOR / FIN DE PARTIDA"
	result_title.text = "TIEMPO AGOTADO"
	result_title.add_theme_font_size_override("font_size", 48)
	result_label.text = "%d paquetes entregados · Nivel %d" % [delivery.delivered, delivery.delivered + 1]
	pause_panel.hide()
	result_panel.show()
	_focus_first(result_panel)
	save_game()

func _pursuit_started() -> void:
	_toast("Persecución · Nivel %d. ¡Detén al fugitivo!" % pursuit.level)
	if playing: save_game()

func _pursuit_failed() -> void:
	paused = true
	car.enabled = false
	result_heading.text = "PERSECUCIÓN / FIN DE PARTIDA"
	result_title.text = pursuit.reason
	result_title.add_theme_font_size_override("font_size", 34)
	result_label.text = "1 fugitivo detenido · Nivel 2" if pursuit.level == 2 else "%d fugitivos detenidos · Nivel %d" % [pursuit.level - 1, pursuit.level]
	pause_panel.hide()
	result_panel.show()
	_focus_first(result_panel)
	save_game()

func _escape_started() -> void:
	_toast("Escape · Nivel %d. ¡Pierde a las patrullas!" % escape.level)
	if playing: save_game()

func _escape_failed() -> void:
	paused = true
	car.enabled = false
	result_heading.text = "ESCAPE / FIN DE PARTIDA"
	result_title.text = escape.reason
	result_title.add_theme_font_size_override("font_size", 40)
	result_label.text = "%d huidas completadas · Nivel %d" % [escape.level - 1, escape.level]
	pause_panel.hide()
	result_panel.show()
	_focus_first(result_panel)
	save_game()

func _quick_pickup_failed() -> void:
	paused = true
	car.enabled = false
	result_heading.text = "RECOGIDA RÁPIDA / FIN DE PARTIDA"
	result_title.text = "TIEMPO AGOTADO"
	result_title.add_theme_font_size_override("font_size", 48)
	result_label.text = "%d monedas recogidas" % quick_pickup.collected
	pause_panel.hide()
	result_panel.show()
	_focus_first(result_panel)
	save_game()

func cycle_car() -> void:
	car.select_next_vehicle()
	car_button.text = "COCHE: " + car.vehicle_name() + "   ↻"

func _build_hud() -> void:
	hud = _layer()
	_rect(hud, Vector2(28, 26), Vector2(302, 86), Color("17272be8"))
	_rect(hud, Vector2(28, 26), Vector2(4, 86), ORANGE)
	_label(hud, "DISTRITO 01", Vector2(48, 37), 24)
	district_label = _label(hud, str(city.profile.name) + " / CENTRO", Vector2(48, 76), 15, MUTED)
	var map := Minimap.new()
	map.city = city
	map.car = car
	map.traffic = traffic
	map.delivery = delivery
	map.pursuit = pursuit
	map.escape = escape
	map.quick_pickup = quick_pickup
	minimap = map
	map.position = Vector2(1050, 28)
	map.size = Vector2(202, 202)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(map)
	_label(hud, "N ↑", Vector2(1200, 237), 16, ORANGE)
	_rect(hud, Vector2(1040, 550), Vector2(212, 221), Color("17272be8"))
	speed_label = _label(hud, "000", Vector2(1062, 549), 58)
	_label(hud, "km/h", Vector2(1180, 598), 18, MUTED)
	_label(hud, "VIDA", Vector2(1062, 636), 16, MUTED)
	health_label = _label(hud, "100%", Vector2(1180, 630), 22)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(1062, 667)
	health_bar.size = Vector2(168, 12)
	health_bar.step = 0.01
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("384646")
	bar_background.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color.WHITE
	bar_fill.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("background", bar_background)
	health_bar.add_theme_stylebox_override("fill", bar_fill)
	hud.add_child(health_bar)
	health_state = _label(hud, "BUEN ESTADO", Vector2(1062, 694), 16)
	distance_label = _label(hud, "0.00 km recorridos", Vector2(1062, 741), 15, MUTED)
	_rect(hud, Vector2(24, 726), Vector2(984, 44), Color("17272be8"))
	hints = _label(hud, "", Vector2(36, 735), 18)
	status_label = _label(hud, "", Vector2(356, 39), 18, ORANGE)
	mission_panel = Control.new()
	hud.add_child(mission_panel)
	_rect(mission_panel, Vector2(28, 130), Vector2(430, 124), Color("17272be8"))
	mission_label = _label(mission_panel, "", Vector2(48, 141), 22, ORANGE)
	mission_timer = _label(mission_panel, "", Vector2(48, 176), 30)
	mission_detail = _label(mission_panel, "", Vector2(48, 220), 16, MUTED)

func _build_pause() -> void:
	pause_panel = _layer()
	_rect(pause_panel, Vector2.ZERO, Vector2(1280, 800), Color(0.03, 0.07, 0.08, 0.82))
	_rect(pause_panel, Vector2(392, 104), Vector2(496, 592), Color("142327"))
	_label(pause_panel, "FRENO Y RESPIRO", Vector2(440, 144), 16, ORANGE)
	_label(pause_panel, "EN PAUSA", Vector2(436, 179), 48)
	_button(pause_panel, "CONTINUAR", Vector2(440, 273), resume_game, 400)
	_button(pause_panel, "GUARDAR PARTIDA", Vector2(440, 349), func(): save_game(), 400)
	_button(pause_panel, "GUARDAR Y VOLVER AL MENÚ", Vector2(440, 425), func():
		if save_game(): show_menu(), 400)
	_button(pause_panel, "GUARDAR Y SALIR", Vector2(440, 501), quit_game, 400)
	pause_status = _label(pause_panel, "", Vector2(440, 581), 18, ORANGE)
	_label(pause_panel, "ESC / ☰  Continuar", Vector2(440, 623), 18, MUTED)

func show_menu() -> void:
	playing = false
	paused = false
	car.enabled = false
	traffic.set_active(false)
	car.position = Vector2(1455, 1460)
	car.rotation = -0.45
	car.camera.position = Vector2(120, -110)
	car.camera.zoom = Vector2.ONE * 0.9
	car.camera.reset_smoothing()
	delivery.hide()
	pursuit.hide()
	pursuit.set_target_visible(false)
	escape.hide()
	escape.set_patrols_visible(false)
	quick_pickup.hide()
	quick_pickup.stop()
	mode_menu.hide()
	result_panel.hide()
	if city_select != null: city_select.hide()
	menu.show()
	hud.hide()
	pause_panel.hide()
	load_button.disabled = not _has_save()
	_focus_first(menu)

func _has_save() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return data is Dictionary and data.get("version") == 1

func _focus_first(parent: Control) -> void:
	for child in parent.get_children():
		if child is Button and not child.disabled:
			child.call_deferred("grab_focus")
			return

func start_new_game(mode := "free") -> void:
	game_mode = mode
	delivery.stop()
	pursuit.stop()
	escape.stop()
	quick_pickup.stop()
	if game_mode == "escape" and car.vehicle_data.category == "police":
		car.set_vehicle(Catalog.default_id())
		car_button.text = "COCHE: " + car.vehicle_name() + "   ↻"
	if game_mode == "pursuit":
		car.set_vehicle("police_interceptor")
		car_button.text = "COCHE: " + car.vehicle_name() + "   ↻"
	city.details.clock = 0
	car.position = SPAWN
	car.rotation = 0
	car.distance_driven = 0
	car.restore()
	_begin_driving()
	if game_mode == "delivery": delivery.start()
	if game_mode == "pursuit": pursuit.start()
	if game_mode == "escape": escape.start()
	if game_mode == "quick_pickup": quick_pickup.start()
	save_game()
	if game_mode == "delivery":
		_delivery_changed()
		return
	if game_mode == "pursuit":
		_toast("Bloquea al fugitivo y mantenlo parado para arrestarlo.")
		return
	if game_mode == "escape":
		_toast("Aléjate de todas las patrullas y mantén la distancia.")
		return
	if game_mode == "quick_pickup":
		_toast("¡Ve a por la moneda! Cada nueva recogida aparece en otra zona.")
		return
	_toast("Bienvenido a %s. La ciudad es tuya." % city.profile.name.to_lower().capitalize())

func _begin_driving() -> void:
	car.speed = 0
	car.velocity = Vector2.ZERO
	car.camera.position = Vector2.ZERO
	car.camera.zoom = Vector2.ONE
	car.camera.reset_smoothing()
	playing = true
	paused = false
	autosave_timer = 0
	car.enabled = true
	city.wilderness.refresh(car.position)
	traffic.reset()
	traffic.set_active(true)
	menu.hide()
	mode_menu.hide()
	result_panel.hide()
	delivery.visible = game_mode == "delivery"
	quick_pickup.visible = game_mode == "quick_pickup"
	mission_panel.visible = game_mode in ["delivery", "pursuit", "escape", "quick_pickup"]
	pause_panel.hide()
	hud.show()
	var focused := get_viewport().gui_get_focus_owner()
	if focused: focused.release_focus()

func load_game() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else null
	if raw is Dictionary:
		var saved_city := str(raw.get("city_id", "barcelona"))
		if saved_city in ["barcelona", "paris", "miami", "los_angeles"] and saved_city != selected_city:
			selected_city = saved_city
			_replace_world()
	var data := read_save()
	if data.is_empty():
		load_button.disabled = true
		return
	city.details.clock = float(data.get("signal_clock", 0))
	game_mode = str(data.get("mode", "free"))
	delivery.stop()
	pursuit.stop()
	escape.stop()
	quick_pickup.stop()
	car.position = Vector2(float(data.x), float(data.y))
	car.set_vehicle(str(data.get("vehicle_id", Catalog.default_id())))
	car_button.text = "COCHE: " + car.vehicle_name() + "   ↻"
	car.rotation = float(data.angle)
	car.distance_driven = float(data.distance)
	car.health = float(data.get("health", car.max_health))
	_begin_driving()
	if game_mode == "delivery":
		delivery.restore(data.delivery)
		if delivery.phase == "failed": _delivery_failed()
	if game_mode == "pursuit":
		pursuit.restore(data.pursuit)
		if pursuit.phase == "failed": _pursuit_failed()
	if game_mode == "escape":
		escape.restore(data.escape)
		if escape.phase == "failed": _escape_failed()
	if game_mode == "quick_pickup":
		quick_pickup.restore(data.quick_pickup)
		if quick_pickup.phase == "failed": _quick_pickup_failed()
	_toast("Ciudad actualizada. Coche llevado a la avenida." if data.get("_relocated", false) else "Partida cargada. Buen viaje.")

func read_save() -> Dictionary:
	if not FileAccess.file_exists(save_path): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return {}
	if data.get("version") != 1: return {}
	for key in ["x", "y", "angle", "distance"]:
		if not data.has(key) or not (data[key] is float or data[key] is int): return {}
		if not is_finite(float(data[key])): return {}
	if float(data.distance) < 0: return {}
	var vehicle_id: Variant = data.get("vehicle_id", Catalog.default_id())
	if not vehicle_id is String: return {}
	var definition := Catalog.get_vehicle(vehicle_id)
	if definition.is_empty() or not definition.player_allowed: return {}
	# Version 1 saves made before vehicle damage start with a healthy car.
	if data.has("health"):
		if not (data.health is float or data.health is int): return {}
		if not is_finite(float(data.health)) or float(data.health) < 0 or float(data.health) > float(definition.max_health): return {}
	var city_version = data.get("city_version", 1)
	if not (city_version is int or city_version is float): return {}
	if not is_finite(float(city_version)) or city_version < 1: return {}
	if data.get("mode", "free") not in ["free", "delivery", "pursuit", "escape", "quick_pickup"]: return {}
	if data.get("city_id", "barcelona") not in ["barcelona", "paris", "miami", "los_angeles"]: return {}
	if data.has("signal_clock"):
		if not (data.signal_clock is float or data.signal_clock is int) or not is_finite(float(data.signal_clock)) or data.signal_clock < 0 or data.signal_clock >= 32: return {}
	if city_version < 4 and not _migrate_city_details(data): return {}
	if data.get("mode", "free") == "delivery" and not delivery.valid_save(data.get("delivery")): return {}
	if data.get("mode", "free") == "pursuit":
		if vehicle_id != "police_interceptor" or not pursuit.valid_save(data.get("pursuit")): return {}
	if data.get("mode", "free") == "escape" and not escape.valid_save(data.get("escape")): return {}
	if data.get("mode", "free") == "quick_pickup" and not quick_pickup.valid_save(data.get("quick_pickup")): return {}
	var saved_position := Vector2(float(data.x), float(data.y))
	var car_clearance := Catalog.vector(definition.collision_size).length() / 2
	if not city.is_safe_position(saved_position) or (city_version < 4 and city.near_roundabout(saved_position) and not city.street_clear(saved_position, car_clearance)):
		if city_version >= city.LAYOUT_VERSION or not city.WORLD_BOUNDS.has_point(saved_position): return {}
		# An older road may now contain a building. Preserve progress safely.
		data.x = SPAWN.x
		data.y = SPAWN.y
		data.angle = 0.0
		data["_relocated"] = true
	return data

# Old navigation IDs retain their coordinates. Rebuild only routes affected by
# the new islands, preserving job phase, clock, damage and level progress.
func _migrate_city_details(data: Dictionary) -> bool:
	var mode: String = str(data.get("mode", "free"))
	if mode == "free": return true
	delivery.build_routes()
	if mode == "delivery":
		if not data.get("delivery") is Dictionary: return false
		for key in ["target", "destination"]:
			var id: Variant = data.delivery.get(key)
			if not (id is float or id is int) or not is_finite(float(id)) or float(id) != floorf(float(id)) or not delivery.graph.has_point(int(id)): return false
			data.delivery[key] = delivery.graph.get_closest_point(delivery.graph.get_point_position(int(id)))
	elif mode == "pursuit":
		if not data.get("pursuit") is Dictionary: return false
		var mission: Dictionary = data.pursuit
		if not mission.get("path") is Array or mission.path.is_empty(): return false
		for id in mission.path:
			if not (id is float or id is int) or not is_finite(float(id)) or float(id) != floorf(float(id)) or not delivery.graph.has_point(int(id)): return false
		if not _migrate_actor(mission): return false
		var origin: int = delivery.graph.get_closest_point(Vector2(mission.x, mission.y))
		var goal: int = delivery.graph.get_closest_point(delivery.graph.get_point_position(int(mission.path.back())))
		mission.path = Array(delivery.graph.get_id_path(origin, goal))
		mission.path_index = 0
	elif mode == "escape":
		if not data.get("escape") is Dictionary or not data.escape.get("patrols") is Array: return false
		for patrol in data.escape.patrols:
			if not patrol is Dictionary or not _migrate_actor(patrol): return false
	return true

func _migrate_actor(actor: Dictionary) -> bool:
	for key in ["x", "y"]:
		if not (actor.get(key) is float or actor.get(key) is int) or not is_finite(float(actor[key])): return false
	var at := Vector2(actor.x, actor.y)
	if city.near_roundabout(at) and not city.street_clear(at, 40):
		var safe: Vector2 = delivery.graph.get_point_position(delivery.graph.get_closest_point(at))
		actor.x = safe.x
		actor.y = safe.y
	return true

func save_game() -> bool:
	if not playing: return false
	var data := {"version": 1, "city_version": city.LAYOUT_VERSION, "city_id": selected_city, "vehicle_id": car.vehicle_id, "x": car.position.x, "y": car.position.y, "angle": car.rotation, "distance": car.distance_driven, "health": car.health}
	data["signal_clock"] = city.details.clock
	data["mode"] = game_mode
	if game_mode == "delivery": data["delivery"] = delivery.serialize()
	if game_mode == "pursuit": data["pursuit"] = pursuit.serialize()
	if game_mode == "escape": data["escape"] = escape.serialize()
	if game_mode == "quick_pickup": data["quick_pickup"] = quick_pickup.serialize()
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		_toast("No se pudo guardar la partida.")
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		_toast("No se pudo guardar la partida.")
		return false
	_toast("Partida guardada")
	return true

func resume_game() -> void:
	if game_mode == "delivery" and delivery.phase == "failed": return
	if game_mode == "pursuit" and pursuit.phase == "failed": return
	if game_mode == "escape" and escape.phase == "failed": return
	if game_mode == "quick_pickup" and quick_pickup.phase == "failed": return
	paused = false
	car.enabled = true
	pause_panel.hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused: focused.release_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_gamepad = true
	elif event is InputEventKey:
		using_gamepad = false
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("pause_game") and mode_menu.visible:
		show_menu()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause_game") and city_select.visible:
		_city_select_back()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause_game") and playing and not result_panel.visible:
		if paused:
			resume_game()
		else:
			paused = true
			car.enabled = false
			pause_panel.show()
			_focus_first(pause_panel)
		get_viewport().set_input_as_handled()
	if playing and not paused:
		if event.is_action_pressed("save_game"): save_game()
		if event.is_action_pressed("reset_car"):
			car.position = SPAWN
			car.rotation = 0
			car.restore()
			city.wilderness.refresh(car.position)
			traffic.clear_near_player()
			car.camera.reset_smoothing()
			if game_mode == "escape":
				escape.start_level()
				_toast("Coche reparado. La persecución de este nivel empieza de nuevo.")
			else:
				_toast("Coche reparado y devuelto a la avenida")

func _process(delta: float) -> void:
	if not playing: return
	car.on_sidewalk = city.is_sidewalk(car.position)
	district_label.text = str(city.profile.name) + " / " + city.district_at(car.position)
	var units := Catalog.units()
	speed_label.text = "%03d" % int(absf(car.speed) * float(units.speed_to_kmh))
	distance_label.text = "%.2f km recorridos" % (car.distance_driven / float(units.distance_units_per_km))
	var health_percent: float = car.health_ratio() * 100.0
	health_bar.value = health_percent
	health_label.text = "%d%%" % ceili(health_percent)
	var health_color := Color("e87b68") if health_percent <= 25 else (ORANGE if health_percent <= 50 else Color("a9d3a4"))
	health_bar.self_modulate = health_color
	health_label.add_theme_color_override("font_color", health_color)
	health_state.text = car.damage_name()
	health_state.add_theme_color_override("font_color", health_color)
	hints.text = "RT  Acelerar    LT  Frenar / atrás    X  Derrapar    Y  Reparar    ☰  Pausa" if using_gamepad else "WASD / ↑↓←→  Conducir    ESPACIO  Derrapar    R  Reparar    ESC  Pausa"
	toast_timer = maxf(toast_timer - delta, 0)
	status_label.visible = toast_timer > 0
	pause_status.visible = toast_timer > 0
	if game_mode == "delivery":
		if not paused: delivery.tick(delta)
		mission_label.text = "REPARTIDOR · NIVEL %d · %d entregados" % [delivery.delivered + 1, delivery.delivered]
		mission_timer.add_theme_font_size_override("font_size", 30)
		var seconds := ceili(delivery.remaining)
		mission_timer.text = "%s  %02d:%02d" % ["RECOGER" if delivery.phase == "pickup" else "ENTREGAR", seconds / 60, seconds % 60]
		mission_timer.add_theme_color_override("font_color", Color("e87b68") if seconds <= 10 else CREAM)
		mission_detail.text = "%s · Frena en el círculo (%d m)" % [city.district_at(delivery.target_position()), roundi(car.position.distance_to(delivery.target_position()) * 1000.0 / float(Catalog.units().distance_units_per_km))]
	if game_mode == "pursuit":
		if not paused: pursuit.tick(delta)
		mission_label.text = "PERSECUCIÓN · NIVEL %d" % pursuit.level
		mission_timer.add_theme_color_override("font_color", CREAM)
		mission_timer.add_theme_font_size_override("font_size", 24)
		if pursuit.phase == "caught":
			mission_timer.text = "¡FUGITIVO DETENIDO!"
			mission_detail.text = "Siguiente nivel en %d… Patrulla reparada al empezar." % ceili(pursuit.transition)
		else:
			mission_timer.text = "ARRESTO %d%% · COCHE %d%%" % [mini(100, roundi(pursuit.arrest / pursuit.arrest_duration() * 100)), ceili(pursuit.target.health / pursuit.target.max_health * 100)]
			if pursuit.lost_time > 0:
				mission_detail.text = "¡Se escapa! Acércate antes de %d s" % ceili(pursuit.escape_grace() - pursuit.lost_time)
			else:
				mission_detail.text = "Bloquéalo y frena cerca · Objetivo a %d m" % roundi(car.position.distance_to(pursuit.target.position) * 1000.0 / float(units.distance_units_per_km))
	if game_mode == "escape":
		if not paused: escape.tick(delta)
		mission_label.text = "ESCAPE · NIVEL %d · %d PATRULLAS" % [escape.level, escape.patrols.size()]
		mission_timer.add_theme_font_size_override("font_size", 24)
		mission_timer.add_theme_color_override("font_color", Color("e87b68") if escape.arrest > 0 else CREAM)
		if escape.phase == "escaped":
			mission_timer.text = "¡HAS ESCAPADO!"
			mission_detail.text = "Siguiente nivel en %d… Coche reparado al empezar." % ceili(escape.transition)
		else:
			mission_timer.text = "HUIDA %d%% · ARRESTO %d%%" % [roundi(escape.escape_time / escape.escape_duration() * 100), roundi(escape.arrest / escape.arrest_duration() * 100)]
			var distance: float = escape.nearest_distance()
			mission_detail.text = "Pierde a todas durante %d s · Más cercana: %d m" % [ceili(escape.escape_duration()), roundi(distance * 1000 / float(units.distance_units_per_km))] if is_finite(distance) else "Patrullas inutilizadas. Mantente libre unos segundos."
	if game_mode == "quick_pickup":
		if not paused: quick_pickup.tick(delta)
		mission_label.text = "RECOGIDA RÁPIDA · %d MONEDAS" % quick_pickup.collected
		mission_timer.add_theme_font_size_override("font_size", 30)
		var seconds := ceili(quick_pickup.remaining)
		mission_timer.text = "%02d:%02d" % [seconds / 60, seconds % 60]
		mission_timer.add_theme_color_override("font_color", Color("e87b68") if seconds <= 10 else CREAM)
		mission_detail.text = "%s · Moneda a %d m" % [city.district_at(quick_pickup.target_position()), roundi(car.position.distance_to(quick_pickup.target_position()) * 1000.0 / float(units.distance_units_per_km))]
	if not paused:
		autosave_timer += delta
		if autosave_timer >= 30:
			autosave_timer = 0
			save_game()

func _toast(text: String) -> void:
	status_label.text = text
	pause_status.text = text if text.length() < 42 else ""
	toast_timer = 4.0
	status_label.show()

func quit_game() -> void:
	if playing and not save_game(): return
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and playing and not paused:
		paused = true
		car.enabled = false
		pause_panel.show()
		_focus_first(pause_panel)

func _controller_changed(_device: int, connected: bool) -> void:
	using_gamepad = not Input.get_connected_joypads().is_empty()
	if not connected and playing and not paused:
		paused = true
		car.enabled = false
		pause_panel.show()
		_focus_first(pause_panel)
		_toast("Mando desconectado. Partida en pausa.")
