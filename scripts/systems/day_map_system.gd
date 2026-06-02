class_name DayMapSystem
extends RefCounted

const DEFAULT_PATH := "res://data/locations.json"

var stamina: int = 0
var max_stamina: int = 0
var current_day: int = 1

var _default_stamina: int = 5
var _stamina_by_day: Dictionary = {}
var _locations: Dictionary = {}
var _visited: Dictionary = {}
var _flags: Dictionary = {}
var _read_documents: Dictionary = {}
var _lead_flags: Dictionary = {}


func load_data(path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DayMapSystem] 无法加载地点数据: " + path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("[DayMapSystem] 地点数据格式无效: " + path)
		return false
	_default_stamina = int(parsed.get("maxStamina", 5))
	_stamina_by_day = parsed.get("maxStaminaByDay", {})
	_locations.clear()
	for location in parsed.get("locations", []):
		_locations[String(location["id"])] = location
	return true


func start_day(day: int) -> void:
	current_day = day
	max_stamina = int(_stamina_by_day.get(str(day), _default_stamina))
	stamina = max_stamina
	_visited.clear()
	_flags.clear()


func set_document_read(document_id: String, read: bool) -> void:
	_read_documents[document_id] = read


func set_lead_flag(flag_id: String, active: bool) -> void:
	_lead_flags[flag_id] = active


func _flag_satisfied(flag_id: String) -> bool:
	return bool(_flags.get(flag_id, false)) or bool(_lead_flags.get(flag_id, false))


func get_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for location in _locations.values():
		if current_day < int(location.get("dayMin", 1)):
			continue
		var required_flag := String(location.get("requiresFlag", ""))
		if required_flag != "" and not _flag_satisfied(required_flag):
			continue
		var required_read := String(location.get("requiresRead", ""))
		if required_read != "" and not bool(_read_documents.get(required_read, false)):
			continue
		result.append(location)
	return result


func visit(location_id: String) -> Dictionary:
	if not _locations.has(location_id):
		return _failure("未知地点。")
	var location: Dictionary = _locations[location_id]
	if current_day < int(location.get("dayMin", 1)):
		return _failure("这个地点尚未开放。")
	var required_flag := String(location.get("requiresFlag", ""))
	if required_flag != "" and not _flag_satisfied(required_flag):
		return _failure("还没有找到前往这里的线索。")
	var required_read := String(location.get("requiresRead", ""))
	if required_read != "" and not bool(_read_documents.get(required_read, false)):
		return _failure("先读一读手里的证据。")
	if not bool(location.get("repeatable", false)) and _visited.has(location_id):
		return _failure("这里今天已经调查过了。")
	var cost := int(location.get("cost", 1))
	if stamina < cost:
		return _failure("行动力不足。")

	stamina -= cost
	_visited[location_id] = int(_visited.get(location_id, 0)) + 1
	var unlocked_flag := String(location.get("unlocksFlag", ""))
	if unlocked_flag != "":
		_flags[unlocked_flag] = true
	var rewards: Array = location.get("rewards", []).duplicate()
	var day_rewards: Dictionary = location.get("dayRewards", {})
	if day_rewards.has(str(current_day)):
		rewards = day_rewards[str(current_day)].duplicate()
	return {
		"success": true,
		"location_id": location_id,
		"message": String(location.get("result", "访问完成。")),
		"rewards": rewards,
		"documents": location.get("documents", []).duplicate(),
		"stamina": stamina,
	}


func _failure(message: String) -> Dictionary:
	return {"success": false, "message": message, "stamina": stamina}
