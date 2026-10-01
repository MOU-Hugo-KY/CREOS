class_name Wanderer
extends Node3D
## Un héros qui se promène sur la place du hub : il marche vers un point au hasard, s'arrête,
## et de temps en temps montre une de ses attaques. Purement décoratif.

const SPEED := 1.6
const PLAZA_CENTER := Vector3(0, 0, -3)
const FOUNTAIN_RADIUS := 4.2

var _model: Node3D
var _anim: AnimationPlayer
var _anims: Dictionary = {}
var _attacks: Array = []
var _target := Vector3.ZERO
var _wait := 0.0
var _rng := RandomNumberGenerator.new()


func setup(data: Dictionary, seed_value: int) -> void:
	_rng.seed = seed_value
	_anims = {"idle": "Idle", "run": "Walk"}
	_anims.merge(data.get("anims", {}), true)
	for a: Dictionary in data.get("attacks", []):
		_attacks.append(a.get("anim", ""))
	var scene: PackedScene = load(data.get("model", ""))
	if scene:
		_model = scene.instantiate()
		# Les modèles regardent vers +Z ; look_at() oriente -Z vers la cible : on retourne le modèle.
		_model.rotation_degrees.y = 180.0
		add_child(_model)
		_anim = _model.find_child("AnimationPlayer", true, false)
		for n in [_anims.idle, _anims.run]:
			if _anim and _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	position = _random_point()
	_wait = _rng.randf_range(0.0, 2.0)
	_play(_anims.idle)


func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_target = _random_point()
			_play(_anims.run)
		return
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.15:
		_arrive()
		return
	var step := to.normalized() * minf(SPEED * delta, to.length())
	var next := position + step
	# Contourne la fontaine.
	var from_center := next - PLAZA_CENTER
	from_center.y = 0.0
	if from_center.length() < FOUNTAIN_RADIUS:
		next = PLAZA_CENTER + from_center.normalized() * FOUNTAIN_RADIUS
	look_at(Vector3(next.x, position.y, next.z) + step * 10.0, Vector3.UP)
	position = next


func _arrive() -> void:
	_wait = _rng.randf_range(1.5, 4.5)
	# Une fois sur quatre, il fait une démonstration d'attaque.
	if not _attacks.is_empty() and _rng.randf() < 0.25:
		_play(_attacks[_rng.randi() % _attacks.size()])
		if _anim:
			_anim.queue(_anims.idle)
	else:
		_play(_anims.idle)
	# Se tourne un peu vers la caméra pour qu'on le voie bien.
	look_at(position + Vector3(_rng.randf_range(-0.5, 0.5), 0, 1), Vector3.UP)


func _random_point() -> Vector3:
	for i in 20:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(FOUNTAIN_RADIUS + 0.5, 8.5)
		var p := PLAZA_CENTER + Vector3(cos(a) * r * 1.2, 0, sin(a) * r * 0.65)
		if p.z < 4.5 and p.z > -9.0 and absf(p.x) < 10.5:
			return p
	return PLAZA_CENTER + Vector3(0, 0, 5.5)


func _play(n: String) -> void:
	if _anim and _anim.has_animation(n):
		_anim.play(n, 0.2)
