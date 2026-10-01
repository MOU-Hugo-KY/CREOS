class_name PixelStyle
extends RefCounted
## Style « low-poly pixel art » de CREOS.
## 1. La 3D est rendue en basse résolution puis agrandie sans flou (voir PixelStage).
## 2. Les matériaux passent en éclairage « toon » (aplats nets) et en textures sans lissage.
## 3. Un contour sombre (coque inversée) dessine la silhouette, 1 pixel à l'écran.

const OUTLINE_COLOR := Color(0.08, 0.06, 0.1)
const OUTLINE_WIDTH := 0.035

static var _outline: StandardMaterial3D


## Applique le style à tous les MeshInstance3D sous `root`.
static func apply(root: Node, outline := true, tint := Color.WHITE) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var mat: StandardMaterial3D
			if src is StandardMaterial3D:
				mat = src.duplicate()
			else:
				mat = StandardMaterial3D.new()
			mat.albedo_color *= tint
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.roughness = 1.0
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if outline:
				mat.next_pass = _outline_material()
			mi.set_surface_override_material(i, mat)


static func _outline_material() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.albedo_color = OUTLINE_COLOR
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = OUTLINE_WIDTH
	return _outline
