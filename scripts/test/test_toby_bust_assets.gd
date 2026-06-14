extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_tavern_uses_toby_portrait()
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
		_ok(sprite.texture != null and sprite.texture.get_size() == Vector2(280, 360),
			"Toby runtime portrait is 280x360 for the customer slot")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Toby portrait renders with nearest filtering")

	tavern.queue_free()
