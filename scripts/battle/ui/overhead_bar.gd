class_name OverheadBar
extends Control
## Barres d'une unité à l'écran, comme la maquette de combat (pièces pixel de assets/ui/combat) :
## la barre de vie seule au-dessus de la tête (vert héros, rouge ennemis, bouclier blanc par-dessus),
## et sous les pieds la jauge jaune d'énergie avec l'icône de son état principal à gauche.

const DIR := "res://assets/ui/combat/"
const BAR := Vector2(110, 18)
const INSET := 4.0
const FOOT := Vector2(96, 10)  # jauge d'énergie sous les pieds
## État du moteur -> icône du pack (status_<nom>_24.png).
const STATUS_ICONS := {"brulure": "burn", "poison": "poison", "mouille": "wet", "marque": "mark",
	"aveugle": "blind", "enracine": "rooted", "desequilibre": "imbalance", "garde": "guard",
	"regen": "regeneration", "armure_reduite": "debuff"}

var view: UnitView
var active := false  # c'est au tour de ce héros (anneau doré au sol, voir UnitView)

var _hp_ratio := 1.0
var _shield_ratio := 0.0
var _energy_ratio := 0.0
var _icon: Texture2D
## États du moteur -> icônes 32 px du pack « Finitions » (assets/ui/finitions/combat/etats/).
const PACK_ICONS := {"brulure": "brulure", "poison": "poison", "mouille": "mouille", "marque": "marque",
	"aveugle": "aveugle", "enracine": "enracine", "desequilibre": "desequilibre", "garde": "garde", "scelle": "scelle",
	"leurre": "leurre", "regen": "regeneration", "armure_reduite": "defense_malus"}
const STAT_ICONS := {"atk": "attaque", "mag": "attaque", "def": "defense", "spd": "vitesse", "speed": "vitesse"}
var _feet := Vector2.ZERO  # position des pieds dans le repère de cette barre

static var _tex: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := DIR + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


func setup(p_view: UnitView) -> void:
	view = p_view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BAR


func follow(_delta: float) -> void:
	var u := view.unit
	visible = view.shown_hp > 0.0 and view.visible and view.modulate.a > 0.5
	if not visible:
		return
	position = (view.head_screen() - Vector2(BAR.x / 2.0, 0)).round()  # juste au-dessus de la tête
	_feet = (view.get_parent().get_global_transform_with_canvas() * view.position - position).round()
	_hp_ratio = clampf(view.shown_hp / u.max_hp, 0.0, 1.0)
	_shield_ratio = clampf(u.shield / u.max_hp, 0.0, 1.0)
	_energy_ratio = clampf(u.energy / BattleUnit.ENERGY_MAX, 0.0, 1.0)
	_icon = null
	if FinPack.available("combat"):
		_icon = _pack_icon(u)
	elif u.stun_time > 0.0:
		_icon = tex("status_stunned_24")
	elif u.taunt_time > 0.0 and u.taunt_time < 1000.0:
		_icon = tex("status_taunt_24")
	else:
		for key: String in STATUS_ICONS:
			if u.has_status(key):
				_icon = tex("status_%s_24" % STATUS_ICONS[key])
				break
		if _icon == null and u.shield > 0.0:
			_icon = tex("status_shield_24")
		if _icon == null:
			for key: String in u.statuses:
				if u.has_status(key) and String(key).begins_with("buff_"):
					_icon = tex("status_buff_24")
					break
	queue_redraw()


## Icône d'état du pack : étourdi, provocation, puis les états, bouclier, bonus et malus.
func _pack_icon(u: BattleUnit) -> Texture2D:
	var name := ""
	if u.stun_time > 0.0:
		name = "etourdi"
	elif u.taunt_time > 0.0 and u.taunt_time < 1000.0:
		name = "provocation"
	else:
		for key: String in PACK_ICONS:
			if u.has_status(key):
				name = PACK_ICONS[key]
				break
		if name == "" and u.shield > 0.0:
			name = "bouclier"
		if name == "":
			for key: String in u.statuses:
				if u.has_status(key) and (String(key).begins_with("buff_") or String(key).begins_with("debuff_")):
					var up := String(key).begins_with("buff_")
					name = "%s_%s" % [STAT_ICONS.get(String(key).get_slice("_", 1), "attaque"), "bonus" if up else "malus"]
					break
	return FinPack.tex("combat/etats/%s.png" % name) if name != "" else null


func _draw() -> void:
	var hero := view.unit.team == 0
	# Vie, au-dessus de la tête.
	var frame := tex("hp_frame")
	if frame:
		draw_texture_rect(frame, Rect2(Vector2.ZERO, BAR), false)
	var inner := Rect2(Vector2(INSET, INSET), BAR - Vector2(INSET, INSET) * 2.0)
	_fill(tex("hp_hero_fill" if hero else "hp_enemy_fill"), inner, _hp_ratio)
	if _shield_ratio > 0.0:
		_fill(tex("shield_fill"), inner, _shield_ratio, Color(1, 1, 1, 0.8))
	# Énergie (jaune), sous les pieds, avec l'icône d'état à gauche.
	var er := Rect2(_feet + Vector2(-FOOT.x / 2.0 + 12, 8), FOOT)
	var ef := tex("energy_frame")
	if ef:
		draw_texture_rect(ef, er, false)
	_fill(tex("hero_energy_fill"), er.grow(-2.0), _energy_ratio)
	if _icon:
		draw_texture_rect(_icon, Rect2(er.position + Vector2(-26, -7), Vector2(24, 24)), false)


## Remplissage recadré à `ratio` (la texture est pleine, on n'en montre que la part utile).
func _fill(t: Texture2D, r: Rect2, ratio: float, color := Color.WHITE) -> void:
	if t == null or ratio <= 0.0:
		return
	var w := r.size.x * ratio
	draw_texture_rect_region(t, Rect2(r.position, Vector2(w, r.size.y)),
		Rect2(Vector2.ZERO, Vector2(t.get_width() * ratio, t.get_height())), color)
