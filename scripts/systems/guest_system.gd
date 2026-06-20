class_name GuestSystem
extends RefCounted

signal guest_arrived(guest)
signal guest_left()
signal patience_low()
signal normal_orders_completed()
signal guest_abandoned()
signal all_guests_served()

const APPETITE_SYSTEM_SCRIPT := preload("res://scripts/systems/appetite_system.gd")
const GUEST_GROUP_PROFILE_PATH := "res://data/guest_group_profiles.json"
const MEME_GUESTS_PATH := "res://data/meme_guests.json"
const MEME_GUEST_BASE_CHANCE := 0.18

class CustomerRecord extends RefCounted:
	var customer_id: String        # 唯一ID
	var display_name: String       # 显示名称
	var template_id: String        # NPC模板ID
	var attributes: Dictionary     # 属性
	var first_seen_day: int        # 初登场天数
	var last_seen_day: int         # 最后一次光顾天数
	var visit_count: int           # 光顾次数
	var favorite_order: String     # 最爱点的菜（key）
	var remembered_tags: Dictionary = {}
	var remembered_orders: Dictionary = {}
	var memory_notes: Array[String] = []

var current_guest: GuestData = null
var has_guest: bool = false

var _get_menu_items: Callable     # 获取当日菜单的回调（替代原 _get_available_orders）
var _rng = RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
var _next_spawn: float = 2.0

var guests_served_today: int = 0
var orders_success: int = 0
var orders_failed: int = 0
var guest_entries_today: Array[Dictionary] = []
var _current_guest_entry_index: int = -1

# 客流系统
var _daily_total_guests: int = 0      # 当日总客人数（含已生成和即将生成）
var _daily_spawned: int = 0           # 已生成数（普通客人）
var _daily_cleared: int = 0           # 已离场数（所有客人）
var _normal_order_limit: int = 0
var _normal_orders_spawned: int = 0
var _daily_important_spawned: bool = false
var _all_completion_emitted: bool = false
var _normal_completion_emitted: bool = false
var _night_guest_bias: Dictionary = {}

# 客户持久化
var _customer_db: Dictionary = {}     # customer_id -> CustomerRecord
var _customer_pool: Array = []        # 模板池（加载自 npc_pool.json）
var _meme_guest_pool: Array = []
var _customer_by_id: Dictionary = {}
var _reaction_pools: Dictionary = {}
var _guest_group_profiles: Dictionary = {}
var _group_appetite: AppetiteSystem = null
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
	_load_regular_customer_roster()
	_load_meme_guest_roster()
	_load_guest_group_profiles()
	_group_appetite = APPETITE_SYSTEM_SCRIPT.new()
	_group_appetite.load_data()

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

func _load_regular_customer_roster() -> void:
	var file = FileAccess.open("res://data/regular_customers.json", FileAccess.READ)
	if file == null:
		push_warning("[GuestSystem] regular_customers.json missing; using legacy npc_pool.json")
		_load_npc_pool()
		return
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		push_error("[GuestSystem] regular_customers.json parse failed")
		return
	_customer_pool = data.get("customers", [])
	_customer_by_id.clear()
	for entry in _customer_pool:
		if entry is Dictionary:
			_customer_by_id[String(entry.get("id", ""))] = entry
	print("[GuestSystem] loaded ", _customer_pool.size(), " named regular customers")


func _load_meme_guest_roster() -> void:
	_meme_guest_pool.clear()
	if not FileAccess.file_exists(MEME_GUESTS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MEME_GUESTS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[GuestSystem] meme_guests.json parse failed")
		return
	for raw_entry in parsed.get("guests", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry := Dictionary(raw_entry).duplicate(true)
		var guest_id := String(entry.get("id", "")).strip_edges()
		var law_id := String(entry.get("physics_law_id", "")).strip_edges()
		if guest_id == "" or law_id == "":
			continue
		entry["id"] = guest_id
		entry["portrait_id"] = String(entry.get("portrait_id", guest_id)).strip_edges()
		entry["physics_law_id"] = law_id
		entry["unlock_day"] = max(1, int(entry.get("unlock_day", 1)))
		entry["spawn_weight"] = maxf(float(entry.get("spawn_weight", 0.0)), 0.0)
		_meme_guest_pool.append(entry)
	print("[GuestSystem] loaded ", _meme_guest_pool.size(), " meme guests")


func _load_guest_group_profiles(path: String = GUEST_GROUP_PROFILE_PATH) -> void:
	_guest_group_profiles.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[GuestSystem] guest_group_profiles.json missing; anonymous groups disabled")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("[GuestSystem] guest_group_profiles.json parse failed")
		return
	var groups: Dictionary = (parsed as Dictionary).get("groups", {})
	for key in groups.keys():
		var group_key := String(key)
		var profile: Dictionary = groups[key]
		if group_key == "" or profile.is_empty():
			continue
		_guest_group_profiles[group_key] = profile.duplicate(true)


func get_guest_group_profile(group_key: String) -> Dictionary:
	var profile: Dictionary = _guest_group_profiles.get(group_key, {})
	if profile.is_empty():
		return {}
	return profile.duplicate(true)


func choose_guest_group_order(group_key: String, menu_items: Array) -> String:
	var profile := get_guest_group_profile(group_key)
	if profile.is_empty() or menu_items.is_empty():
		return ""
	var preferred_tags := _strings_from_values(profile.get("preferredTags", []))
	var tagged_options := _menu_orders_matching_tags(menu_items, preferred_tags)
	if not tagged_options.is_empty():
		return tagged_options[_rng.randi() % tagged_options.size()]
	var fallback_orders := _strings_from_values(profile.get("fallbackOrders", []))
	for order_key in fallback_orders:
		if _menu_contains_order(menu_items, order_key):
			return order_key
	return _menu_item_key(menu_items[_rng.randi() % menu_items.size()])


func get_group_match_feedback(group_key: String, product_tags: Array) -> String:
	var profile := get_guest_group_profile(group_key)
	if profile.is_empty():
		return ""
	var preferred_tags := _strings_from_values(profile.get("preferredTags", []))
	var served_tags := _strings_from_values(product_tags)
	var matched := false
	for tag in served_tags:
		if preferred_tags.has(tag):
			matched = true
			break
	if not matched:
		return ""
	var lines: Array = profile.get("matchLines", [])
	if lines.is_empty():
		return ""
	return String(lines[_rng.randi() % lines.size()])


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
	_customer_by_id.clear()
	for entry in _customer_pool:
		if entry is Dictionary:
			_customer_by_id[String(entry.get("id", ""))] = entry
	print("[GuestSystem] 加载 ", _customer_pool.size(), " 种NPC模板")

# ── 每日配置 ──

func configure_night(normal_order_limit: int, day: int = 0, guest_bias: Dictionary = {}) -> void:
	if day <= 0:
		day = _get_current_day()
	var base_count: int = maxi(normal_order_limit, 0)
	_night_guest_bias = guest_bias.duplicate(true)

	# 回头客：从已有顾客库中按概率选取
	_return_candidates = _build_return_list(day)
	var return_count: int = min(_return_candidates.size(), int(ceil(base_count * 0.4)))  # 最多40%回头客

	_normal_order_limit = base_count
	_normal_orders_spawned = 0
	_daily_total_guests = base_count + return_count
	_daily_spawned = 0
	_daily_cleared = 0
	_daily_important_spawned = false
	_normal_completion_emitted = false
	_all_completion_emitted = false
	_spawn_timer = 0.0
	_next_spawn = 2.0

	print("[GuestSystem] Day%d 客流配置: 基础%d + 回头客%d = 共%d人" % [day, base_count, return_count, _daily_total_guests])


func get_regular_customer_preview(customer_id: String) -> Dictionary:
	var entry: Dictionary = _customer_by_id.get(customer_id, {})
	if entry.is_empty():
		return {
			"id": customer_id,
			"name": customer_id,
			"role": "",
			"favorite_orders": [],
		}
	return {
		"id": customer_id,
		"name": String(entry.get("display_name", customer_id)),
		"role": String(entry.get("role", "")),
		"favorite_orders": (entry.get("favorite_orders", []) as Array).duplicate(),
		"trait": (entry.get("trait", {}) as Dictionary).duplicate(true),
	}


func record_customer_memory(customer_id: String, item_key: String, item_name: String, tags: Array, day: int, reason: String = "") -> Dictionary:
	if customer_id == "" or not customer_id.begins_with("regular_") or item_key == "":
		return {}
	var clean_tags := _memory_strings_from_array(tags)
	if clean_tags.is_empty():
		return {}
	var rec := _ensure_customer_record(customer_id, day)
	var display_item := item_name if item_name != "" else item_key
	rec.remembered_orders[item_key] = int(rec.remembered_orders.get(item_key, 0)) + 1
	for tag in clean_tags:
		rec.remembered_tags[tag] = int(rec.remembered_tags.get(tag, 0)) + 1
	if rec.favorite_order == "":
		rec.favorite_order = item_key
	var note := "%s记住了%s" % [rec.display_name if rec.display_name != "" else customer_id, display_item]
	if not rec.memory_notes.has(note):
		rec.memory_notes.append(note)
	while rec.memory_notes.size() > 5:
		rec.memory_notes.pop_front()
	var result := {
		"customer_id": customer_id,
		"customer_name": rec.display_name if rec.display_name != "" else customer_id,
		"item_key": item_key,
		"item_name": display_item,
		"tags": clean_tags,
		"note": note,
		"reason": reason,
	}
	var trait_info := _triggered_trait_for_tags(customer_id, clean_tags)
	if not trait_info.is_empty():
		result["trait"] = trait_info
		result["trait_note"] = "%s：%s" % [String(trait_info.get("name", "")), String(trait_info.get("summary", ""))]
	return result


func get_customer_memory_summary(customer_id: String) -> Dictionary:
	var rec: CustomerRecord = _customer_db.get(customer_id, null)
	if rec == null:
		return {}
	var preview := get_regular_customer_preview(customer_id)
	return {
		"customer_id": rec.customer_id,
		"customer_name": rec.display_name,
		"remembered_tags": _sorted_memory_keys(rec.remembered_tags),
		"remembered_orders": _sorted_memory_keys(rec.remembered_orders),
		"notes": rec.memory_notes.duplicate(),
		"trait": (preview.get("trait", {}) as Dictionary).duplicate(true),
	}


func get_customer_memory_summaries(limit: int = 5) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids := _sorted_memory_keys(_customer_db)
	for customer_id in ids:
		var summary := get_customer_memory_summary(customer_id)
		if summary.is_empty():
			continue
		if (summary.get("notes", []) as Array).is_empty() and (summary.get("remembered_tags", []) as Array).is_empty():
			continue
		result.append(summary)
		if limit > 0 and result.size() >= limit:
			break
	return result


func _ensure_customer_record(customer_id: String, day: int) -> CustomerRecord:
	var rec: CustomerRecord = _customer_db.get(customer_id, null)
	if rec != null:
		return rec
	var preview := get_regular_customer_preview(customer_id)
	rec = CustomerRecord.new()
	rec.customer_id = customer_id
	rec.display_name = String(preview.get("name", customer_id))
	rec.template_id = customer_id
	rec.attributes = {}
	rec.first_seen_day = day
	rec.last_seen_day = 0
	rec.visit_count = 0
	rec.favorite_order = ""
	_customer_db[customer_id] = rec
	return rec


func _triggered_trait_for_tags(customer_id: String, tags: Array[String]) -> Dictionary:
	var preview := get_regular_customer_preview(customer_id)
	var trait_info: Dictionary = preview.get("trait", {})
	if trait_info.is_empty():
		return {}
	var focus_tags = trait_info.get("focusTags", [])
	if not focus_tags is Array:
		return {}
	for tag in tags:
		if (focus_tags as Array).has(tag):
			return trait_info.duplicate(true)
	return {}


func _memory_strings_from_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var text := String(value)
		if text == "":
			continue
		if not result.has(text):
			result.append(text)
	return result


func _sorted_memory_keys(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in values.keys():
		result.append(String(key))
	result.sort()
	return result

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
		ensure_idle_completion()
		return

	var menu_items: Array = _get_menu_items.call()
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


func _spawn_normal() -> void:
	_try_spawn_next()


func remaining_normal_orders() -> int:
	return maxi(_daily_total_guests - _daily_spawned, 0)


func ensure_idle_completion() -> void:
	if has_guest or current_guest != null:
		return
	if _daily_spawned < _daily_total_guests:
		return
	_emit_normal_orders_completed()
	var expected_total := _daily_total_guests + (1 if _daily_important_spawned else 0)
	if _daily_cleared >= expected_total:
		_emit_all_guests_served()


func _regular_customer_entries_for_day(day: int, exclude_seen_today: bool = true) -> Array:
	var result: Array = []
	for entry in _customer_pool:
		if not entry is Dictionary:
			continue
		var customer_id := String(entry.get("id", ""))
		if customer_id == "" or String(entry.get("portrait_key", "")) == "":
			continue
		if int(entry.get("unlock_day", 1)) > day:
			continue
		var rec: CustomerRecord = _customer_db.get(customer_id, null)
		if exclude_seen_today and rec != null and rec.last_seen_day >= day:
			continue
		result.append(entry)
	return result


func _pick_regular_customer(day: int) -> Dictionary:
	var candidates := _regular_customer_entries_for_day(day, true)
	if candidates.is_empty():
		candidates = _regular_customer_entries_for_day(day, false)
	if candidates.is_empty():
		return {}
	var total_weight := 0.0
	for entry in candidates:
		total_weight += maxf(float(entry.get("spawn_weight", 1.0)), 0.0) * _entry_bias_multiplier(entry)
	if total_weight <= 0.0:
		return candidates[_rng.randi() % candidates.size()]
	var roll := _rng.randf() * total_weight
	for entry in candidates:
		roll -= maxf(float(entry.get("spawn_weight", 1.0)), 0.0) * _entry_bias_multiplier(entry)
		if roll <= 0.0:
			return entry
	return candidates.back()


func _meme_guest_entries_for_day(day: int) -> Array:
	var result: Array = []
	for entry in _meme_guest_pool:
		if not entry is Dictionary:
			continue
		if day < int(entry.get("unlock_day", 1)):
			continue
		if float(entry.get("spawn_weight", 0.0)) <= 0.0:
			continue
		result.append(Dictionary(entry).duplicate(true))
	return result


func _pick_meme_guest(day: int) -> Dictionary:
	var candidates := _meme_guest_entries_for_day(day)
	if candidates.is_empty():
		return {}
	var total_weight := 0.0
	for entry in candidates:
		total_weight += maxf(float(entry.get("spawn_weight", 0.0)), 0.0)
	if total_weight <= 0.0:
		return Dictionary(candidates[_rng.randi() % candidates.size()]).duplicate(true)
	var roll := _rng.randf() * total_weight
	for entry in candidates:
		roll -= maxf(float(entry.get("spawn_weight", 0.0)), 0.0)
		if roll <= 0.0:
			return Dictionary(entry).duplicate(true)
	return Dictionary(candidates.back()).duplicate(true)


func _should_try_meme_guest() -> bool:
	if _daily_total_guests <= 1:
		return false
	var chance := clampf(MEME_GUEST_BASE_CHANCE * float(_night_guest_bias.get("meme", 1.0)), 0.0, 1.0)
	return chance > 0.0 and _rng.randf() < chance


func _entry_bias_multiplier(entry: Dictionary) -> float:
	var customer_id := String(entry.get("id", ""))
	var multiplier := float(_night_guest_bias.get(customer_id, 1.0))
	var role := String(entry.get("role", ""))
	if role.contains("矿") or role.contains("搬运") or role.contains("退伍"):
		multiplier *= float(_night_guest_bias.get("mine", 1.0))
	if role.contains("账") or role.contains("符文"):
		multiplier *= float(_night_guest_bias.get("ledger", 1.0))
	if role.contains("商人") or role.contains("吟游"):
		multiplier *= float(_night_guest_bias.get("trade", 1.0))
	if role.contains("巡林") or role.contains("洗衣"):
		multiplier *= float(_night_guest_bias.get("herbal", 1.0))
	return maxf(multiplier, 0.0)


func _menu_contains_order(menu_items: Array, order_key: String) -> bool:
	for item in menu_items:
		if _menu_item_key(item) == order_key:
			return true
	return false


func _menu_orders_matching_tags(menu_items: Array, tags: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if tags.is_empty():
		return result
	var best_score := 0
	for item in menu_items:
		var order_key := _menu_item_key(item)
		if order_key == "":
			continue
		var product_tags := _product_tags(order_key)
		var score := 0
		for tag in tags:
			if product_tags.has(tag):
				score += 1
		if score <= 0:
			continue
		if score > best_score:
			best_score = score
			result.clear()
		if score == best_score and not result.has(order_key):
			result.append(order_key)
	return result


func _product_tags(product_key: String) -> Array[String]:
	if _group_appetite == null or not _group_appetite.has_method("get_product_tags"):
		return []
	return _strings_from_values(_group_appetite.get_product_tags(product_key))


func _strings_from_values(values) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		var text := String(value)
		if text == "" or result.has(text):
			continue
		result.append(text)
	return result


func _choose_regular_order(entry: Dictionary, menu_items: Array) -> String:
	var available_favorites: Array[String] = []
	var favorites_value = entry.get("favorite_orders", [])
	if favorites_value is Array:
		for order in favorites_value:
			var order_key := String(order)
			if _menu_contains_order(menu_items, order_key):
				available_favorites.append(order_key)
	if not available_favorites.is_empty():
		return available_favorites[_rng.randi() % available_favorites.size()]
	var chosen = menu_items[_rng.randi() % menu_items.size()]
	return _menu_item_key(chosen)


func _pick_menu_item_for_tags(menu_items: Array, preferred_tags: Array) -> Dictionary:
	if menu_items.is_empty():
		return {}
	if preferred_tags.is_empty():
		var fallback = menu_items[_rng.randi() % menu_items.size()]
		return Dictionary(fallback) if fallback is Dictionary else {"key": String(fallback)}
	var weighted: Array = []
	for item in menu_items:
		if not item is Dictionary:
			continue
		var item_key := _menu_item_key(item)
		var tags: Array = Array(item.get("tags", [])) + Array(item.get("flavor_tags", [])) + _product_tags(item_key)
		var score := 1.0
		for tag in preferred_tags:
			if tags.has(String(tag)):
				score += 2.0
		weighted.append({"item": item, "score": score})
	if weighted.is_empty():
		var fallback = menu_items[_rng.randi() % menu_items.size()]
		return Dictionary(fallback) if fallback is Dictionary else {"key": String(fallback)}
	var total := 0.0
	for row in weighted:
		total += float(row["score"])
	var roll := _rng.randf() * total
	for row in weighted:
		roll -= float(row["score"])
		if roll <= 0.0:
			return Dictionary(row["item"])
	return Dictionary(weighted.back()["item"])


func _spawn_meme_guest(entry: Dictionary, menu_items: Array) -> void:
	if menu_items.is_empty():
		return
	var chosen := _pick_menu_item_for_tags(menu_items, Array(entry.get("preferred_tags", [])))
	var order_key := _menu_item_key(chosen)
	if order_key == "":
		return
	var guest := GuestData.new()
	var meme_id := String(entry.get("id", "")).strip_edges()
	var portrait_id := String(entry.get("portrait_id", meme_id)).strip_edges()
	guest.guest_name = String(entry.get("display_name", meme_id))
	guest.type = GuestData.GuestType.NORMAL
	guest.order_key = order_key
	guest.npc_id = portrait_id
	guest.patience = GuestData.BASE_PATIENCE * maxf(float(entry.get("patience_multiplier", 1.0)), 0.1)
	guest.has_dialogue = false
	guest.set_meta("customer_id", "")
	guest.set_meta("meme_guest_id", meme_id)
	guest.set_meta("physics_law_id", String(entry.get("physics_law_id", "")))
	guest.set_meta("portrait_id", portrait_id)
	guest.set_meta("arrival_line", String(entry.get("arrival_line", "")))
	guest.set_meta("event_hint", String(entry.get("event_hint", "")))
	guest.set_meta("dialogue_tags", Array(entry.get("dialogue_tags", [])))
	guest.set_meta("preferred_tags", Array(entry.get("preferred_tags", [])))
	guest.set_meta("tip_multiplier", float(entry.get("tip_multiplier", 1.0)))
	guest.set_meta("template_id", meme_id)

	current_guest = guest
	has_guest = true
	_daily_spawned += 1
	_normal_orders_spawned = _daily_spawned
	_record_guest_arrival(guest)
	guest_arrived.emit(guest)


func _spawn_regular_customer(entry: Dictionary, menu_items: Array) -> void:
	var customer_id := String(entry.get("id", ""))
	if customer_id == "":
		return
	var day := _get_current_day()
	var rec: CustomerRecord = _customer_db.get(customer_id, null)
	if rec == null:
		rec = CustomerRecord.new()
		rec.customer_id = customer_id
		rec.first_seen_day = day
		rec.visit_count = 0
		_customer_db[customer_id] = rec
	rec.display_name = String(entry.get("display_name", customer_id))
	rec.template_id = customer_id
	rec.attributes = (entry.get("attributes", {}) as Dictionary).duplicate()
	rec.last_seen_day = day
	rec.visit_count += 1

	var g := GuestData.new()
	g.guest_name = rec.display_name
	g.type = GuestData.GuestType.NORMAL
	g.order_key = _choose_regular_order(entry, menu_items)
	g.npc_id = customer_id
	g.patience = GuestData.BASE_PATIENCE * maxf(float(entry.get("patience_multiplier", 1.0)), 0.1)
	g.has_dialogue = false
	g.set_meta("customer_id", rec.customer_id)
	g.set_meta("regular_customer_id", customer_id)
	g.set_meta("template_id", customer_id)

	if rec.favorite_order == "":
		rec.favorite_order = g.order_key

	current_guest = g
	has_guest = true
	_daily_spawned += 1
	_normal_orders_spawned = _daily_spawned
	_record_guest_arrival(g)
	guest_arrived.emit(g)


func _active_group_bias_exists() -> bool:
	for key in _guest_group_profiles.keys():
		if float(_night_guest_bias.get(String(key), 1.0)) > 1.0:
			return true
	return false


func _group_bias_multiplier(group_key: String) -> float:
	return maxf(float(_night_guest_bias.get(group_key, 1.0)), 0.0)


func _pick_guest_group_key() -> String:
	if _guest_group_profiles.is_empty():
		return ""
	var total_weight := 0.0
	for key in _guest_group_profiles.keys():
		total_weight += _group_bias_multiplier(String(key))
	if total_weight <= 0.0:
		return ""
	var roll := _rng.randf() * total_weight
	for key in _guest_group_profiles.keys():
		var group_key := String(key)
		roll -= _group_bias_multiplier(group_key)
		if roll <= 0.0:
			return group_key
	return String(_guest_group_profiles.keys().back())


func _group_guest_name(profile: Dictionary, portrait_id: String = "") -> String:
	var personal_name := _regular_customer_display_name(portrait_id)
	var group_name := String(profile.get("displayName", ""))
	if personal_name != "":
		if group_name != "":
			return "%s · %s" % [personal_name, group_name]
		return personal_name
	var prefixes: Array = profile.get("namePrefixes", [])
	var suffixes: Array = profile.get("nameSuffixes", [])
	if prefixes.is_empty() or suffixes.is_empty():
		return group_name if group_name != "" else "旅人"
	return String(prefixes[_rng.randi() % prefixes.size()]) + String(suffixes[_rng.randi() % suffixes.size()])


func _regular_customer_display_name(customer_id: String) -> String:
	if customer_id == "":
		return ""
	var entry: Dictionary = _customer_by_id.get(customer_id, {})
	if entry.is_empty():
		return ""
	return String(entry.get("display_name", customer_id))


func _group_portrait_id(profile: Dictionary) -> String:
	var portrait_pool := _strings_from_values(profile.get("portraitPool", []))
	if portrait_pool.is_empty():
		return ""
	return portrait_pool[_rng.randi() % portrait_pool.size()]


func _spawn_group_guest(group_key: String, menu_items: Array) -> void:
	var profile := get_guest_group_profile(group_key)
	if profile.is_empty() or menu_items.is_empty():
		return
	var portrait_id := _group_portrait_id(profile)
	var g := GuestData.new()
	g.guest_name = _group_guest_name(profile, portrait_id)
	g.type = GuestData.GuestType.NORMAL
	g.order_key = choose_guest_group_order(group_key, menu_items)
	if g.order_key == "":
		return
	g.npc_id = ""
	g.patience = GuestData.BASE_PATIENCE * maxf(float(profile.get("patienceMultiplier", 1.0)), 0.1)
	g.has_dialogue = false
	g.set_meta("customer_id", "")
	g.set_meta("guest_group", group_key)
	g.set_meta("template_id", "group_" + group_key)
	if portrait_id != "":
		g.set_meta("portrait_id", portrait_id)
	g.set_meta("preferred_tags", _strings_from_values(profile.get("preferredTags", [])))
	g.set_meta("tip_multiplier", float(profile.get("tipMultiplier", 1.0)))
	g.set_meta("reputation_on_success", int(profile.get("reputationOnSuccess", 0)))

	current_guest = g
	has_guest = true
	_daily_spawned += 1
	_normal_orders_spawned = _daily_spawned
	_record_guest_arrival(g)
	guest_arrived.emit(g)


func _spawn_new_customer(menu_items: Array) -> void:
	if menu_items.is_empty():
		return
	if _should_try_meme_guest():
		var meme_entry := _pick_meme_guest(_get_current_day())
		if not meme_entry.is_empty():
			_spawn_meme_guest(meme_entry, menu_items)
			if has_guest:
				return

	var group_key := _pick_guest_group_key()
	if group_key != "":
		var group_chance := 0.65 if _active_group_bias_exists() else 0.28
		if _rng.randf() < group_chance:
			_spawn_group_guest(group_key, menu_items)
			if has_guest:
				return

	var regular := _pick_regular_customer(_get_current_day())
	if not regular.is_empty():
		_spawn_regular_customer(regular, menu_items)
		return

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
	var chosen = menu_items[_rng.randi() % menu_items.size()]
	g.order_key = _menu_item_key(chosen)
	g.type = GuestData.GuestType.NORMAL
	g.patience = GuestData.BASE_PATIENCE
	g.has_dialogue = false
	g.set_meta("customer_id", rec.customer_id if rec != null else "")
	g.set_meta("template_id", template.get("id", "") if not template.is_empty() else "")

	if rec != null and rec.favorite_order == "":
		rec.favorite_order = g.order_key

	current_guest = g
	has_guest = true
	_daily_spawned += 1
	_normal_orders_spawned = _daily_spawned
	_record_guest_arrival(g)
	guest_arrived.emit(g)


func _spawn_return_customer(rec: CustomerRecord, menu_items: Array) -> void:
	var g := GuestData.new()
	g.guest_name = rec.display_name
	g.type = GuestData.GuestType.NORMAL
	var regular_entry: Dictionary = _customer_by_id.get(rec.customer_id, {})
	g.npc_id = rec.customer_id if String(regular_entry.get("portrait_key", "")) != "" else ""
	g.patience = GuestData.BASE_PATIENCE * maxf(float(regular_entry.get("patience_multiplier", 1.0)), 0.1)
	g.has_dialogue = false

	# 回头客偏好：50%概率点最爱
	var order_key: String
	if not regular_entry.is_empty():
		order_key = _choose_regular_order(regular_entry, menu_items)
	elif rec.favorite_order != "" and _rng.randf() < 0.5:
		# 确认最爱仍在菜单上
		for item in menu_items:
			if _menu_item_key(item) == rec.favorite_order:
				order_key = rec.favorite_order
				break
	if order_key == "":
		var chosen = menu_items[_rng.randi() % menu_items.size()]
		order_key = _menu_item_key(chosen)
	g.order_key = order_key

	# 更新记录
	rec.last_seen_day = _get_current_day()
	rec.visit_count += 1
	g.set_meta("customer_id", rec.customer_id)
	g.set_meta("is_return", true)
	if g.npc_id != "":
		g.set_meta("regular_customer_id", g.npc_id)
	g.set_meta("template_id", rec.template_id)

	current_guest = g
	has_guest = true
	_daily_spawned += 1
	_normal_orders_spawned = _daily_spawned
	_record_guest_arrival(g)
	guest_arrived.emit(g)


func _menu_item_key(item) -> String:
	if item is Dictionary:
		return String(item.get("key", ""))
	return String(item)


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
	_record_guest_arrival(g)
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
	if departed != null and departed.type == GuestData.GuestType.NORMAL and _daily_spawned >= _daily_total_guests:
		_emit_normal_orders_completed()
	if _daily_cleared >= expected_total:
		_emit_all_guests_served()
	_mark_current_guest_left_if_pending()
	_current_guest_entry_index = -1

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

func get_guest_entries_today() -> Array[Dictionary]:
	return guest_entries_today.duplicate(true)


func update_current_guest_entry_identity(display_name: String, portrait_id: String) -> void:
	if _current_guest_entry_index < 0 or _current_guest_entry_index >= guest_entries_today.size():
		return
	var entry: Dictionary = guest_entries_today[_current_guest_entry_index]
	if display_name != "":
		entry["display_name"] = display_name
	if portrait_id != "":
		entry["portrait_id"] = portrait_id
	guest_entries_today[_current_guest_entry_index] = entry


func _record_guest_arrival(guest: GuestData) -> void:
	if guest == null:
		_current_guest_entry_index = -1
		return
	var npc_id := String(guest.npc_id)
	var entry := {
		"npc_id": npc_id,
		"display_name": String(guest.guest_name),
		"guest_group": String(guest.get_meta("guest_group", "")),
		"meme_guest_id": String(guest.get_meta("meme_guest_id", "")),
		"physics_law_id": String(guest.get_meta("physics_law_id", "")),
		"order_key": String(guest.order_key),
		"result": "pending",
		"gold_delta": 0,
		"rep_delta": 0,
		"served_delta": 0,
		"success_delta": 0,
		"failed_delta": 0,
	}
	guest_entries_today.append(entry)
	_current_guest_entry_index = guest_entries_today.size() - 1


func _resolve_current_guest_entry(result: String, gold_delta: int, rep_delta: int, served_delta: int, success_delta: int, failed_delta: int) -> void:
	if _current_guest_entry_index < 0 or _current_guest_entry_index >= guest_entries_today.size():
		return
	var entry: Dictionary = guest_entries_today[_current_guest_entry_index]
	entry["result"] = result
	entry["gold_delta"] = gold_delta
	entry["rep_delta"] = rep_delta
	entry["served_delta"] = served_delta
	entry["success_delta"] = success_delta
	entry["failed_delta"] = failed_delta
	guest_entries_today[_current_guest_entry_index] = entry


func _mark_current_guest_left_if_pending() -> void:
	if _current_guest_entry_index < 0 or _current_guest_entry_index >= guest_entries_today.size():
		return
	var entry: Dictionary = guest_entries_today[_current_guest_entry_index]
	if String(entry.get("result", "")) == "pending":
		entry["result"] = "left"
		guest_entries_today[_current_guest_entry_index] = entry


func record_guest_served() -> void:
	guests_served_today += 1

func record_order_success(gold_delta: int = 0, rep_delta: int = 0) -> void:
	orders_success += 1
	_resolve_current_guest_entry("success", gold_delta, rep_delta, 1, 1, 0)

func record_order_failed(gold_delta: int = 0, rep_delta: int = 0, result: String = "failed") -> void:
	orders_failed += 1
	_resolve_current_guest_entry(result, gold_delta, rep_delta, 0, 0, 1)

func reset_daily() -> void:
	guests_served_today = 0
	orders_success = 0
	orders_failed = 0
	guest_entries_today.clear()
	_current_guest_entry_index = -1
	_daily_total_guests = 0
	_daily_spawned = 0
	_normal_order_limit = 0
	_normal_orders_spawned = 0
	_daily_important_spawned = false
	_all_completion_emitted = false
	_normal_completion_emitted = false
	_night_guest_bias.clear()

# ── 反应台词 ──

## 获取客人专属反应台词（NPC模板优先，通用池兜底）
func get_reaction_line(outcome: String, npc_id: String = "") -> String:
	if current_guest != null:
		var meme_reaction := _current_meme_reaction_line(outcome)
		if meme_reaction != "":
			return meme_reaction

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

func _current_meme_reaction_line(outcome: String) -> String:
	if current_guest == null:
		return ""
	var meme_id := String(current_guest.get_meta("meme_guest_id", "")).strip_edges()
	if meme_id == "":
		meme_id = String(current_guest.get_meta("template_id", "")).strip_edges()
	if meme_id == "":
		return ""
	for entry in _meme_guest_pool:
		if String(entry.get("id", "")) != meme_id:
			continue
		var reactions: Dictionary = entry.get("reactions", {})
		if not reactions.has(outcome):
			return ""
		var reaction_value = reactions.get(outcome)
		if reaction_value is Array:
			var lines: Array = reaction_value
			if lines.is_empty():
				return ""
			return String(lines[_rng.randi() % lines.size()])
		return String(reaction_value)
	return ""


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
			"remembered_tags": rec.remembered_tags.duplicate(),
			"remembered_orders": rec.remembered_orders.duplicate(),
			"memory_notes": rec.memory_notes.duplicate(),
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
		rec.remembered_tags = (entry.get("remembered_tags", {}) as Dictionary).duplicate()
		rec.remembered_orders = (entry.get("remembered_orders", {}) as Dictionary).duplicate()
		rec.memory_notes = _memory_strings_from_array(entry.get("memory_notes", []) as Array)
		_customer_db[rec.customer_id] = rec
	_next_customer_seq = max(int(data.get("next_seq", 1)), 1)
