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
	_test_structured_ledger_tracks_and_indexes()
	_test_structured_ledger_state_roundtrip()
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


func _test_structured_ledger_tracks_and_indexes() -> void:
	var docs := DocumentSystem.new()
	docs.load_data()
	_ok(docs.has_method("start_fate_track"), "DocumentSystem can create structured fate tracks")
	_ok(docs.has_method("add_fate_note"), "DocumentSystem can append fate track notes")
	_ok(docs.has_method("finish_fate_track"), "DocumentSystem can finish fate tracks")
	_ok(docs.has_method("record_daily_summary"), "DocumentSystem can record daily summaries")
	_ok(docs.has_method("index_evidence"), "DocumentSystem can index evidence without copying full text")
	if not docs.has_method("start_fate_track"):
		return

	_ok(docs.start_fate_track("ryan", "莱恩", "第三日。北矿道。未归。"), "first Ryan fate track is created")
	_ok(not docs.start_fate_track("ryan", "莱恩", "第三日。北矿道。未归。"), "duplicate Ryan fate track is ignored")
	docs.add_fate_note("ryan", "读过染血委托。")
	docs.add_fate_note("ryan", "替代委托已递出。")
	docs.finish_fate_track("ryan", "未赴血斧委托。存活。")
	docs.index_evidence("bloodied_contract", ["莱恩", "北矿道"])
	docs.record_daily_summary(3, {
		"gold_today": 12,
		"rep_today": 2,
		"guests_served": 4,
		"orders_success": 3,
		"orders_failed": 1,
	})

	var ledger := docs.get_document("ledger")
	var pages: Array = ledger.get("pages", [])
	var all_text := "\n".join(PackedStringArray(_string_pages(pages)))
	_ok(all_text.contains("账本索引"), "structured ledger starts with an index")
	_ok(all_text.contains("营业账"), "structured ledger renders a business section")
	_ok(all_text.contains("第 3 天"), "daily summary includes the day")
	_ok(all_text.contains("收入 +12") and all_text.contains("声望 +2"),
		"daily summary renders compact gold and reputation totals")
	_ok(all_text.contains("莱恩 · 宿命轨迹"), "fate track renders as a character section")
	_ok(all_text.contains("预记") and all_text.contains("第三日。北矿道。未归。"),
		"fate track renders the original prediction")
	_ok(all_text.contains("旁注") and all_text.contains("读过染血委托。") and all_text.contains("替代委托已递出。"),
		"fate track renders player intervention notes")
	_ok(all_text.contains("结记") and all_text.contains("未赴血斧委托。存活。"),
		"fate track renders the changed result")
	_ok(all_text.contains("证物索引") and all_text.contains("染血委托书"),
		"evidence renders as an index entry")
	_ok(not all_text.contains("纸角沾着已经干涸的血迹。"),
		"ledger does not copy full evidence body text into the ledger")


func _test_structured_ledger_state_roundtrip() -> void:
	var docs := DocumentSystem.new()
	docs.load_data()
	docs.start_fate_track("toby", "托比", "第十二日。黑齿矿脉。未归。")
	docs.add_fate_note("toby", "委托书已拼回。")
	docs.finish_fate_track("toby", "未赴黑齿。存活。")
	docs.index_evidence("toby_contract", ["托比", "米拉"])
	docs.record_daily_summary(12, {
		"gold_today": -40,
		"rep_today": 0,
		"guests_served": 3,
		"orders_success": 3,
		"orders_failed": 0,
	})
	var snap := docs.capture_state()
	_ok((snap.get("fate_tracks", {}) as Dictionary).has("toby"), "capture includes structured fate tracks")
	_ok((snap.get("evidence_index", {}) as Dictionary).has("toby_contract"), "capture includes evidence index")
	_ok((snap.get("daily_summaries", {}) as Dictionary).has("12"), "capture includes daily summaries")

	var restored := DocumentSystem.new()
	restored.load_data()
	restored.restore_state(snap)
	var all_text := "\n".join(PackedStringArray(_string_pages(restored.get_document("ledger").get("pages", []))))
	_ok(all_text.contains("托比 · 宿命轨迹"), "restored fate track renders")
	_ok(all_text.contains("委托书已拼回。"), "restored fate note renders")
	_ok(all_text.contains("未赴黑齿。存活。"), "restored fate result renders")
	_ok(all_text.contains("托比的委托书"), "restored evidence index renders")
	_ok(all_text.contains("第 12 天"), "restored daily summary renders")


func _string_pages(pages: Array) -> Array[String]:
	var result: Array[String] = []
	for page in pages:
		result.append(String(page))
	return result


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
