class_name DocumentSystem
extends RefCounted

signal open_requested(document: Dictionary)

const DEFAULT_PATH := "res://data/documents.json"

var _definitions: Dictionary = {}
var _owned: Array[String] = ["ledger"]
var _read: Dictionary = {}
var _archived: Array[String] = []
var _ledger_entries: Array[String] = []
var _daily_summaries: Dictionary = {}
var _fate_tracks: Dictionary = {}
var _evidence_index: Dictionary = {}
var _ledger_has_unread_entries: bool = false


func load_data(path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DocumentSystem] 无法加载文档数据: " + path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("[DocumentSystem] 文档数据格式无效: " + path)
		return false
	_definitions = parsed
	return true


func has_document(document_id: String) -> bool:
	return _definitions.has(document_id)


func owns_document(document_id: String) -> bool:
	return _owned.has(document_id)


func get_owned_documents() -> Array[String]:
	var result := _owned.duplicate()
	result.sort()
	return result


func grant_document(document_id: String) -> bool:
	if not has_document(document_id):
		return false
	if not _owned.has(document_id):
		_owned.append(document_id)
	return true


func is_read(document_id: String) -> bool:
	return bool(_read.get(document_id, false))


func has_unread_ledger_entries() -> bool:
	return _ledger_has_unread_entries


func mark_ledger_read() -> void:
	_ledger_has_unread_entries = false


func request_open(document_id: String) -> Dictionary:
	if not owns_document(document_id):
		return {}
	var document := get_document(document_id)
	if document.is_empty():
		return {}
	_read[document_id] = true
	if document_id == "ledger":
		mark_ledger_read()
	open_requested.emit(document)
	return document


func archive_document(document_id: String) -> bool:
	if not owns_document(document_id):
		return false
	if not _archived.has(document_id):
		_archived.append(document_id)
	return true


func get_archived_documents() -> Array[String]:
	var result := _archived.duplicate()
	result.sort()
	return result


func add_ledger_entry(text: String, marks_unread: bool = false) -> void:
	if text != "":
		_ledger_entries.append(text)
		if marks_unread:
			_ledger_has_unread_entries = true


func add_ledger_entry_once(text: String, marks_unread: bool = true) -> bool:
	if text == "" or _ledger_entries.has(text):
		return false
	_ledger_entries.append(text)
	if marks_unread:
		_ledger_has_unread_entries = true
	return true


func record_daily_summary(day: int, summary: Dictionary, marks_unread: bool = false) -> void:
	if day <= 0:
		return
	var key := String.num_int64(day)
	var copy := summary.duplicate(true)
	copy["day"] = day
	_daily_summaries[key] = copy
	if marks_unread:
		_ledger_has_unread_entries = true


func start_fate_track(track_id: String, title: String, prediction: String, marks_unread: bool = true) -> bool:
	if track_id == "" or prediction == "":
		return false
	if _fate_tracks.has(track_id):
		return false
	_fate_tracks[track_id] = {
		"id": track_id,
		"title": title if title != "" else track_id,
		"prediction": prediction,
		"notes": [],
		"result": "",
	}
	if marks_unread:
		_ledger_has_unread_entries = true
	return true


func add_fate_note(track_id: String, note: String, marks_unread: bool = true) -> bool:
	if track_id == "" or note == "":
		return false
	if not _fate_tracks.has(track_id):
		return false
	var track: Dictionary = _fate_tracks[track_id]
	var notes: Array = track.get("notes", [])
	if notes.has(note):
		return false
	notes.append(note)
	track["notes"] = notes
	_fate_tracks[track_id] = track
	if marks_unread:
		_ledger_has_unread_entries = true
	return true


func finish_fate_track(track_id: String, result: String, marks_unread: bool = true) -> bool:
	if track_id == "" or result == "":
		return false
	if not _fate_tracks.has(track_id):
		return false
	var track: Dictionary = _fate_tracks[track_id]
	if String(track.get("result", "")) == result:
		return false
	track["result"] = result
	_fate_tracks[track_id] = track
	if marks_unread:
		_ledger_has_unread_entries = true
	return true


func index_evidence(document_id: String, links: Array = [], marks_unread: bool = true) -> bool:
	if document_id == "" or not has_document(document_id):
		return false
	var doc: Dictionary = _definitions.get(document_id, {})
	if doc.is_empty() or String(doc.get("kind", "")) != "evidence":
		return false
	if _evidence_index.has(document_id):
		return false
	var clean_links: Array[String] = []
	for link in links:
		var text := String(link)
		if text != "" and not clean_links.has(text):
			clean_links.append(text)
	_evidence_index[document_id] = {
		"id": document_id,
		"title": String(doc.get("title", document_id)),
		"summary": _evidence_summary(doc),
		"links": clean_links,
	}
	if marks_unread:
		_ledger_has_unread_entries = true
	return true


func add_document_to_ledger(document_id: String) -> void:
	## Evidence documents are indexed in the ledger; the full body stays in the document.
	index_evidence(document_id)


func get_document(document_id: String) -> Dictionary:
	if not has_document(document_id):
		return {}
	var document: Dictionary = _definitions[document_id].duplicate(true)
	document["id"] = document_id
	if document_id == "ledger":
		document["pages"] = _build_ledger_pages(document.get("pages", []))
	return document


func capture_state() -> Dictionary:
	return {
		"owned": _owned.duplicate(),
		"read": _read.duplicate(),
		"archived": _archived.duplicate(),
		"ledger_entries": _ledger_entries.duplicate(),
		"daily_summaries": _daily_summaries.duplicate(true),
		"fate_tracks": _fate_tracks.duplicate(true),
		"evidence_index": _evidence_index.duplicate(true),
		"ledger_unread": _ledger_has_unread_entries,
	}


func restore_state(data: Dictionary) -> void:
	_owned.clear()
	for d in data.get("owned", ["ledger"]):
		_owned.append(String(d))
	if not _owned.has("ledger"):
		_owned.append("ledger")
	_read.clear()
	var read_dict: Dictionary = data.get("read", {})
	for k in read_dict:
		_read[String(k)] = bool(read_dict[k])
	_archived.clear()
	for a in data.get("archived", []):
		_archived.append(String(a))
	_ledger_entries.clear()
	for e in data.get("ledger_entries", []):
		_ledger_entries.append(String(e))
	_daily_summaries = (data.get("daily_summaries", {}) as Dictionary).duplicate(true)
	_fate_tracks = (data.get("fate_tracks", {}) as Dictionary).duplicate(true)
	_evidence_index = (data.get("evidence_index", {}) as Dictionary).duplicate(true)
	_ledger_has_unread_entries = bool(data.get("ledger_unread", false))


func _build_ledger_pages(base_pages: Array) -> Array:
	var pages: Array[String] = []
	var has_structured := not _daily_summaries.is_empty() \
		or not _fate_tracks.is_empty() \
		or not _evidence_index.is_empty()
	if has_structured:
		pages.append(_render_index_page())
		for day_key in _sorted_numeric_keys(_daily_summaries):
			pages.append(_render_daily_summary(_daily_summaries[day_key]))
		for track_id in _sorted_string_keys(_fate_tracks):
			pages.append(_render_fate_track(_fate_tracks[track_id]))
		if not _evidence_index.is_empty():
			pages.append_array(_render_evidence_pages())
	else:
		pages.append_array(base_pages)
	pages.append_array(_ledger_entries)
	if pages.is_empty():
		pages.append("")
	return pages


func _render_index_page() -> String:
	var lines := [
		"账本索引",
		"",
		"营业账  %d 日" % _daily_summaries.size(),
		"宿命轨迹  %d 条" % _fate_tracks.size(),
		"证物索引  %d 件" % _evidence_index.size(),
	]
	if _ledger_entries.size() > 0:
		lines.append("零散札记  %d 条" % _ledger_entries.size())
	return "\n".join(PackedStringArray(lines))


func _render_daily_summary(summary: Dictionary) -> String:
	var day := int(summary.get("day", 0))
	var gold_today := int(summary.get("gold_today", 0))
	var rep_today := int(summary.get("rep_today", 0))
	var gold_label := "收入 %+d" % gold_today if gold_today >= 0 else "收支 %+d" % gold_today
	return "\n".join(PackedStringArray([
		"第 %d 天 · 营业账" % day,
		"",
		gold_label,
		"声望 %+d" % rep_today,
		"",
		"服务 %d 位" % int(summary.get("guests_served", 0)),
		"成功 %d 单" % int(summary.get("orders_success", 0)),
		"失手 %d 单" % int(summary.get("orders_failed", 0)),
	]))


func _render_fate_track(track: Dictionary) -> String:
	var lines: Array[String] = [
		"%s · 宿命轨迹" % String(track.get("title", "")),
		"",
		"预记",
		String(track.get("prediction", "")),
	]
	var notes: Array = track.get("notes", [])
	if not notes.is_empty():
		lines.append("")
		lines.append("旁注")
		for note in notes:
			lines.append("- " + String(note))
	var result := String(track.get("result", ""))
	if result != "":
		lines.append("")
		lines.append("结记")
		lines.append(result)
	return "\n".join(PackedStringArray(lines))


func _render_evidence_pages() -> Array[String]:
	var pages: Array[String] = []
	var current: Array[String] = ["证物索引"]
	for document_id in _sorted_string_keys(_evidence_index):
		var entry: Dictionary = _evidence_index[document_id]
		if current.size() > 1:
			current.append("")
		current.append(String(entry.get("title", document_id)))
		var links: Array = entry.get("links", [])
		if not links.is_empty():
			current.append("关联：" + " / ".join(PackedStringArray(_string_array(links))))
		var summary := String(entry.get("summary", ""))
		if summary != "":
			current.append("摘要：" + summary)
		if current.size() >= 9:
			pages.append("\n".join(PackedStringArray(current)))
			current = ["证物索引"]
	if current.size() > 1:
		pages.append("\n".join(PackedStringArray(current)))
	return pages


func _evidence_summary(doc: Dictionary) -> String:
	var pages: Array = doc.get("pages", [])
	if pages.is_empty():
		return ""
	var lines := String(pages[0]).split("\n")
	var summary_parts: Array[String] = []
	for i in range(mini(lines.size(), 2)):
		var text := String(lines[i]).strip_edges()
		if text != "":
			summary_parts.append(text)
	return " ".join(PackedStringArray(summary_parts))


func _sorted_string_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in source.keys():
		result.append(String(key))
	result.sort()
	return result


func _sorted_numeric_keys(source: Dictionary) -> Array[String]:
	var result := _sorted_string_keys(source)
	result.sort_custom(func(a: String, b: String): return int(a) < int(b))
	return result


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
