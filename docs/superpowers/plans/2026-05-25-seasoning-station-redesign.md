# 香料台重设计 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan.

**Goal:** 重做香料系统交互：SeasoningZone 三状态（空/有成品/已撒香料），拖成品进去撒香料，拖出来上菜。

**Architecture:** 重写 seasoning_zone.gd（三状态拖放交互），在 craft_station.gd 加两条拖拽路径（ResultSlot→SeasoningZone、SeasoningZone→顾客区），删除死代码 seasoning_panel.gd。

---

### Task 1: 重写 SeasoningZone（三状态拖放台）

**Files:**
- Modify: `scripts/ui/seasoning_zone.gd`（完全重写）
- Modify: `scenes/ui/Tavern.tscn`（调尺寸）

**新 seasoning_zone.gd：**

```gdscript
class_name SeasoningZone
extends Control

signal serve_requested(item_key: String, seasoning_tag: String)

enum State { EMPTY, HAS_ITEM, SEASONED }

var _gm
var _state: State = State.EMPTY
var _item_key: String = ""
var _applied_seasoning: String = ""
var _item_name: String = ""

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	queue_redraw()

func get_item_key() -> String:
	return _item_key

func get_state() -> State:
	return _state

func set_item(key: String) -> void:
	_item_key = key
	_applied_seasoning = ""
	var item = _gm.craft.get_item(key)
	_item_name = item.get("name", key)
	_state = State.HAS_ITEM
	queue_redraw()

func clear_item() -> void:
	_item_key = ""
	_applied_seasoning = ""
	_item_name = ""
	_state = State.EMPTY
	queue_redraw()

func try_apply_seasoning(seasoning_key: String) -> bool:
	if _state != State.HAS_ITEM and _state != State.SEASONED:
		return false
	if not _gm.seasoning.is_seasoning(seasoning_key):
		return false
	
	# 消耗香料（sleep_powder扣库存）
	if seasoning_key == "sleep_powder":
		if not _gm.inventory.has(seasoning_key) or _gm.inventory[seasoning_key] < 1:
			return false
		_gm.inventory[seasoning_key] = _gm.inventory[seasoning_key] - 1
		if _gm.inventory[seasoning_key] <= 0:
			_gm.inventory.erase(seasoning_key)
		_gm.notify_inventory_changed()
	
	_applied_seasoning = seasoning_key
	var seasoning = _gm.seasoning.get_seasoning(seasoning_key)
	_item_name = _gm.craft.get_item(_item_key).get("name", _item_key) + " · " + seasoning.get("name", seasoning_key)
	_state = State.SEASONED
	queue_redraw()
	return true

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	
	# 背景
	var bg: Color
	match _state:
		State.EMPTY:
			bg = Color(0.08, 0.06, 0.04)
		State.HAS_ITEM:
			bg = Color(0.15, 0.13, 0.06)
		State.SEASONED:
			bg = Color(0.12, 0.10, 0.04)
	draw_rect(rect, bg)
	
	# 虚线边框
	var dash_color = Color(ThemeColors.AMBER_PRIMARY, 0.5 if _state == State.EMPTY else 0.8)
	var dash = 5.0
	var gap = 4.0
	var w = rect.size.x
	var h = rect.size.y
	
	var x = 0.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(min(x + dash, w), 0), dash_color)
		draw_line(Vector2(x, h), Vector2(min(x + dash, w), h), dash_color)
		x += dash + gap
	
	var y = 0.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(0, min(y + dash, h)), dash_color)
		draw_line(Vector2(w, y), Vector2(w, min(y + dash, h)), dash_color)
		y += dash + gap
	
	# 文字
	if _state == State.EMPTY:
		draw_string(ThemeDB.fallback_font, Vector2(8, 28), "放入成品", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 16)
	elif _state == State.HAS_ITEM or _state == State.SEASONED:
		draw_string(ThemeDB.fallback_font, Vector2(8, 28), _item_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 16)
```

**Tavern.tscn 改动：**
- SeasoningZone offset_left/right/top/bottom 调整，宽度给够（比如 width=200, height=120）
- 删掉 SeasoningPanel 节点及其 script 引用

---

### Task 2: CraftStation 新增拖拽路径

**Files:**
- Modify: `scripts/ui/craft_station.gd`

**改动点：**

1. 添加变量 `var _drag_result_key: String = ""`（拖拽中持有的成品 key）

2. ResultSlot 被拖时开始拖拽成品：
```gdscript
# 在 _try_pick_up() 中，hit_test ResultSlot 时：
if _hit_test(_result_slot, pos) and _result_slot.has_meta("item_key"):
	_drag_result_key = _result_slot.get_meta("item_key")
	_start_result_drag(pos)
	return
```

3. 新增 `_start_result_drag()`：显示拖拽中的成品色块

4. 拖放到 SeasoningZone：
```gdscript
# 在 _try_drop() 中：
if _hit_test(_seasoning_zone, pos) and _drag_result_key != "":
	_seasoning_zone.set_item(_drag_result_key)
	_clear_result_slot()
	_drag_result_key = ""
	_end_drag()
	return
```

5. 拖 SeasoningZone 的成品到顾客区：
```gdscript
# 从 SeasoningZone 发起拖拽：
if _hit_test(_seasoning_zone, pos) and _seasoning_zone.get_state() != SeasoningZone.State.EMPTY:
	_drag_result_key = _seasoning_zone.get_item_key()
	# 不立即 serve，拖到顾客区才 serve
	_start_result_drag(pos)
	return
```

6. 拖成品到顾客区上菜：
```gdscript
# 在 _try_drop() 中：
if _hit_test(_customer_area, pos) and _drag_result_key != "":
	var seasoning = _seasoning_zone.get_applied_seasoning() if _seasoning_zone.get_state() == SeasoningZone.State.SEASONED else ""
	serve_requested.emit(_drag_result_key, seasoning)
	_seasoning_zone.clear_item()
	_drag_result_key = ""
	_end_drag()
	return
```

7. `_start_result_drag(pos)`:
```gdscript
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
```

8. `_return_drag()` 扩展：如果拖的是成品（`_drag_result_key != ""`），放回 ResultSlot 或 SeasoningZone

---

### Task 3: 清理死代码

**Files:**
- Delete: `scripts/ui/seasoning_panel.gd`
- Modify: `scenes/ui/Tavern.tscn`（删 SeasoningPanel 节点和 ext_resource 引用）

---

### Task 4: 验证

- [ ] Godot 运行，TitleScreen → DayMap → Tavern
- [ ] 合成区产出成品，SeasoningZone 可见（虚线框+"放入成品"）
- [ ] 从 ResultSlot 拖成品到 SeasoningZone → 显示成品名
- [ ] 从快捷栏拖香料（sleep_powder等）到 SeasoningZone → 显示"成品名 · 香料名"
- [ ] 从快捷栏拖非香料材料到 SeasoningZone → 不响应（回弹）
- [ ] 从 SeasoningZone 拖成品到顾客区 → 上菜（带 seasoning_tag）
- [ ] 直接拖 ResultSlot 成品到顾客区 → 上菜（无香料）
- [ ] 修复后 0 error 0 warning
