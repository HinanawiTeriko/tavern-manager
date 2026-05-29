class_name Brewery
extends Node2D

## 酒桶（容器）：物品被"主动甩进"Mouth Area2D 才被接收。
## 力度不够（last_throw_speed < MIN_THROW_SPEED）→ 不消耗，物品穿过桶口落桌上。
## 成品穿过桶口不消耗（玩家拿成品试错的常规动作）。
## 接收的材料 key 攒进 _pending_keys，每接收一个刷新 ACCUM_WINDOW 滑动窗口。
## 窗口关闭 → query_recipe 匹配累积材料 → 命中 spawn 产出，未命中软兜底（材料已消耗、无产出）。

signal recipe_consumed(product_key: String)

const CONTAINER_KEY := "barrel"
const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const MIN_THROW_SPEED := 250.0   # 起始阈值，验收 walkthrough 时按手感调
const ACCUM_WINDOW := 1.5        # 多材料累积滑动窗口（秒）

@onready var _mouth: Area2D = $Mouth
@onready var _output_anchor: Marker2D = $OutputAnchor

var _items_parent: Node2D = null
var _pending_keys: Array[String] = []
var _timer: Timer = null


func _ready() -> void:
	assert(GameManager.craft != null, "[Brewery] GameManager.craft 未就绪")
	_items_parent = get_parent().get_node("Items")
	assert(_items_parent != null, "[Brewery] 未找到父节点下的 'Items' 节点")
	_mouth.body_entered.connect(_on_mouth_body_entered)
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_window_closed)


func _on_mouth_body_entered(body: Node) -> void:
	if not body is DeskItem:
		return
	var item: DeskItem = body
	if item.item_key == "":
		return
	if GameManager.craft.is_product(item.item_key):
		return
	if item.last_throw_speed < MIN_THROW_SPEED:
		return
	# 够力 → 接收
	_pending_keys.append(item.item_key)
	item.queue_free()
	_timer.start(ACCUM_WINDOW)   # 滑动窗口：每接收一个就刷新计时


func _on_window_closed() -> void:
	var product_key: String = GameManager.craft.query_recipe(
		CONTAINER_KEY, _pending_keys)
	_pending_keys.clear()
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
