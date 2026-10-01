extends Control
## Affiche une scène 3D en « pixel art » : rendu dans un SubViewport basse résolution,
## agrandi en plus-proche-voisin (pixels nets). L'interface (CanvasLayer) reste en pleine résolution.

## Taille d'un « gros pixel » en pixels d'écran (3 = assez fin, 5 = très rétro).
@export_range(1, 8) var pixel_size := 4
@export_file("*.tscn") var scene_path := "res://scenes/battle/battle.tscn"

var container: SubViewportContainer
var viewport: SubViewport


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	container = SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = pixel_size
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.handle_input_locally = false
	container.add_child(viewport)

	var scene: Node = load(scene_path).instantiate()
	viewport.add_child(scene)
	# L'interface reste en pleine résolution, au-dessus du rendu pixel.
	var hud: Node = scene.get_node_or_null("HUD")
	if hud:
		hud.reparent(self)
