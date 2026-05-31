class_name DocumentSystem
extends RefCounted

signal open_requested(document: Dictionary)

const DEFAULT_PATH := "res://data/documents.json"

var _definitions: Dictionary = {}
var _owned: Array[String] = ["ledger"]
var _read: Dictionary = {}
var _archived: Array[String] = []
var _ledger_entries: Array[String] = []


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


func request_open(document_id: String) -> Dictionary:
	if not owns_document(document_id):
		return {}
	var document := get_document(document_id)
	if document.is_empty():
		return {}
	_read[document_id] = true
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


func add_ledger_entry(text: String) -> void:
	if text != "":
		_ledger_entries.append(text)


func add_ledger_entry_once(text: String) -> bool:
	if text == "" or _ledger_entries.has(text):
		return false
	_ledger_entries.append(text)
	return true


func get_document(document_id: String) -> Dictionary:
	if not has_document(document_id):
		return {}
	var document: Dictionary = _definitions[document_id].duplicate(true)
	document["id"] = document_id
	if document_id == "ledger":
		var pages: Array = document.get("pages", []).duplicate()
		pages.append_array(_ledger_entries)
		document["pages"] = pages
	return document


func capture_state() -> Dictionary:
	return {
		"owned": _owned.duplicate(),
		"read": _read.duplicate(),
		"archived": _archived.duplicate(),
		"ledger_entries": _ledger_entries.duplicate(),
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
