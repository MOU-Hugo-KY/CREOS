extends Node3D
## Scène de combat jouable : relie le BattleEngine (logique) à l'affichage 3D, aux sons et à
## l'interface. Tout est construit par code pour rester simple à modifier par Claude ou à la main.
##
## Le moteur applique les dégâts tout de suite ; l'affichage, lui, les montre à l'instant de
## l'impact dans l'animation (`hit_time` de l'attaque, + la course pour le corps-à-corps).

const DUNGEON_ID := "brumenoire_1"
const TEAM := ["torvald", "kaito", "vesprin", "orage"]
const HERO_SPOTS := [Vector3(-2.6, 0, 0.6), Vector3(-4.4, 0, -1.6), Vector3(-4.6, 0, 2.6), Vector3(-6.6, 0, 0.4)]
const ENEMY_SPOTS := [Vector3(2.6, 0, 0.6), Vector3(4.4, 0, -1.6), Vector3(4.6, 0, 2.6), Vector3(6.6, 0, 0.4)]
const BOSS_SPOT := Vector3(5.2, 0, 0.0)
const HERO_YAW := 62.0  # de trois quarts vers la caméra (90 = profil pur)
const INTRO_HOLD := 1.4  # pause d'affichage au début de chaque vague (apparition des ennemis)
const END_DELAY := 1.4

var engine := BattleEngine.new()
var views: Dictionary = {}  # uid -> UnitView
var unit_data: Dictionary = {}  # uid -> Dictionary

var hud: BattleHud
var fx: BattleFx
var audio: BattleAudio
var camera: Camera3D

var _units_root: Node3D
var _pending: Array = []  # [{t, fn}] événements à afficher plus tard (instant d'impact)
var _clock := 0.0
var _hold := 0.0
var _hero_stats: Dictionary = {}  # uid -> {damage, healing}
var _last_sound: Dictionary = {}  # nom -> heure (évite 4 fois le même son au même instant)
var _ended := false
var _event_seq := 0


func _ready() -> void:
	_build_world()
	audio = BattleAudio.new()
	add_child(audio)
	hud = BattleHud.new()
	hud.camera = camera
	add_child(hud)
	hud.attack_requested.connect(_on_attack_requested)
	hud.auto_toggled.connect(func(on: bool) -> void:
		engine.auto_mode = on
		if on:
			_end_turn())
	hud.speed_toggled.connect(func(fast: bool) -> void: Engine.time_scale = 2.0 if fast else 1.0)
	hud.restart_requested.connect(func() -> void: start_battle(randi()))
	hud.ui_sound.connect(func(s: String) -> void: audio.play(s, -4.0, 0.0))
	start_battle(randi())


func start_battle(rng_seed: int) -> void:
	for c in _units_root.get_children():
		c.queue_free()
	views.clear()
	unit_data.clear()
	_pending.clear()
	_hero_stats.clear()
	_ended = false
	hud.reset()
	var was_auto := engine.auto_mode
	engine = BattleEngine.new()
	var team_data: Array = TEAM.map(func(id: String) -> Dictionary: return GameData.hero(id))
	engine.setup(team_data, GameData.dungeon_waves(DUNGEON_ID), rng_seed)
	engine.auto_mode = was_auto
	hud.set_auto(was_auto)
	for i in engine.heroes.size():
		var h := engine.heroes[i]
		_spawn(h, team_data[i], HERO_SPOTS[i], HERO_YAW)
		_hero_stats[h.uid] = {"damage": 0.0, "healing": 0.0}
	audio.play_music("battle_loop")
	_handle_events()


func set_auto(on: bool) -> void:
	engine.auto_mode = on
	if hud:
		hud.set_auto(on)


func _process(delta: float) -> void:
	_clock += delta
	if _hold > 0.0:
		_hold -= delta
	else:
		engine.step(delta)
		_handle_events()
	_run_pending()
	hud.refresh(delta)


func _on_attack_requested(uid: int, slot: int) -> void:
	if engine.request_attack(uid, slot):
		audio.play("ui_click", -6.0, 0.0)
		_end_turn(slot)
		_handle_events()


## Clavier : 1, 2, 3 choisissent l'attaque du héros dont c'est le tour.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or engine.awaiting_uid == -1:
		return
	var slot := key.keycode - KEY_1
	if slot >= 0 and slot <= 2:
		_on_attack_requested(engine.awaiting_uid, slot)


func _begin_turn(uid: int) -> void:
	var v: UnitView = views.get(uid)
	if v == null:
		return
	v.set_highlight(true)
	hud.begin_turn(v.unit)
	_sfx("ui_ready", -10.0)


func _end_turn(slot := -1) -> void:
	for uid in views:
		views[uid].set_highlight(false)
	hud.end_turn(slot)


# --- Événements du moteur -> affichage ----------------------------------------

func _handle_events() -> void:
	# Attaque en cours : décalage (course) + instants d'impact. Le k-ième coup reçu par une cible
	# s'affiche au k-ième instant (`hit_times`), le reste (états, mort) après son dernier coup.
	var offset := 0.0
	var times: Array = [0.0]
	var hits_per_dst: Dictionary = {}
	var last_time: Dictionary = {}
	var max_time := 0.0
	for ev in engine.drain_events():
		_event_seq += 1
		ev["seq"] = _event_seq
		match ev.type:
			"wave_start":
				offset = 0.0
				times = [0.0]
				hits_per_dst.clear()
				last_time.clear()
				_on_wave_start(ev)
			"turn":
				_begin_turn(ev.src)
			"attack":
				var delay := _on_attack(ev)
				times = ev.hit_times
				offset = delay - float(times[0])
				hits_per_dst.clear()
				last_time.clear()
			_:
				var t := 0.0
				if ev.get("dot", false):
					t = 0.0
				elif ev.type == "damage":
					var k: int = hits_per_dst.get(ev.dst, 0)
					hits_per_dst[ev.dst] = k + 1
					t = offset + float(times[mini(k, times.size() - 1)])
					last_time[ev.dst] = maxf(last_time.get(ev.dst, 0.0), t)
				elif ev.has("dst"):
					t = last_time.get(ev.dst, offset + float(times[0]))
				else:
					t = max_time  # victoire / défaite : après le dernier coup
				max_time = maxf(max_time, t)
				var event: Dictionary = ev
				_schedule(t, func() -> void: _on_impact(event))


func _on_wave_start(ev: Dictionary) -> void:
	_spawn_wave()
	hud.set_wave(ev.index, ev.count)
	var has_boss := engine.enemies.any(func(u: BattleUnit) -> bool: return u.is_boss)
	var sub := "Le boss arrive !" if has_boss else ""
	hud.banner("Vague %d / %d" % [ev.index + 1, ev.count], sub)
	audio.play("wave_start", -3.0, 0.0)
	if has_boss:
		audio.play_music("boss_loop")
		fx.shake(0.5)
	_hold = INTRO_HOLD


## Lance l'animation d'attaque et ses effets. Renvoie le délai avant le premier impact.
func _on_attack(ev: Dictionary) -> float:
	var v: UnitView = views.get(ev.src)
	if v == null:
		return 0.0
	var atk_data: Dictionary = v.unit.attacks[ev.slot]
	var targets: Array[UnitView] = []
	for uid: int in ev.targets:
		if views.has(uid):
			targets.append(views[uid])
	var offensive := targets.any(func(t: UnitView) -> bool: return t.unit.team != v.unit.team)
	var melee := offensive and v.unit.range_type == "melee"
	var color := Palette.element_color(v.unit.element)
	var dash_to: Variant = null
	if melee and atk_data.get("dash", true) and not targets.is_empty():
		dash_to = targets[0].home_position
	var delay := v.play_attack(ev.anim, ev.hit_time, dash_to)
	var hit_offsets: Array = ev.hit_times.map(func(h: float) -> float: return delay - float(ev.hit_time) + h)

	# Sons de départ.
	if melee:
		for h: float in hit_offsets:
			_schedule(maxf(0.0, h - 0.15), func() -> void: _sfx("swing", -2.0))
	elif v.unit.attack_kind == "magic" or not offensive:
		_sfx("magic_cast", -8.0)
	else:
		_schedule(maxf(0.0, delay - 0.3), func() -> void: _sfx("throw", -3.0))

	_play_attack_fx(v, atk_data.get("fx", ""), targets, offensive, melee, color, delay, hit_offsets, atk_data)

	match int(ev.slot):
		BattleUnit.SLOT_COOLDOWN:
			v.popup(ev.name, Palette.COOLDOWN.lightened(0.3), false, 2.9)
		BattleUnit.SLOT_ULTIMATE:
			hud.callout(ev.name, v.unit.display_name, color, v.unit.team == 0)
			fx.aura(v.global_position, color)
			fx.ring(v.global_position, color, 2.5)
			_sfx("ui_ready", -4.0)
			if offensive:
				_schedule(delay, func() -> void:
					fx.shake(0.7)
					_sfx("ultimate_impact", 0.0))
	return delay


## Effets visuels d'une attaque. `fx` vient du JSON de l'attaque (sinon : effet par défaut).
func _play_attack_fx(v: UnitView, fx_name: String, targets: Array[UnitView], offensive: bool, melee: bool,
		color: Color, delay: float, hit_offsets: Array, atk_data: Dictionary) -> void:
	match fx_name:
		"vial":
			# Fiole lancée en cloche, qui éclate en petit nuage.
			if targets.is_empty():
				return
			var tgt := targets[0]
			var travel := minf(0.3, delay)
			_schedule(delay - travel, func() -> void:
				fx.projectile(v.chest_position() + Vector3(0, 0.5, 0), tgt.chest_position(), color, travel, 0.25)
				_sfx("throw", -4.0))
			_schedule(delay, func() -> void:
				fx.cloud(tgt.global_position, Color(color, 0.5), 1.5))
		"poison_pool":
			var duration := 4.0
			for e: Dictionary in atk_data.get("effects", []):
				if e.get("type") == "dot":
					duration = e.get("duration", duration)
			_schedule(delay, func() -> void:
				for t in targets:
					fx.pool(t.global_position, color, duration)
				_sfx("magic_shot", -8.0))
		"poison_burst":
			_schedule(delay, func() -> void:
				fx.cloud(v.global_position, Color(color, 0.6), 3.0)
				fx.ring(v.global_position, color, 7.0)
				for t in targets:
					fx.cloud(t.global_position, Color(color, 0.45), 1.6))
		"lightning_hit":
			for h: float in hit_offsets:
				_schedule(h, func() -> void:
					for t in targets:
						fx.lightning(v.chest_position(), t.chest_position(), color, 5)
					_sfx("magic_shot", -6.0))
		"sky_lightning":
			_schedule(delay, func() -> void:
				if not targets.is_empty():
					fx.sky_lightning(targets[0].global_position, color))
			_schedule(delay + 0.12, func() -> void:
				for i in range(1, targets.size()):
					fx.lightning(targets[0].chest_position(), targets[i].chest_position(), color, 7)
					fx.burst(targets[i].chest_position(), color, false))
		"whirlwind":
			for h: float in hit_offsets:
				_schedule(h, func() -> void: fx.ring(v.global_position, color, 3.2))
		"ground_slam":
			_schedule(delay, func() -> void:
				fx.ring(v.global_position, color, 6.0)
				fx.cloud(v.global_position, Color(0.45, 0.4, 0.33, 0.5), 2.0)
				fx.shake(0.6))
		_:
			# Par défaut : boule magique (une cible à distance) ou éclats sur chaque cible (zone).
			if offensive and not melee:
				if targets.size() == 1:
					var travel := minf(0.3, delay)
					var tgt := targets[0]
					_schedule(delay - travel, func() -> void:
						fx.projectile(v.chest_position() + Vector3(0, 0.3, 0), tgt.chest_position(), color, travel)
						if v.unit.attack_kind == "magic":
							_sfx("magic_shot", -10.0))
				else:
					_schedule(delay, func() -> void:
						for t in targets:
							fx.burst(t.chest_position(), color, true))
	if not offensive:
		var is_heal: bool = atk_data.get("effects", [{}])[0].get("type") == "heal"
		_schedule(delay, func() -> void:
			for t in targets:
				fx.aura(t.global_position, Palette.HEAL if is_heal else Palette.SHIELD))


func _on_impact(ev: Dictionary) -> void:
	match ev.type:
		"damage":
			var t: UnitView = views.get(ev.dst)
			if t == null:
				return
			_set_shown_hp(t, ev)
			var src: UnitView = views.get(ev.src)
			var color := Palette.element_color(src.unit.element) if src else Color.WHITE
			if ev.get("dot", false):
				t.popup(str(int(ev.amount)), Color(0.75, 0.55, 1.0), false, 1.6)
				t.flash(Color(0.6, 0.3, 0.9), 0.35)
			else:
				t.play_hit(color.lightened(0.4))
				fx.burst(t.chest_position(), color, ev.crit)
				var txt := str(int(ev.amount)) + ("!" if ev.crit else "")
				if int(ev.amount) <= 0:
					txt = "Absorbé"
				var popup_color := Color.WHITE
				if ev.crit:
					popup_color = Palette.GOLD
				elif ev.elem_mult > 1.0:
					popup_color = Color(1, 0.45, 0.3)
				elif ev.elem_mult < 1.0:
					popup_color = Color(0.65, 0.65, 0.72)
				t.popup(txt, popup_color, ev.crit)
				if ev.crit:
					fx.shake(0.35)
					_sfx("hit_heavy", -1.0)
				else:
					_sfx("hit", -4.0)
			if src and _hero_stats.has(src.unit.uid):
				_hero_stats[src.unit.uid].damage += ev.amount
		"heal":
			var t: UnitView = views.get(ev.dst)
			if t == null:
				return
			_set_shown_hp(t, ev)
			t.popup("+" + str(int(ev.amount)), Palette.HEAL)
			t.flash(Palette.HEAL, 0.5)
			_sfx("heal", -6.0)
			if _hero_stats.has(ev.src):
				_hero_stats[ev.src].healing += ev.amount
		"shield":
			var t: UnitView = views.get(ev.dst)
			if t:
				t.popup("Bouclier", Palette.SHIELD)
				t.flash(Palette.SHIELD, 0.5)
				_sfx("shield", -6.0)
		"status":
			var t: UnitView = views.get(ev.dst)
			if t:
				var labels := {"stun": "Étourdi !", "taunt": "Provocation !", "dot": ""}
				var text: String = labels.get(ev.status, "")
				if text != "":
					t.popup(text, Palette.GOLD, false, 3.0)
		"death":
			var t: UnitView = views.get(ev.dst)
			if t:
				t.shown_hp = 0.0
				t.hp_seq = ev.seq
				t.play_death()
				_sfx("death", -2.0)
		"victory":
			_end_battle(true)
		"defeat":
			_end_battle(false)


func _end_battle(won: bool) -> void:
	if _ended:
		return
	_ended = true
	_end_turn()
	if won:
		for uid in views:
			var v: UnitView = views[uid]
			if v.unit.team == 0:
				v.play_cheer()
	hud.banner("VICTOIRE !" if won else "DÉFAITE…", "", 0.8)
	audio.stop_music(0.4)
	var stars := engine.stars()
	var rewards := GameData.dungeon_rewards(DUNGEON_ID, stars)
	var stats: Array = []
	for h in engine.heroes:
		stats.append({
			"name": h.display_name, "element": h.element, "alive": h.is_alive(),
			"damage": _hero_stats[h.uid].damage, "healing": _hero_stats[h.uid].healing,
		})
	var dungeon_name: String = GameData.dungeon(DUNGEON_ID).get("name", "")
	_schedule(END_DELAY, func() -> void:
		audio.play_music("victory" if won else "defeat", false)
		hud.show_end(won, stars, rewards, stats, dungeon_name))


# --- Outils -------------------------------------------------------------------

## Les impacts sont affichés en différé : on ignore un ancien événement qui arriverait après
## un plus récent (sinon un mort pourrait « reprendre » des PV).
func _set_shown_hp(v: UnitView, ev: Dictionary) -> void:
	if ev.seq > v.hp_seq and not v.is_dead():
		v.shown_hp = ev.hp
		v.hp_seq = ev.seq

func _schedule(delay: float, fn: Callable) -> void:
	if delay <= 0.0:
		fn.call()
	else:
		_pending.append({"t": _clock + delay, "fn": fn})


func _run_pending() -> void:
	if _pending.is_empty():
		return
	var due: Array = []
	var keep: Array = []
	for p: Dictionary in _pending:
		(due if p.t <= _clock else keep).append(p)
	_pending = keep
	for p: Dictionary in due:
		p.fn.call()


func _sfx(sfx_name: String, volume_db := 0.0) -> void:
	if _clock - float(_last_sound.get(sfx_name, -1.0)) < 0.06:
		return
	_last_sound[sfx_name] = _clock
	audio.play(sfx_name, volume_db)


func _spawn_wave() -> void:
	for uid in views.keys():
		var v: UnitView = views[uid]
		if v.unit.team == 1:
			v.queue_free()
			views.erase(uid)
			hud.remove_overhead(uid)
	for i in engine.enemies.size():
		var e := engine.enemies[i]
		var spot: Vector3 = BOSS_SPOT if e.is_boss else ENEMY_SPOTS[i % ENEMY_SPOTS.size()]
		_spawn(e, GameData.monster(e.def_id), spot, -HERO_YAW)


func _spawn(u: BattleUnit, data: Dictionary, pos: Vector3, yaw_deg: float) -> void:
	var v := UnitView.new()
	_units_root.add_child(v)
	v.position = pos
	v.rotation_degrees.y = yaw_deg
	v.setup(u, data)
	views[u.uid] = v
	unit_data[u.uid] = data
	hud.add_overhead(v)


# --- Monde 3D ----------------------------------------------------------------

func _build_world() -> void:
	add_child(MarshLevel.new())

	camera = Camera3D.new()
	camera.position = Vector3(0, 8.6, 13.2)
	camera.rotation_degrees = Vector3(-27, 0, 0)
	camera.fov = 48
	add_child(camera)

	fx = BattleFx.new()
	add_child(fx)
	fx.setup(camera)

	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)
