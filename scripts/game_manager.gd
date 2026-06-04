extends Node

# Signals
signal inventory_changed()

# Subsystems
var economy: EconomySystem
var day_cycle: DayCycleSystem
var narrative: NarrativeManager
var shop: ShopSystem
var guests: GuestSystem
var craft: CraftSystem
var seasoning: SeasoningSystem
var craft_style: CraftStyleSystem
var workspace: WorkspaceSystem
var documents: DocumentSystem
var day_map: DayMapSystem
var save_sys: SaveSystem
var ryan_slice: RyanSliceSystem
var audio: AudioManager
var settings: SettingsManager

# Inventory
var inventory_sys: InventorySystem
var inventory: Dictionary = {}
var current_ledger_data: LedgerData = null

# Dialogue state
var _is_dialogue_active: bool = false
var _dialogue_phase: String = ""
var _important_npc_pending: bool = false
var _guest_lingering: bool = false

# Scene refs
var _tavern_view = null
var _day_map_view = null
var _ending_screen = null
var _tutorial_manager = null

const MATERIAL_ICON_PATHS: Dictionary = {
	"ale": "res://assets/textures/icons/materials/wheat.png",
	"grape": "res://assets/textures/icons/materials/grape.png",
	"flour": "res://assets/textures/icons/materials/wheat.png",
	"meat_raw": "res://assets/textures/icons/products/roast.png",
	"herb": "res://assets/textures/icons/materials/herb.png",
	"ale_beer": "res://assets/textures/icons/products/ale.png",
	"bread": "res://assets/textures/icons/products/bread.png",
	"meat_cooked": "res://assets/textures/icons/products/roast.png",
	"herb_broth": "res://assets/textures/icons/products/stew.png",
	"sleep_powder": "res://assets/textures/icons/items/sleep_powder.png",
	"bloodied_contract": "res://assets/textures/icons/items/bloodied_contract.png",
	"alternative_contract": "res://assets/textures/icons/items/alternative_contract.png",
}

## resolve_action 的 feedback key → 玩家可见提示 [文案, 颜色]。
## 对话只回应已发生的行为；这里是动作当下的即时反馈（spec §1.1 / §7.3）。
const ACTION_FEEDBACK: Dictionary = {
	"ryan_informed": ["莱恩盯着那份染血的委托书，脸色一点点沉了下来。", Color.ORANGE],
	"ryan_accepts_alternative": ["莱恩收起替代委托，郑重地点了点头。", Color.LIME_GREEN],
	"ryan_needs_warning_first": ["莱恩疑惑地看着这份委托，似乎还不明白其中的分量。", Color.GRAY],
	"ryan_alternative_pending": ["莱恩默默收起替代委托：让我看看你今晚怎么待我。", Color.GRAY],
	"ryan_accepts_ale": ["莱恩一饮而尽，咧嘴笑了。", Color.LIME_GREEN],
	"ryan_drugged": ["莱恩喝下那杯酒，眼皮越来越沉……趴在桌上睡了过去。", Color.MEDIUM_PURPLE],
	"ryan_refuses_drugged_ale": ["莱恩警觉地推开酒杯：今晚我必须保持清醒。", Color.GRAY],
	"ryan_interaction_closed": ["莱恩已经没有再交谈的心思了。", Color.GRAY],
	"sleep_powder_added": ["你把沉睡花粉搅入了麦芽酒。", Color.MEDIUM_PURPLE],
	"unsupported_story_item": ["他不需要这个。", Color.GRAY],
	"unsupported_npc": ["这东西不该交给他。", Color.GRAY],
	"unsupported_story_product": ["花粉化不进这样东西里。", Color.GRAY],
}

func _ready() -> void:
	economy = EconomySystem.new()
	day_cycle = DayCycleSystem.new()
	narrative = NarrativeManager.new()
	shop = ShopSystem.new()
	craft = CraftSystem.new()
	seasoning = SeasoningSystem.new()
	craft_style = CraftStyleSystem.new()

	craft.load_data()
	inventory_sys = InventorySystem.new()
	inventory_sys.load_items(craft.items)
	inventory_sys.set_initial(_load_initial_inventory())
	inventory = inventory_sys.materials
	workspace = WorkspaceSystem.new()
	documents = DocumentSystem.new()
	documents.load_data()
	day_map = DayMapSystem.new()
	day_map.load_data()
	save_sys = SaveSystem.new()
	settings = SettingsManager.new()
	settings.load_and_apply()
	ryan_slice = RyanSliceSystem.new()
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	narrative.load_npc_data()
	shop.load_config()
	seasoning.load_data()
	craft_style.load_data()

	guests = GuestSystem.new(func():
		return craft.get_orderable_products(economy.current_day)
	)
	guests.guest_arrived.connect(_on_guest_arrived)
	guests.guest_left.connect(_on_guest_left)
	guests.patience_low.connect(_on_patience_low)
	guests.normal_orders_completed.connect(_on_normal_orders_completed)
	guests.guest_abandoned.connect(_on_guest_abandoned)

	economy.changed.connect(_refresh_tavern_ui)
	day_cycle.phase_changed.connect(_on_phase_changed)

	DialogueManager.dialogue_started.connect(func(_resource): _is_dialogue_active = true)
	DialogueManager.dialogue_ended.connect(func(_resource): _on_dialogue_ended())

	_tutorial_manager = get_node_or_null("/root/TutorialManager")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory_toggle") and _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.toggle_inventory_overlay()
	if Input.is_action_just_pressed("ledger_toggle") \
		and ((_tavern_view != null and is_instance_valid(_tavern_view)) \
		or (_day_map_view != null and is_instance_valid(_day_map_view))):
		request_open_document("ledger")

	if day_cycle.phase == DayCycleSystem.DayPhase.NIGHT and _tavern_view != null and is_instance_valid(_tavern_view):
		var tutorial_active = _tutorial_manager != null and _tutorial_manager._is_active
		var menu_open = _tavern_view.is_menu_open()
		if not _is_dialogue_active and not tutorial_active and not _guest_lingering:
			guests.update(delta, guests.has_guest, menu_open)
		if guests.has_guest:
			_tavern_view.update_timer(guests.current_guest.patience / GuestData.BASE_PATIENCE)

func register_view(view: Node) -> void:
	if view is TavernView:
		_tavern_view = view
		_guest_lingering = false
		guests.configure_night(ryan_slice.normal_order_limit(economy.current_day))
		_tavern_view.configure_slice_day(economy.current_day)
		_refresh_tavern_ui()
		_refresh_close_button()

		# 教程：首次进入酒馆，先检查是否需要触发教程
		var tm = _tutorial_manager
		var tutorial_will_start = tm != null and not tm.tavern_first_entered

		if tutorial_will_start:
			tm.tavern_first_entered = true
			tm._save_state()

		narrative.select_today_important_npc(economy.current_day)
		_important_npc_pending = false

		if narrative.today_important_npc != "":
			var npc = null
			for n in narrative.all_npcs:
				if n.id == narrative.today_important_npc:
					npc = n
					break
			if npc != null:
				_important_npc_pending = true
				var scene = null
				for s in npc.scenes:
					if s.day == economy.current_day:
						scene = s
						break
				var order_key = scene.order if scene != null else "bread"

				if tutorial_will_start:
					# 教程结束后再生成重要 NPC（如莱恩）
					tm.tutorial_sequence_ended.connect(
						_spawn_npc_after_tutorial.bind(npc.id, order_key),
						CONNECT_ONE_SHOT
					)
				else:
					guests.spawn_important(npc.id, order_key)

		if tutorial_will_start:
			view.call_deferred("trigger_craft_tutorial")

		_refresh_close_button()

	elif view is DayMapView:
		_day_map_view = view
		start_day_map(economy.current_day)
		save_sys.write(_capture_save_state())
		_day_map_view.show_day(economy.current_day, ryan_slice.last_day())

	elif view is EndingScreen:
		_ending_screen = view
		_ending_screen.show_endings(economy.gold, economy.reputation,
			ryan_slice.total_orders_success, narrative.endings)

func start_day_map(day: int) -> void:
	day_map.start_day(day)
	day_map.set_document_read("bloodied_contract", documents.is_read("bloodied_contract"))
	day_map.set_lead_flag("ryan_warhammer_lead", bool(narrative.get_var("ryan_warhammer_lead")))
	for entry in ryan_slice.day_start_ledger_entries(day):
		if documents.add_ledger_entry_once(String(entry)):
			play_audio_event("new_document")


func visit_day_location(location_id: String) -> Dictionary:
	day_map.set_document_read("bloodied_contract", documents.is_read("bloodied_contract"))
	var result := day_map.visit(location_id)
	if not bool(result.get("success", false)):
		return result
	for key in result.get("rewards", []):
		add_to_inventory(String(key), 1)
	for document_id in result.get("documents", []):
		grant_mine_document(String(document_id))
	return result


func grant_mine_document(document_id: String) -> bool:
	# 矿道场景捡起委托书时的授予入口（中介模式：View 不直接碰 DocumentSystem）。
	# 返回是否「本次新授予」。授予后立即加入故事物品背包。
	var id := String(document_id)
	var already_owned := documents.owns_document(id)
	var newly := documents.grant_document(id) and not already_owned
	if newly:
		play_audio_event("new_document")
		# 文档作为故事物品立即放入背包，无需先阅读（玩家可双击背包中物品打开阅读）
		if inventory_sys.is_story_item(id):
			add_to_inventory(id, 1)
		# 同步到大世界：拥有文档即视为已获取线索（无需先阅读），公会柜台等依赖 requiresRead 的地点可解锁
		day_map.set_document_owned(id, true)
	return newly


func enter_night_from_day_map() -> void:
	if day_cycle.phase == DayCycleSystem.DayPhase.DAY:
		day_cycle.next_phase()


func _on_gathering_confirmed(assignments: Dictionary) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var locations: Array = _load_locations_data()

	for loc_id in assignments:
		var count: int = assignments[loc_id]
		var loc = null
		for l in locations:
			if l.id == loc_id:
				loc = l
				break
		if loc == null:
			continue

		var materials: Array = loc.materials
		if economy.current_day == 2 and loc_id == "mushroom_forest":
			materials = ["sleep_powder"]

		for _i in range(count):
			var mat = materials[rng.randi() % materials.size()]
			inventory_sys.add(mat, 1)

	notify_inventory_changed()
	day_cycle.next_phase()

func _load_locations_data() -> Array[LocationData]:
	var file = FileAccess.open("res://data/locations.json", FileAccess.READ)
	if file == null:
		return [] as Array[LocationData]
	var json_text = file.get_as_text()
	file.close()
	var data: Dictionary = JSON.parse_string(json_text)
	if data == null:
		return [] as Array[LocationData]
	var result: Array[LocationData] = []
	for loc_dict in data["locations"]:
		var loc = LocationData.new()
		loc.id = loc_dict["id"]
		loc.name = loc_dict["name"]
		loc.cost = loc_dict["cost"]
		loc.materials = []
		for m in loc_dict["materials"]:
			loc.materials.append(m)
		loc.description = loc_dict["description"]
		result.append(loc)
	return result

func _on_phase_changed(phase: int) -> void:
	if phase == DayCycleSystem.DayPhase.NIGHT:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/Tavern.tscn")
	else:
		if ryan_slice.should_finish_after_day(economy.current_day):
			get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/EndingScreen.tscn")
		else:
			economy.current_day += 1
			get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/DayMap.tscn")

func _on_guest_arrived(guest: GuestData) -> void:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	_refresh_close_button()

	var item: Dictionary = craft.get_item(guest.order_key)
	var display_name = guest.guest_name
	if guest.has_dialogue:
		for npc in narrative.all_npcs:
			if npc.id == guest.npc_id:
				display_name = npc.npc_name
				break
		display_name = ryan_slice.important_display_name(economy.current_day, guest.npc_id, display_name)
	_tavern_view.show_customer(display_name, item.get("name", guest.order_key), guest.npc_id if guest.npc_id != "" else "guest")

	var tm = get_node_or_null("/root/TutorialManager")

	# 重要 NPC 的对话优先于服务教程
	if guest.has_dialogue:
		var tutorial_active = tm != null and tm._is_active
		if not tutorial_active:
			narrative.today_important_npc = guest.npc_id
			# Day 3 揭晓前按玩家实际行为定格 Ryan 结局，使 ryan_day3 对话能读到 ryan_ending。
			if economy.current_day == 3 and guest.npc_id == "ryan":
				narrative.finalize_ryan_ending()
			var dialogue_path = "res://dialogue/" + guest.npc_id + "_day" + str(economy.current_day) + ".pre.dialogue"
			_dialogue_phase = "pre"
			_tavern_view.set_dialogue_mode(true)
			call_deferred("_start_dialogue_deferred", dialogue_path)
	else:
		# 服务教程：仅对普通客人触发，不对重要 NPC 触发
		if tm != null and not tm.first_guest_arrived and not tm._is_active:
			tm.first_guest_arrived = true
			tm._save_state()
			await get_tree().create_timer(0.5).timeout
			if tm != null and is_instance_valid(tm):
				var rects = {
					"CustomerArea": [432, 70, 410, 328],
				}
				tm.start_tutorial("serve", rects)

## 教程结束后生成重要 NPC（避免教程期间对话冲突）
func _spawn_npc_after_tutorial(group_id: String, npc_id: String, order_key: String) -> void:
	if group_id != "craft":
		return
	guests.spawn_important(npc_id, order_key)

## 公开上菜入口：沙盘 / 未来 BarWorkspace 调用，避免依赖 craft_station 信号。
func request_serve(item_key: String, craft_style_data: Dictionary = {}, seasoning_attribute: String = "") -> void:
	_on_serve_requested(item_key, seasoning_attribute, craft_style_data)

## 上菜判定逻辑（从 register_view lambda 提取）
func _on_serve_requested(item_key: String, seasoning_attribute: String, craft_style_data: Dictionary = {}) -> void:
	if not guests.has_guest or item_key == "" or _guest_lingering:
		return

	var is_important = guests.current_guest.has_dialogue
	var npc_id = guests.current_guest.npc_id
	var success: bool = (item_key == guests.current_guest.order_key)

	var item: Dictionary = craft.get_item(item_key)
	var item_price: int = item.get("price", 0)

	if success:
		economy.add_gold(item_price)
		economy.add_reputation(2)
		guests.record_order_success()
		ryan_slice.record_order_success()
		play_audio_event("serve_success")
		if is_important:
			narrative.set_var("serve_result", "success")
	else:
		guests.record_order_failed()
		play_audio_event("serve_fail")
		if is_important:
			narrative.set_var("serve_result", "fail")

	# L3 动作风格 → 信任阀门：仅重要 NPC 且订单正确时评估（失败不叠风格罚）
	if is_important and success and npc_id != "":
		var serve_style_label: String = craft_style.classify(craft_style_data)
		var mem: Dictionary = craft.get_memory_for(item_key)
		var story_key: String = mem.get(npc_id, "")
		var l3: Dictionary = narrative.resolve_serve_style(npc_id, story_key, serve_style_label)
		narrative.resolve_pending_alternative(npc_id)
		print("[L3] serve_drop_speed=", craft_style_data.get("serve_drop_speed", 0.0),
			" style=", serve_style_label, " story_told=", l3["story_told"],
			" aff_", npc_id, "=", narrative.get_affection(npc_id))

	if seasoning_attribute != "":
		narrative.set_var("seasoning_used", seasoning_attribute)

	guests.record_guest_served()

	var outcome: String
	if success:
		outcome = "success"
	elif item.get("type", "") == "product":
		outcome = "fail_wrong"
	else:
		outcome = "fail_weird"

	if is_important and npc_id != "":
		var post_path = "res://dialogue/" + npc_id + "_day" + str(economy.current_day) + ".post.dialogue"
		if FileAccess.file_exists(post_path):
			# 有 post.dialogue：对话本身就是反应，不再补气泡（消除冗余）。
			_dialogue_phase = "post"
			_tavern_view.set_dialogue_mode(true)
			call_deferred("_start_dialogue_deferred", post_path)
		else:
			_react_then_clear(outcome)
	else:
		_react_then_clear(outcome)

## 散客 / 无 post 重要客人：气泡反应一句 → 停留让玩家读到 → 清场。
func _react_then_clear(outcome: String) -> void:
	if _tavern_view != null and is_instance_valid(_tavern_view) and guests.current_guest != null:
		var line: String = guests.get_reaction_line(outcome, guests.current_guest.npc_id)
		_tavern_view.customer_say(line)
	_guest_lingering = true
	await get_tree().create_timer(1.8).timeout
	_guest_lingering = false
	guests.clear_guest()

func _start_dialogue_deferred(dialogue_path: String) -> void:
	var dialogue_resource = load(dialogue_path)
	if dialogue_resource == null:
		printerr("[GameManager] 对话文件加载失败: ", dialogue_path)
		_recover_from_dialogue_failure()
		return
	var extra_states: Array = [narrative.dialogue_vars]
	var balloon = DialogueManager.show_example_dialogue_balloon(dialogue_resource, "start", extra_states)
	if balloon == null:
		printerr("[GameManager] 显示对话气球失败: ", dialogue_path)
		_recover_from_dialogue_failure()
		return
	balloon.will_block_other_input = false

func _recover_from_dialogue_failure() -> void:
	_dialogue_phase = ""
	_is_dialogue_active = false
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.set_dialogue_mode(false)
	if guests.has_guest and guests.current_guest.has_dialogue:
		guests.clear_guest()

func _on_guest_left() -> void:
	if guests.current_guest != null and guests.current_guest.has_dialogue:
		_important_npc_pending = false
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.hide_customer()
	_refresh_close_button()

func _on_dialogue_ended() -> void:
	_is_dialogue_active = false

	if _dialogue_phase == "pre":
		_dialogue_phase = ""
		if _tavern_view != null and is_instance_valid(_tavern_view):
			_tavern_view.set_dialogue_mode(false)
		# 注：药酒导致 Ryan 离场现在由 request_narrative_delivery 在动作发生时处理，
		# 不再依赖 pre 对话结束（拖拽递交发生在 pre 对话之后）。

	elif _dialogue_phase == "post":
		_dialogue_phase = ""
		guests.clear_guest()
		if _tavern_view != null and is_instance_valid(_tavern_view):
			_tavern_view.set_dialogue_mode(false)

func _on_patience_low() -> void:
	if _tavern_view != null and is_instance_valid(_tavern_view) and guests.current_guest != null:
		_tavern_view.customer_say(guests.get_reaction_line("impatient", guests.current_guest.npc_id))

func _on_guest_abandoned() -> void:
	_react_then_clear("fail_abandon")

func _on_normal_orders_completed() -> void:
	_refresh_close_button()

func end_night() -> void:
	if day_cycle.phase != DayCycleSystem.DayPhase.NIGHT:
		return
	if guests.has_guest or _guest_lingering:
		return
	if _important_npc_pending:
		# 等待中允许点「打烊」，但今晚还有要紧客人没到——场内浮字提示并拒绝关门，避免跳过其剧情。
		if _tavern_view != null and is_instance_valid(_tavern_view):
			_tavern_view.show_stage_caption("今晚还有要紧的客人没露面……", Color.ORANGE)
		return

	var fates = narrative.get_today_npc_fates(economy.current_day)

	current_ledger_data = LedgerData.new()
	current_ledger_data.day = economy.current_day
	current_ledger_data.gold_today = economy.gold_today
	current_ledger_data.rep_today = economy.rep_today
	current_ledger_data.gold_total = economy.gold
	current_ledger_data.rep_total = economy.reputation
	current_ledger_data.guests_served = guests.guests_served_today
	current_ledger_data.orders_success = guests.orders_success
	current_ledger_data.orders_failed = guests.orders_failed
	current_ledger_data.npc_fates = fates
	ryan_slice.complete_day(economy.current_day)

	economy.reset_daily()
	guests.reset_daily()

	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/LedgerScreen.tscn")

func buy_material(key: String, quantity: int, discount: float = 1.0) -> bool:
	if quantity < 1:
		return false
	var unit_price: int = shop.get_material_price(key, discount)
	var total = unit_price * quantity
	if not economy.spend_gold(total):
		return false
	inventory_sys.add(key, quantity)
	notify_inventory_changed()
	return true

func is_mira_in_shop_today() -> bool:
	var scenes = narrative.get_today_scenes(economy.current_day)
	for npc in scenes:
		if npc.id == "mira":
			return true
	return false

func buy_recipe_unlock(key: String) -> bool:
	if craft.is_recipe_unlocked(key):
		return false
	var price: int = shop.get_recipe_unlock_price(key)
	if price <= 0:
		return false
	if not economy.spend_gold(price):
		return false
	craft.unlock_recipe(key)
	return true

func _refresh_tavern_ui() -> void:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	_tavern_view.update_top_bar(economy.gold, economy.reputation, economy.current_day, ryan_slice.last_day())

func notify_inventory_changed() -> void:
	if inventory.get("sleep_powder", 0) > 0:
		narrative.set_var("has_sleep_powder", true)
	inventory_changed.emit()

func play_audio_event(event_key: String) -> bool:
	if audio == null:
		return false
	return audio.play_event(event_key)

## 中介：把物品能力查询(InventorySystem)与越界分类(WorkspaceSystem)串起来。
func classify_recovery(item_key: String) -> String:
	if item_key == "":
		return "backpack"
	return workspace.recovery_target(inventory_sys.get_capabilities(item_key))

## 越界回收一个桌面物品的库存语义。返回回收去向。
## backpack: 加回库存（材料/剧情物品不丢失）。其它去向由 BarWorkspace 处理物理摆放。
func recover_desk_item_key(item_key: String) -> String:
	var target := classify_recovery(item_key)
	if target == "backpack":
		add_to_inventory(item_key, 1)
	return target


## 出口③：按钮可用 = 无客人在场 且 不在上菜停留中（等待中即可按；若今晚还有要紧客人没到，
## 点击会被 end_night 以场内浮字拦下、不关门，避免跳过其剧情）。
func _refresh_close_button() -> void:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	var enabled := not guests.has_guest and not _guest_lingering
	_tavern_view.set_close_enabled(enabled)


## 把 resolve_action 的 feedback key 翻成玩家可见提示（出口②舞台浮字）。
func _show_action_feedback(feedback: String) -> void:
	if ACTION_FEEDBACK.has(feedback):
		var entry: Array = ACTION_FEEDBACK[feedback]
		if _tavern_view != null and is_instance_valid(_tavern_view):
			_tavern_view.show_stage_caption(String(entry[0]), entry[1])


## 当前客人订单 key（无客人返回 ""）。视图据此区分「正式上菜」与「叙事递交」。
func current_order_key() -> String:
	if not guests.has_guest or guests.current_guest == null:
		return ""
	return guests.current_guest.order_key


## 把沉睡花粉搅进桌面成品（spec §7.3 add_story_item_to_product）。
## 库存不变：花粉桌面物体已在取出时扣减，接受时由视图 free（＝被搅进酒里消耗）。
## 返回 resolve_action 结果（接受时含 product_tags）。
func request_apply_story_item_to_product(story_key: String, product_key: String) -> Dictionary:
	var r: Dictionary = narrative.resolve_action({
		"type": "add_story_item_to_product",
		"item_key": story_key,
		"product_key": product_key,
	})
	_show_action_feedback(String(r.get("feedback", "")))
	return r


## 香料罐撒料的纯判定入口（spec §5）。SeasoningShaker 摇够后调用。
## 口味香料无条件写 attribute；效果香料（带 product_tag）复用既有叙事闸门
## （add_story_item_to_product：迷睡花粉只接受 ale_beer），通过才写 attribute + tag。
## 返回 {accepted, attribute, product_tags, feedback}；视图据此写到成品 DeskItem。
func resolve_seasoning_application(seasoning_key: String, product_key: String) -> Dictionary:
	if not seasoning.is_seasoning(seasoning_key):
		return {"accepted": false, "attribute": "", "product_tags": [], "feedback": "not_seasoning"}
	var tag: String = seasoning.get_product_tag(seasoning_key)
	if tag != "":
		# 效果香料：复用既有叙事闸门入口（限定产物规则 + 玩家反馈都在 request_apply_story_item_to_product 里）。
		var r: Dictionary = request_apply_story_item_to_product(seasoning_key, product_key)
		if not bool(r.get("accepted", false)):
			return {"accepted": false, "attribute": "", "product_tags": [], "feedback": String(r.get("feedback", ""))}
		return {
			"accepted": true,
			"attribute": seasoning.get_attribute(seasoning_key),
			"product_tags": r.get("product_tags", []),
			"feedback": String(r.get("feedback", "")),
		}
	# 口味香料：无条件应用。
	return {"accepted": true, "attribute": seasoning.get_attribute(seasoning_key), "product_tags": [], "feedback": ""}


## 把剧情物品/叙事载体成品递交给当前客人（spec §7.2 / §7.3）。
## 物理拖到客人身上时由 BarWorkspace 调用。返回：
##   handled：本方法是否接管（false 时视图走正常上菜结算）。
##   accepted / interaction_closed：resolve_action 结果。
##   consume：视图是否应直接消耗该桌面物体（false 时回收：剧情物品回背包、成品回回收区）。
func request_narrative_delivery(item_key: String, product_tags: Array = []) -> Dictionary:
	if not guests.has_guest or guests.current_guest == null:
		return {"handled": false}
	var npc_id: String = guests.current_guest.npc_id

	if inventory_sys.is_story_item(item_key):
		var r: Dictionary = narrative.resolve_action({
			"type": "give_story_item",
			"npc_id": npc_id,
			"item_key": item_key,
		})
		var feedback: String = String(r.get("feedback", ""))
		# 错误递交（递错人/不认得的物品）→ 自动回背包，不显示动作反馈
		if feedback in ["unsupported_npc", "unsupported_story_item"]:
			if _tavern_view != null and is_instance_valid(_tavern_view):
				_tavern_view.show_stage_caption("他不需要这个，收回了吧。", Color.GRAY)
			return {"handled": true, "accepted": false, "consume": false, "interaction_closed": false, "feedback": feedback}
		_show_action_feedback(feedback)
		var accepted: bool = bool(r.get("accepted", false))
		return {"handled": true, "accepted": accepted, "consume": accepted,
			"interaction_closed": bool(r.get("interaction_closed", false)), "feedback": feedback}

	if inventory_sys.is_product(item_key):
		var r: Dictionary = narrative.resolve_action({
			"type": "give_product",
			"npc_id": npc_id,
			"product_key": item_key,
			"product_tags": product_tags,
		})
		var feedback: String = String(r.get("feedback", ""))
		# 非叙事载体成品（含正式订单）→ 交回视图走正常上菜结算
		if feedback in ["unsupported_product", "unsupported_npc"]:
			return {"handled": false}
		_show_action_feedback(feedback)
		var accepted: bool = bool(r.get("accepted", false))
		# 接受药酒 → Ryan 当场睡过去，离场（spec §10.2）
		if accepted and feedback == "ryan_drugged":
			guests.clear_guest()
			if _tavern_view != null and is_instance_valid(_tavern_view):
				_tavern_view.hide_customer()
		return {"handled": true, "accepted": accepted, "consume": accepted,
			"interaction_closed": bool(r.get("interaction_closed", false)), "feedback": feedback}

	return {"handled": false}


func request_open_document(document_id: String) -> Dictionary:
	# 首次阅读 evidence 类型文档时，将其标题和正文记入账本。
	var first_read: bool = documents.owns_document(document_id) and not documents.is_read(document_id)
	var document := documents.request_open(document_id)
	if document.is_empty():
		return document
	if first_read and String(document.get("kind", "")) == "evidence":
		documents.add_document_to_ledger(document_id)
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.open_document(document)
	elif _day_map_view != null and is_instance_valid(_day_map_view):
		_day_map_view.open_document(document)
	return document

func add_to_inventory(key: String, amount: int = 1) -> void:
	if key == "":
		return
	inventory_sys.add(key, amount)
	notify_inventory_changed()

func remove_from_inventory(key: String, amount: int = 1) -> bool:
	if not inventory_sys.remove(key, amount):
		return false
	notify_inventory_changed()
	return true

func try_load_material_icon(key: String) -> Texture2D:
	if MATERIAL_ICON_PATHS.has(key):
		return TextureManager.try_load(MATERIAL_ICON_PATHS[key])
	return null

func _load_initial_inventory() -> Dictionary:
	var file = FileAccess.open("res://data/inventory_default.json", FileAccess.READ)
	if file != null:
		var json_text = file.get_as_text()
		file.close()
		var data = JSON.parse_string(json_text)
		if data is Dictionary:
			return data

	return {
		"ale": 20, "grape": 20, "flour": 20, "meat_raw": 20, "herb": 20
	}


## ── 存档（spec §12）。SaveSystem 只管磁盘+字典，业务知识留在 GameManager。──

## 收集当日稳定状态（spec §12.1）。不含夜间物理/拖拽/夜间计数器（§12.2）。
func _capture_save_state() -> Dictionary:
	return {
		"economy": {
			"current_day": economy.current_day,
			"gold": economy.gold,
			"reputation": economy.reputation,
			"tavern_level": economy.tavern_level,
		},
		"inventory": inventory_sys.materials.duplicate(),
		"documents": documents.capture_state(),
		"narrative": {
			"dialogue_vars": narrative.dialogue_vars.duplicate(true),
			"affection": narrative.affection.duplicate(true),
			"endings": narrative.endings.duplicate(true),
			"today_important_npc": narrative.today_important_npc,
		},
		"craft": {"unlocked_recipes": craft.unlocked_recipes.duplicate()},
		"tutorial": _capture_tutorial_state(),
		"ryan_slice": ryan_slice.capture_state(),
	}

func _capture_tutorial_state() -> Dictionary:
	var tm = _tutorial_manager
	if tm == null:
		return {}
	return {
		"completed_steps": tm._completed_steps.duplicate(),
		"daymap_first_shown": tm.daymap_first_shown,
		"tavern_first_entered": tm.tavern_first_entered,
		"shop_first_visited": tm.shop_first_visited,
		"first_guest_arrived": tm.first_guest_arrived,
		"first_product_seasoned": tm.first_product_seasoned,
		"first_guest_served": tm.first_guest_served,
		"first_ledger_shown": tm.first_ledger_shown,
	}

## 把快照写回各子系统。只恢复稳定状态，不推进日期。
func _apply_save_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var eco: Dictionary = data.get("economy", {})
	economy.current_day = int(eco.get("current_day", 1))
	economy.gold = int(eco.get("gold", 0))
	economy.reputation = int(eco.get("reputation", 0))
	economy.tavern_level = int(eco.get("tavern_level", 1))
	economy.gold_today = 0
	economy.rep_today = 0

	inventory_sys.set_initial(data.get("inventory", {}))

	documents.restore_state(data.get("documents", {}))

	var nar: Dictionary = data.get("narrative", {})
	narrative.dialogue_vars = (nar.get("dialogue_vars", {}) as Dictionary).duplicate(true)
	narrative.affection = (nar.get("affection", {}) as Dictionary).duplicate(true)
	narrative.endings = (nar.get("endings", {}) as Dictionary).duplicate(true)
	narrative.today_important_npc = String(nar.get("today_important_npc", ""))

	craft.unlocked_recipes.clear()
	for r in data.get("craft", {}).get("unlocked_recipes", []):
		craft.unlocked_recipes.append(String(r))

	_apply_tutorial_state(data.get("tutorial", {}))
	ryan_slice.restore_state(data.get("ryan_slice", {}))
	notify_inventory_changed()

func _apply_tutorial_state(t: Dictionary) -> void:
	var tm = _tutorial_manager
	if tm == null or t.is_empty():
		return
	tm._completed_steps = (t.get("completed_steps", []) as Array).duplicate()
	tm.daymap_first_shown = bool(t.get("daymap_first_shown", false))
	tm.tavern_first_entered = bool(t.get("tavern_first_entered", false))
	tm.shop_first_visited = bool(t.get("shop_first_visited", false))
	tm.first_guest_arrived = bool(t.get("first_guest_arrived", false))
	tm.first_product_seasoned = bool(t.get("first_product_seasoned", false))
	tm.first_guest_served = bool(t.get("first_guest_served", false))
	tm.first_ledger_shown = bool(t.get("first_ledger_shown", false))
	tm._save_state()

## 标题页入口（spec §12.3）。
func has_save() -> bool:
	return save_sys.has_save()

func continue_game() -> void:
	var data := save_sys.read()
	if data.is_empty():
		return
	_apply_save_state(data)
	day_cycle.phase = DayCycleSystem.DayPhase.DAY
	get_tree().change_scene_to_file("res://scenes/ui/DayMap.tscn")

func restart_current_day() -> void:
	# 只有日初快照，重开当天 == 加载该快照（spec §12 "从稳定初始状态开始"）。
	continue_game()

func new_game() -> void:
	save_sys.clear()
	_apply_save_state(_default_new_game_state())
	day_cycle.phase = DayCycleSystem.DayPhase.DAY
	get_tree().change_scene_to_file("res://scenes/ui/DayMap.tscn")

func _default_new_game_state() -> Dictionary:
	return {
		"economy": {"current_day": 1, "gold": 0, "reputation": 0, "tavern_level": 1},
		"inventory": _load_initial_inventory(),
		"documents": {"owned": ["ledger"], "read": {}, "archived": [], "ledger_entries": []},
		"narrative": {"dialogue_vars": _fresh_narrative_vars(), "affection": {"ryan": 0, "mira": 5},
			"endings": {}, "today_important_npc": ""},
		"craft": {"unlocked_recipes": []},
		"tutorial": {"completed_steps": [], "daymap_first_shown": false, "tavern_first_entered": false,
			"shop_first_visited": false, "first_guest_arrived": false, "first_product_seasoned": false,
			"first_guest_served": false, "first_ledger_shown": false},
		"ryan_slice": {"total_orders_success": 0, "completed_days": []},
	}

## 与 narrative_manager.load_npc_data() 的默认值保持一致（fresh game 的真相源）。
func _fresh_narrative_vars() -> Dictionary:
	return {
		"has_sleep_powder": false, "ryan_informed": false, "ryan_has_alternative": false,
		"ryan_warhammer_lead": false,
		"ryan_drugged": false, "ryan_interaction_closed": false, "ryan_ending": "",
		"ryan_alternative_pending": false, "ryan_alternative_declined": false,
		"aff_ryan": 0, "aff_mira": 5,
	}
