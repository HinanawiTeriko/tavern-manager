extends Node

## Item physics profile regression tests. Run headless with
## scenes/test/test_item_physics_profiles.tscn.

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_profile_values_are_applied_and_clamped()
	_test_omitted_profiles_fall_back_to_defaults()
	_test_feedback_profile_triggers_visual_impact()
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
			},
			"thud": {
				"impact_sound": "thud",
				"impact_particle": "",
				"shake_scale": 0.15
			},
			"powder": {
				"impact_sound": "soft",
				"impact_particle": "flour_puff",
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


func _test_feedback_profile_triggers_visual_impact() -> void:
	var item := _spawn_item()
	item.setup_item("grape", {
		"color": [0.6, 0.1, 0.2],
		"feedback_profile": "bouncy"
	}, _profiles())
	var visual := item.get_node("Visual") as Polygon2D
	_ok(not item.trigger_impact_feedback(120.0), "low-speed impact should not trigger feedback")
	_ok(visual.modulate == Color.WHITE, "low-speed impact should leave visual modulate unchanged")
	_ok(item.trigger_impact_feedback(320.0), "high-speed impact should trigger feedback")
	_ok(visual.modulate != Color.WHITE, "high-speed impact should flash visual color")
	_ok(visual.scale != Vector2.ONE, "high-speed impact should pop visual scale")
	_ok(item.has_node("ImpactFeedback/BouncyRing"), "bouncy impact should create visible ring")
	item.queue_free()

	var thud := _spawn_item()
	thud.setup_item("meat_raw", {"feedback_profile": "thud"}, _profiles())
	_ok(thud.trigger_impact_feedback(320.0), "thud impact should trigger feedback")
	_ok(thud.has_node("ImpactFeedback/ThudBlock"), "thud impact should create visible block")
	thud.queue_free()

	var powder := _spawn_item()
	powder.setup_item("flour", {"feedback_profile": "powder"}, _profiles())
	_ok(powder.trigger_impact_feedback(320.0), "powder impact should trigger feedback")
	_ok(powder.get_node("ImpactFeedback").get_child_count() >= 4, "powder impact should create several dust motes")
	powder.queue_free()

	var baseline := _spawn_item()
	baseline.setup_item("ale", {}, _profiles())
	_ok(baseline.trigger_impact_feedback(320.0), "default impact should trigger feedback")
	_ok(baseline.has_node("ImpactFeedback/DefaultFlash"), "default impact should create a small flash")
	baseline.queue_free()


func _visual_rect_size(item: DeskItem) -> Vector2:
	var visual := item.get_node("Visual") as Polygon2D
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for p in visual.polygon:
		min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
		max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
	return max_p - min_p
