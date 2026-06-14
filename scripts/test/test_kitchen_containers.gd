extends Node

var _checks := 0
var _failures := 0
const KITCHEN_CONTAINER_SCRIPT := preload("res://scripts/ui/kitchen_container.gd")


func _ready() -> void:
	_test_meat_doneness()
	_test_meat_orientation()
	_test_pot_stir_progress()
	_test_pot_pop_last_item()
	_test_barrel_pop_last_ingredient()
	_test_pot_intake_requires_center_inside_mouth()
	_test_grill_continues_searing_cooked_items()
	_test_mapped_art_can_be_reapplied_after_item_state_changes()
	_test_grill_timer_changes_item_state_without_heat_color_animation()
	await _test_grill_auto_sears_and_held_accelerates()
	await _test_grill_feedback_uses_generated_atlas()
	_test_pot_unfreezes_while_held()
	_test_recipe_data()
	_test_desk_item_split_visuals()
	_test_tavern_scene_nodes()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-KITCHEN] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-KITCHEN] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-KITCHEN] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _new_state():
	var script = load("res://scripts/systems/cook_station_state.gd")
	_ok(script != null, "cook station state script should exist")
	return script.new()


func _test_meat_doneness() -> void:
	var doneness = MeatDoneness.new()
	doneness.set_raw_color(Color(0.65, 0.2, 0.1))
	_ok(doneness.result() == "raw", "fresh meat is raw")
	doneness.add_heat(0, 1.0)
	_ok(doneness.result() == "cooked", "single-side sear to cooked threshold produces cooked result")
	_ok(doneness.face_color(0) == MeatDoneness.GOLDEN, "cooked meat uses golden color")
	_ok(doneness.face_color(1) == MeatDoneness.GOLDEN, "visual halves share the same single-side doneness color")
	doneness.add_heat(0, 1.5)
	_ok(doneness.result() == "burnt", "continued single-side sear past burn max burns the item")


func _test_meat_orientation() -> void:
	_ok(MeatDoneness.down_face_of(Vector2(0, -10), Vector2(0, 10)) == 1, "lower marker face1 is down")
	_ok(MeatDoneness.down_face_of(Vector2(0, 10), Vector2(0, -10)) == 0, "lower marker face0 is down")
	_ok(MeatDoneness.down_face_of(Vector2(0, 5), Vector2(0, 5)) == 0, "tie resolves to face0")


func _test_pot_stir_progress() -> void:
	var state = _new_state()
	state.configure_pot(3.0)
	state.add_item("meat_raw")
	state.add_item("ale")
	state.add_stir(1.0)
	_ok(not state.is_ready(), "pot should wait for enough stirring")
	state.add_stir(2.0)
	_ok(state.is_ready(), "pot should become ready after required stirring")
	_ok(state.ingredients() == ["meat_raw", "ale"], "pot should preserve ingredient order for caller")
	state.clear()
	_ok(state.ingredients().is_empty(), "clear should remove consumed ingredients")


func _test_pot_pop_last_item() -> void:
	var state = _new_state()
	state.configure_pot(3.0)
	state.add_item("ale")
	state.add_item("herb")
	state.add_stir(2.0)
	_ok(state.pop_last_item() == "herb", "pot pops newest ingredient first")
	_ok(state.ingredients() == ["ale"], "pot keeps older ingredients after pop")
	state.add_stir(1.0)
	_ok(not state.is_ready(), "pot pop resets prior stir progress")
	_ok(state.pop_last_item() == "ale", "pot pops remaining ingredient")
	_ok(state.pop_last_item() == "", "empty pot pop is a no-op")


func _test_barrel_pop_last_ingredient() -> void:
	var scene := load("res://scenes/ui/Tavern.tscn") as PackedScene
	_ok(scene != null, "Tavern scene should load for barrel pop test")
	var tavern := scene.instantiate()
	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	brewery._pending_keys = ["ale", "herb"]
	brewery._shake.shake_count = 3
	_ok(brewery.pop_last_ingredient() == "herb", "barrel pops newest ingredient first")
	_ok(brewery._pending_keys == ["ale"], "barrel keeps older ingredients after pop")
	_ok(brewery._shake.shake_count == 0, "barrel pop resets prior shake progress")
	_ok(brewery.pop_last_ingredient() == "ale", "barrel pops remaining ingredient")
	_ok(brewery.pop_last_ingredient() == "", "empty barrel pop is a no-op")
	tavern.free()


func _test_pot_intake_requires_center_inside_mouth() -> void:
	var pot = KITCHEN_CONTAINER_SCRIPT.new()
	pot.container_key = "pot"
	pot.global_position = Vector2(100, 100)
	var item := Node2D.new()
	item.global_position = Vector2(100, 62)
	_ok(pot.is_item_inside_intake(item), "pot should accept item whose center is inside the mouth")
	item.global_position = Vector2(100, 88)
	_ok(not pot.is_item_inside_intake(item), "pot should not accept item that only touches the lower rim")
	item.global_position = Vector2(150, 62)
	_ok(not pot.is_item_inside_intake(item), "pot should not accept item outside mouth width")
	item.free()
	pot.free()


func _test_grill_continues_searing_cooked_items() -> void:
	var grill = KITCHEN_CONTAINER_SCRIPT.new()
	grill.container_key = "grill"
	_ok(grill.can_sear_item_key("meat_cooked"), "cooked meat should keep searing toward burnt")
	_ok(grill.can_sear_item_key("bread"), "bread should keep searing toward burnt")
	_ok(not grill.can_sear_item_key("wine"), "unrelated finished products should not sear on grill")
	grill.free()


func _test_mapped_art_can_be_reapplied_after_item_state_changes() -> void:
	var item := _spawn_desk_item("ale_beer")
	var art := item.get_node_or_null("IconArt") as Sprite2D
	_ok(art != null and not art.visible, "set_item alone leaves product art hidden until mapped art is applied")
	GameManager.apply_material_icon_to_desk_item(item)
	art = item.get_node_or_null("IconArt") as Sprite2D
	_ok(art != null and art.visible, "mapped art application should show product IconArt")
	_ok(art != null and art.texture != null and art.texture.resource_path == "res://assets/textures/tavern/items/ale_beer.png",
		"mapped art application should use the Tavern ale item art path")
	item.queue_free()


func _test_grill_timer_changes_item_state_without_heat_color_animation() -> void:
	var grill = KITCHEN_CONTAINER_SCRIPT.new()
	grill.container_key = "grill"
	grill.cook_time = 2.0
	grill.burn_time = 5.0
	var item := _spawn_desk_item("meat_raw")
	GameManager.apply_material_icon_to_desk_item(item)
	var art := item.get_node_or_null("IconArt") as Sprite2D
	_ok(art != null and art.visible, "raw grill item starts with mapped art visible")
	var top_visual := item.get_node("VisualTop") as Polygon2D
	var raw_color := top_visual.color
	grill._advance_grill_item(item, grill.cook_time - 0.1)
	_ok(item.item_key == "meat_raw", "grill should not change item state before cook_time")
	_ok(top_visual.color == raw_color, "grill should not animate item color while cooking")
	_ok(art != null and art.visible, "grill should keep mapped art visible while cooking")
	grill._advance_grill_item(item, 0.1)
	art = item.get_node_or_null("IconArt") as Sprite2D
	_ok(item.item_key == "meat_cooked", "grill should switch raw meat to cooked meat at cook_time")
	_ok(art != null and art.visible, "cooked grill product should show mapped art")
	_ok(art != null and art.texture != null and art.texture.resource_path == "res://assets/textures/tavern/items/meat_cooked.png",
		"cooked grill product should use the Tavern cooked meat item art path")
	grill._advance_grill_item(item, grill.burn_time - grill.cook_time - 0.1)
	_ok(item.item_key == "meat_cooked", "cooked meat should not burn before burn_time")
	grill._advance_grill_item(item, 0.1)
	art = item.get_node_or_null("IconArt") as Sprite2D
	_ok(item.item_key == "meat_burnt", "cooked meat should switch to burnt meat after another timed grill pass")
	_ok(art != null and art.visible and art.texture.resource_path == "res://assets/textures/tavern/items/meat_burnt.png",
		"burnt grill product should use the burnt item icon")
	item.queue_free()
	grill.free()


func _test_grill_auto_sears_and_held_accelerates() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	var bar := tavern.get_node("BarWorkspace")
	bar.configure_day(2)
	await get_tree().process_frame
	var grill := tavern.get_node("BarWorkspace/World/Grill") as KitchenContainer
	var sear_zone := grill.get_node("SearZone") as Area2D
	grill.cook_time = 1.0
	grill.burn_time = 3.0

	var auto_item: DeskItem = bar._spawn_desk_item_at(sear_zone.global_position, "meat_raw")
	auto_item.freeze = true
	auto_item.is_held = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	grill._physics_process(0.55)
	_ok(auto_item.item_key == "meat_raw",
		"resting meat should not auto-finish before cook_time")
	grill._physics_process(0.50)
	_ok(auto_item.item_key == "meat_cooked",
		"resting meat on the grill should auto-cook after enough time")
	auto_item.queue_free()
	await get_tree().physics_frame

	var held_item: DeskItem = bar._spawn_desk_item_at(sear_zone.global_position, "meat_raw")
	held_item.freeze = true
	held_item.is_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	grill._physics_process(0.45)
	_ok(held_item.item_key == "meat_cooked",
		"held meat should cook faster than the passive grill rate")

	tavern.queue_free()
	await get_tree().process_frame


func _test_grill_feedback_uses_generated_atlas() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	var bar := tavern.get_node("BarWorkspace")
	bar.configure_day(2)
	await get_tree().process_frame
	var grill := tavern.get_node("BarWorkspace/World/Grill") as KitchenContainer
	var sear_zone := grill.get_node("SearZone") as Area2D
	grill.cook_time = 1.0
	grill.burn_time = 3.0

	var item: DeskItem = bar._spawn_desk_item_at(sear_zone.global_position, "meat_raw")
	item.freeze = true
	item.is_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	grill._physics_process(0.13)
	_ok(_grill_feedback_uses_runtime_sprite(grill, "press_spark"),
		"pressed grill oil sparks should use the generated grill feedback atlas")

	grill._advance_grill_item(item, grill.cook_time)
	_ok(_grill_feedback_uses_runtime_sprite(grill, "done_spark"),
		"finished grill sparks should use the generated grill feedback atlas")

	grill._advance_grill_item(item, grill.burn_time - grill.cook_time)
	_ok(_grill_feedback_uses_runtime_sprite(grill, "char_spark"),
		"burnt grill embers should use the generated grill feedback atlas")

	tavern.queue_free()
	await get_tree().process_frame


func _test_pot_unfreezes_while_held() -> void:
	var pot = KITCHEN_CONTAINER_SCRIPT.new()
	pot.container_key = "pot"
	pot.freeze = true
	pot.begin_action_session()
	_ok(not pot.freeze, "pot should unfreeze while held so drag can move it")
	pot.end_action_session()
	_ok(pot.freeze, "pot should refreeze after release for stable stirring")
	pot.free()


func _test_recipe_data() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	_ok(craft.query_recipe("grill", ["flour"]) == "bread", "flour on grill should make bread")
	_ok(craft.query_recipe("grill", ["meat_raw"]) == "meat_cooked", "meat on grill should make cooked meat")
	_ok(craft.query_recipe("grill", ["meat_raw", "flour"]) == "meat_sand", "grill two ingredient order should not matter")
	_ok(craft.query_recipe("pot", ["meat_raw", "ale"]) == "meat_stew", "meat and ale in pot should make stew")
	_ok(craft.query_recipe("pot", ["ale", "herb"]) == "herb_broth", "herb and ale in pot should make broth")
	_ok(craft.query_recipe("pot", ["flour", "ale"]) == "malt_porridge", "flour and ale in pot should make porridge")


func _test_desk_item_split_visuals() -> void:
	var scene := load("res://scenes/test/desk_item.tscn") as PackedScene
	_ok(scene != null, "desk item scene should load")
	var item := scene.instantiate()
	_ok(item.get_node_or_null("VisualTop") is Polygon2D, "desk item keeps a top visual half")
	_ok(item.get_node_or_null("VisualBottom") is Polygon2D, "desk item keeps a bottom visual half")
	_ok(item.get_node_or_null("FaceTop") is Marker2D, "desk item has FaceTop marker")
	_ok(item.get_node_or_null("FaceBottom") is Marker2D, "desk item has FaceBottom marker")
	item.free()


func _test_tavern_scene_nodes() -> void:
	var scene := load("res://scenes/ui/Tavern.tscn") as PackedScene
	_ok(scene != null, "Tavern scene should load")
	var tavern := scene.instantiate()
	var grill := tavern.get_node_or_null("BarWorkspace/World/Grill")
	var pot := tavern.get_node_or_null("BarWorkspace/World/Pot")
	_ok(grill != null and grill.get_script() == KITCHEN_CONTAINER_SCRIPT, "Tavern should contain a KitchenContainer grill")
	_ok(pot != null and pot.get_script() == KITCHEN_CONTAINER_SCRIPT, "Tavern should contain a KitchenContainer pot")
	_ok(grill.get("container_key") == "grill", "grill container_key should be grill")
	_ok(pot.get("container_key") == "pot", "pot container_key should be pot")
	_ok(grill.get_node_or_null("SearZone") is Area2D, "grill should have a SearZone for press-searing")
	_ok(pot.get_node_or_null("Body") == null, "pot should not use a closed rectangle body over the mouth")
	_ok(pot.get_node_or_null("WallLeft") != null, "pot should have an open left wall")
	_ok(pot.get_node_or_null("WallRight") != null, "pot should have an open right wall")
	_ok(pot.get_node_or_null("WallBottom") != null, "pot should have a bottom wall")
	_ok(pot.get_node_or_null("RimLeft") != null, "pot should have a left rim")
	_ok(pot.get_node_or_null("RimRight") != null, "pot should have a right rim")
	_ok(pot.get_node_or_null("PickupArea") is Area2D, "pot should have a pickup area over the open body")
	var spoon := tavern.get_node_or_null("BarWorkspace/World/Spoon")
	_ok(spoon is StirSpoon, "Tavern should contain a StirSpoon for the pot")
	_ok(spoon.get_node_or_null("Tip") is Marker2D, "stir spoon should expose a Tip marker")
	tavern.queue_free()


func _spawn_desk_item(item_key: String) -> DeskItem:
	var scene := load("res://scenes/test/desk_item.tscn") as PackedScene
	_ok(scene != null, "desk item scene should load for " + item_key)
	var item := scene.instantiate() as DeskItem
	add_child(item)
	item.set_item(item_key, GameManager.craft.get_item(item_key), GameManager.craft.get_item_physics_profiles())
	return item


func _grill_feedback_uses_runtime_sprite(grill: KitchenContainer, element: String) -> bool:
	var layer := grill.get_node_or_null("GrillFeedbackLayer") as Node2D
	if layer == null:
		return false
	for child in layer.get_children():
		if not child is Node2D:
			continue
		if String(child.get_meta("grill_feedback_element", "")) != element:
			continue
		var sprite := child.get_node_or_null("Sprite") as Sprite2D
		if sprite != null and sprite.texture != null \
				and sprite.texture.resource_path == "res://assets/textures/grill_feedback/grill_feedback.png":
			return true
	return false
