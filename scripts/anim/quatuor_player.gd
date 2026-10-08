class_name QuatuorPlayer
extends Node2D
## Lecteur des scènes de quatuor en pixel art (pack ChatGPT, `assets/anim/quatuors/<id>/<id>_quatuor.json`) :
## poses des 4 héros, effets sur calques, grande explosion finale, secousses, voile d'ambiance.
## Espace de référence 512 × 288 (agrandi par le combat). Ne calcule aucun dégât.

signal hit_active(event: Dictionary)
signal finished(formation_id: String)
signal cancelled(formation_id: String)

@export var asset_root: String = "res://assets/anim/quatuors"
var data: Dictionary = {}
var tracks: Array = []
var running := false
var elapsed_ms := 0.0
var event_cursor := 0
var formation := ""
var stage: Node2D
var ambient: Polygon2D
var ghosts: Array[Sprite2D] = []
var facing := 1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func play(id: String) -> bool:
	if running:
		return false
	var folder := asset_root.path_join(id)
	var path := folder.path_join(id + "_quatuor.json")
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	data = parsed
	formation = id
	for child in get_children():
		remove_child(child)
		child.queue_free()
	tracks.clear()
	ghosts.clear()
	stage = Node2D.new()
	add_child(stage)
	for entry in data.actors:
		_add_track(entry, folder, true)
	for entry in data.effects:
		_add_track(entry, folder, false)
	_add_track(data.final, folder, false)
	ambient = Polygon2D.new()
	ambient.polygon = PackedVector2Array([Vector2(-512,-288),Vector2(1024,-288),Vector2(1024,576),Vector2(-512,576)])  # voile sur tout l'écran
	ambient.z_index = 25
	stage.add_child(ambient)
	if data.get("illusion_doubles") != null:
		var g: Dictionary = data.illusion_doubles
		var actor: Dictionary = data.actors[0]
		for pos in g.positions:
			var spr := Sprite2D.new()
			spr.texture = load(folder.path_join(actor.sheet))
			spr.centered = false
			spr.region_enabled = true
			spr.region_rect = Rect2(int(g.frame)*192,0,192,192)
			spr.offset = -Vector2(96,146)
			spr.position = Vector2(pos[0],pos[1])
			spr.scale = Vector2.ONE * float(g.scale)
			spr.z_index = 20
			stage.add_child(spr)
			ghosts.append(spr)
	elapsed_ms = 0.0
	event_cursor = 0
	running = true
	show()
	_update_visuals()
	return true

func _add_track(entry: Dictionary, folder: String, actor: bool) -> void:
	var spr := Sprite2D.new()
	spr.texture = load(folder.path_join(entry.sheet))
	spr.centered = false
	spr.region_enabled = true
	spr.offset = -Vector2(entry.pivot[0],entry.pivot[1])
	spr.scale = Vector2.ONE * float(entry.scale)
	spr.z_index = int(entry.layer)
	if entry.get("blend", "alpha") == "additive":
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spr.material = mat
	stage.add_child(spr)
	tracks.append({"entry":entry,"sprite":spr,"actor":actor})

func face(direction: int) -> void:
	facing = -1 if direction < 0 else 1
	if is_instance_valid(stage):
		_update_visuals()

func _process(delta: float) -> void:
	if running:
		advance(delta * 1000.0)

func advance(milliseconds: float) -> void:
	if not running:
		return
	elapsed_ms = minf(elapsed_ms + maxf(milliseconds,0.0), float(data.duration_ms))
	# Emit every crossed impact, even if a slow frame crosses several at once.
	while event_cursor < data.events.size() and float(data.events[event_cursor].time_ms) <= elapsed_ms:
		var event: Dictionary = data.events[event_cursor]
		event_cursor += 1
		hit_active.emit(event.duplicate(true))
	_update_visuals()
	if elapsed_ms >= float(data.duration_ms):
		running = false
		finished.emit(formation)

func cancel() -> void:
	if not running:
		return
	running = false
	hide()
	cancelled.emit(formation)

func frame_at(entry: Dictionary, relative_ms: float) -> int:
	var cursor := 0.0
	for i in range(entry.frames.size()):
		cursor += float(entry.frames[i].duration_ms)
		if relative_ms < cursor:
			return i
	return entry.frames.size()-1

func _position_at(keys: Array, t: float) -> Vector2:
	var first: Array = keys[0].value
	if t <= float(keys[0].time_ms):
		return Vector2(first[0],first[1])
	for i in range(1,keys.size()):
		if t <= float(keys[i].time_ms):
			var a: Dictionary = keys[i-1]
			var b: Dictionary = keys[i]
			var f := (t-float(a.time_ms))/maxf(1.0,float(b.time_ms)-float(a.time_ms))
			return Vector2(a.value[0],a.value[1]).lerp(Vector2(b.value[0],b.value[1]),f).round()
	var last: Array = keys[-1].value
	return Vector2(last[0],last[1])

func _update_visuals() -> void:
	stage.scale = Vector2(facing,1)
	stage.position = Vector2(512 if facing < 0 else 0,0)
	for quake: Dictionary in data.camera_shake_events:
		var age := elapsed_ms - float(quake.time_ms)
		if age >= 0 and age < float(quake.duration_ms):
			var amplitude := float(quake.amplitude_px)*(1.0-age/float(quake.duration_ms))
			stage.position += Vector2(roundf(sin(age*.13)*amplitude),roundf(cos(age*.19)*amplitude*.5))
	for item: Dictionary in tracks:
		var e: Dictionary = item.entry
		var start := 0.0 if item.actor else float(e.start_ms)
		var end := float(data.duration_ms) if item.actor else start+float(e.duration_ms)
		var spr: Sprite2D = item.sprite
		spr.visible = bool(item.actor) or (elapsed_ms >= start and elapsed_ms < end)
		if spr.visible:
			var frame := frame_at(e,elapsed_ms-start)
			var r: Array = e.frames[frame].rect
			spr.region_rect = Rect2(r[0],r[1],r[2],r[3])
			spr.position = _position_at(e.position_keyframes,elapsed_ms)
			spr.modulate.a = float(e.frames[frame].get("opacity",1.0))*float(e.get("opacity",1.0))
	ambient.visible = data.ambient_overlay != null
	if ambient.visible:
		var a: Dictionary = data.ambient_overlay
		var opacity := minf(1.0,elapsed_ms/float(a.fade_in_ms))
		if elapsed_ms > float(a.fade_out_start_ms):
			opacity *= maxf(0.0,1.0-(elapsed_ms-float(a.fade_out_start_ms))/float(a.fade_out_ms))
		ambient.color = Color(float(a.color[0])/255.0,float(a.color[1])/255.0,float(a.color[2])/255.0,float(a.max_alpha)*opacity)
	if data.get("illusion_doubles") != null:
		var g: Dictionary = data.illusion_doubles
		var age := elapsed_ms-float(g.start_ms)
		var remaining := float(g.end_ms)-elapsed_ms
		var alpha := float(g.opacity)*minf(1.0,maxf(0.0,age/200.0))*minf(1.0,maxf(0.0,remaining/300.0))
		for ghost in ghosts:
			ghost.visible = alpha > 0
			ghost.modulate = Color(.65,.35,1.0,alpha)
