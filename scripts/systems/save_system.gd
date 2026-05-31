class_name SaveSystem
extends RefCounted

## 只负责序列化与恢复 + 磁盘读写，不认识任何子系统，不推进日期（spec §12.2）。
const SAVE_PATH := "user://ryan_slice_save.json"
const SCHEMA_VERSION := 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func write(snapshot: Dictionary) -> bool:
	var payload := {"version": SCHEMA_VERSION, "data": snapshot}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] 无法写存档: " + SAVE_PATH)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func read() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("[SaveSystem] 存档格式无效")
		return {}
	if int(parsed.get("version", 0)) != SCHEMA_VERSION:
		push_warning("[SaveSystem] 存档版本不匹配，已忽略")
		return {}
	var data = parsed.get("data", {})
	if not data is Dictionary:
		return {}
	return _normalize(data)

func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

## JSON 把所有数字读回成 float；把整数 float 还原为 int，使 round-trip 精确。
func _normalize(value):
	if value is float:
		if value == floor(value) and abs(value) < 9.0e15:
			return int(value)
		return value
	if value is Dictionary:
		var out := {}
		for k in value:
			out[k] = _normalize(value[k])
		return out
	if value is Array:
		var arr := []
		for e in value:
			arr.append(_normalize(e))
		return arr
	return value
