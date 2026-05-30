extends Node

var _checks := 0
const KITCHEN_CONTAINER_SCRIPT := preload("res://scripts/ui/kitchen_container.gd")


func _ready() -> void:
	_test_meat_doneness()
	_test_meat_orientation()
	_test_pot_stir_progress()
	_test_pot_intake_requires_center_inside_mouth()
	_test_recipe_data()
	_test_desk_item_two_faces()
	_test_tavern_scene_nodes()
	print("[TEST-KITCHEN] ALL PASS (", _checks, " checks)")
	get_tree().quit()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	assert(cond, "[TEST-KITCHEN] FAIL: " + msg)


func _new_state():
	var script = load("res://scripts/systems/cook_station_state.gd")
	_ok(script != null, "cook station state script should exist")
	return script.new()


func _test_meat_doneness() -> void:
	var doneness = MeatDoneness.new()
	doneness.set_raw_color(Color(0.65, 0.2, 0.1))
	_ok(doneness.result() == "raw", "fresh meat is raw")
	doneness.add_heat(0, 1.0)
	_ok(doneness.result() == "raw", "one cooked face and one raw face is still raw")
	doneness.add_heat(1, 1.0)
	_ok(doneness.result() == "cooked", "both cooked faces produce cooked result")
	doneness.add_heat(0, 1.5)
	_ok(doneness.result() == "burnt", "any face past burn max burns the item")
	_ok(doneness.face_color(1) == MeatDoneness.GOLDEN, "cooked face uses golden color")


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


func _test_recipe_data() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	_ok(craft.query_recipe("grill", ["flour"]) == "bread", "flour on grill should make bread")
	_ok(craft.query_recipe("grill", ["meat_raw"]) == "meat_cooked", "meat on grill should make cooked meat")
	_ok(craft.query_recipe("grill", ["meat_raw", "flour"]) == "meat_sand", "grill two ingredient order should not matter")
	_ok(craft.query_recipe("pot", ["meat_raw", "ale"]) == "meat_stew", "meat and ale in pot should make stew")
	_ok(craft.query_recipe("pot", ["ale", "herb"]) == "herb_broth", "herb and ale in pot should make broth")
	_ok(craft.query_recipe("pot", ["flour", "ale"]) == "malt_porridge", "flour and ale in pot should make porridge")


func _test_desk_item_two_faces() -> void:
	var scene := load("res://scenes/test/desk_item.tscn") as PackedScene
	_ok(scene != null, "desk item scene should load")
	var item := scene.instantiate()
	_ok(item.get_node_or_null("VisualTop") is Polygon2D, "desk item has VisualTop half")
	_ok(item.get_node_or_null("VisualBottom") is Polygon2D, "desk item has VisualBottom half")
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
