class_name DeskItem
extends RigidBody2D

## 桌面物品（物理体）。掉出屏幕下方自动销毁。

const KILL_Y: float = 800.0

var item_key: String = ""
var _pending_color: Color = Color.WHITE

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	_visual.color = _pending_color


func _physics_process(_delta: float) -> void:
	if global_position.y > KILL_Y:
		queue_free()


func set_color(c: Color) -> void:
	_pending_color = c
	if is_node_ready():
		_visual.color = c


func set_item(key: String, item_data: Dictionary) -> void:
	item_key = key
	var rgb: Array = item_data.get("color", [0.8, 0.8, 0.8])
	set_color(Color(rgb[0], rgb[1], rgb[2]))
