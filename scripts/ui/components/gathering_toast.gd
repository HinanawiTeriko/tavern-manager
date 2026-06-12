class_name GatheringToast
extends Panel

## 顶部短暂提示：显示采集获得的物品种类×数量，自动消失，连续采集覆盖旧提示。

const TOAST_WIDTH := 420.0
const TOAST_HEIGHT := 44.0
const DISPLAY_DURATION := 3.0
const FADE_DURATION := 0.4

var _label: Label
var _timer: Timer
var _current_tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	# 面板样式
	add_theme_stylebox_override("panel", _toast_style())

	_label = Label.new()
	_label.name = "Content"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_label.add_theme_font_size_override("font_size", 15)
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 1.0
	add_child(_label)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

	visible = false


## 显示采集提示。rewards: {item_key: count}，message: 结果文案（无奖励或失败时显示）。
func show_rewards(rewards: Dictionary, message: String) -> void:
	# 覆盖旧提示：杀死旧动画、重置计时器
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
	_timer.stop()
	modulate.a = 1.0

	# 构建文字
	var parts: Array = []
	for key in rewards:
		var count: int = rewards[key]
		var item_name: String = _resolve_name(key)
		parts.append("%s×%d" % [item_name, count])

	if parts.is_empty():
		_label.text = message
	else:
		_label.text = "采集获得：" + "、".join(parts)

	visible = true
	_timer.start(DISPLAY_DURATION)


func _on_timeout() -> void:
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_current_tween.tween_callback(func():
		if is_instance_valid(self):
			visible = false
	)


## 通过 GameManager 查物品中文名
func _resolve_name(key: String) -> String:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.craft != null:
		var item: Dictionary = gm.craft.get_item(key)
		if not item.is_empty():
			return item.get("name", key)
	return key


static func _toast_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.90)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(ThemeColors.AMBER_PRIMARY, 0.30)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb
