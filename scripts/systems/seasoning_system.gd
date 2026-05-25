class_name SeasoningSystem
extends RefCounted

var seasonings: Dictionary = {}

func load_data() -> void:
	var file = FileAccess.open("res://data/seasonings.json", FileAccess.READ)
	if file == null:
		print("[Seasoning] seasonings.json 未找到")
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("[Seasoning] JSON 解析失败: ", error)
		return
	seasonings = json.data
	print("[Seasoning] 加载 ", seasonings.size(), " 种香料")

func get_seasoning(key: String) -> Dictionary:
	return seasonings.get(key, {})

func is_seasoning(key: String) -> bool:
	return seasonings.has(key)
