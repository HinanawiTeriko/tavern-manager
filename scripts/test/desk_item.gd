class_name DeskItem
extends RigidBody2D

## 桌面物品（物理体）。掉出屏幕下方自动销毁。

const KILL_Y: float = 800.0

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
