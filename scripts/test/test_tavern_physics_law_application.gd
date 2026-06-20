extends Node

const TAVERN_SCENE := preload("res://scenes/ui/Tavern.tscn")
const PHYSICS_LAW_SYSTEM := preload("res://scripts/systems/physics_law_system.gd")
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
	await _check_dramatic_release_law_adds_extra_spin_and_impulse()
	await _check_collision_law_kicks_items_apart()
	await _check_customer_pull_law_draws_items_toward_drop_area()
	_finish()


func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _load_default_law(law_id: String) -> Dictionary:
	var system = PHYSICS_LAW_SYSTEM.new()
	_ok(system.load_from_path("res://data/physics_laws.json"), "default physics laws should load")
	var law: Dictionary = system.get_law(law_id)
	_ok(not law.is_empty(), "%s law should exist in default physics data" % law_id)
	return law


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

	var low_gravity := _load_default_law("low_gravity")
	bar.call("apply_physics_law", low_gravity)
	await get_tree().process_frame
	var low_gravity_multiplier := float(low_gravity.get("gravity_scale_multiplier", 1.0))
	_ok(is_equal_approx(first.gravity_scale, base_gravity * low_gravity_multiplier), "existing item should receive gravity law")

	var second := bar._spawn_desk_item_at(Vector2(380, 250), "herb")
	await get_tree().process_frame
	_ok(second.has_meta(BASE_GRAVITY_META), "new item should store base gravity")
	_ok(
		is_equal_approx(second.gravity_scale, float(second.get_meta(BASE_GRAVITY_META)) * low_gravity_multiplier),
		"new item should receive active law")

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

	var slippery_law := _load_default_law("slippery_physics")
	bar.call("apply_physics_law", slippery_law)
	await get_tree().process_frame
	var slippery_linear_damp := float(slippery_law.get("linear_damp_multiplier", 1.0))
	var slippery_angular_damp := float(slippery_law.get("angular_damp_multiplier", 1.0))
	_ok(slippery_item.has_meta(BASE_LINEAR_DAMP_META), "slippery law should store base linear damp")
	_ok(slippery_item.has_meta(BASE_ANGULAR_DAMP_META), "slippery law should store base angular damp")
	_ok(is_equal_approx(slippery_item.linear_damp, base_linear_damp * slippery_linear_damp), "slippery law should reduce linear damp")
	_ok(is_equal_approx(slippery_item.angular_damp, base_angular_damp * slippery_angular_damp), "slippery law should reduce angular damp")

	bar.call("clear_physics_law")
	await get_tree().process_frame
	_ok(is_equal_approx(slippery_item.linear_damp, base_linear_damp), "slippery law should restore linear damp")
	_ok(is_equal_approx(slippery_item.angular_damp, base_angular_damp), "slippery law should restore angular damp")
	_ok(not slippery_item.has_meta(BASE_LINEAR_DAMP_META), "slippery law should clear linear damp metadata")
	_ok(not slippery_item.has_meta(BASE_ANGULAR_DAMP_META), "slippery law should clear angular damp metadata")

	var bouncy_item := bar._spawn_desk_item_at(Vector2(380, 250), "herb")
	await get_tree().process_frame
	var base_material = bouncy_item.physics_material_override

	var bouncy_law := _load_default_law("bouncy_physics")
	bar.call("apply_physics_law", bouncy_law)
	await get_tree().process_frame
	_ok(bouncy_item.has_meta(HAS_BASE_MATERIAL_META), "bouncy law should remember whether a base material existed")
	_ok(bouncy_item.has_meta(BASE_MATERIAL_META) or base_material == null, "bouncy law should store base material when one exists")
	_ok(bouncy_item.physics_material_override != null, "bouncy law should install a physics material override")
	_ok(is_equal_approx(bouncy_item.physics_material_override.bounce, float(bouncy_law.get("bounce_override", 0.0))), "bouncy law should override bounce")

	bar.call("clear_physics_law")
	await get_tree().process_frame
	_ok(bouncy_item.physics_material_override == base_material, "bouncy law should restore original physics material")
	_ok(not bouncy_item.has_meta(HAS_BASE_MATERIAL_META), "bouncy law should clear material presence metadata")
	_ok(not bouncy_item.has_meta(BASE_MATERIAL_META), "bouncy law should clear base material metadata")

	tavern.queue_free()
	await get_tree().process_frame


func _check_dramatic_release_law_adds_extra_spin_and_impulse() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null:
		_ok(false, "Tavern should expose BarWorkspace for dramatic release checks")
		tavern.queue_free()
		await get_tree().process_frame
		return

	var item := bar._spawn_desk_item_at(Vector2(540.0, 340.0), "ale")
	await get_tree().process_frame
	item.linear_velocity = Vector2(720.0, -160.0)
	item.angular_velocity = 0.0
	var base_speed := item.linear_velocity.length()

	bar.call("apply_physics_law", _load_default_law("slippery_physics"))
	bar._on_drag_ended(item)
	await get_tree().process_frame

	_ok(item.linear_velocity.length() > base_speed + 115.0, "dramatic default law should add obvious release impulse")
	_ok(absf(item.angular_velocity) >= 16.0, "dramatic default law should add much stronger meme spin")

	tavern.queue_free()
	await get_tree().process_frame


func _check_collision_law_kicks_items_apart() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null:
		_ok(false, "Tavern should expose BarWorkspace for collision law checks")
		tavern.queue_free()
		await get_tree().process_frame
		return

	var left := bar._spawn_desk_item_at(Vector2(500.0, 340.0), "rock_lizard_meat")
	var right := bar._spawn_desk_item_at(Vector2(555.0, 340.0), "black_malt")
	await get_tree().process_frame
	left.linear_velocity = Vector2(260.0, 0.0)
	right.linear_velocity = Vector2(-260.0, 0.0)
	var before_vertical := absf(left.linear_velocity.y) + absf(right.linear_velocity.y)

	bar.call("apply_physics_law", _load_default_law("bouncy_physics"))
	bar._on_item_collision(right, left)
	await get_tree().process_frame

	var after_vertical := absf(left.linear_velocity.y) + absf(right.linear_velocity.y)
	_ok(after_vertical > before_vertical + 220.0, "default collision law should kick colliding items into a visible hop")
	_ok(left.linear_velocity.x < 260.0 or right.linear_velocity.x > -260.0, "collision law should push items away from each other")

	tavern.queue_free()
	await get_tree().process_frame


func _check_customer_pull_law_draws_items_toward_drop_area() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null:
		_ok(false, "Tavern should expose BarWorkspace for customer pull checks")
		tavern.queue_free()
		await get_tree().process_frame
		return
	if not bar.has_method("_apply_active_customer_pull"):
		_ok(false, "BarWorkspace should expose active customer pull behavior")
		tavern.queue_free()
		await get_tree().process_frame
		return

	var item := bar._spawn_desk_item_at(Vector2(340.0, 350.0), "bread")
	await get_tree().process_frame
	item.linear_velocity = Vector2.ZERO
	var drop_area := tavern.get_node("BarWorkspace/CustomerDropArea") as Area2D
	var direction_to_customer := (drop_area.global_position - item.global_position).normalized()

	bar.call("apply_physics_law", _load_default_law("heavy_gravity"))
	bar.call("_apply_active_customer_pull", 1.0)
	await get_tree().process_frame

	_ok(item.linear_velocity.dot(direction_to_customer) > 140.0, "heavy default law should visibly pull loose food toward the customer")

	tavern.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("Tavern physics law checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
