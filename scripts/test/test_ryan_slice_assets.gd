extends Node

const TEXTURE_COLLISION_BOUNDS := preload("res://scripts/ui/texture_collision_bounds.gd")

var _checks := 0
var _failures := 0


func _ready() -> void:
	for path in [
		"res://assets/textures/backgrounds/tavern_bg.png",
		"res://assets/textures/characters/ryan_neutral.png",
		"res://assets/textures/characters/ryan_excited.png",
		"res://assets/textures/characters/ryan_hesitant.png",
		"res://assets/textures/characters/ryan_dejected.png",
		"res://assets/textures/characters/mercenary_a.png",
		"res://assets/textures/icons/items/sleep_powder.png",
		"res://assets/textures/icons/items/spice.png",
		"res://assets/textures/icons/items/herb_spice.png",
		"res://assets/textures/icons/items/salt.png",
		"res://assets/textures/icons/items/bloodied_contract.png",
		"res://assets/textures/icons/items/alternative_contract.png",
		"res://assets/textures/vfx/ingredient_drop.png",
		"res://assets/textures/vfx/product_ready.png",
		"res://assets/textures/vfx/serve_success.png",
		"res://assets/textures/vfx/new_document.png",
		"res://assets/textures/workspace/barrel.png",
		"res://assets/textures/workspace/pot.png",
		"res://assets/textures/workspace/grill.png",
		"res://assets/textures/workspace/spoon.png",
		"res://assets/textures/workspace/seasoning_shaker.png",
		"res://assets/textures/workspace/seasoning_shaker_closed.png",
	]:
		_ok(FileAccess.file_exists(path), "asset exists: " + path)

	var gm = get_node("/root/GameManager")
	for key in [
		"ale", "grape", "flour", "meat_raw", "herb", "ale_beer", "bread", "meat_cooked",
		"herb_broth", "spice", "herb_spice", "salt", "sleep_powder", "bloodied_contract", "alternative_contract",
	]:
		_ok(gm.try_load_material_icon(key) != null, "mapped icon loads: " + key)
	for key in ["ale_beer", "bread", "meat_cooked", "herb_broth", "bloodied_contract", "alternative_contract"]:
		var icon: Texture2D = gm.try_load_material_icon(key)
		_ok(icon != null and icon.resource_path == "res://assets/textures/tavern/items/%s.png" % key,
			key + " uses Tavern item art")
	for key in ["ale", "grape", "flour", "meat_raw", "herb"]:
		var icon: Texture2D = gm.try_load_material_icon(key)
		_ok(icon != null and icon.resource_path == "res://assets/textures/tavern/icons/%s.png" % key,
			key + " uses Tavern item icon")
	await _test_workspace_prop_art()
	_finish()


func _test_workspace_prop_art() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	for path in [
		"BarWorkspace/World/Brewery/Art",
		"BarWorkspace/World/Grill/Art",
		"BarWorkspace/World/Pot/Art",
		"BarWorkspace/World/Spoon/Art",
		"BarWorkspace/World/SeasoningShaker/Art",
		"BarWorkspace/World/SeasoningShaker/ClosedArt",
	]:
		var art := tavern.get_node_or_null(path) as Sprite2D
		_ok(art != null and art.texture != null, "workspace prop art is attached: " + path)
	for path in [
		"BarWorkspace/World/Brewery/Visual",
		"BarWorkspace/World/Brewery/MouthRim",
		"BarWorkspace/World/Grill/Visual",
		"BarWorkspace/World/Grill/HeatBars",
		"BarWorkspace/World/Pot/Visual",
		"BarWorkspace/World/Pot/Soup",
		"BarWorkspace/World/Spoon/Visual",
		"BarWorkspace/World/SeasoningShaker/Visual",
		"BarWorkspace/World/SeasoningShaker/Cap",
	]:
		_ok(not tavern.get_node(path).visible, "placeholder visual is hidden: " + path)
	var shaker := tavern.get_node("BarWorkspace/World/SeasoningShaker") as SeasoningShaker
	var shaker_art := tavern.get_node_or_null("BarWorkspace/World/SeasoningShaker/Art") as Sprite2D
	var shaker_closed_art := tavern.get_node_or_null("BarWorkspace/World/SeasoningShaker/ClosedArt") as Sprite2D
	var shaker_fill := tavern.get_node_or_null("BarWorkspace/World/SeasoningShaker/Fill") as Polygon2D
	if shaker != null and shaker_art != null and shaker_closed_art != null and shaker_fill != null:
		_ok(shaker_art.visible, "empty seasoning shaker shows the open steel can")
		_ok(not shaker_closed_art.visible, "empty seasoning shaker hides the capped steel can")
		_ok(not shaker_fill.visible, "empty opaque seasoning shaker hides the internal fill")
		shaker.load_seasoning("spice")
		_ok(not shaker_art.visible, "loaded seasoning shaker hides the open steel can")
		_ok(shaker_closed_art.visible, "loaded seasoning shaker shows the capped steel can")
		_ok(not shaker_fill.visible, "loaded opaque seasoning shaker does not show internal powder fill")
	_test_workspace_collision_matches_texture_art(tavern)
	tavern.free()


func _test_workspace_collision_matches_texture_art(tavern: Node) -> void:
	var brewery_art := tavern.get_node("BarWorkspace/World/Brewery/Art") as Sprite2D
	var brewery_expected := TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(brewery_art)
	var brewery_pickup := tavern.get_node("BarWorkspace/World/Brewery/PickupArea/Shape") as CollisionPolygon2D
	var brewery_bounds := _polygon_bounds(brewery_pickup.polygon)
	_ok_vec2_approx(brewery_bounds.size, brewery_expected.size, "barrel pickup collision size follows texture alpha bounds")
	_ok_vec2_approx(brewery_bounds.position, brewery_expected.position, "barrel pickup collision position follows texture alpha bounds")

	var grill_art := tavern.get_node("BarWorkspace/World/Grill/Art") as Sprite2D
	var grill_expected := TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(grill_art)
	var grill_body := tavern.get_node("BarWorkspace/World/Grill/Body") as CollisionShape2D
	var grill_shape := grill_body.shape as RectangleShape2D
	_ok(grill_shape != null, "grill body collision uses a rectangle shape")
	if grill_shape != null:
		_ok_vec2_approx(grill_shape.size, grill_expected.size, "grill body collision size follows texture alpha bounds")
		_ok_vec2_approx(grill_body.position, grill_expected.get_center(), "grill body collision center follows texture alpha bounds")

	var pot_art := tavern.get_node("BarWorkspace/World/Pot/Art") as Sprite2D
	var pot_expected := TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(pot_art)
	var pot_pickup := tavern.get_node("BarWorkspace/World/Pot/PickupArea/Shape") as CollisionShape2D
	var pot_shape := pot_pickup.shape as RectangleShape2D
	_ok(pot_shape != null, "pot pickup collision uses a rectangle shape")
	if pot_shape != null:
		_ok_vec2_approx(pot_shape.size, pot_expected.size, "pot pickup collision size follows texture alpha bounds")
		_ok_vec2_approx(pot_pickup.position, pot_expected.get_center(), "pot pickup collision center follows texture alpha bounds")

	var spoon_shape_node := tavern.get_node("BarWorkspace/World/Spoon/Shape") as CollisionShape2D
	var spoon_shape := spoon_shape_node.shape as CapsuleShape2D
	var spoon_art := tavern.get_node("BarWorkspace/World/Spoon/Art") as Sprite2D
	var spoon_expected := TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(spoon_art)
	_ok(spoon_shape != null, "spoon collision uses a capsule shape")
	if spoon_shape != null:
		_ok(is_equal_approx(spoon_shape.radius, spoon_expected.size.x * 0.5), "spoon collision width follows texture alpha bounds")
		_ok(is_equal_approx(spoon_shape.height, maxf(spoon_expected.size.y, spoon_shape.radius * 2.0)), "spoon collision height follows texture alpha bounds")
		_ok_vec2_approx(spoon_shape_node.position, spoon_expected.get_center(), "spoon collision center follows texture alpha bounds")

	var shaker_art := tavern.get_node("BarWorkspace/World/SeasoningShaker/Art") as Sprite2D
	var barrel_art := tavern.get_node("BarWorkspace/World/Brewery/Art") as Sprite2D
	var shaker_expected := TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(shaker_art)
	var barrel_expected := TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(barrel_art)
	_ok(shaker_expected.size.x < barrel_expected.size.x and shaker_expected.size.y < barrel_expected.size.y,
		"seasoning shaker art is smaller than the barrel: shaker %s, barrel %s" % [shaker_expected.size, barrel_expected.size])
	var shaker_mouth := tavern.get_node("BarWorkspace/World/SeasoningShaker/Mouth/Shape") as CollisionShape2D
	var shaker_mouth_shape := shaker_mouth.shape as RectangleShape2D
	_ok(shaker_mouth_shape != null and shaker_mouth_shape.size.x >= 56.0 and shaker_mouth_shape.size.y >= 32.0,
		"seasoning shaker mouth pickup area is generous enough for seasoning items")
	var shaker_body := tavern.get_node("BarWorkspace/World/SeasoningShaker/Shape") as CollisionShape2D
	var shaker_shape := shaker_body.shape as RectangleShape2D
	_ok(shaker_shape != null, "seasoning shaker body collision uses a rectangle shape")
	if shaker_shape != null:
		_ok_vec2_approx(shaker_shape.size, shaker_expected.size, "seasoning shaker body collision size follows texture alpha bounds")
		_ok_vec2_approx(shaker_body.position, shaker_expected.get_center(), "seasoning shaker body collision center follows texture alpha bounds")

	var shaker_pickup := tavern.get_node("BarWorkspace/World/SeasoningShaker/PickupArea/Shape") as CollisionShape2D
	var shaker_pickup_shape := shaker_pickup.shape as RectangleShape2D
	_ok(shaker_pickup_shape != null, "seasoning shaker pickup collision uses a rectangle shape")
	if shaker_pickup_shape != null:
		_ok_vec2_approx(shaker_pickup_shape.size, shaker_expected.size, "seasoning shaker pickup collision size follows texture alpha bounds")
		_ok_vec2_approx(shaker_pickup.position, shaker_expected.get_center(), "seasoning shaker pickup collision center follows texture alpha bounds")


func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for point in points:
		min_p = Vector2(minf(min_p.x, point.x), minf(min_p.y, point.y))
		max_p = Vector2(maxf(max_p.x, point.x), maxf(max_p.y, point.y))
	if min_p.x == INF:
		return Rect2()
	return Rect2(min_p, max_p - min_p)


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RYAN-ASSETS] FAIL: " + msg)


func _ok_vec2_approx(actual: Vector2, expected: Vector2, msg: String) -> void:
	_ok(actual.is_equal_approx(expected), "%s: expected %s, got %s" % [msg, expected, actual])


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RYAN-ASSETS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RYAN-ASSETS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
