extends SceneTree
## Capture d'écran du combat (après ~3 s) dans docs/capture-prototype.png.
## Nécessite un affichage (pas --headless) :
##   godot --path . --resolution 1280x720 --script res://tools/screenshot.gd

const OUT := "res://docs/capture-prototype.png"
const FRAMES := 200

var frames := 0


func _initialize() -> void:
	root.add_child(load("res://scenes/battle/battle.tscn").instantiate())


func _process(_delta: float) -> bool:
	frames += 1
	if frames == FRAMES:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
		print("Capture : ", OUT)
		quit()
	return false
