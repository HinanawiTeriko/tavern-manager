extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var overlay_scene := load("res://scenes/ui/ShopOverlay.tscn") as PackedScene
	if overlay_scene == null:
		_ok(false, "ShopOverlay scene exists")
		_finish()
		return
	var overlay = overlay_scene.instantiate()
	add_child(overlay)
	overlay.configure(get_node("/root/GameManager"))
	overlay.open()
	await get_tree().process_frame
	_test_core_layout(overlay)
	_test_default_selection(overlay)
	_test_mira_discount_state(overlay)
	_test_material_quantity_total(overlay)
	await _test_purchase_updates_inventory_and_gold(overlay)
	await _test_owned_recipe_state(overlay)
	await _test_close_signal(overlay)
	overlay.queue_free()
	await get_tree().process_frame
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SHOP-OVERLAY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-SHOP-OVERLAY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SHOP-OVERLAY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_core_layout(overlay) -> void:
	_ok(overlay.visible, "overlay is visible after open")
	_ok(overlay.get_node_or_null("SceneBackdrop") is TextureRect, "overlay has native-pixel scene backdrop")
	_ok(overlay.get_node_or_null("BookLayer") is TextureRect, "overlay has book layer")
	_ok(overlay.get_node_or_null("Tabs/MaterialsTab") is Button, "materials tab exists")
	_ok(overlay.get_node_or_null("Tabs/RecipesTab") is Button, "recipes tab exists")
	_ok(overlay.get_node_or_null("Tabs/AbilitiesTab") is Button, "abilities tab exists")
	_ok(overlay.get_node_or_null("ItemGrid") is GridContainer, "item card grid exists")
	_ok(overlay.get_node_or_null("Detail/Title") is Label, "detail title exists")
	_ok(overlay.get_node_or_null("CounterBar/GoldLabel") is Label, "gold label exists")
	_ok(overlay.get_node_or_null("CounterBar/PurchaseButton") is Button, "purchase button exists")


func _test_default_selection(overlay) -> void:
	_ok(overlay.get_selected_key() == "ale", "default material selection is ale")
	var title := overlay.get_node("Detail/Title") as Label
	_ok(title.text == "麦芽", "detail title shows selected item name")
	var uses := overlay.get_node("Detail/Uses") as Label
	_ok(uses.text.contains("麦芽酒"), "material detail shows recipe usage")


func _test_material_quantity_total(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 1
	overlay.select_item("ale")
	overlay.set_quantity(3)
	var total := overlay.get_node("CounterBar/TotalLabel") as Label
	_ok(total.text.contains("6"), "quantity total uses material unit price")
	_ok(overlay.get_quantity() == 3, "overlay stores selected quantity")


func _test_mira_discount_state(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 4
	overlay.select_item("ale")
	overlay.set_quantity(1)
	var total := overlay.get_node("CounterBar/TotalLabel") as Label
	_ok(total.text.contains("1"), "Mira day material total uses discounted unit price")
	var state := overlay.get_node("Detail/State") as Label
	_ok(state.text.contains("2→1金"), "Mira day state shows base to discount price")


func _test_purchase_updates_inventory_and_gold(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 1
	gm.economy.gold = 30
	var before_count: int = gm.inventory_sys.get_count("ale")
	overlay.select_item("ale")
	overlay.set_quantity(2)
	overlay.purchase_selected()
	await get_tree().process_frame
	_ok(gm.inventory_sys.get_count("ale") == before_count + 2, "buying material adds inventory")
	_ok(gm.economy.gold == 26, "buying two ale spends 4 gold")
	_ok(overlay.get_quantity() == 0, "material quantity resets after successful purchase")


func _test_owned_recipe_state(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.craft.unlock_recipe("herbal_ale")
	overlay.select_category("recipes")
	await get_tree().process_frame
	overlay.select_item("herbal_ale")
	var purchase := overlay.get_node("CounterBar/PurchaseButton") as Button
	_ok(purchase.disabled, "owned recipe disables purchase button")
	var state := overlay.get_node("Detail/State") as Label
	_ok(state.text.contains("已拥有"), "owned recipe state is visible")


func _test_close_signal(overlay) -> void:
	var state := {"closed": false}
	overlay.closed.connect(func(): state["closed"] = true)
	overlay.close()
	await get_tree().process_frame
	_ok(bool(state["closed"]), "close emits closed signal")
	_ok(not overlay.visible, "overlay hides after close")
