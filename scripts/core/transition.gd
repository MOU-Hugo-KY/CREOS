extends CanvasLayer
## Changement de scène en fondu : un iris d'encre cerclé de laiton se referme, la scène change, il se rouvre.
## Autoload `Transition`. Sans affichage (tests), le changement est immédiat.

const SHADER := "shader_type canvas_item;
uniform float r = 1.2;
uniform float ratio = 1.78;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(ratio, 1.0);
	float d = length(p);
	float a = smoothstep(r, r + 0.015, d);
	float ring = smoothstep(0.014, 0.0, abs(d - r - 0.004)) * step(r, 1.15);
	vec3 col = mix(vec3(0.085, 0.065, 0.105), vec3(0.78, 0.65, 0.42), ring);
	COLOR = vec4(col, max(a, ring));
}"

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func go(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file(path)
		return
	if _busy:
		return
	_busy = true
	var vs := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("ratio", vs.x / maxf(1.0, vs.y))
	_mat.set_shader_parameter("r", 1.2)
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(_set_r, 1.2, 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(path)
	# Le chargement fige le jeu un instant : on attend qu'il soit passé pour rouvrir l'iris en douceur.
	for i in 4:
		await get_tree().process_frame
	tw = create_tween().set_ignore_time_scale(true)
	tw.tween_method(_set_r, 0.0, 1.2, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_rect.visible = false
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false)


func _set_r(v: float) -> void:
	_mat.set_shader_parameter("r", v)
