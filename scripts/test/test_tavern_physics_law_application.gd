extends Node

const TAVERN_SCENE := preload("res://scenes/ui/Tavern.tscn")
const BASE_GRAVITY_META := "base_gravity_scale"
const BASE_LINEAR_DAMP_META := "base_linear_damp"
const BASE_ANGULAR_DAMP_META := "base_angular_damp"
const HAS_BASE_MATERIAL_META := "has_base_physics_material_override"
const BASE_MATERIAL_META := "base_physics_material_override"

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _check_existing_and_new_item_gravity()
	await _check_damp_and_bounce_laws_restore()
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


func _check_damp_and_bounce_laws_restore() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null:
		_ok(false, "Tavern should expose BarWorkspace for damp and bounce checks")
		tavern.queue_free()
		await get_tree().process_frame
		return

	var slippery_item := bar._spawn_desk_item_at(Vector2(320, 250), "ale")
	await get_tree().process_frame
	var base_linear_damp := slippery_item.linear_damp
	var base_angular_damp := slippery_item.angular_damp

	bar.call("apply_physics_law", {
		"id": "slippery_physics",
		"gravity_scale_multiplier": 1.0,
		"linear_damp_multiplier": 0.25,
		"angular_damp_multiplier": 0.25,
		"scope": "desk_items"
	})
	await get_tree().process_frame
	_ok(slippery_item.has_meta(BASE_LINEAR_DAMP_META), "slippery law should store base linear damp")
	_ok(slippery_item.has_meta(BASE_ANGULAR_DAMP_META), "slippery law should store base angular damp")
	_ok(is_equal_approx(slippery_item.linear_damp, base_linear_damp * 0.25), "slippery law should reduce linear damp")
	_ok(is_equal_approx(slippery_item.angular_damp, base_angular_damp * 0.25), "slippery law should reduce angular damp")

	bar.call("clear_physics_law")
	await get_tree().process_frame
	_ok(is_equal_approx(slippery_item.linear_damp, base_linear_damp), "slippery law should restore linear damp")
	_ok(is_equal_approx(slippery_item.angular_damp, base_angular_damp), "slippery law should restore angular damp")
	_ok(not slippery_item.has_meta(BASE_LINEAR_DAMP_META), "slippery law should clear linear damp metadata")
	_ok(not slippery_item.has_meta(BASE_ANGULAR_DAMP_META), "slippery law should clear angular damp metadata")

	var bouncy_item := bar._spawn_desk_item_at(Vector2(380, 250), "herb")
	await get_tree().process_frame
	var base_material = bouncy_item.physics_material_override

	bar.call("apply_physics_law", {
		"id": "bouncy_physics",
		"gravity_scale_multiplier": 1.0,
		"bounce_override": 0.8,
		"scope": "desk_items"
	})
	await get_tree().process_frame
	_ok(bouncy_item.has_meta(HAS_BASE_MATERIAL_META), "bouncy law should remember whether a base material existed")
	_ok(bouncy_item.has_meta(BASE_MATERIAL_META) or base_material == null, "bouncy law should store base material when one exists")
	_ok(bouncy_item.physics_material_override != null, "bouncy law should install a physics material override")
	_ok(is_equal_approx(bouncy_item.physics_material_override.bounce, 0.8), "bouncy law should override bounce")

	bar.call("clear_physics_law")
	await get_tree().process_frame
	_ok(bouncy_item.physics_material_override == base_material, "bouncy law should restore original physics material")
	_ok(not bouncy_item.has_meta(HAS_BASE_MATERIAL_META), "bouncy law should clear material presence metadata")
	_ok(not bouncy_item.has_meta(BASE_MATERIAL_META), "bouncy law should clear base material metadata")

	tavern.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("Tavern physics law checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
