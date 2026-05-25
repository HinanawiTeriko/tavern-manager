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

# Inventory
var inventory: Dictionary = {}
var current_ledger_data: LedgerData = null

# Dialogue state
var _is_dialogue_active: bool = false
var _dialogue_phase: String = ""

# Scene refs
var _tavern_view = null
var _day_map_view = null
var _ending_screen = null

const MATERIAL_ICON_PATHS: Dictionary = {
	"ale": "res://assets/textures/icons/materials/ale.png",
	"grape": "res://assets/textures/icons/materials/wine.png",
	"flour": "res://assets/textures/icons/materials/bread.png",
	"meat_raw": "res://assets/textures/icons/materials/meat.png",
	"herb": "res://assets/textures/icons/materials/herb.png",
}

func _ready() -> void:
	economy = EconomySystem.new()
	day_cycle = DayCycleSystem.new()
	narrative = NarrativeManager.new()
	shop = ShopSystem.new()
	craft = CraftSystem.new()
	seasoning = SeasoningSystem.new()

	inventory = _load_initial_inventory()
	craft.load_data()
	narrative.load_npc_data()
	shop.load_config()
	seasoning.load_data()

	guests = GuestSystem.new(func():
		var available: Array = []
		for key in craft.items:
			if craft.items[key].get("price", 0) > 0:
				available.append(key)
		return available
	)
	guests.guest_arrived.connect(_on_guest_arrived)
	guests.guest_left.connect(_on_guest_left)
	guests.patience_low.connect(_on_patience_low)

	economy.changed.connect(_refresh_tavern_ui)
	day_cycle.phase_changed.connect(_on_phase_changed)

	DialogueManager.dialogue_started.connect(func(_resource): _is_dialogue_active = true)
	DialogueManager.dialogue_ended.connect(func(_resource): _on_dialogue_ended())

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu_toggle") and _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view._toggle_menu()

	if day_cycle.phase == DayCycleSystem.DayPhase.NIGHT and _tavern_view != null and is_instance_valid(_tavern_view):
		var menu_open = _tavern_view._menu_panel.visible if _tavern_view._menu_panel != null else false
		if not _is_dialogue_active:
			guests.update(delta, guests.has_guest, menu_open)
		if guests.has_guest:
			_tavern_view.update_timer(guests.current_guest.patience / GuestData.BASE_PATIENCE)

func register_view(view: Node) -> void:
	if view is TavernView:
		_tavern_view = view
		_refresh_tavern_ui()

		var craft_station = view.get_node("CraftStation")
		if craft_station != null:
			craft_station.serve_requested.connect(func(item_key: String, seasoning_tag: String):
				if not guests.has_guest or item_key == "":
					return

				var is_important = guests.current_guest.has_dialogue
				var npc_id = guests.current_guest.npc_id

				var item: Dictionary = craft.get_item(item_key)
				var item_price: int = item.get("price", 0)

				if item_key == guests.current_guest.order_key:
					economy.add_gold(item_price)
					economy.add_reputation(2)
					guests.record_order_success()
					view.show_message("完美！" + guests.current_guest.guest_name + " 很满意！", Color.LIME_GREEN)
					if is_important:
						narrative.set_var("serve_result", "success")
				else:
					guests.record_order_failed()
					if item_price > 0:
						view.show_message("错了！" + guests.current_guest.guest_name + " 要的不是这个！", Color.RED)
					else:
						view.show_message("这看起来不太对劲……" + guests.current_guest.guest_name + " 很失望。", Color.RED)
					if is_important:
						narrative.set_var("serve_result", "fail")

				if seasoning_tag != "":
					narrative.set_var("seasoning_used", seasoning_tag)

				guests.record_guest_served()

				if is_important and npc_id != "":
					var post_path = "res://dialogue/" + npc_id + "_day" + str(economy.current_day) + ".post.dialogue"
					if FileAccess.file_exists(post_path):
						_dialogue_phase = "post"
						view.set_dialogue_mode(true)
						call_deferred("_start_dialogue_deferred", post_path)
					else:
						guests.clear_guest()
				else:
					guests.clear_guest()
			)

		var npcs_today = narrative.get_today_scenes(economy.current_day)
		if npcs_today.size() > 0:
			narrative.today_important_npc = npcs_today[0].id

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
				guests.spawn_important(npc.id, order_key)

	elif view is DayMapView:
		_day_map_view = view
		_day_map_view.show_day(economy.current_day, EconomySystem.MAX_DAYS)
		_day_map_view.gathering_confirmed.connect(_on_gathering_confirmed)

	elif view is EndingScreen:
		_ending_screen = view
		_ending_screen.show_endings(economy.gold, economy.reputation, narrative.endings)

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
			var existing: int = inventory.get(mat, 0)
			inventory[mat] = existing + 1

	inventory_changed.emit()
	day_cycle.next_phase()

func _load_locations_data() -> Array:
	var file = FileAccess.open("res://data/locations.json", FileAccess.READ)
	if file == null:
		return []
	var json_text = file.get_as_text()
	file.close()
	var data: Dictionary = JSON.parse_string(json_text)
	if data == null:
		return []
	var result: Array = []
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

	if guest.has_dialogue:
		narrative.today_important_npc = guest.npc_id
		var dialogue_path = "res://dialogue/" + guest.npc_id + "_day" + str(economy.current_day) + ".pre.dialogue"
		_dialogue_phase = "pre"
		_tavern_view.set_dialogue_mode(true)
		call_deferred("_start_dialogue_deferred", dialogue_path)

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

		var drugged: bool = narrative.dialogue_vars.get("ryan_drugged", false)
		if drugged and guests.has_guest and guests.current_guest.npc_id == "ryan":
			guests.clear_guest()
			if _tavern_view != null and is_instance_valid(_tavern_view):
				_tavern_view.hide_customer()

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

func buy_material(key: String, quantity: int, mira_active: bool = false) -> bool:
	if quantity < 1:
		return false
	var unit_price: int = shop.get_material_price(key, mira_active)
	var total = unit_price * quantity
	if not economy.spend_gold(total):
		return false
	var existing: int = inventory.get(key, 0)
	inventory[key] = existing + quantity
	notify_inventory_changed()
	return true

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

func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	call_deferred("_register_view_deferred", node)

func _register_view_deferred(node: Node) -> void:
	if node is TavernView or node is DayMapView or node is EndingScreen:
		register_view(node)
