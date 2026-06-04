class_name MapPointMarker
extends Area2D

## 地图上的单个地点点：圆点(程序化绘制) + 下方名字 Label。
## 点击发 clicked(location_id)；悬停/选中改变外观。体力不足不在此变灰（前往时拦下）。

signal clicked(location_id: String)

const RADIUS := 18.0
const COLOR_NORMAL := Color(0.85, 0.7, 0.35)      # 琥珀
const COLOR_HOVER := Color(1.0, 0.88, 0.5)
const COLOR_SELECTED := Color(1.0, 0.95, 0.7)
const RING_COLOR := Color(1.0, 0.95, 0.7, 0.9)

var location_id: String = ""

var _hovered: bool = false
var _selected: bool = false
var _label: Label


func setup(loc: Dictionary) -> void:
	location_id = String(loc.get("id", ""))
	var pos_arr: Array = loc.get("pos", [1000, 700])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	if _label != null:
		_label.text = String(loc.get("name", ""))


func _ready() -> void:
	# 圆形碰撞区，半径略大于视觉圆点，便于点击
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS + 6.0
	shape.shape = circle
	add_child(shape)

	_label = Label.new()
	_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_label.add_theme_font_size_override("font_size", 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-60, RADIUS + 6)
	_label.custom_minimum_size = Vector2(120, 0)
	_label.size = Vector2(120, 24)
	add_child(_label)

	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	input_event.connect(_on_input_event)


func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(location_id)


func _draw() -> void:
	var fill := COLOR_NORMAL
	if _selected:
		fill = COLOR_SELECTED
	elif _hovered:
		fill = COLOR_HOVER
	draw_circle(Vector2.ZERO, RADIUS, fill)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, Color(0.2, 0.15, 0.1, 0.9), 3.0, true)
	if _selected:
		draw_arc(Vector2.ZERO, RADIUS + 8, 0, TAU, 40, RING_COLOR, 3.0, true)
