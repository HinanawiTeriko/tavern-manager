class_name IntroSequence
extends CanvasLayer

const INTRO_DATA := "res://data/intro.json"
const DAYMAP_SCENE := "res://scenes/ui/DayMap.tscn"
const INTRO_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const VIGNETTE_TEXTURE := "res://assets/textures/intro/intro_vignette.png"
const FADE_OUT := 0.6
const SCREEN_CENTER := Vector2(640, 360)
const OVERSCAN := 1.12               # 基数：保证有图铺满、运镜不露黑边
const LETTERBOX_HEIGHT := 80.0       # ≈ 720 * 0.11
const LETTERBOX_SLIDE := 0.6
const NARRATION_FONT_SIZE := 22
const NARRATION_COLOR := Color(0.86, 0.76, 0.64, 1.0)
const NARRATION_OUTLINE_COLOR := Color(0.02, 0.012, 0.008, 0.72)
const NARRATION_OUTLINE_SIZE := 3


static func load_intro(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"bgm": "", "beats": []}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"bgm": "", "beats": []}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"bgm": "", "beats": []}
	var beats = parsed.get("beats", [])
	if typeof(beats) != TYPE_ARRAY:
		beats = []
	return {"bgm": String(parsed.get("bgm", "")), "beats": beats}


@onready var _still: Sprite2D = $Still
@onready var _vignette: TextureRect = $Vignette
@onready var _letter_top: ColorRect = $LetterTop
@onready var _letter_bottom: ColorRect = $LetterBottom
@onready var _narration: Label = $NarrationLabel
@onready var _skip_hint: Label = $SkipHint

var _beats: Array = []
var _timeline: Tween = null
var _exited: bool = false
var _texture_cache: Dictionary = {}


func _ready() -> void:
	_style_narration()
	_setup_vignette()
	_setup_letterbox()
	var data := load_intro(INTRO_DATA)
	_beats = data.get("beats", [])
	_preload_textures()
	_play()


func _style_narration() -> void:
	_narration.add_theme_font_override("font", INTRO_FONT)
	_narration.add_theme_font_size_override("font_size", NARRATION_FONT_SIZE)
	_narration.add_theme_color_override("font_color", NARRATION_COLOR)
	_narration.add_theme_constant_override("outline_size", NARRATION_OUTLINE_SIZE)
	_narration.add_theme_color_override("font_outline_color", NARRATION_OUTLINE_COLOR)
	_skip_hint.add_theme_font_override("font", INTRO_FONT)
	_skip_hint.add_theme_color_override("font_color", Color(ThemeColors.TEXT_LIGHT, 0.42))
	_skip_hint.add_theme_font_size_override("font_size", 14)
	_narration.modulate.a = 0.0


func _setup_vignette() -> void:
	if ResourceLoader.exists(VIGNETTE_TEXTURE):
		_vignette.texture = load(VIGNETTE_TEXTURE)
		_vignette.visible = true
	else:
		_vignette.visible = false


func _setup_letterbox() -> void:
	var bottom_y := 720.0 - LETTERBOX_HEIGHT
	_letter_top.position.y = -LETTERBOX_HEIGHT
	_letter_bottom.position.y = 720.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_letter_top, "position:y", 0.0, LETTERBOX_SLIDE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_letter_bottom, "position:y", bottom_y, LETTERBOX_SLIDE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _preload_textures() -> void:
	for beat in _beats:
		var path := String((beat as Dictionary).get("image", ""))
		if path != "" and ResourceLoader.exists(path):
			_texture_cache[path] = load(path)


func _play() -> void:
	if _beats.is_empty():
		_exit_to_daymap()
		return
	_timeline = create_tween()
	for beat in _beats:
		var beat_data: Dictionary = beat
		var fade_in := float(beat_data.get("fade_in", 1.0))
		var hold := float(beat_data.get("hold", 2.0))
		var fade_out := float(beat_data.get("fade_out", FADE_OUT))
		var path := String(beat_data.get("image", ""))
		var has_image := _texture_cache.has(path)
		var kb: Dictionary = beat_data.get("kenburns", {})

		_timeline.tween_callback(func(): _apply_still(path, kb))
		_timeline.tween_callback(func(): _narration.text = String(beat_data.get("text", "")))
		_timeline.tween_property(_narration, "modulate:a", 1.0, fade_in)
		if has_image:
			var dur := fade_in + hold
			_timeline.parallel().tween_property(_still, "modulate:a", 1.0, fade_in)
			_timeline.parallel().tween_property(_still, "scale", _kb_scale(kb, "to"), dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_timeline.parallel().tween_property(_still, "position", _kb_position(kb, "to"), dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			_timeline.tween_interval(hold)
		# 旁白与画面用同一 fade_out 一起穿黑（保持淡出同步）
		_timeline.tween_property(_narration, "modulate:a", 0.0, fade_out)
		if has_image:
			_timeline.parallel().tween_property(_still, "modulate:a", 0.0, fade_out)
	_timeline.tween_callback(_exit_to_daymap)


func _apply_still(path: String, kb: Dictionary) -> void:
	if _texture_cache.has(path):
		_still.texture = _texture_cache[path]
		_still.visible = true
		_still.modulate.a = 0.0
		_still.scale = _kb_scale(kb, "from")
		_still.position = _kb_position(kb, "from")
	else:
		_still.texture = null
		_still.visible = false


func _exit_to_daymap() -> void:
	if _exited:
		return
	_exited = true
	if _timeline != null and _timeline.is_valid():
		_timeline.kill()
	get_tree().change_scene_to_file(DAYMAP_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _exited:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventKey:
		pressed = event.pressed
	if pressed:
		# 先吃掉事件（此时 viewport 仍有效），再切场景——切场景会拆掉本节点，
		# 之后 get_viewport() 会返回 null。
		get_viewport().set_input_as_handled()
		_exit_to_daymap()


func _kb_zoom(kb: Dictionary, key: String) -> float:
	var seg: Dictionary = kb.get(key, {})
	return float(seg.get("zoom", 1.0))


func _kb_offset(kb: Dictionary, key: String) -> Vector2:
	var seg: Dictionary = kb.get(key, {})
	var off: Array = seg.get("offset", [0, 0])
	return Vector2(float(off[0]), float(off[1]))


func _kb_scale(kb: Dictionary, key: String) -> Vector2:
	var z := OVERSCAN * _kb_zoom(kb, key)
	return Vector2(z, z)


func _kb_position(kb: Dictionary, key: String) -> Vector2:
	return SCREEN_CENTER + _kb_offset(kb, key)
