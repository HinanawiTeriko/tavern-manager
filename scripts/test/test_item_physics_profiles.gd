extends Node

## Item physics profile regression tests. Run headless with
## scenes/test/test_item_physics_profiles.tscn.

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const TEXTURE_COLLISION_BOUNDS := preload("res://scripts/ui/texture_collision_bounds.gd")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_profile_values_are_applied_and_clamped()
	_test_omitted_profiles_fall_back_to_defaults()
	_test_optional_art_texture_overrides_placeholder_visuals()
	if _failures == 0:
		print("[TEST-ITEM-PHYSICS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-ITEM-PHYSICS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-ITEM-PHYSICS] FAIL: " + msg)


func _profiles() -> Dictionary:
	return {
		"physics": {
			"default": {
				"mass": 1.0,
				"friction": 0.6,
				"bounce": 0.25,
				"linear_damp": 0.2,
				"angular_damp": 0.2,
				"gravity_scale": 1.0
			},
			"unsafe": {
				"mass": 99.0,
				"friction": -3.0,
				"bounce": 2.0,
				"linear_damp": 6.0,
				"angular_damp": -4.0,
				"gravity_scale": 0.01
			}
		},
		"collision": {
			"default_box": {
				"shape": "rect",
				"size": [56, 56],
				"offset": [0, 0]
			},
			"circle_small": {
				"shape": "circle",
				"radius": 14,
				"offset": [3, -2]
			}
		},
		"feedback": {
			"default": {
				"impact_sound": "normal",
				"impact_particle": "",
				"shake_scale": 0.0
			},
			"bouncy": {
				"impact_sound": "tap",
				"impact_particle": "",
				"shake_scale": 0.0
			}
		}
	}


func _spawn_item() -> DeskItem:
	var item: DeskItem = DESK_ITEM_SCENE.instantiate()
	add_child(item)
	return item


func _test_profile_values_are_applied_and_clamped() -> void:
	var item := _spawn_item()
	item.setup_item("grape", {
		"color": [0.6, 0.1, 0.2],
		"physics_profile": "unsafe",
		"collision_profile": "circle_small",
		"feedback_profile": "bouncy"
	}, _profiles())

	_ok(is_equal_approx(item.mass, 5.0), "mass should clamp to 5.0")
	_ok(is_equal_approx(item.physics_material_override.friction, 0.0), "friction should clamp to 0.0")
	_ok(is_equal_approx(item.physics_material_override.bounce, 0.8), "bounce should clamp to 0.8")
	_ok(is_equal_approx(item.linear_damp, 2.0), "linear_damp should clamp to 2.0")
	_ok(is_equal_approx(item.angular_damp, 0.0), "angular_damp should clamp to 0.0")
	_ok(is_equal_approx(item.gravity_scale, 0.2), "gravity_scale should clamp to 0.2")
	_ok(item.continuous_cd == RigidBody2D.CCD_MODE_CAST_SHAPE, "items should use shape CCD to reduce tunneling")
	_ok(item.get_node("Shape").shape is CircleShape2D, "circle collision profile should create CircleShape2D")
	_ok(item.get_node("Shape").position == Vector2(3, -2), "collision offset should be applied")
	_ok(item.feedback_profile.get("impact_sound", "") == "tap", "feedback profile should be stored")
	item.queue_free()


func _test_omitted_profiles_fall_back_to_defaults() -> void:
	var item := _spawn_item()
	item.setup_item("unknown", {}, _profiles())

	_ok(is_equal_approx(item.mass, 1.0), "omitted physics profile should use default mass")
	_ok(is_equal_approx(item.physics_material_override.friction, 0.6), "omitted physics profile should use default friction")
	_ok(item.get_node("Shape").shape is RectangleShape2D, "omitted collision profile should use default box")
	_ok(_visual_rect_size(item) == Vector2(56, 56), "visual rect should match default collision box")
	_ok(item.feedback_profile.get("impact_sound", "") == "normal", "omitted feedback profile should use default")
	item.queue_free()


func _test_optional_art_texture_overrides_placeholder_visuals() -> void:
	for key in ["ale", "grape", "flour", "meat_raw", "herb"]:
		var item := _spawn_item()
		item.setup_item(key, {"color": [0.7, 0.55, 0.3]}, _profiles())
		_ok(item.has_method("set_art_texture"), "desk item exposes optional art texture hook")
		if not item.has_method("set_art_texture"):
			item.queue_free()
			return
		var texture := load("res://assets/textures/tavern/icons/%s.png" % key) as Texture2D
		item.set_art_texture(texture)
		var art := item.get_node_or_null("IconArt") as Sprite2D
		_ok(art != null, key + " desk item creates an IconArt Sprite2D")
		_ok(art != null and art.texture == texture, key + " IconArt uses the assigned texture")
		_ok(art != null and art.visible, key + " IconArt is visible when a texture is assigned")
		_ok(not (item.get_node("VisualTop") as Polygon2D).visible, key + " top placeholder visual hides behind texture art")
		_ok(not (item.get_node("VisualBottom") as Polygon2D).visible, key + " bottom placeholder visual hides behind texture art")
		_ok(art != null and art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, key + " IconArt uses nearest texture filtering")
		_ok(art != null and _vector2_is_equal_approx(art.scale, Vector2(0.82, 0.82)), key + " IconArt is scaled down for desk readability")
		_assert_collision_matches_scaled_texture_alpha(item, texture, art.scale, key)
		item.add_heat(0, 0.1)
		_ok(art != null and not art.visible, key + " heating clears texture art so split-face doneness stays visible")
		_ok((item.get_node("VisualTop") as Polygon2D).visible, key + " top visual returns for heated items")
		_ok((item.get_node("VisualBottom") as Polygon2D).visible, key + " bottom visual returns for heated items")
		var shape := item.get_node("Shape") as CollisionShape2D
		var rect := shape.shape as RectangleShape2D
		_ok(rect != null and rect.size == Vector2(56, 56), key + " heating restores profile collision size")
		item.queue_free()


func _assert_collision_matches_scaled_texture_alpha(item: DeskItem, texture: Texture2D, art_scale: Vector2, key: String) -> void:
	var alpha_bounds: Rect2 = TEXTURE_COLLISION_BOUNDS.alpha_rect(texture)
	var expected := Rect2(
		(alpha_bounds.position - Vector2(texture.get_width(), texture.get_height()) * 0.5) * art_scale,
		alpha_bounds.size * art_scale.abs()
	)
	var shape := item.get_node("Shape") as CollisionShape2D
	var convex := shape.shape as ConvexPolygonShape2D
	_ok(convex != null, key + " texture-backed item uses a convex polygon collision shape")
	if convex == null:
		return
	_ok(convex.points.size() > 4, key + " convex collision is more specific than an alpha-bounds rectangle")
	var polygon_bounds := _polygon_bounds(convex.points)
	_ok(_vector2_is_equal_approx(polygon_bounds.size, expected.size), key + " convex collision bounds follow runtime texture alpha bounds")
	_ok(_vector2_is_equal_approx(shape.position + polygon_bounds.get_center(), expected.get_center()),
		key + " convex collision offset follows runtime texture alpha bounds")


func _visual_rect_size(item: DeskItem) -> Vector2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for node_name in ["VisualTop", "VisualBottom"]:
		var visual := item.get_node(node_name) as Polygon2D
		for p in visual.polygon:
			min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
			max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
	return max_p - min_p


func _vector2_is_equal_approx(a: Vector2, b: Vector2) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y)


func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for point in points:
		min_p = Vector2(minf(min_p.x, point.x), minf(min_p.y, point.y))
		max_p = Vector2(maxf(max_p.x, point.x), maxf(max_p.y, point.y))
	if min_p.x == INF:
		return Rect2()
	return Rect2(min_p, max_p - min_p)
