extends Node

## BrewShakeMeter 单元测试。headless 跑或编辑器 F6 跑 scenes/test/test_barrel_shake.tscn。
## 全过 → "[TEST-SHAKE] ALL PASS (N checks)"；失败 → assert 中断报具体 msg。

var _checks := 0

func _ready() -> void:
	_test_count_reversals()
	_test_below_min_speed_ignored()
	_test_enough()
	_test_quality_tiers()
	print("[TEST-SHAKE] ALL PASS (", _checks, " checks)")
	get_tree().quit()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	assert(cond, "[TEST-SHAKE] FAIL: " + msg)

func _meter() -> BrewShakeMeter:
	var m := BrewShakeMeter.new()
	m.load_thresholds({"min_speed": 150.0, "min_count": 4, "good_count": 10})
	return m

func _test_count_reversals() -> void:
	var m := _meter()
	# 每次方向翻转(且够速)记 1 次；右-左-右-左 = 3 次翻转
	m.add_sample(300.0)
	m.add_sample(-300.0)   # 1
	m.add_sample(300.0)    # 2
	m.add_sample(-300.0)   # 3
	_ok(m.shake_count == 3, "右左右左应为 3 次翻转，实得 %d" % m.shake_count)

func _test_below_min_speed_ignored() -> void:
	var m := _meter()
	m.add_sample(300.0)
	m.add_sample(-50.0)    # 低于 min_speed，不计、不更新方向
	m.add_sample(-300.0)   # 相对上一个有效方向(+)翻转 → 1
	_ok(m.shake_count == 1, "低速样本应被忽略，实得 %d" % m.shake_count)

func _test_enough() -> void:
	var m := _meter()
	_ok(not m.has_enough(), "初始不应够")
	var dir := 1.0
	# 第一个样本只定方向，之后每个交替样本算 1 次翻转 → 5 个样本 = 4 次翻转
	for i in range(5):
		dir = -dir
		m.add_sample(300.0 * dir)
	_ok(m.shake_count >= 4, "5 个交替样本后 count>=4，实得 %d" % m.shake_count)
	_ok(m.has_enough(), "count>=min_count 应够")

func _test_quality_tiers() -> void:
	var m := _meter()
	m.shake_count = 5
	_ok(m.quality_tier() == "normal", "5<good_count 应为 normal")
	m.shake_count = 12
	_ok(m.quality_tier() == "good", "12>=good_count 应为 good")
	m.reset()
	_ok(m.shake_count == 0, "reset 后清零")
