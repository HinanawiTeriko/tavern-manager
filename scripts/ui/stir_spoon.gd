class_name StirSpoon
extends RigidBody2D

## 搅拌勺：常驻物理道具。抓起后把勺尖伸进炖锅口内来回搅，勺的移动速度累积到
## 锅的 required_stir 才出菜。本体只负责"是一把可抓的勺 + 暴露勺尖位置"，
## 搅拌进度由 KitchenContainer 读取本体 linear_velocity 累积（复用 DragController 钉拽手感）。

const RESET_Y: float = 800.0
const SUBMERGED_Z_INDEX := -1
const TEXTURE_COLLISION_BOUNDS := preload("res://scripts/ui/texture_collision_bounds.gd")

@onready var _tip: Marker2D = $Tip
@onready var _shape: CollisionShape2D = $Shape
@onready var _art: Sprite2D = $Art

var _home_position: Vector2
var _surface_z_index: int


func _ready() -> void:
	mass = 0.8
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 6.0
	lock_rotation = false
	can_sleep = false   # 常醒着，避免静置后抓起不跟手
	_home_position = global_position
	_surface_z_index = z_index
	_fit_collision_to_art_bounds()


func _physics_process(_delta: float) -> void:
	if global_position.y > RESET_Y:
		_return_home()


## 勺尖（浸入汤里的那一端）的世界坐标，供锅判定是否在锅口内。
func tip_global_position() -> Vector2:
	return _tip.global_position if _tip != null else global_position


func set_submerged(submerged: bool) -> void:
	z_index = SUBMERGED_Z_INDEX if submerged else _surface_z_index


func _return_home() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	global_position = _home_position


func _fit_collision_to_art_bounds() -> void:
	var bounds: Rect2 = TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(_art)
	if bounds.size == Vector2.ZERO:
		return
	var capsule := CapsuleShape2D.new()
	capsule.radius = bounds.size.x * 0.5
	capsule.height = maxf(bounds.size.y, capsule.radius * 2.0)
	_shape.shape = capsule
	_shape.position = bounds.get_center()
