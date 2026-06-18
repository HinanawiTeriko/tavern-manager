class_name PhysicsLawSystem
extends RefCounted

const DEFAULT_PATH := "res://data/physics_laws.json"
const MIN_DESK_GRAVITY := 0.2
const MAX_DESK_GRAVITY := 2.0
const MIN_DAMP_MULTIPLIER := 0.05
const MAX_DAMP_MULTIPLIER := 4.0
const MIN_BOUNCE := 0.0
const MAX_BOUNCE := 1.0

var _laws_by_id: Dictionary = {}
var _active_law_id := ""


func _init(path: String = DEFAULT_PATH) -> void:
	if path != "":
		load_from_path(path)


func load_from_path(path: String = DEFAULT_PATH) -> bool:
	_laws_by_id.clear()
	_active_law_id = ""
	if not FileAccess.file_exists(path):
		push_error("Physics law data not found: %s" % path)
		return false

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Physics law data must be a dictionary: %s" % path)
		return false

	for raw_law in parsed.get("laws", []):
		if typeof(raw_law) != TYPE_DICTIONARY:
			continue
		var law := Dictionary(raw_law).duplicate(true)
		var id := String(law.get("id", "")).strip_edges()
		if id == "":
			continue
		var multiplier := float(law.get("gravity_scale_multiplier", 1.0))
		law["gravity_scale_multiplier"] = clampf(multiplier, MIN_DESK_GRAVITY, MAX_DESK_GRAVITY)
		var linear_damp_multiplier := float(law.get("linear_damp_multiplier", 1.0))
		var angular_damp_multiplier := float(law.get("angular_damp_multiplier", 1.0))
		law["linear_damp_multiplier"] = clampf(linear_damp_multiplier, MIN_DAMP_MULTIPLIER, MAX_DAMP_MULTIPLIER)
		law["angular_damp_multiplier"] = clampf(angular_damp_multiplier, MIN_DAMP_MULTIPLIER, MAX_DAMP_MULTIPLIER)
		if law.has("bounce_override"):
			law["bounce_override"] = clampf(float(law.get("bounce_override", 0.0)), MIN_BOUNCE, MAX_BOUNCE)
		law["id"] = id
		_laws_by_id[id] = law
	return not _laws_by_id.is_empty()


func has_law(law_id: String) -> bool:
	return _laws_by_id.has(law_id)


func get_law(law_id: String) -> Dictionary:
	return Dictionary(_laws_by_id.get(law_id, {})).duplicate(true)


func try_activate_for_night(law_id: String) -> bool:
	if _active_law_id != "":
		return false
	if not has_law(law_id):
		return false
	_active_law_id = law_id
	return true


func has_active_law() -> bool:
	return _active_law_id != ""


func get_active_law() -> Dictionary:
	if _active_law_id == "":
		return {}
	return get_law(_active_law_id)


func clear_active_law() -> void:
	_active_law_id = ""
