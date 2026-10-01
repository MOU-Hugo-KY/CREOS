class_name Palette
extends RefCounted
## Couleurs et thème de l'interface de combat (affichage seulement).

const GOLD := Color(1.0, 0.8, 0.35)
const GOLD_DARK := Color(0.55, 0.4, 0.15)
const PANEL := Color(0.07, 0.08, 0.1, 0.88)
const PANEL_LIGHT := Color(0.16, 0.17, 0.2, 0.95)
const TEXT := Color(0.95, 0.93, 0.88)
const TEXT_DIM := Color(0.65, 0.65, 0.68)
const HP_HERO := Color(0.36, 0.86, 0.38)
const HP_ENEMY := Color(0.92, 0.3, 0.27)
const HP_LOW := Color(0.98, 0.55, 0.2)
const SHIELD := Color(0.55, 0.82, 1.0)
const ENERGY := Color(0.35, 0.75, 1.0)
const COOLDOWN := Color(0.7, 0.55, 1.0)
const HEAL := Color(0.45, 1.0, 0.5)

const ELEMENT_COLORS := {
	"feu": Color(1.0, 0.45, 0.18),
	"eau": Color(0.25, 0.6, 1.0),
	"nature": Color(0.45, 0.85, 0.3),
	"lumiere": Color(1.0, 0.9, 0.45),
	"ombre": Color(0.65, 0.35, 0.95),
}

const ELEMENT_NAMES := {
	"feu": "Feu", "eau": "Eau", "nature": "Nature", "lumiere": "Lumière", "ombre": "Ombre",
}


const CLASS_NAMES := {
	"gardien": "Gardien", "lame": "Lame", "arcaniste": "Arcaniste", "traqueur": "Traqueur", "mystique": "Mystique",
}

# Rareté (GDD §3.4) : nom et couleur.
const RARITIES := {
	1: ["Commun", Color(0.7, 0.7, 0.72)],
	2: ["Rare", Color(0.35, 0.6, 1.0)],
	3: ["Épique", Color(0.72, 0.42, 1.0)],
	4: ["Légendaire", Color(1.0, 0.78, 0.3)],
	5: ["Mythique", Color(1.0, 0.35, 0.3)],
	6: ["Relique Ancienne", Color(0.95, 0.95, 1.0)],
}


static func element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, Color(0.8, 0.8, 0.8))


static func stylebox(bg: Color, border := Color.TRANSPARENT, radius := 14, border_width := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


## Thème commun : boutons arrondis, textes avec contour.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 6)

	t.set_stylebox("normal", "Button", stylebox(PANEL_LIGHT, GOLD_DARK, 12, 2))
	t.set_stylebox("hover", "Button", stylebox(PANEL_LIGHT.lightened(0.1), GOLD, 12, 2))
	t.set_stylebox("pressed", "Button", stylebox(PANEL_LIGHT.darkened(0.2), GOLD, 12, 3))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", stylebox(PANEL.darkened(0.2), Color(0.3, 0.3, 0.3), 12, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Button", 4)
	t.set_font_size("font_size", "Button", 28)

	t.set_stylebox("panel", "PanelContainer", stylebox(PANEL, Color(1, 1, 1, 0.08), 18, 2))
	t.set_stylebox("panel", "Panel", stylebox(PANEL, Color(1, 1, 1, 0.08), 18, 2))
	return t
