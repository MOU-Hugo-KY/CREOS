extends SceneTree
## Test de fumée : charge la vraie scène de combat, active le mode Auto et attend la fin.
## Lancer : godot --headless --path . --script res://tests/smoke_battle.gd

var scene: Node
var frames := 0


func _initialize() -> void:
	scene = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(scene)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		scene._auto_button.button_pressed = true
	if scene.engine.finished or frames > 20000:
		print("fini=%s gagné=%s durée=%.1fs unités affichées=%d vague=%d" % [
			scene.engine.finished, scene.engine.won, scene.engine.time,
			scene.views.size(), scene.engine.wave_index + 1,
		])
		quit(0 if scene.engine.finished else 1)
	return false
