class_name SandboxServe
extends Node2D

## 沙盘测试桩：把 gravity_test 接到真实 GameManager 上菜 / 对话管线。
## - 充当 GameManager._tavern_view（鸭子接口，实现其会调用的方法）
## - 生成一个测试重要 NPC（默认 Mira / Day4 / wine，成功路径叙事连贯）
## - 监听 DragController.drag_ended：成品落入 CustomerArea 即 request_serve
## 仅测试场景使用：直接给 GameManager._tavern_view 赋值（见 spec §5 取舍）。

@export var test_npc_id: String = "mira"
@export var test_day: int = 4
@export var test_order_key: String = "wine"

@onready var _drag_ctrl: DragController = $"../DragCtrl"
@onready var _customer_area: Area2D = $CustomerArea
@onready var _order_label: Label = $UILayer/Root/OrderLabel
@onready var _message_label: Label = $UILayer/Root/MessageLabel
@onready var _topbar_label: Label = $UILayer/Root/TopBarLabel


func _ready() -> void:
	GameManager._tavern_view = self
	_drag_ctrl.drag_ended.connect(_on_drag_ended)
	_spawn_test_guest()
	_refresh_topbar()


func _spawn_test_guest() -> void:
	GameManager.economy.current_day = test_day
	GameManager.guests.spawn_important(test_npc_id, test_order_key)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not GameManager.guests.has_guest:
			_spawn_test_guest()


func _on_drag_ended(body: DeskItem) -> void:
	if body == null or body.item_key == "":
		return
	if not GameManager.craft.is_product(body.item_key):
		return
	if not _customer_area.get_overlapping_bodies().has(body):
		return
	var speed: float = body.linear_velocity.length()
	GameManager.request_serve(body.item_key, {"serve_drop_speed": speed})
	body.queue_free()


# ================================================================
#  GameManager._tavern_view 鸭子接口
# ================================================================

func show_customer(display_name: String, item_name: String, _npc_id: String) -> void:
	_order_label.text = "%s 想要：%s" % [display_name, item_name]

func hide_customer() -> void:
	_order_label.text = "（无客人，按 R 生成）"

func set_dialogue_mode(_on: bool) -> void:
	pass

func show_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)

func update_top_bar(gold: int, rep: int, day: int, max_days: int) -> void:
	_topbar_label.text = "金币 %d   声望 %d   Day %d/%d" % [gold, rep, day, max_days]

func update_timer(_ratio: float) -> void:
	pass

func is_menu_open() -> bool:
	return false

func toggle_menu() -> void:
	pass


func _refresh_topbar() -> void:
	var e = GameManager.economy
	update_top_bar(e.gold, e.reputation, e.current_day, EconomySystem.MAX_DAYS)
