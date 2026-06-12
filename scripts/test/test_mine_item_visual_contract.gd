extends Node

const MINE_ITEM_SCENE := preload("res://scenes/ui/components/MineItem.tscn")
const SHADOW_PATH := "res://assets/ui/generated/investigation/mine_background/mine_item_shadow.png"
const EXPECTED_RUNTIME_SIZES := {
	"broken_arrow": Vector2(120, 36),
	"dented_shield": Vector2(96, 96),
	"lost_boot": Vector2(84, 56),
	"rubble": Vector2(320, 216),
	"torn_backpack": Vector2(112, 84),
	"coins": Vector2(64, 48),
	"warhammer_token": Vector2(56, 56),
	"bloodied_paper": Vector2(72, 88),
}

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_production_item_hides_debug_visuals_and_shows_shadow()
	_test_rubble_item_uses_reduced_visual_scale()
	_test_unknown_item_keeps_legacy_visuals_without_shadow()
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


func _test_production_item_hides_debug_visuals_and_shows_shadow() -> void:
	var item := _spawn_item()
	item.setup("broken_arrow", "observation", Vector2(120, 36), Color.RED, "debug label", "observation")
	item.rotation = 1.35
	await get_tree().physics_frame
	_ok(item.get_node_or_null("Shape") is CollisionShape2D, "Shape node is preserved")
	_ok(item.get_node_or_null("Visual") is Polygon2D, "Visual node is preserved")
	_ok(item.get_node_or_null("Label") is Label, "Label node is preserved")
	_ok(item.get_node_or_null("TextureVisual") is Sprite2D, "production item creates TextureVisual")
	_ok(item.get_node_or_null("ShadowVisual") is Sprite2D, "production item creates ShadowVisual")
	_ok(not item.get_node("Visual").visible, "production item hides polygon debug visual")
	_ok(not item.get_node("Label").visible, "production item hides always-on debug label")
	var sprite := item.get_node_or_null("TextureVisual") as Sprite2D
	if sprite != null:
		_ok(sprite.visible, "production sprite is visible")
		_ok(sprite.texture != null, "production sprite has texture")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "production sprite uses nearest texture filtering")
		if sprite.texture != null:
			var rendered_size := sprite.texture.get_size() * sprite.scale
			_ok(sprite.texture.get_size() == EXPECTED_RUNTIME_SIZES["broken_arrow"], "production sprite texture is final scene size")
			_ok(sprite.scale == Vector2.ONE, "production sprite uses 1:1 runtime scale")
			_ok(rendered_size == EXPECTED_RUNTIME_SIZES["broken_arrow"], "production sprite renders at final scene size")
	var shadow := item.get_node_or_null("ShadowVisual") as Sprite2D
	if shadow != null:
		_ok(shadow.visible, "production shadow is visible")
		_ok(shadow.texture != null, "production shadow has texture")
		if shadow.texture != null:
			_ok(shadow.texture.resource_path == SHADOW_PATH, "production shadow uses mine_item_shadow runtime texture")
		_ok(shadow.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "production shadow uses nearest texture filtering")
		_ok(shadow.top_level, "production shadow is top-level so it does not inherit item rotation")
		_ok(absf(wrapf(shadow.global_rotation, -PI, PI)) < 0.01, "production shadow remains horizontally aligned")
		if sprite != null:
			_ok(shadow.z_index < sprite.z_index, "production shadow renders below item texture")
	_ok(item.item_tag == "broken_arrow", "item_tag contract remains set by setup")
	_ok(item.kind == "observation", "kind contract remains set by setup")
	var shape := item.get_node_or_null("Shape") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		_ok((shape.shape as RectangleShape2D).size == EXPECTED_RUNTIME_SIZES["broken_arrow"], "broken arrow collision matches final visual size")
	item.queue_free()


func _test_rubble_item_uses_reduced_visual_scale() -> void:
	var item := _spawn_item()
	item.setup("rubble", "rubble", Vector2(320, 216), Color.DARK_GRAY, "debug rubble", "")
	var sprite := item.get_node_or_null("TextureVisual") as Sprite2D
	_ok(sprite != null, "rubble production item creates TextureVisual")
	if sprite != null and sprite.texture != null:
		var rendered_size := sprite.texture.get_size() * sprite.scale
		_ok(sprite.texture.get_size() == EXPECTED_RUNTIME_SIZES["rubble"], "rubble texture is final scene size")
		_ok(sprite.scale == Vector2.ONE, "rubble uses 1:1 runtime scale")
		_ok(rendered_size == EXPECTED_RUNTIME_SIZES["rubble"], "rubble visual uses authored final size")
	var shape := item.get_node_or_null("Shape") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		_ok((shape.shape as RectangleShape2D).size == EXPECTED_RUNTIME_SIZES["rubble"], "rubble collision matches larger collapsed-stone visual")
	item.queue_free()


func _test_unknown_item_keeps_legacy_visuals_without_shadow() -> void:
	var item := _spawn_item()
	item.setup("unmapped_debug_item", "plain", Vector2(32, 32), Color.GREEN, "debug label", "")
	_ok(item.get_node("Visual").visible, "unmapped item keeps polygon visual")
	_ok(item.get_node("Label").visible, "unmapped item keeps debug label")
	_ok(item.get_node_or_null("TextureVisual") == null or not item.get_node("TextureVisual").visible, "unmapped item does not show production sprite")
	_ok(item.get_node_or_null("ShadowVisual") == null or not item.get_node("ShadowVisual").visible, "unmapped item does not force a production shadow")
	item.queue_free()
