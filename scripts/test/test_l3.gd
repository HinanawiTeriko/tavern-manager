extends Node

## L3 单元测试桩。编辑器中对 scenes/test/test_l3.tscn 按 F6 运行，看 Output 面板：
## 全过 → "[TEST-L3] ALL PASS (N checks)"；失败 → assert 中断并报具体 msg。
## 验证后可保留作回归。

var _checks := 0

func _ready() -> void:
	_test_classify()
	print("[TEST-L3] ALL PASS (", _checks, " checks)")
	get_tree().quit()  # headless 下退出；编辑器 F6 下也会关闭播放窗口，Output 仍保留

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	assert(cond, "[TEST-L3] FAIL: " + msg)

func _test_classify() -> void:
	var cs := CraftStyleSystem.new()
	cs.load_data()
	_ok(cs.classify({"serve_drop_speed": 2000.0}) == "粗鲁", "高速应为粗鲁")
	_ok(cs.classify({"serve_drop_speed": 50.0}) == "温柔", "低速应为温柔")
	_ok(cs.classify({"serve_drop_speed": 500.0}) == "平静", "中速应为平静")
	_ok(cs.classify({}) == "平静", "空字典应为平静(安全默认)")
