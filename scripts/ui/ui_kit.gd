class_name UiKit
extends RefCounted
## Kit d'interface de CREOS : le même langage visuel partout (hub, écrans, combat).
##
## Style « fantasy occulte encrée », assorti aux héros dessinés : ivoire cerclé d'encre noire
## avec une ombre dure en dessous (comme un dessin), bordeaux, laiton, ardoise et magie turquoise.
## Boutons en relief (une tranche plus foncée en dessous, qui s'écrase quand on appuie),
## police Fredoka, textes clairs à contour d'encre sur la couleur.

const FONT := preload("res://assets/fonts/Fredoka_SemiBold.tres")
const FONT_BOLD := preload("res://assets/fonts/Fredoka_Bold.tres")

# Bois et parchemin
const INK := Color("29262e")  # encre : contours et texte sur l'ivoire
const WOOD := Color("793b49")  # bordeaux (titres de section, accents)
const WOOD_LIGHT := Color("c6a66c")  # laiton (bordures des cartes)
const PARCHMENT := Color("eee4cd")  # ivoire
const PARCHMENT_DARK := Color("d3c4a6")
const NIGHT := Color("34323c")  # panneaux sombres
const SLATE := Color("505e75")
const TEAL := Color("63c8be")  # magie
const SHADOW := Color(0.05, 0.05, 0.08, 0.9)
const TEXT_ON_PARCHMENT := Color("29262e")
const TEXT_SOFT := Color("6e6452")
const WHITE := Color("f6efdf")

# Couleurs de boutons : [dessus, tranche]
const BUTTONS := {
	"green": [Color("3fa79c"), Color("1f5f59")],  # turquoise : récupérer, valider
	"gold": [Color("c6a66c"), Color("7d6436")],  # laiton
	"blue": [Color("505e75"), Color("2c3445")],  # ardoise : y aller, naviguer
	"red": [Color("793b49"), Color("3f1d26")],  # bordeaux : action principale, fermer
	"purple": [Color("6d4f8c"), Color("3a2950")],
	"wood": [Color("8a7a5e"), Color("4d4334")],
	"grey": [Color("a39b8b"), Color("6a6356")],
}
const DEPTH := 7  # épaisseur de la tranche des boutons, en pixels


static func box(bg: Color, border := Color.TRANSPARENT, radius := 18, border_width := 0,
		shadow := 0, shadow_offset := Vector2(0, 5)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_color = SHADOW
		sb.shadow_size = shadow
		sb.shadow_offset = shadow_offset
	return sb


## Parchemin cerclé de bois : le fond des fenêtres et des cartes.
static func parchment(radius := 18, border := 4) -> StyleBoxFlat:
	var sb := box(PARCHMENT, INK, radius, border, 0)
	sb.border_width_bottom = border + 8  # ombre dure, comme un dessin encré
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 10)
	sb.set_content_margin_all(18)
	return sb


## Carte claire posée sur le parchemin (une quête, une statistique…).
static func card(highlight := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := box(Color("f6efdf"), INK if highlight.a == 0.0 else highlight, 12, 2, 0)
	sb.border_width_bottom = 5
	sb.set_content_margin_all(12)
	return sb


## Pilule sombre semi-transparente (ressources, infos sur le décor).
static func pill() -> StyleBoxFlat:
	var sb := box(Color(0.1, 0.07, 0.06, 0.62), Color(1, 0.9, 0.7, 0.25), 30, 2)
	sb.content_margin_left = 8
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func _button_box(top: Color, edge: Color, pressed: bool) -> StyleBoxFlat:
	var sb := box(top, edge.darkened(0.25), 16, 3)
	sb.border_width_bottom = 3 if pressed else DEPTH
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10 + (DEPTH - 3 if pressed else 0)
	sb.content_margin_bottom = 8
	return sb


## Gros bouton en relief. `kind` : green, gold, blue, red, purple, wood, grey.
static func button(text: String, kind := "green", font_size := 26, min_size := Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	style_button(b, kind, font_size)
	return b


static func style_button(b: Button, kind := "green", font_size := 26) -> void:
	var c: Array = BUTTONS.get(kind, BUTTONS.green)
	b.add_theme_stylebox_override("normal", _button_box(c[0], c[1], false))
	b.add_theme_stylebox_override("hover", _button_box(c[0].lightened(0.08), c[1], false))
	b.add_theme_stylebox_override("pressed", _button_box(c[0].darkened(0.06), c[1], true))
	b.add_theme_stylebox_override("disabled", _button_box(BUTTONS.grey[0], BUTTONS.grey[1], false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", FONT_BOLD)
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75))
	b.add_theme_color_override("font_outline_color", c[1].darkened(0.45))
	b.add_theme_constant_override("outline_size", 6)


## Bouton rond rouge « fermer » (croix), en haut à droite des fenêtres.
static func close_button() -> Button:
	var b := button("✕", "red", 30, Vector2(62, 62))
	for state in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		sb.set_corner_radius_all(31)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		b.add_theme_stylebox_override(state, sb)
	return b


static func label(text: String, size := 24, color := TEXT_ON_PARCHMENT, outline := 0,
		outline_color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", outline_color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Titre blanc à gros contour (sur le décor ou un ruban).
static func title(text: String, size := 40, color := WHITE) -> Label:
	var l := label(text, size, color, 12, INK)
	l.add_theme_font_override("font", FONT_BOLD)
	return l


## Barre de progression arrondie. Mettre à jour avec `bar.value`.
static func progress(color := Color("63c8be"), height := 22.0, show_text := false) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(0, height)
	p.show_percentage = show_text
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := box(Color(0.24, 0.15, 0.1, 0.85), INK, int(height / 2.0), 2)
	var fill := box(color, color.darkened(0.3), int(height / 2.0), 0)
	fill.border_width_bottom = 4
	fill.border_color = color.darkened(0.25)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fill)
	p.add_theme_font_size_override("font_size", int(height * 0.7))
	return p


## Petite pastille rouge de notification (« ! » ou un nombre).
static func badge(text := "!") -> Label:
	var l := label(text, 18, WHITE, 4, Color("7a1a12"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(30, 30)
	var sb := box(Color("e8443a"), WHITE, 15, 3)
	l.add_theme_stylebox_override("normal", sb)
	return l


## Icône carrée d'une image de `assets/ui/hub/` (ou null si absente).
static func icon(name: String, size := 40.0) -> TextureRect:
	var t := TextureRect.new()
	var path := "res://assets/ui/hub/" + name + ".png"
	t.texture = load(path) if ResourceLoader.exists(path) else null
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Petite étiquette de récompense : icône + quantité, sur fond crème.
static func reward_chip(icon_name: String, amount: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color("fff1d2"), PARCHMENT_DARK.darkened(0.15), 14, 2)
	sb.content_margin_left = 4
	sb.content_margin_right = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	p.add_child(h)
	h.add_child(icon(icon_name, 30))
	h.add_child(label("×%d" % amount, 18, TEXT_ON_PARCHMENT))
	return p


## Animation d'apparition commune : petit rebond.
static func pop_in(c: Control, delay := 0.0) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * 0.85
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.15).set_delay(delay)


## Thème de base des écrans : police, parchemin, défilement discret.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT_ON_PARCHMENT)
	t.set_stylebox("panel", "PanelContainer", parchment())
	t.set_stylebox("grabber", "VScrollBar", box(WOOD_LIGHT, Color.TRANSPARENT, 6))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(WOOD, Color.TRANSPARENT, 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(WOOD, Color.TRANSPARENT, 6))
	var track := box(Color(0.4, 0.25, 0.15, 0.15), Color.TRANSPARENT, 6)
	track.content_margin_left = 6
	track.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", track)
	var edit := box(Color("fffaf0"), WOOD_LIGHT, 12, 3)
	edit.set_content_margin_all(10)
	t.set_stylebox("normal", "LineEdit", edit)
	var edit_focus := box(Color("fffaf0"), Color("c6a66c"), 12, 3)
	edit_focus.set_content_margin_all(10)
	t.set_stylebox("focus", "LineEdit", edit_focus)
	t.set_color("font_color", "LineEdit", TEXT_ON_PARCHMENT)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_font_size("font_size", "LineEdit", 24)
	return t
