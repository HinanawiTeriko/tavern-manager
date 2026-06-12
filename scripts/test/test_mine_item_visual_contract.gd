extends Node

const MINE_ITEM_SCENE := preload("res://scenes/ui/components/MineItem.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_production_item_hides_debug_visuals()
	_test_unknown_item_keeps_legacy_visuals()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MINE-ITEM-VISUAL] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MINE-ITEM-VISUAL] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MINE-ITEM-VISUAL] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _spawn_item() -> MineItem:
	var item: MineItem = MINE_ITEM_SCENE.instantiate()
	add_child(item)
	return item


func _test_production_item_hides_debug_visuals() -> void:
	var item := _spawn_item()
	item.setup("broken_arrow", "observation", Vector2(48, 16), Color.RED, "debug label", "observation")
	_ok(item.get_node_or_null("Shape") is CollisionShape2D, "Shape node is preserved")
	_ok(item.get_node_or_null("Visual") is Polygon2D, "Visual node is preserved")
	_ok(item.get_node_or_null("Label") is Label, "Label node is preserved")
	_ok(item.get_node_or_null("TextureVisual") is Sprite2D, "production item creates TextureVisual")
	_ok(not item.get_node("Visual").visible, "production item hides polygon debug visual")
	_ok(not item.get_node("Label").visible, "production item hides always-on debug label")
	var sprite := item.get_node_or_null("TextureVisual") as Sprite2D
	if sprite != null:
		_ok(sprite.visible, "production sprite is visible")
		_ok(sprite.texture != null, "production sprite has texture")
	_ok(item.item_tag == "broken_arrow", "item_tag contract remains set by setup")
	_ok(item.kind == "observation", "kind contract remains set by setup")
	item.queue_free()


func _test_unknown_item_keeps_legacy_visuals() -> void:
	var item := _spawn_item()
	item.setup("unmapped_debug_item", "plain", Vector2(32, 32), Color.GREEN, "debug label", "")
	_ok(item.get_node("Visual").visible, "unmapped item keeps polygon visual")
	_ok(item.get_node("Label").visible, "unmapped item keeps debug label")
	_ok(item.get_node_or_null("TextureVisual") == null or not item.get_node("TextureVisual").visible, "unmapped item does not show production sprite")
	item.queue_free()
