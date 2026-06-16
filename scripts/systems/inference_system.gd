class_name InferenceSystem
extends RefCounted

const DEFAULT_PATH := "res://data/inference_puzzles.json"

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
	return clue


func get_owned_clues() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for clue_id in _clues.keys():
		if has_clue(String(clue_id)):
			result.append(get_clue(String(clue_id)))
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
	var expected := String(blanks.get(blank_id, ""))
	if clue_id != expected:
		return _placement_result(false, false, question_id, blank_id, clue_id, String(question.get("hint", "")))

	var placed: Dictionary = (_placements.get(question_id, {}) as Dictionary).duplicate(true)
	placed[blank_id] = clue_id
	_placements[question_id] = placed
	var solved := _is_question_solved(question, placed)
	var result := _placement_result(true, solved, question_id, blank_id, clue_id, "")
	if solved:
		_solved[question_id] = true
		result["conclusion"] = String(question.get("conclusion", ""))
		result["unlockFlags"] = (question.get("unlockFlags", []) as Array).duplicate()
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


func _is_question_solved(question: Dictionary, placed: Dictionary) -> bool:
	var blanks: Dictionary = question.get("blanks", {})
	for blank_id in blanks.keys():
		if String(placed.get(String(blank_id), "")) != String(blanks[blank_id]):
			return false
	return true


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
	}
