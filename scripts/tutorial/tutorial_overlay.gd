class_name TutorialOverlay
extends CanvasLayer

var _highlight_panels: Array = [null, null, null, null]
var _description_panel: Panel
var _description_label: RichTextLabel
var _title_label: Label
var _next_btn: Button
var _skip_btn: Button

var _tutorial_mgr
var _has_next: bool = false


func _ready() -> void:
	_tutorial_mgr = get_node_or_null("/root/TutorialManager")
	layer = 100
	_create_ui()
	visible = false


func _create_ui() -> void:
	# 4遮罩面板（盖住高亮区域外的一切，阻挡点击）
	for i in range(4):
		var panel = ColorRect.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(panel)
		_highlight_panels[i] = panel

	# 高亮区域内点击拦截器（半透明，阻挡高亮区域内的点击）
	var highlight_click_catcher = ColorRect.new()
	highlight_click_catcher.name = "HighlightClickCatcher"
	highlight_click_catcher.color = Color(0, 0, 0, 0.05)
	highlight_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(highlight_click_catcher)

	# 高亮边框指示器
	var border_top = ColorRect.new()
	border_top.color = Color(1.0, 0.741, 0.498, 0.9)
	border_top.name = "BorderTop"
	add_child(border_top)

	var border_bot = ColorRect.new()
	border_bot.color = Color(1.0, 0.741, 0.498, 0.9)
	border_bot.name = "BorderBot"
	add_child(border_bot)

	var border_left = ColorRect.new()
	border_left.color = Color(1.0, 0.741, 0.498, 0.9)
	border_left.name = "BorderLeft"
	add_child(border_left)

	var border_right = ColorRect.new()
	border_right.color = Color(1.0, 0.741, 0.498, 0.9)
	border_right.name = "BorderRight"
	add_child(border_right)

	# 标题
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.741, 0.498))
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title_label)

	# 描述面板
	_description_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.06, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1.0, 0.741, 0.498, 0.5)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_description_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_description_panel)

	# 描述文字
	_description_label = RichTextLabel.new()
	_description_label.bbcode_enabled = true
	_description_label.add_theme_color_override("default_color", Color(0.918, 0.882, 0.867))
	_description_label.add_theme_font_size_override("normal_font_size", 15)
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_panel.add_child(_description_label)

	# "下一步"按钮
	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(150, 44)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(1.0, 0.741, 0.498)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 4
	btn_normal.border_color = Color(0, 0, 0, 0.35)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	_next_btn.add_theme_stylebox_override("normal", btn_normal)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 0.584, 0.0)
	btn_hover.border_width_left = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_bottom = 4
	btn_hover.border_color = Color(0, 0, 0, 0.4)
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	_next_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.8, 0.45, 0.0)
	btn_pressed.border_width_left = 2
	btn_pressed.border_width_top = 4
	btn_pressed.border_width_right = 2
	btn_pressed.border_width_bottom = 2
	btn_pressed.border_color = Color(0, 0, 0, 0.4)
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6
	_next_btn.add_theme_stylebox_override("pressed", btn_pressed)
	_next_btn.add_theme_color_override("font_color", Color(0.294, 0.157, 0.0))
	_next_btn.add_theme_font_size_override("font_size", 16)
	_next_btn.pressed.connect(_on_next)
	add_child(_next_btn)

	# "跳过教程"按钮
	_skip_btn = Button.new()
	_skip_btn.text = "跳过教程"
	_skip_btn.custom_minimum_size = Vector2(100, 34)
	var skip_normal = StyleBoxFlat.new()
	skip_normal.bg_color = Color(0.25, 0.25, 0.25, 0.65)
	skip_normal.corner_radius_top_left = 4
	skip_normal.corner_radius_top_right = 4
	skip_normal.corner_radius_bottom_left = 4
	skip_normal.corner_radius_bottom_right = 4
	skip_normal.border_width_left = 1
	skip_normal.border_width_right = 1
	skip_normal.border_width_top = 1
	skip_normal.border_width_bottom = 1
	skip_normal.border_color = Color(0.45, 0.45, 0.45, 0.5)
	_skip_btn.add_theme_stylebox_override("normal", skip_normal)
	var skip_hover = StyleBoxFlat.new()
	skip_hover.bg_color = Color(0.35, 0.35, 0.35, 0.8)
	skip_hover.corner_radius_top_left = 4
	skip_hover.corner_radius_top_right = 4
	skip_hover.corner_radius_bottom_left = 4
	skip_hover.corner_radius_bottom_right = 4
	skip_hover.border_width_left = 1
	skip_hover.border_width_right = 1
	skip_hover.border_width_top = 1
	skip_hover.border_width_bottom = 1
	skip_hover.border_color = Color(0.55, 0.55, 0.55, 0.5)
	_skip_btn.add_theme_stylebox_override("hover", skip_hover)
	_skip_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_skip_btn.add_theme_font_size_override("font_size", 12)
	_skip_btn.pressed.connect(_on_skip)
	add_child(_skip_btn)


func show_step(step: Dictionary, highlight_rect: Array, _has_prev: bool, has_next: bool) -> void:
	_has_next = has_next
	var shadow = Color(0.0, 0.0, 0.0, 0.73)
	var border_w = 2.0
	var x: float = highlight_rect[0]
	var y: float = highlight_rect[1]
	var w: float = highlight_rect[2]
	var h: float = highlight_rect[3]

	var vs = get_viewport().get_visible_rect().size

	# 上部遮罩
	_highlight_panels[0].position = Vector2(0, 0)
	_highlight_panels[0].size = Vector2(vs.x, max(y - border_w, 0))
	_highlight_panels[0].color = shadow

	# 下部遮罩
	_highlight_panels[1].position = Vector2(0, y + h + border_w)
	_highlight_panels[1].size = Vector2(vs.x, max(vs.y - (y + h + border_w), 0))
	_highlight_panels[1].color = shadow

	# 左部遮罩
	_highlight_panels[2].position = Vector2(0, max(y - border_w, 0))
	_highlight_panels[2].size = Vector2(max(x - border_w, 0), min(h + border_w * 2, vs.y))
	_highlight_panels[2].color = shadow

	# 右部遮罩
	_highlight_panels[3].position = Vector2(x + w + border_w, max(y - border_w, 0))
	_highlight_panels[3].size = Vector2(max(vs.x - (x + w + border_w), 0), min(h + border_w * 2, vs.y))
	_highlight_panels[3].color = shadow

	# 高亮边框
	var bt = get_node_or_null("BorderTop")
	var bb = get_node_or_null("BorderBot")
	var bl = get_node_or_null("BorderLeft")
	var br = get_node_or_null("BorderRight")
	if bt != null:
		bt.position = Vector2(x - border_w, y - border_w)
		bt.size = Vector2(w + border_w * 2, border_w)
	if bb != null:
		bb.position = Vector2(x - border_w, y + h)
		bb.size = Vector2(w + border_w * 2, border_w)
	if bl != null:
		bl.position = Vector2(x - border_w, y - border_w)
		bl.size = Vector2(border_w, h + border_w * 2)
	if br != null:
		br.position = Vector2(x + w, y - border_w)
		br.size = Vector2(border_w, h + border_w * 2)

	# 高亮区域内点击拦截器
	var catcher = get_node_or_null("HighlightClickCatcher")
	if catcher != null:
		catcher.position = Vector2(x, y)
		catcher.size = Vector2(w, h)

	# 标题与描述面板位置（限幅防止超出屏幕）
	var desc_x: float = step.get("desc_pos_x", 0.5)
	var desc_y: float = step.get("desc_pos_y", 0.75)
	var desc_w: float = step.get("desc_width", 420)
	var desc_h: float = step.get("desc_height", 140)

	var panel_x = vs.x * desc_x - desc_w / 2.0
	var panel_y = vs.y * desc_y + 48
	var title_y = vs.y * desc_y + 12
	var btn_next_y = vs.y * desc_y + desc_h + 56

	# 限幅：面板不能超出屏幕底部（为按钮留出空间）
	var panel_bottom = panel_y + desc_h
	var btn_margin = 60  # 按钮 + 间距
	if panel_bottom + btn_margin > vs.y:
		var overflow = panel_bottom + btn_margin - vs.y
		panel_y = max(4, panel_y - overflow)
		title_y = max(4, title_y - overflow)
		btn_next_y = panel_y + desc_h + 8

	# 限幅 x 方向
	panel_x = clamp(panel_x, 10, vs.x - desc_w - 10)

	_title_label.position = Vector2(panel_x, title_y)
	_title_label.size = Vector2(desc_w, 32)
	_title_label.text = step.get("title", "")

	_description_panel.position = Vector2(panel_x, panel_y)
	_description_panel.size = Vector2(desc_w, desc_h)

	_description_label.position = Vector2(16, 14)
	_description_label.size = Vector2(desc_w - 32, desc_h - 28)
	_description_label.text = "[font_size=15]" + step.get("description", "") + "[/font_size]"

	# 按钮位置
	_skip_btn.position = Vector2(vs.x - 120, 16)
	_next_btn.position = Vector2(vs.x * desc_x - 75, btn_next_y)
	_next_btn.text = "完成 ✓" if not has_next else "下一步 ▶"

	visible = true


func hide_overlay() -> void:
	visible = false


func _on_next() -> void:
	if _tutorial_mgr != null:
		_tutorial_mgr.next_step()


func _on_skip() -> void:
	if _tutorial_mgr != null:
		_tutorial_mgr.skip_tutorial()
