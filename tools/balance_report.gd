extends SceneTree
## Rapport d'équilibrage de la campagne : une équipe de 7, à différents niveaux, contre le
## premier et le dernier niveau de chaque monde (10 combats simulés par case).
##   godot --headless --path . --script res://tools/balance_report.gd

const GameDataScript := preload("res://scripts/core/game_data.gd")
## Équipe de 7 typique : 3 rares, 2 épiques, 2 légendaires, rôles variés (formation 2 / 3 / 2).
const TEAM := ["aegis", "kharok", "nyx", "corbin", "brume", "orage", "braise"]


func _initialize() -> void:
	var gd: Node = GameDataScript.new()
	gd.reload()
	var levels := [1, 10, 20, 30, 40, 50, 60]
	print("niveau des héros -> victoires /10 (niveau 1 et 8 de chaque monde)")
	var header := "monde      "
	for l in levels:
		header += "  N%-5d" % l
	print(header)
	for rid: String in gd.region_ids():
		var ids: Array = gd.region_dungeons(rid)
		for did: String in [ids[0], ids[-1]]:
			var line := "%-11s" % did
			for l: int in levels:
				var team: Array = TEAM.map(func(id: String) -> Dictionary:
					return Progression.hero_for_battle(gd.hero(id), l, gd.progression))
				var wins := 0
				for s in 10:
					var e := BattleEngine.new()
					e.setup(team, gd.dungeon_waves_for(did, team.size()), s, gd.team_combos(), gd.synergies())
					if e.simulate(400.0):
						wins += 1
				line += "  %-6d" % wins
			print(line)
	gd.free()
	quit()
