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
const HERO_SPOTS := [Vector3(-2.5, 0, 0.0), Vector3(-4.2, 0, -2.0), Vector3(-4.2, 0, 2.0), Vector3(-6.0, 0, 0.0)]
const ENEMY_SPOTS := [Vector3(2.5, 0, 0.0), Vector3(4.2, 0, -2.0), Vector3(4.2, 0, 2.0), Vector3(6.0, 0, 0.0)]

var engine := BattleEngine.new()
var views: Dictionary = {}  # uid -> UnitView
var unit_data: Dictionary = {}  # uid -> Dictionary

var _visual_events: Array[Dictionary] = []
var _visual_sequence := 0
var _visual_time := 0.0
var _effects_until := 0.0
var _actions_until := 0.0

var _units_root: Node3D
var _hud: CanvasLayer
var _hero_buttons: Dictionary = {}  # uid -> Button
var _banner: Label
var _auto_button: CheckButton
var _restart_button: Button
var _banner_tween: Tween


func _ready() -> void:
	_build_world()
	_build_hud()
	start_battle(randi())


func start_battle(rng_seed: int) -> void:
	_visual_events.clear()
	_visual_sequence = 0
	_visual_time = 0.0
	_effects_until = 0.0
	_actions_until = 0.0
	for c in _units_root.get_children():
		_units_root.remove_child(c)
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
	_visual_time += delta
	engine.step(delta)
	_handle_events()
	for uid in views:
		views[uid].refresh()
	_refresh_hero_buttons()


# --- Événements du moteur -> affichage ----------------------------------------

func _handle_events() -> void:
	var impact_time := _visual_time
	for ev in engine.drain_events():
		if ev.type in ["attack", "skill"]:
			var actor: UnitView = views.get(ev.src)
			var target: UnitView = views.get(ev.targets[0]) if not ev.targets.is_empty() else null
			if is_instance_valid(actor):
				var timing := actor.play_action(target, ev.type == "skill")
				impact_time = _visual_time + float(timing.impact)
				_actions_until = maxf(_actions_until, _visual_time + float(timing.duration))
				if ev.type == "skill":
					actor.popup(ev.name, Color.GOLD, true)
			continue
		var due := _visual_time
		if ev.type in ["damage", "heal", "shield", "status", "death"]:
			# Conserver l'ordre des PV et des morts, même si deux gestes se croisent.
			due = maxf(impact_time, _effects_until)
			_effects_until = due
		elif ev.type in ["wave_start", "victory", "defeat"]:
			due = maxf(_visual_time, maxf(_effects_until, _actions_until))
		_visual_sequence += 1
		_visual_events.append({"due": due, "order": _visual_sequence, "event": ev})
	_flush_visual_events()


func _flush_visual_events() -> void:
	# Tri stable : dégâts puis mort, et dernière mort puis victoire.
	_visual_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.order < b.order if a.due == b.due else a.due < b.due)
	while not _visual_events.is_empty() and float(_visual_events[0].due) <= _visual_time:
		_present_event(_visual_events.pop_front().event)


func _present_event(ev: Dictionary) -> void:
	match ev.type:
		"wave_start":
			_spawn_wave()
			_show_banner("Vague %d / %d" % [ev.index + 1, ev.count])
		"damage":
			_view(ev.dst, func(v: UnitView) -> void:
				v.displayed_hp = ev.hp
				v.play_hit()
				var color := Color.ORANGE if ev.crit else Color.WHITE
				if ev.elem_mult > 1.0:
					color = Color(1, 0.3, 0.2)
				elif ev.elem_mult < 1.0:
					color = Color(0.6, 0.6, 0.7)
				v.popup(str(int(ev.amount)) + ("!" if ev.crit else ""), color, ev.crit))
		"heal":
			_view(ev.dst, func(v: UnitView) -> void:
				v.displayed_hp = ev.hp
				v.popup("+" + str(int(ev.amount)), Color.LIME_GREEN))
		"shield":
			_view(ev.dst, func(v: UnitView) -> void:
				v.show_shield()
				v.popup("Bouclier", Color.SKY_BLUE))
		"death":
			_view(ev.dst, func(v: UnitView) -> void: v.play_death())
		"victory":
			for v: UnitView in views.values():
				if v.unit.team == 0:
					v.play_victory()
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
	e.background_color = Color(0.09, 0.08, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.7)
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.25, 0.3, 0.3)
	e.fog_density = 0.02
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 9.5, 13.5)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.fov = 50
	add_child(cam)

	var tile: PackedScene = load(FLOOR_TILE)
	if tile:
		for x in range(-4, 4):
			for z in range(-3, 3):
				var t := tile.instantiate() as Node3D
				t.position = Vector3(x * 4 + 2, 0, z * 4 + 2)
				add_child(t)
	for path in PROPS:
		var scene: PackedScene = load(path)
		if scene == null:
			continue
		for p: Vector3 in PROPS[path]:
			var prop := scene.instantiate() as Node3D
			prop.position = p
			add_child(prop)

	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)


# --- Interface ---------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
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
		var hp_pct := int(100.0 * (views[uid] as UnitView).displayed_hp / u.max_hp)
		var en_pct := int(u.energy)
		b.text = "%s\nPV %d%%   Énergie %d%%\n%s" % [
			u.display_name, hp_pct, en_pct,
			("▶ " + u.skill.get("name", "")) if u.skill_ready() else u.skill.get("name", ""),
		]
		b.disabled = not u.skill_ready()
		b.modulate = Color(1, 1, 1) if u.is_alive() else Color(0.4, 0.4, 0.4)


func _show_banner(text: String, duration := 2.0) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.text = text
	_banner.modulate.a = 1.0
	if duration > 0.0:
		_banner_tween = create_tween()
		_banner_tween.tween_interval(duration)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
