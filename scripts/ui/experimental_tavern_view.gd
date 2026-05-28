class_name ExperimentalTavernView
extends Node2D

## 实验性酒馆 — 4层视觉深度 + 桌面自由合成 + 相对坐标拖拽

var _desktop: DesktopWorkspace
var _shortcut_slots: Array[Control] = []
var _shortcut_labels: Array[Label] = []
var bar_materials: Array[String] = []
var bar_counts: Array[int] = []
var _gm: Node

var _operation_btns_container: HBoxContainer
var _mix_btn: Button
var _clear_desktop_btn: Button

var _dragging: bool = false
var _drag_material: String = ""
var _drag_offset: Vector2       ## 拖拽物相对鼠标的偏移（点击点→物品左上角）
var _drag_panel: ColorRect

var _customer_sprite: ColorRect
var _customer_name: Label
var _order_label: Label

var _gold_label: Label
var _rep_label: Label
var _day_label: Label


func _ready() -> void:
	_gm = get_node("/root/GameManager")

	_desktop = $DesktopArea/DesktopWorkspace
	_desktop.mix_available.connect(_on_mix_available)

	_operation_btns_container = $DesktopArea/OperationButtons
	_mix_btn = $DesktopArea/MixBtn
	_clear_desktop_btn = $DesktopArea/ClearDesktopBtn

	_gold_label = $UI/TopPanel/GoldLabel
	_rep_label = $UI/TopPanel/ReputationLabel
	_day_label = $UI/TopPanel/DayLabel

	_customer_sprite = $CustomerArea/CustomerSprite
	_customer_name = $CustomerArea/CustomerName
	_order_label = $CustomerArea/OrderLabel

	_init_shortcut_bar()
	_init_drag_panel()
	_sync_shortcut_from_inventory()

	_gm.inventory_changed.connect(_sync_shortcut_from_inventory)
	_mix_btn.pressed.connect(_on_mix_pressed)
	_clear_desktop_btn.pressed.connect(_on_clear_desktop)

	_apply_theme()
	_refresh_top_bar()


func _apply_theme() -> void:
	ThemeColors.style_button(_mix_btn, 14)
	ThemeColors.style_small_button(_clear_desktop_btn, 12)
	_mix_btn.visible = false

	_customer_name.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_customer_name.add_theme_font_size_override("font_size", 20)
	_order_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_order_label.add_theme_font_size_override("font_size", 15)

	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 16)
	_rep_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_rep_label.add_theme_font_size_override("font_size", 16)
	_day_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_day_label.add_theme_font_size_override("font_size", 15)

	for i in range(10):
		_shortcut_slots[i].color = Color(0.08, 0.06, 0.04)


func _refresh_top_bar() -> void:
	if _gm == null:
		return
	_gold_label.text = "金币：" + str(_gm.economy.gold)
	_rep_label.text = "声望：" + str(_gm.economy.reputation)
	_day_label.text = "第%d/%d天" % [_gm.economy.current_day, 30]


# ============================================================
#  快捷栏
# ============================================================

func _init_shortcut_bar() -> void:
	bar_materials.resize(10)
	bar_counts.resize(10)
	_shortcut_slots.resize(10)
	_shortcut_labels.resize(10)

	var bar = $ShortcutBar
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(10):
		_shortcut_slots[i] = bar.get_node("Slot%d" % i)
		_shortcut_slots[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shortcut_labels[i] = bar.get_node("Slot%d/Label" % i)
		_shortcut_labels[i].mouse_filter = Control.MOUSE_FILTER_IGNORE


func _sync_shortcut_from_inventory() -> void:
	if _gm == null:
		return
	var inv: Dictionary = _gm.inventory
	for i in range(10):
		if bar_materials[i] != "" and inv.get(bar_materials[i], 0) <= 0:
			bar_materials[i] = ""
			bar_counts[i] = 0
		elif bar_materials[i] != "":
			bar_counts[i] = inv[bar_materials[i]]
	for key in inv:
		var count: int = inv[key]
		if count <= 0:
			continue
		var already = false
		for i in range(10):
			if bar_materials[i] == key:
				already = true
				break
		if already:
			continue
		for i in range(10):
			if bar_materials[i] == "":
				bar_materials[i] = key
				bar_counts[i] = count
				break
	for i in range(10):
		_refresh_shortcut(i)


func _refresh_shortcut(i: int) -> void:
	if bar_materials[i] == "":
		_shortcut_slots[i].color = Color(0.1, 0.08, 0.06)
		_shortcut_labels[i].text = ""
	else:
		var item = _gm.craft.get_item(bar_materials[i])
		if not item.is_empty():
			var col_arr = item.get("color", [])
			if col_arr is Array and col_arr.size() >= 3:
				_shortcut_slots[i].color = Color(col_arr[0], col_arr[1], col_arr[2])
			else:
				_shortcut_slots[i].color = Color.GRAY
		_shortcut_labels[i].text = "%s x%d" % [item.get("name", bar_materials[i]), bar_counts[i]]


# ============================================================
#  拖拽系统（相对坐标跟随）
# ============================================================

func _init_drag_panel() -> void:
	var drag_canvas = CanvasLayer.new()
	drag_canvas.layer = 100
	add_child(drag_canvas)
	_drag_panel = ColorRect.new()
	_drag_panel.visible = false
	_drag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_canvas.add_child(_drag_panel)


func _process(_delta: float) -> void:
	if _dragging:
		# 相对坐标跟随：鼠标位置减去点击偏移
		_drag_panel.position = get_viewport().get_mouse_position() - _drag_offset


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _dragging:
			_try_pick_up(event.position)
		elif not event.pressed and _dragging:
			_try_drop(event.position)


func _try_pick_up(pos: Vector2) -> void:
	# 从快捷栏拾取
	for i in range(10):
		if _hit_test(_shortcut_slots[i], pos) and bar_materials[i] != "" and bar_counts[i] > 0:
			var mat: String = bar_materials[i]
			# 记录点击点相对于槽位左上角的偏移
			_drag_offset = pos - _shortcut_slots[i].global_position
			_remove_from_inventory(mat)
			_start_drag(pos, mat)
			return

	# 从桌面拾取
	if _hit_test(_desktop, pos):
		var pick = _desktop.pick_at(pos)
		if not pick.is_empty():
			# 记录点击点相对于物品的偏移
			var item_local: Vector2 = pick["local_pos"]
			var item_global = _desktop.global_position + item_local
			_drag_offset = pos - item_global
			_start_drag(pos, pick["key"])
			return

	# 从客人区取回
	if _customer_sprite.has_meta("served_item") and _hit_test(_customer_sprite, pos):
		var served = _customer_sprite.get_meta("served_item", "")
		_customer_sprite.remove_meta("served_item")
		_drag_offset = Vector2(32, 28)
		_start_drag(pos, served)
		return


func _try_drop(pos: Vector2) -> void:
	# 拖到桌面合成区（使用偏移量放置，避免瞬移）
	if _hit_test(_desktop, pos) and _drag_material != "":
		_desktop.add_item(_drag_material, pos - _drag_offset)
		_end_drag()
		return

	# 拖到客人区（上菜）
	var customer_area = $CustomerArea
	if _hit_test(customer_area, pos) and _drag_material != "":
		var item = _gm.craft.get_item(_drag_material)
		if item.get("price", 0) > 0:
			_customer_sprite.set_meta("served_item", _drag_material)
			_end_drag()
			return

	# 拖回快捷栏
	for i in range(10):
		if _hit_test(_shortcut_slots[i], pos):
			if bar_materials[i] == "":
				bar_materials[i] = _drag_material
				_add_to_inventory(_drag_material)
				_end_drag()
				_refresh_shortcut(i)
				return
			elif bar_materials[i] == _drag_material:
				_add_to_inventory(_drag_material)
				_end_drag()
				_refresh_shortcut(i)
				return

	# 无处可放 → 退回背包
	_return_drag()
	_end_drag()


func _start_drag(pos: Vector2, mat_key: String) -> void:
	_dragging = true
	_drag_material = mat_key
	_drag_panel.visible = true
	_drag_panel.size = Vector2(64, 56)
	# 初始位置：鼠标位置减去偏移（无瞬移）
	_drag_panel.position = pos - _drag_offset
	var item = _gm.craft.get_item(mat_key)
	if not item.is_empty():
		var col_arr = item.get("color", [])
		if col_arr is Array and col_arr.size() >= 3:
			_drag_panel.color = Color(col_arr[0], col_arr[1], col_arr[2])
		else:
			_drag_panel.color = Color.GRAY
	else:
		_drag_panel.color = Color.GRAY


func _end_drag() -> void:
	_dragging = false
	_drag_panel.visible = false
	_drag_material = ""


func _return_drag() -> void:
	if _drag_material != "":
		_add_to_inventory(_drag_material)


func _add_to_inventory(key: String, amount: int = 1) -> void:
	if key == "" or _gm == null:
		return
	var cur: int = _gm.inventory.get(key, 0)
	_gm.inventory[key] = cur + amount
	_gm.notify_inventory_changed()


func _remove_from_inventory(key: String, amount: int = 1) -> void:
	if key == "" or _gm == null:
		return
	if _gm.inventory.has(key):
		var remaining = _gm.inventory[key] - amount
		if remaining <= 0:
			_gm.inventory.erase(key)
		else:
			_gm.inventory[key] = remaining
	_gm.notify_inventory_changed()


# ============================================================
#  合成操作
# ============================================================

func _on_mix_available(available: bool) -> void:
	_mix_btn.visible = available
	if available:
		_refresh_operation_buttons()


func _on_mix_pressed() -> void:
	var recipe = _desktop.get_mix_recipe()
	if recipe.is_empty():
		return
	_desktop.do_mix(recipe["a"], recipe["b"], recipe["result"])


func _refresh_operation_buttons() -> void:
	for child in _operation_btns_container.get_children():
		child.queue_free()

	var ops = _desktop.get_available_operation()
	if ops.is_empty():
		return

	for op in ops:
		var result = ops[op]
		var label_text = op
		match op:
			"heat": label_text = "加热"
			"stir": label_text = "搅拌"
			"shake": label_text = "摇晃"
			"pour": label_text = "倒出"

		var btn = Button.new()
		btn.text = label_text
		ThemeColors.style_small_button(btn, 12)
		btn.pressed.connect(_execute_op.bind(op, result))
		_operation_btns_container.add_child(btn)


func _execute_op(op_name: String, result_key: String) -> void:
	_desktop.do_operation(op_name, result_key)


func _on_clear_desktop() -> void:
	var items: Array = _desktop._items
	for item in items:
		_add_to_inventory(item["key"])
	_desktop.clear_all()


# ============================================================
#  工具
# ============================================================

func _hit_test(c: Control, p: Vector2) -> bool:
	if c == null:
		return false
	var r = c.get_global_rect()
	return p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y and p.y <= r.end.y


func _exit_tree() -> void:
	if _gm != null:
		_gm.inventory_changed.disconnect(_sync_shortcut_from_inventory)
		if _desktop != null:
			_desktop.mix_available.disconnect(_on_mix_available)
