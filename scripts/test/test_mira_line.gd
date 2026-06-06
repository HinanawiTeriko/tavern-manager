extends Node

## Mira 线逻辑单测：裸 NarrativeManager 实例，覆盖托比解析、变量初始化、
## toby_contract 告知、结局网格 4 格、托比存活=担责 OR 兜底。headless 安全。

var _checks := 0
var _failures := 0

func _ready() -> void:
	_test_parse_and_init()
	# 以下方法在 Task 1.2 / 1.3 解注释
	# _test_toby_contract_informs_mira()
	# _test_route_she_finally_stopped()
	# _test_route_never_turned_back()
	# _test_route_closed_the_door()
	# _test_route_another_light_out()
	# _test_toby_survival_flags()
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
