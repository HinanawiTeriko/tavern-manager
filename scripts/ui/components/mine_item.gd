class_name MineItem
extends RigidBody2D

## 矿道场景的可拾取物件。生产美术按 item_tag 走纹理映射；
## 未映射物件保留旧 Polygon2D + Label 调试外观。
## kind: "observation"=捡起给一句台词；"contract"=捡起触发授予；"rubble"=可扒开的遮蔽物；
##       "backpack"=可倾倒的容器；"plain"=纯洒落物，无特殊效果。

const ITEM_TEXTURES := {
	"broken_arrow": "res://assets/ui/generated/investigation/mine_items/broken_arrow.png",
	"dented_shield": "res://assets/ui/generated/investigation/mine_items/dented_shield.png",
	"lost_boot": "res://assets/ui/generated/investigation/mine_items/lost_boot.png",
	"rubble": "res://assets/ui/generated/investigation/mine_items/rubble.png",
	"torn_backpack": "res://assets/ui/generated/investigation/mine_items/torn_backpack.png",
	"coins": "res://assets/ui/generated/investigation/mine_items/coins.png",
	"warhammer_token": "res://assets/ui/generated/investigation/mine_items/warhammer_token.png",
	"bloodied_paper": "res://assets/ui/generated/investigation/mine_items/bloodied_paper.png",
}
const SHADOW_TEXTURE := "res://assets/ui/generated/investigation/mine_background/mine_item_shadow.png"

@onready var _shape: CollisionShape2D = $Shape
@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $Label

var item_tag: String = ""
var kind: String = "plain"
var observation: String = ""
var _texture_visual: Sprite2D = null
var _shadow_visual: Sprite2D = null
var _shadow_offset_y: float = 0.0
var _uses_production_texture: bool = false


func setup(p_tag: String, p_kind: String, p_size: Vector2, p_color: Color, p_label: String, p_observation: String = "") -> void:
	item_tag = p_tag
	kind = p_kind
	observation = p_observation
	var hx := p_size.x * 0.5
	var hy := p_size.y * 0.5
	# 每个实例独立的碰撞形状；.tscn 里的 sub_resource 在多实例间默认共享，
	# 原地改 size 会牵连其他 MineItem，这里换成全新 RectangleShape2D 隔离。
	var rect := RectangleShape2D.new()
	rect.size = p_size
	_shape.shape = rect
	_visual.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	_visual.color = p_color
	_label.text = p_label
	_label.position = Vector2(-hx, -hy - 18.0)
	_apply_texture_visual(p_tag, p_size)


func _apply_texture_visual(p_tag: String, p_size: Vector2) -> void:
	var path: String = String(ITEM_TEXTURES.get(p_tag, ""))
	if path == "":
		_show_legacy_visual()
		return
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("MineItem texture missing or invalid for %s: %s" % [p_tag, path])
		_show_legacy_visual()
		return
	_ensure_texture_visual()
	_texture_visual.texture = texture
	_texture_visual.visible = true
	_texture_visual.z_index = _visual.z_index + 2
	var visual_size: Vector2 = texture.get_size()
	_texture_visual.scale = Vector2.ONE
	_visual.visible = false
	_label.visible = false
	_uses_production_texture = true
	_apply_shadow_visual(visual_size)


func _ensure_texture_visual() -> void:
	if _texture_visual != null:
		return
	_texture_visual = Sprite2D.new()
	_texture_visual.name = "TextureVisual"
	_texture_visual.centered = true
	_texture_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_texture_visual)


func _physics_process(_delta: float) -> void:
	_update_shadow_visual()


func _apply_shadow_visual(p_size: Vector2) -> void:
	var texture := load(SHADOW_TEXTURE) as Texture2D
	if texture == null:
		push_warning("MineItem shadow texture missing or invalid: %s" % SHADOW_TEXTURE)
		if _shadow_visual != null:
			_shadow_visual.visible = false
		return
	_ensure_shadow_visual()
	_shadow_visual.texture = texture
	_shadow_visual.visible = true
	_shadow_visual.z_index = _visual.z_index + 1
	_shadow_offset_y = p_size.y * 0.38
	var texture_size := texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var target_width := maxf(24.0, p_size.x * 1.05)
		var target_height := clampf(p_size.y * 0.18, 8.0, 18.0)
		_shadow_visual.scale = Vector2(target_width / texture_size.x, target_height / texture_size.y)
	else:
		_shadow_visual.scale = Vector2.ONE
	_update_shadow_visual()


func _ensure_shadow_visual() -> void:
	if _shadow_visual != null:
		return
	_shadow_visual = Sprite2D.new()
	_shadow_visual.name = "ShadowVisual"
	_shadow_visual.centered = true
	_shadow_visual.top_level = true
	_shadow_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_shadow_visual)


func _update_shadow_visual() -> void:
	if _shadow_visual == null:
		return
	_shadow_visual.visible = visible and _uses_production_texture
	if not _shadow_visual.visible:
		return
	_shadow_visual.global_position = global_position + Vector2(0.0, _shadow_offset_y)
	_shadow_visual.global_rotation = 0.0


func _show_legacy_visual() -> void:
	_uses_production_texture = false
	_visual.visible = true
	_label.visible = true
	if _texture_visual != null:
		_texture_visual.visible = false
	if _shadow_visual != null:
		_shadow_visual.visible = false
