class_name SeasoningData
extends RefCounted

var name: String = ""
var tag: String = ""
var color: Array = []


class_name SeasoningSystem
extends RefCounted

var seasonings: Dictionary = {}

func load_data() -> void:
	var file = FileAccess.open("res://data/seasonings.json", FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return
	seasonings = json.data
	GD.print("[Seasoning] 加载 ", seasonings.size(), " 种香料")

func get_seasoning(key: String) -> Dictionary:
	return seasonings.get(key, {})

func is_seasoning(key: String) -> bool:
	return seasonings.has(key)
