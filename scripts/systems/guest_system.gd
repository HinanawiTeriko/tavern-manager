class_name GuestSystem
extends RefCounted

signal guest_arrived(guest)
signal guest_left()
signal patience_low()
signal normal_orders_completed()
signal guest_abandoned()
signal all_guests_served()

class CustomerRecord extends RefCounted:
	var customer_id: String        # 唯一ID
	var display_name: String       # 显示名称
	var template_id: String        # NPC模板ID
	var attributes: Dictionary     # 属性
	var first_seen_day: int        # 初登场天数
	var last_seen_day: int         # 最后一次光顾天数
	var visit_count: int           # 光顾次数
	var favorite_order: String     # 最爱点的菜（key）

var current_guest: GuestData = null
var has_guest: bool = false

var _get_menu_items: Callable     # 获取当日菜单的回调（替代原 _get_available_orders）
var _rng = RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
var _next_spawn: float = 2.0

var guests_served_today: int = 0
var orders_success: int = 0
var orders_failed: int = 0

# 客流系统
var _daily_total_guests: int = 0      # 当日总客人数（含已生成和即将生成）
var _daily_spawned: int = 0           # 已生成数（普通客人）
var _daily_cleared: int = 0           # 已离场数（所有客人）
var _daily_important_spawned: bool = false
var _all_completion_emitted: bool = false
var _normal_completion_emitted: bool = false

# 客户持久化
var _customer_db: Dictionary = {}     # customer_id -> CustomerRecord
var _customer_pool: Array = []        # 模板池（加载自 npc_pool.json）
var _reaction_pools: Dictionary = {}
var _next_customer_seq: int = 1

# 回头客追踪（每天用完刷新）
var _return_candidates: Array = []

const BASE_PATIENCE: float = 60.0

# ── 对数客流公式 ──
# 基础量 = floor(ln(day+1) * 4) + 1
# day 1: floor(ln2*4)+1 = floor(2.77)+1 = 3
# day 3: floor(ln4*4)+1 = floor(5.54)+1 = 6
# day 7: floor(ln8*4)+1 = floor(8.31)+1 = 9
# day 12: floor(ln13*4)+1 = floor(10.25)+1 = 11
func _daily_customer_base(day: int) -> int:
	return int(floor(log(max(day + 1, 2)) * 4.0)) + 1

func _init(menu_items_callable: Callable) -> void:
	_get_menu_items = menu_items_callable
	_rng.randomize()
	_load_reaction_pools()
	_load_npc_pool()

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

func _load_npc_pool() -> void:
	var file = FileAccess.open("res://data/npc_pool.json", FileAccess.READ)
	if file == null:
		push_warning("[GuestSystem] npc_pool.json 未找到，使用硬编码名字池")
		return
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		push_error("[GuestSystem] npc_pool.json 解析失败")
		return
	_customer_pool = data.get("templates", [])
	print("[GuestSystem] 加载 ", _customer_pool.size(), " 种NPC模板")

# ── 每日配置 ──

func configure_night(normal_order_limit: int, day: int = 0) -> void:
	# normal_order_limit 由公式计算的每日基础客流数
	# 加上回头客数量构成实际总数
	if day <= 0:
		day = _get_current_day()
	var base_count: int = maxi(normal_order_limit, _daily_customer_base(day))

	# 回头客：从已有顾客库中按概率选取
	_return_candidates = _build_return_list(day)
	var return_count: int = min(_return_candidates.size(), int(ceil(base_count * 0.4)))  # 最多40%回头客

	_daily_total_guests = base_count + return_count
	_daily_spawned = 0
	_daily_cleared = 0
	_daily_important_spawned = false
	_normal_completion_emitted = false
	_all_completion_emitted = false
	_spawn_timer = 0.0
	_next_spawn = 2.0

	print("[GuestSystem] Day%d 客流配置: 基础%d + 回头客%d = 共%d人" % [day, base_count, return_count, _daily_total_guests])

func _get_current_day() -> int:
	# 通过 Engine.get_main_loop() 获取 SceneTree 以访问 GameManager
	var main_loop = Engine.get_main_loop()
	if main_loop != null and main_loop is SceneTree:
		var gm = main_loop.root.get_node_or_null("GameManager")
		if gm != null:
			return int(gm.economy.current_day)
	return 1

func _build_return_list(day: int) -> Array:
	# 构建当回头客候选列表（按概率抽取）
	var candidates: Array = []
	for cid in _customer_db:
		var rec: CustomerRecord = _customer_db[cid]
		if rec.last_seen_day >= day:
			continue  # 今天已经来过了
		# 最近来过（3天内）的概率更高
		var days_since := day - rec.last_seen_day
		var chance: float = 1.0 / max(days_since, 1) * 0.6
		if _rng.randf() < chance:
			candidates.append(rec)
	return candidates

# ── 每帧更新 ──

func update(dt: float, has_guest_flag: bool, menu_open: bool) -> void:
	# 仅在准备阶段结束后的营业阶段刷客人
	if not has_guest_flag and not menu_open:
		_spawn_timer += dt
		if _spawn_timer >= _next_spawn:
			_spawn_timer = 0.0
			_next_spawn = _rng.randf() * 3.0 + 2.0
			_try_spawn_next()

	if has_guest_flag and not menu_open and current_guest != null:
		var prev_patience: float = current_guest.patience
		current_guest.patience -= dt
		if current_guest.patience <= 15.0 and prev_patience > 15.0:
			patience_low.emit()
		if current_guest.patience <= 0.0:
			record_order_failed()
			guest_abandoned.emit()

func _try_spawn_next() -> void:
	# 首先完成重要NPC生成（保留原逻辑）
	# 重要NPC由 GM 调用 spawn_important 直接生成

	if _daily_spawned >= _daily_total_guests:
		_emit_normal_orders_completed()
		return

	var menu_items: Array[Dictionary] = _get_menu_items.call()
	if menu_items.is_empty():
		return

	# 决定生成新客还是回头客
	var use_return: bool = false
	if _return_candidates.size() > 0 and _rng.randf() < 0.4:
		use_return = true

	if use_return:
		var idx = _rng.randi() % _return_candidates.size()
		var rec: CustomerRecord = _return_candidates[idx]
		_return_candidates.remove_at(idx)
		_spawn_return_customer(rec, menu_items)
	else:
		_spawn_new_customer(menu_items)

func _spawn_new_customer(menu_items: Array[Dictionary]) -> void:
	var g := GuestData.new()
	var template: Dictionary
	var rec: CustomerRecord

	if _customer_pool.size() > 0:
		template = _customer_pool[_rng.randi() % _customer_pool.size()]
		var template_id: String = template.get("id", "unknown")
		var prefixes: Array = template.get("name_prefixes", ["旅人"])
		var suffixes: Array = template.get("name_suffixes", ["无名"])

		var name = prefixes[_rng.randi() % prefixes.size()] + suffixes[_rng.randi() % suffixes.size()]
		g.guest_name = name

		# 创建或复用客户记录
		var cid := "npc_%d" % _next_customer_seq
		_next_customer_seq += 1
		rec = CustomerRecord.new()
		rec.customer_id = cid
		rec.display_name = name
		rec.template_id = template_id
		rec.attributes = _mutate_attributes(template.get("attributes", {}))
		rec.first_seen_day = _get_current_day()
		rec.last_seen_day = _get_current_day()
		rec.visit_count = 1
		_customer_db[cid] = rec
	else:
		# 回退到硬编码名字
		var fallback_names = ["铁锤格鲁姆", "冰霜莱拉", "暗影德恩", "圣光凯尔", "疾风维克斯",
			"暗夜尼克斯", "山丘伯林", "银弦艾莉亚", "怒血索恩", "黎明扎拉",
			"磐石芬恩", "毒刃鲁克"]
		g.guest_name = fallback_names[_rng.randi() % fallback_names.size()]
		rec = CustomerRecord.new()
		rec.display_name = g.guest_name
		rec.attributes = {}

	# 随机点单（只从当日菜单选）
	var chosen: Dictionary = menu_items[_rng.randi() % menu_items.size()]
	g.order_key = chosen["key"]
	g.type = GuestData.GuestType.NORMAL
	g.patience = GuestData.BASE_PATIENCE
	g.has_dialogue = false
	g.set_meta("customer_id", rec.customer_id if rec != null else "")
	g.set_meta("template_id", template.get("id", "") if not template.is_empty() else "")

	if rec != null and rec.favorite_order == "":
		rec.favorite_order = chosen["key"]

	current_guest = g
	has_guest = true
	_daily_spawned += 1
	guest_arrived.emit(g)

func _spawn_return_customer(rec: CustomerRecord, menu_items: Array[Dictionary]) -> void:
	var g := GuestData.new()
	g.guest_name = rec.display_name
	g.type = GuestData.GuestType.NORMAL
	g.patience = GuestData.BASE_PATIENCE
	g.has_dialogue = false

	# 回头客偏好：50%概率点最爱
	var order_key: String
	if rec.favorite_order != "" and _rng.randf() < 0.5:
		# 确认最爱仍在菜单上
		for item in menu_items:
			if item["key"] == rec.favorite_order:
				order_key = rec.favorite_order
				break
	if order_key == "":
		var chosen: Dictionary = menu_items[_rng.randi() % menu_items.size()]
		order_key = chosen["key"]
	g.order_key = order_key

	# 更新记录
	rec.last_seen_day = _get_current_day()
	rec.visit_count += 1
	g.set_meta("customer_id", rec.customer_id)
	g.set_meta("is_return", true)

	current_guest = g
	has_guest = true
	_daily_spawned += 1
	guest_arrived.emit(g)

func _mutate_attributes(base: Dictionary) -> Dictionary:
	# 小幅随机变异属性值（±1）
	var result := base.duplicate()
	for key in result:
		result[key] = max(int(result[key]) + _rng.randi_range(-1, 1), -5)
	return result

# ── 重要NPC ──

func spawn_important(npc_id: String, order_key: String) -> void:
	var g := GuestData.new()
	g.guest_name = npc_id
	g.type = GuestData.GuestType.IMPORTANT
	g.order_key = order_key
	g.npc_id = npc_id
	g.patience = GuestData.BASE_PATIENCE * 1.5
	g.has_dialogue = true
	current_guest = g
	has_guest = true
	_daily_important_spawned = true
	guest_arrived.emit(g)

# ── 客人离场 ──

func clear_guest() -> void:
	var departed = current_guest
	guest_left.emit()
	current_guest = null
	has_guest = false
	_spawn_timer = 0.0
	_next_spawn = _rng.randf() * 2.0 + 2.0

	# 检查是否全部招待完毕（用离场计数器，不关心生成顺序）
	_daily_cleared += 1
	var expected_total := _daily_total_guests + (1 if _daily_important_spawned else 0)
	if _daily_cleared >= expected_total:
		_emit_all_guests_served()

func _emit_all_guests_served() -> void:
	if _all_completion_emitted:
		return
	_all_completion_emitted = true
	all_guests_served.emit()

func _emit_normal_orders_completed() -> void:
	if _normal_completion_emitted:
		return
	_normal_completion_emitted = true
	normal_orders_completed.emit()

# ── 统计 ──

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
	_daily_total_guests = 0
	_daily_spawned = 0
	_daily_important_spawned = false
	_all_completion_emitted = false
	_normal_completion_emitted = false

# ── 反应台词 ──

## 获取客人专属反应台词（NPC模板优先，通用池兜底）
func get_reaction_line(outcome: String, npc_id: String = "") -> String:
	# 先从当前客人的模板中找专属反应
	if current_guest != null:
		var tid: String = str(current_guest.get_meta("template_id", ""))
		if tid != "":
			for tmpl in _customer_pool:
				if tmpl.get("id", "") == tid:
					var tmpl_react: Dictionary = tmpl.get("reactions", {})
					if tmpl_react.has(outcome):
						return String(tmpl_react[outcome])

	# 通用池兜底
	var pool = _reaction_pools.get(outcome, [])
	if pool is Array and pool.size() > 0:
		return String(pool[_rng.randi() % pool.size()])
	return "「……」"

# ── 客人问候/告别（供UI调用） ──

func get_greeting() -> String:
	if current_guest == null:
		return ""
	var tid: String = str(current_guest.get_meta("template_id", ""))
	if tid != "":
		for tmpl in _customer_pool:
			if tmpl.get("id", "") == tid:
				var greetings: Array = tmpl.get("greetings", [])
				if greetings.size() > 0:
					return String(greetings[_rng.randi() % greetings.size()])
	return "「来一份菜。」"

func get_farewell() -> String:
	if current_guest == null:
		return ""
	var tid: String = str(current_guest.get_meta("template_id", ""))
	if tid != "":
		for tmpl in _customer_pool:
			if tmpl.get("id", "") == tid:
				var farewells: Array = tmpl.get("farewells", [])
				if farewells.size() > 0:
					return String(farewells[_rng.randi() % farewells.size()])
	return "「走了。」"

# ── 存档序列化 ──

func capture_state() -> Dictionary:
	var customers: Array = []
	for cid in _customer_db:
		var rec: CustomerRecord = _customer_db[cid]
		customers.append({
			"customer_id": rec.customer_id,
			"display_name": rec.display_name,
			"template_id": rec.template_id,
			"attributes": rec.attributes.duplicate(),
			"first_seen_day": rec.first_seen_day,
			"last_seen_day": rec.last_seen_day,
			"visit_count": rec.visit_count,
			"favorite_order": rec.favorite_order,
		})
	return {
		"customers": customers,
		"next_seq": _next_customer_seq,
	}

func restore_state(data: Dictionary) -> void:
	_customer_db.clear()
	for entry in data.get("customers", []):
		var rec := CustomerRecord.new()
		rec.customer_id = String(entry.get("customer_id", ""))
		rec.display_name = String(entry.get("display_name", ""))
		rec.template_id = String(entry.get("template_id", ""))
		rec.attributes = (entry.get("attributes", {}) as Dictionary).duplicate()
		rec.first_seen_day = int(entry.get("first_seen_day", 0))
		rec.last_seen_day = int(entry.get("last_seen_day", 0))
		rec.visit_count = int(entry.get("visit_count", 0))
		rec.favorite_order = String(entry.get("favorite_order", ""))
		_customer_db[rec.customer_id] = rec
	_next_customer_seq = max(int(data.get("next_seq", 1)), 1)
