extends Node

const OUT_OF_BOUNDS_Y := 900.0
const KILL_Y := 800.0

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_docked_body_recovers_when_out_of_bounds()
	await _test_inventory_spawn_deducts_and_recovers()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-WORKSPACE-SCENE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-WORKSPACE-SCENE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-WORKSPACE-SCENE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_docked_body_recovers_when_out_of_bounds() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as RigidBody2D
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var dock: Vector2 = bar._docks[brewery]
	brewery.sleeping = false
	brewery.linear_velocity = Vector2(10.0, 20.0)
	brewery.angular_velocity = 3.0
	brewery.global_position.y = OUT_OF_BOUNDS_Y
	bar._recover_docked_bodies()

	_ok(brewery.global_position == dock,
		"out-of-bounds brewery returns to its dock: expected %s, got %s" % [dock, brewery.global_position])
	_ok(brewery.linear_velocity == Vector2.ZERO,
		"recovered brewery stops moving: got %s" % brewery.linear_velocity)
	_ok(is_zero_approx(brewery.angular_velocity),
		"recovered brewery stops rotating: got %s" % brewery.angular_velocity)
	_ok(brewery.sleeping, "recovered brewery sleeps at its dock")

	brewery.global_position.y = OUT_OF_BOUNDS_Y
	await get_tree().physics_frame
	await get_tree().process_frame

	_ok(brewery.global_position.y < KILL_Y,
		"physics tick returns out-of-bounds brewery to the playable area: got %s" % brewery.global_position)


func _test_inventory_spawn_deducts_and_recovers() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var gm = get_node("/root/GameManager")
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var before: int = gm.inventory_sys.get_count("ale")
	var item = bar.spawn_inventory_item_at("ale", Vector2(640.0, 420.0))
	_ok(item != null, "inventory-backed spawn creates a desk item")
	_ok(gm.inventory_sys.get_count("ale") == before - 1, "inventory-backed spawn deducts one item")

	item.global_position.y = OUT_OF_BOUNDS_Y
	await get_tree().physics_frame
	await get_tree().process_frame

	_ok(gm.inventory_sys.get_count("ale") == before, "out-of-bounds material recovery restores inventory")
