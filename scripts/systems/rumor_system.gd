class_name RumorSystem
extends RefCounted

const DEFAULT_PATH := "res://data/rumors.json"

var current_day: int = 0
var _rumors: Array[Dictionary] = []
var _heard_ids: Dictionary = {}
var _today_ids: Array[String] = []


func load_data(path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[RumorSystem] cannot load data: " + path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("[RumorSystem] invalid data: " + path)
		return false
	_rumors.clear()
	for raw in parsed.get("rumors", []):
		if raw is Dictionary:
			_rumors.append((raw as Dictionary).duplicate(true))
	return true


func start_day(day: int) -> void:
	if current_day == day:
		return
	current_day = day
	_today_ids.clear()


func grant_location_rumor(location_id: String, day: int, flags: Dictionary = {}) -> Dictionary:
	start_day(day)
	for rumor in _rumors:
		if not _rumor_available_for_location(rumor, location_id, day, flags):
			continue
		var id := String(rumor.get("id", ""))
		_heard_ids[id] = true
		if not _today_ids.has(id):
			_today_ids.append(id)
		return _public_payload(rumor, true)
	return {"success": false}


func get_today_rumors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _today_ids:
		var rumor := _rumor_by_id(id)
		if not rumor.is_empty():
			result.append(_public_payload(rumor, true))
	return result


func get_guest_bias() -> Dictionary:
	var result: Dictionary = {}
	for rumor in get_today_rumors():
		var effects: Dictionary = rumor.get("effects", {})
		var guest_bias: Dictionary = effects.get("guestBias", {})
		for key in guest_bias.keys():
			var bias_key := String(key)
			var current := float(result.get(bias_key, 1.0))
			result[bias_key] = current * float(guest_bias[key])
	return result


func capture_state() -> Dictionary:
	var heard: Array[String] = []
	for id in _heard_ids.keys():
		if bool(_heard_ids[id]):
			heard.append(String(id))
	heard.sort()
	var today := _today_ids.duplicate()
	today.sort()
	return {
		"current_day": current_day,
		"heard_ids": heard,
		"today_ids": today,
	}


func restore_state(state: Dictionary) -> void:
	_heard_ids.clear()
	_today_ids.clear()
	current_day = int(state.get("current_day", 0))
	for id in state.get("heard_ids", []):
		_heard_ids[String(id)] = true
	for id in state.get("today_ids", []):
		var clean := String(id)
		if _rumor_by_id(clean).is_empty():
			continue
		if not _today_ids.has(clean):
			_today_ids.append(clean)


func _rumor_available_for_location(rumor: Dictionary, location_id: String, day: int, flags: Dictionary) -> bool:
	if String(rumor.get("location", "")) != location_id:
		return false
	var id := String(rumor.get("id", ""))
	if id == "" or bool(_heard_ids.get(id, false)):
		return false
	if day < int(rumor.get("dayMin", 1)):
		return false
	var day_max := int(rumor.get("dayMax", 0))
	if day_max > 0 and day > day_max:
		return false
	var required_flag := String(rumor.get("requiresFlag", ""))
	if required_flag != "" and not bool(flags.get(required_flag, false)):
		return false
	var unless_flag := String(rumor.get("unlessFlag", ""))
	if unless_flag != "" and bool(flags.get(unless_flag, false)):
		return false
	return true


func _rumor_by_id(id: String) -> Dictionary:
	for rumor in _rumors:
		if String(rumor.get("id", "")) == id:
			return rumor
	return {}


func _public_payload(rumor: Dictionary, success: bool) -> Dictionary:
	return {
		"success": success,
		"id": String(rumor.get("id", "")),
		"location": String(rumor.get("location", "")),
		"text": String(rumor.get("text", "")),
		"menuHints": (rumor.get("menuHints", {}) as Dictionary).duplicate(true),
		"affectedCustomerIds": _affected_customer_ids(rumor),
		"effects": (rumor.get("effects", {}) as Dictionary).duplicate(true),
	}


func _affected_customer_ids(rumor: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var effects: Dictionary = rumor.get("effects", {})
	var guest_bias: Dictionary = effects.get("guestBias", {})
	for key in guest_bias.keys():
		var customer_id := String(key)
		if not customer_id.begins_with("regular_"):
			continue
		if not ids.has(customer_id):
			ids.append(customer_id)
	ids.sort()
	return ids
