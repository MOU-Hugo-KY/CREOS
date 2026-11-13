extends SceneTree
## Comparaison animée du dessin d'origine et d'une planche enrichie.
## godot --path . --script res://tools/preview_pixel_animation.gd
## Vidéo : ajouter --write-movie comparaison.avi --fixed-fps 30 --quit-after 270

class Pose extends Node2D:
	var sheet: PixelSheet
	var animation := ""
	var time := 0.0
	var duration := 1.3
	var impact := 0.702

	func _draw() -> void:
		if sheet == null:
			return
		var texture := sheet.frame_at(animation, time, duration, impact)
		var factor := sheet.frame_scale(texture)
		draw_line(Vector2(-180, 0), Vector2(180, 0), Color("536172"), 1.0)
		draw_circle(Vector2.ZERO, 4.0, Color("d8bc78"))
		draw_set_transform(-sheet.frame_anchor(texture) * factor, 0, Vector2.ONE * factor)
		draw_texture(texture, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)

var poses: Array[Pose] = []
var caption: Label
var marker: ColorRect
var elapsed := 0.0
var phase := 0.0


func _initialize() -> void:
	_build.call_deferred()


func _label(parent: Node, text: String, at: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _build() -> void:
	root.get_node("PlayerData").use_memory_only()
	root.content_scale_size = Vector2i(1280, 720)
	var canvas := Node2D.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("182029")
	background.size = Vector2(1280, 720)
	canvas.add_child(background)
	_label(canvas, "CREOS / CORBIN", Vector2(64, 42), 36, Color("eee4cd"))
	_label(canvas, "Entaille du corbeau · comparaison des poses", Vector2(64, 92), 23, Color("a8b6be"))
	var sheet := PixelSheet.for_actor("corbin")
	var clip := ClipPlayer.load_clip("res://assets/anim/heroes/", "corbin_0")
	for i in 2:
		var pose := Pose.new()
		pose.sheet = sheet
		pose.animation = "attack_1_original" if i == 0 else "attack_1"
		pose.duration = float(clip.dur)
		pose.impact = float(clip.cue[0][0])
		pose.position = Vector2(320 + i * 640, 505)
		pose.scale = Vector2.ONE * 0.9
		canvas.add_child(pose)
		poses.append(pose)
	_label(canvas, "AVANT · 8 poses", Vector2(190, 178), 28, Color("c4a89a"))
	_label(canvas, "APRÈS · 16 poses", Vector2(820, 178), 28, Color("63c8be"))
	caption = _label(canvas, "Vitesse normale", Vector2(64, 580), 25, Color("eee4cd"))
	_label(canvas, "Même instant d'impact · taille et pieds recalés · dessins originaux conservés",
		Vector2(64, 625), 21, Color("a8b6be"))
	marker = ColorRect.new()
	marker.position = Vector2(64, 674)
	marker.size = Vector2(1152, 5)
	canvas.add_child(marker)


func _process(delta: float) -> bool:
	if poses.is_empty():
		return false
	elapsed += delta
	var slow := elapsed >= 3.6
	phase += delta * (0.5 if slow else 1.0)
	var t := fposmod(phase, 1.8)
	caption.text = "Ralenti ×0,5" if slow else "Vitesse normale"
	marker.color = Color("d8bc78") if absf(t - poses[0].impact) < 0.045 else Color("34404c")
	for pose in poses:
		pose.time = t
		pose.queue_redraw()
	return false
