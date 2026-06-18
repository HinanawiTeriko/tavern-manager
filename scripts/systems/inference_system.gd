class_name InferenceSystem
extends RefCounted

const DEFAULT_PATH := "res://data/inference_puzzles.json"
const SOURCE_LABELS := {
	"wind": "风声",
	"heart": "人心",
	"evidence": "证据",
	"fact": "事实",
	"cost": "代价",
	"consequence": "后果",
}
const CLUE_SOURCE_TYPES := {
	"toby_name": "wind",
	"blacktooth_escort": "wind",
	"high_pay_trap": "wind",
	"back_alley_boy": "heart",
	"one_person_walk": "heart",
	"mira_traveling_mentor": "wind",
	"child_learned_saying": "wind",
	"mira_avoids_old_road": "heart",
	"grey_ryan_case_number": "evidence",
	"grey_old_payout_register": "evidence",
	"grey_missing_page": "evidence",
	"grey_blacktooth_batch": "evidence",
	"grey_closure_method": "evidence",
	"grey_payout_closure": "evidence",
	"grey_renamed_escort": "evidence",
	"grey_supply_stamp": "evidence",
}

var _clues: Dictionary = {}
var _questions: Array[Dictionary] = []
var _owned_clues: Dictionary = {}
var _placements: Dictionary = {}
var _solved: Dictionary = {}


func load_data(path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[InferenceSystem] cannot load data: " + path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("[InferenceSystem] invalid data: " + path)
		return false
	_clues = (parsed.get("clues", {}) as Dictionary).duplicate(true)
	_questions.clear()
	for question in parsed.get("questions", []):
		if question is Dictionary:
			_questions.append((question as Dictionary).duplicate(true))
	return true


func add_clue(clue_id: String) -> bool:
	if clue_id == "" or not _clues.has(clue_id):
		return false
	var was_new := not bool(_owned_clues.get(clue_id, false))
	_owned_clues[clue_id] = true
	return was_new


func add_clues(clue_ids: Array) -> bool:
	var changed := false
	for clue_id in clue_ids:
		changed = add_clue(String(clue_id)) or changed
	return changed


func has_clue(clue_id: String) -> bool:
	return bool(_owned_clues.get(clue_id, false))


func get_clue(clue_id: String) -> Dictionary:
	if not _clues.has(clue_id):
		return {}
	var clue := (_clues[clue_id] as Dictionary).duplicate(true)
	clue["id"] = clue_id
	var source_type := source_type_for_clue(clue_id, clue)
	clue["sourceType"] = source_type
	clue["sourceLabel"] = source_label_for_type(source_type)
	return clue


func source_type_for_clue(clue_id: String, clue: Dictionary = {}) -> String:
	var explicit := String(clue.get("sourceType", "")).strip_edges()
	if explicit != "":
		return _normalized_source_type(explicit)
	return _normalized_source_type(String(CLUE_SOURCE_TYPES.get(clue_id, "wind")))


func source_label_for_type(source_type: String) -> String:
	return String(SOURCE_LABELS.get(_normalized_source_type(source_type), "线索"))


func source_note(source_type: String, text: String) -> String:
	var clean := text.strip_edges()
	if clean == "":
		return ""
	return "%s · %s" % [source_label_for_type(source_type), clean]


func get_owned_clues() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for clue_id in _clues.keys():
		if has_clue(String(clue_id)):
			result.append(get_clue(String(clue_id)))
	return result


func get_relevant_owned_clues() -> Array[Dictionary]:
	var fillable_clues := _unsolved_fillable_clue_ids()
	var result: Array[Dictionary] = []
	for clue_id in _clues.keys():
		var normalized_id := String(clue_id)
		if has_clue(normalized_id) and bool(fillable_clues.get(normalized_id, false)):
			result.append(get_clue(normalized_id))
	return result


func get_question(question_id: String) -> Dictionary:
	for question in _questions:
		if String(question.get("id", "")) == question_id:
			var copy := question.duplicate(true)
			copy["placements"] = (_placements.get(question_id, {}) as Dictionary).duplicate(true)
			copy["solved"] = bool(_solved.get(question_id, false))
			return copy
	return {}


func get_available_questions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for question in _questions:
		var question_id := String(question.get("id", ""))
		if bool(_solved.get(question_id, false)):
			continue
		if _requirements_met(question):
			result.append(get_question(question_id))
	return result


func has_available_questions() -> bool:
	return not get_available_questions().is_empty()


func try_place(question_id: String, blank_id: String, clue_id: String) -> Dictionary:
	var question := get_question(question_id)
	if question.is_empty():
		return _placement_result(false, false, question_id, blank_id, clue_id, "这句还没有出现。")
	if bool(question.get("solved", false)):
		return _placement_result(false, true, question_id, blank_id, clue_id, "这句已经写完了。")
	if not _requirements_met(question):
		return _placement_result(false, false, question_id, blank_id, clue_id, "线索还不够。")
	if not has_clue(clue_id):
		return _placement_result(false, false, question_id, blank_id, clue_id, "这张纸还没拿到。")
	var blanks: Dictionary = question.get("blanks", {})
	if not blanks.has(blank_id):
		return _placement_result(false, false, question_id, blank_id, clue_id, "这不是这句话的空位。")
	var placed: Dictionary = (_placements.get(question_id, {}) as Dictionary).duplicate(true)
	if not _clue_matches_blank(question, placed, blank_id, clue_id):
		return _placement_result(false, false, question_id, blank_id, clue_id, String(question.get("hint", "")))
	placed[blank_id] = clue_id
	_placements[question_id] = placed
	var solved := _is_question_solved(question, placed)
	var result := _placement_result(true, solved, question_id, blank_id, clue_id, "")
	if solved:
		_solved[question_id] = true
		result["conclusion"] = String(question.get("conclusion", ""))
		result["unlockFlags"] = (question.get("unlockFlags", []) as Array).duplicate()
		result["sourceType"] = "fact"
		result["sourceLabel"] = source_label_for_type("fact")
	result["placements"] = placed.duplicate(true)
	return result


func capture_state() -> Dictionary:
	var clues: Array[String] = []
	for clue_id in _owned_clues.keys():
		if bool(_owned_clues[clue_id]):
			clues.append(String(clue_id))
	var solved_ids: Array[String] = []
	for question_id in _solved.keys():
		if bool(_solved[question_id]):
			solved_ids.append(String(question_id))
	return {
		"owned_clues": clues,
		"placements": _placements.duplicate(true),
		"solved": solved_ids,
	}


func restore_state(data: Dictionary) -> void:
	_owned_clues.clear()
	for clue_id in data.get("owned_clues", []):
		add_clue(String(clue_id))
	_placements = (data.get("placements", {}) as Dictionary).duplicate(true)
	_solved.clear()
	for question_id in data.get("solved", []):
		_solved[String(question_id)] = true


func _requirements_met(question: Dictionary) -> bool:
	for clue_id in question.get("requiresClues", []):
		if not has_clue(String(clue_id)):
			return false
	for question_id in question.get("requiresSolved", []):
		if not bool(_solved.get(String(question_id), false)):
			return false
	return true


func _unsolved_fillable_clue_ids() -> Dictionary:
	var result := {}
	for question in _questions:
		var question_id := String(question.get("id", ""))
		if bool(_solved.get(question_id, false)):
			continue
		var blanks: Dictionary = question.get("blanks", {})
		for clue_id in blanks.values():
			result[String(clue_id)] = true
	return result


func _clue_matches_blank(question: Dictionary, placed: Dictionary, blank_id: String, clue_id: String) -> bool:
	var unordered_group := _unordered_group_for_blank(question, blank_id)
	if unordered_group.is_empty():
		var blanks: Dictionary = question.get("blanks", {})
		return clue_id == String(blanks.get(blank_id, ""))
	var accepted_clues := _expected_clues_for_blanks(question, unordered_group)
	if not accepted_clues.has(clue_id):
		return false
	for other_blank in unordered_group:
		var other_blank_id := String(other_blank)
		if other_blank_id != blank_id and String(placed.get(other_blank_id, "")) == clue_id:
			return false
	return true


func _is_question_solved(question: Dictionary, placed: Dictionary) -> bool:
	var blanks: Dictionary = question.get("blanks", {})
	var checked := {}
	for group in _unordered_blank_groups(question):
		var expected_clues := _expected_clues_for_blanks(question, group)
		var placed_clues: Array[String] = []
		for blank_id_value in group:
			var blank_id := String(blank_id_value)
			if not blanks.has(blank_id):
				return false
			var placed_clue := String(placed.get(blank_id, ""))
			if placed_clue == "":
				return false
			placed_clues.append(placed_clue)
			checked[blank_id] = true
		expected_clues.sort()
		placed_clues.sort()
		if expected_clues != placed_clues:
			return false
	for blank_id in blanks.keys():
		if bool(checked.get(String(blank_id), false)):
			continue
		if String(placed.get(String(blank_id), "")) != String(blanks[blank_id]):
			return false
	return true


func _unordered_blank_groups(question: Dictionary) -> Array:
	var result: Array = []
	for raw_group in question.get("unorderedBlankGroups", []):
		if not raw_group is Array:
			continue
		var group: Array[String] = []
		for blank_id in raw_group:
			var normalized_id := String(blank_id)
			if normalized_id != "":
				group.append(normalized_id)
		if group.size() > 1:
			result.append(group)
	return result


func _unordered_group_for_blank(question: Dictionary, blank_id: String) -> Array:
	for raw_group in _unordered_blank_groups(question):
		var group: Array = raw_group
		if group.has(blank_id):
			return group.duplicate()
	return []


func _expected_clues_for_blanks(question: Dictionary, blank_ids: Array) -> Array[String]:
	var blanks: Dictionary = question.get("blanks", {})
	var result: Array[String] = []
	for blank_id_value in blank_ids:
		var blank_id := String(blank_id_value)
		if blanks.has(blank_id):
			result.append(String(blanks[blank_id]))
	return result


func _placement_result(accepted: bool, solved: bool, question_id: String, blank_id: String, clue_id: String, hint: String) -> Dictionary:
	return {
		"accepted": accepted,
		"solved": solved,
		"questionId": question_id,
		"blankId": blank_id,
		"clueId": clue_id,
		"hint": hint,
		"conclusion": "",
		"unlockFlags": [],
		"sourceType": "",
		"sourceLabel": "",
	}


func _normalized_source_type(source_type: String) -> String:
	var normalized := source_type.strip_edges().to_lower()
	if SOURCE_LABELS.has(normalized):
		return normalized
	return "wind"
