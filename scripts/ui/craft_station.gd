class_name CraftStation
extends Control

signal serve_requested(item_key: String, seasoning_tag: String)
signal clear_requested()
signal gesture_completed(action: String)

var _mixing_area: MixingArea
var _product_panel: ProductPanel
var _seasoning_zone: SeasoningZone
var _operation_buttons: Control
var _clear_btn: Button
var _result_slot: ColorRect
var _result_label: Label
var _mix_btn: Button

# Drag state
var _dragging: bool = false
var _drag_material: String = ""
var _drag_result_key: String = ""
var _drag_result_source: String = ""
var _drag_seasoning: String = ""
var _drag_panel: ColorRect
var _overlay_menu: Control
var _dialogue_overlay

# Shortcut bar
var bar_materials: Array[String] = []
var bar_counts: Array[int] = []
var _shortcut_slots: Array[ColorRect] = []
var _shortcut_labels: Array[Label] = []

var _gm: GameManager

# Heat
var _heating: bool = false
var _heat_progress: float = 0.0
const HEAT_TIME: float = 1.5
var _heat_target_op: String = ""
var _heat_btn_ref: Button = null

# Stir
var _stirring: bool = false
var _stir_circles: int = 0
const STIR_TARGET: int = 3
var _stir_last_mouse: Vector2
var _stir_total_angle: float = 0.0

func _ready() -> void:
	_gm = get_node("/root/GameManager")

	_mixing_area = $MixingArea
	_product_panel = $ProductPanel
	_seasoning_zone = $SeasoningZone
	_operation_buttons = $OperationButtons
	_clear_btn = $ClearBtn
	_result_slot = $ResultSlot
	_result_label = $ResultSlot/Label
	_overlay_menu = get_node_or_null("../OverlayMenu")
	_dialogue_overlay = get_node_or_null("../DialogueDim")

	# 隐藏旧的合并查询栏（Tavern.tscn 中已有 CombineQueryBar 节点，直接隐藏）
	var combine_query_bar = get_node_or_null("CombineQueryBar")
	if combine_query_bar != null:
		combine_query_bar.visible = false

	# 创建混合按钮（放在操作按钮之前）
	_create_mix_button()

	_mixing_area.mix_available.connect(_on_mix_available)
	_mixing_area.contents_changed.connect(_refresh_operation_buttons)
	_mixing_area.contents_changed.connect(_check_result_ready)

	_clear_btn.pressed.connect(func():
		for item in _mixing_area.get_items():
			_gm.add_to_inventory(item)
		_mixing_area.clear_items()
		_clear_result_slot()
		clear_requested.emit()
	)

	ThemeColors.style_small_button(_clear_btn, 12)

	_result_slot.color = Color(0.06, 0.05, 0.04)

	_init_shortcut_bar()
	_init_drag_panel()
	_sync_from_inventory()
	_gm.inventory_changed.connect(_sync_from_inventory)


func _create_mix_button() -> void:
	_mix_btn = Button.new()
	_mix_btn.name = "MixBtn"
	_mix_btn.text = "混合"
	_mix_btn.visible = false
	_mix_btn.custom_minimum_size = Vector2(120, 36)
	ThemeColors.style_button(_mix_btn, 14)
	_mix_btn.pressed.connect(_on_mix_pressed)

	# 放在 CombineQueryBar/OperationButtons 的位置
	var cqbar = get_node_or_null("CombineQueryBar")
	if cqbar != null:
		# 放在 CombineQueryBar 后、OperationButtons 前
		var idx = cqbar.get_index()
		add_child(_mix_btn)
		move_child(_mix_btn, idx)
	else:
		add_child(_mix_btn)


func _on_mix_available(available: bool) -> void:
	_mix_btn.visible = available
	# 混合可用时隐藏操作按钮
	if available:
		for child in _operation_buttons.get_children():
			child.queue_free()
	else:
		_refresh_operation_buttons()


func _on_mix_pressed() -> void:
	var recipe = _mixing_area.get_mix_recipe()
	if recipe.is_empty():
		return

	var a: String = recipe["a"]
	var b: String = recipe["b"]
	var result: String = recipe["result"]

	# 检查库存中是否有足够的材料（混合区的材料来自背包，此处只是合成操作）
	# 严格按配方各消耗一个
	_mixing_area.do_mix(a, b, result)


func _refresh_operation_buttons() -> void:
	for child in _operation_buttons.get_children():
		child.queue_free()

	var contents: Array = _mixing_area._items
	if contents.size() == 0:
		return

	# 如果已有可混合配方，不显示操作按钮
	var recipe = _mixing_area.get_mix_recipe()
	if not recipe.is_empty():
		return

	var first_key: String = contents[0]
	var ops: Dictionary = _gm.craft.get_operations(first_key)
	if ops.size() == 0:
		return

	for op in ops:
		var result: String = ops[op]
		var label_text: String = op
		match op:
			"heat": label_text = "加热"
			"stir": label_text = "搅拌"
			"shake": label_text = "摇晃"
			"pour": label_text = "倒出"

		var btn = Button.new()
		btn.text = label_text
		ThemeColors.style_small_button(btn, 12)

		match op:
			"heat":
				btn.button_down.connect(_start_heat.bind(btn, result))
				btn.button_up.connect(_stop_heat)
			"stir":
				btn.button_down.connect(_start_stir.bind(btn, result))
				btn.button_up.connect(_stop_stir)
			_:
				btn.pressed.connect(_execute_operation.bind(result))

		_operation_buttons.add_child(btn)


func _start_heat(btn: Button, result_key: String) -> void:
	_heating = true
	_heat_progress = 0.0
	_heat_target_op = result_key
	_heat_btn_ref = btn
	btn.text = "加热中..."

func _stop_heat() -> void:
	if not _heating:
		return
	_heating = false
	if _heat_progress < HEAT_TIME:
		_heat_btn_ref.text = "加热"
	_heat_btn_ref = null

func _start_stir(btn: Button, result_key: String) -> void:
	_stirring = true
	_stir_circles = 0
	_stir_total_angle = 0.0
	_stir_last_mouse = get_viewport().get_mouse_position()
	_heat_target_op = result_key
	_heat_btn_ref = btn
	btn.text = "搅拌中... (转圈)"

func _stop_stir() -> void:
	if not _stirring:
		return
	_stirring = false
	if _stir_circles < STIR_TARGET:
		_heat_btn_ref.text = "搅拌"
	_heat_btn_ref = null

func _execute_operation(result_key: String) -> void:
	var contents: Array = _mixing_area._items
	if contents.size() == 0:
		return
	_mixing_area.consume_and_replace([contents[0]], result_key)
	gesture_completed.emit("done")

func _check_result_ready() -> void:
	var contents: Array = _mixing_area._items
	if contents.size() == 1:
		var key: String = contents[0]
		if not _gm.craft.has_operations(key):
			_move_to_result_slot(key)
			_mixing_area.clear_items()

func _move_to_result_slot(key: String) -> void:
	var item: Dictionary = _gm.craft.get_item(key)
	if not item.is_empty():
		var col_arr = item.get("color", [])
		if col_arr is Array and col_arr.size() >= 3:
			_result_slot.color = Color(col_arr[0], col_arr[1], col_arr[2])
		_result_label.text = item.get("name", key)
	else:
		_result_label.text = key

	_result_slot.set_meta("item_key", key)
	_result_slot.set_meta("seasoning", "")
	_seasoning_zone.clear_item()

	# 教程：首次制作出成品，触发香料教程
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null and not tm.first_product_seasoned and not tm._is_active:
		tm.first_product_seasoned = true
		tm._save_state()
		call_deferred("_trigger_seasoning_tutorial")

func _clear_result_slot() -> void:
	_result_label.text = ""
	_result_slot.color = Color(0.06, 0.05, 0.04)
	_result_slot.remove_meta("item_key")
	_result_slot.remove_meta("seasoning")
	_seasoning_zone.clear_item()

func _process(delta: float) -> void:
	if _overlay_menu != null and _overlay_menu.visible:
		return

	if _dragging:
		_drag_panel.position = get_viewport().get_mouse_position() - Vector2(32, 32)

	if _heating:
		_heat_progress += delta
		var ratio: float = _heat_progress / HEAT_TIME
		if _heat_progress >= HEAT_TIME:
			_heating = false
			if _heat_btn_ref != null:
				_heat_btn_ref.text = "加热 ✓"
			gesture_completed.emit("heat")
			_execute_operation(_heat_target_op)
		elif _heat_btn_ref != null:
			_heat_btn_ref.text = "加热中 %d%%" % int(ratio * 100)

	if _stirring:
		var mouse = get_viewport().get_mouse_position()
		var btn_center = _heat_btn_ref.global_position if _heat_btn_ref != null else Vector2.ZERO
		var prev = _stir_last_mouse - btn_center
		var cur = mouse - btn_center
		var angle_prev = atan2(prev.y, prev.x)
		var angle_cur = atan2(cur.y, cur.x)
		var delta_angle = angle_cur - angle_prev

		if delta_angle > PI: delta_angle -= PI * 2.0
		elif delta_angle < -PI: delta_angle += PI * 2.0

		if abs(delta_angle) > 0.005:
			_stir_total_angle += delta_angle
		_stir_last_mouse = mouse

		_stir_circles = int(abs(_stir_total_angle) / (PI * 2.0))
		if _heat_btn_ref != null:
			_heat_btn_ref.text = "搅拌... %d/%d圈" % [_stir_circles, STIR_TARGET]
		if _stir_circles >= STIR_TARGET:
			_stirring = false
			if _heat_btn_ref != null:
				_heat_btn_ref.text = "搅拌 ✓"
			gesture_completed.emit("stir")
			_execute_operation(_heat_target_op)

func _input(event: InputEvent) -> void:
	if _overlay_menu != null and _overlay_menu.visible:
		return
	if _dialogue_overlay != null and _dialogue_overlay.visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _dragging:
			_try_pick_up(event.position)
		elif not event.pressed and _dragging:
			_try_drop(event.position)

func _try_pick_up(pos: Vector2) -> void:
	if _overlay_menu != null and _overlay_menu.visible:
		var backpack_list = get_node_or_null("../OverlayMenu/BackpackPanel/BackpackList")
		if backpack_list != null:
			for row in backpack_list.get_children():
				if _hit_test(row, pos):
					var mat: String = row.get_meta("material_key", "")
					if mat != "" and _gm.inventory.get(mat, 0) > 0:
						_gm.remove_from_inventory(mat)
						_start_drag(pos, mat)
						return
		return

	var serve_key: String = _result_slot.get_meta("item_key", "")
	if serve_key != "" and _hit_test(_result_slot, pos):
		_drag_result_key = serve_key
		_drag_result_source = "result_slot"
		_result_label.text = ""
		_result_slot.color = Color(0.06, 0.05, 0.04)
		_result_slot.remove_meta("item_key")
		_result_slot.remove_meta("seasoning")
		_start_result_drag(pos)
		return

	if _hit_test(_seasoning_zone, pos) and _seasoning_zone.get_state() != SeasoningZone.State.EMPTY:
		_drag_result_key = _seasoning_zone.get_item_key()
		_drag_result_source = "seasoning_zone"
		_drag_seasoning = _seasoning_zone.get_applied_seasoning()
		_seasoning_zone.clear_item()
		_start_result_drag(pos)
		return

	if _hit_test(_mixing_area, pos):
		var contents: Array = _mixing_area._items
		if contents.size() > 0:
			var mat: String = contents[contents.size() - 1]
			_mixing_area.remove_item(mat)
			_start_drag(pos, mat)
			return

	for i in range(10):
		if _hit_test(_shortcut_slots[i], pos) and bar_materials[i] != "" and bar_counts[i] > 0:
			var mat: String = bar_materials[i]
			_gm.remove_from_inventory(mat)
			_start_drag(pos, mat)
			return

func _try_drop(pos: Vector2) -> void:
	var menu_open: bool = _overlay_menu != null and _overlay_menu.visible

	if not menu_open:
		var customer_drop = get_node_or_null("../BarWorkspace/CustomerDropArea")
		if customer_drop != null and _point_in_rect(customer_drop.position.x, customer_drop.position.y, 410, 328, pos):
			if _gm.guests.has_guest and (_drag_material != "" or _drag_result_key != ""):
				var serve_key = _drag_result_key if _drag_result_key != "" else _drag_material
				var serve_seasoning = _drag_seasoning if _drag_result_key != "" else _seasoning_zone.get_applied_seasoning()
				_seasoning_zone.clear_item()
				var item: Dictionary = _gm.craft.get_item(serve_key)
				if not item.is_empty():
					_end_drag()
					serve_requested.emit(serve_key, serve_seasoning)
					return
			_return_drag()
			_end_drag()
			return

		# 检查拖拽物中心点是否在合成区内（大面积重叠判定）
		if _center_hit_test(_mixing_area, pos) and _drag_material != "":
			_mixing_area.add_item(_drag_material)
			_end_drag()
			return

	if _hit_test(_seasoning_zone, pos):
		if _drag_result_key != "" and _seasoning_zone.get_state() == SeasoningZone.State.EMPTY:
			_seasoning_zone.set_item(_drag_result_key)
			_end_drag()
			return
		if _drag_material != "":
			if _seasoning_zone.try_apply_seasoning(_drag_material):
				_end_drag()
				return
			var item = _gm.craft.get_item(_drag_material)
			if not item.is_empty() and _seasoning_zone.get_state() == SeasoningZone.State.EMPTY:
				_seasoning_zone.set_item(_drag_material)
				_end_drag()
				return

	for i in range(10):
		if _drag_material == "":
			break
		if _hit_test(_shortcut_slots[i], pos):
			if bar_materials[i] == "":
				bar_materials[i] = _drag_material
				_gm.add_to_inventory(_drag_material)
				_end_drag()
				_refresh_shortcut(i)
				return
			elif bar_materials[i] == _drag_material:
				_gm.add_to_inventory(_drag_material)
				_end_drag()
				_refresh_shortcut(i)
				return

	if menu_open:
		_return_drag()
		_end_drag()
		return
	_return_drag()
	_end_drag()


## 检查拖拽物中心点是否在目标控件内（用于大面积重叠判定）
func _center_hit_test(target: Control, mouse_pos: Vector2) -> bool:
	var rect = target.get_global_rect()
	# 拖拽面板中心约在鼠标位置
	var cx = mouse_pos.x
	var cy = mouse_pos.y
	return cx >= rect.position.x and cx <= rect.position.x + rect.size.x \
		and cy >= rect.position.y and cy <= rect.position.y + rect.size.y


func _start_drag(pos: Vector2, material: String) -> void:
	_dragging = true
	_drag_material = material
	_drag_panel.visible = true
	_drag_panel.size = Vector2(64, 64)
	_drag_panel.position = pos - Vector2(32, 32)
	var item: Dictionary = _gm.craft.get_item(material)
	if not item.is_empty():
		var col_arr = item.get("color", [])
		if col_arr is Array and col_arr.size() >= 3:
			_drag_panel.color = Color(col_arr[0], col_arr[1], col_arr[2])
		else:
			_drag_panel.color = Color.GRAY
	else:
		_drag_panel.color = Color.GRAY

func _start_result_drag(pos: Vector2) -> void:
	_dragging = true
	_drag_panel.visible = true
	_drag_panel.size = Vector2(64, 64)
	_drag_panel.position = pos - Vector2(32, 32)
	var item: Dictionary = _gm.craft.get_item(_drag_result_key)
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
	_drag_result_key = ""
	_drag_result_source = ""
	_drag_seasoning = ""

func _return_drag() -> void:
	if _drag_result_key != "":
		if _drag_result_source == "result_slot":
			_move_to_result_slot(_drag_result_key)
		elif _drag_result_source == "seasoning_zone":
			_seasoning_zone.set_item(_drag_result_key)
			if _drag_seasoning != "":
				_seasoning_zone.try_apply_seasoning(_drag_seasoning)
		else:
			_gm.add_to_inventory(_drag_result_key)
	elif _drag_material != "":
		_gm.add_to_inventory(_drag_material)

func _init_shortcut_bar() -> void:
	bar_materials.resize(10)
	bar_counts.resize(10)
	_shortcut_slots.resize(10)
	_shortcut_labels.resize(10)

	var bar = get_node("../ShortcutBar")
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(10):
		_shortcut_slots[i] = bar.get_node("Slot%d" % i)
		_shortcut_slots[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shortcut_labels[i] = bar.get_node("Slot%d/Label" % i)
		_shortcut_labels[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shortcut_slots[i].color = Color(0.08, 0.06, 0.04)

func _init_drag_panel() -> void:
	var drag_canvas = CanvasLayer.new()
	drag_canvas.layer = 1
	get_parent().call_deferred("add_child", drag_canvas)
	_drag_panel = ColorRect.new()
	_drag_panel.visible = false
	_drag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_canvas.add_child(_drag_panel)

func _sync_from_inventory() -> void:
	var inv: Dictionary = _gm.inventory
	for i in range(10):
		if bar_materials[i] != "" and inv.get(bar_materials[i], 0) > 0:
			bar_counts[i] = inv[bar_materials[i]]
			_refresh_shortcut(i)
		else:
			bar_materials[i] = ""
			bar_counts[i] = 0

	for key in inv:
		var count: int = inv[key]
		if count <= 0:
			continue
		var already_shown = false
		for i in range(10):
			if bar_materials[i] == key:
				already_shown = true
				break
		if already_shown:
			continue
		for i in range(10):
			if bar_materials[i] == "":
				bar_materials[i] = key
				bar_counts[i] = count
				_refresh_shortcut(i)
				break

	for i in range(10):
		if bar_materials[i] == "":
			_refresh_shortcut(i)

func _refresh_shortcut(i: int) -> void:
	if bar_materials[i] == "":
		_shortcut_slots[i].color = Color(0.1, 0.08, 0.06)
		_shortcut_labels[i].text = ""
	else:
		var item: Dictionary = _gm.craft.get_item(bar_materials[i])
		if not item.is_empty():
			var col_arr = item.get("color", [])
			if col_arr is Array and col_arr.size() >= 3:
				_shortcut_slots[i].color = Color(col_arr[0], col_arr[1], col_arr[2])
			else:
				_shortcut_slots[i].color = Color.GRAY
		else:
			_shortcut_slots[i].color = Color.GRAY
		_shortcut_labels[i].text = "%s x%d" % [item.get("name", bar_materials[i]), bar_counts[i]]

func refresh_all() -> void:
	for i in range(10):
		_refresh_shortcut(i)


func _trigger_seasoning_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	var rects = {
		"SeasoningZone": [821, 556, 114, 75],
	}
	tm.start_tutorial("seasoning", rects)


func _hit_test(c: Control, p: Vector2) -> bool:
	var r = c.get_global_rect()
	return p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y and p.y <= r.end.y

func _point_in_rect(rx: float, ry: float, rw: float, rh: float, p: Vector2) -> bool:
	return p.x >= rx and p.x <= rx + rw and p.y >= ry and p.y <= ry + rh
