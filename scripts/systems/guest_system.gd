class_name GuestSystem
extends RefCounted

signal guest_arrived(guest)
signal guest_left()
signal patience_low()
signal normal_orders_completed()

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
var _normal_order_limit: int = 0
var _normal_orders_spawned: int = 0
var _normal_completion_emitted: bool = false
var _reaction_pools: Dictionary = {}

func _init(available_orders_callable: Callable) -> void:
	_get_available_orders = available_orders_callable
	_rng.randomize()
	_load_reaction_pools()

func _load_reaction_pools() -> void:
	var file = FileAccess.open("res://data/guest_reactions.json", FileAccess.READ)
	if file == null:
		push_error("[GuestSystem] guest_reactions.json 未找到")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null or not data is Dictionary:
		push_error("[GuestSystem] guest_reactions.json 解析失败或格式错误")
		return
	_reaction_pools = data
	print("[GuestSystem] 加载 ", _reaction_pools.size(), " 组反应台词")

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
	if _normal_orders_spawned >= _normal_order_limit:
		_emit_normal_orders_completed()
		return
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
	_normal_orders_spawned += 1
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
	var departed = current_guest
	guest_left.emit()
	current_guest = null
	has_guest = false
	_spawn_timer = 0.0
	_next_spawn = _rng.randf() * 2.0 + 2.0
	if departed != null and departed.type == GuestData.GuestType.NORMAL \
		and _normal_orders_spawned >= _normal_order_limit:
		_emit_normal_orders_completed()

func configure_night(normal_order_limit: int) -> void:
	_normal_order_limit = maxi(normal_order_limit, 0)
	_normal_orders_spawned = 0
	_normal_completion_emitted = false

func remaining_normal_orders() -> int:
	return maxi(_normal_order_limit - _normal_orders_spawned, 0)

func _emit_normal_orders_completed() -> void:
	if _normal_completion_emitted:
		return
	_normal_completion_emitted = true
	normal_orders_completed.emit()

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

## 取某结果（success/fail_wrong/fail_weird/impatient）的随机客人反应台词。
## npc_id 预留 per-npc override，暂未实现内容。池缺失时返回安全兜底。
func get_reaction_line(outcome: String, _npc_id: String = "") -> String:
	var pool = _reaction_pools.get(outcome, [])
	if pool is Array and pool.size() > 0:
		return String(pool[_rng.randi() % pool.size()])
	return "「……」"
