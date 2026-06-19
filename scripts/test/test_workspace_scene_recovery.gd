extends Node

const OUT_OF_BOUNDS_Y := 900.0
const KILL_Y := 800.0

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_runtime_ui_avoids_test_resource_paths()
	await _test_docked_body_recovers_when_out_of_bounds()
	await _test_inventory_spawn_deducts_and_recovers()
	await _test_fast_desk_items_emit_motion_trails()
	await _test_fast_containers_emit_motion_trails()
	await _test_side_table_walls_disabled_and_product_falls_back_to_surface()
	await _test_desk_items_released_on_open_inventory_overlay_return_only_backpack_items()
	await _test_material_drop_on_customer_area_stays_on_desk()
	await _test_failed_products_drop_on_customer_area_stays_on_desk()
	await _test_inventory_overlay_lists_and_drop()
	await _test_inventory_drop_binds_shortcut_slot()
	await _test_shortcut_drag_starts_above_table_baseline()
	await _test_document_overlay_opens_ledger()
	await _test_work_surface_ledger_can_be_dragged()
	await _test_container_ejection_spawns_lifo_desk_items()
	await _test_seasoning_items_fit_into_shaker_mouth()
	await _test_shaker_absorbed_dragged_seasoning_clears_drag_state()
	await _test_seasoning_shaker_spawns_powder_while_moving()
	await _test_barrel_shake_spawns_persistent_upward_bubbles()
	await _test_grape_desk_item_loads_into_barrel_mouth()
	await _test_shortcut_malt_released_inside_barrel_loads()
	await _test_dragged_barrel_shakes_grape_into_wine()
	await _test_grill_press_finish_and_burn_feedback_effects()
	await _test_good_barrel_brew_spawns_celebration()
	await _test_pot_effects_follow_ingredients_and_real_stirring()
	await _test_spoon_drag_keeps_cursor_free_while_pot_uses_thick_walls()
	await _test_spoon_renders_below_container_visuals()
	await _test_held_items_render_below_container_visuals()
	await _test_settings_menu_entry()
	await _test_overlay_menu_clickable_during_menu_preparation()
	await _test_overlay_menu_renders_above_workspace()
	await _test_recipe_menu_uses_split_layout()
	await _test_recipe_book_shows_hand_combine_tab()
	await _test_recipe_book_shows_dough_operation()
	await _test_recipe_book_hides_undiscovered_entries()
	await _test_first_crafted_recipe_discovers_recipe()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-WORKSPACE-SCENE] FAIL: " + msg)


func _test_runtime_ui_avoids_test_resource_paths() -> void:
	var runtime_paths := [
		"res://scenes/ui/Tavern.tscn",
		"res://scripts/ui/bar_workspace.gd",
		"res://scripts/ui/brewery.gd",
		"res://scripts/ui/brew_shake_meter.gd",
		"res://scripts/ui/kitchen_container.gd",
		"res://scripts/ui/seasoning_shaker.gd",
		"res://scripts/ui/components/desk_item_spawner.gd",
	]
	for path in runtime_paths:
		var file := FileAccess.open(path, FileAccess.READ)
		_ok(file != null, "runtime UI file exists: " + path)
		if file == null:
			continue
		var text := file.get_as_text()
		file.close()
		_ok(not text.contains("res://scenes/test/"), path + " does not reference test scenes")
		_ok(not text.contains("res://scripts/test/"), path + " does not reference test scripts")


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return String(texture.resource_path)


func _stylebox_texture_path(control: Control, style_name: String) -> String:
	var stylebox := control.get_theme_stylebox(style_name) as StyleBoxTexture
	if stylebox == null:
		return ""
	return _texture_path(stylebox.texture)


func _reset_game_for_recipe_discovery_test() -> void:
	GameManager._apply_save_state(GameManager._default_new_game_state())
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null:
		tm.tavern_first_entered = true
		tm.first_guest_arrived = true


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


func _test_fast_desk_items_emit_motion_trails() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var slow_item := bar._spawn_desk_item_at(Vector2(520.0, 360.0), "ale")
	slow_item.sleeping = false
	slow_item.linear_velocity = Vector2(40.0, 0.0)
	for i in range(4):
		await get_tree().physics_frame
		await get_tree().process_frame
	_ok(_desk_item_motion_trail_count(slow_item) == 0,
		"slow desk item stays visually quiet below the trail threshold")
	slow_item.queue_free()

	var fast_item := bar._spawn_desk_item_at(Vector2(620.0, 360.0), "grape")
	fast_item.sleeping = false
	fast_item.linear_velocity = Vector2(520.0, -90.0)
	for i in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	_ok(fast_item.get_node_or_null("MotionTrail") is Node2D,
		"fast desk item creates a dedicated motion trail layer")
	_ok(_desk_item_motion_trail_count(fast_item) >= 2,
		"fast desk item emits visible speed-driven trail sprites")
	_ok(_desk_item_motion_trail_count(fast_item) <= 12,
		"fast desk item trail keeps a strict active sprite cap")

	fast_item.queue_free()
	tavern.queue_free()
	await get_tree().process_frame


func _test_fast_containers_emit_motion_trails() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	bar.configure_day(3)
	await get_tree().process_frame

	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	var grill := tavern.get_node("BarWorkspace/World/Grill") as KitchenContainer
	var pot := tavern.get_node("BarWorkspace/World/Pot") as KitchenContainer

	brewery.sleeping = false
	brewery.linear_velocity = Vector2(54.0, 0.0)
	for i in range(4):
		await get_tree().physics_frame
		await get_tree().process_frame
	_ok(_physics_body_motion_trail_count(brewery) == 0,
		"slow brewery movement stays visually quiet below the trail threshold")

	for body in [brewery, grill, pot]:
		var rigid_body := body as RigidBody2D
		rigid_body.freeze = false
		rigid_body.sleeping = false
		for i in range(6):
			rigid_body.global_position += Vector2(34.0, -7.0)
			rigid_body.linear_velocity = Vector2.ZERO
			await get_tree().physics_frame
			await get_tree().process_frame
		_ok(rigid_body.get_node_or_null("MotionTrail") is Node2D,
			"%s creates a motion trail layer when moved quickly" % rigid_body.name)
		_ok(_physics_body_motion_trail_count(rigid_body) >= 2,
			"%s emits visible speed-driven trail sprites" % rigid_body.name)
		_ok(_physics_body_motion_trail_count(rigid_body) <= 12,
			"%s motion trail keeps a strict active sprite cap" % rigid_body.name)

	for body in [brewery, grill, pot]:
		var rigid_body := body as RigidBody2D
		rigid_body.linear_velocity = Vector2.ZERO
		rigid_body.angular_velocity = 0.0
		if bar._docks.has(rigid_body):
			rigid_body.global_position = bar._docks[rigid_body]
		rigid_body.sleeping = true
	await get_tree().physics_frame
	await get_tree().process_frame

	tavern.queue_free()
	await get_tree().physics_frame
	await get_tree().process_frame


func _test_side_table_walls_disabled_and_product_falls_back_to_surface() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var left_wall := tavern.get_node("BarWorkspace/World/Walls/LeftWall") as CollisionShape2D
	var right_wall := tavern.get_node("BarWorkspace/World/Walls/RightWall") as CollisionShape2D
	_ok(left_wall.disabled, "left table air wall is disabled")
	_ok(right_wall.disabled, "right table air wall is disabled")

	var gm = get_node("/root/GameManager")
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var wine_before: int = gm.inventory_sys.get_count("wine")
	var item := bar._spawn_desk_item_at(Vector2(1180.0, 510.0), "wine")
	_ok(item != null, "product recovery test creates a wine desk item")
	if item != null:
		item.global_position = Vector2(1320.0, OUT_OF_BOUNDS_Y)
		item.linear_velocity = Vector2(240.0, 360.0)
		item.angular_velocity = 5.0
		await get_tree().physics_frame
		await get_tree().process_frame
		_ok(is_instance_valid(item) and not item.is_queued_for_deletion(),
			"out-of-bounds product is kept as a desk item")
		_ok(gm.inventory_sys.get_count("wine") == wine_before,
			"out-of-bounds product is not added to backpack inventory")
		_ok(item.global_position.y >= 470.0 and item.global_position.y <= 520.0,
			"out-of-bounds product returns to the visible table surface: got %s" % item.global_position)
		_ok(item.global_position.x >= 260.0 and item.global_position.x <= 1020.0,
			"out-of-bounds product return point is clamped inside the table: got %s" % item.global_position)
		_ok(item.linear_velocity == Vector2.ZERO and is_zero_approx(item.angular_velocity),
			"out-of-bounds product returns without leftover fall velocity")
		var recovered_position := item.global_position
		for i in range(16):
			await get_tree().physics_frame
		await get_tree().process_frame
		_ok(item.global_position.y <= recovered_position.y + 6.0,
			"recovered product stays on the table instead of falling again: recovered %s, now %s" % [recovered_position, item.global_position])
		_ok(item.global_position.y < KILL_Y,
			"recovered product remains inside the playable area after physics settles: got %s" % item.global_position)
		_ok(item.linear_velocity.y <= 20.0,
			"recovered product does not resume downward fall velocity: got %s" % item.linear_velocity)
		_left_press(bar, item.global_position)
		await get_tree().process_frame
		_ok(bar._drag_ctrl.get_body() == item,
			"recovered product can be picked up again after being stabilized")
		_ok(not item.freeze,
			"recovered product unfreezes when the player picks it up again")
		bar._drag_ctrl.end_drag()
		item.queue_free()
	tavern.queue_free()
	await get_tree().process_frame


func _test_desk_items_released_on_open_inventory_overlay_return_only_backpack_items() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var gm = get_node("/root/GameManager")
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var overlay := tavern.get_node("InventoryOverlay") as InventoryOverlay
	var panel := overlay.get_node("Panel") as Panel
	var drop_pos := panel.global_position + Vector2(48.0, 48.0)

	gm.add_to_inventory("bloodied_contract", 1)
	var contract_before: int = gm.inventory_sys.get_count("bloodied_contract")
	var contract_item := bar.spawn_inventory_item_at("bloodied_contract", Vector2(640.0, 420.0))
	_ok(contract_item != null, "bloodied contract desk item can be spawned from inventory")
	_ok(gm.inventory_sys.get_count("bloodied_contract") == contract_before - 1,
		"bloodied contract spawn deducts the story item from inventory")

	overlay.open()
	await get_tree().process_frame
	_release_dragged_body_at(bar, contract_item, drop_pos)
	await get_tree().process_frame

	_ok(gm.inventory_sys.get_count("bloodied_contract") == contract_before,
		"bloodied contract released on open backpack returns to inventory")
	_ok(not is_instance_valid(contract_item) or contract_item.is_queued_for_deletion(),
		"bloodied contract released on open backpack is removed from the desk")

	var wine_before: int = gm.inventory_sys.get_count("wine")
	var wine_item := bar._spawn_desk_item_at(Vector2(640.0, 420.0), "wine")
	_ok(wine_item != null, "product desk item can be spawned for backpack rejection test")

	_release_dragged_body_at(bar, wine_item, drop_pos)
	await get_tree().process_frame

	_ok(gm.inventory_sys.get_count("wine") == wine_before,
		"product released on open backpack is not added to inventory")
	_ok(is_instance_valid(wine_item) and not wine_item.is_queued_for_deletion(),
		"product released on open backpack stays on the desk")
	if is_instance_valid(wine_item):
		wine_item.queue_free()
	overlay.close()
	tavern.queue_free()
	await get_tree().process_frame


func _release_dragged_body_at(bar: BarWorkspace, body: RigidBody2D, global_pos: Vector2) -> void:
	body.global_position = global_pos
	bar._drag_ctrl.start_drag(body, global_pos)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = global_pos
	release.global_position = global_pos
	bar._unhandled_input(release)


func _test_material_drop_on_customer_area_stays_on_desk() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var drop_area := tavern.get_node("BarWorkspace/CustomerDropArea") as Area2D
	var items := tavern.get_node("BarWorkspace/World/Items")
	var before_count := items.get_child_count()
	var item := bar._spawn_desk_item_at(drop_area.global_position, "ale")
	_ok(item != null, "customer-area material test creates a desk item")
	if item != null:
		item.linear_velocity = Vector2.ZERO
		item.angular_velocity = 0.0
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		_ok(drop_area.get_overlapping_bodies().has(item),
			"customer-area material test item overlaps the drop area")
		bar._try_deliver(item)
		await get_tree().process_frame
		_ok(is_instance_valid(item) and not item.is_queued_for_deletion(),
			"plain material dropped on the customer area remains on the desk")
		_ok(items.get_child_count() == before_count + 1,
			"plain material dropped on the customer area is not removed from world items")
		if is_instance_valid(item):
			item.queue_free()
	tavern.queue_free()
	await get_tree().process_frame


func _test_failed_products_drop_on_customer_area_stays_on_desk() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var gm = get_node("/root/GameManager")
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var drop_area := tavern.get_node("BarWorkspace/CustomerDropArea") as Area2D
	var items := tavern.get_node("BarWorkspace/World/Items")
	var failed_keys := ["failed_brew", "failed_stew"]

	for failed_key in failed_keys:
		var guest := GuestData.new()
		guest.type = GuestData.GuestType.NORMAL
		guest.order_key = "ale_beer"
		guest.has_dialogue = false
		guest.npc_id = "failed_product_test"
		gm.guests.current_guest = guest
		gm.guests.has_guest = true
		gm._guest_lingering = false

		var failed_before: int = gm.guests.orders_failed
		var served_before: int = gm.guests.guests_served_today
		var before_count := items.get_child_count()
		var item := bar._spawn_desk_item_at(drop_area.global_position, failed_key)
		_ok(item != null, "%s customer-area test creates a desk item" % failed_key)
		if item != null:
			item.linear_velocity = Vector2.ZERO
			item.angular_velocity = 0.0
			await get_tree().physics_frame
			await get_tree().physics_frame
			await get_tree().physics_frame
			_ok(drop_area.get_overlapping_bodies().has(item),
				"%s overlaps the customer drop area" % failed_key)
			bar._try_deliver(item)
			await get_tree().process_frame
			_ok(is_instance_valid(item) and not item.is_queued_for_deletion(),
				"%s is not consumed as a deliverable order item" % failed_key)
			_ok(items.get_child_count() == before_count + 1,
				"%s remains on the work surface after customer-area drop" % failed_key)
			if is_instance_valid(item):
				item.queue_free()
				await get_tree().process_frame
		_ok(gm.guests.orders_failed == failed_before,
			"%s does not record a failed order when dropped on a customer" % failed_key)
		_ok(gm.guests.guests_served_today == served_before,
			"%s does not count the guest as served" % failed_key)
		_ok(gm.guests.has_guest and gm.guests.current_guest == guest,
			"%s leaves the waiting guest active" % failed_key)
		gm.guests.has_guest = false
		gm.guests.current_guest = null
		gm._guest_lingering = false

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
	var slot0 := tavern.get_node("ShortcutBar/Slot0") as ColorRect
	_ok(slot0.get_node_or_null("BrushBackground") != null, "shortcut slot uses brush background")
	_ok(slot0.get_node_or_null("Icon") != null, "shortcut slot renders an icon node")
	_ok(slot0.get_node_or_null("Count") != null, "shortcut slot renders a count node")
	var shortcut_slot_frame := slot0.get_node_or_null("BrushBackground") as TextureRect
	_ok(shortcut_slot_frame != null and _texture_path(shortcut_slot_frame.texture) == "res://assets/textures/ui/shortcut_slot_filled.png",
		"filled shortcut slot uses the dedicated Tavern shortcut art")
	ThemeColors.set_shortcut_slot_hover(slot0, true)
	_ok(shortcut_slot_frame != null and _texture_path(shortcut_slot_frame.texture) == "res://assets/textures/ui/shortcut_slot_hover.png",
		"shortcut slot hover uses dedicated hover art")
	ThemeColors.set_shortcut_slot_hover(slot0, false)
	_ok(shortcut_slot_frame != null and _texture_path(shortcut_slot_frame.texture) == "res://assets/textures/ui/shortcut_slot_filled.png",
		"shortcut slot returns to filled art after hover")
	gm.add_to_inventory("sleep_powder", 1)
	tavern.toggle_inventory_overlay()

	_ok(overlay.visible, "inventory overlay opens")
	_ok(tavern.is_menu_open(), "inventory overlay pauses tavern updates")
	var inventory_panel := overlay.get_node("Panel") as Panel
	_ok(_stylebox_texture_path(inventory_panel, "panel") == "res://assets/textures/ui/inventory_panel.png",
		"inventory overlay uses dedicated backpack panel art")
	var material_title := overlay.get_node("Panel/MaterialTitle") as Label
	_ok(material_title != null and not material_title.visible and material_title.text == "",
		"inventory overlay hides the obsolete item section title")
	var material_list := overlay.get_node("Panel/MaterialList") as Control
	var story_list := overlay.get_node("Panel/StoryList") as Control
	var material_grid := material_list.get_node_or_null("MaterialGrid") as GridContainer
	var story_grid := story_list.get_node_or_null("StoryGrid") as GridContainer
	_ok(material_grid != null, "inventory renders a unified item grid container")
	_ok(story_grid != null, "inventory keeps story grid compatibility node")
	_ok(material_grid != null and material_grid.columns == 5, "inventory unified grid uses a natural five-column layout")
	_ok(material_list.position.x >= 72.0 and material_list.position.x <= 84.0,
		"inventory unified grid starts closer to the panel edge")
	_ok(inventory_panel.size.x - (material_list.position.x + material_list.size.x) >= 72.0
		and inventory_panel.size.x - (material_list.position.x + material_list.size.x) <= 84.0,
		"inventory unified grid ends closer to the panel edge")
	_ok(material_list.size.x == 464.0, "inventory unified grid width matches five 80px slots plus wider horizontal spacing")
	_ok(material_list.position.y >= 92.0 and material_list.position.y <= 108.0,
		"inventory unified grid starts below the title with comfortable top spacing")
	if material_grid != null:
		_ok(material_grid.get_theme_constant("h_separation") == 16 and material_grid.get_theme_constant("v_separation") == 10,
			"inventory unified grid uses wider horizontal spacing while keeping vertical rhythm")
	_ok(story_grid != null and story_grid.get_child_count() == 0,
		"inventory no longer renders a separate story item grid")
	_ok(not story_list.visible, "inventory hides the old story item section")
	_ok(material_grid != null and material_grid.get_child_count() > 0, "inventory unified grid renders item slots")
	_ok(overlay.get_material_keys().has("ale"), "inventory overlay lists materials")
	_ok(overlay.get_story_keys().has("sleep_powder"), "inventory overlay lists story items")
	_ok(not bar._slot_item_keys.has("sleep_powder"), "shortcut bar excludes story items")
	if material_grid != null:
		var ale_slot := _find_grid_slot_by_item_key(material_grid, "ale")
		_ok(ale_slot != null, "inventory material grid has an ale slot")
		if ale_slot != null:
			_ok(ale_slot.custom_minimum_size == Vector2(80.0, 80.0),
				"inventory grid slot uses the native 80px square art size")
			_ok(ale_slot.get_node_or_null("Icon") != null, "inventory grid slot renders an icon node")
			_ok(_stylebox_texture_path(ale_slot, "normal") == "res://assets/textures/ui/inventory_slot_normal.png",
				"inventory grid slot uses pixel slot art")
			var count_label := ale_slot.get_node_or_null("Count") as Label
			_ok(count_label != null and count_label.text.begins_with("x"),
				"inventory grid slot renders a stack count")
			var drag_data = ale_slot._get_drag_data(Vector2(8.0, 8.0))
			_ok(drag_data is Dictionary and String(drag_data.get("item_key", "")) == "ale",
				"inventory grid slot keeps drag payload compatibility")
			ale_slot.emit_signal("mouse_entered")
			await get_tree().process_frame
			var tooltip := overlay.get_node_or_null("Panel/ItemTooltip") as PanelContainer
			_ok(tooltip != null and tooltip.visible, "hovering an inventory grid slot shows an item tooltip")
			var tooltip_title := tooltip.get_node_or_null("VBox/Title") as Label if tooltip != null else null
			var tooltip_count := tooltip.get_node_or_null("VBox/Count") as Label if tooltip != null else null
			_ok(tooltip_title != null and tooltip_title.text != "",
				"inventory item tooltip shows the item name")
			_ok(tooltip_count != null and tooltip_count.text.find(str(gm.inventory_sys.get_count("ale"))) >= 0,
				"inventory item tooltip shows the stack count")
			ale_slot.emit_signal("mouse_exited")
			await get_tree().process_frame
			_ok(tooltip != null and not tooltip.visible, "leaving an inventory grid slot hides the item tooltip")
	if material_grid != null:
		var sleep_slot := _find_grid_slot_by_item_key(material_grid, "sleep_powder")
		_ok(sleep_slot != null, "inventory unified grid includes sleep_powder story item")

	var before: int = gm.inventory_sys.get_count("ale")
	var item_count: int = items.get_child_count()
	overlay._drop_data(Vector2(20.0, 20.0), {"item_key": "ale"})
	_ok(gm.inventory_sys.get_count("ale") == before - 1, "overlay drop deducts inventory")
	_ok(items.get_child_count() == item_count + 1, "overlay drop spawns a desk item")

	for material_key in ["ale", "grape", "flour", "meat_raw", "herb", "spice", "herb_spice", "salt"]:
		var before_count: int = gm.inventory_sys.get_count(material_key)
		var desk_item: DeskItem = bar.spawn_inventory_item_at(material_key, Vector2(640.0, 420.0))
		_ok(desk_item != null, material_key + " shortcut spawn creates a desk item")
		_ok(gm.inventory_sys.get_count(material_key) == before_count - 1,
			material_key + " desk item spawn deducts inventory")
		var icon_art: Sprite2D = null
		if desk_item != null:
			icon_art = desk_item.get_node_or_null("IconArt") as Sprite2D
		_ok(icon_art != null, material_key + " desk item has IconArt")
		_ok(icon_art != null and icon_art.texture != null, material_key + " desk item renders texture art")
		if icon_art != null and icon_art.texture != null:
			if gm.seasoning.is_seasoning(material_key):
				_ok(String(icon_art.texture.resource_path).ends_with("assets/textures/icons/items/%s.png" % material_key),
					material_key + " desk item uses the seasoning item icon")
			else:
				_ok(String(icon_art.texture.resource_path).ends_with("assets/textures/tavern/icons/%s.png" % material_key),
					material_key + " desk item uses the Tavern item icon")
			_ok(icon_art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
				material_key + " desk item texture uses nearest filtering")
		if desk_item != null:
			desk_item.queue_free()
			gm.add_to_inventory(material_key, 1)

	var sleep_before: int = gm.inventory_sys.get_count("sleep_powder")
	var sleep_item: DeskItem = bar.spawn_inventory_item_at("sleep_powder", Vector2(640.0, 420.0))
	_ok(sleep_item != null, "sleep_powder inventory spawn creates a desk item")
	_ok(gm.inventory_sys.get_count("sleep_powder") == sleep_before - 1,
		"sleep_powder desk item spawn deducts inventory")
	var sleep_art := sleep_item.get_node_or_null("IconArt") as Sprite2D if sleep_item != null else null
	_ok(sleep_art != null and sleep_art.texture != null, "sleep_powder desk item renders texture art")
	if sleep_art != null and sleep_art.texture != null:
		_ok(String(sleep_art.texture.resource_path).ends_with("assets/textures/icons/items/sleep_powder.png"),
			"sleep_powder desk item uses the seasoning item icon")
	if sleep_item != null:
		sleep_item.queue_free()
		gm.add_to_inventory("sleep_powder", 1)
	for textured_key in ["dough", "herb_tea", "wine", "toby_contract"]:
		var textured_item := bar._spawn_desk_item_at(Vector2(640.0, 420.0), textured_key)
		_ok(textured_item != null, textured_key + " direct desk spawn creates an item")
		var textured_art := textured_item.get_node_or_null("IconArt") as Sprite2D if textured_item != null else null
		_ok(textured_art != null and textured_art.texture != null,
			textured_key + " desk item renders mapped item art")
		if textured_art != null and textured_art.texture != null:
			_ok(String(textured_art.texture.resource_path).begins_with("res://assets/textures/tavern/items/"),
				textured_key + " desk item uses the Tavern item texture set")
		if textured_item != null:
			textured_item.queue_free()
	gm.remove_from_inventory("sleep_powder", 1)
	tavern.queue_free()
	await get_tree().process_frame


func _test_inventory_drop_binds_shortcut_slot() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.add_to_inventory("north_sour_grape", 1)
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	bar._init_material_slots()
	var items := tavern.get_node("BarWorkspace/World/Items")
	var slot7 := tavern.get_node("ShortcutBar/Slot7") as Control
	var slot_center := slot7.global_position + slot7.size * 0.5
	var before_items: int = items.get_child_count()

	_ok(bar.has_method("bind_shortcut_at_position"), "BarWorkspace exposes shortcut drop binding")
	tavern._on_inventory_item_dropped("north_sour_grape", slot_center)
	await get_tree().process_frame

	var bindings: Array = gm.get_shortcut_bindings()
	_ok(bindings[7] == "north_sour_grape", "inventory drop on slot7 binds the rare material")
	_ok(bar._slot_item_keys.size() > 7 and bar._slot_item_keys[7] == "north_sour_grape",
		"slot7 renders the bound rare material")
	_ok(gm.inventory_sys.get_count("north_sour_grape") == 1, "binding does not consume inventory")
	_ok(items.get_child_count() == before_items, "binding does not spawn a desk item")

	var spawned := bar.spawn_inventory_item_at("north_sour_grape", slot_center + Vector2(0.0, -120.0))
	_ok(spawned != null, "bound rare material can still spawn as a desk item")
	_ok(gm.inventory_sys.get_count("north_sour_grape") == 0, "spawning consumes inventory, not binding")
	if spawned != null:
		spawned.queue_free()
	tavern.queue_free()
	await get_tree().process_frame


func _test_shortcut_drag_starts_above_table_baseline() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var slot0 := tavern.get_node("ShortcutBar/Slot0") as Control
	var ground := tavern.get_node("BarWorkspace/World/Walls/Ground") as CollisionShape2D
	var segment := ground.shape as SegmentShape2D
	var baseline_y := segment.a.y
	var slot_center := slot0.global_position + slot0.size * 0.5
	_left_press(bar, slot_center)
	var dragged := bar._drag_ctrl.get_body() as DeskItem
	_ok(dragged != null, "shortcut press starts dragging a spawned desk item")
	_ok(dragged != null and dragged.global_position.y < baseline_y,
		"shortcut-spawned item starts on the playable side of the table baseline: item %.2f, baseline %.2f" % [dragged.global_position.y if dragged != null else 9999.0, baseline_y])
	var preview := bar.get_node_or_null("ShortcutDragPreview") as Sprite2D
	_ok(preview != null and preview.visible,
		"shortcut drag shows a cursor-following preview before the cursor reaches the tabletop")
	_ok(preview != null and preview.global_position.distance_to(slot_center) <= 1.0,
		"shortcut drag preview starts under the cursor: got %s, expected %s" % [preview.global_position if preview != null else Vector2.INF, slot_center])
	_ok(dragged != null and not dragged.visible,
		"real shortcut-spawned body stays hidden while the visual preview is below the table")
	_ok(dragged != null and dragged.collision_layer == 0 and dragged.collision_mask == 0,
		"hidden shortcut-spawned body does not collide while preview is below the table")

	var motion := InputEventMouseMotion.new()
	motion.position = slot_center
	motion.global_position = slot_center
	bar._input(motion)
	for _i in range(6):
		await get_tree().physics_frame
	_ok(dragged != null and is_instance_valid(dragged) and dragged.global_position.y < baseline_y,
		"shortcut drag target below the table does not pull the held item through the baseline: item %.2f, baseline %.2f" % [dragged.global_position.y if dragged != null and is_instance_valid(dragged) else 9999.0, baseline_y])
	preview = bar.get_node_or_null("ShortcutDragPreview") as Sprite2D
	_ok(preview != null and preview.visible and preview.global_position.distance_to(slot_center) <= 1.0,
		"shortcut drag preview keeps following the cursor below the table")

	var table_drag_pos := Vector2(slot_center.x, baseline_y - 96.0)
	motion.position = table_drag_pos
	motion.global_position = table_drag_pos
	bar._input(motion)
	await get_tree().physics_frame
	preview = bar.get_node_or_null("ShortcutDragPreview") as Sprite2D
	_ok(preview == null or not preview.visible,
		"shortcut drag preview clears once the cursor reaches the playable tabletop")
	_ok(dragged != null and is_instance_valid(dragged) and dragged.visible,
		"real shortcut-spawned body becomes visible once the cursor reaches the tabletop")
	_ok(dragged != null and is_instance_valid(dragged) and dragged.collision_layer != 0 and dragged.collision_mask != 0,
		"real shortcut-spawned body restores collision once it reaches the tabletop")

	bar._drag_ctrl.end_drag()
	if dragged != null and is_instance_valid(dragged):
		dragged.queue_free()
	tavern.queue_free()
	await get_tree().process_frame


func _test_document_overlay_opens_ledger() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var gm = get_node("/root/GameManager")
	var overlay = tavern.get_node("DocumentOverlay")
	var ledger = tavern.get_node("BarWorkspace/World/Ledger")
	var existing_pages: Array = gm.documents.get_document("ledger").get("pages", [])
	var first_new_page_index := existing_pages.size()
	var second_page := "测试账本第二页"
	var third_page := "测试账本第三页"
	var fourth_page := "测试账本第四页"
	gm.documents.add_ledger_entry(second_page)
	gm.documents.add_ledger_entry(third_page)
	gm.documents.add_ledger_entry(fourth_page)
	ledger.request_open()

	_ok(InputMap.has_action("ledger_toggle"), "ledger toggle input exists")
	_ok(overlay.visible, "ledger opens document overlay")
	_ok(tavern.is_menu_open(), "document overlay pauses tavern updates")
	_ok(overlay.get_current_page_text() != "", "ledger renders a page")
	var target_spread_start := first_new_page_index - (first_new_page_index % 2)
	for _i in range(int(target_spread_start / 2)):
		overlay.next_page()
	if first_new_page_index % 2 == 0:
		_ok(overlay.get_current_page_text() == second_page and overlay.get_right_page_text() == third_page,
			"ledger renders newly added entries as a two-page spread")
	else:
		_ok(overlay.get_right_page_text() == second_page,
			"ledger renders newly added right-side entry in an existing spread")
	overlay.next_page()
	var expected_next_left := fourth_page if first_new_page_index % 2 == 0 else third_page
	_ok(overlay.get_current_page_text() == expected_next_left, "ledger arrow advances by one spread")
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
	_ok(overlay.get_current_page_text() == expected_next_left, "ledger drag beyond threshold advances one spread")

	tavern.queue_free()
	await get_tree().process_frame


func _test_work_surface_ledger_can_be_dragged() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().physics_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var ledger := tavern.get_node("BarWorkspace/World/Ledger") as ReadableDeskItem
	var ledger_body := ledger as RigidBody2D
	_ok(ledger_body != null, "work-surface ledger is a RigidBody2D so DragController can hold it")
	_ok(ledger.visible and ledger.input_pickable, "work-surface ledger remains visible and pickable")
	var original_position := ledger.global_position
	_left_press(bar, original_position)
	_ok(bar._drag_ctrl.get_body() == ledger_body,
		"pressing the work-surface ledger starts a DragController drag")
	_ok(ledger_body != null and not ledger_body.lock_rotation,
		"dragged work-surface ledger keeps rotation unlocked for pin physics")
	_ok(bar._drag_ctrl._joint != null and bar._drag_ctrl._joint.node_b == ledger_body.get_path(),
		"work-surface ledger is attached through the shared PinJoint2D drag system")

	var target := original_position + Vector2(90.0, -24.0)
	var motion := InputEventMouseMotion.new()
	motion.position = target
	motion.global_position = target
	bar._input(motion)
	await get_tree().physics_frame
	var anchor = bar._drag_ctrl._anchor
	_ok(anchor != null and anchor.global_position == target,
		"dragging the work-surface ledger moves the drag anchor to the cursor")
	bar._drag_ctrl.end_drag()
	_ok(not bar._drag_ctrl.is_dragging(), "releasing the work-surface ledger clears drag state")

	var opened: Array[String] = []
	ledger.open_requested.connect(func(document_id: String): opened.append(document_id))
	ledger.request_open()
	_ok(opened == ["ledger"], "draggable work-surface ledger still opens the ledger document")

	tavern.queue_free()
	await get_tree().process_frame


func _test_container_ejection_spawns_lifo_desk_items() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var items := tavern.get_node("BarWorkspace/World/Items")
	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	brewery._pending_keys = ["ale", "herb"]
	var before := items.get_child_count()
	_right_click(bar, brewery.global_position)
	_ok(items.get_child_count() == before + 1, "barrel right-click eject spawns one desk item")
	var spawned = items.get_child(items.get_child_count() - 1)
	_ok(spawned.item_key == "herb", "barrel ejects newest ingredient first")
	_ok(brewery._pending_keys == ["ale"], "barrel keeps older ingredient")

	var shaker := tavern.get_node("BarWorkspace/World/SeasoningShaker") as SeasoningShaker
	shaker.load_seasoning("spice")
	before = items.get_child_count()
	_right_click(bar, shaker.global_position)
	_ok(items.get_child_count() == before + 1, "seasoning shaker right-click eject spawns one desk item")
	spawned = items.get_child(items.get_child_count() - 1)
	_ok(spawned.item_key == "spice", "seasoning shaker ejects the loaded seasoning")
	_ok(shaker.loaded_key == "", "seasoning shaker is empty after right-click eject")
	var initial_local := shaker.to_local(spawned.global_position)
	_ok(absf(initial_local.x) <= 10.0 and initial_local.y >= -52.0 and initial_local.y <= -24.0,
		"seasoning shaker eject starts at the visible mouth: got %s" % initial_local)
	_ok(spawned.linear_velocity.x >= 240.0 and spawned.linear_velocity.y <= -330.0,
		"seasoning shaker eject uses a strong outward pop: got %s" % spawned.linear_velocity)
	for i in range(24):
		await get_tree().physics_frame
	_ok(is_instance_valid(spawned) and not spawned.is_queued_for_deletion(),
		"seasoning shaker ejected seasoning remains on the desk after physics updates")
	_ok(shaker.loaded_key == "", "seasoning shaker ejected seasoning does not fall back into the mouth")
	if is_instance_valid(spawned):
		_ok(not shaker._is_point_inside_mouth_opening(spawned.global_position),
			"seasoning shaker ejects seasoning clear of the mouth opening")
		var settled_local := shaker.to_local(spawned.global_position)
		_ok(absf(settled_local.x) >= 32.0 or settled_local.y <= -58.0,
			"seasoning shaker ejects seasoning far enough from the mouth: got %s" % settled_local)

	var pot = tavern.get_node("BarWorkspace/World/Pot")
	bar.configure_day(3)
	# CollisionShape2D toggles are deferred; wait until the broadphase sees the day-3 pot.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok(pot.visible, "day 3 enables pot visibility for right-click test")
	_ok(not pot.get_node("PickupArea/Shape").disabled, "day 3 enables pot pickup collision for right-click test")
	_ok(bar._hit_test_kitchen_container(pot.global_position) == pot, "pot center resolves through kitchen-container hit test")
	pot._state.add_item("ale")
	pot._state.add_item("meat_raw")
	before = items.get_child_count()
	_right_click(bar, pot.global_position)
	_ok(items.get_child_count() == before + 1, "pot right-click eject spawns one desk item")
	spawned = items.get_child(items.get_child_count() - 1)
	_ok(spawned.item_key == "meat_raw", "pot ejects newest ingredient first")
	_ok(pot._state.ingredients() == ["ale"], "pot keeps older ingredient")

	before = items.get_child_count()
	bar._eject_last_ingredient(pot)
	bar._eject_last_ingredient(pot)
	_ok(items.get_child_count() == before + 1, "empty pot eject is a no-op")
	_ok(tavern.get_node_or_null("BarWorkspace/World/WashBasin") == null, "wash basin node is removed")

	tavern.queue_free()
	await get_tree().process_frame


func _test_settings_menu_entry() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var settings_panel = tavern.get_node_or_null("SettingsPanel")
	_ok(settings_panel != null, "tavern instances a settings panel")
	var btn_settings = tavern.get_node_or_null("OverlayMenu/TabBtns/BtnSettings")
	_ok(btn_settings != null, "tavern menu has a settings tab button")
	_ok(btn_settings != null and btn_settings.text == "设置", "settings tab button reads 设置")

	tavern.toggle_menu()
	_ok(tavern.get_node("OverlayMenu").visible, "overlay menu opens before settings")
	var shortcut_bg := tavern.get_node("ShortcutBarBg") as Panel
	_ok(_stylebox_texture_path(shortcut_bg, "panel") == "res://assets/textures/ui/bar_shortcut_bg.png",
		"shortcut bar background uses dedicated Tavern shortcut tray art")
	tavern._open_settings()
	await get_tree().process_frame
	_ok(settings_panel.visible, "tavern settings entry opens the panel")
	_ok(not tavern.get_node("OverlayMenu").visible, "opening settings hides the overlay menu")
	_ok(tavern.is_menu_open(), "open settings panel keeps gameplay input blocked")
	# 防回归：在 Node2D 根下实例化的设置面板必须居中而不是歪斜。
	var inner_panel := settings_panel.get_node("Shade/Panel") as Control
	_ok(inner_panel.global_position.distance_to(Vector2(400.0, 140.0)) < 1.0,
		"tavern settings panel is centered, not skewed: got %s" % inner_panel.global_position)
	settings_panel.close()
	await get_tree().process_frame
	_ok(not settings_panel.visible, "settings panel closes")
	_ok(tavern.get_node("OverlayMenu").visible, "closing settings restores the overlay menu")

	tavern.queue_free()
	await get_tree().process_frame


func _test_overlay_menu_clickable_during_menu_preparation() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	tavern.configure_menu_preparation([], [])
	await get_tree().process_frame

	var prep_panel := tavern.get_node_or_null("MenuPrepPanel") as Control
	var overlay_menu := tavern.get_node("OverlayMenu") as Control
	_ok(prep_panel != null and prep_panel.visible, "menu preparation panel is visible before opening the legacy menu")

	tavern.toggle_menu()
	await get_tree().process_frame

	_ok(overlay_menu.visible, "legacy overlay menu opens during menu preparation")
	_ok(prep_panel != null and not prep_panel.visible,
		"menu preparation panel stops blocking input while the legacy overlay menu is open")
	_ok(tavern.get_children().find(overlay_menu) > tavern.get_children().find(prep_panel),
		"legacy overlay menu is above the menu preparation panel in GUI input order")

	tavern.toggle_menu()
	await get_tree().process_frame
	_ok(not overlay_menu.visible, "legacy overlay menu closes from menu toggle during menu preparation")
	_ok(prep_panel != null and prep_panel.visible, "menu preparation panel remains available after closing the legacy menu")

	tavern.queue_free()
	await get_tree().process_frame


func _test_overlay_menu_renders_above_workspace() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var overlay_menu := tavern.get_node("OverlayMenu") as Control
	var dialogue_overlay := tavern.get_node("DialogueOverlay") as CanvasItem
	var bar_workspace := tavern.get_node("BarWorkspace") as CanvasItem
	var workspace_paths := [
		"BarWorkspace/World/Brewery/Art",
		"BarWorkspace/World/Grill/Art",
		"BarWorkspace/World/Pot/Art",
		"BarWorkspace/World/Spoon",
	]
	var highest_workspace_z := bar_workspace.z_index
	for path in workspace_paths:
		var canvas_item := tavern.get_node(path) as CanvasItem
		highest_workspace_z = max(highest_workspace_z, bar_workspace.z_index + canvas_item.z_index)

	tavern.toggle_menu()
	_ok(overlay_menu.visible, "overlay menu opens for workspace depth test")
	_ok(dialogue_overlay.z_index >= overlay_menu.z_index - 1,
		"dialogue dim stays immediately below or aligned with overlay menu: dim %d, menu %d" % [dialogue_overlay.z_index, overlay_menu.z_index])
	_ok(overlay_menu.z_index > highest_workspace_z,
		"overlay menu renders above workspace containers: menu %d, workspace max %d" % [overlay_menu.z_index, highest_workspace_z])
	tavern.queue_free()
	await get_tree().process_frame


func _test_recipe_menu_uses_split_layout() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	tavern.toggle_menu()
	await get_tree().process_frame

	var recipe_panel := tavern.get_node("OverlayMenu/RecipePanel") as ScrollContainer
	var backpack_panel := tavern.get_node("OverlayMenu/BackpackPanel") as ScrollContainer
	var recipe_list := tavern.get_node("OverlayMenu/RecipePanel/RecipeList") as Control
	_ok(recipe_panel != null and recipe_panel.visible, "recipe panel opens inside the legacy overlay menu")
	_ok(recipe_panel != null and recipe_panel.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
		"recipe panel hides the default vertical scrollbar")
	_ok(recipe_panel != null and recipe_panel.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"recipe panel disables the default horizontal scrollbar")
	_ok(backpack_panel != null and backpack_panel.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
		"backpack panel hides the default vertical scrollbar")
	_ok(backpack_panel != null and backpack_panel.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"backpack panel disables the default horizontal scrollbar")
	_ok(recipe_list != null, "recipe list contract path remains available")

	var layout := recipe_list.get_node_or_null("RecipeLayout") as HBoxContainer
	var left_column := layout.get_node_or_null("LeftColumn") as VBoxContainer if layout != null else null
	var tabs := left_column.get_node_or_null("ContainerTabs") as HBoxContainer if left_column != null else null
	var rows := left_column.get_node_or_null("RecipeRows") as VBoxContainer if left_column != null else null
	var detail := layout.get_node_or_null("RecipeDetail") as PanelContainer if layout != null else null
	var ingredient_grid := detail.get_node_or_null("Body/IngredientGrid") as GridContainer if detail != null else null
	var header_frame := detail.get_node_or_null("Body/HeaderFrame") as PanelContainer if detail != null else null
	var product_slot := detail.get_node_or_null("Body/HeaderFrame/Header/ProductSlot") as PanelContainer if detail != null else null
	var title_label := detail.get_node_or_null("Body/HeaderFrame/Header/TitleBox/Title") as Label if detail != null else null
	var instruction_panel := detail.get_node_or_null("Body/InstructionPanel") as PanelContainer if detail != null else null

	_ok(layout != null, "recipe menu uses a split recipe layout root")
	_ok(left_column != null, "recipe menu keeps container filters and rows in the left column")
	_ok(tabs != null and tabs.get_child_count() == 4, "recipe menu exposes four recipe filter tabs")
	_ok(rows != null and rows.get_child_count() > 0, "recipe menu renders filtered recipe rows")
	_ok(detail != null, "recipe menu renders a right-side recipe detail panel")
	_ok(_stylebox_texture_path(detail, "panel") == "res://assets/textures/ui/menu_brush_panel.png",
		"recipe detail uses the main brush panel art instead of a default control skin")
	_ok(header_frame != null and _stylebox_texture_path(header_frame, "panel") == "res://assets/textures/ui/menu_brush_band.png",
		"recipe detail header uses brush band art")
	_ok(product_slot != null and _stylebox_texture_path(product_slot, "panel") == "res://assets/textures/ui/inventory_slot_normal.png",
		"recipe detail product icon is carried by inventory slot art")
	_ok(header_frame != null and header_frame.size.y <= 112.0,
		"recipe detail header keeps a compact fixed-height band")
	_ok(product_slot != null and product_slot.size.x >= 76.0 and product_slot.size.x <= 88.0
		and product_slot.size.y >= 76.0 and product_slot.size.y <= 88.0,
		"recipe detail product slot stays square instead of stretching vertically")
	_ok(title_label != null and title_label.size.x >= 160.0 and title_label.get_line_count() <= 2,
		"recipe detail title has enough horizontal room and does not wrap into a vertical column")
	_ok(detail != null and detail.get_meta("container_key", "") == "barrel",
		"recipe detail defaults to a barrel recipe")
	_ok(ingredient_grid != null and ingredient_grid.get_child_count() > 0,
		"recipe detail shows ingredients as grid cells")
	var first_ingredient_cell := ingredient_grid.get_child(0) as PanelContainer if ingredient_grid != null and ingredient_grid.get_child_count() > 0 else null
	_ok(first_ingredient_cell != null and _stylebox_texture_path(first_ingredient_cell, "panel") == "res://assets/textures/ui/inventory_slot_normal.png",
		"recipe detail ingredient cells use inventory slot art")
	_ok(instruction_panel != null and _stylebox_texture_path(instruction_panel, "panel") == "res://assets/textures/ui/menu_brush_band.png",
		"recipe detail instruction copy is carried by brush band art")

	var grill_tab := tabs.get_node_or_null("Tab_grill") as Button if tabs != null else null
	_ok(grill_tab != null, "recipe menu has a grill filter tab")
	if grill_tab != null:
		grill_tab.pressed.emit()
		await get_tree().process_frame
		layout = recipe_list.get_node_or_null("RecipeLayout") as HBoxContainer
		left_column = layout.get_node_or_null("LeftColumn") as VBoxContainer if layout != null else null
		rows = left_column.get_node_or_null("RecipeRows") as VBoxContainer if left_column != null else null
		detail = layout.get_node_or_null("RecipeDetail") as PanelContainer if layout != null else null
		_ok(rows != null and rows.get_child_count() > 0 and rows.get_child(0).get_meta("container_key", "") == "grill",
			"recipe menu filters rows by selected container")
		_ok(detail != null and detail.get_meta("container_key", "") == "grill",
			"recipe detail follows the selected container filter")

	tavern.queue_free()
	await get_tree().process_frame


func _test_recipe_book_shows_hand_combine_tab() -> void:
	_reset_game_for_recipe_discovery_test()
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	tavern.toggle_menu()
	await get_tree().process_frame

	var recipe_list := tavern.get_node("OverlayMenu/RecipePanel/RecipeList") as Control
	var hand_tab := recipe_list.get_node_or_null("RecipeLayout/LeftColumn/ContainerTabs/Tab_hand") as Button
	_ok(hand_tab != null, "recipe book has a hand-combine filter tab")
	if hand_tab != null:
		hand_tab.emit_signal("pressed")
		await get_tree().process_frame
	var rows := recipe_list.get_node_or_null("RecipeLayout/LeftColumn/RecipeRows") as VBoxContainer
	var dough_meat_row := rows.get_node_or_null("Recipe_dough_meat") as Button if rows != null else null
	_ok(dough_meat_row != null, "hand recipe book lists dough_meat combine recipe")
	_ok(dough_meat_row != null and String(dough_meat_row.get_meta("container_key", "")) == "hand",
		"hand recipe row records hand container metadata")
	var detail := recipe_list.get_node_or_null("RecipeLayout/RecipeDetail") as PanelContainer
	_ok(detail != null and detail.get_meta("container_key", "") == "hand",
		"hand recipe detail follows hand filter")

	tavern.queue_free()
	await get_tree().process_frame


func _test_recipe_book_shows_dough_operation() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	tavern.toggle_menu()
	await get_tree().process_frame

	var recipe_list := tavern.get_node("OverlayMenu/RecipePanel/RecipeList") as Control
	var pot_tab := recipe_list.get_node_or_null("RecipeLayout/LeftColumn/ContainerTabs/Tab_pot") as Button
	_ok(pot_tab != null, "recipe book has a pot filter tab")
	if pot_tab != null:
		pot_tab.pressed.emit()
		await get_tree().process_frame

	var rows := recipe_list.get_node_or_null("RecipeLayout/LeftColumn/RecipeRows") as VBoxContainer
	var dough_row := rows.get_node_or_null("Recipe_dough") as Button if rows != null else null
	_ok(dough_row != null, "pot recipe book lists dough as a learnable operation recipe")
	_ok(dough_row != null and dough_row.text.find("???") == -1,
		"dough operation recipe is visible without prior discovery")
	if dough_row != null:
		dough_row.pressed.emit()
		await get_tree().process_frame

	var detail := recipe_list.get_node_or_null("RecipeLayout/RecipeDetail") as PanelContainer
	var title := detail.get_node_or_null("Body/HeaderFrame/Header/TitleBox/Title") as Label if detail != null else null
	var ingredient_grid := detail.get_node_or_null("Body/IngredientGrid") as GridContainer if detail != null else null
	var flour_cell := _find_grid_slot_by_item_key(ingredient_grid, "flour") if ingredient_grid != null else null
	var instruction := detail.get_node_or_null("Body/InstructionPanel/Instruction") as Label if detail != null else null
	_ok(detail != null and detail.get_meta("container_key", "") == "pot",
		"dough detail is filed under the pot container")
	_ok(title != null and title.text == String(GameManager.craft.get_item("dough").get("name", "dough")),
		"dough detail reveals the dough item name")
	_ok(flour_cell != null, "dough detail shows flour as its ingredient")
	_ok(instruction != null and instruction.text.find("锅") >= 0,
		"dough detail instructs players to use the pot")

	tavern.queue_free()
	await get_tree().process_frame


func _test_recipe_book_hides_undiscovered_entries() -> void:
	_reset_game_for_recipe_discovery_test()
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	tavern.toggle_menu()
	await get_tree().process_frame

	var spiced_name := String(GameManager.craft.get_item("spiced_wine").get("name", "spiced_wine"))
	var recipe_list := tavern.get_node("OverlayMenu/RecipePanel/RecipeList") as Control
	var rows := recipe_list.get_node_or_null("RecipeLayout/LeftColumn/RecipeRows") as VBoxContainer
	var hidden_row := rows.get_node_or_null("Recipe_spiced_wine") as Button if rows != null else null
	_ok(hidden_row != null, "recipe book still has a stable row for undiscovered spiced_wine")
	_ok(hidden_row != null and hidden_row.text.contains("???"),
		"undiscovered recipe row uses question marks")
	_ok(hidden_row != null and not hidden_row.text.contains(spiced_name),
		"undiscovered recipe row does not reveal the product name")
	if hidden_row != null:
		hidden_row.pressed.emit()
		await get_tree().process_frame

	var detail := recipe_list.get_node_or_null("RecipeLayout/RecipeDetail") as PanelContainer
	var title := detail.get_node_or_null("Body/HeaderFrame/Header/TitleBox/Title") as Label if detail != null else null
	var ingredient_grid := detail.get_node_or_null("Body/IngredientGrid") as GridContainer if detail != null else null
	_ok(title != null and title.text == "???", "undiscovered recipe detail title is hidden")
	_ok(ingredient_grid != null and ingredient_grid.get_child_count() == 2,
		"undiscovered recipe detail keeps ingredient slot count without revealing names")
	if ingredient_grid != null:
		for cell in ingredient_grid.get_children():
			var label := cell.get_node_or_null("Body/Name") as Label
			_ok(label != null and label.text == "???", "undiscovered ingredient slot hides its name")

	_ok(GameManager.craft.has_method("discover_recipe"), "recipe book can reveal through craft discovery API")
	if GameManager.craft.has_method("discover_recipe"):
		GameManager.craft.call("discover_recipe", "spiced_wine")
		_ok(GameManager.craft.has_method("mark_recipe_new"), "recipe book can mark newly discovered recipes")
		_ok(GameManager.craft.has_method("is_recipe_new"), "recipe book can query newly discovered recipes")
		if GameManager.craft.has_method("mark_recipe_new"):
			GameManager.craft.call("mark_recipe_new", "spiced_wine")
		tavern._build_recipe_list()
		await get_tree().process_frame
		rows = recipe_list.get_node_or_null("RecipeLayout/LeftColumn/RecipeRows") as VBoxContainer
		var revealed_row := rows.get_node_or_null("Recipe_spiced_wine") as Button if rows != null else null
		_ok(revealed_row != null and revealed_row.text.contains(spiced_name),
			"discovered recipe row reveals the product name")
		var new_mark := revealed_row.get_node_or_null("NewMark") as Label if revealed_row != null else null
		_ok(new_mark != null and new_mark.visible and new_mark.text == "新",
			"newly discovered recipe row shows a compact new marker")
		if GameManager.craft.has_method("is_recipe_new"):
			_ok(GameManager.craft.call("is_recipe_new", "spiced_wine"),
				"newly discovered recipe is marked unread before opening detail")
		if revealed_row != null:
			revealed_row.pressed.emit()
			await get_tree().process_frame
		if GameManager.craft.has_method("is_recipe_new"):
			_ok(not GameManager.craft.call("is_recipe_new", "spiced_wine"),
				"opening a recipe detail clears the recipe new marker")
		tavern._build_recipe_list()
		await get_tree().process_frame
		rows = recipe_list.get_node_or_null("RecipeLayout/LeftColumn/RecipeRows") as VBoxContainer
		revealed_row = rows.get_node_or_null("Recipe_spiced_wine") as Button if rows != null else null
		new_mark = revealed_row.get_node_or_null("NewMark") as Label if revealed_row != null else null
		_ok(new_mark == null or not new_mark.visible,
			"cleared recipe row no longer shows the new marker")
		detail = recipe_list.get_node_or_null("RecipeLayout/RecipeDetail") as PanelContainer
		title = detail.get_node_or_null("Body/HeaderFrame/Header/TitleBox/Title") as Label if detail != null else null
		ingredient_grid = detail.get_node_or_null("Body/IngredientGrid") as GridContainer if detail != null else null
		_ok(title != null and title.text == spiced_name, "discovered recipe detail reveals title")
		if ingredient_grid != null and ingredient_grid.get_child_count() > 0:
			var first_label := ingredient_grid.get_child(0).get_node_or_null("Body/Name") as Label
			_ok(first_label != null and first_label.text != "???",
				"discovered recipe detail reveals ingredient names")

	tavern.queue_free()
	await get_tree().process_frame


func _test_first_crafted_recipe_discovers_recipe() -> void:
	_reset_game_for_recipe_discovery_test()
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	_ok(GameManager.craft.has_method("is_recipe_discovered"), "craft discovery query exists before brewing")
	if not GameManager.craft.has_method("is_recipe_discovered"):
		tavern.queue_free()
		await get_tree().process_frame
		return

	_ok(not GameManager.craft.call("is_recipe_discovered", "spiced_wine"),
		"spiced_wine starts undiscovered before first craft")
	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	brewery._pending_keys = ["grape", "herb"]
	brewery._shake.shake_count = brewery._shake.min_count
	brewery._try_brew()
	await get_tree().process_frame

	_ok(GameManager.craft.call("is_recipe_discovered", "spiced_wine"),
		"first successful craft discovers spiced_wine")
	var caption := tavern.get_node("StageCaption") as Label
	var product_name := String(GameManager.craft.get_item("spiced_wine").get("name", "spiced_wine"))
	_ok(caption != null and not caption.text.contains("研制成功"),
		"first successful craft does not show the redundant recipe discovery caption")
	_ok(caption != null and not caption.text.contains(product_name),
		"first successful craft does not repeat the discovered recipe name in the stage caption")
	_ok(GameManager.craft.has_method("is_recipe_new"), "first successful craft can query recipe new marker")
	if GameManager.craft.has_method("is_recipe_new"):
		_ok(GameManager.craft.call("is_recipe_new", "spiced_wine"),
			"first successful craft marks recipe as new in the recipe book")
	var notice := tavern.get_node_or_null("RecipeDiscoveryNotice") as Control
	_ok(notice != null, "first successful craft creates the compact recipe discovery note UI")
	if notice != null:
		for _i in range(12):
			if notice.visible and notice.modulate.a > 0.1:
				break
			await get_tree().process_frame
		var brush := notice.get_node_or_null("BrushBand") as Panel
		var name_label := notice.get_node_or_null("Name") as Label
		var title_label := notice.get_node_or_null("Title") as Label
		var subtitle_label := notice.get_node_or_null("Subtitle") as Label
		var customer_sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as Control
		if customer_sprite != null:
			var notice_rect := notice.get_global_rect()
			var sprite_rect := customer_sprite.get_global_rect()
			var notice_center_x := notice_rect.position.x + notice_rect.size.x * 0.5
			var sprite_center_x := sprite_rect.position.x + sprite_rect.size.x * 0.5
			_ok(absf(notice_center_x - sprite_center_x) <= 12.0,
				"recipe discovery note stays centered over the customer portrait")
			_ok(notice_rect.position.y + notice_rect.size.y <= sprite_rect.position.y + 12.0,
				"recipe discovery note sits above the customer portrait head")
		_ok(notice.visible and notice.modulate.a > 0.1,
			"recipe discovery note is visible immediately after first craft")
		_ok(notice.size.x <= 560.0 and notice.size.y <= 160.0,
			"recipe discovery note stays compact instead of becoming a large banner: size=%s" % notice.size)
		_ok(brush != null and _stylebox_texture_path(brush, "panel") == "res://assets/textures/ui/menu_brush_band.png",
			"recipe discovery note uses the existing menu brush band texture")
		_ok(brush != null and brush.size == notice.size,
			"recipe discovery brush art matches the compact notice bounds")
		_ok(title_label != null and title_label.text == "新配方",
			"recipe discovery note title is rendered by Godot text")
		_ok(name_label != null and name_label.text == product_name,
			"recipe discovery note names the discovered product")
		_ok(name_label != null and name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"recipe discovery note centers the discovered product name in the notice panel")
		_ok(subtitle_label != null and subtitle_label.text == "已记入配方书",
			"recipe discovery note tells the player where the recipe went")

	tavern.queue_free()
	await get_tree().process_frame


func _right_click(bar: BarWorkspace, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = pos
	event.global_position = pos
	bar._unhandled_input(event)


func _left_press(bar: BarWorkspace, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = pos
	event.global_position = pos
	bar._unhandled_input(event)


func _left_release(bar: BarWorkspace, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = pos
	event.global_position = pos
	bar._unhandled_input(event)


func _mouse_motion(bar: BarWorkspace, pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	bar._input(event)


func _find_grid_slot_by_item_key(grid: GridContainer, item_key: String) -> Control:
	if grid == null:
		return null
	for child in grid.get_children():
		var control := child as Control
		if control != null and String(control.get_meta("item_key", "")) == item_key:
			return control
	return null


func _test_spoon_renders_below_container_visuals() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var spoon := tavern.get_node("BarWorkspace/World/Spoon") as StirSpoon
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var background := tavern.get_node("Background") as Sprite2D
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
		_ok(spoon.z_index > background.z_index,
			"submerged spoon remains above Tavern background: spoon %d, background %d" % [spoon.z_index, background.z_index])

	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	spoon.global_position = brewery.to_global(Vector2.ZERO) - tip_offset
	bar._update_spoon_depth()
	_ok(brewery.is_spoon_inside(spoon),
		"spoon tip remains submerged after passing through Brewery mouth")
	_ok(spoon.z_index < 0,
		"spoon remains below Brewery visual after passing through mouth: got z_index %d" % spoon.z_index)

	spoon.global_position = Vector2(120.0, 120.0)
	bar._update_spoon_depth()
	_ok(spoon.z_index == surface_z_index,
		"spoon restores surface depth after leaving containers: expected %d, got %d" % [surface_z_index, spoon.z_index])

	tavern.queue_free()
	await get_tree().process_frame


func _test_spoon_drag_keeps_cursor_free_while_pot_uses_thick_walls() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().physics_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var pot := tavern.get_node("BarWorkspace/World/Pot") as KitchenContainer
	var spoon := tavern.get_node("BarWorkspace/World/Spoon") as StirSpoon
	var tip_offset := spoon.tip_global_position() - spoon.global_position
	spoon.global_position = pot.to_global(Vector2(0.0, -12.0)) - tip_offset
	spoon.sleeping = false
	await get_tree().physics_frame

	var press_pos := spoon.global_position
	var tip_to_anchor := spoon.tip_global_position() - press_pos
	bar._drag_ctrl.start_drag(spoon, press_pos)
	_ok(bar._drag_ctrl.get_body() == spoon,
		"pressing the spoon starts a DragController drag")

	var raw_tip_target := pot.to_global(Vector2(96.0, 76.0))
	var raw_local := pot.to_local(raw_tip_target)
	_ok(raw_local.x > pot.stir_zone_half_width and raw_local.y > pot.stir_zone_bottom_y,
		"test target starts outside the pot stir zone: got %s" % raw_local)
	var raw_anchor_target := raw_tip_target - tip_to_anchor
	bar._update_drag_target(raw_anchor_target)
	await get_tree().physics_frame

	var anchor = bar._drag_ctrl._anchor
	_ok(anchor != null and anchor.global_position.distance_to(raw_anchor_target) <= 0.5,
		"spoon drag anchor follows the cursor freely instead of clamping the mouse target")

	for wall_path in ["WallLeft", "WallRight", "WallBottom", "RimLeft", "RimRight"]:
		var wall := pot.get_node(wall_path) as CollisionShape2D
		var rect := wall.shape as RectangleShape2D
		_ok(rect != null and minf(rect.size.x, rect.size.y) >= 10.0,
			"pot %s uses a thick collision volume instead of a zero-width segment" % wall_path)
	var bottom_wall := pot.get_node("WallBottom") as CollisionShape2D
	var bottom_rect := bottom_wall.shape as RectangleShape2D
	var bottom_inner_edge := bottom_wall.position.y - bottom_rect.size.x * 0.5
	_ok(bottom_inner_edge <= 23.0,
		"pot bottom collision starts high enough to prevent lower visual clipping: got %.2f" % bottom_inner_edge)

	bar._drag_ctrl.end_drag()
	tavern.queue_free()
	await get_tree().process_frame


func _test_seasoning_items_fit_into_shaker_mouth() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var shaker := tavern.get_node("BarWorkspace/World/SeasoningShaker") as SeasoningShaker
	var comfortable_drop_local := Vector2(24.0, -38.0)
	_ok(shaker._is_point_inside_mouth_opening(shaker.to_global(comfortable_drop_local)),
		"seasoning shaker mouth accepts a seasoning center near the visible rim")
	var spice := bar._spawn_desk_item_at(shaker.to_global(comfortable_drop_local), "spice")
	_ok(spice != null, "test creates a spice desk item for shaker loading")
	if spice != null:
		shaker._try_accept_mouth_body(spice)
		_ok(shaker.loaded_key == "spice", "seasoning shaker loads a spice item dropped near the rim")
		_ok(_intake_vfx_count(shaker, "ghost") >= 1,
			"seasoning shaker intake shows the absorbed seasoning shrinking into the mouth")
		_ok(_intake_vfx_count(shaker, "mouth_glow") == 0,
			"seasoning shaker intake no longer flashes the mouth opening")
		_ok(_intake_vfx_count(shaker, "mote") == 0,
			"seasoning shaker intake no longer emits small mouth particles")
		_ok(_intake_vfx_elements_render_below_container_art(shaker, "ghost"),
			"seasoning shaker absorbed seasoning ghost renders below the shaker visual")

	tavern.queue_free()
	await get_tree().process_frame


func _test_shaker_absorbed_dragged_seasoning_clears_drag_state() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var shaker := tavern.get_node("BarWorkspace/World/SeasoningShaker") as SeasoningShaker
	var spice := bar._spawn_desk_item_at(shaker.to_global(Vector2(0.0, -38.0)), "spice")
	_ok(spice != null, "test creates a dragged spice desk item for shaker loading")
	if spice != null:
		bar._drag_ctrl.start_drag(spice, spice.global_position)
		shaker._try_accept_mouth_body(spice)
		_ok(shaker.loaded_key == "spice", "seasoning shaker loads the dragged spice item")
		_ok(not bar._drag_ctrl.is_dragging(),
			"drag controller stops tracking a seasoning item absorbed by the shaker")
		if not bar._drag_ctrl.is_dragging():
			await get_tree().process_frame
			bar._release_dragged_body()
			_ok(not bar._drag_ctrl.is_dragging(),
				"releasing after shaker absorption is a no-op")

	tavern.queue_free()
	await get_tree().process_frame


func _test_seasoning_shaker_spawns_powder_while_moving() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var shaker := tavern.get_node("BarWorkspace/World/SeasoningShaker") as SeasoningShaker
	shaker.begin_shake_session()
	shaker.linear_velocity = Vector2(520.0, 0.0)
	for i in range(8):
		shaker._physics_process(0.05)
	shaker.end_shake_session()
	_ok(_seasoning_powder_count(shaker) == 0,
		"empty seasoning shaker does not create powder particles while moving")

	shaker.load_seasoning("spice")
	shaker.begin_shake_session()
	shaker.linear_velocity = Vector2.ZERO
	for i in range(8):
		shaker._physics_process(0.05)
	shaker.end_shake_session()
	_ok(_seasoning_powder_count(shaker) == 0,
		"loaded seasoning shaker does not shed powder while stationary")

	shaker.begin_shake_session()
	shaker.linear_velocity = Vector2(180.0, 0.0)
	for i in range(8):
		shaker._physics_process(0.05)
	var slow_powder_count := _seasoning_powder_count(shaker)
	var first_powder := _first_seasoning_powder(shaker)
	_ok(slow_powder_count > 0,
		"loaded seasoning shaker creates falling powder particles while moving")
	_ok(first_powder != null and String(first_powder.get_meta("seasoning_powder_key", "")) == "spice",
		"seasoning powder remembers the loaded spice key")
	var powder_local := shaker.to_local(first_powder.global_position) if first_powder != null else Vector2.ZERO
	_ok(first_powder != null and absf(powder_local.x) <= 18.0 and powder_local.y >= -54.0 and powder_local.y <= -12.0,
		"seasoning powder starts from the visible shaker mouth: got %s" % powder_local)
	var powder_color := _seasoning_powder_color(first_powder)
	_ok(powder_color.r > powder_color.g and powder_color.r > powder_color.b,
		"spice powder particles use a red seasoning tint")
	var powder_kinds := _seasoning_powder_kinds(shaker)
	_ok(powder_kinds.has("dust") and powder_kinds.has("flake") and powder_kinds.has("mist"),
		"seasoning powder mixes fine dust, flake, and mist particles")
	_ok(_seasoning_powder_color_bucket_count(shaker) >= 3,
		"seasoning powder uses multiple tint values instead of one flat color")
	_ok(_seasoning_powder_rotating_count(shaker) >= 3,
		"seasoning powder has rotating irregular particles")
	var start_y := first_powder.global_position.y if first_powder != null else 0.0
	shaker.end_shake_session()
	shaker._physics_process(0.05)
	_ok(first_powder != null and is_instance_valid(first_powder) and first_powder.global_position.y > start_y,
		"seasoning powder keeps falling after shaking stops")
	_clear_seasoning_powder(shaker)

	shaker.load_seasoning("spice")
	shaker.begin_shake_session()
	shaker.linear_velocity = Vector2(720.0, 0.0)
	for i in range(8):
		shaker._physics_process(0.05)
	var fast_powder_count := _seasoning_powder_count(shaker)
	shaker.end_shake_session()
	_ok(fast_powder_count >= slow_powder_count + 8,
		"faster seasoning shaker movement creates denser powder: slow=%d fast=%d" % [
			slow_powder_count,
			fast_powder_count,
		])

	tavern.queue_free()
	await get_tree().process_frame


func _test_barrel_shake_spawns_persistent_upward_bubbles() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	var grill := tavern.get_node("BarWorkspace/World/Grill") as KitchenContainer
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	bar.configure_day(2)
	await get_tree().process_frame

	brewery.begin_shake_session()
	brewery.linear_velocity = Vector2(260.0, 0.0)
	for i in range(8):
		brewery._physics_process(0.016)
	brewery.end_shake_session()
	_ok(brewery.get_node_or_null("ShakeBubbles") == null,
		"empty barrel does not create shake bubbles")

	brewery._pending_keys = ["ale"]
	brewery.begin_shake_session()
	brewery.linear_velocity = Vector2(260.0, 0.0)
	for i in range(8):
		brewery._physics_process(0.05)
	var one_direction_bubble_count := _barrel_bubble_layer_count(brewery)
	brewery.end_shake_session()
	_ok(one_direction_bubble_count > 0,
		"barrel creates continuous bubble feedback from held movement even without reversals")
	_ok(_brewery_combo_value(brewery) == 0,
		"barrel combo does not increase from fast one-direction movement")
	_ok(brewery.get_node_or_null("BrewComboHud") == null,
		"barrel combo HUD is not shown until real shake reversals happen")
	_clear_barrel_test_bubbles(brewery)
	brewery._shake.reset()
	brewery._pending_keys = ["ale"]
	brewery.begin_shake_session()
	brewery.linear_velocity = Vector2(180.0, 0.0)
	for i in range(8):
		brewery._physics_process(0.05)
	var slow_continuous_bubble_count := _barrel_bubble_layer_count(brewery)
	brewery.end_shake_session()
	_clear_barrel_test_bubbles(brewery)
	brewery._shake.reset()
	brewery._pending_keys = ["ale"]
	brewery.begin_shake_session()
	brewery.linear_velocity = Vector2(720.0, 0.0)
	for i in range(8):
		brewery._physics_process(0.05)
	var fast_continuous_bubble_count := _barrel_bubble_layer_count(brewery)
	brewery.end_shake_session()
	_ok(fast_continuous_bubble_count >= slow_continuous_bubble_count + 12,
		"faster held barrel movement creates denser continuous bubbles: slow=%d fast=%d" % [
			slow_continuous_bubble_count,
			fast_continuous_bubble_count,
		])
	_clear_barrel_test_bubbles(brewery)
	brewery._shake.reset()
	brewery._pending_keys = ["ale"]
	brewery.begin_shake_session()
	brewery.linear_velocity = Vector2(260.0, 0.0)
	brewery._physics_process(0.05)
	brewery.linear_velocity = Vector2(-260.0, 0.0)
	brewery._physics_process(0.05)
	_ok(brewery._shake.shake_count == 0,
		"first valid shake reversal does not count as a full shake")
	_ok(_brewery_combo_value(brewery) == 0,
		"first valid shake reversal does not increase combo")
	brewery.linear_velocity = Vector2(260.0, 0.0)
	brewery._physics_process(0.05)
	_ok(brewery._shake.shake_count == 1,
		"completed full shake still counts exactly one combo-quality shake")
	brewery.end_shake_session()
	_clear_barrel_test_bubbles(brewery)
	brewery._pending_keys = ["ale"]

	var pending_bubble := _spawn_barrel_test_bubble(brewery, 1)
	var bubble_layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	_ok(brewery.get_node_or_null("BubbleVfx") == null, "barrel does not restore the old BubbleVfx contract")
	_ok(bubble_layer != null, "barrel creates a dedicated shake bubble layer while shaken")
	if bubble_layer != null:
		_ok(bubble_layer.get_child_count() > 0, "barrel shake creates visible bubble nodes")
		if pending_bubble != null:
			_ok(_barrel_bubble_quality(pending_bubble) == "pending",
				"barrel bubble shows pending quality before minimum shakes")
			_ok(_barrel_bubble_uses_runtime_sprite(pending_bubble),
				"barrel bubbles use the generated runtime sprite atlas")
			_ok(_barrel_bubble_region_row(pending_bubble) == 0,
				"pending barrel bubbles use the pending atlas row")
			_ok(_barrel_bubble_layer_count(brewery) >= 1 and _barrel_bubble_layer_count(brewery) <= 3,
				"pending barrel shakes emit a restrained visible bubble set")
			var pending_pixel_count := _barrel_bubble_pixel_count(pending_bubble)
			_ok(pending_pixel_count >= 360 and pending_pixel_count <= 3600,
				"pending barrel bubble sprite stays a single readable bubble")
			brewery.linear_velocity = Vector2(720.0, 0.0)
			brewery._shake.shake_count = brewery._shake.min_count - 1
			var pending_peak_burst := brewery._shake_bubble_burst_count("pending")
			brewery._shake.shake_count = brewery._shake.min_count
			var normal_entry_burst := brewery._shake_bubble_burst_count("normal")
			brewery._shake.shake_count = brewery._shake.good_count
			var good_entry_burst := brewery._shake_bubble_burst_count("good")
			_ok(pending_peak_burst <= 5,
				"pending barrel bubble stage stays restrained even at high speed: got %d" % pending_peak_burst)
			_ok(normal_entry_burst > pending_peak_burst,
				"normal barrel bubble stage starts denser than pending: pending=%d normal=%d" % [
					pending_peak_burst,
					normal_entry_burst,
				])
			_ok(good_entry_burst >= normal_entry_burst,
				"good barrel bubble stage is not thinner than normal: normal=%d good=%d" % [
					normal_entry_burst,
					good_entry_burst,
				])
			_clear_barrel_test_bubbles(brewery)
			brewery._shake.reset()
			brewery._pending_keys = ["ale"]
			brewery.linear_velocity = Vector2(260.0, 0.0)
			brewery._shake.shake_count = brewery._shake.min_count - 1
			brewery._shake_bubble_spawn_elapsed = 99.0
			brewery._try_spawn_shake_bubble(0.0)
			var pending_stage_count := _barrel_bubble_quality_count(brewery, "pending")
			brewery._shake.shake_count = brewery._shake.min_count
			brewery._shake_bubble_spawn_elapsed = 0.0
			brewery._try_spawn_shake_bubble(0.0)
			_ok(pending_stage_count > 0,
				"barrel test creates pending bubbles before crossing into normal")
			_ok(_barrel_bubble_quality_count(brewery, "normal") > 0,
				"barrel crossing into normal quality emits normal bubbles immediately even during spawn cooldown")
			_clear_barrel_test_bubbles(brewery)
			brewery._shake.reset()
			brewery._pending_keys = ["ale"]
			brewery.begin_shake_session()
			var fast_direction := 1.0
			var fast_guard := 0
			while brewery._shake.shake_count < brewery._shake.good_count and fast_guard < 40:
				brewery.linear_velocity = Vector2(720.0 * fast_direction, 0.0)
				brewery._physics_process(0.05)
				fast_direction *= -1.0
				fast_guard += 1
			var good_transition_count := _barrel_bubble_quality_count(brewery, "good")
			var normal_before_good_count := _barrel_bubble_quality_count(brewery, "normal")
			_ok(brewery._shake.shake_count >= brewery._shake.good_count,
				"barrel test reaches good bubble tier during fast continuous shaking")
			_ok(good_transition_count >= 18,
				"fast transition into good quality makes room for visible good bubbles: good=%d normal=%d total=%d" % [
					good_transition_count,
					normal_before_good_count,
					_barrel_bubble_layer_count(brewery),
				])
			_ok(_barrel_bubble_layer_count(brewery) <= 220,
				"making room for good bubbles still respects the barrel bubble performance cap")
			var visible_peak := _barrel_bubble_layer_count(brewery)
			var visible_min_after_peak := visible_peak
			for i in range(64):
				brewery.linear_velocity = Vector2(720.0 * fast_direction, 0.0)
				brewery._physics_process(0.05)
				fast_direction *= -1.0
				var visible_now := _barrel_bubble_layer_count(brewery)
				if visible_now > visible_peak:
					visible_peak = visible_now
					visible_min_after_peak = visible_now
				else:
					visible_min_after_peak = mini(visible_min_after_peak, visible_now)
			_ok(visible_min_after_peak >= visible_peak - 12,
				"continued fast shaking keeps visible barrel foam from thinning mid-shake: peak=%d min_after_peak=%d" % [
					visible_peak,
					visible_min_after_peak,
				])
			var full_screen_foam_count := _barrel_bubble_layer_count(brewery)
			var full_screen_foam_span := _barrel_bubble_horizontal_span(brewery)
			_ok(full_screen_foam_count >= 420,
				"sustained over-good shaking can build far past the old plume cap: got %d" % full_screen_foam_count)
			_ok(full_screen_foam_span >= 760.0,
				"sustained over-good shaking spreads barrel bubbles across the screen: span=%.1f" % full_screen_foam_span)
			_ok(full_screen_foam_count <= 720,
				"sustained over-good shaking still keeps bubble nodes capped for performance: got %d" % full_screen_foam_count)
			var full_screen_pressure := brewery._shake_bubble_foam_pressure
			_clear_barrel_test_bubbles(brewery, false)
			brewery._shake_bubble_foam_pressure = full_screen_pressure
			brewery._spawn_shake_bubble_burst("good")
			var birth_max_local_x := _barrel_bubble_max_abs_local_x(brewery)
			var birth_min_local_y := _barrel_bubble_min_local_y(brewery)
			_ok(birth_max_local_x <= 48.0,
				"high-pressure barrel bubbles still originate from the mouth: max local x=%.1f" % birth_max_local_x)
			_ok(birth_min_local_y >= -88.0,
				"high-pressure barrel bubbles do not appear far above the mouth at birth: min local y=%.1f" % birth_min_local_y)
			_clear_barrel_test_bubbles(brewery, false)
			brewery._shake_bubble_foam_pressure = 1.0
			brewery._shake.shake_count = brewery._shake.good_count + 48
			brewery.linear_velocity = Vector2(720.0, 0.0)
			_fill_barrel_test_bubbles(brewery, "good", 680, Vector2(280.0, -180.0))
			brewery._spawn_shake_bubble_burst("good")
			var capped_mouth_birth_count := _barrel_bubble_mouth_origin_count(brewery)
			_ok(capped_mouth_birth_count >= 4,
				"capped high-pressure foam still emits fresh bubbles at the mouth between stage bursts: got %d" % capped_mouth_birth_count)
			_ok(_barrel_bubble_layer_count(brewery) <= 680,
				"capped high-pressure mouth emission keeps the dynamic bubble cap")
			_clear_barrel_test_bubbles(brewery)
			brewery._shake.reset()
			brewery._pending_keys = ["ale"]
			brewery._last_shake_bubble_quality_tier = ""
			brewery._shake_bubble_spawn_elapsed = 99.0
			var vertical_direction := 1.0
			var vertical_guard := 0
			while brewery._shake.shake_count < brewery._shake.good_count and vertical_guard < 40:
				brewery.linear_velocity = Vector2(0.0, 720.0 * vertical_direction)
				brewery._physics_process(0.05)
				vertical_direction *= -1.0
				vertical_guard += 1
			for i in range(64):
				brewery.linear_velocity = Vector2(0.0, 720.0 * vertical_direction)
				brewery._physics_process(0.05)
				vertical_direction *= -1.0
			var vertical_foam_count := _barrel_bubble_layer_count(brewery)
			var vertical_foam_span := _barrel_bubble_horizontal_span(brewery)
			_ok(vertical_foam_count >= 420,
				"sustained vertical over-good shaking still builds dense foam: got %d" % vertical_foam_count)
			_ok(vertical_foam_span <= 420.0,
				"sustained vertical over-good shaking keeps foam as an upward plume, not a sideways spread: span=%.1f" % vertical_foam_span)
			var normal_bubble := _spawn_barrel_test_bubble(brewery, brewery._shake.min_count)
			_ok(_barrel_bubble_quality(normal_bubble) == "normal",
				"barrel bubble shows normal quality once minimum shakes are reached")
			_ok(_barrel_bubble_region_row(normal_bubble) == 1,
				"normal barrel bubbles use the normal atlas row")
			_ok(_barrel_bubble_layer_count(brewery) >= 8,
				"normal barrel shakes create density by spawning more individual bubbles")
			var normal_pixel_count := _barrel_bubble_pixel_count(normal_bubble)
			_ok(normal_pixel_count >= 360 and normal_pixel_count <= 3600,
				"normal barrel bubble sprite remains a single bubble, not baked foam")
			var good_bubble := _spawn_barrel_test_bubble(brewery, brewery._shake.good_count)
			_ok(_barrel_bubble_quality(good_bubble) == "good",
				"barrel bubble shows good quality once good-count shakes are reached")
			_ok(_barrel_bubble_region_row(good_bubble) == 2,
				"good barrel bubbles use the good-quality atlas row")
			_ok(_barrel_bubble_layer_count(brewery) >= 14,
				"good barrel shakes create dense foam by spawning many individual bubbles")
			var good_pixel_count := _barrel_bubble_pixel_count(good_bubble)
			_ok(good_pixel_count >= 360 and good_pixel_count <= 3600,
				"good barrel bubble sprite stays a single bubble")
			_ok(_barrel_bubble_vivid_hue_bucket_count(good_bubble) >= 4,
				"good individual bubbles include multiple rainbow hue families")
			var start_y := good_bubble.global_position.y
			brewery._pending_keys.clear()
			brewery.end_shake_session()
			brewery._physics_process(0.25)
			_ok(is_instance_valid(good_bubble) and good_bubble.global_position.y < start_y,
				"barrel bubble keeps floating upward after shaking stops")
			good_bubble.global_position.y = -12.0
			brewery._physics_process(0.016)
			await get_tree().process_frame
			_ok(not is_instance_valid(good_bubble),
				"barrel bubble is removed only after floating above the screen")
			brewery._pending_keys = ["ale"]
			var just_good_bubble := _spawn_barrel_test_bubble(brewery, brewery._shake.good_count)
			var just_good_bubble_count := _barrel_bubble_layer_count(brewery)
			_ok(_barrel_bubble_quality(just_good_bubble) == "good",
				"just-good barrel bubbles use the good-quality visual tier")
			var late_good_bubble := _spawn_barrel_test_bubble(brewery, brewery._shake.good_count + 60)
			var late_good_bubble_count := _barrel_bubble_layer_count(brewery)
			_ok(_barrel_bubble_quality(late_good_bubble) == "good",
				"late over-shaken barrel bubbles remain in the good-quality visual tier")
			_ok(late_good_bubble_count >= just_good_bubble_count + 30,
				"late over-shaking creates a much denser bubble burst: just-good=%d late=%d" % [
					just_good_bubble_count,
					late_good_bubble_count,
				])
			var slow_good_bubble := _spawn_barrel_test_bubble(brewery, brewery._shake.good_count, 180.0)
			var slow_good_bubble_count := _barrel_bubble_layer_count(brewery)
			_ok(_barrel_bubble_quality(slow_good_bubble) == "good",
				"slow good-quality barrel shake still uses the good visual tier")
			var fast_good_bubble := _spawn_barrel_test_bubble(brewery, brewery._shake.good_count, 720.0)
			var fast_good_bubble_count := _barrel_bubble_layer_count(brewery)
			_ok(_barrel_bubble_quality(fast_good_bubble) == "good",
				"fast good-quality barrel shake still uses the good visual tier")
			_ok(fast_good_bubble_count >= slow_good_bubble_count + 8,
				"faster barrel shaking creates a visibly denser bubble burst at the same quality: slow=%d fast=%d" % [
					slow_good_bubble_count,
					fast_good_bubble_count,
				])
			_clear_barrel_test_bubbles(brewery)
			brewery._shake.reset()
			_drive_barrel_combo_to(brewery, brewery._shake.good_count + 42)
			var combo_value := _brewery_combo_value(brewery)
			_ok(combo_value >= brewery._shake.good_count + 42,
				"barrel combo keeps counting past good quality without a hard cap: got %d" % combo_value)
			var combo_hud := brewery.get_node_or_null("BrewComboHud") as CanvasLayer
			_ok(combo_hud != null,
				"barrel creates a fixed-screen brew combo HUD while real shaking continues")
			var combo_label := combo_hud.get_node_or_null("ComboLabel") as Label if combo_hud != null else null
			var rank_label := combo_hud.get_node_or_null("RankLabel") as Label if combo_hud != null else null
			_ok(combo_label != null and combo_label.text == "BREW COMBO x%d" % combo_value,
				"barrel combo HUD shows the uncapped combo number")
			_ok(rank_label != null and rank_label.text.begins_with("酒神 +"),
				"barrel combo rank advances into uncapped original plus ranks")
			var combo_vfx := brewery.get_node_or_null("BrewComboVfx") as Node2D
			_ok(combo_vfx != null and combo_vfx.get_child_count() > 0,
				"high barrel combo spawns extra capped rank and sparkle VFX")
			var shake_camera := brewery.get_node_or_null("BrewShakeCamera") as Camera2D
			_ok(shake_camera != null and shake_camera.offset.length() > 0.0,
				"high barrel combo drives visible screen shake through a camera offset")
			var high_combo_bubble_count := _barrel_bubble_layer_count(brewery)
			_ok(high_combo_bubble_count <= 720,
				"uncapped barrel combo still keeps bubble nodes capped for performance: got %d" % high_combo_bubble_count)
			brewery._pending_keys.clear()
			if brewery._session_active:
				brewery.end_shake_session()
			brewery.linear_velocity = Vector2.ZERO
			brewery.angular_velocity = 0.0

	tavern.queue_free()
	await get_tree().process_frame
	tavern = preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	brewery = tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	grill = tavern.get_node("BarWorkspace/World/Grill") as KitchenContainer
	bar = tavern.get_node("BarWorkspace") as BarWorkspace
	bar.configure_day(2)
	await get_tree().process_frame

	var sear_zone := grill.get_node("SearZone") as Area2D
	grill._physics_process(0.05)
	_ok(grill.get_node_or_null("GrillVaporLayer") == null,
		"empty grill does not create vapor")
	var item := bar._spawn_desk_item_at(sear_zone.global_position, "meat_raw")
	item.freeze = true
	item.is_held = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	grill._physics_process(0.20)
	_ok(grill.get_node_or_null("SteamVfx") == null, "grill no longer spawns steam work vfx")
	var idle_vapor_count := _grill_vapor_count(grill)
	_ok(idle_vapor_count == 1,
		"resting grill item creates light auto-cook vapor")
	var steam_vapor := _first_grill_vapor(grill)
	_ok(_grill_vapor_quality(steam_vapor) == "steam",
		"resting raw grill item emits steam vapor")
	_ok(_grill_vapor_uses_runtime_sprite(steam_vapor),
		"resting grill vapor uses the generated runtime sprite atlas")
	_ok(_grill_vapor_region_row(steam_vapor) == 0,
		"resting raw steam uses the steam atlas row")

	_clear_grill_vapors(grill)
	item.is_held = true
	grill._physics_process(0.12)
	steam_vapor = _first_grill_vapor(grill)
	_ok(_grill_vapor_count(grill) >= 2 and _grill_vapor_count(grill) <= 3,
		"held raw searing creates denser but readable vapor wisps")
	_ok(_grill_vapor_quality(steam_vapor) == "steam",
		"raw searing emits steam vapor")
	_ok(_grill_vapor_uses_runtime_sprite(steam_vapor),
		"grill vapor uses the generated runtime sprite atlas")
	_ok(_grill_vapor_region_row(steam_vapor) == 0,
		"raw steam uses the steam atlas row")

	_clear_grill_vapors(grill)
	grill._advance_grill_item(item, grill.cook_time)
	_clear_grill_vapors(grill)
	grill._physics_process(0.12)
	var smoke_vapor := _first_grill_vapor(grill)
	_ok(_grill_vapor_count(grill) >= 2 and _grill_vapor_count(grill) <= 3,
		"cooked searing emits a compact smoke wisp set")
	_ok(_grill_vapor_quality(smoke_vapor) == "smoke",
		"cooked searing emits smoke vapor")
	_ok(_grill_vapor_region_row(smoke_vapor) == 1,
		"cooked smoke uses the smoke atlas row")

	_clear_grill_vapors(grill)
	grill._advance_grill_item(item, grill.burn_time - grill.cook_time)
	var char_vapor := _first_grill_vapor(grill)
	_ok(_grill_vapor_count(grill) >= 3 and _grill_vapor_count(grill) <= 4,
		"burnt transition emits a short char vapor burst")
	_ok(_grill_vapor_quality(char_vapor) == "char",
		"burnt transition emits char vapor")
	_ok(_grill_vapor_region_row(char_vapor) == 2,
		"burnt char vapor uses the char atlas row")

	if brewery._session_active:
		brewery.end_shake_session()
	tavern.queue_free()
	await get_tree().process_frame


func _test_dragged_barrel_shakes_grape_into_wine() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().physics_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	var items := tavern.get_node("BarWorkspace/World/Items")
	brewery._pending_keys = ["grape"]
	var before := items.get_child_count()
	var start_pos := brewery.global_position

	_left_press(bar, start_pos)
	_ok(bar._drag_ctrl.get_body() == brewery, "pressing the visible barrel starts a barrel drag")
	var direction := 1.0
	for i in range(18):
		var target := start_pos + Vector2(170.0 * direction, 0.0)
		var motion := InputEventMouseMotion.new()
		motion.position = target
		motion.global_position = target
		bar._input(motion)
		for _step in range(2):
			await get_tree().physics_frame
		direction *= -1.0

	var counted_shakes := brewery._shake.shake_count
	_ok(counted_shakes >= brewery._shake.min_count,
		"real dragged barrel motion counts enough shakes for brewing: got %d, need %d" % [counted_shakes, brewery._shake.min_count])
	bar._release_dragged_body()
	await get_tree().physics_frame
	await get_tree().process_frame

	_ok(items.get_child_count() == before + 1, "releasing a shaken grape barrel produces one desk item")
	var product := items.get_child(items.get_child_count() - 1) as DeskItem if items.get_child_count() > before else null
	_ok(product != null and product.item_key == "wine",
		"dragged grape barrel produces wine: got %s" % [product.item_key if product != null else "<none>"])

	tavern.queue_free()
	await get_tree().process_frame


func _test_grape_desk_item_loads_into_barrel_mouth() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().physics_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	var items := tavern.get_node("BarWorkspace/World/Items")
	var grape := bar._spawn_desk_item_at(brewery.to_global(Vector2(0.0, -44.0)), "grape")
	_ok(grape != null, "test creates a grape desk item for barrel loading")
	if grape != null:
		grape.linear_velocity = Vector2.ZERO
		grape.angular_velocity = 0.0
		_release_dragged_body_at(bar, grape, grape.global_position)
		_ok(not is_instance_valid(grape) or grape.is_queued_for_deletion(),
			"grape desk item is absorbed by the barrel mouth on release")
		_ok(brewery._pending_keys == ["grape"],
			"barrel stores grape as the pending wine ingredient immediately on release: got %s" % [brewery._pending_keys])
		_ok(_intake_vfx_count(brewery, "ghost") >= 1,
			"barrel intake shows the absorbed ingredient shrinking into the mouth")
		_ok(_intake_vfx_count(brewery, "mouth_glow") == 0,
			"barrel intake no longer flashes the mouth opening")
		_ok(_intake_vfx_count(brewery, "mote") == 0,
			"barrel intake no longer emits small mouth particles")
		_ok(_intake_vfx_elements_render_below_container_art(brewery, "ghost"),
			"barrel absorbed ingredient ghost renders below the barrel visual")
		await get_tree().process_frame
		_ok(items.get_child_count() == 0,
			"absorbed grape is removed from world items")

	tavern.queue_free()
	await get_tree().process_frame


func _test_shortcut_malt_released_inside_barrel_loads() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().physics_frame

	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	var slot0 := tavern.get_node("ShortcutBar/Slot0") as Control
	bar._init_material_slots()
	_ok(bar._slot_item_keys.size() > 0 and bar._slot_item_keys[0] == "ale",
		"default shortcut slot 0 is malt for the barrel drop regression")

	var slot_center := slot0.global_position + slot0.size * 0.5
	var release_pos := brewery.to_global(Vector2(0.0, -8.0))
	_ok(not brewery._is_point_inside_mouth_opening(release_pos),
		"shortcut release point is visibly inside the barrel but below the strict mouth opening")
	_left_press(bar, slot_center)
	var ale := bar._drag_ctrl.get_body() as DeskItem
	_ok(ale != null and ale.item_key == "ale", "shortcut drag creates a malt desk item")
	if ale != null:
		_mouse_motion(bar, brewery._mouth_center_global_position())
		await get_tree().physics_frame
		_mouse_motion(bar, release_pos)
		await get_tree().physics_frame
		_left_release(bar, release_pos)
		await get_tree().physics_frame
		await get_tree().process_frame
		_ok(not is_instance_valid(ale) or ale.is_queued_for_deletion(),
			"shortcut malt released inside the visible barrel is absorbed")
		_ok(brewery._pending_keys == ["ale"],
			"barrel stores shortcut malt after release inside the visible barrel: got %s" % [brewery._pending_keys])

	tavern.queue_free()
	await get_tree().process_frame


func _test_grill_press_finish_and_burn_feedback_effects() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	bar.configure_day(2)
	await get_tree().process_frame
	var grill := tavern.get_node("BarWorkspace/World/Grill") as KitchenContainer
	var sear_zone := grill.get_node("SearZone") as Area2D
	grill.cook_time = 1.0
	grill.burn_time = 3.0
	_ok(grill.get_node_or_null("GrillFeedbackLayer") == null,
		"empty grill starts without the fun feedback layer")

	var item := bar._spawn_desk_item_at(sear_zone.global_position, "meat_raw")
	item.freeze = true
	item.is_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	grill._physics_process(0.13)
	_ok(_grill_feedback_count(grill, "press_spark") >= 2 and _grill_feedback_count(grill, "press_spark") <= 3,
		"pressed grill item sprays a readable oil spark pair")
	_ok(_grill_feedback_count(grill, "press_glow") >= 1,
		"pressed grill item creates a heat glow")
	var spark := _first_grill_feedback(grill, "press_spark")
	_ok(spark != null and spark.get_node_or_null("Sprite") is Sprite2D,
		"grill oil sparks render as pixel sprites")
	_ok(_grill_feedback_uses_runtime_sprite(spark),
		"grill oil sparks use the generated runtime feedback atlas")

	_clear_grill_feedback(grill)
	grill._advance_grill_item(item, grill.cook_time)
	_ok(_grill_feedback_count(grill, "done_word") >= 1,
		"finished grill item pops a doneness word")
	_ok(_grill_feedback_count(grill, "done_spark") >= 4 and _grill_feedback_count(grill, "done_spark") <= 5,
		"finished grill item throws a compact golden spark burst")
	var done_word := _first_grill_feedback(grill, "done_word")
	var done_label := done_word.get_node_or_null("Label") as Label if done_word != null else null
	_ok(done_label != null and done_label.text != "",
		"finished grill feedback renders text with a Label")
	var done_spark := _first_grill_feedback(grill, "done_spark")
	_ok(_grill_feedback_uses_runtime_sprite(done_spark),
		"finished grill sparks use the generated runtime feedback atlas")

	_clear_grill_feedback(grill)
	item.is_held = false
	grill._grill_elapsed_by_item[item] = grill.burn_time - grill.cook_time - 0.35
	grill._physics_process(0.08)
	_ok(_grill_feedback_count(grill, "burn_warning") >= 1,
		"near-burn grill item warns before ruining food")
	var warning := _first_grill_feedback(grill, "burn_warning")
	var warning_label := warning.get_node_or_null("Label") as Label if warning != null else null
	_ok(warning_label != null and warning_label.text != "",
		"near-burn warning renders text with a Label")

	_clear_grill_feedback(grill)
	grill._advance_grill_item(item, grill.burn_time - grill.cook_time)
	_ok(_grill_feedback_count(grill, "burnt_word") >= 1,
		"burnt transition pops a charred word")
	_ok(_grill_feedback_count(grill, "char_spark") >= 4 and _grill_feedback_count(grill, "char_spark") <= 5,
		"burnt transition adds a compact ember burst")
	var char_spark := _first_grill_feedback(grill, "char_spark")
	_ok(_grill_feedback_uses_runtime_sprite(char_spark),
		"burnt grill embers use the generated runtime feedback atlas")

	tavern.queue_free()
	await get_tree().process_frame


func _test_good_barrel_brew_spawns_celebration() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	var items := tavern.get_node("BarWorkspace/World/Items")

	brewery._pending_keys = ["ale"]
	brewery._shake.shake_count = brewery._shake.min_count
	var normal_before := items.get_child_count()
	brewery._try_brew()
	_ok(items.get_child_count() == normal_before + 1,
		"normal barrel brew still produces an item")
	var normal_product := items.get_child(items.get_child_count() - 1) as DeskItem
	_ok(normal_product != null and normal_product.quality == "normal",
		"normal barrel brew keeps normal product quality")
	var normal_art := normal_product.get_node_or_null("IconArt") as Sprite2D if normal_product != null else null
	_ok(normal_art != null and _texture_path(normal_art.texture) == "res://assets/textures/tavern/items/ale_beer.png",
		"normal barrel brew keeps the original ale_beer desk-item texture")
	var normal_product_vfx := normal_product.get_node_or_null("BrewProductVfx") as Node2D if normal_product != null else null
	_ok(normal_product_vfx != null and String(normal_product_vfx.get_meta("brew_product_vfx_quality", "")) == "normal",
		"normal barrel brew attaches a short product trail to the spawned drink")
	_ok(_product_output_vfx_count(normal_product, "trail") >= 3,
		"normal barrel brew makes the product itself visibly carry a restrained trail")
	var output_burst := brewery.get_node_or_null("BrewOutputBurst") as Node2D
	_ok(output_burst != null,
		"normal barrel brew creates a dedicated mouth pop output burst layer")
	_ok(_brew_output_burst_count(brewery, "normal", "pop") >= 5,
		"normal barrel brew pops several small particles from the barrel mouth")
	_ok(brewery.get_node_or_null("GoodBrewCelebration") == null,
		"normal barrel brew does not create good-quality celebration")
	var normal_feedback := brewery.get_node_or_null("NormalBrewFeedback") as Node2D
	_ok(normal_feedback != null,
		"normal barrel brew creates a separate light word feedback layer")
	_ok(_normal_brew_feedback_count(brewery) == 1,
		"normal barrel brew only pops one restrained feedback word")
	var normal_word_effect := _first_normal_brew_feedback_effect(brewery)
	var normal_word_label := normal_word_effect.get_node_or_null("Label") as Label if normal_word_effect != null else null
	var normal_words: Array[String] = ["成了", "稳了", "顺口", "够味", "不赖", "过关"]
	_ok(normal_word_label != null,
		"normal barrel brew renders feedback text with a Label node")
	_ok(normal_word_label != null and normal_words.has(normal_word_label.text),
		"normal barrel brew picks a random approved normal-quality word")
	_ok(normal_word_label != null and normal_word_label.get_theme_font_size("font_size") <= 22,
		"normal barrel brew word stays visually quieter than good-quality praise")
	_ok(normal_word_effect != null and normal_word_effect.get_node_or_null("Sprite") == null,
		"normal barrel brew word is not baked into a sprite")

	brewery._pending_keys = ["ale"]
	brewery._shake.shake_count = brewery._shake.good_count
	var good_before := items.get_child_count()
	brewery._try_brew()
	_ok(items.get_child_count() == good_before + 1,
		"good barrel brew produces an item")
	var good_product := items.get_child(items.get_child_count() - 1) as DeskItem
	_ok(good_product != null and good_product.quality == "good",
		"good barrel brew keeps good product quality")
	var good_art := good_product.get_node_or_null("IconArt") as Sprite2D if good_product != null else null
	_ok(good_art != null and _texture_path(good_art.texture) == "res://assets/textures/tavern/items/ale_beer_good.png",
		"good barrel brew swaps the final drink to its item-pipeline quality texture")
	var good_product_vfx := good_product.get_node_or_null("BrewProductVfx") as Node2D if good_product != null else null
	_ok(good_product_vfx != null and String(good_product_vfx.get_meta("brew_product_vfx_quality", "")) == "good",
		"good barrel brew attaches a brighter product trail to the spawned drink")
	_ok(_product_output_vfx_count(good_product, "trail") >= 6,
		"good barrel brew makes the product carry a longer gold trail")
	_ok(_product_output_vfx_count(good_product, "spark") >= 3,
		"good barrel brew makes the product carry visible spark highlights")
	_ok(_brew_output_burst_count(brewery, "good", "impact") >= 1,
		"good barrel brew adds a punchy mouth impact burst")

	var layer := brewery.get_node_or_null("GoodBrewCelebration") as Node2D
	_ok(layer != null, "good barrel brew creates a dedicated celebration layer")
	var elements := _barrel_celebration_elements(brewery)
	for expected in ["ring", "beam", "star", "gold_bubble", "aroma", "trail", "word", "stamp", "mouth_flash"]:
		_ok(elements.has(expected),
			"good barrel celebration includes %s elements" % expected)
	_ok(_barrel_celebration_count(brewery, "star") >= 18,
		"good barrel celebration creates denser sparkle burst from individual star nodes")
	_ok(_barrel_celebration_count(brewery, "beam") >= 6,
		"good barrel celebration builds a more theatrical light column from separate beam pieces")
	_ok(_barrel_celebration_count(brewery, "gold_bubble") >= 12,
		"good barrel celebration adds a denser spray of individual quality bubbles")
	var word_effect := _first_barrel_celebration_effect_with_element(brewery, "word")
	var word_label := word_effect.get_node_or_null("Label") as Label if word_effect != null else null
	var valid_words: Array[String] = ["牛逼", "绝品", "神酿", "爆香", "上头", "天成"]
	_ok(word_label != null,
		"good barrel celebration renders random praise text with a Label node")
	_ok(word_label != null and valid_words.has(word_label.text),
		"good barrel celebration picks a random approved praise word")
	_ok(word_effect != null and _barrel_celebration_sprite(word_effect) == null,
		"good barrel celebration word is not baked into the generated sprite atlas")
	var stamp_effect := _first_barrel_celebration_effect_with_element(brewery, "stamp")
	var stamp_label := stamp_effect.get_node_or_null("Label") as Label if stamp_effect != null else null
	_ok(stamp_label != null,
		"good barrel celebration adds a rating stamp rendered as a Label")
	_ok(stamp_label != null and valid_words.has(stamp_label.text),
		"good barrel celebration stamp uses the approved praise word pool")
	_ok(stamp_effect != null and _barrel_celebration_sprite(stamp_effect) == null,
		"good barrel celebration stamp is not baked into a sprite")
	var first_effect := _first_barrel_celebration_effect(brewery)
	_ok(_barrel_celebration_uses_runtime_sprite(first_effect),
		"good barrel celebration uses the generated runtime sprite atlas")
	_ok(_barrel_celebration_region_row(first_effect) >= 0,
		"good barrel celebration chooses a valid atlas row")

	tavern.queue_free()
	await get_tree().process_frame


func _test_pot_effects_follow_ingredients_and_real_stirring() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var pot := tavern.get_node("BarWorkspace/World/Pot") as KitchenContainer
	var spoon := tavern.get_node("BarWorkspace/World/Spoon") as StirSpoon
	var items := tavern.get_node("BarWorkspace/World/Items")
	var tip_offset := spoon.tip_global_position() - spoon.global_position

	pot._physics_process(0.75)
	_ok(pot.get_node_or_null("PotEffectLayer") == null,
		"empty pot does not create pot effects")
	_drive_pot_stir_path(pot, spoon, tip_offset, [Vector2(-24.0, -24.0), Vector2(-16.0, -24.0), Vector2(-8.0, -24.0)])
	_ok(_pot_effect_count(pot) == 0,
		"empty pot does not create effects even when the spoon is moving inside")

	pot._state.add_item("ale")
	pot._stir_tracking = false
	pot._physics_process(0.75)
	var simmer_count := _pot_effect_kind_count(pot, "simmer")
	_ok(simmer_count >= 1 and simmer_count <= 2,
		"loaded pot emits only a light simmer before real stirring: got %d" % simmer_count)
	_ok(_pot_effect_elements(pot).has("bubble") or _pot_effect_elements(pot).has("steam"),
		"loaded pot simmer uses single bubble or steam elements")
	_clear_pot_effects(pot)

	pot._stir_tracking = false
	_drive_pot_stir_path(pot, spoon, tip_offset, [Vector2(-42.0, -24.0), Vector2(42.0, -24.0)])
	_ok(_pot_effect_count(pot) == 0,
		"large spoon position jumps are ignored and do not create active stir effects")

	pot._stir_tracking = false
	_drive_pot_stir_path(pot, spoon, tip_offset, [
		Vector2(-24.0, -24.0),
		Vector2(-16.0, -24.0),
		Vector2(-8.0, -24.0),
		Vector2(0.0, -24.0),
		Vector2(8.0, -24.0),
		Vector2(16.0, -24.0),
	])
	var active_stir_count := _pot_effect_kind_count(pot, "stir")
	var active_elements := _pot_effect_elements(pot)
	_ok(active_stir_count >= 16,
		"real stirring creates dense motion from many individual pot effect nodes: got %d" % active_stir_count)
	_ok(active_elements.has("bubble") and active_elements.has("ripple") and active_elements.has("steam")
			and active_elements.has("fleck") and active_elements.has("oil"),
		"real stirring mixes bubbles, ripples, steam, food flecks, and oil glints")
	var fleck_effect := _first_pot_effect_with_element(pot, "fleck")
	var oil_effect := _first_pot_effect_with_element(pot, "oil")
	_ok(_pot_effect_region_row(fleck_effect) == 4,
		"food flecks use their own pot atlas row")
	_ok(_pot_effect_region_row(oil_effect) == 5,
		"oil glints use their own pot atlas row")
	var first_stir_effect := _first_pot_effect(pot, "stir")
	_ok(_pot_effect_uses_runtime_sprite(first_stir_effect),
		"pot effects use the generated runtime sprite atlas")
	_ok(_pot_effect_region_row(first_stir_effect) >= 0,
		"pot effect sprite chooses a valid atlas row")
	_clear_pot_effects(pot)

	pot._state._stir_progress = pot.required_stir * 0.82
	pot._physics_process(0.75)
	_ok(_pot_effect_kind_count(pot, "simmer") >= 1,
		"high-progress loaded pot keeps simmering")
	_ok(_pot_effect_elements(pot).has("aroma"),
		"high-progress simmer starts showing warm aroma before completion")
	_clear_pot_effects(pot)

	pot._state.add_item("herb")
	if GameManager.craft.has_method("is_recipe_discovered"):
		_ok(not GameManager.craft.call("is_recipe_discovered", "herb_broth"),
			"pot test recipe starts undiscovered")
	else:
		_ok(false, "craft discovery query exists before pot completion")
	var item_count_before := items.get_child_count()
	pot._finish_current(GameManager.craft.query_recipe("pot", pot._state.ingredients()))
	_ok(items.get_child_count() == item_count_before + 1,
		"pot ready test produces a crafted item")
	if GameManager.craft.has_method("is_recipe_discovered"):
		_ok(GameManager.craft.call("is_recipe_discovered", "herb_broth"),
			"pot completion discovers herb_broth")
	_ok(_pot_effect_kind_count(pot, "ready") >= 6,
		"pot completion emits a warm ready burst")
	_ok(_pot_effect_elements(pot).has("aroma"),
		"pot completion uses aroma elements instead of implying a quality tier")

	tavern.queue_free()
	await get_tree().process_frame


func _drive_pot_stir_path(pot: KitchenContainer, spoon: StirSpoon, tip_offset: Vector2, local_points: Array[Vector2]) -> void:
	for local_point in local_points:
		spoon.global_position = pot.to_global(local_point) - tip_offset
		pot._accumulate_stir(spoon, 0.05)


func _spawn_barrel_test_bubble(brewery: Brewery, shake_count: int, shake_speed: float = 260.0) -> Node2D:
	_clear_barrel_test_bubbles(brewery)
	brewery._shake.reset()
	if brewery.has_method("_reset_brew_combo_feedback"):
		brewery.call("_reset_brew_combo_feedback")
	brewery.begin_shake_session()
	brewery.linear_velocity = Vector2(shake_speed, 0.0)
	brewery._physics_process(0.05)
	var dir := -1.0
	while brewery._shake.shake_count < shake_count:
		brewery.linear_velocity = Vector2(shake_speed * dir, 0.0)
		brewery._physics_process(0.05)
		dir *= -1.0
		if brewery._shake.shake_count < shake_count:
			_clear_barrel_test_bubbles(brewery)
	var layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	if layer == null or layer.get_child_count() == 0:
		return null
	return layer.get_child(0) as Node2D


func _drive_barrel_combo_to(brewery: Brewery, target_combo: int) -> void:
	brewery._pending_keys = ["ale"]
	if not brewery._session_active:
		brewery.begin_shake_session()
	var direction := 1.0
	var guard := 0
	while _brewery_combo_value(brewery) < target_combo and guard < target_combo * 4 + 16:
		brewery.linear_velocity = Vector2(280.0 * direction, 0.0)
		brewery._physics_process(0.045)
		direction *= -1.0
		guard += 1


func _brewery_combo_value(brewery: Brewery) -> int:
	var value = brewery.get("_brew_combo")
	if value == null:
		return 0
	return int(value)


func _clear_barrel_test_bubbles(brewery: Brewery, reset_foam_pressure: bool = true) -> void:
	var layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	if layer != null:
		for child in layer.get_children():
			child.free()
	brewery._shake_bubbles.clear()
	if reset_foam_pressure:
		brewery._shake_bubble_foam_pressure = 0.0


func _fill_barrel_test_bubbles(brewery: Brewery, quality: String, count: int, local_position: Vector2) -> void:
	var layer := brewery._ensure_shake_bubble_layer() as Node2D
	for i in range(count):
		var bubble := Node2D.new()
		bubble.name = "Bubble"
		bubble.set_meta("barrel_bubble_quality", quality)
		layer.add_child(bubble)
		bubble.global_position = brewery.to_global(local_position)
		brewery._shake_bubbles.append(bubble)


func _barrel_bubble_quality(bubble: Node2D) -> String:
	if bubble == null or not bubble.has_meta("barrel_bubble_quality"):
		return ""
	return String(bubble.get_meta("barrel_bubble_quality"))


func _barrel_bubble_pixel_count(bubble: Node2D) -> int:
	var sprite := _barrel_bubble_sprite(bubble)
	if sprite == null or sprite.texture == null:
		return 0
	var image := sprite.texture.get_image()
	if image == null:
		return 0
	var region := sprite.region_rect
	var count := 0
	for y in range(int(region.position.y), int(region.position.y + region.size.y)):
		for x in range(int(region.position.x), int(region.position.x + region.size.x)):
			if image.get_pixel(x, y).a > 0.01:
				count += 1
	return count


func _barrel_bubble_layer_count(brewery: Brewery) -> int:
	var layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func _barrel_bubble_horizontal_span(brewery: Brewery) -> float:
	var layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	if layer == null:
		return 0.0
	var has_bubble := false
	var min_x := 0.0
	var max_x := 0.0
	for child in layer.get_children():
		if child.is_queued_for_deletion() or not child is Node2D:
			continue
		var bubble := child as Node2D
		if not has_bubble:
			min_x = bubble.global_position.x
			max_x = bubble.global_position.x
			has_bubble = true
		else:
			min_x = minf(min_x, bubble.global_position.x)
			max_x = maxf(max_x, bubble.global_position.x)
	if not has_bubble:
		return 0.0
	return max_x - min_x


func _barrel_bubble_max_abs_local_x(brewery: Brewery) -> float:
	var layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	if layer == null:
		return 0.0
	var max_local_x := 0.0
	for child in layer.get_children():
		if child.is_queued_for_deletion() or not child is Node2D:
			continue
		var bubble := child as Node2D
		max_local_x = maxf(max_local_x, absf(brewery.to_local(bubble.global_position).x))
	return max_local_x


func _barrel_bubble_min_local_y(brewery: Brewery) -> float:
	var layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	if layer == null:
		return 0.0
	var has_bubble := false
	var min_local_y := 0.0
	for child in layer.get_children():
		if child.is_queued_for_deletion() or not child is Node2D:
			continue
		var bubble := child as Node2D
		var local_y := brewery.to_local(bubble.global_position).y
		if not has_bubble:
			min_local_y = local_y
			has_bubble = true
		else:
			min_local_y = minf(min_local_y, local_y)
	return min_local_y if has_bubble else 0.0


func _barrel_bubble_mouth_origin_count(brewery: Brewery) -> int:
	var layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child.is_queued_for_deletion() or not child is Node2D:
			continue
		var bubble := child as Node2D
		var local_position := brewery.to_local(bubble.global_position)
		if absf(local_position.x) <= 48.0 and local_position.y >= -88.0 and local_position.y <= -48.0:
			count += 1
	return count


func _barrel_bubble_quality_count(brewery: Brewery, quality: String) -> int:
	var layer := brewery.get_node_or_null("ShakeBubbles") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Node2D and String(child.get_meta("barrel_bubble_quality", "")) == quality:
			count += 1
	return count


func _barrel_bubble_vivid_hue_bucket_count(bubble: Node2D) -> int:
	var sprite := _barrel_bubble_sprite(bubble)
	if sprite == null or sprite.texture == null:
		return 0
	var image := sprite.texture.get_image()
	if image == null:
		return 0
	var region := sprite.region_rect
	var buckets := {}
	for y in range(int(region.position.y), int(region.position.y + region.size.y)):
		for x in range(int(region.position.x), int(region.position.x + region.size.x)):
			var color := image.get_pixel(x, y)
			if color.a <= 0.01:
				continue
			var max_channel := maxf(color.r, maxf(color.g, color.b))
			var min_channel := minf(color.r, minf(color.g, color.b))
			if max_channel < 0.35 or max_channel - min_channel < 0.25:
				continue
			var bucket := "red"
			if color.r >= color.g and color.r >= color.b:
				bucket = "yellow" if color.g >= 0.55 else "red"
			elif color.g >= color.r and color.g >= color.b:
				bucket = "green"
			elif color.b >= color.r and color.b >= color.g:
				bucket = "purple" if color.r >= 0.55 else "blue"
			buckets[bucket] = true
	return buckets.size()


func _barrel_bubble_sprite(bubble: Node2D) -> Sprite2D:
	if bubble == null:
		return null
	return bubble.get_node_or_null("Sprite") as Sprite2D


func _barrel_bubble_uses_runtime_sprite(bubble: Node2D) -> bool:
	var sprite := _barrel_bubble_sprite(bubble)
	if sprite == null or sprite.texture == null:
		return false
	return sprite.texture.resource_path == "res://assets/textures/barrel_bubbles/barrel_bubbles.png"


func _barrel_bubble_region_row(bubble: Node2D) -> int:
	var sprite := _barrel_bubble_sprite(bubble)
	if sprite == null or sprite.region_rect.size.y <= 0.0:
		return -1
	return int(round(sprite.region_rect.position.y / sprite.region_rect.size.y))


func _normal_brew_feedback_count(brewery: Brewery) -> int:
	var layer := brewery.get_node_or_null("NormalBrewFeedback") as Node2D
	if layer == null:
		return 0
	return layer.get_child_count()


func _first_normal_brew_feedback_effect(brewery: Brewery) -> Node2D:
	var layer := brewery.get_node_or_null("NormalBrewFeedback") as Node2D
	if layer == null or layer.get_child_count() == 0:
		return null
	return layer.get_child(0) as Node2D


func _product_output_vfx_count(product: DeskItem, element: String) -> int:
	if product == null:
		return 0
	var vfx := product.get_node_or_null("BrewProductVfx") as Node2D
	if vfx == null:
		return 0
	var count := 0
	for child in vfx.get_children():
		if child is Node2D and String(child.get_meta("brew_product_vfx_element", "")) == element:
			count += 1
	return count


func _desk_item_motion_trail_count(item: DeskItem) -> int:
	if item == null or not is_instance_valid(item):
		return 0
	var layer := item.get_node_or_null("MotionTrail") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D and bool(child.get_meta("desk_item_motion_trail", false)):
			count += 1
	return count


func _physics_body_motion_trail_count(body: Node2D) -> int:
	if body == null or not is_instance_valid(body):
		return 0
	var layer := body.get_node_or_null("MotionTrail") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D and bool(child.get_meta("physics_motion_trail", false)):
			count += 1
	return count


func _brew_output_burst_count(brewery: Brewery, quality: String, element: String) -> int:
	var layer := brewery.get_node_or_null("BrewOutputBurst") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if not child is Node2D:
			continue
		if String(child.get_meta("brew_output_burst_quality", "")) != quality:
			continue
		if String(child.get_meta("brew_output_burst_element", "")) == element:
			count += 1
	return count


func _barrel_celebration_elements(brewery: Brewery) -> Array[String]:
	var layer := brewery.get_node_or_null("GoodBrewCelebration") as Node2D
	var elements: Array[String] = []
	if layer == null:
		return elements
	for child in layer.get_children():
		if not child is Node2D:
			continue
		var element := String(child.get_meta("barrel_celebration_element", ""))
		if element != "" and not elements.has(element):
			elements.append(element)
	return elements


func _barrel_celebration_count(brewery: Brewery, element: String) -> int:
	var layer := brewery.get_node_or_null("GoodBrewCelebration") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D and String(child.get_meta("barrel_celebration_element", "")) == element:
			count += 1
	return count


func _first_barrel_celebration_effect(brewery: Brewery) -> Node2D:
	var layer := brewery.get_node_or_null("GoodBrewCelebration") as Node2D
	if layer == null or layer.get_child_count() == 0:
		return null
	return layer.get_child(0) as Node2D


func _first_barrel_celebration_effect_with_element(brewery: Brewery, element: String) -> Node2D:
	var layer := brewery.get_node_or_null("GoodBrewCelebration") as Node2D
	if layer == null:
		return null
	for child in layer.get_children():
		if child is Node2D and String(child.get_meta("barrel_celebration_element", "")) == element:
			return child as Node2D
	return null


func _barrel_celebration_sprite(effect: Node2D) -> Sprite2D:
	if effect == null:
		return null
	return effect.get_node_or_null("Sprite") as Sprite2D


func _barrel_celebration_uses_runtime_sprite(effect: Node2D) -> bool:
	var sprite := _barrel_celebration_sprite(effect)
	if sprite == null or sprite.texture == null:
		return false
	return sprite.texture.resource_path == "res://assets/textures/barrel_celebration/barrel_celebration.png"


func _barrel_celebration_region_row(effect: Node2D) -> int:
	var sprite := _barrel_celebration_sprite(effect)
	if sprite == null or sprite.region_rect.size.y <= 0.0:
		return -1
	return int(round(sprite.region_rect.position.y / sprite.region_rect.size.y))


func _seasoning_powder_count(shaker: SeasoningShaker) -> int:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func _intake_vfx_count(container: Node, element: String) -> int:
	return _intake_vfx_nodes(container, element).size()


func _intake_vfx_elements_render_below_container_art(container: Node, element: String) -> bool:
	var art := container.get_node_or_null("Art") as CanvasItem
	if art == null:
		return false
	var art_z := _canvas_absolute_z(art)
	var nodes := _intake_vfx_nodes(container, element)
	if nodes.is_empty():
		return false
	for node in nodes:
		if _canvas_absolute_z(node) >= art_z:
			return false
	return true


func _intake_vfx_nodes(container: Node, element: String) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var layer := container.get_node_or_null("IngredientIntakeVfx") as Node2D
	if layer == null:
		return result
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("ingredient_intake_vfx_element", "")) == element:
			result.append(child as Node2D)
	return result


func _canvas_absolute_z(item: CanvasItem) -> int:
	var total := item.z_index
	var cursor := item
	while cursor.z_as_relative:
		var parent := cursor.get_parent()
		if not parent is CanvasItem:
			break
		cursor = parent as CanvasItem
		total += cursor.z_index
	return total


func _first_seasoning_powder(shaker: SeasoningShaker) -> Node2D:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer == null:
		return null
	for child in layer.get_children():
		if child is Node2D and not child.is_queued_for_deletion():
			return child as Node2D
	return null


func _seasoning_powder_color(powder: Node2D) -> Color:
	if powder == null:
		return Color.TRANSPARENT
	var sprite := powder.get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		return sprite.modulate
	var pixel := powder.get_node_or_null("Pixel") as Polygon2D
	if pixel != null:
		return pixel.color
	return Color.TRANSPARENT


func _seasoning_powder_kinds(shaker: SeasoningShaker) -> Array[String]:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	var kinds: Array[String] = []
	if layer == null:
		return kinds
	for child in layer.get_children():
		if not child is Node2D or child.is_queued_for_deletion():
			continue
		var kind := String(child.get_meta("seasoning_powder_kind", ""))
		if kind != "" and not kinds.has(kind):
			kinds.append(kind)
	return kinds


func _seasoning_powder_color_bucket_count(shaker: SeasoningShaker) -> int:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer == null:
		return 0
	var buckets := {}
	for child in layer.get_children():
		if not child is Node2D or child.is_queued_for_deletion():
			continue
		var color := _seasoning_powder_color(child as Node2D)
		if color.a <= 0.01:
			continue
		var bucket := "%d:%d:%d" % [int(round(color.r * 10.0)), int(round(color.g * 10.0)), int(round(color.b * 10.0))]
		buckets[bucket] = true
	return buckets.size()


func _seasoning_powder_rotating_count(shaker: SeasoningShaker) -> int:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if not child is Node2D or child.is_queued_for_deletion():
			continue
		if absf(float((child as Node2D).get_meta("seasoning_powder_rotation_speed", 0.0))) > 0.1:
			count += 1
	return count


func _clear_seasoning_powder(shaker: SeasoningShaker) -> void:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer != null:
		for child in layer.get_children():
			child.free()
	var particles = shaker.get("_powder_particles")
	if particles is Array:
		(particles as Array).clear()


func _first_grill_vapor(grill: KitchenContainer) -> Node2D:
	var layer := grill.get_node_or_null("GrillVaporLayer") as Node2D
	if layer == null or layer.get_child_count() == 0:
		return null
	return layer.get_child(0) as Node2D


func _grill_vapor_count(grill: KitchenContainer) -> int:
	var layer := grill.get_node_or_null("GrillVaporLayer") as Node2D
	if layer == null:
		return 0
	return layer.get_child_count()


func _clear_grill_vapors(grill: KitchenContainer) -> void:
	var layer := grill.get_node_or_null("GrillVaporLayer") as Node2D
	if layer == null:
		return
	for child in layer.get_children():
		child.free()


func _grill_vapor_quality(vapor: Node2D) -> String:
	if vapor == null or not vapor.has_meta("grill_vapor_quality"):
		return ""
	return String(vapor.get_meta("grill_vapor_quality"))


func _grill_vapor_sprite(vapor: Node2D) -> Sprite2D:
	if vapor == null:
		return null
	return vapor.get_node_or_null("Sprite") as Sprite2D


func _grill_vapor_uses_runtime_sprite(vapor: Node2D) -> bool:
	var sprite := _grill_vapor_sprite(vapor)
	if sprite == null or sprite.texture == null:
		return false
	return sprite.texture.resource_path == "res://assets/textures/grill_vapor/grill_vapor.png"


func _grill_vapor_region_row(vapor: Node2D) -> int:
	var sprite := _grill_vapor_sprite(vapor)
	if sprite == null or sprite.region_rect.size.y <= 0.0:
		return -1
	return int(round(sprite.region_rect.position.y / sprite.region_rect.size.y))


func _grill_feedback_count(grill: KitchenContainer, element: String) -> int:
	var layer := grill.get_node_or_null("GrillFeedbackLayer") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D and String(child.get_meta("grill_feedback_element", "")) == element:
			count += 1
	return count


func _first_grill_feedback(grill: KitchenContainer, element: String) -> Node2D:
	var layer := grill.get_node_or_null("GrillFeedbackLayer") as Node2D
	if layer == null:
		return null
	for child in layer.get_children():
		if child is Node2D and String(child.get_meta("grill_feedback_element", "")) == element:
			return child as Node2D
	return null


func _grill_feedback_uses_runtime_sprite(effect: Node2D) -> bool:
	if effect == null:
		return false
	var sprite := effect.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.texture == null:
		return false
	return sprite.texture.resource_path == "res://assets/textures/grill_feedback/grill_feedback.png"


func _clear_grill_feedback(grill: KitchenContainer) -> void:
	var layer := grill.get_node_or_null("GrillFeedbackLayer") as Node2D
	if layer == null:
		return
	for child in layer.get_children():
		child.free()


func _pot_effect_count(pot: KitchenContainer) -> int:
	var layer := pot.get_node_or_null("PotEffectLayer") as Node2D
	if layer == null:
		return 0
	return layer.get_child_count()


func _pot_effect_kind_count(pot: KitchenContainer, kind: String) -> int:
	var layer := pot.get_node_or_null("PotEffectLayer") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D and String(child.get_meta("pot_effect_kind", "")) == kind:
			count += 1
	return count


func _pot_effect_elements(pot: KitchenContainer) -> Array[String]:
	var layer := pot.get_node_or_null("PotEffectLayer") as Node2D
	var elements: Array[String] = []
	if layer == null:
		return elements
	for child in layer.get_children():
		if not child is Node2D:
			continue
		var element := String(child.get_meta("pot_effect_element", ""))
		if element != "" and not elements.has(element):
			elements.append(element)
	return elements


func _first_pot_effect(pot: KitchenContainer, kind: String) -> Node2D:
	var layer := pot.get_node_or_null("PotEffectLayer") as Node2D
	if layer == null:
		return null
	for child in layer.get_children():
		if child is Node2D and String(child.get_meta("pot_effect_kind", "")) == kind:
			return child as Node2D
	return null


func _first_pot_effect_with_element(pot: KitchenContainer, element: String) -> Node2D:
	var layer := pot.get_node_or_null("PotEffectLayer") as Node2D
	if layer == null:
		return null
	for child in layer.get_children():
		if child is Node2D and String(child.get_meta("pot_effect_element", "")) == element:
			return child as Node2D
	return null


func _clear_pot_effects(pot: KitchenContainer) -> void:
	var layer := pot.get_node_or_null("PotEffectLayer") as Node2D
	if layer == null:
		return
	for child in layer.get_children():
		child.free()


func _pot_effect_sprite(effect: Node2D) -> Sprite2D:
	if effect == null:
		return null
	return effect.get_node_or_null("Sprite") as Sprite2D


func _pot_effect_uses_runtime_sprite(effect: Node2D) -> bool:
	var sprite := _pot_effect_sprite(effect)
	if sprite == null or sprite.texture == null:
		return false
	return sprite.texture.resource_path == "res://assets/textures/pot_effects/pot_effects.png"


func _pot_effect_region_row(effect: Node2D) -> int:
	var sprite := _pot_effect_sprite(effect)
	if sprite == null or sprite.region_rect.size.y <= 0.0:
		return -1
	return int(round(sprite.region_rect.position.y / sprite.region_rect.size.y))


func _test_held_items_render_below_container_visuals() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var item := bar._spawn_desk_item_at(Vector2(120.0, 120.0), "ale")
	item.freeze = true
	var surface_z_index := item.z_index
	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	var shaker := tavern.get_node("BarWorkspace/World/SeasoningShaker") as SeasoningShaker
	var grill := tavern.get_node("BarWorkspace/World/Grill") as KitchenContainer
	var pot := tavern.get_node("BarWorkspace/World/Pot") as KitchenContainer
	var containers: Array = [
		[brewery, brewery._mouth_center_global_position()],
		[shaker, shaker._mouth_center_global_position()],
		[grill, (grill.get_node("Intake") as Area2D).global_position],
		[pot, (pot.get_node("Intake") as Area2D).global_position],
	]
	bar._drag_ctrl.start_drag(item, item.global_position)
	for pair in containers:
		var container: Node2D = pair[0]
		var target_global: Vector2 = pair[1]
		var art := container.get_node("Art") as Sprite2D
		item.global_position = target_global
		bar._physics_process(0.0)
		_ok(item.z_index < art.z_index + container.z_index,
			"held item renders below %s visual while inside: item %d, art %d" % [container.name, item.z_index, art.z_index + container.z_index])
		_ok(item.z_index == BarWorkspace.SUBMERGED_ITEM_Z_INDEX,
			"held item switches to submerged z inside %s: expected %d, got %d" % [
				container.name,
				BarWorkspace.SUBMERGED_ITEM_Z_INDEX,
				item.z_index,
			])

	item.global_position = Vector2(120.0, 120.0)
	bar._physics_process(0.0)
	_ok(item.z_index == surface_z_index,
		"held item restores surface depth after leaving containers: expected %d, got %d" % [surface_z_index, item.z_index])
	bar._drag_ctrl.end_drag()
	item.queue_free()
	tavern.queue_free()
	await get_tree().process_frame
