extends Node

const OUT_OF_BOUNDS_Y := 900.0
const KILL_Y := 800.0

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_docked_body_recovers_when_out_of_bounds()
	await _test_inventory_spawn_deducts_and_recovers()
	await _test_inventory_overlay_lists_and_drop()
	await _test_document_overlay_opens_ledger()
	await _test_spoon_renders_below_container_visuals()
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
	tavern.queue_free()
	await get_tree().process_frame


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
	tavern.queue_free()
	await get_tree().process_frame


func _test_inventory_overlay_lists_and_drop() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var gm = get_node("/root/GameManager")
	var overlay = tavern.get_node("InventoryOverlay")
	var items := tavern.get_node("BarWorkspace/World/Items")
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	gm.add_to_inventory("sleep_powder", 1)
	tavern.toggle_inventory_overlay()

	_ok(overlay.visible, "inventory overlay opens")
	_ok(tavern.is_menu_open(), "inventory overlay pauses tavern updates")
	_ok(overlay.get_material_keys().has("ale"), "inventory overlay lists materials")
	_ok(overlay.get_story_keys().has("sleep_powder"), "inventory overlay lists story items")
	_ok(not bar._slot_item_keys.has("sleep_powder"), "shortcut bar excludes story items")

	var before: int = gm.inventory_sys.get_count("ale")
	var item_count: int = items.get_child_count()
	overlay._drop_data(Vector2(20.0, 20.0), {"item_key": "ale"})
	_ok(gm.inventory_sys.get_count("ale") == before - 1, "overlay drop deducts inventory")
	_ok(items.get_child_count() == item_count + 1, "overlay drop spawns a desk item")

	gm.remove_from_inventory("sleep_powder", 1)
	tavern.queue_free()
	await get_tree().process_frame


func _test_document_overlay_opens_ledger() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var gm = get_node("/root/GameManager")
	var overlay = tavern.get_node("DocumentOverlay")
	var ledger = tavern.get_node("BarWorkspace/World/Ledger")
	gm.documents.add_ledger_entry("第二页")
	gm.documents.add_ledger_entry("第三页")
	ledger.request_open()

	_ok(InputMap.has_action("ledger_toggle"), "ledger toggle input exists")
	_ok(overlay.visible, "ledger opens document overlay")
	_ok(tavern.is_menu_open(), "document overlay pauses tavern updates")
	_ok(overlay.get_current_page_text() != "", "ledger renders a page")
	_ok(overlay.get_right_page_text() == "第二页", "ledger renders a two-page spread")
	overlay.next_page()
	_ok(overlay.get_current_page_text() == "第三页", "ledger arrow advances by one spread")
	overlay.previous_page()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(500.0, 200.0)
	overlay._on_panel_gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(100.0, 200.0)
	overlay._on_panel_gui_input(release)
	_ok(overlay.get_current_page_text() == "第三页", "ledger drag beyond threshold advances one spread")

	tavern.queue_free()
	await get_tree().process_frame


func _test_spoon_renders_below_container_visuals() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var spoon := tavern.get_node("BarWorkspace/World/Spoon") as StirSpoon
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var surface_z_index := spoon.z_index
	var containers: Array = [
		[tavern.get_node("BarWorkspace/World/Brewery"), tavern.get_node("BarWorkspace/World/Brewery/Mouth")],
		[tavern.get_node("BarWorkspace/World/Grill"), tavern.get_node("BarWorkspace/World/Grill/Intake")],
		[tavern.get_node("BarWorkspace/World/Pot"), tavern.get_node("BarWorkspace/World/Pot/Intake")],
	]
	spoon.freeze = true
	var tip_offset := spoon.tip_global_position() - spoon.global_position
	for pair in containers:
		var container = pair[0]
		var area: Area2D = pair[1]
		spoon.global_position = area.global_position - tip_offset
		bar._update_spoon_depth()
		_ok(container.is_spoon_inside(spoon),
			"spoon tip enters %s during depth test" % container.name)
		_ok(spoon.z_index < 0,
			"spoon renders below %s while inside: got z_index %d" % [container.name, spoon.z_index])

	var wash_basin := tavern.get_node("BarWorkspace/World/WashBasin") as Area2D
	spoon.global_position = wash_basin.global_position - tip_offset
	bar._update_spoon_depth()
	_ok(spoon.z_index < 0,
		"spoon renders below WashBasin while inside: got z_index %d" % spoon.z_index)

	spoon.global_position = Vector2(120.0, 120.0)
	bar._update_spoon_depth()
	_ok(spoon.z_index == surface_z_index,
		"spoon restores surface depth after leaving containers: expected %d, got %d" % [surface_z_index, spoon.z_index])

	tavern.queue_free()
	await get_tree().process_frame
