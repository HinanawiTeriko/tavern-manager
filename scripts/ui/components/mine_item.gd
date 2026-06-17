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
	"oil_lamp": "res://assets/ui/generated/investigation/toby_lodging/items/oil_lamp.png",
	"hard_bread": "res://assets/ui/generated/investigation/toby_lodging/items/hard_bread.png",
	"oversized_coat": "res://assets/ui/generated/investigation/toby_lodging/items/oversized_coat.png",
	"contract_fragment_a": "res://assets/ui/generated/investigation/toby_lodging/items/contract_fragment_a.png",
	"contract_fragment_b": "res://assets/ui/generated/investigation/toby_lodging/items/contract_fragment_b.png",
	"contract_fragment_c": "res://assets/ui/generated/investigation/toby_lodging/items/contract_fragment_c.png",
	"contract_fragment_pair": "res://assets/ui/generated/investigation/toby_lodging/items/contract_fragment_pair.png",
	"contract_complete": "res://assets/ui/generated/investigation/toby_lodging/items/contract_complete.png",
	"clearing_ryan_name": "res://assets/ui/generated/investigation/clearing_table/items/clearing_ryan_name.png",
	"clearing_north_mine": "res://assets/ui/generated/investigation/clearing_table/items/clearing_north_mine.png",
	"clearing_unreturned": "res://assets/ui/generated/investigation/clearing_table/items/clearing_unreturned.png",
	"clearing_payout_slip": "res://assets/ui/generated/investigation/clearing_table/items/clearing_payout_slip.png",
	"clearing_toby_name": "res://assets/ui/generated/investigation/clearing_table/items/clearing_toby_name.png",
	"clearing_blacktooth_batch": "res://assets/ui/generated/investigation/clearing_table/items/clearing_blacktooth_batch.png",
	"clearing_high_pay": "res://assets/ui/generated/investigation/clearing_table/items/clearing_high_pay.png",
	"clearing_temp_name": "res://assets/ui/generated/investigation/clearing_table/items/clearing_temp_name.png",
	"clearing_mira_name": "res://assets/ui/generated/investigation/clearing_table/items/clearing_mira_name.png",
	"clearing_supply_contract": "res://assets/ui/generated/investigation/clearing_table/items/clearing_supply_contract.png",
	"clearing_deposit_token": "res://assets/ui/generated/investigation/clearing_table/items/clearing_deposit_token.png",
}
const ITEM_COLLISION_PROFILES := {
	"broken_arrow": {"size": Vector2(108, 24), "offset": Vector2(0, 2)},
	"dented_shield": {"size": Vector2(88, 60), "offset": Vector2(0, 2)},
	"lost_boot": {"size": Vector2(78, 42), "offset": Vector2(0, 5)},
	"rubble": {"size": Vector2(306, 112), "offset": Vector2(0, 20)},
	"torn_backpack": {"size": Vector2(104, 72), "offset": Vector2(0, 8)},
	"coins": {"size": Vector2(58, 22), "offset": Vector2(0, 2)},
	"warhammer_token": {"size": Vector2(50, 30), "offset": Vector2(0, 2)},
	"bloodied_paper": {"size": Vector2(58, 44), "offset": Vector2(0, 0)},
	"oil_lamp": {"size": Vector2(44, 70), "offset": Vector2(0, 8)},
	"hard_bread": {"size": Vector2(60, 30), "offset": Vector2(0, 4)},
	"oversized_coat": {"size": Vector2(140, 76), "offset": Vector2(0, 10)},
	"contract_fragment_a": {"size": Vector2(48, 34), "offset": Vector2(0, 2)},
	"contract_fragment_b": {"size": Vector2(46, 36), "offset": Vector2(0, 2)},
	"contract_fragment_c": {"size": Vector2(52, 32), "offset": Vector2(0, 2)},
	"contract_fragment_pair": {"size": Vector2(78, 46), "offset": Vector2(0, 2)},
	"contract_complete": {"size": Vector2(100, 62), "offset": Vector2(0, 2)},
	"clearing_ryan_name": {"size": Vector2(160, 62), "offset": Vector2(0, 2)},
	"clearing_north_mine": {"size": Vector2(150, 84), "offset": Vector2(0, 4)},
	"clearing_unreturned": {"size": Vector2(120, 62), "offset": Vector2(0, 2)},
	"clearing_payout_slip": {"size": Vector2(112, 60), "offset": Vector2(0, 2)},
	"clearing_toby_name": {"size": Vector2(160, 62), "offset": Vector2(0, 2)},
	"clearing_blacktooth_batch": {"size": Vector2(150, 84), "offset": Vector2(0, 4)},
	"clearing_high_pay": {"size": Vector2(120, 62), "offset": Vector2(0, 2)},
	"clearing_temp_name": {"size": Vector2(160, 62), "offset": Vector2(0, 2)},
	"clearing_mira_name": {"size": Vector2(120, 62), "offset": Vector2(0, 2)},
	"clearing_supply_contract": {"size": Vector2(104, 124), "offset": Vector2(0, 4)},
	"clearing_deposit_token": {"size": Vector2(86, 104), "offset": Vector2(0, 4)},
}

@onready var _shape: CollisionShape2D = $Shape
@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $Label

var item_tag: String = ""
var kind: String = "plain"
var observation: String = ""
var _texture_visual: Sprite2D = null
var _uses_production_texture: bool = false


func setup(p_tag: String, p_kind: String, p_size: Vector2, p_color: Color, p_label: String, p_observation: String = "") -> void:
	item_tag = p_tag
	kind = p_kind
	observation = p_observation
	var collision_size := p_size
	var collision_offset := Vector2.ZERO
	var profile: Dictionary = ITEM_COLLISION_PROFILES.get(p_tag, {})
	if not profile.is_empty():
		collision_size = profile.get("size", p_size)
		collision_offset = profile.get("offset", Vector2.ZERO)
	var hx := collision_size.x * 0.5
	var hy := collision_size.y * 0.5
	# 每个实例独立的碰撞形状；.tscn 里的 sub_resource 在多实例间默认共享，
	# 原地改 size 会牵连其他 MineItem，这里换成全新 RectangleShape2D 隔离。
	var rect := RectangleShape2D.new()
	rect.size = collision_size
	_shape.shape = rect
	_shape.position = collision_offset
	_visual.position = collision_offset
	_visual.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	_visual.color = p_color
	_label.text = p_label
	_label.position = collision_offset + Vector2(-hx, -hy - 18.0)
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
	_texture_visual.scale = Vector2.ONE
	_visual.visible = false
	_label.visible = false
	_uses_production_texture = true


func _ensure_texture_visual() -> void:
	if _texture_visual != null:
		return
	_texture_visual = Sprite2D.new()
	_texture_visual.name = "TextureVisual"
	_texture_visual.centered = true
	_texture_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_texture_visual)


func _show_legacy_visual() -> void:
	_uses_production_texture = false
	_visual.visible = true
	_label.visible = true
	if _texture_visual != null:
		_texture_visual.visible = false
