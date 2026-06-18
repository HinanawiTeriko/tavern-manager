extends Node

# Signals
signal inventory_changed()

const INFERENCE_SYSTEM_SCRIPT := preload("res://scripts/systems/inference_system.gd")
const RUMOR_SYSTEM_SCRIPT := preload("res://scripts/systems/rumor_system.gd")
const APPETITE_SYSTEM_SCRIPT := preload("res://scripts/systems/appetite_system.gd")

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
var rumors
var appetite
var inference
var save_sys: SaveSystem
var ryan_slice: RyanSliceSystem
var audio: AudioManager
var settings: SettingsManager

# Inventory
const DEFAULT_SHORTCUT_BINDINGS: Array[String] = [
	"ale", "grape", "flour", "meat_raw", "herb", "", "", "", "", ""
]

var inventory_sys: InventorySystem
var inventory: Dictionary = {}
var shortcut_bindings: Array[String] = []
var current_ledger_data: LedgerData = null

# Dialogue state
const DIALOGUE_BALLOON_SCENE := "res://scenes/ui/DialogueBalloon.tscn"
const RYAN_ACTION_FEEDBACK_DIALOGUE := "res://dialogue/ryan_action_feedback.dialogue"
const MIRA_OLD_LEDGER_GOSSIP_GRANTED_DAY_VAR := "mira_old_ledger_gossip_granted_day"
const MIRA_RESPONSIBILITY_STALL_BONUS_SEEN_VAR := "mira_responsibility_stall_bonus_seen"
const MIRA_RESPONSIBILITY_STALL_BONUS := 2
const EVELYN_FINAL_DAY := 20
const EVELYN_PUBLIC_ACCOUNT_GAPS := [
	{
		"id": "toby_identity",
		"flag": "toby_identity_known",
		"label": "托比身份",
		"detail": "托比的名字还没和后巷少年对上。",
	},
	{
		"id": "toby_risk",
		"flag": "toby_commission_lead",
		"label": "黑齿矿脉陷阱",
		"detail": "黑齿矿脉为什么是陷阱还没说清。",
	},
	{
		"id": "mira_old_road",
		"flag": "mira_toby_link_known",
		"label": "米拉旧路",
		"detail": "米拉和托比的旧路还没对上。",
	},
	{
		"id": "mira_responsibility",
		"flag": "mira_responsibility_lead",
		"label": "米拉旧话来源",
		"detail": "“一个人走才轻快”是谁留下的，还没证明。",
	},
	{
		"id": "grey_same_batch",
		"flag": "grey_same_batch_known",
		"label": "同批灰账",
		"detail": "莱恩和托比还没被压进同一批灰账。",
	},
	{
		"id": "grey_payout_method",
		"flag": "grey_payout_method_known",
		"label": "赔付结案顺序",
		"detail": "赔付和结案的顺序还没反过来。",
	},
	{
		"id": "mira_grey_link",
		"flag": "mira_grey_ledger_link_known",
		"label": "米拉供应灰印",
		"detail": "米拉供应协议背面的灰印还没接到账上。",
	},
]
const EVELYN_PUBLIC_ACCOUNT_FINAL_GAP := {
	"id": "public_account",
	"label": "公开抄本",
	"detail": "三条线还没被抄成公开账本。",
}

var _is_dialogue_active: bool = false
var _dialogue_phase: String = ""
var _important_npc_pending: bool = false
var _guest_lingering: bool = false
var _serve_tutorial_pending_after_dialogue: bool = false
var _craft_tutorial_pending_after_menu: bool = false

# 开场交接：刚看完开场后置位，DayMap 一次性消费以走 match-cut 拉镜
var _pending_intro_handoff: bool = false

# Scene refs
var _tavern_view = null
var _day_map_view = null
var _ending_screen = null
var _tutorial_manager = null
var _day_map_state_missing_from_save: bool = false
var _announced_inference_question_ids: Dictionary = {}
var _day_start_snapshot: Dictionary = {}
var _current_day_events: Array = []
var _pending_guest_reaction_suffix: String = ""
var _word_of_mouth: Dictionary = {}

const MATERIAL_ICON_PATHS: Dictionary = {
	"ale": "res://assets/textures/tavern/icons/ale.png",
	"grape": "res://assets/textures/tavern/icons/grape.png",
	"flour": "res://assets/textures/tavern/icons/flour.png",
	"meat_raw": "res://assets/textures/tavern/icons/meat_raw.png",
	"herb": "res://assets/textures/tavern/icons/herb.png",
	"cave_mushroom": "res://assets/textures/tavern/icons/cave_mushroom.png",
	"rock_lizard_meat": "res://assets/textures/tavern/icons/rock_lizard_meat.png",
	"north_sour_grape": "res://assets/textures/tavern/icons/north_sour_grape.png",
	"black_malt": "res://assets/textures/tavern/icons/black_malt.png",
	"dough": "res://assets/textures/tavern/items/dough.png",
	"bread_burnt": "res://assets/textures/tavern/items/bread_burnt.png",
	"meat_burnt": "res://assets/textures/tavern/items/meat_burnt.png",
	"ale_roasted": "res://assets/textures/tavern/items/ale_roasted.png",
	"ale_burnt": "res://assets/textures/tavern/items/ale_burnt.png",
	"grape_juice": "res://assets/textures/tavern/items/grape_juice.png",
	"dough_meat": "res://assets/textures/tavern/items/dough_meat.png",
	"ale_herb": "res://assets/textures/tavern/items/ale_herb.png",
	"grape_herb": "res://assets/textures/tavern/items/grape_herb.png",
	"meat_stew_raw": "res://assets/textures/tavern/items/meat_stew_raw.png",
	"failed_brew": "res://assets/textures/tavern/items/failed_brew.png",
	"failed_stew": "res://assets/textures/tavern/items/failed_stew.png",
	"ale_beer": "res://assets/textures/tavern/items/ale_beer.png",
	"bread": "res://assets/textures/tavern/items/bread.png",
	"meat_cooked": "res://assets/textures/tavern/items/meat_cooked.png",
	"wine": "res://assets/textures/tavern/items/wine.png",
	"herb_tea": "res://assets/textures/tavern/items/herb_tea.png",
	"meat_sand": "res://assets/textures/tavern/items/meat_sand.png",
	"herbal_ale": "res://assets/textures/tavern/items/herbal_ale.png",
	"spiced_wine": "res://assets/textures/tavern/items/spiced_wine.png",
	"meat_stew": "res://assets/textures/tavern/items/meat_stew.png",
	"herb_broth": "res://assets/textures/tavern/items/herb_broth.png",
	"malt_porridge": "res://assets/textures/tavern/items/malt_porridge.png",
	"cave_mushroom_stew": "res://assets/textures/tavern/items/cave_mushroom_stew.png",
	"rock_lizard_steak": "res://assets/textures/tavern/items/rock_lizard_steak.png",
	"old_road_wine": "res://assets/textures/tavern/items/old_road_wine.png",
	"miner_dark_ale": "res://assets/textures/tavern/items/miner_dark_ale.png",
	"spice": "res://assets/textures/icons/items/spice.png",
	"herb_spice": "res://assets/textures/icons/items/herb_spice.png",
	"salt": "res://assets/textures/icons/items/salt.png",
	"sleep_powder": "res://assets/textures/icons/items/sleep_powder.png",
	"bloodied_contract": "res://assets/textures/tavern/items/bloodied_contract.png",
	"alternative_contract": "res://assets/textures/tavern/items/alternative_contract.png",
	"toby_contract": "res://assets/textures/tavern/items/toby_contract.png",
	"grey_ryan_case_number": "res://assets/ui/generated/investigation/clearing_table/items/clearing_ryan_name.png",
	"grey_old_payout_register": "res://assets/ui/generated/investigation/clearing_table/items/clearing_payout_slip.png",
	"grey_missing_page": "res://assets/ui/generated/investigation/clearing_table/items/clearing_unreturned.png",
	"grey_blacktooth_batch": "res://assets/ui/generated/investigation/clearing_table/items/clearing_blacktooth_batch.png",
	"grey_closure_method": "res://assets/ui/generated/investigation/clearing_table/items/clearing_grey_stamp.png",
	"grey_payout_closure": "res://assets/ui/generated/investigation/clearing_table/items/clearing_closure_stamp.png",
	"grey_renamed_escort": "res://assets/ui/generated/investigation/clearing_table/items/clearing_rename_stamp.png",
	"grey_supply_stamp": "res://assets/ui/generated/investigation/clearing_table/items/clearing_supply_contract.png",
}

## resolve_action 的 feedback key → 玩家可见提示 [文案, 颜色]。
## 对话只回应已发生的行为；这里是动作当下的即时反馈（spec §1.1 / §7.3）。
const ACTION_FEEDBACK: Dictionary = {
	"sleep_powder_added": ["你把沉睡花粉搅入了麦芽酒。", Color.MEDIUM_PURPLE],
	"unsupported_story_item": ["他不需要这个。", Color.GRAY],
	"unsupported_npc": ["这东西不该交给他。", Color.GRAY],
	"unsupported_story_product": ["花粉化不进这样东西里。", Color.GRAY],
}

const ACTION_FEEDBACK_CHANNEL: Dictionary = {
	"sleep_powder_added": "silent",
}

const ACTION_FEEDBACK_DIALOGUE_TITLES: Dictionary = {
	"ryan_informed": "ryan_informed",
	"ryan_accepts_alternative": "ryan_accepts_alternative",
	"ryan_needs_warning_first": "ryan_needs_warning_first",
	"ryan_alternative_pending": "ryan_alternative_pending",
	"ryan_accepts_ale": "ryan_accepts_ale",
	"ryan_drugged": "ryan_drugged",
	"ryan_refuses_drugged_ale": "ryan_refuses_drugged_ale",
	"ryan_interaction_closed": "ryan_interaction_closed",
	"mira_informed_trusted": "mira_informed_trusted",
	"mira_informed_guarded": "mira_informed_guarded",
	"mira_informed_unsettled": "mira_informed_unsettled",
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
	shortcut_bindings = _default_shortcut_bindings()
	workspace = WorkspaceSystem.new()
	documents = DocumentSystem.new()
	documents.load_data()
	day_map = DayMapSystem.new()
	day_map.load_data()
	rumors = RUMOR_SYSTEM_SCRIPT.new()
	rumors.load_data()
	appetite = APPETITE_SYSTEM_SCRIPT.new()
	appetite.load_data()
	inference = INFERENCE_SYSTEM_SCRIPT.new()
	inference.load_data()
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
		if _tavern_view != null and is_instance_valid(_tavern_view):
			return _tavern_view.get_daily_menu_items()
		return _get_fallback_menu()
	)
	guests.guest_arrived.connect(_on_guest_arrived)
	guests.guest_left.connect(_on_guest_left)
	guests.patience_low.connect(_on_patience_low)
	guests.normal_orders_completed.connect(_on_normal_orders_completed)
	guests.guest_abandoned.connect(_on_guest_abandoned)
	guests.all_guests_served.connect(_on_all_guests_served)

	economy.changed.connect(_refresh_tavern_ui.unbind(3))
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
		var menu_open = _tavern_view.is_menu_open() or _tavern_view.is_menu_config_open()
		var in_prep = _tavern_view.is_preparation_phase() or not _tavern_view.daily_menu_confirmed
		if not in_prep and not _is_dialogue_active and not tutorial_active and not _guest_lingering:
			guests.update(delta, guests.has_guest, menu_open)
		if guests.has_guest:
			_tavern_view.update_timer(_guest_patience_ratio(guests.current_guest))


func _guest_patience_ratio(guest: GuestData) -> float:
	if guest == null:
		return 0.0
	var max_patience := GuestData.BASE_PATIENCE
	if guest.type == GuestData.GuestType.IMPORTANT:
		max_patience = GuestData.BASE_PATIENCE * 1.5
	return clampf(guest.patience / max_patience, 0.0, 1.0)


func _today_important_guest_request() -> Dictionary:
	var day := economy.current_day
	var npc_id := narrative.select_today_important_npc(day)
	if npc_id != "":
		return {
			"npc_id": npc_id,
			"order_key": _scene_order_for_npc(npc_id, day),
		}

	var fate_reveal := _today_fate_reveal_event(day)
	if fate_reveal.is_empty():
		return {}
	npc_id = String(fate_reveal.get("npc_id", ""))
	var order_key := String(fate_reveal.get("order", ""))
	if npc_id == "" or order_key == "":
		return {}
	narrative.today_important_npc = npc_id
	return {
		"npc_id": npc_id,
		"order_key": order_key,
	}


func _scene_order_for_npc(npc_id: String, day: int) -> String:
	for npc in narrative.all_npcs:
		if npc.id != npc_id:
			continue
		for scene in npc.scenes:
			if scene.day == day:
				return scene.order
	return "bread"


func _today_fate_reveal_event(day: int) -> Dictionary:
	if ryan_slice == null:
		return {}
	for raw_event in ryan_slice.night_events(day):
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		if String(event.get("type", "")) == "fate_reveal":
			return event
	return {}


func _should_defer_important_guest_for_tutorial(tm: Node) -> bool:
	if tm == null:
		return false
	if bool(tm.tavern_first_entered):
		return false
	if tm.has_method("is_group_completed") and tm.is_group_completed("craft"):
		return false
	return true


func _should_start_menu_prep_tutorial(tm: Node) -> bool:
	if tm == null:
		return false
	if bool(tm.first_menu_prep_shown):
		return false
	if tm.has_method("is_group_completed") and tm.is_group_completed("menu_prep"):
		return false
	return true


func register_view(view: Node) -> void:
	if view is TavernView:
		_tavern_view = view
		_guest_lingering = false
		# 每日账本头（进入夜间营业时记录）
		_ledger_day_header()
		guests.configure_night(ryan_slice.normal_order_limit(economy.current_day), economy.current_day, _combined_guest_bias_for_night())
		_tavern_view.configure_slice_day(economy.current_day)
		var today_rumors := get_today_rumors()
		if _tavern_view.has_method("configure_menu_preparation"):
			_tavern_view.configure_menu_preparation(today_rumors, get_menu_preparation_echoes())
		_refresh_tavern_ui()
		_refresh_close_button()

		# 教程：首次进入酒馆，先检查是否需要触发教程
		var tm = _tutorial_manager
		var first_tavern_entry = tm != null and not tm.tavern_first_entered
		var tutorial_will_start = _should_defer_important_guest_for_tutorial(tm)
		var menu_prep_tutorial_will_start = _should_start_menu_prep_tutorial(tm)

		if first_tavern_entry:
			tm.tavern_first_entered = true
			tm._save_state()
		if tutorial_will_start:
			_craft_tutorial_pending_after_menu = true
		if menu_prep_tutorial_will_start:
			tm.first_menu_prep_shown = true
			tm._save_state()

		var important_guest_request := _today_important_guest_request()
		_important_npc_pending = false

		if not important_guest_request.is_empty():
			_important_npc_pending = true
			var npc_id := String(important_guest_request.get("npc_id", ""))
			var order_key := String(important_guest_request.get("order_key", "bread"))

			if not tutorial_will_start and _tavern_view.daily_menu_confirmed and not guests.has_guest:
				guests.spawn_important(npc_id, order_key)
			# 菜单未确认时等待 on_menu_confirmed() 生成

		if menu_prep_tutorial_will_start:
			view.call_deferred("trigger_menu_prep_tutorial")
		elif tutorial_will_start and _tavern_view.daily_menu_confirmed:
			view.call_deferred("trigger_craft_tutorial")

		_refresh_close_button()
		_show_pending_inference_ready_notice()

	elif view is DayMapView:
		_day_map_view = view
		start_day_map(economy.current_day)
		if _day_start_snapshot_day() != economy.current_day:
			capture_day_start_snapshot()
		save_sys.write(_capture_save_state())
		_day_map_view.show_day(economy.current_day, ryan_slice.last_day())

	elif view is EndingScreen:
		_ending_screen = view
		_ending_screen.show_endings(economy.gold, economy.reputation,
			ryan_slice.total_orders_success, narrative.endings)

func start_day_map(day: int) -> void:
	day_map.start_day(day)
	if rumors != null:
		rumors.start_day(day)
	day_map.set_document_read("bloodied_contract", documents.is_read("bloodied_contract"))
	day_map.set_lead_flag("ryan_warhammer_lead", bool(narrative.get_var("ryan_warhammer_lead")))
	day_map.set_lead_flag("toby_name_lead", narrative.get_var("toby_name_seen") == true)
	day_map.set_lead_flag("toby_identity_known", narrative.get_var("toby_identity_known") == true)
	day_map.set_lead_flag("toby_commission_lead",
		narrative.get_var("toby_commission_lead") == true or narrative.get_var("toby_danger_known") == true)
	day_map.set_document_owned("toby_contract", documents.owns_document("toby_contract"))
	if documents.owns_document("toby_contract"):
		narrative.set_var("toby_contract_found", true)
	_sync_day_map_completion_from_story_state()
	_ensure_fate_tracks_for_day(day)
	_migrate_missing_day_map_state()


func persist_day_map_state() -> void:
	if save_sys != null:
		save_sys.write(_capture_save_state())


func _sync_day_map_completion_from_story_state() -> void:
	if day_map == null or documents == null:
		return
	if day_map.has_method("mark_completed_by_document"):
		for document_id in documents.get_owned_documents():
			day_map.call("mark_completed_by_document", String(document_id))
	if narrative != null and bool(narrative.get_var("toby_secured_by_fixer")) and day_map.has_method("mark_completed"):
		day_map.call("mark_completed", "fixer_den")


func _migrate_missing_day_map_state() -> void:
	if not _day_map_state_missing_from_save:
		return
	_day_map_state_missing_from_save = false
	var tm = _tutorial_manager
	if tm == null:
		tm = get_node_or_null("/root/TutorialManager")
	if tm == null or not tm.daymap_first_shown:
		return
	for loc in day_map.get_locations():
		day_map.mark_revealed(String(loc.get("id", "")))


## Mira 线随日推进的账本预记（与 ryan_slice 的预记并行）。
func _mira_day_start_ledger_entries(day: int) -> Array:
	if day == 6:
		return ["托比，黑齿矿脉护送委托，未归。"]
	if day == 13:
		return ["伊芙琳，灰账清算，第二十日封存。"]
	return []


func _ensure_fate_tracks_for_day(day: int) -> void:
	var added := false
	if day == 2:
		added = documents.start_fate_track("ryan", "莱恩", "第三日。北矿道。未归。") or added
	if day == 6:
		added = documents.start_fate_track("toby", "托比", "第十二日。黑齿矿脉护送委托。未归。") or added
		added = documents.start_fate_track("mira", "米拉", "第十二日。长期供应协议。签署。") or added
	if day == 13:
		added = documents.start_fate_track("evelyn", "伊芙琳", "第二十日。灰账清算。封存。") or added
	if added:
		play_audio_event("new_document")


func _has_next_day_fate_ledger_warning() -> bool:
	var next_day := economy.current_day + 1
	return not ryan_slice.day_start_ledger_entries(next_day).is_empty() \
		or not _mira_day_start_ledger_entries(next_day).is_empty()


func _add_mira_stall_ledger_beat() -> void:
	var entry := ""
	if bool(narrative.get_var("toby_contract_found")):
		if narrative.get_affection("mira") >= narrative.MIRA_TRUST_THRESHOLD:
			entry = "米拉已经听得懂黑齿矿脉意味着什么。"
		else:
			entry = "米拉听见黑齿矿脉时停了一下。"
	else:
		entry = "米拉收摊时停了停，像是在等一个不被问出口的问题。"
	if entry != "" and documents.add_fate_note("mira", entry):
		play_audio_event("new_document")


func _prepare_mira_stall_encounter() -> String:
	var state := _select_mira_stall_encounter_state()
	narrative.set_var("mira_stall_encounter_state", state)
	return _mira_stall_encounter_message(state)


func _grant_mira_responsibility_stall_bonus_if_ready() -> void:
	if narrative.get_var("mira_responsibility_lead") != true:
		return
	if bool(narrative.get_var(MIRA_RESPONSIBILITY_STALL_BONUS_SEEN_VAR)):
		return
	narrative.set_var(MIRA_RESPONSIBILITY_STALL_BONUS_SEEN_VAR, true)
	narrative.set_affection("mira", narrative.get_affection("mira") + MIRA_RESPONSIBILITY_STALL_BONUS)


func _select_mira_stall_encounter_state() -> String:
	if bool(narrative.get_var("told_mira_truth")):
		var trusts_player := narrative.get_affection("mira") >= narrative.MIRA_TRUST_THRESHOLD
		if not bool(narrative.get_var("mira_contract_aftershock_seen")):
			narrative.set_var("mira_contract_aftershock_seen", true)
			var entry := "米拉开始打听托比的落脚处。" if trusts_player else "米拉把酒馆里的那张委托书记在心里，却仍不肯回头。"
			if documents.add_fate_note("mira", entry):
				play_audio_event("new_document")
		return "after_truth_trusted" if trusts_player else "after_truth_guarded"
	if narrative.get_var("mira_responsibility_lead") == true:
		return "responsibility"
	if narrative.get_var("mira_toby_link_known") == true:
		return "old_relation"
	if inference != null:
		if inference.has_clue("one_person_walk") or inference.has_clue("child_learned_saying"):
			_grant_mira_old_road_stall_clue("米拉听见“一个人走”时避开了那条旧路。")
			return "phrase"
		if inference.has_clue("mira_traveling_mentor"):
			_grant_mira_old_road_stall_clue("米拉避开了带孩子跑货的旧事。")
			return "mentor"
	return "surface"


func _grant_mira_old_road_stall_clue(note: String) -> void:
	if inference == null:
		return
	var previous_questions := _available_inference_question_ids()
	if inference.add_clue("mira_avoids_old_road"):
		if documents.add_fate_note("mira", note):
			play_audio_event("new_document")
		_maybe_show_inference_ready_notice(previous_questions)


func _mira_stall_encounter_message(state: String) -> String:
	match state:
		"after_truth_trusted":
			return "米拉把一卷货布扎紧。她没有再绕开托比那份委托。\n米拉: 托比那份黑齿委托，我没忘。\n米拉: 托比现在住哪儿？别误会。我只是……不能让他一个人进黑齿矿脉。"
		"after_truth_guarded":
			return "货摊前的灯芯短了一截。米拉把一枚骨扣翻到背面。\n米拉: 托比那份黑齿委托，别在摊前再提。\n米拉: 他的名字也别喊。黑齿矿脉是什么地方，我知道，不用你讲。\n米拉: 有些路，回头也是死路。我知道你想问什么，今天别问。"
		"responsibility":
			return "米拉把货箱合上，没再装作听不懂。\n米拉: 你想说托比，对吧？\n米拉: 那句话是我教坏他的。一个人走，才轻快。"
		"old_relation":
			return "米拉听见你的脚步，手指停在账绳上。\n米拉: 我以前确实带过一个孩子跑货。\n米拉: 但路上没人能一直替别人背包。"
		"phrase":
			return "米拉正要收起空瓶，听见远处有人念起那句旧话时停了一下。\n米拉: 旧路上的话，别拿到今天问。\n米拉: 谁学去了，谁就拿去活命。别问是谁教的。"
		"mentor":
			return "米拉把货箱盖上，像合上一页旧账。\n米拉: 带过孩子跑货的人很多。\n米拉: 别在摊前替旧路算账。"
		_:
			return "米拉把货布一角压平，像是在抹掉某个折痕。\n米拉: 不买就别挡光。小东西也要看准了才值钱。"


func _collect_toby_board_clues() -> void:
	narrative.set_var("toby_name_seen", true)
	narrative.set_var("toby_name_lead", true)
	var previous_questions := _available_inference_question_ids()
	if inference != null:
		inference.add_clues(["toby_name", "blacktooth_escort", "high_pay_trap"])
		_maybe_show_inference_ready_notice(previous_questions)
	if documents.add_fate_note("toby", "告示板出现黑齿矿脉护送委托，落款是托比。"):
		play_audio_event("new_document")


func _collect_toby_day6_night_clues() -> bool:
	if economy.current_day != 6:
		return false
	if inference == null:
		return false
	var previous_questions := _available_inference_question_ids()
	var changed: bool = inference.add_clues(["back_alley_boy", "one_person_walk"])
	if changed and documents.add_fate_note("toby", "夜里买草药清汤的后巷少年，也说起了黑齿矿脉。"):
		play_audio_event("new_document")
	if changed:
		_maybe_show_inference_ready_notice(previous_questions)
	return changed


func _collect_toby_day6_night_clues_for_test() -> bool:
	return _collect_toby_day6_night_clues()


func _grant_mira_old_ledger_gossip_for_test() -> Dictionary:
	return _try_grant_mira_old_ledger_gossip()


func _try_grant_mira_old_ledger_gossip() -> Dictionary:
	if inference == null:
		return {"granted": false, "clue_id": "", "line": ""}
	if economy.current_day < 7 or economy.current_day > 11:
		return {"granted": false, "clue_id": "", "line": ""}
	var raw_granted_day = narrative.get_var(MIRA_OLD_LEDGER_GOSSIP_GRANTED_DAY_VAR)
	var granted_day := int(raw_granted_day) if raw_granted_day != null else -1
	if granted_day == economy.current_day:
		return {"granted": false, "clue_id": "", "line": ""}
	if not _mira_old_ledger_route_active():
		return {"granted": false, "clue_id": "", "line": ""}

	var candidate := _next_mira_old_ledger_gossip()
	if candidate.is_empty():
		return {"granted": false, "clue_id": "", "line": ""}
	var clue_id := String(candidate.get("clue_id", ""))
	var previous_questions := _available_inference_question_ids()
	if not inference.add_clue(clue_id):
		return {"granted": false, "clue_id": "", "line": ""}
	narrative.set_var(MIRA_OLD_LEDGER_GOSSIP_GRANTED_DAY_VAR, economy.current_day)
	if documents.add_fate_note("mira", String(candidate.get("note", ""))):
		play_audio_event("new_document")
	_maybe_show_inference_ready_notice(previous_questions)
	return {
		"granted": true,
		"clue_id": clue_id,
		"line": String(candidate.get("line", "")),
	}


func _inference_clue_label(clue_id: String) -> String:
	if inference == null:
		return clue_id
	var clue: Dictionary = inference.get_clue(clue_id)
	return String(clue.get("label", clue_id))


func _mira_old_ledger_route_active() -> bool:
	return bool(narrative.get_var("toby_name_seen")) \
		or bool(narrative.get_var("toby_identity_known")) \
		or bool(narrative.get_var("toby_commission_lead")) \
		or inference.has_clue("one_person_walk")


func _next_mira_old_ledger_gossip() -> Dictionary:
	if not inference.has_clue("mira_traveling_mentor"):
		return {
			"clue_id": "mira_traveling_mentor",
			"line": "客人: 以前有个女商人，总带着个[color=#d6a84d]半大孩子跑货[/color]。",
			"note": "今晚有人提起带孩子跑货的女商人。",
		}
	if inference.has_clue("one_person_walk") and not inference.has_clue("child_learned_saying"):
		return {
			"clue_id": "child_learned_saying",
			"line": "客人: 那孩子[color=#d6a84d]学她说话[/color]，老念叨[color=#d6a84d]一个人走才轻快[/color]。",
			"note": "今晚有人说，那孩子是从别人那里学会“一个人走”的。",
		}
	return {}


func _available_inference_question_ids() -> Array[String]:
	var result: Array[String] = []
	if inference == null:
		return result
	for question in inference.get_available_questions():
		var question_id := String(question.get("id", ""))
		if question_id != "":
			result.append(question_id)
	return result


func _maybe_show_inference_ready_notice(previous_question_ids: Array[String]) -> void:
	var newly_available: Array[String] = []
	for question_id in _available_inference_question_ids():
		if previous_question_ids.has(question_id):
			continue
		if bool(_announced_inference_question_ids.get(question_id, false)):
			continue
		newly_available.append(question_id)
	if newly_available.is_empty():
		return
	if not _show_inference_ready_notice():
		return
	for question_id in newly_available:
		_announced_inference_question_ids[question_id] = true


func _show_pending_inference_ready_notice() -> void:
	_maybe_show_inference_ready_notice([])


func _show_inference_ready_notice() -> bool:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return false
	if not _tavern_view.has_method("show_inference_ready_notice"):
		return false
	_tavern_view.call("show_inference_ready_notice")
	return true


func apply_inference_result(result: Dictionary) -> bool:
	if not bool(result.get("solved", false)):
		return false
	var previous_questions := _available_inference_question_ids()
	var changed := false
	for flag in result.get("unlockFlags", []):
		match String(flag):
			"toby_identity_known":
				if not bool(narrative.get_var("toby_identity_known")):
					narrative.set_var("toby_identity_known", true)
					day_map.set_lead_flag("toby_identity_known", true)
					changed = true
					if documents.add_fate_note("toby", "夜里的后巷少年，就是告示上的托比。"):
						play_audio_event("new_document")
			"toby_commission_lead":
				if not bool(narrative.get_var("toby_commission_lead")):
					narrative.set_var("toby_commission_lead", true)
					day_map.set_lead_flag("toby_commission_lead", true)
					changed = true
				if not bool(narrative.get_var("toby_danger_known")):
					narrative.set_var("toby_danger_known", true)
					changed = true
					if documents.add_fate_note("toby", "黑齿矿脉护送的报酬高得像陷阱，得找人截住这趟路。"):
						play_audio_event("new_document")
			"mira_toby_link_known":
				if narrative.get_var("mira_toby_link_known") != true:
					narrative.set_var("mira_toby_link_known", true)
					changed = true
					if documents.add_fate_note("mira", "托比和米拉的旧路被重新对上。"):
						play_audio_event("new_document")
			"mira_responsibility_lead":
				if narrative.get_var("mira_responsibility_lead") != true:
					narrative.set_var("mira_responsibility_lead", true)
					changed = true
					if documents.add_fate_note("mira", "托比那句“一个人走”，来自米拉留下的旧办法。"):
						play_audio_event("new_document")
			"grey_same_batch_known":
				if narrative.get_var("grey_same_batch_known") != true:
					narrative.set_var("grey_same_batch_known", true)
					changed = true
					if documents.add_fate_note("evelyn", "莱恩案卷和托比的黑齿批次被对进同一批灰账。"):
						play_audio_event("new_document")
			"grey_payout_method_known":
				if narrative.get_var("grey_payout_method_known") != true:
					narrative.set_var("grey_payout_method_known", true)
					changed = true
					if documents.add_fate_note("evelyn", "灰账先决定赔付，再把事故补成已结案。"):
						play_audio_event("new_document")
			"mira_grey_ledger_link_known":
				if narrative.get_var("mira_grey_ledger_link_known") != true:
					narrative.set_var("mira_grey_ledger_link_known", true)
					changed = true
					if documents.add_fate_note("evelyn", "米拉的供应协议背面盖着同一枚灰契印，协议也接进灰账。"):
						play_audio_event("new_document")
			"grey_public_account_known":
				if narrative.get_var("grey_public_account_known") != true:
					narrative.set_var("grey_public_account_known", true)
					changed = true
					if documents.add_fate_note("evelyn", "莱恩、托比和米拉能被抄成同一份公开灰账。"):
						play_audio_event("new_document")
	if changed:
		if economy != null and economy.current_day == EVELYN_FINAL_DAY:
			_refresh_evelyn_public_gap_vars()
		_maybe_show_inference_ready_notice(previous_questions)
	return changed


func get_evelyn_public_account_gap_labels() -> Array[String]:
	var labels: Array[String] = []
	for gap in _evelyn_public_account_gaps():
		labels.append(String(gap.get("label", "")))
	return labels


func get_evelyn_public_account_gap_summary(max_items: int = 3) -> String:
	var gaps := _evelyn_public_account_gaps()
	if gaps.is_empty():
		return ""
	var labels := PackedStringArray()
	var limit: int = mini(max_items, gaps.size())
	for i in range(limit):
		labels.append(String(gaps[i].get("label", "")))
	var suffix := " 等" if gaps.size() > limit else ""
	return "公开账本缺：" + " / ".join(labels) + suffix


func _evelyn_public_account_gaps() -> Array[Dictionary]:
	var gaps: Array[Dictionary] = []
	if narrative == null or narrative.get_var("grey_public_account_known") == true:
		return gaps
	for spec in EVELYN_PUBLIC_ACCOUNT_GAPS:
		var gap: Dictionary = spec
		var flag := String(gap.get("flag", ""))
		if flag != "" and narrative.get_var(flag) != true:
			gaps.append(gap)
	if gaps.is_empty():
		gaps.append(EVELYN_PUBLIC_ACCOUNT_FINAL_GAP)
	return gaps


func _refresh_evelyn_public_gap_vars() -> void:
	if narrative == null:
		return
	var gaps := _evelyn_public_account_gaps()
	narrative.set_var("evelyn_public_gap_primary", "" if gaps.is_empty() else String(gaps[0].get("id", "")))
	narrative.set_var("evelyn_public_gap_summary", get_evelyn_public_account_gap_summary())


func _clear_evelyn_public_gap_vars() -> void:
	if narrative == null:
		return
	narrative.set_var("evelyn_public_gap_primary", "")
	narrative.set_var("evelyn_public_gap_summary", "")


func visit_day_location(location_id: String) -> Dictionary:
	day_map.set_document_read("bloodied_contract", documents.is_read("bloodied_contract"))
	var location_before := _find_day_map_location(location_id)
	var gold_cost := int(location_before.get("goldCost", _day_location_gold_cost(location_id)))
	if gold_cost > 0 and economy.gold < gold_cost:
		return {
			"success": false,
			"message": "掮客开价 %d 金，钱不够就不会动手。" % gold_cost,
			"stamina": day_map.stamina,
			"blocked_reason": "not_enough_gold",
			"goldCost": gold_cost,
		}
	var result := day_map.visit(location_id)
	if not bool(result.get("success", false)):
		return result
	var unlocked_flag := String(result.get("unlockedFlag", ""))
	if unlocked_flag == "toby_name_lead":
		_collect_toby_board_clues()
	elif unlocked_flag == "toby_commission_lead":
		narrative.set_var("toby_commission_lead", true)
		narrative.set_var("toby_danger_known", true)
		if documents.add_fate_note("toby", "告示板出现黑齿矿脉护送委托，落款是托比。"):
			play_audio_event("new_document")
	for key in result.get("rewards", []):
		add_to_inventory(String(key), 1)
	for document_id in result.get("documents", []):
		grant_investigation_document(String(document_id))
	var aff = result.get("affection", null)
	if aff is Dictionary and String(aff.get("npc", "")) != "":
		var npc_id := String(aff["npc"])
		narrative.set_affection(npc_id, narrative.get_affection(npc_id) + int(aff.get("amount", 0)))
	if location_id == "mira_stall":
		result["message"] = _prepare_mira_stall_encounter()
		_grant_mira_responsibility_stall_bonus_if_ready()
		_add_mira_stall_ledger_beat()
	if bool(result.get("securesToby", false)):
		var cost := int(result.get("goldCost", 0))
		if economy.gold >= cost:
			economy.add_gold(-cost)
			narrative.set_var("toby_secured", true)
			narrative.set_var("toby_secured_by_fixer", true)
			if documents.add_fate_note("toby", "掮客换掉了那条路。"):
				play_audio_event("new_document")
			_ledger_gold(-cost, "矿洞押金")
		else:
			result["blocked_reason"] = "not_enough_gold"
			narrative.set_var("toby_secured", false)
	if bool(location_before.get("completeOnVisit", false)) and day_map.has_method("mark_completed"):
		day_map.call("mark_completed", location_id)
	if rumors != null:
		var rumor_day := economy.current_day
		if day_map != null:
			rumor_day = int(day_map.current_day)
		var rumor: Dictionary = rumors.grant_location_rumor(location_id, rumor_day, _rumor_context_flags())
		if bool(rumor.get("success", false)):
			result["rumor"] = rumor
			var rumor_text := String(rumor.get("text", ""))
			if rumor_text != "":
				var base_message := String(result.get("message", "访问完成。"))
				result["message"] = base_message + "\n\n听到传闻：" + rumor_text
	# 聚合 rewards 数组为 {item_key: count} 字典，供 UI Toast 展示
	var reward_counts_toast: Dictionary = {}
	for key in result.get("rewards", []):
		var k := String(key)
		reward_counts_toast[k] = int(reward_counts_toast.get(k, 0)) + 1
	result["reward_counts"] = reward_counts_toast
	add_current_day_event({
		"type": "location",
		"label": String(location_before.get("name", location_id)),
		"detail": _day_location_event_detail(result),
		"location_id": location_id,
	})
	return result


func get_today_rumors() -> Array[Dictionary]:
	if rumors == null:
		return []
	var result: Array[Dictionary] = []
	for rumor in rumors.get_today_rumors():
		if rumor is Dictionary:
			result.append(_enrich_rumor_for_display(rumor))
	return result


func _enrich_rumor_for_display(rumor: Dictionary) -> Dictionary:
	var payload := rumor.duplicate(true)
	var affected_ids := _string_array_from_values(payload.get("affectedCustomerIds", []))
	var affected_customers: Array[Dictionary] = []
	for customer_id in affected_ids:
		var preview := _regular_customer_preview(customer_id)
		if not preview.is_empty():
			affected_customers.append(preview)
	payload["affectedCustomers"] = affected_customers
	return payload


func _regular_customer_preview(customer_id: String) -> Dictionary:
	if customer_id == "":
		return {}
	if guests != null and guests.has_method("get_regular_customer_preview"):
		var preview: Dictionary = guests.get_regular_customer_preview(customer_id)
		if not preview.is_empty():
			return preview
	return {
		"id": customer_id,
		"name": customer_id,
		"role": "",
		"favorite_orders": [],
	}


func get_menu_preparation_echoes(limit: int = 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _sorted_keys_as_strings(_word_of_mouth):
		var bias_key := String(key)
		if bias_key.begins_with("regular_"):
			continue
		var title := _word_of_mouth_echo_title(bias_key)
		if title == "":
			continue
		result.append({
			"type": "word_of_mouth",
			"title": title,
			"detail": _word_of_mouth_echo_detail(bias_key),
			"score": int(_word_of_mouth.get(bias_key, 0)),
		})
		if limit > 0 and result.size() >= limit:
			return result
	if guests != null and guests.has_method("get_customer_memory_summaries"):
		for summary in guests.get_customer_memory_summaries(limit):
			var notes := _string_array_from_values(summary.get("notes", []))
			if notes.is_empty():
				continue
			var trait_info: Dictionary = summary.get("trait", {})
			var detail := String(notes.back())
			if not trait_info.is_empty():
				detail += "\n特质：" + String(trait_info.get("name", ""))
				var menu_hint := String(trait_info.get("menuHint", ""))
				if menu_hint != "":
					detail += " · " + menu_hint
			result.append({
				"type": "customer_memory",
				"title": notes.back(),
				"detail": detail,
				"tags": _string_array_from_values(summary.get("remembered_tags", [])),
			})
			if limit > 0 and result.size() >= limit:
				return result
	return result


func get_menu_product_recommendation(product_key: String) -> Dictionary:
	var tags := _menu_product_tags(product_key)
	var chips: Array[String] = []
	var reasons: Array[String] = []
	_append_customer_memory_menu_recommendations(product_key, tags, chips, reasons)
	_append_rumor_menu_recommendations(tags, chips, reasons)
	_append_word_of_mouth_menu_recommendations(tags, chips, reasons)
	return {
		"product_key": product_key,
		"tags": tags,
		"chips": chips,
		"reasons": reasons,
	}


func _append_customer_memory_menu_recommendations(product_key: String, product_tags: Array[String], chips: Array[String], reasons: Array[String]) -> void:
	if guests == null or not guests.has_method("get_customer_memory_summaries"):
		return
	for summary in guests.get_customer_memory_summaries(8):
		if not summary is Dictionary:
			continue
		var customer: Dictionary = summary
		var customer_name := String(customer.get("customer_name", ""))
		if customer_name == "":
			continue
		var remembered_orders := _string_array_from_values(customer.get("remembered_orders", []))
		var remembered_tags := _string_array_from_values(customer.get("remembered_tags", []))
		var matched_tags := _shared_strings(product_tags, remembered_tags)
		if remembered_orders.has(product_key) or not matched_tags.is_empty():
			_append_unique_string(chips, "★" + customer_name, 2)
			var product_name := _menu_product_display_name(product_key)
			if remembered_orders.has(product_key):
				_append_unique_string(reasons, "%s记得这道菜：%s" % [customer_name, product_name], 3)
			else:
				_append_unique_string(reasons, "%s记得这些味道：%s" % [customer_name, " / ".join(matched_tags)], 3)
		var trait_info: Dictionary = customer.get("trait", {})
		var trait_tags := _string_array_from_values(trait_info.get("focusTags", []))
		var trait_matches := _shared_strings(product_tags, trait_tags)
		if not trait_matches.is_empty():
			_append_unique_string(chips, "★" + customer_name, 2)
			var trait_name := String(trait_info.get("name", ""))
			if trait_name != "":
				_append_unique_string(reasons, "%s特质命中：%s" % [customer_name, trait_name], 3)


func _append_rumor_menu_recommendations(product_tags: Array[String], chips: Array[String], reasons: Array[String]) -> void:
	for rumor in get_today_rumors():
		var menu_hints: Dictionary = rumor.get("menuHints", {})
		var recommended_tags := _string_array_from_values(menu_hints.get("recommendedTags", []))
		var matched_tags := _shared_strings(product_tags, recommended_tags)
		if matched_tags.is_empty():
			continue
		var group_label := _rumor_group_recommendation_label(rumor)
		if group_label != "":
			_append_unique_string(chips, "★" + group_label, 2)
		var summary := String(menu_hints.get("summary", ""))
		if summary == "":
			summary = String(rumor.get("text", ""))
		if summary != "":
			_append_unique_string(reasons, "命中传闻：%s" % summary, 3)


func _append_word_of_mouth_menu_recommendations(product_tags: Array[String], chips: Array[String], reasons: Array[String]) -> void:
	for key in _sorted_keys_as_strings(_word_of_mouth):
		var bias_key := String(key)
		if bias_key.begins_with("regular_") or int(_word_of_mouth.get(bias_key, 0)) <= 0:
			continue
		var matched_tags := _shared_strings(product_tags, _word_of_mouth_recommendation_tags(bias_key))
		if matched_tags.is_empty():
			continue
		var group_label := _menu_recommendation_group_label(bias_key)
		if group_label != "":
			_append_unique_string(chips, "★" + group_label, 2)
		var title := _word_of_mouth_echo_title(bias_key)
		var detail := _word_of_mouth_echo_detail(bias_key)
		if title != "":
			_append_unique_string(reasons, "%s：%s" % [title, detail], 3)


func _menu_product_tags(product_key: String) -> Array[String]:
	if appetite == null or not appetite.has_method("get_product_tags"):
		return []
	return _string_array_from_values(appetite.get_product_tags(product_key))


func _menu_product_display_name(product_key: String) -> String:
	if craft != null and craft.has_method("get_item"):
		var item: Dictionary = craft.get_item(product_key)
		return String(item.get("name", product_key))
	return product_key


func _rumor_group_recommendation_label(rumor: Dictionary) -> String:
	var effects: Dictionary = rumor.get("effects", {})
	var guest_bias: Dictionary = effects.get("guestBias", {})
	for key in _sorted_keys_as_strings(guest_bias):
		var bias_key := String(key)
		if bias_key.begins_with("regular_"):
			continue
		var label := _menu_recommendation_group_label(bias_key)
		if label != "":
			return label
	var affected_customers: Array = rumor.get("affectedCustomers", [])
	if not affected_customers.is_empty() and affected_customers[0] is Dictionary:
		return String((affected_customers[0] as Dictionary).get("name", ""))
	return ""


func _menu_recommendation_group_label(key: String) -> String:
	match key:
		"mine":
			return "矿口"
		"ledger":
			return "账房"
		"trade":
			return "商路"
		"herbal":
			return "草药客"
		"old_road":
			return "旧路"
	return ""


func _word_of_mouth_recommendation_tags(key: String) -> Array[String]:
	match key:
		"mine":
			return ["顶饿", "热食", "力量"]
		"ledger":
			return ["体面", "精致", "清香"]
		"trade":
			return ["酒水", "体面", "精致"]
		"herbal":
			return ["清香", "秘香", "轻快"]
		"old_road":
			return ["清香", "热食", "顶饿"]
	return []


func _shared_strings(left: Array[String], right: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in left:
		if right.has(value) and not result.has(value):
			result.append(value)
	return result


func _append_unique_string(values: Array[String], text: String, limit: int = 0) -> void:
	var clean := text.strip_edges()
	if clean == "" or values.has(clean):
		return
	if limit > 0 and values.size() >= limit:
		return
	values.append(clean)


func _combined_guest_bias_for_night() -> Dictionary:
	var result: Dictionary = {}
	if rumors != null:
		result = rumors.get_guest_bias()
	for key in _word_of_mouth.keys():
		var bias_key := String(key)
		var current := float(result.get(bias_key, 1.0))
		result[bias_key] = current * _word_of_mouth_multiplier(bias_key)
	return result


func _record_customer_memory_from_appetite(npc_id: String, item_key: String, item_name: String, appetite_result: Dictionary) -> Dictionary:
	if npc_id == "" or item_key == "" or not npc_id.begins_with("regular_"):
		return {}
	var tier := String(appetite_result.get("tier", ""))
	if tier != "delighted" and tier != "satisfied":
		return {}
	var matched_tags := _string_array_from_values(appetite_result.get("matched_tags", []))
	if matched_tags.is_empty() or guests == null or not guests.has_method("record_customer_memory"):
		return {}
	var matched_rumor := _matching_rumor_for_customer(npc_id)
	if matched_rumor.is_empty():
		return {}
	var memory: Dictionary = guests.record_customer_memory(npc_id, item_key, item_name, matched_tags, economy.current_day, "传闻应验")
	if memory.is_empty():
		return {}
	var word_labels := _apply_word_of_mouth_from_rumor(matched_rumor)
	memory["word_of_mouth_labels"] = word_labels
	return memory


func _matching_rumor_for_customer(customer_id: String) -> Dictionary:
	for rumor in get_today_rumors():
		var affected_ids := _string_array_from_values(rumor.get("affectedCustomerIds", []))
		if affected_ids.has(customer_id):
			return rumor
	return {}


func _apply_word_of_mouth_from_rumor(rumor: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	var effects: Dictionary = rumor.get("effects", {})
	var guest_bias: Dictionary = effects.get("guestBias", {})
	for key in guest_bias.keys():
		var bias_key := String(key)
		if bias_key == "":
			continue
		_word_of_mouth[bias_key] = mini(int(_word_of_mouth.get(bias_key, 0)) + 1, 5)
		var label := _word_of_mouth_label(bias_key)
		if label != "" and not labels.has(label):
			labels.append(label)
	return labels


func _word_of_mouth_multiplier(key: String) -> float:
	return 1.0 + minf(float(_word_of_mouth.get(key, 0)), 5.0) * 0.08


func _word_of_mouth_label(key: String) -> String:
	match key:
		"mine":
			return "矿口口碑 +1"
		"ledger":
			return "账房口碑 +1"
		"trade":
			return "商路口碑 +1"
		"herbal":
			return "草药口碑 +1"
		"old_road":
			return "旧路口碑 +1"
	return ""


func _word_of_mouth_echo_title(key: String) -> String:
	match key:
		"mine":
			return "矿口口碑升温"
		"ledger":
			return "账房口碑升温"
		"trade":
			return "商路口碑升温"
		"herbal":
			return "草药口碑升温"
		"old_road":
			return "旧路口碑升温"
	return ""


func _word_of_mouth_echo_detail(key: String) -> String:
	match key:
		"mine":
			return "矿工、搬运工和退伍兵更可能来。"
		"ledger":
			return "账房学徒、符文学者和体面客人更可能来。"
		"trade":
			return "走货商人和吟游旅客更可能来。"
		"herbal":
			return "巡林人和草药客更可能来。"
		"old_road":
			return "旧路熟人和安静客人更可能来。"
	return ""


func _rumor_context_flags() -> Dictionary:
	var flags := {}
	if narrative == null:
		return flags
	for key in narrative.dialogue_vars.keys():
		var raw_value = narrative.dialogue_vars[key]
		var flag_value := false
		match typeof(raw_value):
			TYPE_BOOL:
				flag_value = raw_value
			TYPE_INT, TYPE_FLOAT:
				flag_value = raw_value != 0
			TYPE_STRING:
				flag_value = String(raw_value) == "true"
		flags[String(key)] = flag_value
	return flags


func _day_location_gold_cost(location_id: String) -> int:
	for loc in day_map.get_locations():
		if String(loc.get("id", "")) == location_id:
			return int(loc.get("goldCost", 0))
	return 0


func peek_shop_gossip(location_id: String) -> Dictionary:
	return _shop_gossip(location_id, false)


func consume_shop_gossip(location_id: String) -> Dictionary:
	return _shop_gossip(location_id, true)


func _shop_gossip(location_id: String, mark_seen: bool) -> Dictionary:
	var location := _find_day_map_location(location_id)
	if location.is_empty():
		return {"success": false, "message": ""}
	for gossip in location.get("gossip", []):
		if not gossip is Dictionary:
			continue
		var entry := gossip as Dictionary
		if not _is_shop_gossip_available(entry):
			continue
		var seen_var := String(entry.get("seenVar", ""))
		if mark_seen and seen_var != "":
			narrative.set_var(seen_var, true)
		return {
			"success": true,
			"id": String(entry.get("id", "")),
			"hint": String(entry.get("hint", "")),
			"message": String(entry.get("message", "")),
		}
	return {"success": false, "message": ""}


func _find_day_map_location(location_id: String) -> Dictionary:
	for loc in day_map.get_locations():
		if String(loc.get("id", "")) == location_id:
			return loc
	return {}


func _is_shop_gossip_available(entry: Dictionary) -> bool:
	var exact_day := int(entry.get("day", 0))
	if exact_day > 0 and day_map.current_day != exact_day:
		return false
	var day_min := int(entry.get("dayMin", 0))
	if day_min > 0 and day_map.current_day < day_min:
		return false
	var day_max := int(entry.get("dayMax", 0))
	if day_max > 0 and day_map.current_day > day_max:
		return false
	var required_var := String(entry.get("requiresVar", ""))
	if required_var != "" and not bool(narrative.get_var(required_var)):
		return false
	var seen_var := String(entry.get("seenVar", ""))
	if seen_var != "" and bool(narrative.get_var(seen_var)):
		return false
	var unless_var := String(entry.get("unlessVar", ""))
	if unless_var != "" and bool(narrative.get_var(unless_var)):
		return false
	var unless_inventory := String(entry.get("unlessInventory", ""))
	if unless_inventory != "" and inventory_sys.get_count(unless_inventory) > 0:
		return false
	return true


func grant_investigation_document(document_id: String) -> bool:
	# 物理调查场景捡起/拼合出线索时的授予入口（中介模式：View 不直接碰 DocumentSystem）。
	# 返回是否「本次新授予」。授予后立即加入故事物品背包。
	var id := String(document_id)
	var already_owned := documents.owns_document(id)
	var newly := documents.grant_document(id) and not already_owned
	if newly:
		play_audio_event("new_document")
		if id == "toby_contract":
			narrative.set_var("toby_contract_found", true)
			if documents.add_fate_note("toby", "委托书已拼回。米拉还不知道。"):
				play_audio_event("new_document")
		var clue_id := _document_inference_clue(id)
		if clue_id != "" and inference != null:
			var previous_questions := _available_inference_question_ids()
			if inference.add_clue(clue_id):
				_add_grey_document_fate_note(id)
				_maybe_show_inference_ready_notice(previous_questions)
		# 文档作为故事物品立即放入背包，无需先阅读（玩家可双击背包中物品打开阅读）
		if inventory_sys.is_story_item(id):
			add_to_inventory(id, 1)
			_ledger_item(id, 1, "剧情获得")
		# 同步到大世界：拥有文档即视为已获取线索，公会柜台等依赖 requiresRead 的地点可解锁
		day_map.set_document_owned(id, true)
	if newly or already_owned:
		day_map.set_document_owned(id, true)
		if day_map.has_method("mark_completed_by_document"):
			day_map.call("mark_completed_by_document", id)
	return newly


func _document_inference_clue(document_id: String) -> String:
	const GREY_DOCUMENT_CLUES := [
		"grey_ryan_case_number",
		"grey_old_payout_register",
		"grey_missing_page",
		"grey_blacktooth_batch",
		"grey_closure_method",
		"grey_payout_closure",
		"grey_renamed_escort",
		"grey_supply_stamp",
	]
	if GREY_DOCUMENT_CLUES.has(document_id):
		return document_id
	return ""


func _add_grey_document_fate_note(document_id: String) -> void:
	var note := ""
	match document_id:
		"grey_ryan_case_number":
			note = "莱恩的案卷编号被抄进灰账批次；他不是单独归档。"
		"grey_old_payout_register":
			note = "旧赔付登记显示，几份委托先决定赔付，再补成已结案。"
		"grey_missing_page":
			note = "失踪名单缺页处压着灰色蜡印，缺走的是能互相对上的名字。"
		"grey_blacktooth_batch":
			note = "托比的黑齿委托被并入 G-17，同莱恩案卷进了同一批清算。"
		"grey_closure_method":
			note = "灰契可以把临时人名、事故赔付和保证金合成一笔已结账。"
		"grey_payout_closure":
			note = "赔付登记处夹出了莱恩案卷先赔付、后结案的顺序。"
		"grey_renamed_escort":
			note = "黑齿转运账把托比的护送委托改进了临时人名栏。"
		"grey_supply_stamp":
			note = "米拉旧供应副本背面有同一枚灰契印，协议也接进灰账。"
	if note == "":
		return
	_ensure_fate_track("evelyn")
	if documents.add_fate_note("evelyn", note):
		play_audio_event("new_document")


func enter_night_from_day_map() -> void:
	if day_cycle.phase == DayCycleSystem.DayPhase.DAY:
		day_cycle.next_phase()


func _on_gathering_confirmed(assignments: Dictionary) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var locations: Array = _load_locations_data()
	var gathered: Dictionary = {}  # 汇总采集结果

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
			gathered[mat] = int(gathered.get(mat, 0)) + 1

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
	if guest == null:
		return
	var display_name = guest.guest_name
	var default_portrait_id: String = guest.npc_id if guest.npc_id != "" else "guest"
	var portrait_id: String = String(guest.get_meta("portrait_id", default_portrait_id))
	if portrait_id == "":
		portrait_id = default_portrait_id
	if guest.has_dialogue:
		for npc in narrative.all_npcs:
			if npc.id == guest.npc_id:
				display_name = npc.npc_name
				break
		display_name = _important_guest_display_name(guest.npc_id, display_name)
		portrait_id = ryan_slice.important_portrait_id(economy.current_day, guest.npc_id, portrait_id)
	guest.set_meta("portrait_id", portrait_id)
	guests.update_current_guest_entry_identity(display_name, portrait_id)

	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	_refresh_close_button()

	var item: Dictionary = craft.get_item(guest.order_key)
	_tavern_view.show_customer(display_name, item.get("name", guest.order_key), portrait_id, guest.order_key)

	var tm = get_node_or_null("/root/TutorialManager")
	_queue_first_guest_serve_tutorial(guest.has_dialogue)

	# 重要 NPC 的对话优先于服务教程
	if guest.has_dialogue:
		var tutorial_active = tm != null and tm._is_active
		if not tutorial_active:
			narrative.today_important_npc = guest.npc_id
			# Day 3 揭晓前按玩家实际行为定格 Ryan 结局，使 ryan_day3 对话能读到 ryan_ending。
			if economy.current_day == 3 and guest.npc_id == "ryan":
				narrative.finalize_ryan_ending()
				_finish_ryan_fate_track()
			var dialogue_path = "res://dialogue/" + guest.npc_id + "_day" + str(economy.current_day) + ".pre.dialogue"
			_dialogue_phase = "pre"
			_tavern_view.set_dialogue_mode(true)
			call_deferred("_start_dialogue_deferred", dialogue_path)


func _queue_first_guest_serve_tutorial(wait_for_dialogue: bool) -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null or tm.first_guest_arrived or tm._is_active:
		return
	tm.first_guest_arrived = true
	tm._save_state()
	if wait_for_dialogue:
		_serve_tutorial_pending_after_dialogue = true
		return
	_serve_tutorial_pending_after_dialogue = false
	call_deferred("_start_first_guest_serve_tutorial_after_delay")


func _start_first_guest_serve_tutorial_after_delay() -> void:
	await get_tree().create_timer(0.5).timeout
	_start_first_guest_serve_tutorial()


func _start_first_guest_serve_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null or tm._is_active:
		return
	var rects := {}
	if _tavern_view != null and is_instance_valid(_tavern_view) and _tavern_view.has_method("get_tutorial_highlight_rects"):
		rects = _tavern_view.get_tutorial_highlight_rects("serve")
	tm.start_tutorial("serve", rects)

## 教程结束后生成重要 NPC（避免教程期间对话冲突）
func _spawn_npc_after_tutorial(group_id: String, npc_id: String, order_key: String) -> void:
	if group_id != "craft":
		return
	# 如果准备阶段还未结束（菜单未确认），推迟到 on_menu_confirmed
	if _tavern_view != null and is_instance_valid(_tavern_view) and not _tavern_view.daily_menu_confirmed:
		return  # on_menu_confirmed 会在菜单确认后生成
	guests.spawn_important(npc_id, order_key)

## 准备阶段结束后延迟生成重要NPC
func _spawn_important_deferred(npc_id: String, order_key: String) -> void:
	await get_tree().create_timer(1.0).timeout
	if _tavern_view != null and _tavern_view.daily_menu_confirmed:
		guests.spawn_important(npc_id, order_key)

## 菜单确认后的回调：触发生成重要NPC（由 TavernView._confirm_menu 调用）
func on_menu_confirmed() -> void:
	if _craft_tutorial_pending_after_menu:
		if _start_deferred_craft_tutorial_after_menu():
			return
	_spawn_pending_important_guest_after_menu()


func _start_deferred_craft_tutorial_after_menu() -> bool:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		_craft_tutorial_pending_after_menu = false
		return false
	if tm.has_method("is_group_completed") and tm.is_group_completed("craft"):
		_craft_tutorial_pending_after_menu = false
		return false
	if tm._is_active:
		return true
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		_craft_tutorial_pending_after_menu = false
		return false
	_craft_tutorial_pending_after_menu = false
	if tm.has_signal("tutorial_sequence_ended") and not tm.tutorial_sequence_ended.is_connected(_on_deferred_craft_tutorial_sequence_ended):
		tm.tutorial_sequence_ended.connect(_on_deferred_craft_tutorial_sequence_ended, CONNECT_ONE_SHOT)
	_tavern_view.call_deferred("trigger_craft_tutorial")
	return true


func _on_deferred_craft_tutorial_sequence_ended(group_id: String) -> void:
	if group_id != "craft":
		return
	_spawn_pending_important_guest_after_menu()


func _spawn_pending_important_guest_after_menu() -> void:
	if _important_npc_pending:
		var important_guest_request := _today_important_guest_request()
		if not important_guest_request.is_empty():
			if guests.has_guest:
				return
			guests.spawn_important(
				String(important_guest_request.get("npc_id", "")),
				String(important_guest_request.get("order_key", "bread"))
			)
		else:
			_important_npc_pending = false

## 当所有客人都招待完毕后提示打烊
func _on_all_guests_served() -> void:
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.show_stage_caption("今日客流招待完毕，可以打烊了！", ThemeColors.AMBER_PRIMARY)

## 当日菜单回退（从已解锁配方获取，用于 guest_system 初始化回调）
func _get_fallback_menu() -> Array:
	var result: Array[Dictionary] = []
	var products: Array = craft.get_orderable_products(economy.current_day)
	for key in products:
		var item: Dictionary = craft.get_item(key)
		result.append({
			"key": key,
			"price": int(item.get("price", 0)),
			"name": item.get("name", key),
		})
	return result

## 公开上菜入口：沙盘 / 未来 BarWorkspace 调用，避免依赖 craft_station 信号。
func request_serve(item_key: String, craft_style_data: Dictionary = {}, seasoning_attribute: String = "") -> void:
	_on_serve_requested(item_key, seasoning_attribute, craft_style_data)

## 上菜判定逻辑（从 register_view lambda 提取）
func _on_serve_requested(item_key: String, seasoning_attribute: String, craft_style_data: Dictionary = {}) -> void:
	if not guests.has_guest or item_key == "" or _guest_lingering:
		return
	if inventory_sys.is_product(item_key) and not inventory_sys.is_deliverable_product(item_key):
		return

	var is_important = guests.current_guest.has_dialogue
	var npc_id = guests.current_guest.npc_id
	var success: bool = craft.can_satisfy_order(item_key, guests.current_guest.order_key)

	var item: Dictionary = craft.get_item(item_key)
	var item_price: int = item.get("price", 0)
	# 使用当日菜单定价（如果已配置）
	if _tavern_view != null and is_instance_valid(_tavern_view) and _tavern_view.daily_menu.has(item_key):
		item_price = int(_tavern_view.daily_menu[item_key].get("price", item_price))
	var serve_gold_delta := 0
	var serve_rep_delta := 0
	var appetite_result: Dictionary = {}
	var memory_result: Dictionary = {}
	_pending_guest_reaction_suffix = ""

	if success:
		var serve_quality: String = String(craft_style_data.get("quality", "normal"))
		var earned_gold := economy.gold_for_quality(item_price, serve_quality)
		var earned_rep := economy.reputation_for_quality(serve_quality)
		if not is_important and appetite != null and npc_id != "":
			appetite_result = appetite.evaluate(npc_id, item_key, serve_quality, seasoning_attribute)
			memory_result = _record_customer_memory_from_appetite(npc_id, item_key, String(item.get("name", item_key)), appetite_result)
			earned_gold += int(appetite_result.get("bonus_gold", 0))
			earned_rep += int(appetite_result.get("bonus_rep", 0))
			_pending_guest_reaction_suffix = _appetite_feedback_suffix(appetite_result)
		if not is_important:
			earned_gold = int(round(float(earned_gold) * _current_guest_group_tip_multiplier()))
			earned_rep += _current_guest_group_reputation_bonus()
			var group_feedback := _guest_group_feedback_suffix(item_key)
			if group_feedback != "":
				if _pending_guest_reaction_suffix != "":
					_pending_guest_reaction_suffix += "\n"
				_pending_guest_reaction_suffix += group_feedback
		serve_gold_delta = earned_gold
		serve_rep_delta = earned_rep
		var previous_gold := economy.gold
		var previous_max_gold := economy.max_gold_held
		var previous_rep := economy.reputation
		economy.add_gold(earned_gold)
		economy.add_reputation(earned_rep)
		if _tavern_view != null and is_instance_valid(_tavern_view) and _tavern_view.has_method("show_order_reward_feedback"):
			_tavern_view.show_order_reward_feedback(earned_gold, earned_rep, previous_gold, previous_rep, previous_max_gold, economy.max_gold_held)
		guests.record_order_success(earned_gold, earned_rep)
		ryan_slice.record_order_success()
		play_audio_event("serve_success")
		# 账本：金币收入 + 声望变化
		_ledger_gold(earned_gold, "上菜:%s" % item.get("name", item_key))
		if earned_rep > 0:
			_ledger_rep(earned_rep, "品质:%s" % serve_quality)
		if is_important:
			narrative.set_var("serve_result", "success")
	else:
		guests.record_order_failed(0, 0, "failed")
		play_audio_event("serve_fail")
		if is_important:
			narrative.set_var("serve_result", "fail")

	# L3 动作风格 → 信任阀门：仅重要 NPC 且订单正确时评估（失败不叠风格罚）
	if is_important and success and npc_id != "" and _current_guest_allows_narrative_actions():
		var serve_style_label: String = craft_style.classify(craft_style_data)
		var mem: Dictionary = craft.get_memory_for(item_key)
		var story_key: String = mem.get(npc_id, "")
		var l3: Dictionary = narrative.resolve_serve_style(npc_id, story_key, serve_style_label)
		var alternative_result: Dictionary = narrative.resolve_pending_alternative(npc_id)
		if npc_id == "ryan" and bool(alternative_result.get("resolved", false)):
			if bool(alternative_result.get("accepted", false)):
				_add_fate_note("ryan", "他收下了替代委托。")
			else:
				_add_fate_note("ryan", "他婉拒了替代委托。")
		print("[L3] serve_drop_speed=", craft_style_data.get("serve_drop_speed", 0.0),
			" style=", serve_style_label, " story_told=", l3["story_told"],
			" aff_", npc_id, "=", narrative.get_affection(npc_id))

	# Day12 当晚上菜结算后定格 Mira 结局：此刻温柔上菜的 +2 已计入 aff_mira，
	# 担责判定看的是最终信任值。无论成功失败都定格（失败也是一种走向）。
	if is_important and npc_id == "mira" and economy.current_day == 12:
		narrative.finalize_mira_ending()
		_finish_mira_toby_fate_tracks()

	if is_important and npc_id == "evelyn" and economy.current_day == EVELYN_FINAL_DAY:
		_finalize_evelyn_ending_for_current_day()

	if seasoning_attribute != "":
		narrative.set_var("seasoning_used", seasoning_attribute)

	add_current_day_event({
		"type": "serve",
		"label": _item_event_name(item_key),
		"detail": _serve_event_detail(success, serve_gold_delta, serve_rep_delta),
		"item_key": item_key,
		"success": success,
		"gold_delta": serve_gold_delta,
		"rep_delta": serve_rep_delta,
		"npc_id": npc_id,
		"appetite": appetite_result,
		"memory": memory_result,
	})
	guests.record_guest_served()

	var outcome: String
	if success:
		outcome = "success"
	elif item.get("type", "") == "product":
		outcome = "fail_wrong"
	else:
		outcome = "fail_weird"
	_refresh_current_customer_portrait(outcome)

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
		if outcome == "fail_abandon" and _tavern_view.has_method("show_order_timeout"):
			_tavern_view.show_order_timeout("等太久了")
		var line: String = guests.get_reaction_line(outcome, guests.current_guest.npc_id)
		if outcome == "success" and not guests.current_guest.has_dialogue:
			var gossip := _try_grant_mira_old_ledger_gossip()
			if bool(gossip.get("granted", false)):
				line += "\n" + String(gossip.get("line", ""))
			if _pending_guest_reaction_suffix != "":
				line += "\n" + _pending_guest_reaction_suffix
		_tavern_view.customer_say(line)
	_pending_guest_reaction_suffix = ""
	_guest_lingering = true
	await get_tree().create_timer(1.8).timeout
	_guest_lingering = false
	guests.clear_guest()


func _appetite_feedback_suffix(appetite_result: Dictionary) -> String:
	if appetite_result.is_empty():
		return ""
	var lines := PackedStringArray()
	var reaction := String(appetite_result.get("reaction", ""))
	if reaction != "":
		lines.append(reaction)
	var tier := String(appetite_result.get("tier", ""))
	if (tier == "delighted" or tier == "satisfied") and not get_today_rumors().is_empty():
		var tag_text := _appetite_tag_text(appetite_result.get("matched_tags", []))
		if tag_text != "":
			lines.append("传闻应验：" + tag_text + "正合今晚胃口。")
		else:
			lines.append("传闻应验：这份菜正合今晚胃口。")
	return "\n".join(lines)


func _current_guest_group_key() -> String:
	if guests == null or guests.current_guest == null:
		return ""
	return String(guests.current_guest.get_meta("guest_group", ""))


func _current_guest_group_tip_multiplier() -> float:
	if _current_guest_group_key() == "":
		return 1.0
	if guests == null or guests.current_guest == null:
		return 1.0
	return maxf(float(guests.current_guest.get_meta("tip_multiplier", 1.0)), 0.0)


func _current_guest_group_reputation_bonus() -> int:
	if _current_guest_group_key() == "":
		return 0
	if guests == null or guests.current_guest == null:
		return 0
	return int(guests.current_guest.get_meta("reputation_on_success", 0))


func _guest_group_feedback_suffix(item_key: String) -> String:
	var group_key := _current_guest_group_key()
	if group_key == "" or appetite == null or not appetite.has_method("get_product_tags"):
		return ""
	if guests == null or not guests.has_method("get_group_match_feedback"):
		return ""
	var tags: Array = appetite.get_product_tags(item_key)
	return String(guests.get_group_match_feedback(group_key, tags))


func _appetite_tag_text(tags) -> String:
	if not tags is Array:
		return ""
	var readable := PackedStringArray()
	for tag in tags:
		var text := String(tag)
		if text == "" or readable.has(text):
			continue
		readable.append(text)
		if readable.size() >= 3:
			break
	if readable.is_empty():
		return ""
	return "“" + " / ".join(readable) + "”"


func _refresh_current_customer_portrait(outcome: String = "") -> void:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	if guests.current_guest == null:
		return
	if not _tavern_view.has_method("show_customer_reaction"):
		return
	var npc_id := guests.current_guest.npc_id if guests.current_guest.npc_id != "" else "guest"
	var portrait_id := String(guests.current_guest.get_meta("portrait_id", npc_id))
	_tavern_view.show_customer_reaction(outcome, portrait_id)


func set_customer_expression(expression: String, npc_id: String = "") -> void:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	if not _tavern_view.has_method("show_customer_expression"):
		return
	var target_npc_id := npc_id
	if target_npc_id == "" and guests.current_guest != null:
		var fallback_id := guests.current_guest.npc_id if guests.current_guest.npc_id != "" else "guest"
		target_npc_id = String(guests.current_guest.get_meta("portrait_id", fallback_id))
	if target_npc_id == "":
		return
	_tavern_view.show_customer_expression(expression, target_npc_id)


func _important_guest_display_name(npc_id: String, fallback: String) -> String:
	if npc_id == "toby" and narrative.get_var("toby_identity_known") == true:
		return fallback
	return ryan_slice.important_display_name(economy.current_day, npc_id, fallback)


func _current_guest_allows_narrative_actions() -> bool:
	if guests == null or guests.current_guest == null:
		return false
	if not guests.current_guest.has_dialogue:
		return false
	return not _current_guest_is_fate_reveal()


func _current_guest_is_fate_reveal() -> bool:
	if guests == null or guests.current_guest == null:
		return false
	var npc_id := String(guests.current_guest.npc_id)
	if npc_id == "":
		return false
	for event in ryan_slice.night_events(economy.current_day):
		if String(event.get("npc_id", "")) == npc_id and String(event.get("type", "")) == "fate_reveal":
			return true
	return false


func _start_dialogue_deferred(dialogue_path: String, title: String = "start") -> void:
	var dialogue_resource = load(dialogue_path)
	if dialogue_resource == null:
		printerr("[GameManager] 对话文件加载失败: ", dialogue_path)
		_recover_from_dialogue_failure()
		return
	var extra_states: Array = [narrative.dialogue_vars]
	var balloon = DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON_SCENE, dialogue_resource, title, extra_states)
	if balloon == null:
		printerr("[GameManager] 显示对话气球失败: ", dialogue_path)
		_recover_from_dialogue_failure()
		return
	balloon.will_block_other_input = false

func _recover_from_dialogue_failure() -> void:
	_dialogue_phase = ""
	_is_dialogue_active = false
	_serve_tutorial_pending_after_dialogue = false
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.set_dialogue_mode(false)
	if guests.has_guest and guests.current_guest.has_dialogue:
		guests.clear_guest()

func _on_guest_left() -> void:
	if guests.current_guest != null and guests.current_guest.has_dialogue:
		_important_npc_pending = false
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.hide_customer()
	# 注：guest_left 在 clear_guest 内 emit，此刻 has_guest 仍为 true（随后才置 false）。
	# 必须延迟刷新，等 clear_guest 收尾后再算，否则按钮会卡在禁用，整段"等待中"无法打烊。
	call_deferred("_refresh_close_button")

func _on_dialogue_ended() -> void:
	_is_dialogue_active = false

	if _dialogue_phase == "pre":
		if guests.current_guest != null and guests.current_guest.npc_id == "toby":
			_collect_toby_day6_night_clues()
		_dialogue_phase = ""
		if _tavern_view != null and is_instance_valid(_tavern_view):
			_tavern_view.set_dialogue_mode(false)
		if _serve_tutorial_pending_after_dialogue:
			_serve_tutorial_pending_after_dialogue = false
			_start_first_guest_serve_tutorial()
		# 注：药酒导致 Ryan 离场现在由 request_narrative_delivery 在动作发生时处理，
		# 不再依赖 pre 对话结束（拖拽递交发生在 pre 对话之后）。

	elif _dialogue_phase == "post":
		_dialogue_phase = ""
		guests.clear_guest()
		if _tavern_view != null and is_instance_valid(_tavern_view):
			_tavern_view.set_dialogue_mode(false)

	elif _dialogue_phase == "action_feedback":
		_dialogue_phase = ""
		if _tavern_view != null and is_instance_valid(_tavern_view):
			_tavern_view.set_dialogue_mode(false)

func _on_patience_low() -> void:
	if _tavern_view != null and is_instance_valid(_tavern_view) and guests.current_guest != null:
		if _tavern_view.has_method("show_order_warning"):
			_tavern_view.show_order_warning()
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

	current_ledger_data = _create_ledger_data_for_current_day()
	add_current_day_event({
		"type": "settlement",
		"label": "今日结算",
		"detail": "%+dG / %+d REP" % [economy.gold_today, economy.rep_today],
		"gold_delta": economy.gold_today,
		"rep_delta": economy.rep_today,
	})
	documents.record_daily_summary(economy.current_day, {
		"gold_today": economy.gold_today,
		"rep_today": economy.rep_today,
		"guests_served": guests.guests_served_today,
		"orders_success": guests.orders_success,
		"orders_failed": guests.orders_failed,
	})
	ryan_slice.complete_day(economy.current_day)

	economy.reset_daily()
	guests.reset_daily()
	if _tavern_view != null:
		_tavern_view.reset_today_gold()
		_tavern_view.daily_menu.clear()
		_tavern_view.daily_menu_confirmed = false

	var next_scene := "res://scenes/ui/LedgerScreen.tscn"
	if inference != null and inference.has_available_questions():
		next_scene = "res://scenes/ui/CleanTableInferenceScreen.tscn"
	get_tree().call_deferred("change_scene_to_file", next_scene)


func _create_ledger_data_for_current_day() -> LedgerData:
	var fates = narrative.get_today_npc_fates(economy.current_day)
	_sync_fate_track_results_for_day(economy.current_day)

	var data := LedgerData.new()
	data.day = economy.current_day
	data.gold_today = economy.gold_today
	data.rep_today = economy.rep_today
	data.gold_total = economy.gold
	data.rep_total = economy.reputation
	data.guests_served = guests.guests_served_today
	data.orders_success = guests.orders_success
	data.orders_failed = guests.orders_failed
	data.guest_entries = guests.get_guest_entries_today()
	data.rumor_summary = _create_rumor_summary_for_current_day()
	data.npc_fates = fates
	data.fate_warning_next_day = _has_next_day_fate_ledger_warning()
	return data


func _create_rumor_summary_for_current_day() -> Dictionary:
	var today_rumors := get_today_rumors()
	if today_rumors.is_empty():
		return {}
	var hit_count := 0
	var bonus_gold := 0
	var bonus_rep := 0
	var tag_seen := {}
	var memory_seen := {}
	var word_label_seen := {}
	var affected_ids := _affected_customer_ids_from_rumors(today_rumors)
	var affected_lookup := {}
	for customer_id in affected_ids:
		affected_lookup[customer_id] = true
	var arrived_lookup := {}
	var matched_lookup := {}
	for event in _current_day_events:
		if not event is Dictionary:
			continue
		var event_data: Dictionary = event
		if String(event_data.get("type", "")) != "serve" or not bool(event_data.get("success", false)):
			continue
		var npc_id := String(event_data.get("npc_id", ""))
		var is_affected_customer := npc_id != "" and bool(affected_lookup.get(npc_id, false))
		if is_affected_customer:
			arrived_lookup[npc_id] = true
		var appetite_result: Dictionary = event_data.get("appetite", {})
		if appetite_result.is_empty():
			continue
		var tier := String(appetite_result.get("tier", ""))
		if tier != "delighted" and tier != "satisfied":
			continue
		hit_count += 1
		if is_affected_customer:
			matched_lookup[npc_id] = true
		bonus_gold += int(appetite_result.get("bonus_gold", 0))
		bonus_rep += int(appetite_result.get("bonus_rep", 0))
		for tag in appetite_result.get("matched_tags", []):
			var tag_text := String(tag)
			if tag_text != "":
				tag_seen[tag_text] = true
		var memory: Dictionary = event_data.get("memory", {})
		var note := String(memory.get("note", ""))
		if note != "":
			memory_seen[note] = true
		for label in memory.get("word_of_mouth_labels", []):
			var label_text := String(label)
			if label_text != "":
				word_label_seen[label_text] = true
	var tags: Array[String] = []
	for tag in tag_seen.keys():
		tags.append(String(tag))
	tags.sort()
	var first_rumor: Dictionary = today_rumors[0]
	var menu_hints: Dictionary = first_rumor.get("menuHints", {})
	var arrived_ids := _sorted_keys_as_strings(arrived_lookup)
	var matched_ids := _sorted_keys_as_strings(matched_lookup)
	var missed_ids: Array[String] = []
	for customer_id in arrived_ids:
		if not bool(matched_lookup.get(customer_id, false)):
			missed_ids.append(customer_id)
	return {
		"heard": true,
		"hit_count": hit_count,
		"bonus_gold": bonus_gold,
		"bonus_rep": bonus_rep,
		"tags": tags,
		"affected_customers": _customer_names_from_ids(affected_ids),
		"arrived_customers": _customer_names_from_ids(arrived_ids),
		"matched_customers": _customer_names_from_ids(matched_ids),
		"missed_customers": _customer_names_from_ids(missed_ids),
		"memory_notes": _sorted_keys_as_strings(memory_seen),
		"word_of_mouth_labels": _sorted_keys_as_strings(word_label_seen),
		"summary": String(menu_hints.get("summary", first_rumor.get("text", ""))),
	}


func _affected_customer_ids_from_rumors(today_rumors: Array[Dictionary]) -> Array[String]:
	var seen := {}
	for rumor in today_rumors:
		for customer_id in _string_array_from_values(rumor.get("affectedCustomerIds", [])):
			seen[customer_id] = true
	return _sorted_keys_as_strings(seen)


func _customer_names_from_ids(ids: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for customer_id in ids:
		var preview := _regular_customer_preview(customer_id)
		var name := String(preview.get("name", customer_id))
		if name == "":
			continue
		if not names.has(name):
			names.append(name)
	return names


func _sorted_keys_as_strings(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in values.keys():
		result.append(String(key))
	result.sort()
	return result


func _string_array_from_values(values) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		var text := String(value)
		if text == "":
			continue
		if not result.has(text):
			result.append(text)
	return result

func finish_clean_table_inference() -> void:
	_finalize_evelyn_ending_for_current_day(true)
	save_sys.write(_capture_save_state())
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
	_ledger_gold(-total, "商店购买")
	_ledger_item(key, quantity, "商店")
	add_current_day_event({
		"type": "purchase_material",
		"label": _item_event_name(key),
		"detail": "x%d / -%dG" % [quantity, total],
		"item_key": key,
		"quantity": quantity,
		"gold_delta": -total,
	})
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
	craft.mark_recipe_new(key)
	_ledger_gold(-price, "配方解锁:%s" % key)
	add_current_day_event({
		"type": "recipe_unlock",
		"label": _recipe_event_name(key),
		"detail": "-%dG" % price,
		"recipe_key": key,
		"gold_delta": -price,
	})
	return true

func discover_recipe(product_key: String, notify: bool = true) -> bool:
	if craft == null:
		return false
	var discovered := craft.discover_recipe(product_key)
	if discovered:
		craft.mark_recipe_new(product_key)
	if discovered and notify:
		if _tavern_view != null and is_instance_valid(_tavern_view) and _tavern_view.has_method("show_recipe_discovery_notice"):
			_tavern_view.show_recipe_discovery_notice(product_key)
	return discovered

const ABILITY_TO_CONTAINER := {"slam_pot": "pot", "slam_barrel": "barrel"}

func buy_ability(key: String) -> bool:
	var container: String = ABILITY_TO_CONTAINER.get(key, "")
	if container == "":
		return false
	if craft.is_slam_unlocked(container):
		return false
	var price: int = shop.get_ability_price(key)
	if price <= 0:
		return false
	if not economy.spend_gold(price):
		return false
	craft.unlock_slam(container)
	_ledger_gold(-price, "能力购买:%s" % key)
	add_current_day_event({
		"type": "ability_unlock",
		"label": shop.get_ability_name(key),
		"detail": "-%dG" % price,
		"ability_key": key,
		"gold_delta": -price,
	})
	return true

func is_ability_owned(key: String) -> bool:
	var container: String = ABILITY_TO_CONTAINER.get(key, "")
	return container != "" and craft.is_slam_unlocked(container)

func _refresh_tavern_ui() -> void:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	_tavern_view.update_top_bar(economy.gold, economy.reputation, economy.current_day, ryan_slice.last_day(), economy.max_gold_held)


func notify_stage_caption(text: String, color: Color = Color.WHITE) -> void:
	if _tavern_view != null and is_instance_valid(_tavern_view):
		_tavern_view.show_stage_caption(text, color)

func notify_inventory_changed() -> void:
	if inventory.get("sleep_powder", 0) > 0:
		narrative.set_var("has_sleep_powder", true)
	inventory_changed.emit()

func _default_shortcut_bindings() -> Array[String]:
	var result: Array[String] = []
	for key in DEFAULT_SHORTCUT_BINDINGS:
		result.append(String(key))
	return result

func get_shortcut_bindings() -> Array[String]:
	if shortcut_bindings.size() != 10:
		shortcut_bindings = _normalized_shortcut_bindings(shortcut_bindings)
	return shortcut_bindings.duplicate()

func can_bind_shortcut_item(item_key: String) -> bool:
	if item_key == "" or inventory_sys == null:
		return false
	if inventory_sys.is_material(item_key):
		return true
	return seasoning != null and seasoning.is_seasoning(item_key)

func bind_shortcut_item(slot_index: int, item_key: String) -> bool:
	if slot_index < 0 or slot_index >= 10:
		return false
	if not can_bind_shortcut_item(item_key):
		return false
	shortcut_bindings = _normalized_shortcut_bindings(shortcut_bindings)
	for i in range(shortcut_bindings.size()):
		if i != slot_index and shortcut_bindings[i] == item_key:
			shortcut_bindings[i] = ""
	shortcut_bindings[slot_index] = item_key
	notify_inventory_changed()
	return true

func clear_shortcut_binding(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 10:
		return false
	shortcut_bindings = _normalized_shortcut_bindings(shortcut_bindings)
	shortcut_bindings[slot_index] = ""
	notify_inventory_changed()
	return true

func _normalized_shortcut_bindings(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for i in range(10):
		var key := ""
		if i < raw.size():
			key = String(raw[i])
		if key != "" and can_bind_shortcut_item(key):
			result.append(key)
		else:
			result.append("")
	return result

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


## 把 resolve_action 的 feedback key 翻成玩家可见提示（正式对话 / 顾客气泡 / 舞台提示 / 静默）。
func _show_action_feedback(feedback: String) -> void:
	if ACTION_FEEDBACK_DIALOGUE_TITLES.has(feedback):
		_show_action_feedback_dialogue(feedback)
		return
	if not ACTION_FEEDBACK.has(feedback):
		return
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	var channel := String(ACTION_FEEDBACK_CHANNEL.get(feedback, "stage"))
	if channel == "silent":
		return
	var entry: Array = ACTION_FEEDBACK[feedback]
	var text := String(entry[0])
	var color: Color = entry[1]
	if channel == "customer" and _tavern_view.has_method("customer_say"):
		_tavern_view.customer_say(text)
		return
	_tavern_view.show_stage_caption(text, color)

func _show_action_feedback_dialogue(feedback: String) -> void:
	if _tavern_view == null or not is_instance_valid(_tavern_view):
		return
	if _tavern_view is Node and not (_tavern_view as Node).is_inside_tree():
		return
	_dialogue_phase = "action_feedback"
	if _tavern_view.has_method("set_dialogue_mode"):
		_tavern_view.set_dialogue_mode(true)
	var title := String(ACTION_FEEDBACK_DIALOGUE_TITLES[feedback])
	call_deferred("_start_dialogue_deferred", RYAN_ACTION_FEEDBACK_DIALOGUE, title)


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
	var allows_narrative_actions := _current_guest_allows_narrative_actions()

	if not allows_narrative_actions:
		if inventory_sys.is_story_item(item_key):
			if _tavern_view != null and is_instance_valid(_tavern_view):
				_tavern_view.show_stage_caption("他不需要这个，收回了吧。", Color.GRAY)
			return {"handled": true, "accepted": false, "consume": false, "interaction_closed": false, "feedback": "unsupported_npc"}
		if inventory_sys.is_product(item_key):
			return {"handled": false}

	if inventory_sys.is_story_item(item_key):
		var r: Dictionary = narrative.resolve_action({
			"type": "give_story_item",
			"npc_id": npc_id,
			"item_key": item_key,
			"day": economy.current_day,
		})
		var feedback: String = String(r.get("feedback", ""))
		# 错误递交（递错人/不认得的物品）→ 自动回背包，不显示动作反馈
		if feedback in ["unsupported_npc", "unsupported_story_item"]:
			if _tavern_view != null and is_instance_valid(_tavern_view):
				_tavern_view.show_stage_caption("他不需要这个，收回了吧。", Color.GRAY)
			return {"handled": true, "accepted": false, "consume": false, "interaction_closed": false, "feedback": feedback}
		_show_action_feedback(feedback)
		var accepted: bool = bool(r.get("accepted", false))
		if accepted:
			_refresh_current_customer_portrait()
			_record_story_item_fate_note(npc_id, item_key)
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
			_add_fate_note("ryan", "酒中有沉睡花粉。")
			guests.clear_guest()
			if _tavern_view != null and is_instance_valid(_tavern_view):
				_tavern_view.hide_customer()
		return {"handled": true, "accepted": accepted, "consume": accepted,
			"interaction_closed": bool(r.get("interaction_closed", false)), "feedback": feedback}

	return {"handled": false}


func _record_story_item_fate_note(npc_id: String, item_key: String) -> void:
	if npc_id == "ryan" and item_key == "bloodied_contract":
		_add_fate_note("ryan", "读过染血委托。")
		documents.index_evidence("bloodied_contract", ["莱恩", "北矿道"])
	elif npc_id == "ryan" and item_key == "alternative_contract":
		_add_fate_note("ryan", "替代委托已递出。")
		documents.index_evidence("alternative_contract", ["莱恩", "公会柜台"])
	elif npc_id == "mira" and item_key == "toby_contract":
		_add_fate_note("mira", "托比的委托书已递到她手上。")
		_add_fate_note("toby", "托比的委托书已递给米拉。")
		documents.index_evidence("toby_contract", ["托比", "米拉"])


func _add_fate_note(track_id: String, note: String) -> void:
	_ensure_fate_track(track_id)
	if documents.add_fate_note(track_id, note):
		play_audio_event("new_document")


func _ensure_fate_track(track_id: String) -> void:
	match track_id:
		"ryan":
			documents.start_fate_track("ryan", "莱恩", "第三日。北矿道。未归。", false)
		"toby":
			documents.start_fate_track("toby", "托比", "第十二日。黑齿矿脉护送委托。未归。", false)
		"mira":
			documents.start_fate_track("mira", "米拉", "第十二日。长期供应协议。签署。", false)
		"evelyn":
			documents.start_fate_track("evelyn", "伊芙琳", "第二十日。灰账清算。封存。", false)


func _sync_fate_track_results_for_day(day: int) -> void:
	if day == 3:
		_finish_ryan_fate_track()
	if day == 12:
		_finish_mira_toby_fate_tracks()
	if day == EVELYN_FINAL_DAY:
		if str(narrative.get_var("evelyn_resolution_state")) == "pending":
			_refresh_evelyn_public_gap_vars()
			return
		if _should_defer_evelyn_finalization_for_inference():
			_refresh_evelyn_public_gap_vars()
			return
		_finish_evelyn_fate_track()


func _finalize_evelyn_ending_for_current_day(force: bool = false) -> void:
	if economy.current_day != EVELYN_FINAL_DAY:
		return
	if not force and _should_defer_evelyn_finalization_for_inference():
		_refresh_evelyn_public_gap_vars()
		narrative.set_var("evelyn_resolution_state", "pending")
		return
	_clear_evelyn_public_gap_vars()
	narrative.set_var("evelyn_resolution_state", "final")
	narrative.finalize_evelyn_ending()
	_finish_evelyn_fate_track()
	_refresh_current_ledger_fates_for_current_day()


func _should_defer_evelyn_finalization_for_inference() -> bool:
	if narrative.get_var("grey_public_account_known") == true:
		return false
	return inference != null and inference.has_available_questions()


func _refresh_current_ledger_fates_for_current_day() -> void:
	if current_ledger_data == null:
		return
	if current_ledger_data.day != economy.current_day:
		return
	current_ledger_data.npc_fates = narrative.get_today_npc_fates(economy.current_day)
	current_ledger_data.fate_warning_next_day = _has_next_day_fate_ledger_warning()


func _finish_ryan_fate_track() -> void:
	var route := String(narrative.get_var("ryan_ending"))
	if route == "":
		route = narrative.get_ryan_route()
	_ensure_fate_track("ryan")
	var result := _ryan_track_result(route)
	if result != "" and documents.finish_fate_track("ryan", result):
		play_audio_event("new_document")


func _finish_mira_toby_fate_tracks() -> void:
	_ensure_fate_track("mira")
	_ensure_fate_track("toby")
	var mira_route := String(narrative.get_var("mira_ending"))
	var toby_route := String(narrative.endings.get("toby", ""))
	var mira_result := _mira_track_result(mira_route)
	var toby_result := _toby_track_result(toby_route, mira_route)
	var changed := false
	if mira_result != "":
		changed = documents.finish_fate_track("mira", mira_result) or changed
	if toby_result != "":
		changed = documents.finish_fate_track("toby", toby_result) or changed
	if changed:
		play_audio_event("new_document")


func _finish_evelyn_fate_track() -> void:
	_ensure_fate_track("evelyn")
	var route := String(narrative.get_var("evelyn_ending"))
	if route == "":
		route = narrative.get_evelyn_route()
	var result := _evelyn_track_result(route)
	if result != "" and documents.finish_fate_track("evelyn", result):
		play_audio_event("new_document")


func _ryan_track_result(route: String) -> String:
	match route:
		"alternative_survivor":
			return "未赴血斧委托。存活。改走更慢的安全路线。"
		"drugged_survivor":
			return "未赴约。存活。怨恨未消。"
		"informed_fallen":
			return "清醒赴约。未归。"
		"uninformed_fallen":
			return "毫不知情地赴约。未归。"
	return ""


func _mira_track_result(route: String) -> String:
	match route:
		"she_finally_stopped":
			return "撕掉长期供应协议。回头带走托比。"
		"never_turned_back":
			return "读完委托，仍签下协议。"
		"closed_the_door":
			return "协议照签。她不知道有人替她兜了底。"
		"another_light_out":
			return "协议照签。托比未归。"
	return ""


func _toby_track_result(route: String, mira_route: String) -> String:
	if route == "saved":
		if mira_route == "she_finally_stopped":
			return "未赴黑齿。存活。米拉回头。"
		return "未赴黑齿。存活。"
	if route == "lost":
		return "赴黑齿矿脉。未归。"
	return ""


func _evelyn_track_result(route: String) -> String:
	var pressure := ""
	var raw_pressure = narrative.get_var("evelyn_pressure")
	if raw_pressure != null:
		pressure = String(raw_pressure)
	if pressure == "" and narrative.has_method("get_evelyn_pressure"):
		pressure = narrative.get_evelyn_pressure(route)
	var evidence_summary := _evelyn_pressure_evidence_suffix()
	match route:
		"public_account":
			if pressure == "living_witnesses":
				return "灰账公开。莱恩、托比和米拉三条线合为一案，活人和纸证一起顶住公会封存。" + evidence_summary
			if pressure == "paper_public":
				return "灰账公开。莱恩、托比和米拉三条线合为一案，纸证替未归和沉默的人说话。" + evidence_summary
			return "灰账公开。三条线合为一案，封存失败。" + evidence_summary
		"amended_account":
			if pressure == "damaged_amendment":
				return "承认账面有误。部分改账，活下来的人得到喘息，但灰账仍由公会保管。"
			if pressure == "cold_amendment":
				return "承认账面有误。部分改账，但冷账多过活口，灰账仍由公会保管。"
			return "承认账面有误。部分改账。"
		"sealed_account":
			return "灰账封存。证据不足以公开，事故照常归档。"
	return ""


func _evelyn_pressure_evidence_suffix() -> String:
	if narrative == null or not narrative.has_method("get_evelyn_pressure_evidence_summary"):
		return ""
	var summary := String(narrative.get_evelyn_pressure_evidence_summary())
	return "" if summary == "" else summary


func _evidence_links_for(document_id: String) -> Array:
	match document_id:
		"bloodied_contract":
			return ["莱恩", "北矿道"]
		"alternative_contract":
			return ["莱恩", "公会柜台"]
		"toby_contract":
			return ["托比", "米拉"]
		"grey_ryan_case_number":
			return ["莱恩", "伊芙琳", "灰账"]
		"grey_old_payout_register":
			return ["伊芙琳", "灰账"]
		"grey_missing_page":
			return ["伊芙琳", "灰账"]
		"grey_blacktooth_batch":
			return ["托比", "伊芙琳", "灰账"]
		"grey_closure_method":
			return ["伊芙琳", "灰账"]
		"grey_payout_closure":
			return ["莱恩", "伊芙琳", "灰账"]
		"grey_renamed_escort":
			return ["托比", "伊芙琳", "灰账"]
		"grey_supply_stamp":
			return ["米拉", "伊芙琳", "灰账"]
	return []


func request_open_document(document_id: String) -> Dictionary:
	# 首次阅读 evidence 类型文档时，将其登记为账本证物索引，全文仍留在文档本身。
	var first_read: bool = documents.owns_document(document_id) and not documents.is_read(document_id)
	var document := documents.request_open(document_id)
	if document.is_empty():
		return document
	if first_read and String(document.get("kind", "")) == "evidence":
		documents.index_evidence(document_id, _evidence_links_for(document_id))
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


func apply_material_icon_to_desk_item(item) -> void:
	if item == null or not is_instance_valid(item) or not item.has_method("set_art_texture"):
		return
	var item_key := String(item.get("item_key"))
	if item_key == "":
		item.set_art_texture(null)
		return
	item.set_art_texture(try_load_material_icon(item_key))

## ── 账本记录辅助 ──

func _ledger_gold(amount: int, reason: String) -> void:
	pass

func _ledger_rep(amount: int, reason: String) -> void:
	pass

func _ledger_item(key: String, count: int, source: String) -> void:
	pass

func _ledger_day_header() -> void:
	pass

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
			"max_gold_held": economy.max_gold_held,
			"reputation": economy.reputation,
			"tavern_level": economy.tavern_level,
		},
		"inventory": inventory_sys.materials.duplicate(),
		"shortcut_bindings": get_shortcut_bindings(),
		"documents": documents.capture_state(),
		"day_map": day_map.capture_state() if day_map != null else {},
		"rumors": rumors.capture_state() if rumors != null else {},
		"word_of_mouth": _word_of_mouth.duplicate(true),
		"inference": inference.capture_state() if inference != null else {},
		"narrative": {
			"dialogue_vars": narrative.dialogue_vars.duplicate(true),
			"affection": narrative.affection.duplicate(true),
			"endings": narrative.endings.duplicate(true),
			"today_important_npc": narrative.today_important_npc,
		},
		"craft": {
			"unlocked_recipes": craft.unlocked_recipes.duplicate(),
			"discovered_recipes": craft.discovered_recipes.duplicate(),
			"newly_discovered_recipes": craft.newly_discovered_recipes.duplicate(),
			"unlocked_slam_containers": craft.unlocked_slam_containers.duplicate(),
		},
		"tutorial": _capture_tutorial_state(),
		"ryan_slice": ryan_slice.capture_state(),
		"guests": guests.capture_state(),
		"day_start_snapshot": _day_start_snapshot.duplicate(true),
		"current_day_events": _current_day_events.duplicate(true),
	}

func _capture_tutorial_state() -> Dictionary:
	var tm = _tutorial_manager
	if tm == null:
		return {}
	return {
		"completed_steps": tm._completed_steps.duplicate(),
		"daymap_first_shown": tm.daymap_first_shown,
		"tavern_first_entered": tm.tavern_first_entered,
		"first_menu_prep_shown": tm.first_menu_prep_shown,
		"shop_first_visited": tm.shop_first_visited,
		"first_guest_arrived": tm.first_guest_arrived,
		"first_product_seasoned": tm.first_product_seasoned,
		"first_guest_served": tm.first_guest_served,
		"first_ledger_shown": tm.first_ledger_shown,
		"first_inference_shown": tm.first_inference_shown,
	}

## 把快照写回各子系统。只恢复稳定状态，不推进日期。
func _apply_save_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var eco: Dictionary = data.get("economy", {})
	economy.current_day = int(eco.get("current_day", 1))
	economy.gold = int(eco.get("gold", 0))
	economy.max_gold_held = maxi(int(eco.get("max_gold_held", economy.gold)), economy.gold)
	economy.reputation = int(eco.get("reputation", 0))
	economy.tavern_level = int(eco.get("tavern_level", 1))
	economy.gold_today = 0
	economy.rep_today = 0

	inventory_sys.set_initial(data.get("inventory", {}))
	shortcut_bindings = _normalized_shortcut_bindings(data.get("shortcut_bindings", _default_shortcut_bindings()))

	documents.restore_state(data.get("documents", {}))
	_day_map_state_missing_from_save = not data.has("day_map")
	if day_map != null:
		day_map.restore_state(data.get("day_map", {}))
	if rumors != null:
		rumors.restore_state(data.get("rumors", {}))
	_word_of_mouth = (data.get("word_of_mouth", {}) as Dictionary).duplicate(true)
	if inference != null:
		inference.restore_state(data.get("inference", {}))
	_announced_inference_question_ids.clear()

	var nar: Dictionary = data.get("narrative", {})
	var restored_vars := _fresh_narrative_vars()
	var saved_vars := (nar.get("dialogue_vars", {}) as Dictionary).duplicate(true)
	for key in saved_vars.keys():
		restored_vars[key] = saved_vars[key]
	narrative.dialogue_vars = restored_vars
	narrative.affection = (nar.get("affection", {}) as Dictionary).duplicate(true)
	narrative.endings = (nar.get("endings", {}) as Dictionary).duplicate(true)
	narrative.today_important_npc = String(nar.get("today_important_npc", ""))

	craft.unlocked_recipes.clear()
	for r in data.get("craft", {}).get("unlocked_recipes", []):
		craft.unlocked_recipes.append(String(r))
	craft.discovered_recipes.clear()
	for r in data.get("craft", {}).get("discovered_recipes", []):
		craft.discovered_recipes.append(String(r))
	craft.ensure_default_discovered_recipes()
	for r in craft.unlocked_recipes:
		craft.discover_recipe(String(r))
	craft.newly_discovered_recipes.clear()
	for r in data.get("craft", {}).get("newly_discovered_recipes", []):
		craft.newly_discovered_recipes.append(String(r))
	craft.prune_new_recipe_markers()
	craft.unlocked_slam_containers.clear()
	for sc in data.get("craft", {}).get("unlocked_slam_containers", []):
		craft.unlocked_slam_containers.append(String(sc))

	_apply_tutorial_state(data.get("tutorial", {}))
	ryan_slice.restore_state(data.get("ryan_slice", {}))
	guests.restore_state(data.get("guests", {}))
	_day_start_snapshot = (data.get("day_start_snapshot", {}) as Dictionary).duplicate(true)
	_current_day_events = (data.get("current_day_events", []) as Array).duplicate(true)
	notify_inventory_changed()


func capture_day_start_snapshot() -> void:
	var snapshot := _capture_save_state().duplicate(true)
	snapshot.erase("day_start_snapshot")
	snapshot["current_day_events"] = []
	_day_start_snapshot = snapshot
	_current_day_events.clear()


func has_day_start_snapshot() -> bool:
	return not _day_start_snapshot.is_empty()


func add_current_day_event(event: Dictionary) -> void:
	if event.is_empty():
		return
	var clean := event.duplicate(true)
	clean["day"] = economy.current_day
	_current_day_events.append(clean)
	if _current_day_events.size() > 24:
		_current_day_events.pop_front()


func get_current_day_events() -> Array:
	return _current_day_events.duplicate(true)


func clear_current_day_events() -> void:
	_current_day_events.clear()


func _item_event_name(key: String) -> String:
	if craft == null:
		return key
	var item: Dictionary = craft.get_item(key)
	return String(item.get("name", key))


func _recipe_event_name(key: String) -> String:
	if craft == null:
		return key
	var recipe: Dictionary = craft.recipes.get(key, {})
	return String(recipe.get("name", _item_event_name(key)))


func _day_location_event_detail(result: Dictionary) -> String:
	var parts := PackedStringArray()
	var reward_counts: Dictionary = result.get("reward_counts", {})
	for key in reward_counts.keys():
		var count := int(reward_counts[key])
		if count > 0:
			parts.append("%s x%d" % [_item_event_name(String(key)), count])
	for document_id in result.get("documents", []):
		parts.append(String(document_id))
	if not parts.is_empty():
		return "获得 " + "、".join(parts)
	return String(result.get("message", ""))


func _serve_event_detail(success: bool, gold_delta: int, rep_delta: int) -> String:
	if success:
		return "成功 %+dG / %+d REP" % [gold_delta, rep_delta]
	return "未满足点单"


func _day_start_snapshot_day() -> int:
	var eco: Dictionary = _day_start_snapshot.get("economy", {})
	return int(eco.get("current_day", -1))

func _apply_tutorial_state(t: Dictionary) -> void:
	var tm = _tutorial_manager
	if tm == null or t.is_empty():
		return
	tm._completed_steps = (t.get("completed_steps", []) as Array).duplicate()
	tm.daymap_first_shown = bool(t.get("daymap_first_shown", false))
	tm.tavern_first_entered = bool(t.get("tavern_first_entered", false))
	tm.first_menu_prep_shown = bool(t.get("first_menu_prep_shown", false))
	tm.shop_first_visited = bool(t.get("shop_first_visited", false))
	tm.first_guest_arrived = bool(t.get("first_guest_arrived", false))
	tm.first_product_seasoned = bool(t.get("first_product_seasoned", false))
	tm.first_guest_served = bool(t.get("first_guest_served", false))
	tm.first_ledger_shown = bool(t.get("first_ledger_shown", false))
	tm.first_inference_shown = bool(t.get("first_inference_shown", false))
	tm._save_state()


func reset_tutorial_progress() -> void:
	_craft_tutorial_pending_after_menu = false
	var tm = _tutorial_manager
	if tm == null:
		tm = get_node_or_null("/root/TutorialManager")
	if tm != null:
		tm.replay_all()
	if save_sys.has_save():
		var snapshot := save_sys.read()
		if snapshot.is_empty():
			snapshot = _capture_save_state()
		snapshot["tutorial"] = _default_tutorial_state()
		save_sys.write(snapshot)

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
	if not _day_start_snapshot.is_empty():
		var snapshot := _day_start_snapshot.duplicate(true)
		_apply_save_state(snapshot)
		_day_start_snapshot = snapshot
		_current_day_events.clear()
		current_ledger_data = null
		_guest_lingering = false
		_important_npc_pending = false
		_craft_tutorial_pending_after_menu = false
		_is_dialogue_active = false
		day_cycle.phase = DayCycleSystem.DayPhase.DAY
		if save_sys != null:
			save_sys.write(_capture_save_state())
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/DayMap.tscn")
		return
	# 只有日初快照，重开当天 == 加载该快照（spec §12 "从稳定初始状态开始"）。
	continue_game()

## 一次性消费「刚看完开场」标志：返回是否应走 match-cut 拉镜，读后即清。
func consume_intro_handoff() -> bool:
	var v := _pending_intro_handoff
	_pending_intro_handoff = false
	return v

func new_game() -> void:
	save_sys.clear()
	_apply_save_state(_default_new_game_state())
	day_cycle.phase = DayCycleSystem.DayPhase.DAY
	_pending_intro_handoff = true
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/IntroSequence.tscn")

func _default_new_game_state() -> Dictionary:
	return {
		"economy": {"current_day": 1, "gold": 0, "max_gold_held": 0, "reputation": 0, "tavern_level": 1},
		"inventory": _load_initial_inventory(),
		"shortcut_bindings": _default_shortcut_bindings(),
		"documents": {"owned": ["ledger"], "read": {}, "archived": [], "ledger_entries": []},
		"day_map": {"current_day": 1, "revealed": [], "announced_postings": {}},
		"rumors": {"current_day": 1, "heard_ids": [], "today_ids": []},
		"word_of_mouth": {},
		"inference": {"owned_clues": [], "placements": {}, "solved": []},
		"narrative": {"dialogue_vars": _fresh_narrative_vars(), "affection": {"ryan": 0, "mira": 5, "toby": 0, "evelyn": 0},
			"endings": {}, "today_important_npc": ""},
		"craft": {
			"unlocked_recipes": [],
			"discovered_recipes": CraftSystem.DEFAULT_DISCOVERED_RECIPES.duplicate(),
			"newly_discovered_recipes": [],
			"unlocked_slam_containers": [],
		},
		"tutorial": _default_tutorial_state(),
		"ryan_slice": {"total_orders_success": 0, "completed_days": []},
		"guests": {"customers": [], "next_seq": 1},
	}


func _default_tutorial_state() -> Dictionary:
	return {
		"completed_steps": [],
		"daymap_first_shown": false,
		"tavern_first_entered": false,
		"first_menu_prep_shown": false,
		"shop_first_visited": false,
		"first_guest_arrived": false,
		"first_product_seasoned": false,
		"first_guest_served": false,
		"first_ledger_shown": false,
		"first_inference_shown": false,
	}


## 与 narrative_manager.load_npc_data() 的默认值保持一致（fresh game 的真相源）。
func _fresh_narrative_vars() -> Dictionary:
	return {
		"has_sleep_powder": false, "ryan_informed": false, "ryan_has_alternative": false,
		"ryan_warhammer_lead": false,
		"ryan_drugged": false, "ryan_interaction_closed": false, "ryan_ending": "",
		"ryan_alternative_pending": false, "ryan_alternative_declined": false,
		"merchant_sleep_powder_hint_seen": false,
		"told_mira_truth": false, "toby_name_seen": false, "toby_name_lead": false,
		"toby_identity_known": false, "toby_commission_lead": false,
		"toby_danger_known": false, "toby_contract_found": false,
		"mira_contract_aftershock_seen": false,
		"mira_responsibility_stall_bonus_seen": false,
		"toby_secured": false, "toby_secured_by_fixer": false, "toby_survived": false,
		"mira_ending": "",
		"aff_ryan": 0, "aff_mira": 5,
		"aff_toby": 0,
		"grey_same_batch_known": false,
		"grey_payout_method_known": false,
		"mira_grey_ledger_link_known": false,
		"grey_public_account_known": false,
		"evelyn_ending": "",
		"evelyn_pressure": "",
		"evelyn_resolution_state": "",
		"evelyn_public_gap_summary": "",
		"evelyn_public_gap_primary": "",
		"aff_evelyn": 0,
	}
