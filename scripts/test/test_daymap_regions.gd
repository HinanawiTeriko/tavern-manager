extends Node

## DayMapSystem 区域模型：regions 解析、点位世界坐标=origin+局部、边界=区域并集。

var _checks := 0
var _failures := 0

func _ready() -> void:
	var sys := DayMapSystem.new()
	sys.load_data()
	sys.start_day(6)
	# 解锁北矿道门控点位，便于断言其世界坐标（坐标解析与门控无关，仅 get_locations 过滤）
	sys.set_lead_flag("mine_clue", true)

	# regions 解析
	var regions := sys.get_regions()
	_ok(regions.size() == 4, "解析到 4 个区域")
	var by_id := {}
	for r in regions:
		by_id[String(r.get("id",""))] = r
	_ok(by_id.has("market") and by_id.has("fog"), "含 market 与 fog 区域")

	# 点位世界坐标 = origin + 局部 pos
	var loc := _find(sys, "mira_stall")
	_ok(loc.size() > 0, "找到 mira_stall")
	# market origin (0,0) + 局部 (980,300) = (980,300)
	_ok(_pos(loc) == Vector2(980, 300), "mira_stall 世界坐标 = (980,300)")
	var forest := _find(sys, "mushroom_forest")
	# wilds origin (1280,0) + (555,555) = (1835,555)
	_ok(_pos(forest) == Vector2(1835, 555), "mushroom_forest 世界坐标 = (1835,555)")
	var mine := _find(sys, "abandoned_mine")
	# north_road origin (0,720) + (930,225) = (930,945)
	_ok(_pos(mine) == Vector2(930, 945), "abandoned_mine 世界坐标 = (930,945)")

	# 边界 = 区域并集
	var b := sys.get_map_bounds()
	_ok(b["min"] == Vector2(0, 0), "边界 min = (0,0)")
	_ok(b["max"] == Vector2(2560, 1440), "边界 max = (2560,1440)")

	# 每个点位世界坐标落在某区域矩形内
	for l in sys.get_locations():
		var wp := _pos(l)
		var rid := String(l.get("region",""))
		var reg = by_id.get(rid, {})
		_ok(reg.size() > 0, "点位 %s 有合法区域" % String(l.get("id","")))
		if reg.size() > 0:
			var o = reg["origin"]; var s = reg["size"]
			var inside := wp.x >= float(o[0]) and wp.x <= float(o[0])+float(s[0]) \
				and wp.y >= float(o[1]) and wp.y <= float(o[1])+float(s[1])
			_ok(inside, "点位 %s 落在区域 %s 内" % [String(l.get("id","")), rid])
	_finish()

func _find(sys: DayMapSystem, id: String) -> Dictionary:
	for l in sys.get_locations():
		if String(l.get("id","")) == id:
			return l
	return {}

func _pos(l: Dictionary) -> Vector2:
	var p: Array = l.get("pos", [0,0])
	return Vector2(float(p[0]), float(p[1]))

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-REGIONS] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-REGIONS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-REGIONS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
