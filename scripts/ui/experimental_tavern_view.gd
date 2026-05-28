class_name ExperimentalTavernView
extends Node2D

## 实验性酒馆 — 重力物理合成
## 快捷栏取材料生成 DeskItem → DragController 钉住拖拽 → 松手自由落体
## 物理桌面包围盒 (60,360)→(1220,710)，地面 y=600（桌面中心/屏幕下1/6）

# —— 常量 ——
const DESK_RECT := Rect2(20, 420, 1240, 280)           # 桌面视觉区
const RECIPE_CHECK_INTERVAL: float = 0.3                # 配方重检间隔
const BAR_SIZE := 10
const MERGE_SPEED_THRESHOLD: float = 350.0              # 速度碰撞合成最低相对速度

# 拖动软边界（物品中心可到达的范围，留 30px 半宽防止穿墙抽搐）
# 墙壁: 左x=60 右x=1220 上y=10 地面y=600
const ITEM_HALF: float = 30.0
const DRAG_BOUNDS := Rect2(60 + ITEM_HALF, 10 + ITEM_HALF, 1220 - 60 - ITEM_HALF * 2, 600 - 10 - ITEM_HALF * 2)
const DROP_MARGIN: float = 50.0                         # 鼠标超出边界多少 px 后自动松手

# —— 子节点 ——
@onready var _drag_ctrl: DragController = $DragCtrl
@onready var _items_node: Node2D = $World/Items
@onready var _desktop_area: Control = $DesktopArea
@onready var _operation_btn_container: HBoxContainer = $DesktopArea/OperationButtons
@onready var _mix_btn: Button = $DesktopArea/MixBtn
@onready var _clear_btn: Button = $DesktopArea/ClearDesktopBtn
@onready var _gold_label: Label = $UI/TopPanel/GoldLabel
@onready var _rep_label: Label = $UI/TopPanel/ReputationLabel
@onready var _day_label: Label = $UI/TopPanel/DayLabel

# —— 快捷栏 ——
var _slot_rects: Array[Rect2] = []
var bar_materials: Array[String] = []
var bar_counts: Array[int] = []

# —— 运行时 ——
var _gm: Node
var _recipe_timer: Timer
var _drag_from_shortcut: bool = false  # 当前拖拽的物品是否来自快捷栏（碰撞暂禁用）
var _prev_drag_in_bounds: bool = false # 上一帧物品中心是否在 DRAG_BOUNDS 内


func _ready() -> void:
	_gm = get_node("/root/GameManager")

	# 快捷栏 — 等待一帧让 HBoxContainer 完成布局，否则 global_position 不准确
	await get_tree().process_frame
	_init_shortcut_bar()
	_sync_shortcut_from_inventory()
	_gm.inventory_changed.connect(_sync_shortcut_from_inventory)

	# 配方重检定时器
	_recipe_timer = Timer.new()
	_recipe_timer.wait_time = RECIPE_CHECK_INTERVAL
	_recipe_timer.timeout.connect(_check_recipes)
	add_child(_recipe_timer)
	_recipe_timer.start()

	# 按钮
	_mix_btn.pressed.connect(_on_mix_pressed)
	_clear_btn.pressed.connect(_on_clear_desktop)
	_mix_btn.visible = false

	_apply_theme()
	_refresh_top_bar()


# ============================================================
#  主题
# ============================================================

func _apply_theme() -> void:
	ThemeColors.style_button(_mix_btn, 14)
	ThemeColors.style_small_button(_clear_btn, 12)

	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 16)
	_rep_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_rep_label.add_theme_font_size_override("font_size", 16)
	_day_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_day_label.add_theme_font_size_override("font_size", 15)


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
	bar_materials.resize(BAR_SIZE)
	bar_counts.resize(BAR_SIZE)
	_slot_rects.resize(BAR_SIZE)

	var bar := $ShortcutBar
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(BAR_SIZE):
		var slot := bar.get_node("Slot%d" % i) as ColorRect
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_rects[i] = Rect2(slot.global_position, slot.size)
		var label := slot.get_node("Label") as Label
		if label != null:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _sync_shortcut_from_inventory() -> void:
	if _gm == null:
		return
	var inv: Dictionary = _gm.inventory
	# 清理已耗尽的栏位
	for i in range(BAR_SIZE):
		if bar_materials[i] != "" and inv.get(bar_materials[i], 0) <= 0:
			bar_materials[i] = ""
			bar_counts[i] = 0
		elif bar_materials[i] != "":
			bar_counts[i] = inv[bar_materials[i]]
	# 填充新材料
	for key in inv:
		var count: int = inv[key]
		if count <= 0:
			continue
		var already := false
		for i in range(BAR_SIZE):
			if bar_materials[i] == key:
				already = true
				break
		if already:
			continue
		for i in range(BAR_SIZE):
			if bar_materials[i] == "":
				bar_materials[i] = key
				bar_counts[i] = count
				break
	for i in range(BAR_SIZE):
		_refresh_shortcut_display(i)


func _refresh_shortcut_display(i: int) -> void:
	var slot := $ShortcutBar.get_node("Slot%d" % i) as ColorRect
	var label := slot.get_node("Label") as Label
	if bar_materials[i] == "":
		slot.color = Color(0.1, 0.08, 0.06)
		if label: label.text = ""
	else:
		var item: Dictionary = _gm.craft.get_item(bar_materials[i])
		if not item.is_empty():
			var col_arr: Array = item.get("color", [])
			if col_arr is Array and col_arr.size() >= 3:
				slot.color = Color(col_arr[0], col_arr[1], col_arr[2])
			else:
				slot.color = Color.GRAY
		if label:
			label.text = "%s x%d" % [item.get("name", bar_materials[i]), bar_counts[i]]


# ============================================================
#  输入处理 — DragController 钉子拖拽
# ============================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.global_position
		if event.pressed and not _drag_ctrl.is_dragging():
			_try_pickup(pos)
		elif not event.pressed and _drag_ctrl.is_dragging():
			_try_drop(pos)
	elif event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		var pos: Vector2 = event.global_position

		# 快捷栏物品（无碰撞）不限制位置，自由穿透墙壁
		if _drag_from_shortcut:
			_drag_ctrl.update_target_global(pos)
			if _point_in_desktop(pos):
				_enable_item_collision()
			return

		# 记录本帧物品是否在边界内（用于下帧判断）
		var body := _drag_ctrl.get_body()
		var in_bounds_now: bool = DRAG_BOUNDS.has_point(body.global_position) if body else false

		# 仅当物品上一帧已在边界内时，才启用软边界钳制
		# 避免刚从快捷栏进入桌面时就被钳住
		if _prev_drag_in_bounds:
			var overflow: float = _calc_boundary_overflow(pos)
			if overflow > DROP_MARGIN:
				# 鼠标超出边界超过 50px → 自动松手掉落
				_drag_ctrl.end_drag()
				_drag_from_shortcut = false
				_prev_drag_in_bounds = false
			else:
				# 鼠标在边界内或超出 0~50px → 锚点钳制在边界上，物品贴墙不动
				_drag_ctrl.update_target_global(_clamp_to_bounds(pos))
		else:
			_drag_ctrl.update_target_global(pos)

		_prev_drag_in_bounds = in_bounds_now


# —— 拾取 ——

func _try_pickup(pos: Vector2) -> void:
	# 1. 物理点查询：桌面上已有物品？
	var hit_body := _hit_test_item(pos)
	if hit_body != null:
		_drag_from_shortcut = false
		_prev_drag_in_bounds = false
		_drag_ctrl.start_drag(hit_body, pos)
		return

	# 2. 命中快捷栏槽位？
	for i in range(BAR_SIZE):
		if _slot_rects[i].has_point(pos) and bar_materials[i] != "" and bar_counts[i] > 0:
			var mat: String = bar_materials[i]
			_remove_from_inventory(mat)
			var body := DeskItemSpawner.spawn_at(pos, mat, _items_node, _gm.craft)
			_ensure_collision_connected(body)
			_disable_item_collision(body)
			_drag_from_shortcut = true
			_prev_drag_in_bounds = false
			_drag_ctrl.start_drag(body, pos)
			return


func _try_drop(_pos: Vector2) -> void:
	_drag_ctrl.end_drag()
	_drag_from_shortcut = false
	_prev_drag_in_bounds = false
	# 物品留在世界中，DeskItem 自动在 KILL_Y=800 下方自毁


func _hit_test_item(pos: Vector2) -> DeskItem:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 1)
	if hits.size() > 0:
		var collider = hits[0].get("collider")
		if collider is DeskItem:
			return collider
	return null


func _point_in_desktop(pos: Vector2) -> bool:
	var r := _desktop_area.get_global_rect()
	return pos.x >= r.position.x and pos.x <= r.end.x and pos.y >= r.position.y and pos.y <= r.end.y


## 计算鼠标超出拖动边界的最大距离（0 表示在界内）
func _calc_boundary_overflow(pos: Vector2) -> float:
	var over: float = 0.0
	over = max(over, DRAG_BOUNDS.position.x - pos.x)
	over = max(over, pos.x - DRAG_BOUNDS.end.x)
	over = max(over, DRAG_BOUNDS.position.y - pos.y)
	over = max(over, pos.y - DRAG_BOUNDS.end.y)
	return over


## 将鼠标位置钳制到拖动边界内（贴墙不抽搐）
func _clamp_to_bounds(pos: Vector2) -> Vector2:
	return Vector2(
		clamp(pos.x, DRAG_BOUNDS.position.x, DRAG_BOUNDS.end.x),
		clamp(pos.y, DRAG_BOUNDS.position.y, DRAG_BOUNDS.end.y)
	)


## 禁用物品碰撞（从快捷栏取出时临时关闭，避免穿过桌面墙壁时被弹飞）
func _disable_item_collision(body: RigidBody2D) -> void:
	body.collision_layer = 0
	body.collision_mask = 0


## 恢复物品碰撞（拖入桌面上方后启用）
func _enable_item_collision() -> void:
	if not _drag_ctrl.is_dragging():
		return
	var body := _drag_ctrl.get_body()
	if body != null:
		body.collision_layer = 1
		body.collision_mask = 1
	_drag_from_shortcut = false


# ============================================================
#  库存
# ============================================================

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
		var remaining: int = _gm.inventory[key] - amount
		if remaining <= 0:
			_gm.inventory.erase(key)
		else:
			_gm.inventory[key] = remaining
	_gm.notify_inventory_changed()


# ============================================================
#  配方检测（定时器驱动）
# ============================================================

func _check_recipes() -> void:
	if _gm == null:
		return

	var keys := _get_desk_item_keys()
	# 混合检测
	var recipe := _find_mix_recipe(keys)
	_mix_btn.visible = not recipe.is_empty()

	# 操作按钮刷新（单材料有操作配方时显示）
	_refresh_operation_buttons(keys)


func _get_desk_item_keys() -> Array[String]:
	var keys: Array[String] = []
	for child in _items_node.get_children():
		if child is DeskItem and child.has_meta("material_key"):
			var k: String = child.get_meta("material_key")
			if not keys.has(k):
				keys.append(k)
	return keys


func _find_mix_recipe(keys: Array[String]) -> Dictionary:
	if keys.size() < 2:
		return {}
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			var result: String = _gm.craft.get_combine_result(keys[i], keys[j])
			if result != "":
				return {"a": keys[i], "b": keys[j], "result": result}
	return {}


func _refresh_operation_buttons(keys: Array[String]) -> void:
	for child in _operation_btn_container.get_children():
		child.queue_free()

	if keys.size() != 1:
		return

	var ops: Dictionary = _gm.craft.get_operations(keys[0])
	if ops.is_empty():
		return

	for op_name in ops:
		var result_key: String = ops[op_name]
		var label_text: String = op_name
		match op_name:
			"heat":  label_text = "加热"
			"stir":  label_text = "搅拌"
			"shake": label_text = "摇晃"
			"pour":  label_text = "倒出"

		var btn := Button.new()
		btn.text = label_text
		ThemeColors.style_small_button(btn, 12)
		btn.pressed.connect(_execute_op.bind(int(_items_node.get_child_count()), op_name, result_key))
		_operation_btn_container.add_child(btn)


# ============================================================
#  混合 / 操作
# ============================================================

func _on_mix_pressed() -> void:
	if _gm == null:
		return
	var keys := _get_desk_item_keys()
	var recipe := _find_mix_recipe(keys)
	if recipe.is_empty():
		return

	# 物理学查询找到两个物品实例
	var item_a := _find_desk_item_by_key(recipe["a"])
	var item_b := _find_desk_item_by_key(recipe["b"])
	if item_a == null or item_b == null:
		return

	# 销毁原材料
	item_a.queue_free()
	item_b.queue_free()

	# 在桌面中心生成结果
	var result_pos := Vector2(
		DESK_RECT.position.x + DESK_RECT.size.x / 2.0,
		DESK_RECT.position.y + DESK_RECT.size.y / 2.0
	)
	var result_body := DeskItemSpawner.spawn_at(result_pos, recipe["result"], _items_node, _gm.craft)
	_ensure_collision_connected(result_body)


func _execute_op(idx_hint: int, op_name: String, result_key: String) -> void:
	if _gm == null:
		return
	# 找到任一 DeskItem 取其材料
	var target: DeskItem = null
	for child in _items_node.get_children():
		if child is DeskItem:
			target = child
			break
	if target == null:
		return

	var pos := target.global_position
	target.queue_free()

	var result_body := DeskItemSpawner.spawn_at(pos, result_key, _items_node, _gm.craft)
	_ensure_collision_connected(result_body)


func _find_desk_item_by_key(key: String) -> DeskItem:
	for child in _items_node.get_children():
		if child is DeskItem and child.has_meta("material_key"):
			if child.get_meta("material_key") == key:
				return child
	return null


func _on_clear_desktop() -> void:
	for child in _items_node.get_children():
		if child is DeskItem:
			var mat: String = child.get_meta("material_key", "")
			if mat != "":
				_add_to_inventory(mat)
			child.queue_free()


# ============================================================
#  速度碰撞合成
# ============================================================

## 确保 DeskItem 的 body_entered 信号已连接（幂等）
func _ensure_collision_connected(item: DeskItem) -> void:
	if not item.body_entered.is_connected(_on_item_collision.bind(item)):
		item.body_entered.connect(_on_item_collision.bind(item))


## 两个 DeskItem 碰撞（a=信号发出者自身, b=被撞的对方）
func _on_item_collision(a: DeskItem, b: Node) -> void:
	if _gm == null:
		return
	if not (b is DeskItem):
		return
	var other: DeskItem = b as DeskItem

	# 去重：如果任一物品已被 queue_free（同帧另一信号已处理），跳过
	if a.is_queued_for_deletion() or other.is_queued_for_deletion():
		return

	# 检查相对速度
	var rel_vel: Vector2 = a.linear_velocity - other.linear_velocity
	if rel_vel.length() < MERGE_SPEED_THRESHOLD:
		return

	var key_a: String = a.get_meta("material_key", "")
	var key_b: String = other.get_meta("material_key", "")
	if key_a == "" or key_b == "":
		return

	var result: String = _gm.craft.get_combine_result(key_a, key_b)
	var is_double: bool = false

	# 无双物品配方 → 检查单物品配方（同种物品碰撞产出两个）
	if result == "" and key_a == key_b:
		var ops: Dictionary = _gm.craft.get_operations(key_a)
		if not ops.is_empty():
			result = ops.values()[0] as String
			is_double = true

	if result == "":
		return

	# 判断模式：拖拽合成 vs 自由落体合成
	var dragged_body := _drag_ctrl.get_body() if _drag_ctrl.is_dragging() else null
	var is_drag_mode: bool = (a == dragged_body or other == dragged_body)

	# 用 call_deferred 避免在物理回调中操作节点
	if is_drag_mode:
		var held := dragged_body
		var free := a if other == held else other
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		call_deferred("_merge_drag", held, free, result, is_double, mouse_pos)
	else:
		call_deferred("_merge_freefall", a, other, result, is_double)


## Mode 1：拖拽碰撞 — 手中物品甩中桌面物品
func _merge_drag(held: DeskItem, free: DeskItem, result_key: String, is_double: bool, mouse_pos: Vector2) -> void:
	if held.is_queued_for_deletion() or free.is_queued_for_deletion():
		return

	if is_double:
		# 单物品配方 × 2：手中物品变为结果1（保持拖拽），被撞物品变为结果2（保持运动）
		var free_pos := free.global_position
		var free_vel := free.linear_velocity
		var free_ang := free.angular_velocity

		held.queue_free()
		free.queue_free()

		var r1 := DeskItemSpawner.spawn_at(mouse_pos, result_key, _items_node, _gm.craft)
		_ensure_collision_connected(r1)
		_drag_ctrl.start_drag(r1, mouse_pos)

		var r2 := DeskItemSpawner.spawn_at(free_pos, result_key, _items_node, _gm.craft)
		_ensure_collision_connected(r2)
		r2.linear_velocity = free_vel
		r2.angular_velocity = free_ang
	else:
		# 双物品配方 → 1 个结果，保持拖拽
		held.queue_free()
		free.queue_free()

		var r := DeskItemSpawner.spawn_at(mouse_pos, result_key, _items_node, _gm.craft)
		_ensure_collision_connected(r)
		_drag_ctrl.start_drag(r, mouse_pos)


## Mode 2：自由落体碰撞 — 动量守恒
func _merge_freefall(a: DeskItem, b: DeskItem, result_key: String, is_double: bool) -> void:
	if a.is_queued_for_deletion() or b.is_queued_for_deletion():
		return

	var m_a: float = a.mass
	var m_b: float = b.mass
	var v_a: Vector2 = a.linear_velocity
	var v_b: Vector2 = b.linear_velocity
	var total_mass: float = m_a + m_b
	var center: Vector2 = (a.global_position * m_a + b.global_position * m_b) / total_mass
	var conserved_vel: Vector2 = (m_a * v_a + m_b * v_b) / total_mass

	a.queue_free()
	b.queue_free()

	if is_double:
		# 两个结果，略微偏移分布
		var offset := Vector2(20, 0)
		var r1 := DeskItemSpawner.spawn_at(center - offset, result_key, _items_node, _gm.craft)
		_ensure_collision_connected(r1)
		r1.linear_velocity = conserved_vel + Vector2(0, -30)

		var r2 := DeskItemSpawner.spawn_at(center + offset, result_key, _items_node, _gm.craft)
		_ensure_collision_connected(r2)
		r2.linear_velocity = conserved_vel + Vector2(0, 30)
	else:
		var r := DeskItemSpawner.spawn_at(center, result_key, _items_node, _gm.craft)
		_ensure_collision_connected(r)
		r.linear_velocity = conserved_vel


# ============================================================
#  生命周期
# ============================================================

func _exit_tree() -> void:
	if _gm != null:
		_gm.inventory_changed.disconnect(_sync_shortcut_from_inventory)
	if _recipe_timer != null:
		_recipe_timer.stop()
