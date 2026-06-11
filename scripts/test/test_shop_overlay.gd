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
	_test_nearest_filtering(overlay)
	_test_shop_scene_v2_texture_paths(overlay)
	_test_shop_scene_v2_text_safe_layout(overlay)
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
	_ok(overlay.get_node_or_null("ShopBackdrop") is TextureRect, "overlay has shop scene v2 backdrop")
	_ok(overlay.get_node_or_null("ShopStage") == null, "old dark shop stage is removed")
	_ok(overlay.get_node_or_null("MainBrushPanel") is Control, "legacy MainBrushPanel contract root remains")
	_ok(overlay.get_node_or_null("MainBrushPanel/ListPanel") is TextureRect, "legacy list panel path remains")
	_ok(overlay.get_node_or_null("MainBrushPanel/DetailPanelArt") is TextureRect, "legacy detail panel path remains")
	_ok(overlay.get_node_or_null("CategoryTabs/MaterialsZone") is Button, "materials category zone exists")
	_ok(overlay.get_node_or_null("CategoryTabs/RecipesZone") is Button, "recipes category zone exists")
	_ok(overlay.get_node_or_null("CategoryTabs/AbilitiesZone") is Button, "abilities category zone exists")
	_ok(overlay.get_node_or_null("ItemList") is Control, "item list exists")
	_ok(overlay.get_node_or_null("DetailPanel/Title") is Label, "detail title exists")
	_ok(overlay.get_node_or_null("CheckoutBar/StripArt") is TextureRect, "legacy checkout strip path remains")
	_ok(overlay.get_node_or_null("CheckoutBar/GoldAreaArt") is TextureRect, "legacy checkout gold area path remains")
	_ok(overlay.get_node_or_null("CheckoutBar/CheckoutArt") == null, "checkout does not add a second strip art path")
	_ok(overlay.get_node_or_null("CheckoutBar/GoldLabel") is Label, "checkout gold label exists")
	_ok(overlay.get_node_or_null("CheckoutBar/TotalLabel") is Label, "checkout total label exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusArt") is TextureRect, "quantity minus art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/BodyArt") is TextureRect, "quantity body art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusArt") is TextureRect, "quantity plus art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusZone") is Button, "quantity minus zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusZone") is Button, "quantity plus zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") is Button, "purchase zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/CloseButton/CloseZone") is Button, "close zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/CloseButton/CloseLabel") == null, "close button is icon-only")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/ControlArt") == null, "old single quantity art is not used")
	_test_v2_layout_sizes(overlay)
	var purchase := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") as Button
	if purchase != null:
		_ok(purchase.text == "", "purchase input zone is textless")
		_ok(not purchase.has_theme_stylebox_override("normal"), "purchase input zone does not expose normal button skin")
	_ok(overlay.get_node_or_null("BookLayer") == null, "old large ledger layer is removed")
	_ok(overlay.get_node_or_null("Tabs") == null, "old tab container is removed")
	_ok(overlay.get_node_or_null("ItemGrid") == null, "old item card grid is removed")


func _test_v2_layout_sizes(overlay) -> void:
	var list_panel := overlay.get_node_or_null("MainBrushPanel/ListPanel") as TextureRect
	var detail_panel := overlay.get_node_or_null("MainBrushPanel/DetailPanelArt") as TextureRect
	var checkout := overlay.get_node_or_null("CheckoutBar") as Control
	var item_list := overlay.get_node_or_null("ItemList") as Control
	var quantity := overlay.get_node_or_null("CheckoutBar/QuantityControl") as Control
	var purchase := overlay.get_node_or_null("CheckoutBar/PurchaseButton") as Control
	var close := overlay.get_node_or_null("CheckoutBar/CloseButton") as Control
	if list_panel != null:
		_ok(list_panel.position == Vector2(56, 112), "list panel uses v2 runtime position")
		_ok(list_panel.size == Vector2(760, 396), "list panel uses v2 runtime size")
	if detail_panel != null:
		_ok(detail_panel.position == Vector2(864, 112), "detail panel uses v2 runtime position")
		_ok(detail_panel.size == Vector2(360, 396), "detail panel uses v2 runtime size")
	if checkout != null:
		_ok(checkout.position == Vector2(120, 568), "checkout bar uses v2 runtime position")
		_ok(checkout.size == Vector2(1040, 128), "checkout bar uses v2 runtime size")
	if item_list != null:
		var first_row := item_list.get_node_or_null("Item_ale") as Control
		if first_row != null:
			_ok(first_row.size == Vector2(580, 64), "item row uses v2 runtime size")
		var rows := item_list.get_children()
		if rows.size() >= 2 and rows[0] is Control and rows[1] is Control:
			var first := rows[0] as Control
			var second := rows[1] as Control
			_ok(second.position.y - first.position.y >= first.size.y + 12, "item rows have breathing room")
	if quantity != null:
		_ok(quantity.position == Vector2(296, 28), "quantity control aligns to manifest crop")
		_ok(quantity.size == Vector2(320, 72), "quantity control uses three-piece runtime size")
	if purchase != null:
		_ok(purchase.position == Vector2(744, 4), "purchase control aligns to manifest crop")
		_ok(purchase.size == Vector2(256, 72), "purchase control uses manifest runtime size")
	if close != null:
		_ok(close.position == Vector2(992, 4), "close control aligns to manifest crop")
		_ok(close.size == Vector2(72, 72), "close control uses manifest runtime size")


func _rect_contains(parent: Control, child: Control) -> bool:
	var parent_rect := Rect2(parent.position, parent.size)
	var child_rect := Rect2(child.position, child.size)
	return parent_rect.encloses(child_rect)


func _test_nearest_filtering(overlay) -> void:
	for path in ["ShopBackdrop", "MainBrushPanel/ListPanel", "MainBrushPanel/DetailPanelArt", "CheckoutBar/StripArt", "CheckoutBar/GoldAreaArt"]:
		var rect := overlay.get_node_or_null(path) as TextureRect
		if rect != null:
			_ok(rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, path + " uses nearest texture filtering")


func _ok_shop_scene_v2_texture(overlay, path: String) -> void:
	var node: Node = overlay.get_node_or_null(path)
	_ok(node is TextureRect, path + " is TextureRect")
	var rect := node as TextureRect
	if rect == null:
		return
	_ok(rect.texture != null, path + " has texture")
	if rect.texture != null:
		_ok(rect.texture.resource_path.contains("/shop_scene_v2/"), path + " uses shop_scene_v2 texture")


func _test_shop_scene_v2_texture_paths(overlay) -> void:
	for path in [
		"ShopBackdrop",
		"MainBrushPanel/ListPanel",
		"MainBrushPanel/DetailPanelArt",
		"CheckoutBar/StripArt",
		"CheckoutBar/GoldAreaArt",
		"CategoryTabs/MaterialsArt",
		"CategoryTabs/RecipesArt",
		"CategoryTabs/AbilitiesArt",
		"ItemList/Item_ale/RowArt",
		"CheckoutBar/QuantityControl/MinusArt",
		"CheckoutBar/QuantityControl/BodyArt",
		"CheckoutBar/QuantityControl/PlusArt",
		"CheckoutBar/PurchaseButton/ButtonArt",
		"CheckoutBar/CloseButton/ButtonArt",
		"DetailPanel/OwnedMark",
		"DetailPanel/DiscountMark",
	]:
		_ok_shop_scene_v2_texture(overlay, path)


func _test_shop_scene_v2_text_safe_layout(overlay) -> void:
	var title := overlay.get_node_or_null("DetailPanel/Title") as Label
	var description := overlay.get_node_or_null("DetailPanel/Description") as Label
	var uses := overlay.get_node_or_null("DetailPanel/Uses") as Label
	var state := overlay.get_node_or_null("DetailPanel/State") as Label
	var gold := overlay.get_node_or_null("CheckoutBar/GoldLabel") as Label
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	var first_row := overlay.get_node_or_null("ItemList/Item_ale") as Control
	var first_row_name := overlay.get_node_or_null("ItemList/Item_ale/Name") as Label
	var first_row_price := overlay.get_node_or_null("ItemList/Item_ale/Price") as Label
	_ok(title != null and Rect2(Vector2(0, 8), Vector2(288, 42)).encloses(Rect2(title.position, title.size)), "detail title stays inside v2 detail safe area")
	_ok(description != null and description.position.x >= 0.0 and description.position.x + description.size.x <= 288.0, "description stays inside v2 detail width")
	_ok(uses != null and uses.position.x >= 0.0 and uses.position.x + uses.size.x <= 288.0, "uses stays inside v2 detail width")
	_ok(state != null and state.position.y >= 260.0 and state.position.y + state.size.y <= 352.0, "state stays inside v2 detail lower area")
	_ok(gold != null and gold.position.x >= 176.0 and gold.position.x + gold.size.x <= 426.0, "gold label stays in checkout safe area")
	_ok(total != null and total.position.x >= 176.0 and total.position.x + total.size.x <= 426.0, "total label stays in checkout safe area")
	_ok(first_row_name != null and first_row != null and first_row_name.position.x >= 0.0 and first_row_name.position.y >= 0.0 and first_row_name.position.x + first_row_name.size.x <= min(first_row.size.x, 390.0) and first_row_name.position.y + first_row_name.size.y <= first_row.size.y, "first item row name stays inside text safe area")
	_ok(first_row_price != null and first_row != null and first_row_price.position.x >= 390.0 and first_row_price.position.y >= 0.0 and first_row_price.position.x + first_row_price.size.x <= min(first_row.size.x, 580.0) and first_row_price.position.y + first_row_price.size.y <= first_row.size.y, "first item row price stays inside price safe area")


func _test_default_selection(overlay) -> void:
	_ok(overlay.get_selected_key() == "ale", "default material selection is ale")
	var title := overlay.get_node_or_null("DetailPanel/Title") as Label
	if title != null:
		_ok(title.text == "麦芽", "detail title shows selected item name")
	var uses := overlay.get_node_or_null("DetailPanel/Uses") as Label
	if uses != null:
		_ok(uses.text.contains("麦芽酒"), "material detail shows recipe usage")


func _test_material_quantity_total(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 1
	overlay.select_item("ale")
	overlay.set_quantity(3)
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	if total != null:
		_ok(total.text.contains("6"), "quantity total uses material unit price")
	_ok(overlay.get_quantity() == 3, "overlay stores selected quantity")


func _test_mira_discount_state(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 4
	overlay.select_item("ale")
	overlay.set_quantity(1)
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	if total != null:
		_ok(total.text.contains("1"), "Mira day material total uses discounted unit price")
	var state := overlay.get_node_or_null("DetailPanel/State") as Label
	if state != null:
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
	var purchase := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") as Button
	if purchase != null:
		_ok(purchase.disabled, "owned recipe disables purchase button")
	var state := overlay.get_node_or_null("DetailPanel/State") as Label
	if state != null:
		_ok(state.text.contains("已拥有"), "owned recipe state is visible")


func _test_close_signal(overlay) -> void:
	var state := {"closed": false}
	overlay.closed.connect(func(): state["closed"] = true)
	overlay.close()
	await get_tree().process_frame
	_ok(bool(state["closed"]), "close emits closed signal")
	_ok(not overlay.visible, "overlay hides after close")
