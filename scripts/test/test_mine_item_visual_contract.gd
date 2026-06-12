extends Node

const MINE_ITEM_SCENE := preload("res://scenes/ui/components/MineItem.tscn")
const EXPECTED_RUNTIME_SIZES := {
	"broken_arrow": Vector2(120, 36),
	"dented_shield": Vector2(96, 96),
	"lost_boot": Vector2(84, 56),
	"rubble": Vector2(320, 216),
	"torn_backpack": Vector2(128, 112),
	"coins": Vector2(64, 48),
	"warhammer_token": Vector2(56, 56),
	"bloodied_paper": Vector2(72, 88),
}
const EXPECTED_COLLISION_PROFILES := {
	"broken_arrow": {"size": Vector2(88, 32), "offset": Vector2.ZERO},
	"dented_shield": {"size": Vector2(88, 76), "offset": Vector2.ZERO},
	"lost_boot": {"size": Vector2(76, 48), "offset": Vector2(-2, 4)},
	"rubble": {"size": Vector2(304, 148), "offset": Vector2.ZERO},
	"torn_backpack": {"size": Vector2(104, 88), "offset": Vector2(0, 10)},
	"coins": {"size": Vector2(52, 28), "offset": Vector2(8, 0)},
	"warhammer_token": {"size": Vector2(48, 48), "offset": Vector2.ZERO},
	"bloodied_paper": {"size": Vector2(56, 80), "offset": Vector2.ZERO},
}

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_production_item_hides_debug_visuals_without_shadow()
	_test_rubble_item_uses_reduced_visual_scale()
	_test_open_backpack_uses_taller_collision_volume()
	_test_all_production_items_use_fixed_collision_profiles()
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


func _assert_rect_collision(item: MineItem, expected_size: Vector2, expected_offset: Vector2, msg_prefix: String) -> void:
	var shape := item.get_node_or_null("Shape") as CollisionShape2D
	_ok(shape != null, msg_prefix + " keeps Shape collision node")
	if shape == null:
		return
	var rect := shape.shape as RectangleShape2D
	_ok(rect != null, msg_prefix + " uses rectangle collision shape")
	if rect != null:
		_ok(rect.size == expected_size, msg_prefix + " collision size matches authored profile")
	_ok(shape.position == expected_offset, msg_prefix + " collision offset matches authored profile")


func _test_production_item_hides_debug_visuals_without_shadow() -> void:
	var item := _spawn_item()
	item.setup("broken_arrow", "observation", Vector2(120, 36), Color.RED, "debug label", "observation")
	item.rotation = 1.35
	await get_tree().physics_frame
	_ok(item.get_node_or_null("Shape") is CollisionShape2D, "Shape node is preserved")
	_ok(item.get_node_or_null("Visual") is Polygon2D, "Visual node is preserved")
	_ok(item.get_node_or_null("Label") is Label, "Label node is preserved")
	_ok(item.get_node_or_null("TextureVisual") is Sprite2D, "production item creates TextureVisual")
	_ok(item.get_node_or_null("ShadowVisual") == null, "production item does not create a contact shadow")
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
	_ok(item.item_tag == "broken_arrow", "item_tag contract remains set by setup")
	_ok(item.kind == "observation", "kind contract remains set by setup")
	_assert_rect_collision(
		item,
		EXPECTED_COLLISION_PROFILES["broken_arrow"]["size"],
		EXPECTED_COLLISION_PROFILES["broken_arrow"]["offset"],
		"broken arrow"
	)
	item.queue_free()


func _test_open_backpack_uses_taller_collision_volume() -> void:
	var item := _spawn_item()
	item.setup("torn_backpack", "backpack", EXPECTED_RUNTIME_SIZES["torn_backpack"], Color.SADDLE_BROWN, "debug backpack", "")
	var sprite := item.get_node_or_null("TextureVisual") as Sprite2D
	_ok(sprite != null, "open backpack production item creates TextureVisual")
	if sprite != null and sprite.texture != null:
		_ok(sprite.texture.get_size() == EXPECTED_RUNTIME_SIZES["torn_backpack"], "open backpack texture is taller final scene size")
		_ok(sprite.scale == Vector2.ONE, "open backpack uses 1:1 runtime scale")
	_assert_rect_collision(
		item,
		EXPECTED_COLLISION_PROFILES["torn_backpack"]["size"],
		EXPECTED_COLLISION_PROFILES["torn_backpack"]["offset"],
		"open backpack"
	)
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
	_assert_rect_collision(
		item,
		EXPECTED_COLLISION_PROFILES["rubble"]["size"],
		EXPECTED_COLLISION_PROFILES["rubble"]["offset"],
		"rubble"
	)
	item.queue_free()


func _test_all_production_items_use_fixed_collision_profiles() -> void:
	for key in EXPECTED_COLLISION_PROFILES.keys():
		var item := _spawn_item()
		item.setup(key, "plain", EXPECTED_RUNTIME_SIZES[key], Color.WHITE, "debug " + key, "")
		_assert_rect_collision(
			item,
			EXPECTED_COLLISION_PROFILES[key]["size"],
			EXPECTED_COLLISION_PROFILES[key]["offset"],
			key
		)
		item.queue_free()


func _test_unknown_item_keeps_legacy_visuals_without_shadow() -> void:
	var item := _spawn_item()
	item.setup("unmapped_debug_item", "plain", Vector2(32, 32), Color.GREEN, "debug label", "")
	_ok(item.get_node("Visual").visible, "unmapped item keeps polygon visual")
	_ok(item.get_node("Label").visible, "unmapped item keeps debug label")
	_ok(item.get_node_or_null("TextureVisual") == null or not item.get_node("TextureVisual").visible, "unmapped item does not show production sprite")
	_ok(item.get_node_or_null("ShadowVisual") == null or not item.get_node("ShadowVisual").visible, "unmapped item does not force a production shadow")
	_assert_rect_collision(item, Vector2(32, 32), Vector2.ZERO, "unmapped debug item")
	item.queue_free()
