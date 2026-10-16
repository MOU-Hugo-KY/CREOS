class_name TurnOrder
extends Control
## Frise de l'ordre des prochains tours (d'après les jauges et la Vitesse, `BattleEngine.predict_order`) :
## en haut au centre, des vignettes carrées (tête du personnage tirée de son dessin de combat), cadre
## doré pour les héros et rouge pour les ennemis ; le premier (celui qui joue) est plus grand.

const COUNT := 8
const SIZE := 66.0
const FIRST := 84.0
const GAP := 8.0

var _order: Array = []
var _units: Dictionary = {}  # uid -> BattleUnit
static var _heads: Dictionary = {}  # def_id -> AtlasTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	var w := FIRST + (COUNT - 1) * (SIZE + GAP)
	offset_left = -w / 2.0
	offset_right = w / 2.0
	offset_top = 24.0
	offset_bottom = 24.0 + FIRST + 20.0


func update_from(engine: BattleEngine) -> void:
	var order := engine.predict_order(COUNT)
	if order == _order:
		return
	_order = order
	_units.clear()
	for uid: int in order:
		_units[uid] = engine.get_unit(uid)
	queue_redraw()


## Tête du personnage : le haut de sa première image de repos, recadré en carré.
static func head(def_id: String) -> AtlasTexture:
	if _heads.has(def_id):
		return _heads[def_id]
	var at: AtlasTexture = null
	var sheet := PixelSheet.for_actor(def_id)
	var px := RoundPortrait.pixel_head(def_id)
	if px:
		at = AtlasTexture.new()
		at.atlas = px
		at.region = Rect2(Vector2.ZERO, px.get_size())
	elif sheet and sheet.anims.has("idle"):
		var tex: Texture2D = sheet.anims.idle.frames[0][0]
		var used := tex.get_image().get_used_rect()
		var side := mini(used.size.x, maxi(28, int(used.size.y * 0.6)))
		at = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(used.position.x + (used.size.x - side) / 2, used.position.y, side, side)
	_heads[def_id] = at
	return at


func _draw() -> void:
	var x := 0.0
	for i in _order.size():
		var u: BattleUnit = _units.get(_order[i])
		if u == null:
			continue
		var s := FIRST if i == 0 else SIZE
		var r := Rect2(x, 0 if i == 0 else (FIRST - SIZE) / 2.0, s, s)
		var edge := Color("e8c66a") if u.team == 0 else Color("c8454a")
		draw_rect(r.grow(3), Color("16131b"))
		draw_rect(r, Color("2c2733") if u.team == 0 else Color("33232a"))
		var h := head(u.def_id)
		if h:
			var src := h.region
			var flip := u.team == 1
			var dst := r.grow(-4)
			if flip:  # les ennemis regardent vers la gauche, comme sur le plateau
				draw_set_transform(Vector2(dst.position.x * 2.0 + dst.size.x, 0), 0.0, Vector2(-1, 1))
			draw_texture_rect_region(h.atlas, dst, src)
			draw_set_transform(Vector2.ZERO)
		draw_rect(r, edge, false, 3.0 if i == 0 else 2.0)
		if i == 0:
			draw_rect(Rect2(x + 6, FIRST + 4, s - 12, 20), Color(0.08, 0.07, 0.1, 0.85))
			draw_string(UiKit.FONT, Vector2(x, FIRST + 21), "À lui", HORIZONTAL_ALIGNMENT_CENTER, s, 19, edge)
		x += s + GAP
