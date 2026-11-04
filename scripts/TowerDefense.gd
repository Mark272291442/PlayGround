extends Node3D

const CELL := 0.82
const COLS := 7
const ROWS := 8
const HEROES := ["sakura", "ren", "yuki"]
const NAMES := {"sakura":"SAKURA", "ren":"REN", "yuki":"YUKI"}
const ROLES := {"sakura":"BLADE DANCER", "ren":"STAR MAGE", "yuki":"MOON ARCHER"}
const COSTS := {"sakura":100, "ren":145, "yuki":175}
const COLORS := {"sakura":Color("ff69ae"), "ren":Color("65d8ff"), "yuki":Color("b99aff")}

var camera: Camera3D
var ui: Control
var coins_label: Label
var hearts_label: Label
var wave_label: Label
var message_label: Label
var upgrade_button: Button
var ultimate_button: Button
var wave_button: Button
var hero_buttons := {}
var path_cells: Array[Vector2i] = []
var path_points: Array[Vector3] = []
var path_lookup := {}
var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var selected_type := "sakura"
var selected_tower: Dictionary = {}
var coins := 320
var hearts := 20
var wave := 0
var kills := 0
var combo := 0
var combo_time := 0.0
var ultimate_charge := 0.0
var spawn_remaining := 0
var spawn_timer := 0.0
var wave_active := false
var game_over := false
var run_time := 0.0

func _ready() -> void:
	build_world()
	build_path()
	build_ui()
	refresh_ui()

func _process(delta: float) -> void:
	run_time += delta
	update_enemies(delta)
	update_towers(delta)
	update_shots(delta)
	update_wave(delta)
	if combo > 0:
		combo_time -= delta
		if combo_time <= 0.0:
			combo = 0
		refresh_ui()
	animate_world()

func _unhandled_input(event: InputEvent) -> void:
	var p := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		p = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		p = event.position
	if p.x < 0 or game_over:
		return
	var origin := camera.project_ray_origin(p)
	var direction := camera.project_ray_normal(p)
	if absf(direction.y) < 0.001:
		return
	var hit := origin + direction * (-origin.y / direction.y)
	var cell := Vector2i(roundi(hit.x / CELL + 3.0), roundi(hit.z / CELL + 3.5))
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		return
	for tower in towers:
		if tower.node.position.distance_to(Vector3(cell.x - 3.0, 0, cell.y - 3.5) * CELL) < CELL * 0.45:
			select_tower(tower)
			return
	if path_lookup.has(cell):
		set_message("THE SPIRIT ROAD IS BLOCKED", Color("ff819b"))
		return
	place_tower(cell)

func build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9aa8df")
	e.ambient_light_energy = 0.7
	 e:
	pass
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffd9e8")
	sun.light_energy = 1.4
	add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(0, 12.8, 13.5)
	camera.fov = 43
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(camera)
	camera.current = true
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18, 19)
	ground.mesh = plane
	ground.position.y = -0.15
	ground.material_override = material(Color("20213e"), 0.9)
	add_child(ground)
	var platform := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.7, 0.22, 7.7)
	platform.mesh = box
	platform.position = Vector3(0, -0.02, 0)
	platform.material_override = material(Color("302c55"))
	add_child(platform)
	for r in range(ROWS):
		for c in range(COLS):
			var tile := MeshInstance3D.new()
			var tile_mesh := BoxMesh.new()
			tile_mesh.size = Vector3(CELL * 0.94, 0.08, CELL * 0.94)
			tile.mesh = tile_mesh
			tile.position = cell_position(Vector2i(c, r)) + Vector3(0, 0.13, 0)
			tile.material_override = material(Color("3b3865") if (r + c) % 2 == 0 else Color("343257"))
			add_child(tile)
	add_decorations()

func build_path() -> void:
	for c in range(0, 4): path_cells.append(Vector2i(c, 0))
	for r in range(1, 3): path_cells.append(Vector2i(3, r))
	for c in range(4, 7): path_cells.append(Vector2i(c, 2))
	for r in range(3, 5): path_cells.append(Vector2i(6, r))
	for c in range(5, 0, -1): path_cells.append(Vector2i(c, 4))
	for r in range(5, 7): path_cells.append(Vector2i(1, r))
	for c in range(2, 7): path_cells.append(Vector2i(c, 6))
	path_cells.append(Vector2i(6, 7))
	for cell in path_cells:
		path_lookup[cell] = true
		var p := cell_position(cell)
		var tile := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(CELL * 0.9, 0.13, CELL * 0.9)
		tile.mesh = mesh
		tile.position = p + Vector3(0, 0.22, 0)
		tile.material_override = material(Color("754d83"), 0.7, Color("b66da5"))
		add_child(tile)
		path_points.append(p + Vector3(0, 0.34, 0))
	for i in range(path_points.size() - 1):
		var a := path_points[i]
		var b := path_points[i + 1]
		var ribbon := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.10, 0.025, a.distance_to(b) * 0.72)
		ribbon.mesh = mesh
		ribbon.position = (a + b) * 0.5 + Vector3(0, 0.1, 0)
		ribbon.look_at(Vector3(b.x, ribbon.position.y, b.z), Vector3.UP)
		ribbon.material_override = material(Color("ffc2df"), 0.3, Color("ff91cb"))
		add_child(ribbon)
	create_gate(path_points[0], Color("ff87c2"), "ENTRY")
	create_gate(path_points[-1], Color("70e8ff"), "EXIT")

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui)
	var top := panel(Vector2(24, 24), Vector2(-24, 150), true)
	top.anchor_right = 1.0
	var title := label("ASTRAL GUARDIANS", 30, Color("fff0f8"), Vector2(20, 10), Vector2(430, 42))
	top.add_child(title)
	var sub := label("SPIRIT ROAD • DEFEND THE REALM", 14, Color("a9b5e9"), Vector2(22, 49), Vector2(500, 26))
	top.add_child(sub)
	coins_label = label("✦ 320", 21, Color("ffe58b"), Vector2(22, 91), Vector2(140, 38))
	hearts_label = label("♥ 20", 21, Color("ff8dac"), Vector2(175, 91), Vector2(120, 38))
	wave_label = label("WAVE 0", 18, Color("a9edff"), Vector2(315, 93), Vector2(150, 34))
	top.add_child(coins_label)
	top.add_child(hearts_label)
	top.add_child(wave_label)
	message_label = label("TAP A CLEAR TILE TO SUMMON A GUARDIAN", 15, Color("fff0b0"), Vector2(32, 181), Vector2(660, 38))
	ui.add_child(message_label)
	var bottom := panel(Vector2(18, -286), Vector2(-18, -18), false)
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	var heroes_title := label("CHOOSE YOUR GUARDIAN", 14, Color("b7c4f4"), Vector2(16, 10), Vector2(400, 24))
	bottom.add_child(heroes_title)
	for i in range(HEROES.size()):
		var kind: String = HEROES[i]
		var b := button(NAMES[kind] + "\n" + ROLES[kind] + "\n✦ " + str(COSTS[kind]), Color(COLORS[kind]), Vector2(14 + i * 206, 39), Vector2(194, 75))
		b.pressed.connect(select_hero.bind(kind))
		bottom.add_child(b)
		hero_buttons[kind] = b
	upgrade_button = button("SELECT A GUARDIAN", Color("91e9ff"), Vector2(14, 127), Vector2(240, 56))
	upgrade_button.pressed.connect(upgrade_selected)
	bottom.add_child(upgrade_button)
	ultimate_button = button("SPIRIT BURST  0%", Color("f6a5ff"), Vector2(264, 127), Vector2(235, 56))
	ultimate_button.pressed.connect(cast_ultimate)
	bottom.add_child(ultimate_button)
	wave_button = button("START WAVE 1  ▶", Color("ffe58b"), Vector2(509, 127), Vector2(220, 56))
	wave_button.pressed.connect(start_wave)
	bottom.add_child(wave_button)
	for kind in HEROES: style_hero_button(kind)

func panel(pos: Vector2, size: Vector2, top_panel: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.18, 0.91)
	style.border_color = Color("7467a8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	p.add_theme_stylebox_override("panel", style)
	ui.add_child(p)
	return p

func label(text: String, size: int, color: Color, pos: Vector2, dims: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = dims
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color("1a1534"))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func button(text: String, color: Color, pos: Vector2, dims: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = dims
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color("fff7ff"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.35, color.g * 0.32, color.b * 0.4, 0.95)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(color.r * 0.48, color.g * 0.42, color.b * 0.52, 1)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b

func cell_position(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - 3.0) * CELL, 0.2, (cell.y - 3.5) * CELL)

func material(color: Color, roughness := 0.55, emission := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 0.8
	return m
