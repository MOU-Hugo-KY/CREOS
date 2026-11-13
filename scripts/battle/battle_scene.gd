extends Node2D
## Scène de combat jouable, entièrement en 2D : relie le BattleEngine (logique) au décor dessiné du
## monde, aux personnages animés (clips en pièces détachées), aux sons et à l'interface. Tout est
## construit par code. Repère de travail : cadre 1280 × 720 (pieds vers y = 590), agrandi à l'écran.
##
## Le moteur applique les dégâts tout de suite ; l'affichage, lui, les montre aux instants d'impact
## dessinés dans le clip de l'attaque (`hit_times`, repris des repères du clip).

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const FRAME := Vector2(1280, 720)
const TRAP_DELAY := 1.0  # un piège se déclenche une seconde après l'annonce de la salle
# Scène de quatuor (repère 512 × 288) posée sur le combat : ses cibles (≈ 374, 217) tombent sur la
# ligne ennemie et ses pieds de héros sur la ligne alliée.
const QUARTET_SCALE := 2.0
const QUARTET_ORIGIN := Vector2(82, 176)
# Formation en losange : devant, haut, bas, arrière (en pixels du cadre, point au sol).
## Ancien décor de côté : jusqu'à 8 places par camp, sur deux rangs en quinconce (le premier rang devant).
## (Dans un même rang, ceux de devant sont un poil plus bas : ils passent devant ceux de derrière.)
const HERO_SPOTS := [Vector2(575, 554), Vector2(520, 668), Vector2(450, 552), Vector2(395, 666),
	Vector2(325, 550), Vector2(270, 664), Vector2(200, 548), Vector2(145, 662)]
const ENEMY_SPOTS := [Vector2(705, 554), Vector2(760, 668), Vector2(830, 552), Vector2(885, 666),
	Vector2(955, 550), Vector2(1010, 664), Vector2(1080, 548), Vector2(1135, 662)]
const CROWD_SCALE := 0.78  # combattants un peu plus petits quand il y a plus de 4 héros
# Formation en colonnes, comme les règles du moteur (BattleUnit.line()) : places 0-1 devant (près
# de l'adversaire), 2-4 au milieu, 5-6 à l'arrière. Les ennemis en miroir.
const TOP_HEROES := [Vector2(505, 425), Vector2(505, 570), Vector2(335, 350), Vector2(335, 480),
	Vector2(335, 610), Vector2(165, 425), Vector2(165, 570)]
const TOP_ENEMIES := [Vector2(775, 425), Vector2(775, 570), Vector2(945, 350), Vector2(945, 480),
	Vector2(945, 610), Vector2(1115, 425), Vector2(1115, 570)]
# Personnages tous à la même taille. Héros : pixel source × 4,8 × 0,5 × TOP_SCALE × 1,5 (cadre 1280 → écran
# 1920) = exactement 3 pixels d'écran par pixel de dessin, pour un pixel art net.
const TOP_SCALE := 3.0 / (4.8 * 0.5 * 1.5)
const BOSS_SPOT := Vector2(1040, 604)
const INTRO_HOLD := 1.4  # pause d'affichage au début de chaque vague
const END_DELAY := 1.4
const STATUS_LABELS := {
	"taunt": "Provocation !", "stun": "Étourdi !", "marque": "Marqué", "mouille": "Mouillé",
	"desequilibre": "Déséquilibré", "aveugle": "Aveuglé", "scelle": "Scellé", "somnolence": "Somnolence",
	"ouverture": "Ouverture", "resonance": "Résonance", "enracine": "Enraciné", "petale": "Pétale",
	"armure_reduite": "Armure réduite", "brulure": "Brûlure", "poison": "Poison", "regen": "Régénération",
	"leurre": "Leurre", "garde": "Garde", "alarme": "Alarme", "protege": "Protégé", "retard": "Retard",
	"buff_def": "DEF ↑", "buff_atk": "ATQ ↑", "buff_crit": "Critique ↑", "buff_evade": "Esquive ↑",
	"buff_res": "Résistance ↑", "debuff_atk": "ATQ ↓", "debuff_def": "DEF ↓",
}

var engine := BattleEngine.new()
var dungeon_id := ""  # donjon choisi au hub (PlayerData.current_dungeon)
var lodge_battle: Dictionary = {}  # combat de Loge (PlayerData.current_lodge_battle), vide pour une chasse
var team_ids: Array = []  # équipe de chasse (PlayerData.team())
var views: Dictionary = {}  # uid -> UnitView
var unit_data: Dictionary = {}  # uid -> Dictionary

var hud: BattleHud
var fx: BattleFx
var fxlib: FxLibrary  # effets de lancer / d'impact pilotés par data/fx.json
var audio: BattleAudio
var camera: Camera2D
var stage: BattleStage

var _units_root: Node2D
var _pending: Array = []  # [{t, fn}] événements à afficher plus tard (instant d'impact)
var _clock := 0.0
var _hold := 0.0
var _hero_stats: Dictionary = {}  # uid -> {damage, healing}
var _last_sound: Dictionary = {}  # nom -> heure (évite 4 fois le même son au même instant)
var _ended := false
var _event_seq := 0

var _fx_ctx := {}  # uid -> contexte visuel de sa dernière attaque (FxLibrary.attack_context)
var _last_slot := {}  # uid -> emplacement de sa dernière attaque (coups lourds)
var _last_attack := {}  # uid -> id de sa dernière attaque (effets pixelfx, data/pixelfx.json)
var _pfx_seen := {}  # anti-doublon des effets pixelfx : clé -> instant (ms)
var _status_fx := {}  # uid -> {état -> sprite pixelfx en boucle} (data/pixelfx.json "statuses")


func _ready() -> void:
	dungeon_id = PlayerData.current_dungeon
	lodge_battle = PlayerData.current_lodge_battle
	if dungeon_id == "" or not GameData.dungeons.has(dungeon_id):
		dungeon_id = GameData.hub.get("first_hunt", "monde01_1")
	_build_world()
	audio = BattleAudio.new()
	add_child(audio)
	hud = BattleHud.new()
	add_child(hud)
	hud.attack_requested.connect(_on_attack_requested)
	hud.quartet_requested.connect(_on_quartet_requested)
	hud.combo_requested.connect(_on_combo_requested)
	hud.auto_toggled.connect(func(on: bool) -> void:
		engine.auto_mode = on
		if on:
			_end_turn())
	hud.speed_toggled.connect(func(fast: bool) -> void: Engine.time_scale = 2.0 if fast else 1.0)
	hud.draw_requested.connect(func() -> void:
		engine.declare_draw()
		_handle_events())
	hud.restart_requested.connect(func() -> void:
		if PlayerData.start_hunt(dungeon_id):
			start_battle(randi()))
	hud.hub_requested.connect(func() -> void:
		Engine.time_scale = 1.0
		PlayerData.current_lodge_battle = {}
		Transition.go(HUB_SCENE))
	hud.ui_sound.connect(func(s: String) -> void: audio.play(s, -4.0, 0.0))
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
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
	# Équipe choisie avant la chasse, avec les stats de chaque héros (niveau, Échos, relique).
	team_ids = PlayerData.team()
	var team_data: Array = team_ids.map(func(id: String) -> Dictionary:
		return PlayerData.hero_for_battle(id))
	if lodge_battle.is_empty():
		engine.setup(team_data, GameData.dungeon_waves_for(dungeon_id, team_data.size()), rng_seed,
			GameData.team_combos(), GameData.synergies())
	else:
		# Donjon d'une Loge : une vague par salle, des héros en défense, des pièges à l'entrée.
		var level := int(lodge_battle.get("level", 0))
		var hero_data := func(id: String) -> Dictionary:
			if level <= 0:
				return PlayerData.hero_for_battle(id)
			return Progression.hero_for_battle(GameData.hero(id), level, GameData.progression)
		engine.setup(team_data, Lodge.waves(lodge_battle.rooms, hero_data, lodge_battle.get("defenses", []),
			GameData.lodge), rng_seed, GameData.team_combos(),
			GameData.synergies(), Lodge.wave_traps(lodge_battle.traps, GameData.lodge))
	engine.auto_mode = was_auto
	hud.set_auto(was_auto)
	for i in engine.heroes.size():
		var h := engine.heroes[i]
		_spawn(h, team_data[i], _spot(0, i))
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
	var ready: Array = []
	if engine.awaiting_uid != -1:
		for cid: String in engine.ready_combos():
			var c := engine._combo(cid)
			ready.append({"id": cid, "attack": c.get("attack", ""), "size": c.members.size(), "members": c.members})
	hud.set_combos(ready)
	hud.refresh(delta)
	if not engine.finished and not hud.draw_button.visible and engine.time > draw_after():
		hud.draw_button.visible = true
	if not engine.finished:
		hud.turn_order.update_from(engine)


func _on_attack_requested(uid: int, slot: int) -> void:
	if _hold > 0.0:
		return  # une chaîne de réactions se joue encore : le tour suivant attend
	if engine.request_attack(uid, slot):
		audio.play("ui_click", -6.0, 0.0)
		_end_turn(slot)
		_handle_events()


func _on_quartet_requested() -> void:
	var ready := engine.ready_combos()
	if not ready.is_empty():
		_on_combo_requested(ready[0])


func _on_combo_requested(combo_id: String) -> void:
	if _hold > 0.0:
		return
	if engine.request_combo(engine.awaiting_uid, combo_id):
		audio.play("ui_ready", -2.0, 0.0)
		_end_turn()
		_handle_events()


## Toucher (ou cliquer) un ennemi le désigne comme cible de l'équipe.
## Clavier : 1, 2, 3 choisissent l'attaque du héros dont c'est le tour, 4 le quatuor, 5 la technique secrète.
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var enemy := _enemy_at(click.position)
		# Ligne protégée : le héros dont c'est le tour ne peut pas l'atteindre (corps-à-corps : la ligne
		# de devant d'abord ; à distance : l'arrière seulement quand la ligne de devant est tombée).
		if enemy and engine.awaiting_uid != -1 and not engine.can_reach(engine.awaiting_uid, enemy.unit.uid):
			enemy.popup("Protégé", Color("c9c1d6"))
			audio.play("ui_toggle", -8.0, 0.0)
			get_viewport().set_input_as_handled()
			return
		if enemy and engine.set_focus(enemy.unit.uid):
			audio.play("ui_click", -8.0, 0.0)
			_handle_events()
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or engine.awaiting_uid == -1:
		return
	if key.keycode == KEY_4:
		_on_quartet_requested()
		return
	if key.keycode == KEY_5:
		_on_attack_requested(engine.awaiting_uid, BattleUnit.SLOT_SECRET)
		return
	var slot := key.keycode - KEY_1
	if slot >= 0 and slot <= 2:
		_on_attack_requested(engine.awaiting_uid, slot)


## Ennemi vivant le plus proche du point touché à l'écran (rayon généreux pour le doigt).
func _enemy_at(screen_pos: Vector2) -> UnitView:
	var radius := 120.0 * get_viewport().get_visible_rect().size.y / 1080.0
	var best: UnitView = null
	var best_d := radius
	for uid in views:
		var v: UnitView = views[uid]
		if v.unit.team != 1 or v.is_dead():
			continue
		var d := v.chest_screen().distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = v
	return best


func _show_focus(target_uid: int) -> void:
	for uid in views:
		var v: UnitView = views[uid]
		if v.unit.team == 1:
			v.set_target_mark(uid == target_uid)


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
	# Le k-ième coup reçu par une cible s'affiche au k-ième instant d'impact du clip (`hit_times`),
	# le reste (états, mort) après son dernier coup.
	var offset := 0.0
	var times: Array = [0.0]
	var hits_per_dst: Dictionary = {}
	var last_time: Dictionary = {}
	var max_time := 0.0
	var chain_end := 0.0  # fin de la dernière attaque : les réactions jouent ensuite, l'une après l'autre
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
			"focus":
				_show_focus(ev.target)
			"attack", "quartet":
				if ev.type == "attack" and ev.slot == BattleUnit.SLOT_ULTIMATE and engine.get_unit(ev.src).team == 0:
					PlayerData.record_event("ultimate")  # prime du jour « Pleine puissance »
				if ev.get("reaction", false):
					# Réaction : après l'attaque qui l'a provoquée, avec un trait de lumière vers sa cible.
					var rev: Dictionary = ev
					var start := chain_end
					_schedule(start, func() -> void:
						_reaction_streak(rev)
						_on_attack(rev))
					offset = start
				else:
					offset = _on_attack(ev) if ev.type == "attack" else _on_quartet(ev)
				var ht: Array = ev.get("hit_times", [0.4])
				chain_end = offset + (float(ht[-1]) if not ht.is_empty() else 0.4) + 0.45
				_hold = maxf(_hold, chain_end if ev.get("reaction", false) else 0.0)
				times = ev.hit_times
				if times.is_empty():
					times = [0.4]
				hits_per_dst.clear()
				last_time.clear()
			"trap":
				# Le piège se déclenche juste après l'annonce de la salle ; ses dégâts suivent.
				offset = TRAP_DELAY
				times = [0.0]
				hits_per_dst.clear()
				last_time.clear()
				var trap_ev: Dictionary = ev
				_schedule(TRAP_DELAY, func() -> void: _on_trap(trap_ev))
			_:
				var t := 0.0
				if ev.get("dot", false):
					t = 0.0
				elif ev.type == "damage" or ev.type == "miss":
					var k: int = hits_per_dst.get(ev.dst, 0)
					hits_per_dst[ev.dst] = k + 1
					t = offset + float(times[mini(k, times.size() - 1)])
					last_time[ev.dst] = maxf(last_time.get(ev.dst, 0.0), t)
				elif ev.type == "status" and ev.get("status", "") == "reaction":
					t = chain_end  # le nom de la réaction s'affiche quand le héros intervient
				elif ev.type == "reaction":
					t = chain_end
					if String(ev.get("action", "")) in ["shield", "transform"]:
						chain_end += 0.6  # pas d'attaque : on laisse le temps de voir l'effet
						_hold = maxf(_hold, chain_end)
				elif ev.has("dst"):
					t = last_time.get(ev.dst, offset + float(times[0]))
				else:
					t = max_time  # victoire / défaite : après le dernier coup
				max_time = maxf(max_time, t)
				var event: Dictionary = ev
				_schedule(t, func() -> void: _on_impact(event))


## Trait de lumière du héros qui réagit vers sa cible (lien visible entre les deux).
func _reaction_streak(ev: Dictionary) -> void:
	var v: UnitView = views.get(ev.src)
	if v == null:
		return
	var color := Palette.element_color(v.unit.element).lightened(0.3)
	fx.aura(v.position, color)
	for uid: int in ev.get("targets", []).slice(0, 3):
		var t: UnitView = views.get(uid)
		if t and t != v:
			fx.add_child(Projectile.new().setup(v.chest_position(), t.chest_position(), 0.18, color, true))


## Piège de Loge : son nom s'affiche et il éclate sur les combattants touchés.
func _on_trap(ev: Dictionary) -> void:
	var element := String(ev.get("element", ""))
	hud.callout(String(ev.name), "Piège", Palette.element_color(element), true)
	for uid: int in ev.targets:
		var v: UnitView = views.get(uid)
		if v and not v.is_dead():
			fx.element_hit(v.chest_position(), element, true)
			v.flash(Palette.element_color(element), 0.5)
	fx.shake(0.3)
	_sfx("ultimate_impact", -6.0)


func _on_wave_start(ev: Dictionary) -> void:
	_spawn_wave()
	hud.set_wave(ev.index, ev.count)
	var has_boss := engine.enemies.any(func(u: BattleUnit) -> bool: return u.is_boss)
	var sub := "Le boss arrive !" if has_boss else ""
	var title := "Vague %d / %d" % [ev.index + 1, ev.count]
	if not lodge_battle.is_empty():  # salles de la Loge
		var rooms: Array = GameData.lodge.get("rooms", [])
		title = String(rooms[ev.index].name) if ev.index < rooms.size() else title
		sub = "Salle %d / %d" % [ev.index + 1, ev.count]
	hud.banner(title, sub)
	audio.play("wave_start", -3.0, 0.0)
	if has_boss:
		audio.play_music("boss_loop")
		fx.shake(0.5)
	_hold = INTRO_HOLD


## Lance le clip de l'attaque. Renvoie le délai avant le premier impact.
func _on_attack(ev: Dictionary) -> float:
	var v: UnitView = views.get(ev.src)
	if v == null:
		return 0.0
	var clip := String(ev.get("clip", ""))
	# Les effets du clip tombent sur la cible (au centre du groupe pour une attaque de zone).
	var aim := Vector2.INF
	var hits: Array = []
	for uid: int in ev.get("targets", []):
		if views.has(uid) and views[uid] != v:
			hits.append(views[uid].chest_position())
	if not hits.is_empty():
		aim = Vector2.ZERO
		for p: Vector2 in hits:
			aim += p
		aim /= hits.size()
	var delay := v.play_attack(clip, 0.0, aim)
	_last_slot[int(ev.src)] = int(ev.slot)
	_last_attack[int(ev.src)] = String(ev.get("attack_id", ""))
	var ctx := FxLibrary.attack_context(v.unit, _attack_data(int(ev.src), String(ev.get("attack_id", ""))), int(ev.slot))
	_fx_ctx[int(ev.src)] = ctx
	_fxl().cast(v.position + Vector2(0, -20), ctx)
	_launch_projectiles(v, ev, delay)
	# attaques sans dégâts ni soin (bouclier, renfort) : leur effet pixelfx éclate sur les cibles au moment du coup
	var adata := _attack_data(int(ev.src), String(ev.get("attack_id", "")))
	var kinds: Array = (adata.get("effects", []) as Array).map(func(x): return String(x.get("type", "")))
	if not PixelFx.entry(String(ev.get("attack_id", ""))).is_empty() and not kinds.has("damage") and not kinds.has("heal"):
		var src_uid := int(ev.src)
		for uid: int in ev.get("targets", []):
			var tu := uid
			_schedule(delay, func() -> void: _pixel_hit(views.get(src_uid), views.get(tu)))
	fx.dust(v.position, 0.8)  # appui au sol au départ de l'attaque
	var color := Palette.element_color(v.unit.element)
	if int(ev.slot) == BattleUnit.SLOT_COOLDOWN:
		v.popup(ev.name, Palette.COOLDOWN.lightened(0.3), false, 1.6)
	elif int(ev.slot) == BattleUnit.SLOT_SECRET:
		v.popup(ev.name, Palette.GOLD, true, 1.6)
	elif int(ev.slot) == BattleUnit.SLOT_ULTIMATE:
		hud.callout(ev.name, v.unit.display_name, color, v.unit.team == 0)
		fx.aura(v.position, color)
		stage.ambience.set_ultimate_active(true)
		_schedule(maxf(1.5, v.clip_duration(clip) - 0.3), func() -> void:
			stage.ambience.set_ultimate_active(false))
		_sfx("ui_ready", -4.0)
	return delay


## Attaque à distance sur des ennemis : un projectile par coup et par cible (3 cibles au plus), qui
## arrive pile à l'instant d'impact.
func _launch_projectiles(v: UnitView, ev: Dictionary, delay: float) -> void:
	if v.unit.range_type != "ranged":
		return
	var targets: Array = []
	for uid: int in ev.get("targets", []):
		var t: UnitView = views.get(uid)
		if t and t.unit.team != v.unit.team:
			targets.append(t)
	if targets.is_empty():
		return  # soin, bouclier : pas de projectile
	var color := Palette.element_color(v.unit.element)
	var magic := v.unit.attack_kind == "magic"
	var times: Array = ev.get("hit_times", [])
	if times.is_empty():
		times = [0.4]
	var start := v.chest_position() + Vector2(30.0 * (1 if v.unit.team == 0 else -1), -10)
	for k in mini(times.size(), 4):
		for t: UnitView in targets.slice(0, 3):
			var target := t
			var land := delay + float(times[k])
			var travel := clampf(start.distance_to(target.chest_position()) / 1500.0, 0.12, 0.4)
			_schedule(maxf(0.0, land - travel), func() -> void:
				if is_instance_valid(target):
					var proj := Projectile.new().setup(start, target.chest_position(), travel, color, magic)
					fx.add_child(proj)
					_fxl().attach_trail(proj, v.unit.element))


## Duo ou trio : chaque membre lance son ultime à sa place, en même temps, vers les ennemis.
func _on_small_combo(ev: Dictionary) -> float:
	var hits: Array = []
	for uid: int in ev.targets:
		if views.has(uid):
			hits.append(views[uid].chest_position())
	var aim := Vector2.INF
	if not hits.is_empty():
		aim = Vector2.ZERO
		for p: Vector2 in hits:
			aim += p
		aim /= hits.size()
	for uid: int in ev.members:
		var v: UnitView = views.get(uid)
		if v:
			v.play_attack(v._id + "_2", 0.0, aim)
			fx.aura(v.position, Palette.element_color(v.unit.element))
	var kind := "Trio" if ev.members.size() == 3 else "Duo"
	hud.callout(String(ev.name), "%s · %s" % [kind, ev.get("title", "")], Palette.GOLD, true)
	stage.ambience.set_ultimate_active(true)
	_schedule(2.4, func() -> void: stage.ambience.set_ultimate_active(false))
	for t: float in ev.hit_times:
		_schedule(t, func() -> void:
			fx.shake(0.35)
			fx.kick(0.04)
			_sfx("ultimate_impact", -3.0))
	return 0.0


## Attaque combinée du quatuor : les quatre héros s'effacent pendant que le clip du quatuor les
## montre ensemble, puis reviennent.
func _on_quartet(ev: Dictionary) -> float:
	var clip := String(ev.get("clip", ""))
	if clip == "":
		return _on_small_combo(ev)
	if FileAccess.file_exists("res://assets/anim/quatuors/%s/%s_quatuor.json" % [ev.id, ev.id]):
		return _on_pixel_quartet(ev)
	var p := ClipPlayer.new()
	p.bundle = "res://assets/anim/heroes/"
	p.scale = Vector2.ONE * 0.65  # les quatre héros du clip sont dessinés plus petits
	p.position = Vector2(330, HERO_SPOTS[0].y)  # les effets tombent sur la ligne ennemie
	p.z_index = 12
	_units_root.add_child(p)
	p.play(clip, false)
	var members: Array = ev.members
	for uid: int in members:
		if views.has(uid):
			views[uid].modulate.a = 0.0
	var dur := maxf(2.0, p.duration(clip))
	_hold = maxf(_hold, dur)  # le combat attend la fin du quatuor (pas de vague suivante en plein milieu)
	hud.callout(String(ev.name), "Quatuor", Palette.GOLD, true)
	stage.ambience.set_ultimate_active(true)
	_schedule(dur, func() -> void:
		p.queue_free()
		stage.ambience.set_ultimate_active(false)
		for uid: int in members:
			if views.has(uid) and not views[uid].is_dead():
				var tw: Tween = views[uid].create_tween()
				tw.tween_property(views[uid], "modulate:a", 1.0, 0.25))
	for t: float in ev.hit_times:
		_schedule(t, func() -> void:
			fx.shake(0.45)
			_sfx("ultimate_impact", -2.0))
	return 0.0


## Quatuor en pixel art : la scène du pack (512 × 288) agrandie sur tout le cadre, les quatre héros
## cachés pendant qu'elle se joue. Les dégâts tombent sur ses impacts (hit_times de relics.json).
func _on_pixel_quartet(ev: Dictionary) -> float:
	var p := QuatuorPlayer.new()
	p.scale = Vector2.ONE * QUARTET_SCALE
	p.position = QUARTET_ORIGIN
	p.z_index = 40
	add_child(p)
	if not p.play(String(ev.id)):
		p.queue_free()
		return 0.0
	# Les cibles de la scène tombent sur le centre des ennemis vivants.
	var aim := Vector2.ZERO
	var n := 0
	for v: UnitView in views.values():
		if v.unit.team == 1 and not v.is_dead():
			aim += v.chest_position()
			n += 1
	var targets: Array = p.data.get("preview_targets", [])
	if n > 0 and not targets.is_empty():
		var t := Vector2.ZERO
		for xy: Array in targets:
			t += Vector2(xy[0], xy[1])
		t /= targets.size()
		p.position = aim / n - t * QUARTET_SCALE
		# La grande explosion finale (dessinée au centre de son cadre) est recentrée sur les cibles.
		var shift: Vector2 = t - Vector2(256, 144)
		for key: Dictionary in p.data.final.position_keyframes:
			key.value = [float(key.value[0]) + shift.x, float(key.value[1]) + shift.y]
	var members: Array = ev.members
	for uid: int in members:
		if views.has(uid):
			views[uid].modulate.a = 0.0
	# Le combat attend la fin de la scène : la vague suivante n'arrive pas pendant le quatuor.
	_hold = maxf(_hold, float(p.data.get("duration_ms", 3000)) / 1000.0 + 0.3)
	hud.callout(String(ev.name), "Quatuor", Palette.GOLD, true)
	stage.ambience.set_ultimate_active(true)
	p.hit_active.connect(func(e: Dictionary) -> void:
		var final: bool = e.get("kind", "") == "final_explosion"
		fx.shake(0.6 if final else 0.3)
		if final:
			fx.kick(0.05)
		_sfx("ultimate_impact", -2.0 if final else -5.0))
	p.finished.connect(func(_id: String) -> void:
		p.queue_free()
		stage.ambience.set_ultimate_active(false)
		for uid: int in members:
			if views.has(uid) and not views[uid].is_dead():
				var tw: Tween = views[uid].create_tween()
				tw.tween_property(views[uid], "modulate:a", 1.0, 0.25))
	return 0.0


## Bibliothèque d'effets (créée à la demande si un événement arrive avant le décor).
func _fxl() -> FxLibrary:
	if not is_instance_valid(fxlib):
		fxlib = FxLibrary.new()
		add_child(fxlib)
		fxlib.setup(camera)
	return fxlib


## Données de l'attaque (héros ou monstre) pour choisir ses effets visuels.
func _attack_data(uid: int, attack_id: String) -> Dictionary:
	for a: Dictionary in unit_data.get(uid, {}).get("attacks", []):
		if String(a.get("id", "")) == attack_id:
			return a
	return {}


## Effet pixelfx de la dernière attaque de `src` sur `t` (data/pixelfx.json). Un coup qui part de l'attaquant
## (at = src) ne joue qu'une fois par attaque, même sur plusieurs cibles. Renvoie true si un effet a été joué.
func _pixel_hit(src: UnitView, t: UnitView) -> bool:
	if src == null or t == null:
		return false
	var aid := String(_last_attack.get(src.unit.uid, ""))
	var e := PixelFx.entry(aid)
	if e.is_empty():
		e = PixelFx.monster_entry(src.unit.def_id, aid)  # monstres : règles de data/pixelfx_monsters.json
	if e.is_empty():
		return false
	var now := Time.get_ticks_msec()
	var key := "%d:%s" % [src.unit.uid, "src" if String(e.get("at", "")) == "src" else str(t.unit.uid)]
	if now - int(_pfx_seen.get(key, -100000)) < 350:
		return true  # déjà joué pour ce coup : on n'ajoute pas les éclats génériques non plus
	_pfx_seen[key] = now
	var face_left := t.position.x < src.position.x if t != src else src.unit.team == 1
	return PixelFx.play(fx, e, src.position, src.height * src._size_scale(), t.position, t.chest_position(),
		t.height * t._size_scale(), face_left)


## État en pixel art (data/pixelfx.json "statuses") : aux pieds de l'unité, en boucle tant que l'état dure
## (un nouvel envoi du même état remplace l'ancien). Renvoie false si l'état n'a pas d'effet pixelfx.
func _pixel_status(t: UnitView, status: String, duration: float) -> bool:
	var e: Dictionary = PixelFx.data().get("statuses", {}).get(status, {})
	if e.is_empty() or t.is_dead():
		return false
	var mine: Dictionary = _status_fx.get(t.unit.uid, {})
	_status_fx[t.unit.uid] = mine
	if is_instance_valid(mine.get(status)):
		mine[status].queue_free()
	var spr := PixelFx.spawn(t, e, Vector2.ZERO, PixelFx.unit_scale(t.height * t._size_scale(), 0.9), 30)
	if spr == null:
		return false
	spr.z_as_relative = false  # sous les chiffres (40), au-dessus des personnages
	if e.get("once", false):
		return true
	mine[status] = spr
	var tw := spr.create_tween()
	tw.tween_interval(maxf(0.6, duration - 0.3))
	tw.tween_property(spr, "modulate:a", 0.0, 0.3)
	tw.tween_callback(spr.queue_free)
	return true


## Mort en pixel art (data/pixelfx.json "deaths") selon l'élément, plus une pluie d'or pour un boss.
func _pixel_death(t: UnitView) -> void:
	for spr in _status_fx.get(t.unit.uid, {}).values():
		if is_instance_valid(spr):
			spr.queue_free()
	_status_fx.erase(t.unit.uid)
	var deaths: Dictionary = PixelFx.data().get("deaths", {})
	var k := PixelFx.unit_scale(t.height * t._size_scale(), 0.9)
	var e: Dictionary = deaths.get(t.unit.element, deaths.get("", {}))
	var spr := PixelFx.spawn(fx, e, t.position, k, 30) if not e.is_empty() else null
	if spr:
		spr.z_as_relative = false
	var m: Dictionary = GameData.monsters.get(t.unit.def_id, {})
	if m.get("boss", false):
		var b: Dictionary = deaths.get("_regional" if m.get("regional_boss", false) else "_boss", {})
		if not b.is_empty():
			var bs := PixelFx.spawn(fx, b, t.position, maxf(1.0, roundf(k * float(b.get("size", 1.0)))), 30)
			if bs:
				bs.z_as_relative = false


## Héros et monstres en pixel art : leur effet d'impact (pack ChatGPT) éclate sur la cible touchée.
func _signature_fx(src: UnitView, t: UnitView, slot: int) -> void:
	var sheet := PixelSheet.for_actor(src.unit.def_id)
	if sheet == null or sheet.effect == null:
		return
	var anim := sheet.anim_for(str(slot))
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sheet.effect
	spr.centered = false
	spr.offset = -sheet.effect_pivot
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var size := float(sheet.effect_scale.get(anim, 1.0)) * sheet.scale * src.model_scale * 0.55
	spr.scale = Vector2(size, size)
	spr.position = t.chest_position()
	spr.z_index = 50
	fx.add_child(spr)
	spr.play()
	spr.animation_finished.connect(spr.queue_free)


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
				t.popup(str(int(ev.amount)), Color(0.75, 0.55, 1.0), false, 0.8)
				t.flash(Color(0.6, 0.3, 0.9), 0.35)
				var tick := "brulure" if src and src.unit.element == "feu" else "poison"
				_fxl().status(tick, t.head_position(), t.chest_position(), t.position, 0.0)
			else:
				t.play_hit(color)
				var heavy: bool = ev.crit or int(_last_slot.get(int(ev.src), 0)) >= BattleUnit.SLOT_ULTIMATE
				var pixel := _pixel_hit(src, t)
				if not pixel:
					fx.burst(t.chest_position(), color, ev.crit)
					fx.slash(t.chest_position(), color, heavy)
				var ctx: Dictionary = _fx_ctx.get(int(ev.src), {})
				var slot_fx: Dictionary = {}
				if src and not ctx.is_empty():
					if not pixel:
						_fxl().impact(t.chest_position(), ctx, ev.crit)
					slot_fx = FxLibrary.data().get("slots", {}).get(ctx.slot, {})
					if slot_fx.has("flash"):
						_fxl().flash(Palette.element_color(src.unit.element).lightened(0.4), float(slot_fx.flash))
						fx.kick(float(slot_fx.get("zoom", 0.04)))
						fx.shake(float(slot_fx.get("shake", 0.4)))
				elif src and not pixel:
					fx.element_hit(t.chest_position(), src.unit.element, heavy)
				if src and not pixel:
					_signature_fx(src, t, int(_last_slot.get(int(ev.src), 0)))
				if heavy:
					fx.kick(0.05 if ev.crit else 0.035)
				fx.dust(t.position, 0.6)
				# Arrêt sur image : attaquant et cible se figent un instant.
				# (Ultime : arrêt un peu plus long = léger ralenti, réglé dans data/fx.json.)
				var stop := float(slot_fx.get("freeze", 0.11 if heavy else 0.06))
				t.freeze(stop)
				if src:
					src.freeze(stop)
				fx.shake(0.35 if heavy else 0.12)
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
					fx.shake(0.3)
					_sfx("hit_heavy", -1.0)
				else:
					_sfx("hit", -4.0)
			if src and _hero_stats.has(src.unit.uid):
				_hero_stats[src.unit.uid].damage += ev.amount
		"miss":
			var t: UnitView = views.get(ev.dst)
			if t:
				t.popup("Leurre !" if ev.reason == "leurre" else "Esquive !", Color(0.8, 0.9, 1.0))
		"heal":
			var t: UnitView = views.get(ev.dst)
			if t == null:
				return
			_set_shown_hp(t, ev)
			t.popup("+" + str(int(ev.amount)), Palette.HEAL)
			t.flash(Palette.HEAL, 0.5)
			if not _pixel_hit(views.get(ev.src), t):
				_fxl().heal(t.position, t.chest_position())
			_sfx("heal", -6.0)
			if _hero_stats.has(ev.src):
				_hero_stats[ev.src].healing += ev.amount
		"shield":
			var t: UnitView = views.get(ev.dst)
			if t:
				t.popup("Bouclier", Palette.SHIELD)
				t.flash(Palette.SHIELD, 0.5)
				if not _pixel_hit(views.get(ev.get("src", -1)), t):
					_fxl().shield(t.chest_position(), t.height)
				_sfx("shield", -6.0)
		"status":
			var t: UnitView = views.get(ev.dst)
			if t:
				var text: String = ev.get("label", "")
				if text == "":
					text = STATUS_LABELS.get(ev.status, "")
				if text != "":
					t.popup(text, Palette.GOLD, false, 1.4)
				if not _pixel_status(t, String(ev.status), float(ev.get("duration", 0.0))):
					_fxl().status(String(ev.status), t.head_position(), t.chest_position(), t.position,
						float(ev.get("duration", 0.0)))
		"death":
			var t: UnitView = views.get(ev.dst)
			if t:
				t.shown_hp = 0.0
				t.hp_seq = ev.seq
				t.play_death()
				_pixel_death(t)
				_sfx("death", -2.0)
				if t.unit and t.unit.is_boss:
					Input.vibrate_handheld(220)  # le boss tombe : le téléphone tremble
					var speed := Engine.time_scale
					Engine.time_scale = speed * 0.35  # court ralenti sur le coup fatal
					get_tree().create_timer(0.25, true, false, true).timeout.connect(Callable(Engine, "set").bind("time_scale", speed))
				var fall_at := t.position
				_schedule(1.3, func() -> void: fx.dust(fall_at, 1.3))
		"victory":
			Input.vibrate_handheld(80)
			_end_battle(true)
		"defeat":
			_end_battle(false)
		"draw":
			_end_battle(false, true)


## Temps de combat après lequel « Arrêter » (égalité) est proposé : 45 s par vague, au moins 90 s.
func draw_after() -> float:
	return maxf(90.0, 45.0 * engine.waves.size())


func _end_battle(won: bool, draw := false) -> void:
	if _ended:
		return
	_ended = true
	_end_turn()
	hud.draw_button.visible = false
	if won:
		for uid in views:
			var v: UnitView = views[uid]
			if v.unit.team == 0:
				v.play_cheer()
	hud.hide_turn_order()  # la bannière de fin prend sa place en haut
	hud.banner("ÉGALITÉ" if draw else ("VICTOIRE !" if won else "DÉFAITE…"), "", 0.8)
	audio.stop_music(0.4)
	var stars := engine.stars()
	var rewards := PlayerData.filter_locked_loot(GameData.dungeon_rewards(dungeon_id, stars), dungeon_id)
	var result: Dictionary
	if draw:
		rewards = {}
		result = {"heroes": {}, "player_level_up": false}
		PlayerData.refund_draw(dungeon_id, lodge_battle)
	elif lodge_battle.is_empty():
		# Le butin et l'XP sont enregistrés dans la sauvegarde.
		result = PlayerData.finish_hunt(dungeon_id, won, stars, rewards, team_ids)
	else:
		var gain := PlayerData.finish_lodge_battle(won)
		rewards = {"gold": gain.gold} if gain.gold > 0 else {}
		result = {"heroes": {}, "player_level_up": false}
	var stats: Array = []
	for i in engine.heroes.size():
		var h := engine.heroes[i]
		var progress: Dictionary = result.heroes.get(team_ids[i], {})
		stats.append({
			"id": team_ids[i], "name": h.display_name, "element": h.element, "alive": h.is_alive(),
			"damage": _hero_stats[h.uid].damage, "healing": _hero_stats[h.uid].healing,
			"level": progress.get("level", PlayerData.hero_level(team_ids[i])),
			"xp": progress.get("xp", 0), "level_up": progress.get("gained_levels", 0) > 0,
		})
	var dungeon_name: String = GameData.dungeon(dungeon_id).get("name", "")
	var replay := {"cost": PlayerData.hunt_cost(dungeon_id), "possible": PlayerData.can_start_hunt(dungeon_id),
		"energy": PlayerData.energy(), "player_level_up": result.player_level_up, "player_level": PlayerData.level(),
		"chest": result.get("chest", {}), "draw": draw}
	if not lodge_battle.is_empty():
		dungeon_name = "Donjon · " + String(lodge_battle.name)
		replay.possible = false
	_schedule(END_DELAY, func() -> void:
		audio.play_music("victory" if won else "defeat", false)
		hud.show_end(won, stars, rewards, stats, dungeon_name, replay))


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
	var k := 0
	var has_boss := engine.enemies.any(func(u: BattleUnit) -> bool: return u.is_boss)
	for e in engine.enemies:
		var spot: Vector2 = _boss_spot()
		if not e.is_boss:
			spot = _spot(1, k)
			k += 1
			if has_boss and k > 5:
				spot.x -= 70.0  # les derniers sbires se placent devant le boss, pas sur lui
		var data: Dictionary
		if lodge_battle.is_empty():
			data = GameData.monster(e.def_id)
		else:
			data = GameData.hero(e.def_id) if e.structure == "" else Lodge.defense_unit(e.structure, [], GameData.lodge)
		_spawn(e, data, spot)


## Place du n-ième combattant d'un camp (0 héros, 1 ennemis).
func _spot(team: int, n: int) -> Vector2:
	if not stage.topdown:
		var spots: Array = HERO_SPOTS if team == 0 else ENEMY_SPOTS
		return spots[n % spots.size()]
	var spots: Array = TOP_HEROES if team == 0 else TOP_ENEMIES
	return spots[n % spots.size()]


func _boss_spot() -> Vector2:
	if not stage.topdown:
		return BOSS_SPOT
	# Au fond de la colonne arrière ennemie, centré entre ses deux places (le boss est plus grand).
	return Vector2(TOP_ENEMIES[5].x + 30.0, (TOP_ENEMIES[5].y + TOP_ENEMIES[6].y) / 2.0 + 20.0)


func _spawn(u: BattleUnit, data: Dictionary, pos: Vector2) -> void:
	var v := UnitView.new()
	v.position = pos
	_units_root.add_child(v)
	v.setup(u, data)
	if stage.topdown:
		# Plongée : un peu plus petits au fond, un peu plus grands devant.
		v.scale = Vector2.ONE * TOP_SCALE
	elif engine.heroes.size() > 4:
		v.scale = Vector2.ONE * CROWD_SCALE
	views[u.uid] = v
	unit_data[u.uid] = data
	hud.add_overhead(v)
	# Entrée en scène : les héros arrivent de la gauche, les monstres de la droite, l'un après l'autre.
	var side := -1.0 if u.team == 0 else 1.0
	var order := _units_root.get_child_count() % 8
	if u.is_boss:
		v.enter(Vector2(side * 520.0, 0), 0.45, func() -> void:
			fx.shake(0.7)
			fx.dust(v.position, 2.0))
	else:
		v.enter(Vector2(side * 460.0, 0), 0.06 * order, func() -> void: fx.dust(v.position, 0.8))


# --- Monde 2D ----------------------------------------------------------------

func _build_world() -> void:
	var d := GameData.dungeon(dungeon_id)
	var region: Dictionary = GameData.regions.get(d.get("region", ""), {})
	stage = BattleStage.new()
	add_child(stage)
	if not lodge_battle.is_empty():
		var arena: Dictionary = GameData.lodge.get("arena", {})
		stage.setup(String(arena.get("decor", "res://assets/decors/monde06/")), int(arena.get("scene", 2)))
	else:
		stage.setup(String(region.get("decor", "res://assets/decors/monde01/")), int(d.get("decor_scene", 1)))

	camera = Camera2D.new()
	camera.position = FRAME / 2.0
	add_child(camera)
	camera.make_current()

	_units_root = Node2D.new()
	_units_root.name = "Units"
	_units_root.y_sort_enabled = true
	add_child(_units_root)

	fx = BattleFx.new()
	add_child(fx)
	fx.setup(camera)
	fxlib = FxLibrary.new()
	add_child(fxlib)
	fxlib.setup(camera)


## Le cadre 1280 × 720 remplit la fenêtre (on coupe un peu les bords si le format diffère).
func _fit_camera() -> void:
	var vs := get_viewport().get_visible_rect().size
	var z := maxf(vs.y / FRAME.y, vs.x / FRAME.x)
	camera.zoom = Vector2(z, z)
