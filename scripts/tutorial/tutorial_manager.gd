extends Node

signal tutorial_step_started(step_id: String)
signal tutorial_step_completed(step_id: String)
signal tutorial_sequence_ended(group_id: String)

const SAVE_PATH: String = "user://tutorial_state.save"

var _steps: Dictionary = {}
var _completed_steps: Array = []
var _current_sequence: Array = []
var _current_step: int = -1
var _is_active: bool = false
var _overlay: Node = null

# Trigger flags
var daymap_first_shown: bool = false
var tavern_first_entered: bool = false
var first_menu_prep_shown: bool = false
var shop_first_visited: bool = false
var first_guest_arrived: bool = false
var first_product_seasoned: bool = false
var first_guest_served: bool = false
var first_ledger_shown: bool = false
var first_inference_shown: bool = false


func _ready() -> void:
	# 不加载持久化状态，每次重启游戏都重新开始教程
	_load_steps()


func _load_steps() -> void:
	var file = FileAccess.open("res://data/tutorial_steps.json", FileAccess.READ)
	if file == null:
		printerr("[TutorialManager] 无法加载教程步骤数据")
		return
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data is Dictionary:
		_steps = data


func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data is Dictionary:
		_completed_steps = data.get("completed_steps", [])
		daymap_first_shown = data.get("daymap_first_shown", false)
		tavern_first_entered = data.get("tavern_first_entered", false)
		first_menu_prep_shown = data.get("first_menu_prep_shown", false)
		shop_first_visited = data.get("shop_first_visited", false)
		first_guest_arrived = data.get("first_guest_arrived", false)
		first_product_seasoned = data.get("first_product_seasoned", false)
		first_guest_served = data.get("first_guest_served", false)
		first_ledger_shown = data.get("first_ledger_shown", false)
		first_inference_shown = data.get("first_inference_shown", false)


func _save_state() -> void:
	var data = {
		"completed_steps": _completed_steps,
		"daymap_first_shown": daymap_first_shown,
		"tavern_first_entered": tavern_first_entered,
		"first_menu_prep_shown": first_menu_prep_shown,
		"shop_first_visited": shop_first_visited,
		"first_guest_arrived": first_guest_arrived,
		"first_product_seasoned": first_product_seasoned,
		"first_guest_served": first_guest_served,
		"first_ledger_shown": first_ledger_shown,
		"first_inference_shown": first_inference_shown,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()


func _spawn_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	var overlay_script = load("res://scripts/tutorial/tutorial_overlay.gd")
	if overlay_script == null:
		printerr("[TutorialManager] 无法加载 TutorialOverlay 脚本")
		return
	_overlay = overlay_script.new()
	get_tree().root.add_child(_overlay)


func _remove_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func start_tutorial(group_key: String, highlight_rects: Dictionary = {}) -> void:
	if _is_active:
		return

	if not _steps.has(group_key):
		return

	var steps_data = _steps[group_key]
	if steps_data.size() == 0:
		return

	# Check if all steps already completed
	var all_done = true
	for step in steps_data:
		if not _completed_steps.has(step["id"]):
			all_done = false
			break

	if all_done:
		return

	_current_sequence = steps_data.duplicate(true)
	_current_step = -1
	_is_active = true

	_spawn_overlay()
	_show_next_step(highlight_rects)


func _show_next_step(highlight_rects: Dictionary = {}) -> void:
	_current_step += 1
	if _current_step >= _current_sequence.size():
		_finish_sequence()
		return

	# Skip already completed steps
	while _current_step < _current_sequence.size():
		var step = _current_sequence[_current_step]
		if not _completed_steps.has(step["id"]):
			break
		_current_step += 1

	if _current_step >= _current_sequence.size():
		_finish_sequence()
		return

	var step = _current_sequence[_current_step]
	tutorial_step_started.emit(step["id"])

	if _overlay != null and is_instance_valid(_overlay) and _overlay.has_method("show_step"):
		var rect = highlight_rects.get(step.get("highlight_node", ""), step.get("highlight_rect", [0, 0, 0, 0]))
		var has_next = _current_step < _current_sequence.size() - 1
		var has_prev = _current_step > 0
		_overlay.show_step(step, rect, has_prev, has_next)


func next_step() -> void:
	if not _is_active:
		return

	if _current_step >= 0 and _current_step < _current_sequence.size():
		var step = _current_sequence[_current_step]
		if not _completed_steps.has(step["id"]):
			_completed_steps.append(step["id"])
		tutorial_step_completed.emit(step["id"])

	_show_next_step()


func skip_tutorial() -> void:
	if not _is_active:
		return

	for i in range(_current_step, _current_sequence.size()):
		var step = _current_sequence[i]
		if not _completed_steps.has(step["id"]):
			_completed_steps.append(step["id"])

	_finish_sequence()


func _finish_sequence() -> void:
	var group_id = ""
	if _current_sequence.size() > 0:
		group_id = _current_sequence[0].get("group", "")

	_is_active = false
	_current_step = -1
	_current_sequence.clear()
	_save_state()
	_remove_overlay()

	tutorial_sequence_ended.emit(group_id)


func is_step_completed(step_id: String) -> bool:
	return _completed_steps.has(step_id)


func is_group_completed(group_key: String) -> bool:
	if not _steps.has(group_key):
		return true
	for step in _steps[group_key]:
		if not _completed_steps.has(step["id"]):
			return false
	return true


func replay_all() -> void:
	# 如果当前有活跃教程，先关闭
	if _is_active:
		_current_sequence.clear()
		_current_step = -1
		_is_active = false
		_remove_overlay()

	_completed_steps.clear()
	daymap_first_shown = false
	tavern_first_entered = false
	first_menu_prep_shown = false
	shop_first_visited = false
	first_guest_arrived = false
	first_product_seasoned = false
	first_guest_served = false
	first_ledger_shown = false
	first_inference_shown = false
	_save_state()


func replay_group(group_key: String) -> void:
	if not _steps.has(group_key):
		return
	for step in _steps[group_key]:
		_completed_steps.erase(step["id"])
	_save_state()


func has_any_tutorial() -> bool:
	for group_key in _steps:
		if not is_group_completed(group_key):
			return true
	return false
