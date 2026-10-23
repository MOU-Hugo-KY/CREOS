extends SceneTree
## Tests de la défense de base : règles du moteur, puis la scène tourne sans erreur.
## Lancer : godot --headless --path . --script res://tests/smoke_defense.gd

var _failures := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)


func _cfg() -> Dictionary:
	return JSON.parse_string(FileAccess.open("res://data/defense.json", FileAccess.READ).get_as_text())


func _initialize() -> void:
	var e := DefenseEngine.new()
	e.setup(_cfg(), 3)
	var gold := e.gold
	check(e.place("guerrier", Vector2i(3, 4)) != 0, "on pose un guerrier dans la zone")
	check(e.gold == gold - 50, "le guerrier coûte 50 or")
	check(e.place("archer", Vector2i(3, 4)) == 0, "une case occupée est refusée")
	check(e.place("archer", Vector2i(10, 4)) == 0, "hors de la zone de construction, refusé")
	check(e.place("archer", e.castle_cell()) == 0, "pas sur le château")
	var hero := e.place("archere", Vector2i(2, 2))
	check(hero != 0 and e.place("archere", Vector2i(2, 3)) == 0, "un seul exemplaire de chaque héros")
	e.place("tour", Vector2i(4, 5))
	check(e.use_skill(hero), "la compétence est prête au départ")
	check(not e.use_skill(hero), "puis elle recharge")

	# même graine, mêmes ordres -> même résultat
	var results := []
	for run in 2:
		var d := DefenseEngine.new()
		d.setup(_cfg(), 11)
		d.place("guerrier", Vector2i(4, 4))
		d.place("tour", Vector2i(5, 3))
		for i in 3000:
			d.step(0.05)
		results.append([d.wave, d.castle_hp, d.gold, d.units.size()])
	check(results[0] == results[1], "déterministe : %s" % [results[0]])
	check(results[0][0] >= 3, "les vagues continuent d'arriver")

	# sans défense, le château finit par tomber
	var f := DefenseEngine.new()
	f.setup(_cfg(), 5)
	for i in 20000:
		f.step(0.05)
		if f.finished:
			break
	check(f.finished and f.castle_hp == 0, "sans défense, défaite à la vague %d" % f.wave)

	var scene: Node = load("res://scenes/defense/defense.tscn").instantiate()
	root.add_child(scene)
	check(scene.get_script() != null, "la scène de défense se charge")
	print("\n%d échec(s)" % _failures)


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 30:
		quit(1 if _failures > 0 else 0)
	return false
