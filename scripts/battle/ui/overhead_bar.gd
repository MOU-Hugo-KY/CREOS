class_name OverheadBar
extends Control
## Barre qui suit une unité à l'écran (pièces pixel de assets/ui/combat) : cadre sombre, PV vert
## (héros) ou rouge (ennemis), bouclier blanc par-dessus, fine jauge d'énergie dorée dessous pour
## les héros, et les icônes de ses états (4 au plus).

const DIR := "res://assets/ui/combat/"
const BAR := Vector2(110, 18)
const INSET := 4.0
## État du moteur -> icône du pack (status_<nom>_16.png).
const STATUS_ICONS := {"brulure": "burn", "poison": "poison", "mouille": "wet", "marque": "mark",
	"aveugle": "blind", "enracine": "rooted", "desequilibre": "imbalance", "garde": "guard",
	"regen": "regeneration", "armure_reduite": "debuff"}

var view: UnitView
var active := false  # c'est au tour de ce héros (anneau doré au sol, voir UnitView)

var _hp_ratio := 1.0
var _shield_ratio := 0.0
var _energy_ratio := -1.0
var _icons: Array[Texture2D] = []

static var _tex: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := DIR + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


func setup(p_view: UnitView) -> void:
	view = p_view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(BAR.x, 48)


func follow(_delta: float) -> void:
	var u := view.unit
	visible = view.shown_hp > 0.0 and view.visible and view.modulate.a > 0.5
	if not visible:
		return
	position = (view.head_screen() - Vector2(size.x / 2.0, 30)).round()
	_hp_ratio = clampf(view.shown_hp / u.max_hp, 0.0, 1.0)
	_shield_ratio = clampf(u.shield / u.max_hp, 0.0, 1.0)
	_energy_ratio = u.energy / BattleUnit.ENERGY_MAX if u.team == 0 else -1.0
	_icons.clear()
	if u.stun_time > 0.0:
		_icons.append(tex("status_stunned_16"))
	if u.taunt_time > 0.0 and u.taunt_time < 1000.0:
		_icons.append(tex("status_taunt_16"))
	if u.shield > 0.0:
		_icons.append(tex("status_shield_16"))
	for key: String in STATUS_ICONS:
		if u.has_status(key):
			_icons.append(tex("status_%s_16" % STATUS_ICONS[key]))
	for key: String in u.statuses:
		if u.has_status(key) and String(key).begins_with("buff_"):
			_icons.append(tex("status_buff_16"))
			break
	for key: String in u.statuses:
		if u.has_status(key) and String(key).begins_with("debuff_"):
			_icons.append(tex("status_debuff_16"))
			break
	queue_redraw()


func _draw() -> void:
	var hero := view.unit.team == 0
	var frame := tex("hp_frame")
	if frame:
		draw_texture_rect(frame, Rect2(Vector2.ZERO, BAR), false)
	var inner := Rect2(Vector2(INSET, INSET), BAR - Vector2(INSET, INSET) * 2.0)
	_fill(tex("hp_hero_fill" if hero else "hp_enemy_fill"), inner, _hp_ratio)
	if _shield_ratio > 0.0:
		_fill(tex("shield_fill"), inner, _shield_ratio, Color(1, 1, 1, 0.8))
	if _energy_ratio >= 0.0:
		var ef := tex("energy_frame")
		var er := Rect2(Vector2(0, 22), Vector2(BAR.x, 6))
		if ef:
			draw_texture_rect(ef, er, false)
		_fill(tex("hero_energy_fill"), er.grow(-1.0), clampf(_energy_ratio, 0.0, 1.0))
	var x := 0.0
	for icon: Texture2D in _icons.slice(0, 4):
		if icon:
			draw_texture_rect(icon, Rect2(Vector2(x, 31), Vector2(16, 16)), false)
			x += 18.0


## Remplissage recadré à `ratio` (la texture est pleine, on n'en montre que la part utile).
func _fill(t: Texture2D, r: Rect2, ratio: float, color := Color.WHITE) -> void:
	if t == null or ratio <= 0.0:
		return
	var w := r.size.x * ratio
	draw_texture_rect_region(t, Rect2(r.position, Vector2(w, r.size.y)),
		Rect2(Vector2.ZERO, Vector2(t.get_width() * ratio, t.get_height())), color)
