extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_mira_expression_textures_exist()
	await _test_tavern_switches_mira_expression_portraits()
	await _test_mira_day4_entry_tolerates_missing_story_vars()
	await _test_tavern_uses_mira_portrait()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MIRA-BUST] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MIRA-BUST] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MIRA-BUST] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return String(texture.resource_path)


func _test_tavern_uses_mira_portrait() -> void:
	_ok(FileAccess.file_exists("res://assets/textures/characters/mira_neutral.png"),
		"Mira runtime portrait exists")

	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	tavern.show_customer("Mira", "wine", "mira")
	var sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	_ok(sprite != null, "Tavern keeps CustomerSprite")
	if sprite != null:
		_ok(_texture_path(sprite.texture) == "res://assets/textures/characters/mira_neutral.png",
			"Tavern resolves mira npc_id to Mira runtime portrait")
		_ok(sprite.texture != null and sprite.texture.get_size() == Vector2(512, 640),
			"Mira runtime portrait uses the official 512x640 character pipeline")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Mira portrait renders with nearest filtering")

	tavern.queue_free()


func _test_mira_expression_textures_exist() -> void:
	for portrait_id in [
		"mira_neutral",
		"mira_smile",
		"mira_surprised",
		"mira_serious",
		"mira_guilty",
		"mira_conflicted",
		"mira_resolved",
		"mira_detached",
	]:
		var path := "res://assets/textures/characters/%s.png" % portrait_id
		_ok(FileAccess.file_exists(path), portrait_id + " runtime portrait exists")
		var texture := load(path) as Texture2D
		_ok(texture != null, portrait_id + " runtime portrait loads as Texture2D")
		if texture != null:
			_ok(texture.get_size() == Vector2(512, 640), portrait_id + " runtime portrait uses official 512x640")


func _test_tavern_switches_mira_expression_portraits() -> void:
	var gm = get_node("/root/GameManager")
	var old_day: int = gm.economy.current_day
	gm.narrative.set_var("told_mira_truth", false)
	gm.narrative.set_var("mira_ending", "")
	gm.narrative.set_affection("mira", 5)

	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	gm.economy.current_day = 4
	tavern.show_customer("Mira", "wine", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_neutral.png"), "Mira Day4 entry uses neutral portrait")
	tavern.show_customer_reaction("success", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_smile.png"), "Mira correct Day4 serve switches to smile")
	tavern.show_customer_reaction("fail_wrong", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_serious.png"), "Mira failed serve switches to serious")

	gm.economy.current_day = 12
	gm.narrative.set_var("told_mira_truth", false)
	gm.narrative.set_var("mira_ending", "")
	tavern.show_customer("Mira", "spiced_wine", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_detached.png"), "Mira Day12 entry uses detached portrait")
	gm.narrative.set_var("told_mira_truth", true)
	tavern.show_customer("Mira", "spiced_wine", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_guilty.png"), "Mira told truth state uses guilty portrait before ending")
	gm.narrative.set_affection("mira", gm.narrative.MIRA_TRUST_THRESHOLD - 1)
	tavern.show_customer_reaction("success", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_conflicted.png"), "Mira told truth with low trust uses conflicted portrait")
	gm.narrative.set_affection("mira", gm.narrative.MIRA_TRUST_THRESHOLD)
	tavern.show_customer_reaction("success", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_resolved.png"), "Mira told truth with enough trust uses resolved portrait")

	gm.narrative.set_var("mira_ending", "never_turned_back")
	tavern.show_customer_reaction("success", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_detached.png"), "Mira never turned back ending uses detached portrait")
	gm.narrative.set_var("mira_ending", "closed_the_door")
	tavern.show_customer_reaction("success", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_smile.png"), "Mira unaware safe-contract ending uses smile portrait")
	gm.narrative.set_var("mira_ending", "she_finally_stopped")
	tavern.show_customer_reaction("success", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_resolved.png"), "Mira accountability ending uses resolved portrait")

	gm.economy.current_day = 12
	gm.narrative.set_var("told_mira_truth", false)
	gm.narrative.set_var("mira_ending", "")
	gm.guests.clear_guest()
	gm.grant_investigation_document("toby_contract")
	gm.guests.spawn_important("mira", "spiced_wine")
	await get_tree().process_frame
	_ok(_portrait_path(tavern).ends_with("/mira_detached.png"), "Mira active Day12 guest starts detached")
	gm.request_narrative_delivery("toby_contract")
	await get_tree().process_frame
	_ok(_portrait_path(tavern).ends_with("/mira_guilty.png"), "Giving Toby contract to active Mira switches to guilty portrait")
	var overlay := tavern.get_node_or_null("DocumentOverlay") as DocumentOverlay
	_ok(overlay != null and overlay.visible, "Giving Toby contract to Mira opens the completed contract document")
	if overlay != null:
		var art := overlay.get_node_or_null("DocumentArt") as TextureRect
		_ok(art != null and art.visible,
			"Giving Toby contract to Mira shows the completed contract document art")

	gm.economy.current_day = old_day
	gm.guests.clear_guest()
	tavern.queue_free()


func _test_mira_day4_entry_tolerates_missing_story_vars() -> void:
	var gm = get_node("/root/GameManager")
	var old_day: int = gm.economy.current_day
	var old_vars: Dictionary = gm.narrative.dialogue_vars.duplicate(true)
	gm.economy.current_day = 4
	gm.narrative.dialogue_vars.erase("told_mira_truth")
	gm.narrative.dialogue_vars.erase("mira_ending")
	gm.narrative.dialogue_vars.erase("toby_secured")

	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	tavern.show_customer("Mira", "wine", "mira")
	_ok(_portrait_path(tavern).ends_with("/mira_neutral.png"),
		"Mira Day4 entry tolerates old saves missing Mira story vars")

	gm.economy.current_day = old_day
	gm.narrative.dialogue_vars = old_vars
	tavern.queue_free()


func _portrait_path(tavern: Node) -> String:
	var sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	if sprite == null or sprite.texture == null:
		return ""
	return sprite.texture.resource_path
