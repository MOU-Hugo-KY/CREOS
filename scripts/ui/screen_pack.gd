class_name ScreenPack
extends RefCounted
## Pièces pixel des écrans du hub (pack ChatGPT partie 2, assets/ui/ecrans/<écran>/) : textures,
## boîtes 9-slice d'après les marges du JSON de l'écran, boutons à trois états, animations image
## par image. Toutes les positions des JSON sont en pixels de l'écran 1920 × 1080.

const DIR := "res://assets/ui/ecrans/"

static var _json: Dictionary = {}
static var _tex: Dictionary = {}


static func data(screen: String) -> Dictionary:
	if not _json.has(screen):
		var f := FileAccess.open(DIR + screen + "/" + screen + ".json", FileAccess.READ)
		_json[screen] = JSON.parse_string(f.get_as_text()) if f else {}
	return _json[screen]


static func layout(screen: String) -> Dictionary:
	return data(screen).get("layout", {})


static func tex(screen: String, name: String) -> Texture2D:
	var path := DIR + screen + "/pieces/" + name + ".png"
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Rectangle [x, y, w, h] du JSON.
static func rect(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


## Boîte 9-slice d'une pièce (marges du JSON, sinon `margin`).
static func nine(screen: String, name: String, margin := 28) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(screen, name)
	var info: Dictionary = data(screen).get("assets", {}).get(name, {})
	var ns = info.get("nine_slice")
	if ns is Dictionary:
		sb.texture_margin_left = ns.left
		sb.texture_margin_top = ns.top
		sb.texture_margin_right = ns.right
		sb.texture_margin_bottom = ns.bottom
	else:
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sb.set_texture_margin(side, margin)
	return sb


## Repère 1920 × 1080 du pack, centré dans l'écran (qui peut être plus large).
static func frame(parent: Control) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(1920, 1080)
	parent.add_child(root)
	var center := func() -> void:
		root.position = ((parent.size - root.size) / 2.0).round()
	parent.resized.connect(center)
	center.call()
	return root


## Panneau 9-slice posé à `r`.
static func panel(parent: Control, screen: String, name: String, r: Rect2) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", nine(screen, name))
	parent.add_child(p)
	return p


## Image simple posée à `r` (étirée, filtrage net).
static func image(parent: Control, t: Texture2D, r: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # avant la taille, sinon l'image impose la sienne
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture = t
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## Bouton à trois états du pack (`<base>_normal/_hover/_pressed`, `_disabled` s'il existe).
static func button(parent: Control, screen: String, base: String, text: String, r: Rect2,
		font_size := 30, color := UiKit.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiKit.FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("outline_size", 0)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, color)
	b.add_theme_color_override("font_disabled_color", Color(color, 0.45))
	var states := {"normal": "normal", "hover": "hover", "pressed": "pressed", "focus": "normal"}
	for st: String in states:
		b.add_theme_stylebox_override(st, nine(screen, base + "_" + states[st]))
	var dis := base + "_disabled"
	if tex(screen, dis):
		b.add_theme_stylebox_override("disabled", nine(screen, dis))
	else:
		var sb := nine(screen, base + "_normal")
		sb.modulate_color = Color(0.55, 0.55, 0.6)
		b.add_theme_stylebox_override("disabled", sb)
	parent.add_child(b)
	return b


## Texte Fredoka posé à `r`.
static func text(parent: Control, s: String, r: Rect2, size := 28, color := UiKit.INK,
		align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var l := Label.new()
	l.text = s
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.add_theme_font_override("font", UiKit.FONT)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("line_spacing", 2)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if not wrap:
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = r.position
	l.size = r.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Animation image par image d'un JSON d'écran (`animations.<name>`) : un Control dont l'origine
## est le pivot de la séquence. `play()` renvoie quand elle est finie (sauf en boucle).
class Anim extends Control:
	signal finished
	var frames: Array[Texture2D] = []
	var durations: Array = []
	var pivot := Vector2.ZERO
	var loop := false
	var _i := 0
	var _t := 0.0
	var _running := false

	func _init(screen: String, name: String) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var a: Dictionary = ScreenPack.data(screen).get("animations", {}).get(name, {})
		for f: String in a.get("frames", []):
			var path := ScreenPack.DIR + screen + "/" + f.replace("animations/", "anim/")
			frames.append(load(path) if ResourceLoader.exists(path) else null)
		durations = a.get("durations_ms", [])
		var p: Array = a.get("pivot", [0, 0])
		pivot = Vector2(p[0], p[1])
		loop = bool(a.get("loop", false))
		visible = false

	func play() -> void:
		_i = 0
		_t = 0.0
		_running = not frames.is_empty()
		visible = _running
		queue_redraw()

	func stop() -> void:
		_running = false
		visible = false

	func _process(delta: float) -> void:
		if not _running:
			return
		_t += delta * 1000.0
		var d := float(durations[_i]) if _i < durations.size() else 100.0
		while _t >= d:
			_t -= d
			_i += 1
			if _i >= frames.size():
				if loop:
					_i = 0
				else:
					_running = false
					_i = frames.size() - 1
					visible = false
					finished.emit()
					return
			d = float(durations[_i]) if _i < durations.size() else 100.0
		queue_redraw()

	func _draw() -> void:
		var t := frames[_i] if _i < frames.size() else null
		if t:
			draw_texture(t, -pivot)
