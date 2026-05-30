class_name Brewery
extends RigidBody2D

## 酒桶（容器，物理体）。默认 freeze 悬停桌上；抓起解冻可移动+可摇；松手在落点重冻。
## 杯状侧壁（左斜壁/右斜壁/桶底）由 .tscn 提供，顶部留口；甩偏撞壁弹开，甩准从 Mouth 入桶。
## 收料：物品够速度入 Mouth → 攒进 _pending_keys（不再自动产出，出酒见后续摇晃任务）。
## 成品穿过桶口不消耗（玩家拿成品试错的常规动作）。

signal recipe_consumed(product_key: String)

const CONTAINER_KEY := "barrel"
const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const MIN_THROW_SPEED := 250.0   # 进桶瞬间速度阈值；够力才收料

@onready var _mouth: Area2D = $Mouth
@onready var _output_anchor: Marker2D = $OutputAnchor

var _items_parent: Node2D = null
var _pending_keys: Array[String] = []


func _ready() -> void:
	assert(GameManager.craft != null, "[Brewery] GameManager.craft 未就绪")
	_items_parent = get_parent().get_node("Items")
	assert(_items_parent != null, "[Brewery] 未找到父节点下的 'Items' 节点")
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	gravity_scale = 0.0           # 解冻后靠拖拽/重冻定位，不自由下坠
	lock_rotation = true          # 摇晃只用水平平移，不让桶自转
	_mouth.body_entered.connect(_on_mouth_body_entered)


func _on_mouth_body_entered(body: Node) -> void:
	if not body is DeskItem:
		return
	var item: DeskItem = body
	if item.item_key == "":
		return
	if GameManager.craft.is_product(item.item_key):
		return
	if item.linear_velocity.length() < MIN_THROW_SPEED:
		return
	_pending_keys.append(item.item_key)
	item.queue_free()


func _spawn_product(product_key: String) -> void:
	var product: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_parent.add_child(product)
	product.global_position = _output_anchor.global_position
	var item_data: Dictionary = GameManager.craft.get_item(product_key)
	product.set_item(product_key, item_data)


## ⚠️ 临时占位：当前只做解冻/重冻。真正的摇晃计数 + 必须摇够才出酒
## 将在后续「摇晃酿造」任务中替换这两个函数的实现（届时 begin 启动摇晃采样、
## end 结算 _try_brew）。本任务阶段酒桶刻意不产出。
func begin_shake_session() -> void:
	freeze = false


func end_shake_session() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
