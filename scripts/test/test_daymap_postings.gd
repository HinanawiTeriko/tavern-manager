extends Node

## 地点贴文机制：统一告示板常驻、贴文随天数/旗标更新、访问产出取激活贴文、
## 内容变化进 updated-locations（重新拉镜头）。守护莱恩线（血斧贴文→mine_clue）。

var _checks := 0
var _failures := 0

func _ready() -> void:
	# Day1：告示板常驻可见、闲置（无激活贴文）
	var m := _sys(1)
	_ok(_ids(m.get_locations()).has("mercenary_board"), "Day1 告示板常驻可见")
	_ok(_eff(m, "mercenary_board").get("active_posting", "x") == "", "Day1 无激活贴文（闲置）")

	# Day2 无 lead：仍闲置，访问成功但不产 mine_clue（矿道不解锁）
	var m2 := _sys(2)
	_ok(m2.visit("mercenary_board").get("success", false), "闲置板访问成功")
	_ok(not _ids(m2.get_locations()).has("abandoned_mine"), "闲置板不解锁矿道")

	# Day2 + lead：血斧贴文激活，访问产 mine_clue → 矿道解锁
	var m3 := _sys(2)
	m3.set_lead_flag("ryan_warhammer_lead", true)
	_ok(_eff(m3, "mercenary_board").get("active_posting", "") == "ryan_warhammer", "Day2+lead 血斧贴文激活")
	m3.visit("mercenary_board")
	_ok(_ids(m3.get_locations()).has("abandoned_mine"), "血斧贴文解锁矿道（莱恩线保活）")

	# Day3 起血斧小队已经出发；旧 lead 仍在存档里也不能继续显示招募贴文
	var m3b := _sys(2)
	m3b.set_lead_flag("ryan_warhammer_lead", true)
	m3b.mark_revealed("mercenary_board")
	m3b.mark_posting_announced("mercenary_board")
	m3b.start_day(3)
	m3b.set_lead_flag("ryan_warhammer_lead", true)
	var expired_board := _eff(m3b, "mercenary_board")
	_ok(expired_board.get("active_posting", "x") == "", "Day3 血斧贴文过期并回到闲置")
	_ok(not String(expired_board.get("description", "")).contains("血斧小队"), "Day3 告示牌描述不再显示血斧招募")
	_ok(_ids(m3b.get_updated_locations()).has("mercenary_board"), "血斧贴文过期后告示牌进入更新列表")
	var expired_visit := m3b.visit("mercenary_board")
	_ok(String(expired_visit.get("unlockedFlag", "")) == "", "过期血斧贴文不会继续产出 mine_clue")

	# Day6：托比贴文激活（盖过血斧），描述更新、访问授予 toby_contract
	var m4 := _sys(6)
	m4.set_lead_flag("ryan_warhammer_lead", true)
	var eff := _eff(m4, "mercenary_board")
	_ok(eff.get("active_posting", "") == "toby_commission", "Day6 托比贴文激活（盖过血斧）")
	_ok(String(eff.get("description", "")).contains("托比"), "Day6 描述更新为托比委托")
	var vr := m4.visit("mercenary_board")
	_ok(String(vr.get("unlockedFlag", "")) == "toby_commission_lead", "Day6 board visit unlocks Toby lead flag")
	_ok(String(vr.get("activePosting", "")) == "toby_commission", "Day6 board visit reports active Toby posting")
	var board_message := String(vr.get("message", ""))
	_ok(board_message.contains("托比"), "Day6 board result names Toby as the signer")
	_ok(board_message.contains("黑齿矿脉"), "Day6 board result keeps the dangerous commission clue")
	_ok(not board_message.contains("米拉"), "Day6 board result does not reveal Mira's connection to Toby")
	_ok(not board_message.contains("学徒"), "Day6 board result does not reveal Toby was Mira's apprentice")
	_ok(not board_message.contains("撇下"), "Day6 board result does not spoil that Mira abandoned Toby")
	_ok(not (vr.get("documents", []) as Array).has("toby_contract"), "告示板贴文不再直接授予委托书（已搬进托比落脚处场景）")
	var toby_pre := FileAccess.get_file_as_string("res://dialogue/toby_day6.pre.dialogue")
	_ok(toby_pre.contains("一个人走"), "Toby Day6 pre dialogue echoes the lone-road clue")
	_ok(not toby_pre.contains("米拉"), "Toby Day6 pre dialogue hints without naming Mira")
	var toby_post := FileAccess.get_file_as_string("res://dialogue/toby_day6.post.dialogue")
	_ok(not toby_post.contains("后天"), "Toby Day6 post avoids a hard departure date before Day12")
	_ok(toby_post.contains("队伍") or toby_post.contains("点齐"),
		"Toby Day6 post frames departure as waiting for the escort team")
	var mira_day4_pre := FileAccess.get_file_as_string("res://dialogue/mira_day4.pre.dialogue")
	_ok(mira_day4_pre.contains("一个人走") and mira_day4_pre.contains("轻快"),
		"Mira Day4 pre dialogue plants the exact lone-road phrase before serving")
	var docs_root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/documents.json"))
	var toby_doc: Dictionary = docs_root.get("toby_contract", {})
	var doc_pages: Array = toby_doc.get("pages", [])
	var contract_text := String(doc_pages[0]) if not doc_pages.is_empty() else ""
	_ok(contract_text.contains("一个人走"), "Toby contract document repeats the lone-road phrase")
	_ok(contract_text.contains("米拉"), "Toby contract document points the evidence back to Mira")

	# 重新亮相：刚亮相无更新；贴文激活后进 updated-locations；宣告后清除
	var m5 := _sys(2)
	m5.mark_revealed("mercenary_board")
	_ok(not _ids(m5.get_updated_locations()).has("mercenary_board"), "刚亮相无更新")
	m5.set_lead_flag("ryan_warhammer_lead", true)
	_ok(_ids(m5.get_updated_locations()).has("mercenary_board"), "贴文激活 → 板子进更新列表（重新拉镜头）")
	m5.mark_posting_announced("mercenary_board")
	_ok(not _ids(m5.get_updated_locations()).has("mercenary_board"), "宣告后不再重复更新")

	# toby_board 已删除
	_ok(not _ids(m4.get_locations()).has("toby_board"), "toby_board 已并入告示板")
	_finish()

func _sys(day: int) -> DayMapSystem:
	var s := DayMapSystem.new()
	s.load_data()
	s.start_day(day)
	return s

func _ids(locs: Array) -> Array:
	var r := []
	for l in locs:
		r.append(String(l.get("id", "")))
	return r

func _eff(s: DayMapSystem, id: String) -> Dictionary:
	for l in s.get_locations():
		if String(l.get("id", "")) == id:
			return l
	return {}

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-POSTINGS] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-POSTINGS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-POSTINGS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
