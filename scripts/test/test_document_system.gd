extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_document_state()
	_test_game_manager_document_mediation()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DOCUMENTS] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DOCUMENTS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DOCUMENTS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_document_state() -> void:
	var docs := DocumentSystem.new()
	_ok(docs.load_data(), "documents.json loads")
	_ok(docs.has_document("ledger"), "ledger definition exists")
	_ok(docs.get_owned_documents() == ["ledger"], "ledger is owned by default")
	_ok(not docs.is_read("bloodied_contract"), "contract starts unread")
	docs.grant_document("bloodied_contract")
	_ok(docs.owns_document("bloodied_contract"), "grant adds owned document")
	var contract := docs.request_open("bloodied_contract")
	_ok(contract.get("title", "") == "染血委托书", "open returns contract definition")
	_ok(docs.is_read("bloodied_contract"), "open marks contract read")
	docs.archive_document("bloodied_contract")
	_ok(docs.get_archived_documents() == ["bloodied_contract"], "archive records document")
	docs.add_ledger_entry("第三日。莱恩。\n北矿道。\n未归。")
	var ledger := docs.request_open("ledger")
	_ok(ledger.get("kind", "") == "ledger", "ledger opens as ledger kind")
	_ok(ledger.get("pages", []).has("第三日。莱恩。\n北矿道。\n未归。"), "ledger includes added entry")


func _test_game_manager_document_mediation() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.documents is DocumentSystem, "GameManager owns DocumentSystem")
	var ledger: Dictionary = gm.request_open_document("ledger")
	_ok(ledger.get("id", "") == "ledger", "GameManager routes ledger open request")
