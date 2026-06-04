class_name IntroSequence
extends CanvasLayer

const INTRO_DATA := "res://data/intro.json"
const DAYMAP_SCENE := "res://scenes/ui/DayMap.tscn"
const FADE_OUT := 0.6  # 每拍旁白淡出时长（淡入/停留由 beat 数据驱动）
const SCREEN_CENTER := Vector2(640, 360)  # 1280×720 基准屏幕中心，背景 Sprite 锚点


## 解析开场数据为 {bgm, beats[]}。缺失/损坏文件优雅降级为空。静态以便单测。
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


@onready var _background: Sprite2D = $Background
@onready var _narration: Label = $NarrationLabel
@onready var _skip_hint: Label = $SkipHint

var _beats: Array = []
var _timeline: Tween = null
var _exited: bool = false
var _bg_cache: Dictionary = {}  # bg_path -> Texture，开场前预载，避免播放中同步 load 卡顿


func _ready() -> void:
	# 文案样式（沿用项目主题色）
	ThemeColors.style_header(_narration, 26)
	_narration.add_theme_constant_override("outline_size", 4)
	_narration.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_skip_hint.add_theme_color_override("font_color", Color(ThemeColors.TEXT_LIGHT, 0.5))
	_skip_hint.add_theme_font_size_override("font_size", 14)
	_narration.modulate.a = 0.0

	var data := load_intro(INTRO_DATA)
	_beats = data.get("beats", [])
	_preload_backgrounds()
	_play()


func _play() -> void:
	if _beats.is_empty():
		_exit_to_daymap()
		return
	_timeline = create_tween()
	for beat in _beats:
		var fade_in := float(beat.get("fade_in", 1.0))
		var hold := float(beat.get("hold", 2.0))
		var bg_path := String(beat.get("bg", ""))
		var cam = beat.get("camera", null)
		# 镜头只在背景图成功载入时生效：camera 段依附于真实背景，bg 为空时被忽略
		var has_cam: bool = _bg_cache.has(bg_path) and cam != null
		# 换拍起点：设背景纹理 + 镜头起点(from)，再设旁白文字
		_timeline.tween_callback(func(): _apply_background(bg_path, cam))
		_timeline.tween_callback(func(): _narration.text = String(beat.get("text", "")))
		# 旁白淡入（作为并行锚点）
		_timeline.tween_property(_narration, "modulate:a", 1.0, fade_in)
		if has_cam:
			# L1 镜头：与旁白可见窗口并行推拉。并行组时长 = fade_in+hold，
			# 既完成镜头、又承担 hold，故此分支不再单独 tween_interval。
			var dur := fade_in + hold
			var to_dict: Dictionary = cam.get("to", {})
			var to_zoom := float(to_dict.get("zoom", 1.0))
			var to_off: Array = to_dict.get("offset", [0, 0])
			_timeline.parallel().tween_property(_background, "scale", Vector2(to_zoom, to_zoom),
				dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_timeline.parallel().tween_property(_background, "position",
				SCREEN_CENTER + Vector2(float(to_off[0]), float(to_off[1])),
				dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			_timeline.tween_interval(hold)
		# 旁白淡出
		_timeline.tween_property(_narration, "modulate:a", 0.0, FADE_OUT)
	_timeline.tween_callback(_exit_to_daymap)


func _exit_to_daymap() -> void:
	# 单一出口：跳过与播完都走这里，保证 handoff 一致（标志已在 new_game 置位）
	if _exited:
		return
	_exited = true
	if _timeline != null and _timeline.is_valid():
		_timeline.kill()
	get_tree().change_scene_to_file(DAYMAP_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventKey:
		pressed = event.pressed
	if pressed:
		_exit_to_daymap()
		get_viewport().set_input_as_handled()


func _preload_backgrounds() -> void:
	for beat in _beats:
		var bg_path := String(beat.get("bg", ""))
		if bg_path != "" and ResourceLoader.exists(bg_path):
			_bg_cache[bg_path] = load(bg_path)


func _apply_background(bg_path: String, cam) -> void:
	if _bg_cache.has(bg_path):
		_background.texture = _bg_cache[bg_path]
		_background.visible = true
		# 镜头起点(from)
		var from_dict: Dictionary = (cam.get("from", {}) if cam != null else {})
		var from_zoom := float(from_dict.get("zoom", 1.0))
		var from_off: Array = from_dict.get("offset", [0, 0])
		_background.scale = Vector2(from_zoom, from_zoom)
		_background.position = SCREEN_CENTER + Vector2(float(from_off[0]), float(from_off[1]))
	else:
		_background.visible = false
