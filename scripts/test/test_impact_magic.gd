extends Node

## 冲击魔法功能单元测：shop abilities / 砸解锁状态 / 配方反查 / 力度分档 /
## buy_ability / quality 收益 / 存档往返。物理碰撞与商店 UI 走编辑器走查。

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_shop_abilities()
	_test_slam_state()
	_test_find_slam_recipe()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-IMPACT] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-IMPACT] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-IMPACT] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _gm():
	return get_node("/root/GameManager")


func _test_shop_abilities() -> void:
	var s = _gm().shop
	_ok(s.get_ability_price("slam_pot") == 60, "slam_pot 价格应为 60")
	_ok(s.get_ability_price("slam_barrel") == 100, "slam_barrel 价格应为 100")
	_ok(s.get_ability_name("slam_pot") == "冲击魔法·炖锅", "slam_pot 名称")
	_ok(s.get_ability_price("nope") == -1, "未知能力价格应为 -1")
	_ok(s.get_ability_keys().size() == 2, "应有 2 个能力")


func _test_slam_state() -> void:
	var c = _gm().craft
	# 解锁状态从干净起步（测试间互不污染：先清）
	c.unlocked_slam_containers.clear()
	_ok(not c.is_slam_unlocked("pot"), "初始 pot 未解锁")
	c.unlock_slam("pot")
	_ok(c.is_slam_unlocked("pot"), "解锁后 pot 已解锁")
	c.unlock_slam("pot")  # 幂等
	_ok(c.unlocked_slam_containers.size() == 1, "重复解锁不应增加")
	# 力度分档
	_ok(c.classify_slam_force(100.0) == "none", "100 应不合成")
	_ok(c.classify_slam_force(500.0) == "normal", "窗口内应 normal")
	_ok(c.classify_slam_force(1500.0) == "poor", "超上限应 poor")


func _test_find_slam_recipe() -> void:
	var c = _gm().craft
	c.unlocked_slam_containers.clear()
	c.unlocked_recipes.clear()

	# 未解锁任何砸 → 无匹配
	_ok(c.find_slam_recipe(["herb", "ale"]).is_empty(), "未解锁 pot 时草药清汤不可砸")

	c.unlock_slam("pot")
	# 双料 pot 配方：herb_broth = herb + ale（不需购买）
	var r1 = c.find_slam_recipe(["herb", "ale"])
	_ok(r1.get("product", "") == "herb_broth", "草药清汤可砸")
	_ok(r1.get("double", true) == false, "双料配方 double=false")
	# 顺序无关
	_ok(c.find_slam_recipe(["ale", "herb"]).get("product", "") == "herb_broth", "食材顺序无关")

	# requires_purchase 的 pot 配方 meat_stew（生肉+麦芽）：未解锁配方 → 不可砸
	_ok(c.find_slam_recipe(["meat_raw", "ale"]).is_empty(), "肉汤配方未购则不可砸")
	c.unlock_recipe("meat_stew")
	_ok(c.find_slam_recipe(["meat_raw", "ale"]).get("product", "") == "meat_stew", "购配方后肉汤可砸")

	# 单料 barrel 配方 ale_beer = ale：需解锁 barrel + 撞两个相同
	_ok(c.find_slam_recipe(["ale", "ale"]).is_empty(), "未解锁 barrel 时麦芽酒不可砸")
	c.unlock_slam("barrel")
	var r2 = c.find_slam_recipe(["ale", "ale"])
	_ok(r2.get("product", "") == "ale_beer", "麦芽酒可砸（同料）")
	_ok(r2.get("double", false) == true, "单料配方 double=true")
	# 两个不同材料但无双料配方 → 无匹配
	_ok(c.find_slam_recipe(["ale", "grape"]).is_empty(), "无对应双料配方应空")
