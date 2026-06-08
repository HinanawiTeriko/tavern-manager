extends Node

## 回归：进入/离开废弃矿道时的相机让位与 DayMap UI 整层隐藏。
## 守护两个曾导致"矿道 UI 与 DayMap UI 并存、什么都点不到"的缺陷：
##   1. 进入时未禁用 DayMapCamera → 视口非恒等变换 → 物品命中测试全落空。
##   2. 只隐藏了枚举的几个节点，遗漏运行时建的采集/商店标签 → UI 并存截获输入。

var _checks := 0
var _failures := 0

func _ready() -> void:
	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().process_frame

	# 进入前：相机当前且 UI 可见
	_ok(view._camera.enabled, "进入前相机 enabled")
	_ok(view.get_node("UILayer").visible, "进入前 UILayer 可见")

	view._enter_investigation(view.MINE_SCENE)
	await get_tree().process_frame

	# 进入后：相机让出（恒等变换）+ 整层 DayMap UI 隐藏
	_ok(not view._camera.enabled, "进入矿道后相机 enabled=false（让出恒等变换）")
	_ok(not view._camera.active, "进入矿道后相机 active=false（停止平移缩放输入）")
	_ok(not view.get_node("UILayer").visible, "进入矿道后整层 UILayer 隐藏（含采集/商店标签）")
	_ok(not view.get_node("MapWorld").visible, "进入矿道后地图世界隐藏")
	_ok(view._investigation_scene != null, "调查场景已实例化")
	_ok(view._document_overlay.get_parent() == view._overlay_layer, "文档浮层移到高层 CanvasLayer")

	view._on_investigation_finished()
	await get_tree().process_frame

	# 离开后：UI 复现 + 浮层归位 $UILayer
	_ok(view.get_node("UILayer").visible, "离开后 UILayer 复现")
	_ok(view.get_node("MapWorld").visible, "离开后地图世界复现")
	_ok(view._investigation_scene == null, "调查场景已释放")
	_ok(view._document_overlay.get_parent() == view.get_node("UILayer"), "文档浮层归位 $UILayer（屏幕空间）")

	view.queue_free()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MINE-ENTER] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-MINE-ENTER] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MINE-ENTER] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
