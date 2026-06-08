extends Node

## Mira 线逻辑单测：裸 NarrativeManager 实例，覆盖托比解析、变量初始化、
## toby_contract 告知、结局网格 4 格、托比存活=担责 OR 兜底。headless 安全。

var _checks := 0
var _failures := 0

func _ready() -> void:
	_test_parse_and_init()
	_test_toby_contract_informs_mira()
	_test_route_she_finally_stopped()
	_test_route_never_turned_back()
	_test_route_closed_the_door()
	_test_route_another_light_out()
	_test_toby_survival_flags()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MIRA] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-MIRA] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MIRA] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)

func _nm() -> NarrativeManager:
	var nm := NarrativeManager.new()
	nm.load_npc_data()
	return nm

func _test_parse_and_init() -> void:
	var nm := _nm()
	var toby: NpcData = null
	for n in nm.all_npcs:
		if n.id == "toby":
			toby = n
	_ok(toby != null, "应解析到 toby")
	_ok(nm.get_affection("mira") == 5, "aff_mira 初始 5")
	_ok(nm.get_var("told_mira_truth") == false, "told_mira_truth 初始 false")
	_ok(nm.get_var("toby_secured") == false, "toby_secured 初始 false")

func _test_toby_contract_informs_mira() -> void:
	var nm := _nm()
	# 递给 mira：告知真相
	var r := nm.resolve_action({"type": "give_story_item", "npc_id": "mira", "item_key": "toby_contract"})
	_ok(r.get("accepted", false), "Mira 收下托比委托书")
	_ok(nm.get_var("told_mira_truth") == true, "递交置 told_mira_truth")
	# 递给非 mira：不认
	var nm2 := _nm()
	var bad := nm2.resolve_action({"type": "give_story_item", "npc_id": "toby", "item_key": "toby_contract"})
	_ok(not bad.get("accepted", true), "托比本人不接收真相文档")

func _test_route_she_finally_stopped() -> void:
	var nm := _nm()
	nm.set_var("told_mira_truth", true)
	nm.set_affection("mira", nm.MIRA_TRUST_THRESHOLD)
	_ok(nm.get_mira_route() == "she_finally_stopped", "告知+信任达标 → 她终于停下")

func _test_route_never_turned_back() -> void:
	var nm := _nm()
	nm.set_var("told_mira_truth", true)
	nm.set_affection("mira", nm.MIRA_TRUST_THRESHOLD - 1)
	_ok(nm.get_mira_route() == "never_turned_back", "告知+信任不足 → 再没回头")

func _test_route_closed_the_door() -> void:
	var nm := _nm()
	nm.set_var("toby_secured", true)
	_ok(nm.get_mira_route() == "closed_the_door", "未告知+兜底 → 替他合上门")

func _test_route_another_light_out() -> void:
	var nm := _nm()
	_ok(nm.get_mira_route() == "another_light_out", "未告知+未兜底 → 另一盏熄灭的灯")

func _test_toby_survival_flags() -> void:
	var nm := _nm()
	# 担责救活
	nm.set_var("told_mira_truth", true)
	nm.set_affection("mira", nm.MIRA_TRUST_THRESHOLD)
	_ok(nm.toby_survived(), "担责 → 托比存活")
	# 仅兜底救活（未告知）
	var nm2 := _nm()
	nm2.set_var("toby_secured", true)
	_ok(nm2.toby_survived(), "兜底 → 托比存活")
	# 告知但信任不足且未兜底 → 死
	var nm3 := _nm()
	nm3.set_var("told_mira_truth", true)
	nm3.set_affection("mira", nm3.MIRA_TRUST_THRESHOLD - 1)
	_ok(not nm3.toby_survived(), "知情仍逃且未兜底 → 托比赴死")
	# finalize 写入 ending 与 toby_survived
	nm3.finalize_mira_ending()
	_ok(nm3.get_var("mira_ending") == "never_turned_back", "finalize 写 mira_ending")
	_ok(nm3.get_var("toby_survived") == false, "finalize 写 toby_survived")
	_ok(nm3.endings.get("toby", "") == "lost", "finalize 写 toby 结局 lost")
	# 担责存活时托比结局为 saved
	var nm4 := _nm()
	nm4.set_var("told_mira_truth", true)
	nm4.set_affection("mira", nm4.MIRA_TRUST_THRESHOLD)
	nm4.finalize_mira_ending()
	_ok(nm4.endings.get("toby", "") == "saved", "finalize 写 toby 结局 saved")
