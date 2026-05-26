class_name GuestSystem
extends RefCounted

signal guest_arrived(guest)
signal guest_left()
signal patience_low()

const _normal_names: Array = [
	"铁锤格鲁姆", "冰霜莱拉", "暗影德恩", "圣光凯尔", "疾风维克斯",
	"暗夜尼克斯", "山丘伯林", "银弦艾莉亚", "怒血索恩", "黎明扎拉",
	"磐石芬恩", "毒刃鲁克"
]

var current_guest = null
var has_guest: bool = false

var _get_available_orders: Callable
var _rng = RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
var _next_spawn: float = 2.0

var guests_served_today: int = 0
var orders_success: int = 0
var orders_failed: int = 0

func _init(available_orders_callable: Callable) -> void:
	_get_available_orders = available_orders_callable
	_rng.randomize()

func update(dt: float, has_guest_flag: bool, menu_open: bool) -> void:
	if not has_guest_flag and not menu_open:
		_spawn_timer += dt
		if _spawn_timer >= _next_spawn:
			_spawn_timer = 0.0
			_next_spawn = _rng.randf() * 3.0 + 2.0
			_spawn_normal()

	if has_guest_flag and not menu_open and current_guest != null:
		var prev_patience: float = current_guest.patience
		current_guest.patience -= dt
		if current_guest.patience <= 15.0 and prev_patience > 15.0:
			patience_low.emit()
		if current_guest.patience <= 0.0:
			record_order_failed()
			clear_guest()

func _spawn_normal() -> void:
	var orders: Array = _get_available_orders.call()
	if orders.size() == 0:
		return
	var g = GuestData.new()
	g.guest_name = _normal_names[_rng.randi() % _normal_names.size()]
	g.type = GuestData.GuestType.NORMAL
	g.order_key = orders[_rng.randi() % orders.size()]
	g.patience = GuestData.BASE_PATIENCE
	g.has_dialogue = false
	current_guest = g
	has_guest = true
	guest_arrived.emit(g)

func spawn_important(npc_id: String, order_key: String) -> void:
	var g = GuestData.new()
	g.guest_name = npc_id
	g.type = GuestData.GuestType.IMPORTANT
	g.order_key = order_key
	g.npc_id = npc_id
	g.patience = GuestData.BASE_PATIENCE * 1.5
	g.has_dialogue = true
	current_guest = g
	has_guest = true
	guest_arrived.emit(g)

func clear_guest() -> void:
	guest_left.emit()
	current_guest = null
	has_guest = false
	_spawn_timer = 0.0
	_next_spawn = _rng.randf() * 2.0 + 2.0

func record_guest_served() -> void:
	guests_served_today += 1

func record_order_success() -> void:
	orders_success += 1

func record_order_failed() -> void:
	orders_failed += 1

func reset_daily() -> void:
	guests_served_today = 0
	orders_success = 0
	orders_failed = 0
