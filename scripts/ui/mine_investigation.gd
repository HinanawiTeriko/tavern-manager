class_name MineInvestigation
extends InvestigationScene

## 废弃矿道物理调查。继承 InvestigationScene 管道层；专属内容：
## 扒开塌方碎石 → 倾倒撕裂背包 → 捡起沾血委托书授予 bloodied_contract。

const RUBBLE_REVEAL_DIST := 120.0   # 碎石被拖离原位多远算「扒开」
const SPILL_TILT := 1.2             # 背包倾斜超过此弧度算「倾倒」
const LEAVE_BUTTON_SIZE := Vector2(200, 48)
const LEAVE_BUTTON_BOTTOM_RIGHT := Vector2(1240, 684)

var _rubble: MineItem = null
var _rubble_origin: Vector2 = Vector2.ZERO
var _backpack: MineItem = null
var _rubble_cleared: bool = false
var _backpack_spilled: bool = false
var _contract_taken: bool = false


func _setup_scene() -> void:
	_apply_mine_ui_style()
	_spawn_shallow_items()
	_spawn_deep_layer()


func _apply_mine_ui_style() -> void:
	ThemeColors.style_brush_label(_obs_label, 20, ThemeColors.TEXT_LIGHT)
	ThemeColors.style_brush_label(_hint_label, 16, ThemeColors.TEXT_SUBTITLE)
	_apply_label_outline(_obs_label)
	_apply_label_outline(_hint_label)
	ThemeColors.style_button(_leave_btn, 16)
	var font := ThemeColors.menu_font()
	if font != null:
		_leave_btn.add_theme_font_override("font", font)
	_leave_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_leave_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_leave_btn.offset_right = LEAVE_BUTTON_BOTTOM_RIGHT.x
	_leave_btn.offset_bottom = LEAVE_BUTTON_BOTTOM_RIGHT.y
	_leave_btn.offset_left = LEAVE_BUTTON_BOTTOM_RIGHT.x - LEAVE_BUTTON_SIZE.x
	_leave_btn.offset_top = LEAVE_BUTTON_BOTTOM_RIGHT.y - LEAVE_BUTTON_SIZE.y


func _apply_label_outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.018, 0.015, 0.9))


func _spawn_shallow_items() -> void:
	# 浅层散落物：捡起=一句观察，不授予。
	_spawn_item("broken_arrow", "observation", Vector2(120, 36), Color(0.55, 0.4, 0.25),
		"断箭", "箭杆从中折断——这里被打崩过。", Vector2(260, 470))
	_spawn_item("dented_shield", "observation", Vector2(96, 96), Color(0.45, 0.45, 0.5),
		"凹盾", "盾面一个深陷的凹痕，挡下过重重一击。", Vector2(380, 460))
	_spawn_item("lost_boot", "observation", Vector2(84, 56), Color(0.35, 0.25, 0.2),
		"破靴", "一只孤零零的靴子，主人走得很急——或者没走成。", Vector2(500, 475))


func _spawn_deep_layer() -> void:
	# 深层：血迹尽头的塌方碎石，底下压着撕裂的背包。
	# 背包先生成、冻结、隐藏；碎石盖在其上，扒开碎石才解封背包。
	_backpack = _spawn_item("torn_backpack", "backpack", Vector2(128, 112), Color(0.3, 0.22, 0.16),
		"撕裂的背包", "", Vector2(980, 470))
	_backpack.visible = false
	_backpack.freeze = true
	_rubble = _spawn_item("rubble", "rubble", Vector2(320, 216), Color(0.4, 0.38, 0.36),
		"塌方碎石", "", Vector2(980, 455))
	_rubble.freeze = true
	_rubble_origin = _rubble.global_position


func _can_pickup(item: MineItem) -> bool:
	# 背包还埋着，扒开碎石前抓不到
	return not (item.kind == "backpack" and not _rubble_cleared)


func _on_special_pickup(item: MineItem) -> bool:
	if item.kind == "contract":
		_take_contract()   # 捡起沾血纸 = 直接阅读，不进入拖拽
		item.queue_free()
		return true
	return false


func _priority_kinds() -> Array:
	return ["contract"]   # 优先返回沾血纸，避免被硬币/队牌挡住


func _investigation_physics(_delta: float) -> void:
	_check_rubble_cleared()
	_check_backpack_spill()


func _check_rubble_cleared() -> void:
	if _rubble_cleared or _rubble == null:
		return
	if _rubble.global_position.distance_to(_rubble_origin) >= RUBBLE_REVEAL_DIST:
		_rubble_cleared = true
		_backpack.visible = true
		_backpack.freeze = false
		_obs_label.text = "碎石底下露出一只撕裂的背包。"
		_hint_label.text = ""


func _check_backpack_spill() -> void:
	if _backpack_spilled or _backpack == null or not _rubble_cleared:
		return
	if _drag_ctrl.is_dragging() and _drag_ctrl.get_body() == _backpack:
		if absf(wrapf(_backpack.rotation, -PI, PI)) >= SPILL_TILT:
			_spill_backpack()


func _spill_backpack() -> void:
	_backpack_spilled = true
	var mouth := _backpack.global_position + Vector2(0, 40)
	# 洒落物 Y 向上偏移，避免生成时穿入地面 StaticBody2D（地面顶 y≈520）
	var coins := _spawn_item("coins", "plain", Vector2(64, 48), Color(0.85, 0.7, 0.25),
		"硬币", "", mouth + Vector2(-30, -15))
	coins.linear_velocity = Vector2(-90, -200)
	var token := _spawn_item("warhammer_token", "plain", Vector2(56, 56), Color(0.6, 0.15, 0.12),
		"血斧队牌", "", mouth + Vector2(10, -15))
	token.linear_velocity = Vector2(40, -220)
	var paper := _spawn_item("bloodied_paper", "contract", Vector2(72, 88), Color(0.7, 0.62, 0.5),
		"沾血的纸", "", mouth + Vector2(50, -30))
	paper.linear_velocity = Vector2(120, -250)
	_obs_label.text = "背包一倒，硬币、一枚血斧队牌、还有一张沾血的纸哗啦落了出来。"


func _take_contract() -> void:
	if _contract_taken:
		return
	_contract_taken = true
	_grant_document("bloodied_contract")
	_obs_label.text = "一张染血的委托书。已放入背包——回头可以翻看。"


func _has_deep_progress() -> bool:
	return _rubble_cleared or _contract_taken


func _leave_hint_text() -> String:
	return "血迹仍延向未翻处……总觉得还藏着什么。"
