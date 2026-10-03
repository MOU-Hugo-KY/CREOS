extends SceneTree
## Captures d'écran du combat. Nécessite un affichage (pas --headless).
##   godot --path . --resolution 1280x720 --script res://tools/screenshot.gd
## Options (après `--`) :
##   --shots=200,600     images où prendre une capture (défaut : 200)
##   --out=res://docs/capture-prototype.png   (plusieurs captures : -1, -2… ajoutés au nom)
##   --auto              active le mode Auto
##   --speed=2           accélère le combat
##   --end               attend l'écran de fin et le capture en dernier
##   --scene=res://scenes/hub/hub.tscn   capture une autre scène (défaut : le combat)

var shots: Array[int] = [200]
var out := "res://docs/capture-prototype.png"
var wait_end := false
var frames := 0
var taken := 0
var end_frame := -1
var scene: Node
var scene_path := "res://scenes/battle/battle.tscn"


func _initialize() -> void:
	var auto := false
	var speed := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots.clear()
			for s in arg.trim_prefix("--shots=").split(","):
				shots.append(int(s))
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--auto":
			auto = true
		elif arg.begins_with("--speed="):
			speed = float(arg.trim_prefix("--speed="))
		elif arg == "--end":
			wait_end = true
		elif arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
	root.get_node("PlayerData").use_memory_only()  # ne touche pas à la vraie sauvegarde
	scene = load(scene_path).instantiate()
	root.add_child(scene)
	if scene.has_method("set_auto"):
		scene.set_auto(auto)
	Engine.time_scale = speed


func _process(_delta: float) -> bool:
	frames += 1
	if frames in shots:
		_save()
	if wait_end and end_frame < 0 and "end_screen" in scene.hud and scene.hud.end_screen.visible:
		end_frame = frames + 150  # laisse le temps aux étoiles d'apparaître
	if end_frame > 0 and frames == end_frame:
		_save()
	var done_shots: bool = frames >= int(shots.max())
	if done_shots and (not wait_end or (end_frame > 0 and frames >= end_frame)) or frames > 30000:
		Engine.time_scale = 1.0
		quit()
	return false


func _save() -> void:
	taken += 1
	var path := out
	var multi := shots.size() + (1 if wait_end else 0) > 1
	if multi:
		path = out.get_basename() + "-%d.png" % taken
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	root.get_texture().get_image().save_png(abs_path)
	print("Capture : ", abs_path)
