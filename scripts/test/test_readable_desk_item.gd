extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_ledger_art_is_wired()
	_test_double_click_requests_open()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-READABLE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-READABLE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-READABLE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_double_click_requests_open() -> void:
	var item = preload("res://scenes/ui/readable_desk_item.tscn").instantiate()
	add_child(item)
	var opened: Array[String] = []
	item.open_requested.connect(func(document_id: String): opened.append(document_id))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	item._input_event(null, click, 0)
	_ok(opened == ["ledger"], "double click requests ledger open")


func _test_ledger_art_is_wired() -> void:
	var item = preload("res://scenes/ui/readable_desk_item.tscn").instantiate()
	add_child(item)
	_ok(item is RigidBody2D, "ReadableDeskItem is a draggable physics body")
	if item is RigidBody2D:
		_ok(not (item as RigidBody2D).lock_rotation,
			"ReadableDeskItem allows rotation under the pin-joint drag physics")
	var art := item.get_node_or_null("Art") as Sprite2D
	_ok(art != null and art.texture != null, "ReadableDeskItem has ledger texture art")
	if art != null and art.texture != null:
		_ok(String(art.texture.resource_path) == "res://assets/textures/tavern/props/ledger.png",
			"ReadableDeskItem uses the Tavern ledger prop texture")
		_ok(art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"ReadableDeskItem ledger art uses nearest texture filtering")
	var label := item.get_node_or_null("Label") as Label
	if label != null:
		_ok(not label.visible, "ReadableDeskItem hides placeholder text when using ledger art")
	var visual := item.get_node_or_null("Visual") as CanvasItem
	if visual != null:
		_ok(not visual.visible, "ReadableDeskItem hides placeholder polygon when using ledger art")
	item.queue_free()
