class_name NarrativeManager
extends RefCounted

## L3 信任阀门：上菜手法定夺替代委托所需的最低 aff_ryan。范围约 [-1, 7]（Day1风格+Day1post+3+Day2风格）。改此文件调整。
const TRUST_THRESHOLD := 5

## Mira 线信任阀门：告知真相后 aff_mira 达此值她才肯担责。Mira 专属，不复用 Ryan 的 TRUST_THRESHOLD。
const MIRA_TRUST_THRESHOLD := 10

const LINKED_FATE_DAYS: Dictionary = {
	12: ["toby"],
}

var all_npcs: Array[NpcData] = []
var dialogue_vars: Dictionary = {}
var key_items: Array = []
var affection: Dictionary = {}
var endings: Dictionary = {}
var today_important_npc: String = ""
var day_encounter_triggered: bool = false

func set_var(key: String, value) -> void:
	dialogue_vars[key] = value

func get_var(key: String):
	return dialogue_vars.get(key, null)

func has_key_item(item_id: String) -> bool:
	return key_items.has(item_id)

func add_key_item(item_id: String) -> void:
	if not key_items.has(item_id):
		key_items.append(item_id)
	set_var("has_" + item_id, true)

func set_affection(npc_id: String, value: int) -> void:
	affection[npc_id] = value
	set_var("aff_" + npc_id, value)

func get_affection(npc_id: String) -> int:
	var v = dialogue_vars.get("aff_" + npc_id, 0)
	return int(v)

func set_ending(npc_id: String, ending: String) -> void:
	endings[npc_id] = ending
	dialogue_vars[npc_id + "_ending"] = ending
	print("[Narrative] ", npc_id, " 结局 → ", ending)


func resolve_action(action: Dictionary) -> Dictionary:
	match String(action.get("type", "")):
		"add_story_item_to_product":
			return _resolve_story_item_product_action(action)
		"give_story_item":
			match String(action.get("npc_id", "")):
				"ryan":
					return _resolve_ryan_story_item_action(action)
				"mira":
					return _resolve_mira_story_item_action(action)
			return _action_result(false, "unsupported_npc")
		"give_product":
			return _resolve_ryan_product_action(action)
	return _action_result(false, "unsupported_action")


## 按当前路线写入 Ryan 结局（单一真相源：路线优先级只在 get_ryan_route 里定义）。
## 由 GameManager 在 Day 3 揭晓前调用；对话只读 ryan_ending，不再自行判定路线。
func finalize_ryan_ending() -> void:
	set_ending("ryan", get_ryan_route())


## 托比存活充要：Mira 担责（告知真相且信任达标）或玩家在掮客处兜底。
func toby_survived() -> bool:
	var told := bool(dialogue_vars.get("told_mira_truth", false))
	var contract_found := bool(dialogue_vars.get("toby_contract_found", false))
	var trust_ok := get_affection("mira") >= MIRA_TRUST_THRESHOLD
	var secured := bool(dialogue_vars.get("toby_secured_by_fixer", false)) \
		or bool(dialogue_vars.get("toby_secured", false))
	return (told and contract_found and trust_ok) or secured


## Mira 结局路线（单一真相源；对话只读 mira_ending，不自行判定）。
func get_mira_route() -> String:
	var told := bool(dialogue_vars.get("told_mira_truth", false))
	var contract_found := bool(dialogue_vars.get("toby_contract_found", false))
	var trust_ok := get_affection("mira") >= MIRA_TRUST_THRESHOLD
	var secured := bool(dialogue_vars.get("toby_secured_by_fixer", false)) \
		or bool(dialogue_vars.get("toby_secured", false))
	if told and contract_found and trust_ok:
		return "she_finally_stopped"
	if told:
		return "never_turned_back"
	if secured:
		return "closed_the_door"
	return "another_light_out"


## Day12 当晚上菜结算后由 GameManager 调用：定格 Mira 结局与托比 fate。
func finalize_mira_ending() -> void:
	set_ending("mira", get_mira_route())
	var survived := toby_survived()
	set_var("toby_survived", survived)
	set_ending("toby", "saved" if survived else "lost")


func get_ryan_route() -> String:
	if bool(dialogue_vars.get("ryan_has_alternative", false)):
		return "alternative_survivor"
	if bool(dialogue_vars.get("ryan_drugged", false)):
		return "drugged_survivor"
	if bool(dialogue_vars.get("ryan_informed", false)):
		return "informed_fallen"
	return "uninformed_fallen"


func _resolve_story_item_product_action(action: Dictionary) -> Dictionary:
	if String(action.get("item_key", "")) != "sleep_powder" \
		or String(action.get("product_key", "")) != "ale_beer":
		return _action_result(false, "unsupported_story_product")
	var result := _action_result(true, "sleep_powder_added")
	result["product_tags"] = ["sleep_powder"]
	return result


func _resolve_mira_story_item_action(action: Dictionary) -> Dictionary:
	match String(action.get("item_key", "")):
		"toby_contract":
			set_var("toby_contract_found", true)
			set_var("told_mira_truth", true)
			return _action_result(true, "mira_informed")
	return _action_result(false, "unsupported_story_item")


func _resolve_ryan_story_item_action(action: Dictionary) -> Dictionary:
	if String(action.get("npc_id", "")) != "ryan":
		return _action_result(false, "unsupported_npc")
	if bool(dialogue_vars.get("ryan_interaction_closed", false)):
		return _action_result(false, "ryan_interaction_closed", true)
	match String(action.get("item_key", "")):
		"bloodied_contract":
			set_var("ryan_informed", true)
			return _action_result(true, "ryan_informed")
		"alternative_contract":
			if not bool(dialogue_vars.get("ryan_informed", false)):
				return _action_result(false, "ryan_needs_warning_first")
			# 递交=提请；是否收下由当晚上菜手法在 resolve_pending_alternative 定夺。
			set_var("ryan_alternative_pending", true)
			return _action_result(true, "ryan_alternative_pending")
	return _action_result(false, "unsupported_story_item")


## 上菜手法定夺待定的替代委托：当晚上菜（风格已计入 aff_ryan）后由 GameManager 调用。
## 信任达标 → 收下替代委托（活路）；不足 → 婉拒，留在知情赴死。无待定项则空操作。
func resolve_pending_alternative(npc_id: String) -> Dictionary:
	if npc_id != "ryan":
		return {"resolved": false}
	if not bool(dialogue_vars.get("ryan_alternative_pending", false)):
		return {"resolved": false}
	set_var("ryan_alternative_pending", false)
	if get_affection("ryan") >= TRUST_THRESHOLD:
		set_var("ryan_has_alternative", true)
		set_var("ryan_interaction_closed", true)
		return {"resolved": true, "accepted": true}
	set_var("ryan_alternative_declined", true)
	set_var("ryan_interaction_closed", true)  # 婉拒亦为终局，封住后续重递
	return {"resolved": true, "accepted": false}


func _resolve_ryan_product_action(action: Dictionary) -> Dictionary:
	if String(action.get("npc_id", "")) != "ryan":
		return _action_result(false, "unsupported_npc")
	if bool(dialogue_vars.get("ryan_interaction_closed", false)):
		return _action_result(false, "ryan_interaction_closed", true)
	if String(action.get("product_key", "")) != "ale_beer":
		return _action_result(false, "unsupported_product")
	var product_tags: Array = action.get("product_tags", [])
	if not product_tags.has("sleep_powder"):
		return _action_result(true, "ryan_accepts_ale")
	if bool(dialogue_vars.get("ryan_informed", false)):
		return _action_result(false, "ryan_refuses_drugged_ale")
	set_var("ryan_drugged", true)
	set_var("ryan_interaction_closed", true)
	return _action_result(true, "ryan_drugged", true)


func _action_result(accepted: bool, feedback: String, interaction_closed: bool = false) -> Dictionary:
	return {
		"accepted": accepted,
		"feedback": feedback,
		"interaction_closed": interaction_closed,
	}


func load_npc_data() -> void:
	dialogue_vars["has_sleep_powder"] = false
	dialogue_vars["ryan_informed"] = false
	dialogue_vars["ryan_warhammer_lead"] = false
	dialogue_vars["ryan_has_alternative"] = false
	dialogue_vars["ryan_drugged"] = false
	dialogue_vars["ryan_interaction_closed"] = false
	dialogue_vars["ryan_alternative_pending"] = false
	dialogue_vars["ryan_alternative_declined"] = false
	dialogue_vars["ryan_ending"] = ""
	dialogue_vars["merchant_sleep_powder_hint_seen"] = false
	dialogue_vars["aff_ryan"] = 0
	dialogue_vars["aff_mira"] = 5
	dialogue_vars["told_mira_truth"] = false
	dialogue_vars["toby_danger_known"] = false
	dialogue_vars["toby_contract_found"] = false
	dialogue_vars["mira_contract_aftershock_seen"] = false
	dialogue_vars["toby_secured"] = false
	dialogue_vars["toby_secured_by_fixer"] = false
	dialogue_vars["toby_survived"] = false
	dialogue_vars["mira_ending"] = ""
	dialogue_vars["aff_toby"] = 0

	var file = FileAccess.open("res://data/npcs.json", FileAccess.READ)
	if file == null:
		print("[Narrative] npcs.json 未找到，使用默认变量")
		return
	var json_text = file.get_as_text()
	file.close()
	var root = JSON.parse_string(json_text)
	if root == null or not root is Dictionary:
		printerr("[Narrative] JSON 解析失败")
		return
	var npcs_array: Array = root["npcs"]
	for npc_dict in npcs_array:
		var npc = NpcData.new()
		npc.id = npc_dict["id"]
		npc.npc_name = npc_dict["name"]
		npc.title = npc_dict["title"]
		npc.description = npc_dict["description"]
		npc.affection_start = int(npc_dict["affectionStart"])
		npc.scenes = _parse_scenes(npc_dict["scenes"])
		npc.endings = _parse_endings(npc_dict["endings"])
		if npc_dict.has("preferred_styles"):
			for s in npc_dict["preferred_styles"]:
				npc.preferred_styles.append(s)
		if npc_dict.has("disliked_styles"):
			for s in npc_dict["disliked_styles"]:
				npc.disliked_styles.append(s)
		all_npcs.append(npc)
		set_affection(npc.id, npc.affection_start)
	print("[Narrative] 加载 ", all_npcs.size(), " 个 NPC")

func _parse_scenes(scenes_array: Array) -> Array[NpcSceneData]:
	var result: Array[NpcSceneData] = []
	for scene_dict in scenes_array:
		var scene = NpcSceneData.new()
		scene.day = int(scene_dict["day"])
		scene.dialogue = scene_dict["dialogue"]
		scene.order = scene_dict["order"]
		scene.trigger = scene_dict["trigger"]
		if scene_dict.has("variables"):
			scene.variables = [] as Array[String]
			for v in scene_dict["variables"]:
				scene.variables.append(v)
		result.append(scene)
	return result

func _parse_endings(endings_dict: Dictionary) -> Dictionary:
	return endings_dict

func get_today_scenes(day: int) -> Array[NpcData]:
	var result: Array[NpcData] = []
	for npc in all_npcs:
		for scene in npc.scenes:
			if scene.day == day:
				if _check_trigger(scene.trigger, npc.id):
					result.append(npc)
				break
	return result

func select_today_important_npc(day: int) -> String:
	today_important_npc = ""
	var scenes := get_today_scenes(day)
	if scenes.size() > 0:
		today_important_npc = scenes[0].id
	return today_important_npc

func _check_trigger(trigger, npc_id: String) -> bool:
	# 新格式: {"type": "auto"}
	if trigger is Dictionary and trigger.get("type") == "auto":
		return true
	# 新格式: {"type": "affection", "threshold": N}
	if trigger is Dictionary and trigger.get("type") == "affection":
		var threshold: int = trigger.get("threshold", 0)
		return get_affection(npc_id) >= threshold
	# 兼容旧格式: "auto"
	if trigger is String and trigger == "auto":
		return true
	# 兼容旧格式: "affection >= N"
	if trigger is String and trigger.begins_with("affection"):
		var parts = trigger.split(">=")
		if parts.size() == 2:
			var threshold: int = int(parts[1].strip_edges())
			return get_affection(npc_id) >= threshold
	return false

func get_today_npc_fates(day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for npc in all_npcs:
		for scene in npc.scenes:
			if scene.day == day:
				_append_npc_fate(result, npc)
				break
	for npc_id in LINKED_FATE_DAYS.get(day, []):
		if _fate_result_has_npc(result, String(npc_id)):
			continue
		var linked_npc := _find_npc(String(npc_id))
		if linked_npc != null:
			_append_npc_fate(result, linked_npc)
	return result

func _append_npc_fate(result: Array[Dictionary], npc: NpcData) -> void:
	var ending_var: String = npc.id + "_ending"
	if not dialogue_vars.has(ending_var):
		return
	var raw_ending = dialogue_vars.get(ending_var, "")
	if raw_ending == null:
		return
	var ending_key: String = String(raw_ending)
	if ending_key == "" or not npc.endings.has(ending_key):
		return
	result.append({
		"npc_id": npc.id,
		"ending_key": ending_key,
		"npc_name": npc.npc_name,
		"npc_title": npc.title,
		"fate_text": npc.endings[ending_key]
	})

func _fate_result_has_npc(result: Array[Dictionary], npc_id: String) -> bool:
	for fate in result:
		if String(fate.get("npc_id", "")) == npc_id:
			return true
	return false

func _find_npc(npc_id: String) -> NpcData:
	for n in all_npcs:
		if n.id == npc_id:
			return n
	return null

## L3 信任阀门。分类已由 CraftStyleSystem 完成；memory_story_key 由 GameManager 经
## CraftSystem.get_memory_for 查出（L2 信号，空串=该配方对此 NPC 无记忆）。
## 仅在订单正确(成功上菜)时由 GameManager 调用。
## 副作用：写对话变量 serve_style / story_told / story_key，应用信任增减。
func resolve_serve_style(npc_id: String, memory_story_key: String, serve_style: String) -> Dictionary:
	var npc := _find_npc(npc_id)
	var preferred: Array = npc.preferred_styles if npc != null else []
	var disliked: Array = npc.disliked_styles if npc != null else []

	var l2_wants: bool = memory_story_key != ""
	var l3_willing: bool = preferred.has(serve_style)
	var l3_dislike: bool = disliked.has(serve_style)
	var story_told: bool = l2_wants and l3_willing

	var delta: int = 0
	if l3_willing:
		delta = 2
	elif l3_dislike:
		delta = -2
	if delta != 0:
		set_affection(npc_id, get_affection(npc_id) + delta)

	set_var("serve_style", serve_style)
	set_var("story_told", story_told)
	set_var("story_key", memory_story_key if story_told else "")

	return {
		"serve_style": serve_style,
		"story_told": story_told,
		"story_key": memory_story_key if story_told else "",
		"affection_delta": delta,
	}
