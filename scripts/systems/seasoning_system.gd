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
	var data = JSON.parse_string(json_text)
	if data == null or not data is Dictionary:
		push_error("[Seasoning] JSON 解析失败或格式错误")
		return
	seasonings = data
	print("[Seasoning] 加载 ", seasonings.size(), " 种香料")

func get_seasoning(key: String) -> Dictionary:
	return seasonings.get(key, {})

func is_seasoning(key: String) -> bool:
	return seasonings.has(key)
