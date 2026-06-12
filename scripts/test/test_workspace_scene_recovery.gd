extends Node

const OUT_OF_BOUNDS_Y := 900.0
const KILL_Y := 800.0

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_docked_body_recovers_when_out_of_bounds()
	await _test_inventory_spawn_deducts_and_recovers()
	await _test_material_drop_on_customer_area_stays_on_desk()
	await _test_inventory_overlay_lists_and_drop()
	await _test_shortcut_drag_starts_above_table_baseline()
	await _test_document_overlay_opens_ledger()
	await _test_work_surface_ledger_can_be_dragged()
	await _test_container_ejection_spawns_lifo_desk_items()
	await _test_seasoning_items_fit_into_shaker_mouth()
	await _test_shaker_absorbed_dragged_seasoning_clears_drag_state()
	await _test_workspace_containers_do_not_spawn_work_vfx()
	await _test_spoon_renders_below_container_visuals()
	await _test_held_items_render_below_container_visuals()
	await _test_settings_menu_entry()
	await _test_overlay_menu_renders_above_workspace()
	await _test_recipe_menu_uses_split_layout()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-WORKSPACE-SCENE] FAIL: " + msg)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return String(texture.resource_path)


func _stylebox_texture_path(control: Control, style_name: String) -> String:
	var stylebox := control.get_theme_stylebox(style_name) as StyleBoxTexture
	if stylebox == null:
		return ""
	return _texture_path(stylebox.texture)


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
	var recipe_list := tavern.get_node("OverlayMenu/RecipePanel/RecipeList") as Control
	_ok(recipe_panel != null and recipe_panel.visible, "recipe panel opens inside the legacy overlay menu")
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
	_ok(tabs != null and tabs.get_child_count() == 3, "recipe menu exposes three container filter tabs")
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


func _test_workspace_containers_do_not_spawn_work_vfx() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	var grill := tavern.get_node("BarWorkspace/World/Grill") as KitchenContainer
	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	bar.configure_day(2)
	await get_tree().process_frame

	brewery._pending_keys = ["ale"]
	brewery.begin_shake_session()
	brewery.linear_velocity = Vector2(260.0, 0.0)
	brewery._physics_process(0.016)
	_ok(brewery.get_node_or_null("BubbleVfx") == null, "barrel no longer spawns bubble work vfx")

	var sear_zone := grill.get_node("SearZone") as Area2D
	var item := bar._spawn_desk_item_at(sear_zone.global_position, "meat_raw")
	item.freeze = true
	item.is_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	grill._physics_process(0.016)
	_ok(grill.get_node_or_null("SteamVfx") == null, "grill no longer spawns steam work vfx")

	brewery.end_shake_session()
	tavern.queue_free()
	await get_tree().process_frame


func _test_held_items_render_below_container_visuals() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var item := bar._spawn_desk_item_at(Vector2(120.0, 120.0), "ale")
	item.freeze = true
	var surface_z_index := item.z_index
	var containers: Array = [
		[tavern.get_node("BarWorkspace/World/Brewery"), tavern.get_node("BarWorkspace/World/Brewery/Mouth")],
		[tavern.get_node("BarWorkspace/World/Grill"), tavern.get_node("BarWorkspace/World/Grill/Intake")],
		[tavern.get_node("BarWorkspace/World/Pot"), tavern.get_node("BarWorkspace/World/Pot/Intake")],
	]
	bar._drag_ctrl.start_drag(item, item.global_position)
	for pair in containers:
		var container: Node2D = pair[0]
		var area: Area2D = pair[1]
		var art := container.get_node("Art") as Sprite2D
		item.global_position = area.global_position
		bar._physics_process(0.0)
		_ok(item.z_index < art.z_index + container.z_index,
			"held item renders below %s visual while inside: item %d, art %d" % [container.name, item.z_index, art.z_index + container.z_index])

	item.global_position = Vector2(120.0, 120.0)
	bar._physics_process(0.0)
	_ok(item.z_index == surface_z_index,
		"held item restores surface depth after leaving containers: expected %d, got %d" % [surface_z_index, item.z_index])
	bar._drag_ctrl.end_drag()
	item.queue_free()
	tavern.queue_free()
	await get_tree().process_frame
