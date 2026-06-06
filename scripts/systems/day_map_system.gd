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
var _owned_documents: Dictionary = {}
var _lead_flags: Dictionary = {}
var _revealed: Dictionary = {}
var _regions: Array = []


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
	_regions = parsed.get("regions", [])
	_locations.clear()
	var region_origin := {}
	for r in _regions:
		region_origin[String(r.get("id", ""))] = r.get("origin", [0, 0])
	for location in parsed.get("locations", []):
		var rid := String(location.get("region", ""))
		if region_origin.has(rid):
			var o = region_origin[rid]
			var p = location.get("pos", [0, 0])
			location["pos"] = [float(o[0]) + float(p[0]), float(o[1]) + float(p[1])]
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


func set_document_owned(document_id: String, owned: bool) -> void:
	_owned_documents[document_id] = owned


func is_document_known(document_id: String) -> bool:
	return bool(_read_documents.get(document_id, false)) or bool(_owned_documents.get(document_id, false))


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
		if required_read != "" and not is_document_known(required_read):
			continue
		result.append(location)
	return result


func is_revealed(location_id: String) -> bool:
	return bool(_revealed.get(location_id, false))


func mark_revealed(location_id: String) -> void:
	_revealed[location_id] = true


func get_new_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for location in get_locations():
		if not is_revealed(String(location.get("id", ""))):
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
	if required_read != "" and not is_document_known(required_read):
		return _failure("先看看手里的线索。")
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
		"affection": location.get("affection", null),
		"goldCost": int(location.get("goldCost", 0)),
		"securesToby": bool(location.get("securesToby", false)),
	}


func _failure(message: String) -> Dictionary:
	return {"success": false, "message": message, "stamina": stamina}


func get_regions() -> Array:
	return _regions


## 相机边界 = 所有区域矩形的并集；无区域时回退到单屏 1280×720。
func get_map_bounds() -> Dictionary:
	if _regions.is_empty():
		return {"min": Vector2(0, 0), "max": Vector2(1280, 720)}
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for r in _regions:
		var o = r.get("origin", [0, 0])
		var s = r.get("size", [1280, 720])
		mn.x = minf(mn.x, float(o[0]))
		mn.y = minf(mn.y, float(o[1]))
		mx.x = maxf(mx.x, float(o[0]) + float(s[0]))
		mx.y = maxf(mx.y, float(o[1]) + float(s[1]))
	return {"min": mn, "max": mx}
