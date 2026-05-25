class_name TitleAmbience
extends Node2D

@export var star_region: Rect2 = Rect2(20, 20, 380, 200)
@export var star_count: int = 10
@export var star_color: Color = Color.WHITE
@export var star_base_size: float = 3.0

@export var dust_region: Rect2 = Rect2(380, 280, 560, 280)
@export var dust_count: int = 30
@export var dust_color: Color = Color(1.0, 0.82, 0.55)
@export var dust_base_size: float = 2.0

var _stars: Array = []
var _motes: Array = []
var _rng = RandomNumberGenerator.new()
var _time: float = 0.0

func _ready() -> void:
	z_index = -50
	_rng.randomize()

	for _i in range(star_count):
		_stars.append({
			"pos": Vector2(
				star_region.position.x + _rng.randf() * star_region.size.x,
				star_region.position.y + _rng.randf() * star_region.size.y
			),
			"phase": _rng.randf() * PI * 2.0,
			"speed": 0.8 + _rng.randf() * 2.5,
			"size_mul": 0.6 + _rng.randf() * 0.9
		})

	for _i in range(dust_count):
		_motes.append(_spawn_mote(true))

func _spawn_mote(initial: bool) -> Dictionary:
	var m = {
		"pos": Vector2(
			dust_region.position.x + _rng.randf() * dust_region.size.x,
			dust_region.position.y + _rng.randf() * dust_region.size.y
		),
		"vel": Vector2(
			-8.0 + _rng.randf() * 16.0,
			-10.0 - _rng.randf() * 15.0
		),
		"max_life": 3.0 + _rng.randf() * 6.0,
		"size": 1.0 + _rng.randf() * 2.5,
		"alpha": 0.3 + _rng.randf() * 0.7
	}
	if initial:
		m["life"] = _rng.randf() * m["max_life"]
	else:
		m["life"] = m["max_life"]
	return m

func _process(delta: float) -> void:
	_time += delta

	for i in range(_stars.size()):
		_stars[i]["phase"] += _stars[i]["speed"] * delta
		if _stars[i]["phase"] > PI * 2.0:
			_stars[i]["phase"] -= PI * 2.0

	for i in range(_motes.size()):
		_motes[i]["life"] -= delta
		_motes[i]["pos"] += _motes[i]["vel"] * delta
		_motes[i]["vel"].x += (-4.0 + _rng.randf() * 8.0) * delta
		if _motes[i]["life"] <= 0.0 or not dust_region.has_point(_motes[i]["pos"]):
			_motes[i] = _spawn_mote(false)

	queue_redraw()

func _draw() -> void:
	for star in _stars:
		var raw = (sin(star["phase"]) + 1.0) / 2.0
		var brightness: float
		if raw < 0.15: brightness = 0.0
		elif raw < 0.4: brightness = 0.25
		elif raw < 0.75: brightness = 0.6
		else: brightness = 1.0
		if brightness < 0.01:
			continue
		var size = star_base_size * star["size_mul"]
		var c = Color(star_color, brightness)
		if brightness >= 0.6:
			draw_rect(Rect2(star["pos"].x - size * 0.5, star["pos"].y - size * 1.5, size, size * 3.0), c)
			draw_rect(Rect2(star["pos"].x - size * 1.5, star["pos"].y - size * 0.5, size * 3.0, size), c)
		else:
			draw_rect(Rect2(star["pos"].x - size * 0.5, star["pos"].y - size * 0.5, size, size), c)

	for mote in _motes:
		var life_ratio = mote["life"] / mote["max_life"]
		var alpha = mote["alpha"] * min(life_ratio * 1.5, 1.0)
		var c = Color(dust_color, alpha)
		var size = mote["size"]
		draw_rect(Rect2(mote["pos"].x - size * 0.5, mote["pos"].y - size * 0.5, size, size), c)
