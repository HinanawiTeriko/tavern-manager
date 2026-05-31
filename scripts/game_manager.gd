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

# Inventory
var inventory_sys: InventorySystem
var inventory: Dictionary = {}
var current_ledger_data: LedgerData = null

# Dialogue state
var _is_dialogue_active: bool = false
var _dialogue_phase: String = ""

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
}

## resolve_action 的 feedback key → 玩家可见提示 [文案, 颜色]。
## 对话只回应已发生的行为；这里是动作当下的即时反馈（spec §1.1 / §7.3）。
const ACTION_FEEDBACK: Dictionary = {
	"ryan_informed": ["莱恩盯着那份染血的委托书，脸色一点点沉了下来。", Color.ORANGE],
	"ryan_accepts_alternative": ["莱恩收起替代委托，郑重地点了点头。", Color.LIME_GREEN],
	"ryan_needs_warning_first": ["莱恩疑惑地看着这份委托，似乎还不明白其中的分量。", Color.GRAY],
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
		if not _is_dialogue_active and not tutorial_active:
			guests.update(delta, guests.has_guest, menu_open)
		if guests.has_guest:
			_tavern_view.update_timer(guests.current_guest.patience / GuestData.BASE_PATIENCE)

func register_view(view: Node) -> void:
	if view is TavernView:
		_tavern_view = view
		_refresh_tavern_ui()


		# 教程：首次进入酒馆，先检查是否需要触发教程
		var tm = _tutorial_manager
		var tutorial_will_start = tm != null and not tm.tavern_first_entered

		if tutorial_will_start:
			tm.tavern_first_entered = true
			tm._save_state()

		narrative.select_today_important_npc(economy.current_day)

		if narrative.today_important_npc != "":
			var npc = null
			for n in narrative.all_npcs:
				if n.id == narrative.today_important_npc:
					npc = n
					break
			if npc != null:
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

	elif view is DayMapView:
		_day_map_view = view
		start_day_map(economy.current_day)
		_day_map_view.show_day(economy.current_day, EconomySystem.MAX_DAYS)

	elif view is EndingScreen:
		_ending_screen = view
		_ending_screen.show_endings(economy.gold, economy.reputation, narrative.endings)

func start_day_map(day: int) -> void:
	day_map.start_day(day)
	day_map.set_document_read("bloodied_contract", documents.is_read("bloodied_contract"))


func visit_day_location(location_id: String) -> Dictionary:
	day_map.set_document_read("bloodied_contract", documents.is_read("bloodied_contract"))
	var result := day_map.visit(location_id)
	if not bool(result.get("success", false)):
		return result
	for key in result.get("rewards", []):
		add_to_inventory(String(key), 1)
	for document_id in result.get("documents", []):
		documents.grant_document(String(document_id))
	return result


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
		economy.current_day += 1
		if economy.current_day > EconomySystem.MAX_DAYS:
			get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/EndingScreen.tscn")
		else:
			get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/DayMap.tscn")

func _on_guest_arrived(guest: GuestData) -> void:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return

	var item: Dictionary = craft.get_item(guest.order_key)
	var display_name = guest.guest_name
	if guest.has_dialogue:
		for npc in narrative.all_npcs:
			if npc.id == guest.npc_id:
				display_name = npc.npc_name
				break
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
func request_serve(item_key: String, craft_style_data: Dictionary = {}, seasoning_tag: String = "") -> void:
	_on_serve_requested(item_key, seasoning_tag, craft_style_data)

## 上菜判定逻辑（从 register_view lambda 提取）
func _on_serve_requested(item_key: String, seasoning_tag: String, craft_style_data: Dictionary = {}) -> void:
	if not guests.has_guest or item_key == "":
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
		_tavern_view.show_message("完美！" + guests.current_guest.guest_name + " 很满意！", Color.LIME_GREEN)
		if is_important:
			narrative.set_var("serve_result", "success")
	else:
		guests.record_order_failed()
		if item.get("type", "") == "product":
			_tavern_view.show_message("错了！" + guests.current_guest.guest_name + " 要的不是这个！", Color.RED)
		else:
			_tavern_view.show_message("这看起来不太对劲……" + guests.current_guest.guest_name + " 很失望。", Color.RED)
		if is_important:
			narrative.set_var("serve_result", "fail")

	# L3 动作风格 → 信任阀门：仅重要 NPC 且订单正确时评估（失败不叠风格罚）
	if is_important and success and npc_id != "":
		var serve_style_label: String = craft_style.classify(craft_style_data)
		var mem: Dictionary = craft.get_memory_for(item_key)
		var story_key: String = mem.get(npc_id, "")
		var l3: Dictionary = narrative.resolve_serve_style(npc_id, story_key, serve_style_label)
		print("[L3] serve_drop_speed=", craft_style_data.get("serve_drop_speed", 0.0),
			" style=", serve_style_label, " story_told=", l3["story_told"],
			" aff_", npc_id, "=", narrative.get_affection(npc_id))

	if seasoning_tag != "":
		narrative.set_var("seasoning_used", seasoning_tag)

	guests.record_guest_served()

	if is_important and npc_id != "":
		var post_path = "res://dialogue/" + npc_id + "_day" + str(economy.current_day) + ".post.dialogue"
		if FileAccess.file_exists(post_path):
			_dialogue_phase = "post"
			_tavern_view.set_dialogue_mode(true)
			call_deferred("_start_dialogue_deferred", post_path)
		else:
			guests.clear_guest()
	else:
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
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.hide_customer()

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
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.show_message("客人等得不耐烦了……", Color.ORANGE)

func end_night() -> void:
	if day_cycle.phase != DayCycleSystem.DayPhase.NIGHT:
		return
	if guests.has_guest:
		if _tavern_view != null and is_instance_valid(_tavern_view):
			_tavern_view.show_message("还有客人在等呢！", Color.ORANGE)
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
	_tavern_view.update_top_bar(economy.gold, economy.reputation, economy.current_day, EconomySystem.MAX_DAYS)

func notify_inventory_changed() -> void:
	if inventory.get("sleep_powder", 0) > 0:
		narrative.set_var("has_sleep_powder", true)
	inventory_changed.emit()

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


## null 安全的提示输出（headless 测试无 _tavern_view）。
func _show_message(text: String, color: Color = Color.WHITE) -> void:
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.show_message(text, color)


## 把 resolve_action 的 feedback key 翻成玩家可见提示。
func _show_action_feedback(feedback: String) -> void:
	if ACTION_FEEDBACK.has(feedback):
		var entry: Array = ACTION_FEEDBACK[feedback]
		_show_message(String(entry[0]), entry[1])


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
			_show_message("他不需要这个，收回了吧。", Color.GRAY)
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
	# 剧情证据首次读过后进入剧情物品栏（spec §8.3），之后可从背包拖出递交给 NPC。
	var first_read: bool = documents.owns_document(document_id) and not documents.is_read(document_id)
	var document := documents.request_open(document_id)
	if document.is_empty():
		return document
	if first_read and String(document.get("kind", "")) == "evidence" and inventory_sys.is_story_item(document_id):
		add_to_inventory(document_id, 1)
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
