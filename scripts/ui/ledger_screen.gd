class_name LedgerScreen
extends Node2D

var _title_label: Label
var _stats_list: VBoxContainer
var _fate_title: Label
var _fate_list: VBoxContainer
var _continue_btn: Button

func _ready() -> void:
	_title_label = $UI/TitleLabel
	_stats_list = $UI/StatsList
	_fate_title = $UI/FateTitle
	_fate_list = $UI/FateList
	_continue_btn = $UI/ContinueBtn

	_continue_btn.pressed.connect(_on_continue)

	var gm = get_node("/root/GameManager")
	var data = gm.current_ledger_data
	if data != null:
		_render(data)

func _render(data: Dictionary) -> void:
	_title_label.text = "第 %d 天 · 营业结算" % data["day"]
	ThemeColors.style_header(_title_label, 30)

	_add_stat_row("金币收入    +%d 金      累计: %d 金" % [data["gold_today"], data["gold_total"]])
	_add_stat_row("声望变化    +%d           累计: %d" % [data["rep_today"], data["rep_total"]])
	_add_stat_row("服务客人    %d 位" % data["guests_served"])
	_add_stat_row("成功订单    %d 单" % data["orders_success"])
	_add_stat_row("失败订单    %d 单" % data["orders_failed"])

	var fates: Array = data.get("npc_fates", [])
	if fates.size() > 0:
		_fate_title.text = "今日宿命"
		ThemeColors.style_header(_fate_title, 22)

		for fate in fates:
			var card = VBoxContainer.new()
			card.add_theme_constant_override("separation", 4)

			var name_label = Label.new()
			name_label.text = fate["npc_name"] + " · " + fate["npc_title"]
			name_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
			name_label.add_theme_font_size_override("font_size", 20)
			card.add_child(name_label)

			var fate_label = Label.new()
			fate_label.text = fate["fate_text"]
			fate_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
			fate_label.add_theme_font_size_override("font_size", 15)
			card.add_child(fate_label)

			_fate_list.add_child(card)
	else:
		_fate_title.visible = false

	ThemeColors.style_button(_continue_btn, 20)

func _add_stat_row(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	label.add_theme_font_size_override("font_size", 16)
	_stats_list.add_child(label)

func _on_continue() -> void:
	var gm = get_node("/root/GameManager")
	gm.day_cycle.next_phase()
