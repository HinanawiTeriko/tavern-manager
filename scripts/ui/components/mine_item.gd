class_name MineItem
extends RigidBody2D

## 矿道场景的占位可拾取物件。外观=纯色方块+文字标签；kind 决定捡起时的行为。
## kind: "observation"=捡起给一句台词；"contract"=捡起触发授予；"rubble"=可扒开的遮蔽物；
##       "backpack"=可倾倒的容器；"plain"=纯洒落物，无特殊效果。

@onready var _shape: CollisionShape2D = $Shape
@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $Label

var item_tag: String = ""
var kind: String = "plain"
var observation: String = ""


func setup(p_tag: String, p_kind: String, p_size: Vector2, p_color: Color, p_label: String, p_observation: String = "") -> void:
	item_tag = p_tag
	kind = p_kind
	observation = p_observation
	var hx := p_size.x * 0.5
	var hy := p_size.y * 0.5
	# 每个实例独立的碰撞形状——.tscn 里的 sub_resource 在多实例间默认共享，
	# 原地改 size 会牵连其他 MineItem；这里换成全新 RectangleShape2D 隔离。
	var rect := RectangleShape2D.new()
	rect.size = p_size
	_shape.shape = rect
	_visual.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	_visual.color = p_color
	_label.text = p_label
	_label.position = Vector2(-hx, -hy - 18.0)
