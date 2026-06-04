class_name IntroSequence
extends CanvasLayer

const INTRO_DATA := "res://data/intro.json"
const DAYMAP_SCENE := "res://scenes/ui/DayMap.tscn"


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
