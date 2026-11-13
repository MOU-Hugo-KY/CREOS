class_name AlbumScreen
extends UiWindow
## Album des monstres : tous les monstres de la campagne, ceux déjà vaincus en couleur (avec leur nombre
## de victoires), les autres en ombre. Tous les 10 monstres découverts, 50 gemmes (PlayerData._record_album).

signal ui_sound(name: String)

const COLS := 8
const ROWS := 3

var _grid: GridContainer
var _info: Label
var _page_label: Label
var _page := 0
var _ids: Array = []


func _init() -> void:
	setup("Album des monstres", Vector2(1500, 860))


func _ready() -> void:
	super._ready()
	_info = UiKit.label("", 22)
	content.add_child(_info)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_grid)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	content.add_child(nav)
	var prev := UiKit.button("◀", "wood", 28, Vector2(90, 60))
	prev.pressed.connect(func() -> void: _turn(-1))
	nav.add_child(prev)
	_page_label = UiKit.label("", 24)
	nav.add_child(_page_label)
	var next := UiKit.button("▶", "wood", 28, Vector2(90, 60))
	next.pressed.connect(func() -> void: _turn(1))
	nav.add_child(next)
	# Monstres dans l'ordre de la campagne (premier donjon où on les croise).
	for rid: String in GameData.region_ids():
		for did: String in GameData.region_dungeons(rid):
			for wave: Array in GameData.dungeons[did].get("waves", []):
				for mid: String in wave:
					if mid not in _ids and GameData.monsters.has(mid):
						_ids.append(mid)


func open() -> void:
	super.open()
	_fill()


func _pages() -> int:
	return maxi(1, ceili(_ids.size() / float(COLS * ROWS)))


func _turn(d: int) -> void:
	ui_sound.emit("ui_click")
	_page = posmod(_page + d, _pages())
	_fill()


func _fill() -> void:
	var seen := PlayerData.album()
	var found := 0
	for mid: String in _ids:
		if seen.has(mid):
			found += 1
	var next_gift := (found / PlayerData.ALBUM_STEP + 1) * PlayerData.ALBUM_STEP
	_info.text = "%d / %d monstres découverts — prochain cadeau (%d gemmes) à %d." % [found, _ids.size(),
		PlayerData.ALBUM_GEMS, mini(next_gift, _ids.size())]
	_page_label.text = "%d / %d" % [_page + 1, _pages()]
	for c in _grid.get_children():
		c.queue_free()
	var start := _page * COLS * ROWS
	for i in range(start, mini(start + COLS * ROWS, _ids.size())):
		_grid.add_child(_cell(String(_ids[i]), seen))


func _cell(mid: String, seen: Dictionary) -> Control:
	var m: Dictionary = GameData.monsters[mid]
	var known := seen.has(mid)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card(Color("c6a66c") if known and m.get("boss", false) else Color.TRANSPARENT))
	card.custom_minimum_size = Vector2(165, 200)
	var box := Control.new()
	box.custom_minimum_size = Vector2(150, 140)
	box.clip_contents = true
	var v := VBoxContainer.new()
	v.add_child(box)
	card.add_child(v)
	var p := ClipPlayer.new()
	p.bundle = String(m.get("anim", ""))
	p.sound_enabled = false
	p.show_effects = false
	p.position = Vector2(75, 130)
	var k := 120.0 / maxf(80.0, float(m.get("size", 160)))
	p.scale = Vector2(k, k)
	box.add_child(p)
	if p.has_clip(mid + "_idle"):
		p.play(mid + "_idle")
		p.idle_clip = mid + "_idle"
	if not known:
		p.modulate = Color(0, 0, 0, 0.75)  # silhouette
		p.speed = 0.0
	var name := UiKit.label(String(m.get("name", mid)) if known else "???", 16)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.custom_minimum_size = Vector2(150, 0)
	v.add_child(name)
	if known:
		var n := UiKit.label("vaincu ×%d" % int(seen[mid]), 14, Color("505e75"))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
	return card
