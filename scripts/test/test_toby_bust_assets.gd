extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_toby_expression_textures_exist()
	await _test_tavern_uses_toby_portrait()
	await _test_tavern_switches_toby_serve_expression_portraits()
	await _test_toby_story_state_uses_afraid_portrait()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TOBY-BUST] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TOBY-BUST] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TOBY-BUST] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return String(texture.resource_path)


func _test_tavern_uses_toby_portrait() -> void:
	_ok(FileAccess.file_exists("res://assets/textures/characters/toby_neutral.png"),
		"Toby runtime portrait exists")

	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	tavern.show_customer("Toby", "herb_broth", "toby")
	var sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	_ok(sprite != null, "Tavern keeps CustomerSprite")
	if sprite != null:
		_ok(_texture_path(sprite.texture) == "res://assets/textures/characters/toby_neutral.png",
			"Tavern resolves toby npc_id to Toby runtime portrait")
		_ok(sprite.texture != null and sprite.texture.get_size() == Vector2(512, 640),
			"Toby runtime portrait uses the official 512x640 character pipeline")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Toby portrait renders with nearest filtering")

	tavern.queue_free()


func _test_toby_expression_textures_exist() -> void:
	for portrait_id in [
		"toby_neutral",
		"toby_warmed",
		"toby_hurt",
		"toby_afraid",
	]:
		var path := "res://assets/textures/characters/%s.png" % portrait_id
		_ok(FileAccess.file_exists(path), portrait_id + " runtime portrait exists")
		var texture := load(path) as Texture2D
		_ok(texture != null, portrait_id + " runtime portrait loads as Texture2D")
		if texture != null:
			_ok(texture.get_size() == Vector2(512, 640), portrait_id + " runtime portrait uses official 512x640")


func _test_tavern_switches_toby_serve_expression_portraits() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	tavern.show_customer("Toby", "herb_broth", "toby")
	_ok(_portrait_path(tavern).ends_with("/toby_neutral.png"), "Toby entry uses neutral portrait")
	tavern.show_customer_reaction("success", "toby")
	_ok(_portrait_path(tavern).ends_with("/toby_warmed.png"), "Toby correct serve switches to warmed portrait")

	tavern.show_customer("Toby", "herb_broth", "toby")
	tavern.show_customer_reaction("fail_wrong", "toby")
	_ok(_portrait_path(tavern).ends_with("/toby_hurt.png"), "Toby wrong product switches to hurt portrait")

	tavern.show_customer("Toby", "herb_broth", "toby")
	tavern.show_customer_reaction("fail_weird", "toby")
	_ok(_portrait_path(tavern).ends_with("/toby_hurt.png"), "Toby weird item switches to hurt portrait")

	tavern.queue_free()


func _test_toby_story_state_uses_afraid_portrait() -> void:
	var gm = get_node("/root/GameManager")
	var old_danger = gm.narrative.get_var("toby_danger_known")
	var old_secured = gm.narrative.get_var("toby_secured")

	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	gm.narrative.set_var("toby_danger_known", true)
	gm.narrative.set_var("toby_secured", false)
	tavern.show_customer("Toby", "herb_broth", "toby")
	_ok(_portrait_path(tavern).ends_with("/toby_afraid.png"),
		"Toby danger-known unsecure story state uses afraid portrait")

	gm.narrative.set_var("toby_secured", true)
	tavern.show_customer("Toby", "herb_broth", "toby")
	_ok(_portrait_path(tavern).ends_with("/toby_neutral.png"),
		"Toby secured story state no longer enters afraid")

	gm.narrative.set_var("toby_danger_known", old_danger)
	gm.narrative.set_var("toby_secured", old_secured)
	tavern.queue_free()


func _portrait_path(tavern: Node) -> String:
	var sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	if sprite == null or sprite.texture == null:
		return ""
	return sprite.texture.resource_path
