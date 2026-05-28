class_name DeskItem
extends RigidBody2D

var _pending_color: Color = Color.WHITE

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	_visual.color = _pending_color


func set_color(c: Color) -> void:
	_pending_color = c
	if is_node_ready():
		_visual.color = c
