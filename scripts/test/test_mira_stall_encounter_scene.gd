extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_scene_contract()
	_test_dialogue_has_no_player_responses()
	_finish()


func _test_scene_contract() -> void:
	var scene: PackedScene = load("res://scenes/ui/MiraStallEncounter.tscn")
	_ok(scene != null, "Mira stall encounter scene loads")
	if scene == null:
		return
	var encounter = scene.instantiate()
	encounter.auto_start_dialogue = false
	add_child(encounter)
	await get_tree().process_frame
	_ok(encounter.has_signal("finished"), "Mira stall encounter exposes finished signal")
	var background := encounter.get_node_or_null("BackgroundArt") as Sprite2D
	_ok(background != null, "Mira stall encounter has BackgroundArt Sprite2D")
	_ok(background != null and background.texture != null, "Mira stall encounter background texture is assigned")
	var portrait := encounter.get_node_or_null("MiraPortrait") as Sprite2D
	_ok(portrait != null, "Mira stall encounter has MiraPortrait Sprite2D")
	_ok(portrait != null and portrait.texture != null, "Mira stall encounter portrait texture is assigned")
	if portrait != null and portrait.texture != null:
		_ok(portrait.texture.resource_path == "res://assets/textures/characters/mira_neutral.png",
			"Mira stall encounter defaults to Mira neutral portrait")
	if background != null and portrait != null:
		_ok(portrait.z_index > background.z_index, "Mira portrait renders in front of background art")
	if portrait != null and encounter.has_method("_apply_mira_portrait_expression_for_state"):
		encounter.call("_apply_mira_portrait_expression_for_state", "after_truth_trusted")
		_ok(portrait.texture != null and portrait.texture.resource_path == "res://assets/textures/characters/mira_resolved.png",
			"Mira stall trusted truth state uses resolved portrait")
		encounter.call("_apply_mira_portrait_expression_for_state", "after_truth_guarded")
		_ok(portrait.texture != null and portrait.texture.resource_path == "res://assets/textures/characters/mira_detached.png",
			"Mira stall guarded truth state uses detached portrait")
	else:
		_ok(false, "Mira stall encounter exposes portrait expression application")
	_ok(_count_buttons(encounter) == 0, "Mira stall encounter scene exposes no player dialogue buttons")
	encounter.queue_free()


func _test_dialogue_has_no_player_responses() -> void:
	var text := FileAccess.get_file_as_string("res://dialogue/mira_stall_encounter.dialogue")
	_ok(text.begins_with("~ start"), "Mira stall dialogue has a start title")
	_ok(not text.contains("\n- "), "Mira stall dialogue contains no response choices")
	_ok(text.contains("mira_stall_encounter_state"), "Mira stall dialogue branches on encounter state")


func _count_buttons(node: Node) -> int:
	var count := 0
	if node is Button:
		count += 1
	for child in node.get_children():
		count += _count_buttons(child)
	return count


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MIRA-STALL-SCENE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MIRA-STALL-SCENE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MIRA-STALL-SCENE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
