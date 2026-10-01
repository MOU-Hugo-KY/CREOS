class_name HeroCard
extends PanelContainer
## Carte d'un héros en bas de l'écran : portrait rond, PV, énergie et ses 3 boutons d'attaque.

signal attack_pressed(slot: int)

const PORTRAIT_SIZE := 132
const PORTRAIT_SHADER := """
shader_type canvas_item;
uniform vec4 ring_color : source_color = vec4(1.0);
uniform vec4 bg_color : source_color = vec4(0.2, 0.2, 0.25, 1.0);
uniform float grey = 0.0;
uniform float glow = 0.0;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	vec4 tex = texture(TEXTURE, UV);
	vec3 bg = mix(bg_color.rgb * 0.35, bg_color.rgb * 0.9, smoothstep(1.0, 0.0, UV.y));
	vec3 c = mix(bg, tex.rgb, tex.a);
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(g) * 0.55, grey);
	float ring = smoothstep(0.84, 0.88, r);
	c = mix(c, ring_color.rgb * (1.0 + glow * 0.8), ring);
	COLOR = vec4(c, 1.0 - smoothstep(0.97, 1.0, r));
}
"""

var unit: BattleUnit
var view: UnitView
var buttons: Array[AttackButton] = []

var _portrait: TextureRect
var _portrait_mat: ShaderMaterial
var _hp_bar: StatBar
var _energy_bar: StatBar
var _name_label: Label
var _status_label: Label

static var _portrait_shader: Shader


func setup(p_unit: BattleUnit, p_view: UnitView, data: Dictionary) -> void:
	unit = p_unit
	view = p_view
	custom_minimum_size = Vector2(450, 0)
	var elem_color := Palette.element_color(unit.element)
	add_theme_stylebox_override("panel", Palette.stylebox(Palette.PANEL, Color(elem_color, 0.45), 18, 2))

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# Portrait rond rendu en direct à partir du modèle 3D.
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.texture = _make_portrait_texture(data)
	if _portrait_shader == null:
		_portrait_shader = Shader.new()
		_portrait_shader.code = PORTRAIT_SHADER
	_portrait_mat = ShaderMaterial.new()
	_portrait_mat.shader = _portrait_shader
	_portrait_mat.set_shader_parameter("ring_color", elem_color)
	_portrait_mat.set_shader_parameter("bg_color", elem_color.darkened(0.3))
	_portrait.material = _portrait_mat
	row.add_child(_portrait)
	# États (étourdi, provocation…) en bas du portrait.
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Palette.GOLD)
	_status_label.add_theme_stylebox_override("normal", Palette.stylebox(Color(0, 0, 0, 0.75), Color.TRANSPARENT, 8))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_label.offset_bottom = 4
	_portrait.add_child(_status_label)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	row.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_name_label = Label.new()
	_name_label.text = unit.display_name
	_name_label.add_theme_font_size_override("font_size", 23)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.clip_text = true
	head.add_child(_name_label)
	var elem := Label.new()
	elem.text = Palette.ELEMENT_NAMES.get(unit.element, "")
	elem.add_theme_font_size_override("font_size", 17)
	elem.add_theme_color_override("font_color", elem_color)
	head.add_child(elem)

	_hp_bar = StatBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 24)
	_hp_bar.font_size = 16
	col.add_child(_hp_bar)
	_energy_bar = StatBar.new()
	_energy_bar.custom_minimum_size = Vector2(0, 10)
	_energy_bar.fill_color = Palette.ENERGY
	col.add_child(_energy_bar)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	col.add_child(btn_row)
	for i in unit.attacks.size():
		var a: Dictionary = unit.attacks[i]
		var b := AttackButton.new()
		b.slot = i
		b.title = a.get("name", "")
		b.description = a.get("description", "")
		b.accent = Palette.ENERGY if i == BattleUnit.SLOT_ULTIMATE else (Palette.COOLDOWN if i == BattleUnit.SLOT_COOLDOWN else Palette.TEXT_DIM)
		b.custom_minimum_size = Vector2(96, 78)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot := i
		b.pressed.connect(func() -> void: attack_pressed.emit(slot))
		btn_row.add_child(b)
		buttons.append(b)



func refresh() -> void:
	var alive := view.shown_hp > 0.0
	_hp_bar.set_values(view.shown_hp / unit.max_hp, unit.shield / unit.max_hp,
		"%d / %d" % [int(ceil(view.shown_hp)), int(unit.max_hp)])
	_energy_bar.set_values(unit.energy / BattleUnit.ENERGY_MAX)
	var ult_ready := unit.attack_ready(BattleUnit.SLOT_ULTIMATE)
	_portrait_mat.set_shader_parameter("grey", 0.0 if alive else 1.0)
	_portrait_mat.set_shader_parameter("glow", (0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)) if ult_ready else 0.0)
	modulate = Color(1, 1, 1) if alive else Color(0.6, 0.6, 0.6)

	var stunned := unit.stun_time > 0.0
	for b in buttons:
		match b.slot:
			BattleUnit.SLOT_BASIC:
				b.set_state(unit.gauge / BattleUnit.GAUGE_MAX, false, "AUTO", not alive or stunned)
			BattleUnit.SLOT_COOLDOWN:
				var cd: float = unit.attacks[b.slot].get("cooldown", 1.0)
				var left := unit.cooldowns[b.slot]
				var corner := "" if left <= 0.0 else "%d s" % int(ceil(left))
				b.set_state(1.0 - left / maxf(cd, 0.01), unit.attack_ready(b.slot), corner, not alive or stunned)
			_:
				var cost := unit.energy_cost(b.slot)
				var corner := "" if unit.energy >= cost else "%d%%" % int(unit.energy / cost * 100.0)
				b.set_state(unit.energy / maxf(cost, 1.0), unit.attack_ready(b.slot), corner, not alive or stunned)

	var tags: Array[String] = []
	if stunned:
		tags.append("ÉTOURDI")
	if unit.taunt_time > 0.0:
		tags.append("PROVOC.")
	if not unit.dots.is_empty():
		tags.append("BRÛLURE")
	_status_label.text = " ".join(tags)
	_status_label.visible = alive and not tags.is_empty()


## Rendu du héros (tête et buste) dans une petite fenêtre 3D séparée.
func _make_portrait_texture(data: Dictionary) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(192, 192)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var scene: PackedScene = load(data.get("model", ""))
	if scene:
		var model := scene.instantiate()
		vp.add_child(model)
		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("Idle"):
			ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			ap.play("Idle")
	var cam := Camera3D.new()
	cam.position = Vector3(0.35, 1.75, 2.0)
	cam.fov = 34
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 1.45, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 1.4
	vp.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.8)
	e.ambient_light_energy = 0.8
	env.environment = e
	vp.add_child(env)
	return vp.get_texture()
