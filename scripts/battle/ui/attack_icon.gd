class_name AttackIcon
extends Control
## Case carrée d'une compétence (pièces pixel de assets/ui/combat) : cadre normal / survol / appuyé /
## indisponible, icône de la compétence à l'intérieur, voile de recharge qui se vide, et pour
## l'ultime une jauge d'énergie dessous qui brille quand elle est pleine. La technique secrète
## (slot 3) a une case plus petite.

signal pressed

const ICON_DIR := "res://assets/ui/attacks/"
const INSET := 16.0

var slot := 0
var attack: Dictionary = {}
var accent := Palette.GOLD
var available := false
var progress := 1.0  # 0..1 (recharge ou énergie)
var corner_text := ""

var _icon: Texture2D
var _hover := false
var _down := false
var _time := 0.0


func setup(p_slot: int, p_attack: Dictionary, p_accent: Color) -> void:
	slot = p_slot
	attack = p_attack
	accent = p_accent
	var side := 96.0 if slot == BattleUnit.SLOT_SECRET else 128.0
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	var path: String = ICON_DIR + String(attack.get("id", "")) + ".png"
	_icon = load(path) if ResourceLoader.exists(path) else null
	tooltip_text = "%s\n%s" % [attack.get("name", ""), attack.get("description", "")]
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(128, 128)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_down = false
		queue_redraw())


func _process(delta: float) -> void:
	_time += delta
	if slot == BattleUnit.SLOT_ULTIMATE and available:
		queue_redraw()  # lueur de l'ultime prêt


func set_state(p_available: bool, p_progress: float, p_corner: String) -> void:
	available = p_available
	progress = clampf(p_progress, 0.0, 1.0)
	corner_text = p_corner
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not available:
		return
	_down = mb.pressed
	queue_redraw()
	if not mb.pressed:
		accept_event()
		pressed.emit()


func press_feedback() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 0.9, 0.05)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)


func _draw() -> void:
	var secret := slot == BattleUnit.SLOT_SECRET
	var base := "secret_frame" if secret else "skill_frame"
	var state := "disabled" if not available else ("pressed" if _down else ("hover" if _hover else "normal"))
	var full := Rect2(Vector2.ZERO, size)
	var inner := full.grow(-INSET)
	var frame := OverheadBar.tex("%s_%s" % [base, state])
	if frame:
		draw_texture_rect(frame, full, false)
	if _icon:  # par-dessus le fond de la case
		draw_texture_rect(_icon, inner, false, Color.WHITE if available else Color(0.55, 0.55, 0.6))
	if not available:
		# Recharge : voile qui se vide (17 images) ; sinon simple voile gris.
		if slot == BattleUnit.SLOT_COOLDOWN or secret:
			var f := clampi(roundi(progress * 16.0), 0, 16)
			var veil := OverheadBar.tex("anim/cooldown_veil/%02d" % f)
			if veil:
				draw_texture_rect(veil, inner, false)
		else:
			var grey := OverheadBar.tex("skill_disabled_veil")
			if grey:
				draw_texture_rect(grey, inner, false)
	elif state == "hover":
		var over := OverheadBar.tex("skill_hover_overlay")
		if over:
			draw_texture_rect(over, full, false)
	elif state == "pressed":
		var pv := OverheadBar.tex("skill_pressed_veil")
		if pv:
			draw_texture_rect(pv, inner, false)
	if slot == BattleUnit.SLOT_ULTIMATE:
		var bar := Rect2(Vector2(0, size.y + 6), Vector2(size.x, 10))
		var ef := OverheadBar.tex("ultimate_energy_frame")
		if ef:
			draw_texture_rect(ef, bar, false)
		var fill := OverheadBar.tex("ultimate_energy_fill")
		if fill and progress > 0.0:
			var r := bar.grow(-2.0)
			draw_texture_rect_region(fill, Rect2(r.position, Vector2(r.size.x * progress, r.size.y)),
				Rect2(Vector2.ZERO, Vector2(fill.get_width() * progress, fill.get_height())))
		if available:
			var glow := OverheadBar.tex("anim/ultimate_ready/%02d" % (int(_time / 0.09) % 8))
			if glow:
				draw_texture_rect(glow, full, false)
	if corner_text != "":
		var font := get_theme_default_font()
		var fs := 28 if not secret else 22
		var ts := font.get_string_size(corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2((size.x - ts.x) / 2.0, size.y / 2.0 + fs * 0.35)
		draw_string_outline(font, pos, corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0, 0, 0, 0.95))
		draw_string(font, pos, corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT)
