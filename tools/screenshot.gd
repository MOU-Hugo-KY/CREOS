extends SceneTree
## Capture d'écran d'une scène (par défaut le combat en pixel art) après ~3 s.
## Nécessite un affichage (pas --headless) :
##   godot --path . --resolution 1280x720 --script res://tools/screenshot.gd -- [scene.tscn] [sortie.png] [frames]

var frames := 0
var target := 200
var out := "res://docs/capture-prototype.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := args[0] if args.size() > 0 else "res://scenes/pixel_battle.tscn"
	if args.size() > 1:
		out = args[1]
	if args.size() > 2:
		target = int(args[2])
	root.add_child(load(scene).instantiate())


func _process(_delta: float) -> bool:
	frames += 1
	if frames == target:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
		print("Capture : ", out)
		quit()
	return false
