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

	# Day6：托比贴文激活（盖过血斧），描述更新、访问授予 toby_contract
	var m4 := _sys(6)
	m4.set_lead_flag("ryan_warhammer_lead", true)
	var eff := _eff(m4, "mercenary_board")
	_ok(eff.get("active_posting", "") == "toby_commission", "Day6 托比贴文激活（盖过血斧）")
	_ok(String(eff.get("description", "")).contains("托比"), "Day6 描述更新为托比委托")
	var vr := m4.visit("mercenary_board")
	_ok(String(vr.get("unlockedFlag", "")) == "toby_commission_lead", "Day6 board visit unlocks Toby lead flag")
	_ok(String(vr.get("activePosting", "")) == "toby_commission", "Day6 board visit reports active Toby posting")
	_ok(not (vr.get("documents", []) as Array).has("toby_contract"), "告示板贴文不再直接授予委托书（已搬进托比落脚处场景）")

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
