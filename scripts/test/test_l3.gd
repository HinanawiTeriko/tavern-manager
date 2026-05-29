extends Node

## L3 单元测试桩。编辑器中对 scenes/test/test_l3.tscn 按 F6 运行，看 Output 面板：
## 全过 → "[TEST-L3] ALL PASS (N checks)"；失败 → assert 中断并报具体 msg。
## 验证后可保留作回归。

var _checks := 0

func _ready() -> void:
	_test_classify()
	_test_npc_parse()
	_test_valve()
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

func _test_npc_parse() -> void:
	var nm := NarrativeManager.new()
	nm.load_npc_data()
	var mira: NpcData = null
	for n in nm.all_npcs:
		if n.id == "mira":
			mira = n
	_ok(mira != null, "应解析到 mira")
	_ok(mira.preferred_styles.has("温柔"), "mira preferred 含 温柔")
	_ok(mira.disliked_styles.has("粗鲁"), "mira disliked 含 粗鲁")

func _test_valve() -> void:
	var nm := NarrativeManager.new()
	nm.load_npc_data()
	var base := nm.get_affection("mira")
	# preferred + 有故事 → story_told, +2
	var r1 := nm.resolve_serve_style("mira", "day4_road_story", "温柔")
	_ok(r1["story_told"] == true, "温柔+memory → story_told")
	_ok(r1["affection_delta"] == 2, "温柔 → +2")
	# disliked → 不讲, -2
	nm.set_affection("mira", base)
	var r2 := nm.resolve_serve_style("mira", "day4_road_story", "粗鲁")
	_ok(r2["story_told"] == false, "粗鲁 → 不讲")
	_ok(r2["affection_delta"] == -2, "粗鲁 → -2")
	# 平静 → 0, 不讲
	nm.set_affection("mira", base)
	var r3 := nm.resolve_serve_style("mira", "day4_road_story", "平静")
	_ok(r3["story_told"] == false, "平静 → 不讲")
	_ok(r3["affection_delta"] == 0, "平静 → 0")
	# preferred 但无 memory(L2 缺) → 不讲
	nm.set_affection("mira", base)
	var r4 := nm.resolve_serve_style("mira", "", "温柔")
	_ok(r4["story_told"] == false, "无 memory → 即便温柔也不讲(L2 阀门)")
