class_name RoomAmbiance
extends Control
## Effets d'ambiance d'une salle d'invocation (pack « FX Ambiance », assets/ui/invocateurs/ambiance/,
## positions dans fx_ambiances.json) : bougies, poussière, vapeur, lucioles… en boucle, décalés
## dans le temps. `dim(true)` baisse les effets décoratifs (pas les bougies) pendant une invocation.

const DIR := "res://assets/ui/invocateurs/ambiance/"

var _items: Array = []  # [Sheet, opacité, atténuable]


static func make(room: String) -> RoomAmbiance:
	var a := RoomAmbiance.new()
	a.size = Vector2(1920, 1080)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var data := GameData.load_json(DIR + "fx_ambiances.json")
	var anims: Dictionary = data.get("animations", {})
	for e: Dictionary in data.get("salles", {}).get(room, []):
		var name := String(e.animation)
		var s := MageRoom.Sheet.new()
		s.base_dir = DIR
		s.anims = anims
		s.position = Vector2(e.position[0], e.position[1])
		s.scale = Vector2(e.get("scale", [1, 1])[0], e.get("scale", [1, 1])[1])
		s.modulate.a = float(e.get("opacity", 1.0))
		s.z_index = int(e.get("z_index", 0))
		a.add_child(s)
		s.play(name)
		s._frame = int(e.get("phase", 0)) % maxi(1, int(anims.get(name, {}).get("frame_count", 1)))
		a._items.append([s, float(e.get("opacity", 1.0)), bool(e.get("dim_during_invocation", true))])
	return a


func dim(on: bool) -> void:
	for it: Array in _items:
		if it[2]:
			create_tween().tween_property(it[0], "modulate:a", float(it[1]) * (0.4 if on else 1.0), 0.3)
