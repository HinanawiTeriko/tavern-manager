class_name TobyLodgingInvestigation
extends InvestigationScene

## 托比落脚处物理调查。专属机制：拼合撕碎的委托书——把散落的碎片拖到一起，
## 全部靠拢到拼合点即授予 toby_contract。与矿道（扒碎石/倾倒）区分。
## 灾前·私密·热：你在翻一个还没上路的绝望孩子的窝。

const ASSEMBLE_POINT := Vector2(640, 490)   # 拼合点（窝里地面中央的矮桌）
const ASSEMBLE_RADIUS := 80.0               # 碎片全部进入此半径即拼合
const LEAVE_BUTTON_NORMAL := "res://assets/ui/generated/investigation/toby_lodging/ui/leave_button_normal.png"
const LEAVE_BUTTON_HOVER := "res://assets/ui/generated/investigation/toby_lodging/ui/leave_button_hover.png"
const LEAVE_BUTTON_PRESSED := "res://assets/ui/generated/investigation/toby_lodging/ui/leave_button_pressed.png"
const LEAVE_BUTTON_SIZE := Vector2(280, 100)
const LEAVE_BUTTON_BOTTOM_RIGHT := Vector2(1240, 684)

var _fragments: Array[MineItem] = []
var _assembled: bool = false


func _setup_scene() -> void:
	_apply_toby_lodging_ui_style()
	_spawn_shallow_items()
	_spawn_fragments()


func _apply_toby_lodging_ui_style() -> void:
	ThemeColors.style_brush_label(_obs_label, 20, ThemeColors.TEXT_LIGHT)
	ThemeColors.style_brush_label(_hint_label, 16, ThemeColors.TEXT_SUBTITLE)
	_apply_label_outline(_obs_label)
	_apply_label_outline(_hint_label)
	_apply_leave_button_style()


func _apply_leave_button_style() -> void:
	var font := ThemeColors.menu_font()
	if font != null:
		_leave_btn.add_theme_font_override("font", font)
	_leave_btn.add_theme_font_size_override("font_size", 18)
	_leave_btn.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_leave_btn.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	_leave_btn.add_theme_color_override("font_pressed_color", ThemeColors.AMBER_BRIGHT)
	_leave_btn.add_theme_stylebox_override("normal", _leave_button_stylebox(LEAVE_BUTTON_NORMAL))
	_leave_btn.add_theme_stylebox_override("hover", _leave_button_stylebox(LEAVE_BUTTON_HOVER))
	_leave_btn.add_theme_stylebox_override("pressed", _leave_button_stylebox(LEAVE_BUTTON_PRESSED))
	_leave_btn.add_theme_stylebox_override("disabled", _leave_button_stylebox(LEAVE_BUTTON_NORMAL))
	_leave_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_leave_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_leave_btn.offset_right = LEAVE_BUTTON_BOTTOM_RIGHT.x
	_leave_btn.offset_bottom = LEAVE_BUTTON_BOTTOM_RIGHT.y
	_leave_btn.offset_left = LEAVE_BUTTON_BOTTOM_RIGHT.x - LEAVE_BUTTON_SIZE.x
	_leave_btn.offset_top = LEAVE_BUTTON_BOTTOM_RIGHT.y - LEAVE_BUTTON_SIZE.y


func _leave_button_stylebox(path: String) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		style = StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, 58.0)
	style.set_content_margin(SIDE_RIGHT, 58.0)
	style.set_content_margin(SIDE_TOP, 30.0)
	style.set_content_margin(SIDE_BOTTOM, 30.0)
	return style


func _apply_label_outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.018, 0.015, 0.9))


func _spawn_shallow_items() -> void:
	# 浅层肖像物：捡起=一句观察，不授予、不参与拼合。堆出「这孩子怎么活」。
	_spawn_item("oil_lamp", "observation", Vector2(72, 96), Color(0.55, 0.5, 0.3),
		"将灭的油灯", "灯油只剩一指——他舍不得点。", Vector2(300, 470))
	_spawn_item("hard_bread", "observation", Vector2(80, 48), Color(0.5, 0.42, 0.28),
		"干硬的面包", "硬得硌牙，是他攒着的几天口粮。", Vector2(440, 478))
	_spawn_item("oversized_coat", "observation", Vector2(176, 112), Color(0.3, 0.3, 0.38),
		"不合身的旧外套", "袖子长出一截——别人穿剩的。", Vector2(560, 468))


func _spawn_fragments() -> void:
	# 撕碎的委托书：三片，散在窝里不同角落。拖到拼合点靠拢即成。
	var specs := [
		["contract_fragment_a", "褥子边的碎片", Vector2(220, 460), Vector2(68, 52)],
		["contract_fragment_b", "灯影里的碎片", Vector2(700, 462), Vector2(64, 56)],
		["contract_fragment_c", "扣在碗底的碎片", Vector2(940, 470), Vector2(76, 48)],
	]
	for s in specs:
		var frag := _spawn_item(String(s[0]), "fragment", s[3] as Vector2,
			Color(0.62, 0.54, 0.34), String(s[1]), "撕开的委托书一角——他动摇过，撕了，却没扔。", s[2] as Vector2)
		_fragments.append(frag)


# ============================================================
#  专属机制：拼合
# ============================================================

func _priority_kinds() -> Array:
	return ["fragment"]   # 碎片优先于浅层物被抓起


func _investigation_physics(_delta: float) -> void:
	_check_assembly()


func _check_assembly() -> void:
	if _assembled:
		return
	if _drag_ctrl.is_dragging():
		return   # 拖拽中不判定，待松手安置
	for frag in _fragments:
		if not is_instance_valid(frag):
			return
		if frag.global_position.distance_to(ASSEMBLE_POINT) > ASSEMBLE_RADIUS:
			return
	_complete_assembly()


func _complete_assembly() -> void:
	_assembled = true
	for frag in _fragments:
		if is_instance_valid(frag):
			frag.queue_free()
	_fragments.clear()
	_grant_document("toby_contract")
	_obs_label.text = "碎片拼回原样——托比为钱接下的那份委托，赫然在目。已放入背包。"


# ============================================================
#  离场软提示：没拼全就走 → 先耳语
# ============================================================

func _has_deep_progress() -> bool:
	return _assembled


func _leave_hint_text() -> String:
	return "几片撕碎的纸还散在角落……拼起来，或许能看清他要去赴的是什么。"
