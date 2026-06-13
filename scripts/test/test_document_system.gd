extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_document_state()
	_test_game_manager_document_mediation()
	_test_ledger_toggle_matches_tab_keycode()
	_test_capture_restore()
	_test_ledger_entry_once()
	_test_ledger_unread_entry_state()
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


func _test_capture_restore() -> void:
	var d := DocumentSystem.new()
	d.load_data()
	d.grant_document("bloodied_contract")
	d.request_open("bloodied_contract")
	d.add_ledger_entry("第三日。莱恩。北矿道。未归。")
	d.add_ledger_entry_once("第三日。莱恩。\n北矿道。\n未归。")
	var snap := d.capture_state()
	var d2 := DocumentSystem.new()
	d2.load_data()
	d2.restore_state(snap)
	_ok(d2.owns_document("bloodied_contract"), "restored ownership")
	_ok(d2.is_read("bloodied_contract"), "restored read state")
	_ok(d2.owns_document("ledger"), "ledger always owned after restore")
	_ok(d2.has_method("has_unread_ledger_entries"), "DocumentSystem exposes ledger unread state")
	if d2.has_method("has_unread_ledger_entries"):
		_ok(d2.has_unread_ledger_entries(), "restored ledger remembers unread dynamic entries")
	var doc := d2.get_document("ledger")
	_ok(doc.get("pages", []).has("第三日。莱恩。北矿道。未归。"), "restored ledger entry")


func _test_ledger_entry_once() -> void:
	var d := DocumentSystem.new()
	d.load_data()
	_ok(d.add_ledger_entry_once("第三日。莱恩。\n北矿道。\n未归。"), "first ledger prediction is added")
	_ok(not d.add_ledger_entry_once("第三日。莱恩。\n北矿道。\n未归。"), "duplicate ledger prediction is ignored")
	var ledger := d.get_document("ledger")
	_ok(ledger.get("pages", []).count("第三日。莱恩。\n北矿道。\n未归。") == 1, "prediction appears once")


func _test_ledger_unread_entry_state() -> void:
	var d := DocumentSystem.new()
	d.load_data()
	_ok(d.has_method("has_unread_ledger_entries"), "DocumentSystem can report unread ledger entries")
	_ok(d.has_method("mark_ledger_read"), "DocumentSystem can clear unread ledger entries")
	if not d.has_method("has_unread_ledger_entries") or not d.has_method("mark_ledger_read"):
		return
	_ok(not d.has_unread_ledger_entries(), "fresh ledger has no unread dynamic entries")
	d.add_ledger_entry_once("第三日。莱恩。\n北矿道。\n未归。")
	_ok(d.has_unread_ledger_entries(), "new fate ledger entry marks the ledger unread")
	d.request_open("ledger")
	_ok(not d.has_unread_ledger_entries(), "opening the ledger clears the unread entry prompt")


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


func _test_ledger_toggle_matches_tab_keycode() -> void:
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	_ok(InputMap.event_is_action(tab, "ledger_toggle"), "ledger toggle matches a Tab key event")
