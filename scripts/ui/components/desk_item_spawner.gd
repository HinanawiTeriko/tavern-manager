class_name DeskItemSpawner
extends RefCounted

## 可复用工具：从材料 key 生成 DeskItem RigidBody2D 并自动着色 + 打 meta 标签。
##
## 用法：
##   var item := DeskItemSpawner.spawn_at(pos, "malt", $World/Items, craft_system)
##   # 或手动指定颜色和名称：
##   var item := DeskItemSpawner.spawn_with_color(pos, "malt", "麦芽", Color.RED, $World/Items)

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")


## 使用 CraftSystem 数据生成 DeskItem（自动从 item 定义读取颜色和名称）
static func spawn_at(pos: Vector2, material_key: String, parent: Node, craft_system) -> DeskItem:
	var item_data: Dictionary = craft_system.get_item(material_key)
	var color := Color.GRAY
	var col_arr: Array = item_data.get("color", [])
	if col_arr is Array and col_arr.size() >= 3:
		color = Color(col_arr[0], col_arr[1], col_arr[2])
	var display_name: String = item_data.get("name", material_key)
	return spawn_with_color(pos, material_key, display_name, color, parent)


## 直接指定颜色和名称生成 DeskItem
static func spawn_with_color(pos: Vector2, material_key: String, display_name: String, color: Color, parent: Node) -> DeskItem:
	var item: DeskItem = DESK_ITEM_SCENE.instantiate()
	parent.add_child(item)
	item.set_color(color)
	item.set_meta("material_key", material_key)
	item.global_position = pos
	item.z_index = 100  # 确保粒子/物品渲染在所有 UI 之上
	item.contact_monitor = true       # 启用物品间碰撞检测
	item.max_contacts_reported = 4

	# 动态添加文字标签
	var label := Label.new()
	label.text = display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.size = Vector2(60, 60)
	label.position = Vector2(-30, -30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(label)

	return item
