extends Node

## Item physics profile regression tests. Run headless with
## scenes/test/test_item_physics_profiles.tscn.

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_profile_values_are_applied_and_clamped()
	_test_omitted_profiles_fall_back_to_defaults()
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


func _visual_rect_size(item: DeskItem) -> Vector2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for node_name in ["VisualTop", "VisualBottom"]:
		var visual := item.get_node(node_name) as Polygon2D
		for p in visual.polygon:
			min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
			max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
	return max_p - min_p
