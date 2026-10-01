extends Node3D
## Scène de combat jouable : relie le BattleEngine (logique) à l'affichage 3D et à l'interface.
## Tout est construit par code pour rester simple à modifier par Claude ou à la main.

const DUNGEON_ID := "brumenoire_1"
const TEAM := ["brannoc", "kaela", "ysolde", "aubeline"]
const FLOOR_TILE := "res://assets/kaykit/dungeon/Assets/floor_tile_large.gltf.glb"
const PROPS := {
	"res://assets/kaykit/dungeon/Assets/torch_lit.gltf.glb": [Vector3(-4, 0, -5), Vector3(4, 0, -5)],
	"res://assets/kaykit/dungeon/Assets/pillar_decorated.gltf.glb": [Vector3(-8, 0, -6), Vector3(8, 0, -6)],
	"res://assets/kaykit/dungeon/Assets/chest_gold.glb": [Vector3(0, 0, -6)],
	"res://assets/kaykit/dungeon/Assets/barrel_large.gltf.glb": [Vector3(-9, 0, -3.5)],
	"res://assets/kaykit/dungeon/Assets/rubble_large.gltf.glb": [Vector3(9.5, 0, -4)],
}
const FLOOR_TINT := Color(0.42, 0.5, 0.45)  # dalles du marais de Brumenoire
const HERO_SPOTS := [Vector3(-2.2, 0, 0.3), Vector3(-4.0, 0, -2.6), Vector3(-4.6, 0, 2.6), Vector3(-6.4, 0, 0.0)]
const ENEMY_SPOTS := [Vector3(2.2, 0, 0.3), Vector3(4.0, 0, -2.6), Vector3(4.6, 0, 2.6), Vector3(6.4, 0, 0.0)]

var engine := BattleEngine.new()
var views: Dictionary = {}  # uid -> UnitView
var unit_data: Dictionary = {}  # uid -> Dictionary

var _units_root: Node3D
var _hud: CanvasLayer
var _hero_buttons: Dictionary = {}  # uid -> Button
var _banner: Label
var _auto_button: CheckButton
var _restart_button: Button


func _ready() -> void:
	_build_world()
	_build_hud()
	start_battle(randi())


func start_battle(rng_seed: int) -> void:
	for c in _units_root.get_children():
		c.queue_free()
	views.clear()
	unit_data.clear()
	engine = BattleEngine.new()
	var team_data: Array = TEAM.map(func(id: String) -> Dictionary: return GameData.hero(id))
	engine.setup(team_data, GameData.dungeon_waves(DUNGEON_ID), rng_seed)
	engine.auto_mode = _auto_button.button_pressed
	for i in engine.heroes.size():
		_spawn(engine.heroes[i], team_data[i], HERO_SPOTS[i], 90.0)
	_rebuild_hero_buttons()
	_restart_button.visible = false
	_handle_events()


func _process(delta: float) -> void:
	engine.step(delta)
	_handle_events()
	for uid in views:
		views[uid].refresh()
	_refresh_hero_buttons()


# --- Événements du moteur -> affichage ----------------------------------------

func _handle_events() -> void:
	for ev in engine.drain_events():
		match ev.type:
			"wave_start":
				_spawn_wave()
				_show_banner("Vague %d / %d" % [ev.index + 1, ev.count])
			"attack":
				_view(ev.src, func(v: UnitView) -> void: v.play_attack())
			"skill":
				_view(ev.src, func(v: UnitView) -> void:
					v.play_skill()
					v.popup(ev.name, Color.GOLD, true))
			"damage":
				_view(ev.dst, func(v: UnitView) -> void:
					v.play_hit()
					var color := Color.ORANGE if ev.crit else Color.WHITE
					if ev.elem_mult > 1.0:
						color = Color(1, 0.3, 0.2)
					elif ev.elem_mult < 1.0:
						color = Color(0.6, 0.6, 0.7)
					v.popup(str(int(ev.amount)) + ("!" if ev.crit else ""), color, ev.crit))
			"heal":
				_view(ev.dst, func(v: UnitView) -> void: v.popup("+" + str(int(ev.amount)), Color.LIME_GREEN))
			"shield":
				_view(ev.dst, func(v: UnitView) -> void: v.popup("Bouclier", Color.SKY_BLUE))
			"death":
				_view(ev.dst, func(v: UnitView) -> void: v.play_death())
			"victory":
				_show_banner("VICTOIRE ! Brumenoire recule…", 0.0)
				_restart_button.visible = true
			"defeat":
				_show_banner("Défaite… Morvath gagne du terrain.", 0.0)
				_restart_button.visible = true


func _view(uid: int, fn: Callable) -> void:
	if views.has(uid):
		fn.call(views[uid])


func _spawn_wave() -> void:
	for uid in views.keys():
		var v: UnitView = views[uid]
		if v.unit.team == 1:
			v.queue_free()
			views.erase(uid)
	for i in engine.enemies.size():
		var e := engine.enemies[i]
		_spawn(e, GameData.monster(e.def_id), ENEMY_SPOTS[i % ENEMY_SPOTS.size()], -90.0)


func _spawn(u: BattleUnit, data: Dictionary, pos: Vector3, yaw_deg: float) -> void:
	var v := UnitView.new()
	_units_root.add_child(v)
	v.position = pos
	v.rotation_degrees.y = yaw_deg
	v.setup(u, data)
	views[u.uid] = v
	unit_data[u.uid] = data


# --- Monde 3D ----------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.09, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.5, 0.75)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	e.adjustment_contrast = 1.05
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	# Caméra orthographique : pas de perspective, rendu net façon pixel art.
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 12.5
	cam.position = Vector3(0, 10, 14)
	cam.rotation_degrees = Vector3(-35, 0, 0)
	add_child(cam)

	var tile: PackedScene = load(FLOOR_TILE)
	if tile:
		for x in range(-4, 4):
			for z in range(-3, 3):
				var t := tile.instantiate() as Node3D
				t.position = Vector3(x * 4 + 2, 0, z * 4 + 2)
				add_child(t)
				PixelStyle.apply(t, false, FLOOR_TINT)
	for path in PROPS:
		var scene: PackedScene = load(path)
		if scene == null:
			continue
		for p: Vector3 in PROPS[path]:
			var prop := scene.instantiate() as Node3D
			prop.position = p
			add_child(prop)
			PixelStyle.apply(prop)

	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)


# --- Interface ---------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"  # PixelStage la déplace hors du rendu basse résolution
	add_child(_hud)

	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 40
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 56)
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_child(_banner)

	var bar := HBoxContainer.new()
	bar.name = "HeroBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -190
	bar.offset_bottom = -24
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	_hud.add_child(bar)

	_auto_button = CheckButton.new()
	_auto_button.text = "Auto"
	_auto_button.add_theme_font_size_override("font_size", 36)
	_auto_button.position = Vector2(30, 30)
	_auto_button.toggled.connect(func(on: bool) -> void: engine.auto_mode = on)
	_hud.add_child(_auto_button)

	_restart_button = Button.new()
	_restart_button.text = "Rejouer"
	_restart_button.add_theme_font_size_override("font_size", 40)
	_restart_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_restart_button.visible = false
	_restart_button.pressed.connect(func() -> void: start_battle(randi()))
	_hud.add_child(_restart_button)


func _rebuild_hero_buttons() -> void:
	var bar: HBoxContainer = _hud.get_node("HeroBar")
	for c in bar.get_children():
		c.queue_free()
	_hero_buttons.clear()
	for h in engine.heroes:
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 150)
		b.add_theme_font_size_override("font_size", 28)
		var uid := h.uid
		b.pressed.connect(func() -> void: engine.request_skill(uid))
		bar.add_child(b)
		_hero_buttons[uid] = b
	_refresh_hero_buttons()


func _refresh_hero_buttons() -> void:
	for uid in _hero_buttons:
		var u := engine.get_unit(uid)
		var b: Button = _hero_buttons[uid]
		var hp_pct := int(100.0 * u.hp / u.max_hp)
		var en_pct := int(u.energy)
		b.text = "%s\nPV %d%%   Énergie %d%%\n%s" % [
			u.display_name, hp_pct, en_pct,
			("▶ " + u.skill.get("name", "")) if u.skill_ready() else u.skill.get("name", ""),
		]
		b.disabled = not u.skill_ready()
		b.modulate = Color(1, 1, 1) if u.is_alive() else Color(0.4, 0.4, 0.4)


func _show_banner(text: String, duration := 2.0) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	if duration > 0.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
