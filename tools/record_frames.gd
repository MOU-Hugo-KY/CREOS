extends SceneTree
## Enregistre une suite d'images d'une scène (pour faire un GIF ou une vidéo avec ffmpeg).
##   godot --path . --resolution 960x540 --script res://tools/record_frames.gd -- <scene.tscn> <dossier> [nb_images] [tous_les_n_frames]

var frames := 0
var saved := 0
var count := 90
var every := 3
var out_dir := "/tmp/frames"
var start := 30


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := args[0] if args.size() > 0 else "res://scenes/pixel_battle.tscn"
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		count = int(args[2])
	if args.size() > 3:
		every = int(args[3])
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.add_child(load(scene).instantiate())


func _process(_delta: float) -> bool:
	frames += 1
	if frames > start and frames % every == 0:
		root.get_texture().get_image().save_png("%s/f%04d.png" % [out_dir, saved])
		saved += 1
		if saved >= count:
			print("Images : ", saved, " dans ", out_dir)
			quit()
	return false
