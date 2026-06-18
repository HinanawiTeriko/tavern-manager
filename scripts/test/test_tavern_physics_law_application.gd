extends Node

const TAVERN_SCENE := preload("res://scenes/ui/Tavern.tscn")
const BASE_GRAVITY_META := "base_gravity_scale"

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _check_existing_and_new_item_gravity()
	_finish()


func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _check_existing_and_new_item_gravity() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	_ok(bar != null, "Tavern should expose BarWorkspace")
	_ok(bar.has_method("apply_physics_law"), "BarWorkspace should apply physics laws")
	_ok(bar.has_method("clear_physics_law"), "BarWorkspace should clear physics laws")
	if bar == null or not bar.has_method("apply_physics_law") or not bar.has_method("clear_physics_law"):
		tavern.queue_free()
		await get_tree().process_frame
		return

	var first := bar._spawn_desk_item_at(Vector2(320, 250), "ale")
	await get_tree().process_frame
	var base_gravity := first.gravity_scale
	_ok(is_equal_approx(base_gravity, 1.0), "test item should start with base gravity 1")

	bar.call("apply_physics_law", {
		"id": "low_gravity",
		"gravity_scale_multiplier": 0.45,
		"scope": "desk_items"
	})
	await get_tree().process_frame
	_ok(is_equal_approx(first.gravity_scale, base_gravity * 0.45), "existing item should receive gravity law")

	var second := bar._spawn_desk_item_at(Vector2(380, 250), "herb")
	await get_tree().process_frame
	_ok(second.has_meta(BASE_GRAVITY_META), "new item should store base gravity")
	_ok(is_equal_approx(second.gravity_scale, float(second.get_meta(BASE_GRAVITY_META)) * 0.45), "new item should receive active law")

	bar.call("clear_physics_law")
	await get_tree().process_frame
	_ok(is_equal_approx(first.gravity_scale, base_gravity), "first item should restore gravity")
	_ok(not first.has_meta(BASE_GRAVITY_META), "first item should clear base gravity metadata")
	_ok(is_equal_approx(second.gravity_scale, 1.0), "second item should restore gravity")
	_ok(not second.has_meta(BASE_GRAVITY_META), "second item should clear base gravity metadata")

	tavern.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("Tavern physics law checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
