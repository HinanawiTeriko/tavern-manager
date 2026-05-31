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
