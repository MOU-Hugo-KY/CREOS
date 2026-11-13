extends SceneTree
## Lisse la difficulté de la campagne : pour chaque niveau, cherche le multiplicateur qui donne ~6/10
## victoires au niveau de héros visé (1 au début, 58 au boss final), puis ne garde que l'écart avec ses
## voisins (moyenne glissante) : les « murs » et les creux disparaissent sans changer la difficulté
## générale, voulue par progression.json. Bornes 0,75 – 1,3. Écrit data/difficulty.json.
##   godot --headless --path . --script res://tools/calibrate_difficulty.gd

const GameDataScript := preload("res://scripts/core/game_data.gd")
const TEAM := ["aegis", "kharok", "nyx", "corbin", "brume", "orage", "braise"]
const SIMS := 12
const GOAL := 7  # victoires visées sur SIMS


static func target_level(world: int, level: int) -> int:
	# 1 -> 1, monde10_8 -> 58 : un peu de marge sous le maximum (60).
	var i := (world - 1) * 8 + (level - 1)  # 0..79
	return clampi(1 + roundi(57.0 * i / 79.0), 1, 60)


func _initialize() -> void:
	var gd: Node = GameDataScript.new()
	gd.reload()
	gd.difficulty = {"dungeons": {}}
	var out := {}
	for rid: String in gd.region_ids():
		var world := int(rid.trim_prefix("monde"))
		for did: String in gd.region_dungeons(rid):
			var lvl := int(gd.dungeons[did].get("level", 1))
			var hl := target_level(world, lvl)
			var team: Array = TEAM.map(func(id: String) -> Dictionary:
				return Progression.hero_for_battle(gd.hero(id), hl, gd.progression))
			var lo := 0.2
			var hi := 4.0
			for it in 9:
				var m := sqrt(lo * hi)
				gd.difficulty.dungeons[did] = m
				var wins := 0
				for s in SIMS:
					var e := BattleEngine.new()
					e.setup(team, gd.dungeon_waves_for(did, team.size()), s, gd.team_combos(), gd.synergies())
					if e.simulate(400.0):
						wins += 1
				if wins >= GOAL:
					lo = m
				else:
					hi = m
			var k := snappedf(lo, 0.01)
			gd.difficulty.dungeons[did] = k
			out[did] = k
			print("%s  héros niv.%d  ×%.2f" % [did, hl, k])
	# Écart avec la tendance (moyenne géométrique des 9 voisins) : on corrige seulement les bosses.
	var ids: Array = out.keys()
	var raw: Array = ids.map(func(d: String) -> float: return float(out[d]))
	for i in ids.size():
		var acc := 0.0
		var n := 0
		for j in range(maxi(0, i - 4), mini(ids.size(), i + 5)):
			acc += log(raw[j])
			n += 1
		var trend := exp(acc / n)
		out[ids[i]] = snappedf(clampf(raw[i] / trend, 0.75, 1.3), 0.01)  # niveau facile (raw haut) -> plus dur
	out["monde10_8"] = minf(float(out.get("monde10_8", 1.0)), 0.9)  # boss final gagnable un peu avant le niveau 60
	var f := FileAccess.open("res://data/difficulty.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"_note": "Écrit par tools/calibrate_difficulty.gd : multiplicateur des ennemis par niveau (courbe continue, ~6/10 victoires au niveau de héros visé).", "dungeons": out}, "  "))
	f.close()
	gd.free()
	quit()
