class_name GravityTest
extends Control

## 桌面重力测试：地面线、下落、堆叠、滑落

# —— 物品数据结构 ——
class DeskItem:
	var color: Color
	var pos: Vector2
	var vel: Vector2
	var is_static: bool


# —— 物理参数 ——
const GRAVITY: float = 800.0
const ITEM_SIZE: float = 60.0
const BOUNCE_DAMP: float = 0.3
const SLIDE_SPEED: float = 250.0
const SETTLE_THRESHOLD: float = 2.0
const GROUND_Y_RATIO: float = 0.65

# —— UI ——
var _drag_ctrl: DragController
var _desktop_rect: Rect2
var _ground_y: float
var _items: Array[DeskItem] = []

const BAR_COUNT: int = 5
const BAR_W: float = 70.0
const BAR_H: float = 70.0
const BAR_GAP: float = 12.0
var _bar_slots: Array[Rect2] = []
var _bar_colors: Array[Color] = []


func _ready() -> void:
	_drag_ctrl = DragController.new()
	_drag_ctrl.name = "DragCtrl"
	add_child(_drag_ctrl)
	_drag_ctrl.animation_finished.connect(_on_anim_done)

	_desktop_rect = Rect2(80, 60, size.x - 160, size.y * 0.55)
	_ground_y = _desktop_rect.position.y + _desktop_rect.size.y * GROUND_Y_RATIO

	var colors: Array[Color] = [
		Color.CRIMSON, Color.GOLD, Color(0.18, 0.55, 0.34),
		Color.ROYAL_BLUE, Color.DARK_ORCHID,
	]
	var total_w: float = BAR_COUNT * BAR_W + (BAR_COUNT - 1) * BAR_GAP
	var sx: float = (size.x - total_w) * 0.5
	var sy: float = size.y - BAR_H - 30.0
	for i in range(BAR_COUNT):
		_bar_slots.append(Rect2(sx + i * (BAR_W + BAR_GAP), sy, BAR_W, BAR_H))
		_bar_colors.append(colors[i])


func _draw() -> void:
	if not is_inside_tree():
		return

	# 桌面背景
	draw_rect(_desktop_rect, Color(0.12, 0.10, 0.07))
	draw_rect(_desktop_rect, Color(0.35, 0.30, 0.20), false, 2.0)

	# 地面线
	var gx1: float = _desktop_rect.position.x
	var gx2: float = gx1 + _desktop_rect.size.x
	var dash: float = 10.0; var gap: float = 6.0
	var x: float = gx1
	while x < gx2:
		draw_line(Vector2(x, _ground_y), Vector2(min(x + dash, gx2), _ground_y), Color(1, 0.3, 0.3, 0.7), 2.0)
		x += dash + gap

	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(_desktop_rect.position.x + 8, _ground_y - 14),
			"--- 地面线 ---", HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color(1, 0.3, 0.3, 0.6))

	# 桌面物品（本地坐标）
	for item in _items:
		var r := Rect2(item.pos, Vector2(ITEM_SIZE, ITEM_SIZE))
		draw_rect(r, item.color)
		draw_rect(r, Color.WHITE if not item.is_static else Color(item.color, 0.5), false, 1.5)

	# 快捷栏
	for i in range(BAR_COUNT):
		var r := _bar_slots[i]
		draw_rect(r, _bar_colors[i])
		draw_rect(r, Color.WHITE, false, 1.5)
		if font:
			draw_string(font, r.position + Vector2(4, 14), str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 13)

	# 提示
	if font:
		draw_string(font, Vector2(10, 10),
			"从底部拖到红线上方松手 → 下落 | 堆叠 | 重心悬空→滑落",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 14, Color(0.65, 0.55, 0.45))


# —— 输入处理 ——
# button 事件走 _gui_input：press/release 用本地坐标，匹配 _draw()
# motion 事件走 _input：更可靠，不依赖 GUI 路由

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		print("[GUI] btn pressed=%s drag=%s pos=%s" % [event.pressed, _drag_ctrl.is_dragging(), event.position])
		if event.pressed:
			if not _drag_ctrl.is_dragging():
				_try_pickup(event.position)
		else:
			if _drag_ctrl.is_dragging():
				_on_release(event.position)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		_drag_ctrl.update_target(event)


func _process(delta: float) -> void:
	if _drag_ctrl.is_dragging():
		_drag_ctrl.process_step(delta)
	_simulate_physics(delta)
	queue_redraw()


# —— 拾取 / 释放 ——

func _try_pickup(local_pos: Vector2) -> void:
	# 桌面物品（从顶层向下遍历）
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		var item_rect := Rect2(it.pos, Vector2(ITEM_SIZE, ITEM_SIZE))
		if it.is_static and item_rect.has_point(local_pos):
			print("[PICK] hit item %d at local %s (rect %s)" % [i, local_pos, item_rect])
			_drag_ctrl.start_drag("desk", get_global_mouse_position(), it.color,
				Vector2(ITEM_SIZE * 0.5, ITEM_SIZE * 0.5))
			_items.remove_at(i)
			return

	# 没命中——打印前两个物品对比
	if _items.size() > 0 and _items[0].is_static:
		print("[MISS] local=%s gl_pos=%s cnt=%d item0_rect=%s" % [
			local_pos, global_position, _items.size(),
			Rect2(_items[0].pos, Vector2(ITEM_SIZE, ITEM_SIZE))
		])

	# 快捷栏
	for i in range(BAR_COUNT):
		if _bar_slots[i].has_point(local_pos):
			_drag_ctrl.start_drag("bar", get_global_mouse_position(), _bar_colors[i],
				Vector2(BAR_W * 0.5, BAR_H * 0.5))
			return


func _on_release(local_pos: Vector2) -> void:
	if _desktop_rect.has_point(local_pos):
		# DragController 的视觉位置是 viewport 坐标，转本地
		var vp_center := _drag_ctrl.get_visual_pos()
		var local_center := vp_center - global_position
		var it := DeskItem.new()
		it.color = _drag_ctrl.get_panel_color()
		it.pos = local_center - Vector2(ITEM_SIZE * 0.5, ITEM_SIZE * 0.5)
		it.vel = Vector2.ZERO
		it.is_static = false
		_items.append(it)
		_drag_ctrl.cancel()
		print("[DROP] vp_center=%s gl_pos=%s stored=%s local_mouse=%s" % [vp_center, global_position, it.pos, local_pos])
	else:
		# 回到快捷栏（本地坐标 → viewport）
		var vp_origin := _find_nearest_bar(local_pos) + global_position
		_drag_ctrl.end_drag_return(vp_origin)


func _on_anim_done(_key: String, _dest: Vector2, _type: String) -> void:
	pass


# —— 重力物理 ——

func _simulate_physics(delta: float) -> void:
	for item in _items:
		if item.is_static:
			if not _has_support(item):
				item.is_static = false
			else:
				continue

		item.vel.y += GRAVITY * delta
		item.pos += item.vel * delta

		# 地面碰撞
		if item.pos.y + ITEM_SIZE >= _ground_y:
			item.pos.y = _ground_y - ITEM_SIZE
			item.vel.y = -item.vel.y * BOUNCE_DAMP
			if abs(item.vel.y) < SETTLE_THRESHOLD:
				item.vel.y = 0
			item.vel.x *= 0.9
			_snap_to_static(item)

		_resolve_item_collisions(item)


func _resolve_item_collisions(item: DeskItem) -> void:
	var r := Rect2(item.pos, Vector2(ITEM_SIZE, ITEM_SIZE))
	# AABB 相交即视为支撑候选，取最高的顶面（y 最小）作为 snap 目标
	var support_y: float = INF

	for other in _items:
		if other == item or not other.is_static:
			continue
		var o_r := Rect2(other.pos, Vector2(ITEM_SIZE, ITEM_SIZE))
		if not r.intersects(o_r, true):
			continue
		if item.vel.y < 0:
			continue
		if other.pos.y < support_y:
			support_y = other.pos.y

	if support_y < INF:
		item.pos.y = support_y - ITEM_SIZE
		item.vel.y = -item.vel.y * BOUNCE_DAMP
		if abs(item.vel.y) < SETTLE_THRESHOLD:
			item.vel.y = 0
		_snap_to_static(item)

	if item.is_static and abs(item.vel.x) < SETTLE_THRESHOLD:
		_try_slide(item)


func _has_support(item: DeskItem) -> bool:
	if item.pos.y + ITEM_SIZE >= _ground_y - 1:
		return true
	var foot := Rect2(item.pos.x + 4, item.pos.y + ITEM_SIZE - 2, ITEM_SIZE - 8, 4)
	for other in _items:
		if other == item or not other.is_static:
			continue
		if foot.intersects(Rect2(other.pos, Vector2(ITEM_SIZE, ITEM_SIZE)), true):
			return true
	return false


func _try_slide(item: DeskItem) -> void:
	# 在地面上的物品不参与滑落判定（地面是无限平面，无悬空概念）
	if item.pos.y + ITEM_SIZE >= _ground_y - 0.5:
		return

	# 无支撑 → 不应是 static，复位为下落
	if not _has_support(item):
		item.is_static = false
		return

	# 在我下方且 top 接触我 bottom 的物体，取它们的 x 范围作为支撑跨度
	var cx: float = item.pos.x + ITEM_SIZE * 0.5
	var support_left: float = INF
	var support_right: float = -INF
	var my_bottom: float = item.pos.y + ITEM_SIZE

	for other in _items:
		if other == item or not other.is_static:
			continue
		if abs(my_bottom - other.pos.y) > 0.5:
			continue
		var left: float = max(item.pos.x, other.pos.x)
		var right: float = min(item.pos.x + ITEM_SIZE, other.pos.x + ITEM_SIZE)
		if right <= left:
			continue
		if left < support_left:
			support_left = left
		if right > support_right:
			support_right = right

	# 有 _has_support 但找不到接触 top（防御性，正常不会到这里）
	if support_left == INF:
		return

	# 重心在支撑范围中部 → 保持静止
	if cx >= support_left + 8 and cx <= support_right - 8:
		return

	# 重心悬空 → 向外滑落
	if cx < support_left + 8:
		item.vel.x = -SLIDE_SPEED
		item.is_static = false
	elif cx > support_right - 8:
		item.vel.x = SLIDE_SPEED
		item.is_static = false


func _snap_to_static(item: DeskItem) -> void:
	if abs(item.vel.x) < SETTLE_THRESHOLD and abs(item.vel.y) < SETTLE_THRESHOLD:
		item.vel = Vector2.ZERO
		item.is_static = true


func _find_nearest_bar(local_pos: Vector2) -> Vector2:
	var best: Rect2 = _bar_slots[0]
	var best_d: float = INF
	for r in _bar_slots:
		var d: float = r.get_center().distance_squared_to(local_pos)
		if d < best_d:
			best_d = d
			best = r
	return best.position
