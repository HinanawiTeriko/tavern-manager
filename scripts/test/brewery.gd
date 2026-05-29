class_name Brewery
extends Node2D

## 酒桶（容器）：物品掉入 Mouth Area2D 触发配方匹配。
## 命中 → 销毁输入物 + 在 OutputAnchor spawn 产出物理体。
## 未命中 → 销毁输入物（"材料消耗"软兜底），不 spawn 产出。

signal recipe_consumed(product_key: String)

const CONTAINER_KEY := "barrel"
const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")

@onready var _mouth: Area2D = $Mouth
@onready var _output_anchor: Marker2D = $OutputAnchor

var _items_parent: Node2D = null


func _ready() -> void:
	assert(GameManager.craft != null, "[Brewery] GameManager.craft 未就绪")
	_items_parent = get_parent().get_node("Items")
	_mouth.body_entered.connect(_on_mouth_body_entered)


func _on_mouth_body_entered(body: Node) -> void:
	if not body is DeskItem:
		return
	var item: DeskItem = body
	if item.item_key == "":
		return
	var product_key: String = GameManager.craft.query_recipe(
		CONTAINER_KEY, [item.item_key])
	item.queue_free()
	if product_key == "":
		return
	_spawn_product(product_key)
	recipe_consumed.emit(product_key)


func _spawn_product(product_key: String) -> void:
	var product: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_parent.add_child(product)
	product.global_position = _output_anchor.global_position
	var item_data: Dictionary = GameManager.craft.get_item(product_key)
	product.set_item(product_key, item_data)
