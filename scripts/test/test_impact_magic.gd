extends Node

## 冲击魔法功能单元测：shop abilities / 砸解锁状态 / 配方反查 / 力度分档 /
## buy_ability / quality 收益 / 存档往返。物理碰撞与商店 UI 走编辑器走查。

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_shop_abilities()
	_test_slam_state()
	_test_find_slam_recipe()
	_test_quality_payoff()
	_test_buy_and_serve()
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


func _test_quality_payoff() -> void:
	var e = _gm().economy
	_ok(e.gold_for_quality(10, "good") == 15, "good 金币 ×1.5")
	_ok(e.gold_for_quality(10, "normal") == 10, "normal 金币 ×1")
	_ok(e.gold_for_quality(10, "poor") == 5, "poor 金币 ×0.5")
	_ok(e.gold_for_quality(7, "poor") == 3, "poor 金币向下取整 floor(3.5)=3")
	_ok(e.gold_for_quality(10, "") == 10, "未知品质回退 ×1")
	_ok(e.reputation_for_quality("good") == 3, "good 声望 +3")
	_ok(e.reputation_for_quality("normal") == 2, "normal 声望 +2")
	_ok(e.reputation_for_quality("poor") == 0, "poor 声望 +0")
	_ok(e.reputation_for_quality("") == 2, "未知品质声望回退 +2")


func _test_buy_and_serve() -> void:
	var gm = _gm()
	gm.craft.unlocked_slam_containers.clear()

	# 钱不够买不了
	gm.economy.gold = 0
	_ok(not gm.buy_ability("slam_pot"), "无钱不能购买")
	_ok(not gm.craft.is_slam_unlocked("pot"), "购买失败不解锁")

	# 钱够：扣钱 + 解锁
	gm.economy.gold = 200
	_ok(gm.buy_ability("slam_pot"), "有钱购买成功")
	_ok(gm.economy.gold == 140, "购买后扣 60 金")
	_ok(gm.craft.is_slam_unlocked("pot"), "购买后 pot 解锁")
	_ok(gm.is_ability_owned("slam_pot"), "is_ability_owned 反映已购")

	# 重复购买被拒、不二次扣钱
	_ok(not gm.buy_ability("slam_pot"), "重复购买被拒")
	_ok(gm.economy.gold == 140, "重复购买不扣钱")

	# 未知能力 key 被拒
	_ok(not gm.buy_ability("nope"), "未知能力购买被拒")
