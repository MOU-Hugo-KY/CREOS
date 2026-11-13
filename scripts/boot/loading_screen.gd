extends Control
## Écran de chargement du jeu (scène de démarrage), à la manière des RPG mobiles : la vue du port de nuit
## une illustration de l'équipe tirée au hasard, le logo en haut, et en bas la barre qui suit le vrai chargement du port avec son pourcentage et un conseil.

const NEXT := "res://scenes/hub/hub.tscn"
const LOADING_DIR := "res://assets/ui/loading/"
const MIN_TIME := 1.2  # on voit l'écran au moins ce temps, même si tout est déjà chargé
const TIPS := [
	"Touche un monde sur la carte pour le grossir, puis choisis ton niveau.",
	"Les héros de la même famille ou du même élément se renforcent ensemble.",
	"Quand quatre héros d'un quatuor ont lancé leur ultime, leur combo s'éveille.",
	"Reviens chaque jour au port : les Primes donnent de l'or et des gemmes.",
	"Les doublons d'un héros deviennent des Échos et le rendent plus fort.",
]

var _gauge: FinPack.Gauge
var _pct: Label
var _shown := 0.0
var _time := 0.0
var _done := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0d0b14")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := ScreenPack.frame(self)
	var C: Dictionary = FinPack.data("popups").get("chargement", {})
	# Une illustration de l'équipe tirée au hasard à chaque lancement (assets/ui/loading/chargement_NN.png).
	var pics: Array[String] = []
	for f in DirAccess.get_files_at(LOADING_DIR):
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if name.begins_with("chargement_") and name.ends_with(".png") and not pics.has(name):
			pics.append(name)
	var bg_tex: Texture2D = load(LOADING_DIR + pics[randi() % pics.size()]) if not pics.is_empty() 		else FinPack.tex(String(C.get("background", "popups/chargement.png")))
	var art := ScreenPack.image(root, bg_tex, Rect2(0, 0, 1920, 1080))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Dégradés sombres en haut (logo) et en bas (barre), pour lire par-dessus n'importe quelle image.
	_shade(root, 0.0, 300.0, true)
	_shade(root, 820.0, 260.0, false)
	var logo_tex: Texture2D = load(LOADING_DIR + "logo_creos.png")
	var lw := 760.0
	var lh := lw * logo_tex.get_height() / logo_tex.get_width()
	var logo := ScreenPack.image(root, logo_tex, Rect2(960 - lw / 2, 24, lw, lh))
	logo.pivot_offset = Vector2(lw / 2, lh / 2)
	var pulse := logo.create_tween().set_loops()
	pulse.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(logo, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	var br := Rect2(560, 970, 800, 36)  # dans la bande sombre du bas des images
	_gauge = FinPack.Gauge.new().setup("popups/chargement_barre_fond.png", br, [12, 12, 12, 12],
		"popups/chargement_barre_remplissage.png", Rect2(566, 976, 788, 24))
	_gauge.set_ratio(0.0)
	root.add_child(_gauge)
	_pct = ScreenPack.shadow(ScreenPack.text(root, "0 %", Rect2(br.end.x + 16, br.position.y - 4, 120, br.size.y + 8), 28,
		Color("f3d9a0")), 2)
	_pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tip := ScreenPack.shadow(ScreenPack.text(root, String(TIPS[randi() % TIPS.size()]),
		Rect2(360, 1020, 1200, 45), 24, Color("eee4cd"),
		HORIZONTAL_ALIGNMENT_CENTER), 2)
	tip.autowrap_mode = TextServer.AUTOWRAP_OFF
	ResourceLoader.load_threaded_request(NEXT)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


func _shade(root: Control, y: float, h: float, from_top: bool) -> void:
	var grad := GradientTexture2D.new()
	grad.width = 4
	grad.height = 64
	grad.gradient = Gradient.new()
	var dark := Color(0.03, 0.02, 0.07, 0.7)
	var clear := Color(0.03, 0.02, 0.07, 0.0)
	grad.gradient.colors = PackedColorArray([dark, clear] if from_top else [clear, dark])
	grad.fill_to = Vector2(0, 1)
	var r := TextureRect.new()
	r.texture = grad
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = Vector2(-600, y)  # déborde du cadre sur les écrans plus larges
	r.size = Vector2(3120, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(NEXT, progress)
	var target := 1.0 if status == ResourceLoader.THREAD_LOAD_LOADED else float(progress[0]) if not progress.is_empty() else 0.0
	# La barre avance en douceur, sans jamais dépasser la part du temps minimum écoulée.
	target = minf(target, _time / MIN_TIME)
	_shown = move_toward(_shown, target, delta * 1.6)
	_gauge.set_ratio(_shown)
	_pct.text = "%d %%" % int(roundf(_shown * 100.0))
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		get_tree().change_scene_to_file(NEXT)  # secours : chargement classique
	elif status == ResourceLoader.THREAD_LOAD_LOADED and _shown >= 0.999:
		_done = true
		var scene: PackedScene = ResourceLoader.load_threaded_get(NEXT)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void: get_tree().change_scene_to_packed(scene))

