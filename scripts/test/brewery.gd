class_name Brewery
extends RigidBody2D

## Barrel container body. It keeps normal gravity, can be grabbed/shaken,
## and continues as a physics body after release.
signal recipe_consumed(product_key: String)

const CONTAINER_KEY := "barrel"
const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const BARREL_MASS := 2.5
const BARREL_LINEAR_DAMP := 0.8
const BARREL_ANGULAR_DAMP := 4.0
const MOUTH_INNER_HALF_WIDTH := 24.0
const MOUTH_TOP_Y := -64.0
const MOUTH_BOTTOM_Y := -34.0

@onready var _mouth: Area2D = $Mouth
@onready var _output_anchor: Marker2D = $OutputAnchor

var _items_parent: Node2D = null
var _pending_keys: Array[String] = []


func _ready() -> void:
	assert(GameManager.craft != null, "[Brewery] GameManager.craft is not ready")
	_items_parent = get_parent().get_node("Items")
	assert(_items_parent != null, "[Brewery] Missing sibling Items node")
	mass = BARREL_MASS
	freeze = false
	gravity_scale = 1.0
	linear_damp = BARREL_LINEAR_DAMP
	angular_damp = BARREL_ANGULAR_DAMP
	lock_rotation = false
	_mouth.body_entered.connect(_on_mouth_body_entered)


func _physics_process(_delta: float) -> void:
	for body in _mouth.get_overlapping_bodies():
		_try_accept_mouth_body(body)


func _on_mouth_body_entered(body: Node) -> void:
	_try_accept_mouth_body(body)


func _try_accept_mouth_body(body: Node) -> void:
	if not body is DeskItem:
		return
	var item: DeskItem = body
	if item.is_queued_for_deletion():
		return
	if item.item_key == "":
		return
	if GameManager.craft.is_product(item.item_key):
		return
	if not _is_item_inside_mouth_opening(item):
		return
	_pending_keys.append(item.item_key)
	item.queue_free()


func _is_item_inside_mouth_opening(item: DeskItem) -> bool:
	var local_pos: Vector2 = to_local(item.global_position)
	return absf(local_pos.x) <= MOUTH_INNER_HALF_WIDTH \
		and local_pos.y >= MOUTH_TOP_Y \
		and local_pos.y <= MOUTH_BOTTOM_Y


func _spawn_product(product_key: String) -> void:
	var product: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_parent.add_child(product)
	product.global_position = _output_anchor.global_position
	var item_data: Dictionary = GameManager.craft.get_item(product_key)
	product.set_item(product_key, item_data)


## Placeholder for the later shake-brewing task. For now these only wake the
## barrel for dragging and keep it dynamic when released.
func begin_shake_session() -> void:
	freeze = false
	lock_rotation = false
	sleeping = false


func end_shake_session() -> void:
	freeze = false
	lock_rotation = false
	sleeping = false
