class_name EndingScreen
extends Node2D

const SETTLEMENT_BACKDROP := "res://assets/textures/ui/night_settlement/night_settlement_backdrop.png"
const FINAL_PANEL_ART := "res://assets/textures/ui/night_settlement/night_settlement_panel_fates.png"
const PIXEL_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const CHARACTER_ORDER := ["ryan", "mira", "toby", "evelyn"]
const NPC_DISPLAY_NAMES := {
	"ryan": "莱恩",
	"mira": "米拉",
	"toby": "托比",
	"evelyn": "伊芙琳",
}
const FATE_COMMENTS := {
	"ryan": {
		"uninformed_fallen": "没能看见陷阱，北矿道只留下未读完的委托。",
		"drugged_survivor": "活了下来，但这盏灯是替他做出的选择。",
		"informed_fallen": "知道了真相，也把最后一步留给了自己。",
		"alternative_survivor": "绕开北矿道，背着更慢却活着的前路离开。",
	},
	"mira": {
		"another_light_out": "照常上路，身后的灯又灭了一盏。",
		"closed_the_door": "没有回头，但有人替托比关上了危险的门。",
		"never_turned_back": "听见了真相，却还是让账页替她关门。",
		"she_finally_stopped": "终于停下脚步，把那句旧话从托比身上取了下来。",
	},
	"toby": {
		"saved": "留在了灯下，没有把自己交给黑齿矿脉。",
		"lost": "独自走进黑齿矿脉，账页没能把他带回来。",
	},
	"evelyn": {
		"sealed_account": "重新封账，事故照旧被写成已结。",
		"amended_account": "改了账面，但公会仍握着最后的栏位。",
		"public_account": "没能合上灰账，真相第一次被摆到灯下。",
	},
}
const FATE_QUALITY := {
	"uninformed_fallen": -2,
	"drugged_survivor": 1,
	"informed_fallen": -1,
	"alternative_survivor": 2,
	"another_light_out": -2,
	"closed_the_door": 1,
	"never_turned_back": -1,
	"she_finally_stopped": 2,
	"saved": 1,
	"lost": -1,
	"sealed_account": -2,
	"amended_account": 0,
	"public_account": 2,
}

var _npc_endings_list: VBoxContainer
var _gold_label: Label
var _rep_label: Label
var _orders_label: Label
var _title_label: Label
var _closing_label: Label
var _content: VBoxContainer

func _ready() -> void:
	_content = $Content
	_npc_endings_list = $Content/NPCEndingsList
	_gold_label = $Content/Stats/GoldLabel
	_rep_label = $Content/Stats/RepLabel
	_orders_label = $Content/Stats/OrdersLabel
	_title_label = $Content/TitleLabel
	_closing_label = $Content/ClosingLabel

	_apply_runtime_art()
	_style_static_ui()

	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.register_view(self)


func show_endings(gold: int, rep: int, orders_success: int, npc_endings: Dictionary) -> void:
	_gold_label.text = "最终金币：" + str(gold)
	_rep_label.text = "最终声望：" + str(rep)
	_orders_label.text = "成功订单：" + str(orders_success)
	var fate_score := _fate_score(npc_endings)
	var verdict_score := fate_score + _economy_score(gold, rep, orders_success)
	_title_label.text = _title_for_score(verdict_score)
	_closing_label.text = _closing_for_score(verdict_score) + " " + _economy_line(gold, rep, orders_success)

	_clear_container(_npc_endings_list)
	_npc_endings_list.add_theme_constant_override("separation", 5)

	var divider = ColorRect.new()
	divider.color = Color(ThemeColors.AMBER_PRIMARY, 0.3)
	divider.custom_minimum_size = Vector2(0, 2)
	_npc_endings_list.add_child(divider)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_npc_endings_list.add_child(spacer)

	for npc_id in CHARACTER_ORDER:
		_add_character_row(String(npc_id), String(npc_endings.get(npc_id, "")))


func _style_static_ui() -> void:
	_content.add_theme_constant_override("separation", 8)
	_title_label.custom_minimum_size = Vector2(0, 52)
	($Content/Stats as HBoxContainer).custom_minimum_size = Vector2(0, 36)
	($Content/Stats as HBoxContainer).add_theme_constant_override("separation", 10)
	_closing_label.custom_minimum_size = Vector2(0, 70)
	_npc_endings_list.custom_minimum_size = Vector2(0, 216)

	_style_label(_title_label, 30, ThemeColors.AMBER_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, 3)
	_style_label(_gold_label, 16, ThemeColors.AMBER_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, 1)
	_style_label(_rep_label, 16, ThemeColors.TEXT_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, 1)
	_style_label(_orders_label, 16, ThemeColors.TEXT_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, 1)
	_style_label(_closing_label, 15, ThemeColors.TEXT_SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER, 1)
	_closing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var quit_btn := $Content/QuitBtn as Button
	var restart_btn := $Content/RestartBtn as Button
	quit_btn.custom_minimum_size = Vector2(200, 36)
	restart_btn.custom_minimum_size = Vector2(200, 36)
	quit_btn.top_level = true
	restart_btn.top_level = true
	ThemeColors.style_brush_button(quit_btn, 15)
	ThemeColors.style_brush_button(restart_btn, 15)
	quit_btn.text = "退出游戏"
	restart_btn.text = "返回标题"
	_position_action_buttons()
	quit_btn.pressed.connect(func(): get_tree().quit())
	restart_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn"))


func _apply_runtime_art() -> void:
	var backdrop := get_node_or_null("ArtLayer/SettlementBackdrop") as TextureRect
	if backdrop != null:
		_apply_texture(backdrop, SETTLEMENT_BACKDROP)
	var panel := get_node_or_null("ArtLayer/FinalPanelArt") as TextureRect
	if panel != null:
		_apply_texture(panel, FINAL_PANEL_ART)
	var bg_node := get_node_or_null("Background") as Sprite2D
	if bg_node != null:
		var bg_tex := TextureManager.try_load(SETTLEMENT_BACKDROP)
		if bg_tex != null:
			bg_node.texture = bg_tex
			bg_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _apply_texture(rect: TextureRect, path: String) -> void:
	rect.texture = TextureManager.try_load(path)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _add_character_row(npc_id: String, ending_key: String) -> void:
	var row := HBoxContainer.new()
	row.name = "%sVerdictRow" % npc_id.capitalize()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 44)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = String(NPC_DISPLAY_NAMES.get(npc_id, npc_id))
	name_label.custom_minimum_size = Vector2(92, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(name_label, 16, ThemeColors.AMBER_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, 1)
	row.add_child(name_label)

	var comment_label := Label.new()
	comment_label.name = "Comment"
	comment_label.text = _comment_for(npc_id, ending_key)
	comment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(comment_label, 14, ThemeColors.TEXT_LIGHT, HORIZONTAL_ALIGNMENT_LEFT, 1)
	row.add_child(comment_label)

	_npc_endings_list.add_child(row)


func _position_action_buttons() -> void:
	var quit_btn := $Content/QuitBtn as Button
	var restart_btn := $Content/RestartBtn as Button
	quit_btn.size = Vector2(200, 36)
	restart_btn.size = Vector2(200, 36)
	quit_btn.global_position = Vector2(424, 672)
	restart_btn.global_position = Vector2(656, 672)


func _comment_for(npc_id: String, ending_key: String) -> String:
	var comments: Dictionary = FATE_COMMENTS.get(npc_id, {})
	if ending_key != "" and comments.has(ending_key):
		return String(comments[ending_key])
	return "这条命运线留下了无法辨认的记录。"


func _fate_score(npc_endings: Dictionary) -> int:
	var total := 0
	for npc_id in CHARACTER_ORDER:
		var ending_key := String(npc_endings.get(npc_id, ""))
		total += int(FATE_QUALITY.get(ending_key, 0))
	return total


func _economy_score(gold: int, rep: int, orders_success: int) -> int:
	var score := 0
	if gold >= 120:
		score += 1
	if rep >= 10:
		score += 1
	if orders_success >= 40:
		score += 1
	return score


func _title_for_score(score: int) -> String:
	if score >= 6:
		return "灯还亮着"
	if score >= 2:
		return "打烊之后"
	return "合上的账页"


func _closing_for_score(score: int) -> String:
	if score >= 6:
		return "这二十一天的账本并不干净，却留下了足够多活人和证词。酒馆打烊时，灯仍为他们亮着。"
	if score >= 2:
		return "酒馆撑到了最后，几页账被改写，几页仍压在灰尘里。打烊之后，剩下的人还要继续清点。"
	return "账本合上时，太多名字只剩尾注。酒馆守住了夜晚，却没能守住所有人。"


func _economy_line(gold: int, rep: int, orders_success: int) -> String:
	if rep >= 10 and orders_success >= 40:
		return "你的经营让这间酒馆有了被信任的重量。"
	if gold >= 120:
		return "柜台还有余钱，足够支撑下一盏灯。"
	return "酒馆的账并不宽裕，但至少撑完了最后一夜。"


func _style_label(label: Label, font_size: int, color: Color, alignment: HorizontalAlignment, outline_size: int = 0) -> void:
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	if outline_size > 0:
		label.add_theme_constant_override("outline_size", outline_size)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.62))


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
