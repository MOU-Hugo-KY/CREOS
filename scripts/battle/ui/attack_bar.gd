class_name AttackBar
extends Control
## Barre d'attaque du héros dont c'est le tour (pièces pixel de assets/ui/combat, disposition de
## combat_ui.json) : plateau en bas au centre, portrait rond et nom du héros, énergie, puis ses
## 3 compétences et la case plus petite de la technique secrète (cadenas tant qu'elle n'est pas
## débloquée). Invisible le reste du temps : le bas de l'arène redevient visible.

signal attack_chosen(slot: int)

const TRAY := Vector2(1090, 164)
const SKILL_X := [420.0, 566.0, 712.0]
const SECRET_POS := Vector2(874, 26)  # centrée sur les cases de compétence
## Icône d'élément du badge (pack partie 2, assets/ui/ecrans/fiche_heros/pieces/element_<nom>_64.png).
const ELEMENT_ICONS := {"feu": "fire", "eau": "water", "nature": "nature", "lumiere": "light", "ombre": "shadow"}

var unit: BattleUnit
var _icons: Array[AttackIcon] = []
var _portrait_holder: Control
var _name: Label
var _energy: TextureRect
var _energy_fill: TextureRect
var _lock: Control
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -TRAY.x / 2.0
	offset_right = TRAY.x / 2.0
	offset_top = -TRAY.y - 31.0
	offset_bottom = -31.0
	var tray := Panel.new()
	tray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tray.mouse_filter = Control.MOUSE_FILTER_STOP  # le plateau ne laisse pas passer le toucher
	var tray_box := _nine("attack_tray", 28)
	tray_box.modulate_color = Color(0.62, 0.62, 0.68)  # plus sombre, comme la maquette
	tray.add_theme_stylebox_override("panel", tray_box)
	add_child(tray)
	_portrait_holder = Control.new()
	_portrait_holder.position = Vector2(24, 20)
	_portrait_holder.size = Vector2(124, 124)
	_portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_holder)
	_name = UiKit.title("", 34)
	_name.position = Vector2(168, 34)
	_name.size = Vector2(240, 44)
	add_child(_name)
	_energy = TextureRect.new()
	_energy.texture = OverheadBar.tex("energy_frame")
	_energy.stretch_mode = TextureRect.STRETCH_SCALE
	_energy.position = Vector2(168, 96)
	_energy.size = Vector2(220, 10)
	_energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_energy)
	_energy_fill = TextureRect.new()
	_energy_fill.texture = OverheadBar.tex("hero_energy_fill")
	_energy_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_energy_fill.position = Vector2(170, 98)
	_energy_fill.size = Vector2(216, 6)
	_energy_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_energy_fill)
	for i in 4:
		var icon := AttackIcon.new()
		var slot := i
		icon.pressed.connect(func() -> void: attack_chosen.emit(slot))
		icon.position = SECRET_POS if i == BattleUnit.SLOT_SECRET else Vector2(SKILL_X[i], 10)
		add_child(icon)
		_icons.append(icon)
	# Case de la technique secrète encore verrouillée : cadre grisé + cadenas du kit.
	_lock = Control.new()
	_lock.position = SECRET_POS
	_lock.size = Vector2(96, 96)
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.tooltip_text = "Technique secrète : se débloque à 6 Échos."
	var frame := TextureRect.new()
	frame.texture = OverheadBar.tex("secret_frame_disabled")
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lock.add_child(frame)
	var lock := TextureRect.new()
	lock.texture = load("res://assets/ui/kit/lock.png")
	lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.position = Vector2(28, 26)
	lock.size = Vector2(40, 40)
	_lock.add_child(lock)
	add_child(_lock)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


static func _nine(name: String, margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = OverheadBar.tex(name)
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	return sb


func show_for(p_unit: BattleUnit) -> void:
	unit = p_unit
	_name.text = unit.display_name.to_upper()
	for c in _portrait_holder.get_children():
		c.queue_free()
	# Cadre carré (comme une case de compétence) avec la tête du héros, et son élément en bas à droite.
	var frame := TextureRect.new()
	frame.texture = OverheadBar.tex("skill_frame_normal")
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_holder.add_child(frame)
	var head := TextureRect.new()
	head.texture = RoundPortrait.portrait_texture(GameData.hero(unit.def_id))
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	head.position = Vector2(14, 14)
	head.size = Vector2(96, 96)
	head.clip_contents = true
	_portrait_holder.add_child(head)
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(88, 88)
	badge.size = Vector2(44, 44)
	var elem_color := Palette.element_color(unit.element).lightened(0.2)
	var glyph_tex := ScreenPack.tex("fiche_heros", "element_%s_64" % ELEMENT_ICONS.get(unit.element, "shadow"))
	# Pastille ronde (maquette) : fond sombre, liseré de la couleur de l'élément, symbole au centre.
	badge.draw.connect(func() -> void:
		var c := Vector2(22, 22)
		var disc := PackedVector2Array()
		for i in 32:
			disc.append(c + Vector2.from_angle(TAU * i / 32.0) * 17.0)
		badge.draw_colored_polygon(disc, Color("1c1a22"))
		badge.draw_arc(c, 16.0, 0.0, TAU, 32, elem_color, 3.0)
		badge.draw_arc(c, 18.5, 0.0, TAU, 32, Color("0e0c12"), 2.0)
		if glyph_tex:
			badge.draw_texture_rect(glyph_tex, Rect2(c - Vector2(16, 16), Vector2(32, 32)), false))
	badge.z_index = 2
	_portrait_holder.add_child(badge)
	var color := Palette.element_color(unit.element)
	for i in _icons.size():
		var icon := _icons[i]
		icon.visible = unit.has_attack(i)
		if icon.visible:
			icon.setup(i, unit.attacks[i], color)
	_lock.visible = not unit.has_attack(BattleUnit.SLOT_SECRET)
	refresh()
	visible = true
	modulate.a = 0.0
	if _tween:
		_tween.kill()  # sinon le fondu de fermeture du héros précédent recache la barre
	var tw := create_tween()
	_tween = tw
	tw.tween_property(self, "modulate:a", 1.0, 0.12)


func hide_bar(chosen := -1) -> void:
	if not visible:
		return
	if chosen >= 0 and chosen < _icons.size():
		_icons[chosen].press_feedback()
	unit = null
	if _tween:
		_tween.kill()
	var tw := create_tween()
	_tween = tw
	tw.tween_interval(0.08)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func() -> void:
		if unit == null:
			visible = false)


func refresh() -> void:
	if unit == null:
		return
	_energy_fill.size.x = 216.0 * clampf(unit.energy / BattleUnit.ENERGY_MAX, 0.0, 1.0)
	for i in _icons.size():
		if not unit.has_attack(i):
			continue
		var corner := ""
		var progress := 1.0
		match i:
			BattleUnit.SLOT_COOLDOWN, BattleUnit.SLOT_SECRET:
				var cd: float = unit.attacks[i].get("cooldown", 1.0)
				var left := unit.cooldowns[i]
				progress = 1.0 - left / maxf(cd, 0.01)
				if left > 0.0:
					corner = "%d" % int(ceil(left))
			BattleUnit.SLOT_ULTIMATE:
				var cost := unit.energy_cost(i)
				progress = unit.energy / maxf(cost, 1.0)
		_icons[i].set_state(unit.can_use(i), progress, corner)


func icon_rect(slot: int) -> Rect2:
	return _icons[slot].get_global_rect()
