extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var sys := DayMapSystem.new()
	_ok(sys.load_data(), "locations data loads")
	sys.start_day(6)
	sys.set_lead_flag("mine_clue", true)

	var regions := sys.get_regions()
	_ok(regions.size() == 4, "parses four regions")
	var by_id := {}
	for r in regions:
		by_id[String(r.get("id", ""))] = r
	_ok(by_id.has("market") and by_id.has("fog"), "includes market and fog regions")

	var loc := _find(sys, "mira_stall")
	_ok(not loc.is_empty(), "finds mira_stall")
	_ok(_pos(loc) == Vector2(1720, 760), "mira_stall world pos resolves onto the v2 town market")

	var forest := _find(sys, "mushroom_forest")
	_ok(_pos(forest) == Vector2(410, 420), "mushroom_forest world pos resolves onto the v2 dark forest")

	var mine := _find(sys, "abandoned_mine")
	_ok(_pos(mine) == Vector2(430, 1055), "abandoned_mine world pos resolves onto the v2 mine cave")

	_test_anchor_model(sys, by_id)
	_test_shop_location(sys)

	var b := sys.get_map_bounds()
	_ok(b["min"] == Vector2(0, 0), "bounds min = (0,0)")
	_ok(b["max"] == Vector2(2560, 1440), "bounds max = (2560,1440)")

	for l in sys.get_locations():
		var wp := _pos(l)
		var rid := String(l.get("region", ""))
		var reg = by_id.get(rid, {})
		_ok(not reg.is_empty(), "location %s has a valid region" % String(l.get("id", "")))
		if not reg.is_empty():
			_ok(_inside_region(wp, reg), "location %s lands inside region %s" % [String(l.get("id", "")), rid])

	_finish()


func _test_anchor_model(sys: DayMapSystem, by_id: Dictionary) -> void:
	_ok(sys.has_method("get_anchors"), "DayMapSystem exposes get_anchors")
	if not sys.has_method("get_anchors"):
		return
	var anchors: Array = sys.call("get_anchors")
	_ok(anchors.size() >= 12, "DayMap has reusable marker anchors")
	var by_anchor := {}
	for anchor in anchors:
		var id := String(anchor.get("id", ""))
		by_anchor[id] = anchor
		var rid := String(anchor.get("region", ""))
		_ok(by_id.has(rid), "anchor %s has a valid region" % id)
		var kind := String(anchor.get("kind", ""))
		_ok(["landmark_anchor", "route_anchor", "reserve_anchor"].has(kind), "anchor %s has a supported kind" % id)
		var reg = by_id.get(rid, {})
		if not reg.is_empty():
			_ok(_inside_region(_pos(anchor), reg), "anchor %s lands inside region %s" % [id, rid])

	_ok(by_anchor.has("market_crossroad_01"), "market route anchor exists")
	_ok(_pos(by_anchor.get("market_crossroad_01", {})) == Vector2(1600, 830), "market_crossroad_01 resolves onto the v2 town landmark")
	var board := _find(sys, "mercenary_board")
	_ok(String(board.get("anchor", "")) == "market_crossroad_01", "mercenary board references anchor")
	_ok(_pos(board) == _pos(by_anchor.get("market_crossroad_01", {})), "location pos resolves from its anchor")

	sys.start_day(17)
	var blacktooth := _find(sys, "blacktooth_ledger")
	var mira_supply := _find(sys, "mira_supply_copy")
	var clearing := _find(sys, "clearing_table")
	var payout := _find(sys, "payout_office")
	var mira_stall := _find(sys, "mira_stall")
	_ok(not blacktooth.is_empty(), "finds blacktooth_ledger")
	_ok(not mira_supply.is_empty(), "finds mira_supply_copy")
	_ok(not clearing.is_empty(), "finds clearing_table")
	_ok(not payout.is_empty(), "finds payout_office")
	_ok(_pos(blacktooth) != _pos(board), "blacktooth ledger has its own map coordinate")
	_ok(_pos(mira_supply) != _pos(mira_stall), "Mira supply copy has its own map coordinate")
	_ok(_pos(payout) != _pos(clearing), "payout office and clearing table are separate map points")


func _test_shop_location(sys: DayMapSystem) -> void:
	var shop := _find(sys, "market_shop")
	_ok(not shop.is_empty(), "finds market_shop location")
	if shop.is_empty():
		return
	_ok(bool(shop.get("opensShop", false)), "market_shop is flagged opensShop")
	_ok(int(shop.get("cost", 1)) == 0, "market_shop costs no stamina")
	_ok(bool(shop.get("repeatable", false)), "market_shop is repeatable")
	_ok(String(shop.get("anchor", "")) == "market_shop_01", "market_shop references its anchor")
	_ok(_pos(shop) == Vector2(1745, 640), "market_shop resolves onto the market anchor")
	# 商店是免费、可重复地点：visit 不应消耗体力，可反复进入
	var before := sys.stamina
	var r1 := sys.visit("market_shop")
	_ok(bool(r1.get("success", false)), "market_shop visit succeeds")
	_ok(sys.stamina == before, "market_shop visit keeps stamina unchanged")
	var r2 := sys.visit("market_shop")
	_ok(bool(r2.get("success", false)), "market_shop visit repeatable same day")


func _inside_region(world_pos: Vector2, region: Dictionary) -> bool:
	var o = region.get("origin", [0, 0])
	var s = region.get("size", [1280, 720])
	return world_pos.x >= float(o[0]) and world_pos.x <= float(o[0]) + float(s[0]) \
		and world_pos.y >= float(o[1]) and world_pos.y <= float(o[1]) + float(s[1])


func _find(sys: DayMapSystem, id: String) -> Dictionary:
	for l in sys.get_locations():
		if String(l.get("id", "")) == id:
			return l
	return {}


func _pos(l: Dictionary) -> Vector2:
	var p: Array = l.get("pos", [0, 0])
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
