class_name IntroSequence
extends CanvasLayer

const INTRO_DATA := "res://data/intro.json"
const DAYMAP_SCENE := "res://scenes/ui/DayMap.tscn"
const FADE_OUT := 0.6  # 每拍旁白淡出时长（淡入/停留由 beat 数据驱动）


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
@onready var _gradient: ColorRect = $GradientOverlay
@onready var _narration: Label = $NarrationLabel
@onready var _skip_hint: Label = $SkipHint

var _beats: Array = []
var _timeline: Tween = null
var _exited: bool = false


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
	_play()


func _play() -> void:
	if _beats.is_empty():
		_exit_to_daymap()
		return
	_timeline = create_tween()
	for beat in _beats:
		var fade_in := float(beat.get("fade_in", 1.0))
		var hold := float(beat.get("hold", 2.0))
		# 换拍：先设文字，再淡入，停留，淡出
		_timeline.tween_callback(func(): _narration.text = String(beat.get("text", "")))
		_timeline.tween_property(_narration, "modulate:a", 1.0, fade_in)
		_timeline.tween_interval(hold)
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
