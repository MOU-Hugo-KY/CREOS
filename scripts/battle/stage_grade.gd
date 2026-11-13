class_name StageGrade
extends Node2D
## Lumière de la scène de combat, par-dessus les combattants : coins assombris (vignette), bas de l'écran
## un peu plus sombre, lueur du monde en haut à gauche et rayons de lumière qui bougent doucement.
## Affichage seul, textures en dégradé créées une fois (léger sur téléphone).

const SIZE := Vector2(1280, 720)
## Couleur de la lumière par monde.
const WORLD_LIGHT := {
	"monde01": Color(1.0, 0.86, 0.55), "monde02": Color(0.7, 1.0, 0.6), "monde03": Color(1.0, 0.72, 0.4),
	"monde04": Color(1.0, 0.5, 0.25), "monde05": Color(0.95, 0.88, 0.7), "monde06": Color(0.45, 0.95, 0.9),
	"monde07": Color(0.75, 0.88, 1.0), "monde08": Color(1.0, 0.95, 0.8), "monde09": Color(1.0, 0.45, 0.2),
	"monde10": Color(0.75, 0.5, 1.0),
}

static var _disc: GradientTexture2D
static var _vignette: GradientTexture2D

var _light := Color(1.0, 0.86, 0.55)
var _rays := false
var _clock := 0.0
var _glow: Node2D


## Disque blanc doux (plein au centre, transparent au bord) : ombres, lueurs, poussières.
static func disc() -> GradientTexture2D:
	if _disc == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_disc = GradientTexture2D.new()
		_disc.gradient = g
		_disc.fill = GradientTexture2D.FILL_RADIAL
		_disc.fill_from = Vector2(0.5, 0.5)
		_disc.fill_to = Vector2(1.0, 0.5)
		_disc.width = 128
		_disc.height = 128
	return _disc


static func vignette() -> GradientTexture2D:
	if _vignette == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0.06, 0.03, 0.1, 0.0), Color(0.06, 0.03, 0.1, 0.0), Color(0.06, 0.03, 0.1, 0.62)])
		_vignette = GradientTexture2D.new()
		_vignette.gradient = g
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2(1.2, 0.5)
		_vignette.width = 256
		_vignette.height = 256
	return _vignette


func setup(world: String, rays: bool) -> void:
	_light = WORLD_LIGHT.get(world, _light)
	_rays = rays
	z_index = 24
	_glow = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _process(delta: float) -> void:
	_clock += delta
	_glow.queue_redraw()


func _draw() -> void:
	draw_texture_rect(vignette(), Rect2(Vector2(-90, -60), SIZE + Vector2(180, 120)), false)
	# Bas de l'écran un peu plus sombre : le regard reste sur les combattants.
	var top := Color(0.06, 0.03, 0.1, 0.0)
	var low := Color(0.06, 0.03, 0.1, 0.34)
	draw_polygon(PackedVector2Array([Vector2(-90, 600), Vector2(SIZE.x + 90, 600), Vector2(SIZE.x + 90, 790), Vector2(-90, 790)]),
		PackedColorArray([top, top, low, low]))


func _draw_glow() -> void:
	# Lueur du monde, en haut à gauche.
	var breathe := 0.9 + 0.1 * sin(_clock * 0.7)
	_glow.draw_texture_rect(disc(), Rect2(Vector2(-420, -520), Vector2(1300, 1000)), false, Color(_light, 0.2 * breathe))
	if not _rays:
		return
	# Rayons inclinés qui se balancent lentement.
	for i in 4:
		var sway := sin(_clock * 0.25 + i * 1.7) * 26.0
		var x := 120.0 + i * 250.0 + sway
		var w := 70.0 + 28.0 * sin(i * 2.3)
		var a := 0.055 + 0.03 * sin(_clock * 0.5 + i * 2.1)
		var c := Color(_light, a)
		var c0 := Color(_light, 0.0)
		_glow.draw_polygon(PackedVector2Array([Vector2(x, -40), Vector2(x + w, -40), Vector2(x + w + 330, 640), Vector2(x + 250, 640)]),
			PackedColorArray([c, c, c0, c0]))
