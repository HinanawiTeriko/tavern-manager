extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_expression_textures_exist()
	await _test_tavern_uses_grey_ledger_lady_portrait()
	await _test_tavern_switches_grey_ledger_lady_expression_portraits()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-GREY-LEDGER-LADY-BUST] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-GREY-LEDGER-LADY-BUST] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-GREY-LEDGER-LADY-BUST] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_expression_textures_exist() -> void:
	for portrait_id in [
		"grey_ledger_lady_neutral",
		"grey_ledger_lady_smile",
		"grey_ledger_lady_assessing",
		"grey_ledger_lady_cracked",
		"grey_ledger_lady_welcoming",
		"grey_ledger_lady_knowing",
		"grey_ledger_lady_cold",
		"grey_ledger_lady_unsettled",
	]:
		var path := "res://assets/textures/characters/%s.png" % portrait_id
		_ok(FileAccess.file_exists(path), portrait_id + " runtime portrait exists")
		var texture := load(path) as Texture2D
		_ok(texture != null, portrait_id + " runtime portrait loads as Texture2D")
		if texture != null:
			_ok(texture.get_size() == Vector2(512, 640), portrait_id + " runtime portrait uses official 512x640")


func _test_tavern_uses_grey_ledger_lady_portrait() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	tavern.show_customer("Grey Ledger Lady", "black_wine", "grey_ledger_lady")
	_ok(_portrait_path(tavern).ends_with("/grey_ledger_lady_neutral.png"),
		"Tavern resolves grey_ledger_lady npc_id to neutral portrait")
	var sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	_ok(sprite != null, "Tavern keeps CustomerSprite")
	if sprite != null:
		_ok(sprite.texture != null and sprite.texture.get_size() == Vector2(512, 640),
			"Grey Ledger Lady runtime portrait uses the official 512x640 character pipeline")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Grey Ledger Lady portrait renders with nearest filtering")

	tavern.queue_free()


func _test_tavern_switches_grey_ledger_lady_expression_portraits() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	tavern.show_customer("Grey Ledger Lady", "black_wine", "grey_ledger_lady")
	_ok(tavern.has_method("show_customer_expression"),
		"TavernView exposes show_customer_expression for dialogue-driven portrait swaps")
	tavern.show_customer_reaction("success", "grey_ledger_lady")
	_ok(_portrait_path(tavern).ends_with("/grey_ledger_lady_smile.png"),
		"Grey Ledger Lady correct serve switches to false-savior smile")

	tavern.show_customer("Grey Ledger Lady", "black_wine", "grey_ledger_lady")
	tavern.show_customer_reaction("fail_wrong", "grey_ledger_lady")
	_ok(_portrait_path(tavern).ends_with("/grey_ledger_lady_assessing.png"),
		"Grey Ledger Lady failed serve switches to assessing portrait")

	tavern.show_customer("Grey Ledger Lady", "black_wine", "grey_ledger_lady")
	tavern.show_customer_reaction("cracked", "grey_ledger_lady")
	_ok(_portrait_path(tavern).ends_with("/grey_ledger_lady_cracked.png"),
		"Grey Ledger Lady cracked state switches to porcelain-cracked threat portrait")

	tavern.show_customer("Grey Ledger Lady", "black_wine", "grey_ledger_lady")
	if tavern.has_method("show_customer_expression"):
		tavern.show_customer_expression("welcoming", "grey_ledger_lady")
		_ok(_portrait_path(tavern).ends_with("/grey_ledger_lady_welcoming.png"),
			"Grey Ledger Lady dialogue can switch to courteous welcome portrait")
		tavern.show_customer_expression("knowing", "grey_ledger_lady")
		_ok(_portrait_path(tavern).ends_with("/grey_ledger_lady_knowing.png"),
			"Grey Ledger Lady dialogue can switch to knowing clue portrait")
		tavern.show_customer_expression("cold", "grey_ledger_lady")
		_ok(_portrait_path(tavern).ends_with("/grey_ledger_lady_cold.png"),
			"Grey Ledger Lady dialogue can switch to cold sealed-account portrait")
		tavern.show_customer_expression("unsettled", "grey_ledger_lady")
		_ok(_portrait_path(tavern).ends_with("/grey_ledger_lady_unsettled.png"),
			"Grey Ledger Lady dialogue can switch to unsettled public-account portrait")

	tavern.queue_free()


func _portrait_path(tavern: Node) -> String:
	var sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	if sprite == null or sprite.texture == null:
		return ""
	return sprite.texture.resource_path
