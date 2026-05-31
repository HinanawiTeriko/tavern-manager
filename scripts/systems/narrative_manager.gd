class_name NarrativeManager
extends RefCounted

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
			return _resolve_ryan_story_item_action(action)
		"give_product":
			return _resolve_ryan_product_action(action)
	return _action_result(false, "unsupported_action")


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
			set_var("ryan_has_alternative", true)
			set_var("ryan_interaction_closed", true)
			return _action_result(true, "ryan_accepts_alternative", true)
	return _action_result(false, "unsupported_story_item")


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
	dialogue_vars["ryan_has_alternative"] = false
	dialogue_vars["ryan_drugged"] = false
	dialogue_vars["ryan_interaction_closed"] = false
	dialogue_vars["ryan_ending"] = ""
	dialogue_vars["aff_ryan"] = 0
	dialogue_vars["aff_mira"] = 5

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
				var ending_var: String = npc.id + "_ending"
				if dialogue_vars.has(ending_var):
					var ending_key: String = dialogue_vars[ending_var]
					if ending_key != null and ending_key != "" and npc.endings.has(ending_key):
						result.append({
							"npc_name": npc.npc_name,
							"npc_title": npc.title,
							"fate_text": npc.endings[ending_key]
						})
				break
	return result

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
