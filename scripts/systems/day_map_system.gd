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
var _anchors: Array = []
var _anchor_by_id: Dictionary = {}
var _announced_postings: Dictionary = {}


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
	_anchors.clear()
	_anchor_by_id.clear()
	_locations.clear()
	var region_origin := {}
	for r in _regions:
		region_origin[String(r.get("id", ""))] = r.get("origin", [0, 0])
	for anchor in parsed.get("anchors", []):
		var resolved_anchor: Dictionary = (anchor as Dictionary).duplicate(true)
		var rid := String(resolved_anchor.get("region", ""))
		if region_origin.has(rid):
			var o = region_origin[rid]
			var p = resolved_anchor.get("pos", [0, 0])
			resolved_anchor["pos"] = [float(o[0]) + float(p[0]), float(o[1]) + float(p[1])]
		_anchors.append(resolved_anchor)
		_anchor_by_id[String(resolved_anchor.get("id", ""))] = resolved_anchor
	for location in parsed.get("locations", []):
		var anchor_id := String(location.get("anchor", ""))
		if anchor_id != "" and _anchor_by_id.has(anchor_id):
			var anchor: Dictionary = _anchor_by_id[anchor_id]
			location["region"] = String(anchor.get("region", location.get("region", "")))
			location["pos"] = (anchor.get("pos", [0, 0]) as Array).duplicate()
			location["anchor_kind"] = String(anchor.get("kind", ""))
			location["anchor_tags"] = (anchor.get("tags", []) as Array).duplicate()
		var rid := String(location.get("region", ""))
		if anchor_id == "" and region_origin.has(rid):
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
		if _passes_filters(location):
			result.append(_effective(location))
	return result


func _passes_filters(location: Dictionary) -> bool:
	if current_day < int(location.get("dayMin", 1)):
		return false
	var required_flag := String(location.get("requiresFlag", ""))
	if required_flag != "" and not _flag_satisfied(required_flag):
		return false
	var required_read := String(location.get("requiresRead", ""))
	if required_read != "" and not is_document_known(required_read):
		return false
	return true


## 当前激活贴文 = 满足 dayMin+requiresFlag、数组里最靠后的那条（后者为更新的贴文，优先）。无则空。
func _active_posting(location: Dictionary) -> Dictionary:
	var best := {}
	for p in location.get("postings", []):
		if current_day < int(p.get("dayMin", 1)):
			continue
		var day_max := int(p.get("dayMax", 0))
		if day_max > 0 and current_day > day_max:
			continue
		var rf := String(p.get("requiresFlag", ""))
		if rf != "" and not _flag_satisfied(rf):
			continue
		best = p
	return best


func _active_posting_id(location: Dictionary) -> String:
	return String(_active_posting(location).get("id", ""))


## 把当前激活贴文的描述/产出并入返回副本（地点持久、内容随贴文演变）。无 postings 原样返回。
func _effective(location: Dictionary) -> Dictionary:
	if not location.has("postings"):
		return location
	var loc := location.duplicate(true)
	var ap := _active_posting(location)
	if ap.is_empty():
		loc["documents"] = []
		loc["active_posting"] = ""
	else:
		loc["description"] = ap.get("description", loc.get("description", ""))
		loc["result"] = ap.get("result", loc.get("result", ""))
		loc["documents"] = (ap.get("documents", []) as Array).duplicate()
		loc["active_posting"] = String(ap.get("id", ""))
	return loc


func is_revealed(location_id: String) -> bool:
	return bool(_revealed.get(location_id, false))


func mark_revealed(location_id: String) -> void:
	_revealed[location_id] = true
	if _locations.has(location_id):
		_announced_postings[location_id] = _active_posting_id(_locations[location_id])


func get_new_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for location in get_locations():
		if not is_revealed(String(location.get("id", ""))):
			result.append(location)
	return result


## 已亮相、但当前激活贴文与"已宣告贴文"不同的地点 → 需要重新拉镜头高亮 + 刷新描述。
func get_updated_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for location in _locations.values():
		if not location.has("postings"):
			continue
		var id := String(location.get("id", ""))
		if not is_revealed(id) or not _passes_filters(location):
			continue
		if String(_announced_postings.get(id, "__none__")) != _active_posting_id(location):
			result.append(_effective(location))
	return result


func mark_posting_announced(location_id: String) -> void:
	if _locations.has(location_id):
		_announced_postings[location_id] = _active_posting_id(_locations[location_id])


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
	var previous_visits := int(_visited.get(location_id, 0))
	_visited[location_id] = previous_visits + 1
	# 有 postings 时，产出取当前激活贴文（无激活贴文=闲置，不产出）。
	var unlocked_flag := String(location.get("unlocksFlag", ""))
	var documents: Array = location.get("documents", []).duplicate()
	var active_posting := ""
	var message := String(location.get("result", "访问完成。"))
	if location.has("postings"):
		var ap := _active_posting(location)
		if ap.is_empty():
			unlocked_flag = ""
			documents = []
		else:
			active_posting = String(ap.get("id", ""))
			unlocked_flag = String(ap.get("unlocksFlag", ""))
			documents = (ap.get("documents", []) as Array).duplicate()
			message = String(ap.get("result", location.get("result", "访问完成。")))
	if unlocked_flag != "":
		_flags[unlocked_flag] = true
	var rewards: Array = location.get("rewards", []).duplicate()
	var day_rewards: Dictionary = location.get("dayRewards", {})
	if day_rewards.has(str(current_day)):
		rewards = day_rewards[str(current_day)].duplicate()
	var affection = location.get("affection", null)
	if bool(location.get("affectionOncePerDay", false)) and previous_visits > 0:
		affection = null
	return {
		"success": true,
		"location_id": location_id,
		"message": message,
		"rewards": rewards,
		"documents": documents,
		"unlockedFlag": unlocked_flag,
		"activePosting": active_posting,
		"stamina": stamina,
		"affection": affection,
		"goldCost": int(location.get("goldCost", 0)),
		"securesToby": bool(location.get("securesToby", false)),
	}


func _failure(message: String) -> Dictionary:
	return {"success": false, "message": message, "stamina": stamina}


func get_regions() -> Array:
	return _regions


func get_anchors() -> Array:
	return _anchors.duplicate(true)


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
