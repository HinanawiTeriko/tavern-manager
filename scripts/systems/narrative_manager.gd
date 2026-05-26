class_name NarrativeManager
extends RefCounted

var all_npcs: Array = []
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

func load_npc_data() -> void:
	dialogue_vars["has_sleep_powder"] = false
	dialogue_vars["ryan_drugged"] = false
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
		all_npcs.append(npc)
		set_affection(npc.id, npc.affection_start)
	print("[Narrative] 加载 ", all_npcs.size(), " 个 NPC")

func _parse_scenes(scenes_array: Array) -> Array[NpcSceneData]:
	var result: Array = []
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

func get_today_scenes(day: int) -> Array:
	var result: Array = []
	for npc in all_npcs:
		for scene in npc.scenes:
			if scene.day == day:
				if scene.trigger == "auto":
					result.append(npc)
				elif scene.trigger.begins_with("affection"):
					var parts = scene.trigger.split(">=")
					if parts.size() == 2:
						var threshold: int = int(parts[1].strip_edges())
						if get_affection(npc.id) >= threshold:
							result.append(npc)
				break
	return result

func get_today_npc_fates(day: int) -> Array:
	var result: Array = []
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
