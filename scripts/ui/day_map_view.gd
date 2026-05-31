class_name DayMapView
extends Node2D

signal gathering_confirmed(assignments: Dictionary)

var _location_list: VBoxContainer
var _stamina_label: Label
var _day_label: Label
var _go_button: Button
var _result_panel: Panel
var _result_label: Label
var _continue_btn: Button
var _document_overlay: DocumentOverlay

var _assignments: Dictionary = {}
var _stamina_left: int = 0
var _max_stamina: int = 5
var _locations: Array = []

var _assign_labels: Dictionary = {}
var _loc_add_btns: Dictionary = {}
var _loc_sub_btns: Dictionary = {}

# Shop
var _is_shop_tab: bool = false
var _gather_tab_btn: Button
var _shop_tab_btn: Button
var _shop_panel: ScrollContainer
var _shop_title: Label
var _gold_label: Label
var _material_list: VBoxContainer
var _recipe_list: VBoxContainer
var _is_mira_shop: bool = false

func _ready() -> void:
	_location_list = $MapArea/LocationList
	_stamina_label = $TopBar/StaminaLabel
	_day_label = $TopBar/DayLabel
	_go_button = $GoButton
	_result_panel = $ResultPanel
	_result_label = $ResultPanel/ResultLabel
	_continue_btn = $ResultPanel/ContinueBtn
	_document_overlay = $DocumentOverlay

	var title_label = $MapArea/TitleLabel
	ThemeColors.style_header(title_label, 26)
	ThemeColors.style_header(_day_label, 22)
	_stamina_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_stamina_label.add_theme_font_size_override("font_size", 20)

	ThemeColors.style_button(_go_button, 24)
	ThemeColors.style_button(_continue_btn, 16)

	_result_panel.add_theme_stylebox_override("panel", ThemeColors.parchment_panel())
	_result_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_result_label.add_theme_font_size_override("font_size", 18)

	_go_button.pressed.connect(_on_go_pressed)
	_continue_btn.pressed.connect(_on_continue)
	$TopBar/DocumentsBtn.pressed.connect(_open_latest_document)

	var exp_btn = $TopBar/ExpTavernBtn
	ThemeColors.style_small_button(exp_btn, 13)
	exp_btn.pressed.connect(_on_exp_tavern_pressed)

	_gold_label = $TopBar/GoldLabel
	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 20)

	# Register with GameManager
	var gm = get_node("/root/GameManager")
	if gm != null:
		gm.register_view(self)

	_build_tab_buttons()
	_build_shop_ui()

	var bg_node = get_node_or_null("Background")
	if bg_node != null:
		# 使用程序化渐变，避免占位图上的 "DAYMAP" 文字
		var grad = GradientTexture2D.new()
		grad.width = 1280; grad.height = 720
		var g = Gradient.new()
		g.colors = [ThemeColors.BACKGROUND_DEEP, ThemeColors.SURFACE_MID]
		g.offsets = [0.0, 1.0]
		grad.gradient = g
		bg_node.texture = grad

func _load_locations() -> void:
	var file = FileAccess.open("res://data/locations.json", FileAccess.READ)
	if file == null:
		push_error("[DayMapView] 无法加载 locations.json")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null:
		push_error("[DayMapView] locations.json 格式无效")
		return
	_locations = []
	for loc_dict in data["locations"]:
		var loc = LocationData.new()
		loc.id = loc_dict["id"]
		loc.name = loc_dict["name"]
		loc.cost = loc_dict["cost"]
		loc.materials = []
		for m in loc_dict["materials"]:
			loc.materials.append(m)
		loc.description = loc_dict["description"]
		_locations.append(loc)
	_max_stamina = data["maxStamina"]
	_stamina_left = _max_stamina

func show_day(day: int, total_days: int) -> void:
	_day_label.text = "第 %d/%d 天 — 白天·行动" % [day, total_days]
	var gm = get_node("/root/GameManager")
	_max_stamina = gm.day_map.max_stamina
	_stamina_left = gm.day_map.stamina
	_assignments.clear()
	_reload_location_ui()
	_update_stamina_display()
	_result_panel.visible = false
	_continue_btn.visible = true
	_go_button.disabled = false
	_go_button.visible = true
	_go_button.text = "进入夜晚"
	_is_shop_tab = false
	if _gather_tab_btn != null:
		_update_tab_appearance()
	if _shop_panel != null:
		_shop_panel.visible = false
	var map_area = $MapArea
	map_area.get_node("TitleLabel").visible = true
	map_area.get_node("LocationList").visible = true
	_update_gold_display()

	# 教程：首次进入采集界面
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null and not tm.daymap_first_shown:
		tm.daymap_first_shown = true
		tm._save_state()
		call_deferred("_trigger_gather_tutorial")

func _build_location_ui() -> void:
	for loc in _locations:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, 52)

		var info = VBoxContainer.new()
		info.custom_minimum_size = Vector2(360, 0)

		var name_label = Label.new()
		name_label.text = String(loc["name"]) + "  [" + str(loc["cost"]) + "体力]"
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 18)
		info.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = String(loc["description"])
		desc_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
		desc_label.add_theme_font_size_override("font_size", 13)
		info.add_child(desc_label)

		row.add_child(info)

		var visit_btn = Button.new()
		visit_btn.text = "访问"
		visit_btn.custom_minimum_size = Vector2(80, 36)
		ThemeColors.style_button(visit_btn, 16)
		var loc_id: String = loc["id"]
		visit_btn.pressed.connect(_visit_location.bind(loc_id))
		row.add_child(visit_btn)
		_loc_add_btns[loc_id] = visit_btn

		_location_list.add_child(row)


func _reload_location_ui() -> void:
	for child in _location_list.get_children():
		child.queue_free()
	_loc_add_btns.clear()
	_locations = get_node("/root/GameManager").day_map.get_locations()
	_build_location_ui()


func _visit_location(location_id: String) -> void:
	var gm = get_node("/root/GameManager")
	var result: Dictionary = gm.visit_day_location(location_id)
	_result_label.text = String(result.get("message", "访问完成。"))
	_result_panel.visible = true
	_continue_btn.text = "知道了"
	_stamina_left = gm.day_map.stamina
	_update_stamina_display()
	_reload_location_ui()

func _add_assignment(loc_id: String, cost: int, count_label: Label) -> void:
	if _stamina_left < cost:
		return
	_stamina_left -= cost
	var cur: int = _assignments.get(loc_id, 0)
	_assignments[loc_id] = cur + 1
	count_label.text = str(_assignments[loc_id])
	_update_stamina_display()
	if _loc_sub_btns.has(loc_id):
		_loc_sub_btns[loc_id].disabled = false
	if _stamina_left < 1:
		for btn in _loc_add_btns.values():
			btn.disabled = true

func _remove_assignment(loc_id: String, cost: int, count_label: Label) -> void:
	var cur: int = _assignments.get(loc_id, 0)
	if cur < 1:
		return
	_stamina_left += cost
	_assignments[loc_id] = cur - 1
	if _assignments[loc_id] <= 0:
		_assignments.erase(loc_id)
	count_label.text = str(_assignments.get(loc_id, 0))
	_update_stamina_display()
	for btn in _loc_add_btns.values():
		btn.disabled = false
	if _loc_sub_btns.has(loc_id):
		_loc_sub_btns[loc_id].disabled = not _assignments.has(loc_id)

func _update_stamina_display() -> void:
	_stamina_label.text = "体力：" + str(_stamina_left) + "/" + str(_max_stamina)

func _on_go_pressed() -> void:
	_go_button.disabled = true
	get_node("/root/GameManager").enter_night_from_day_map()

func _on_continue() -> void:
	_result_panel.visible = false


func _open_latest_document() -> void:
	var gm = get_node("/root/GameManager")
	for document_id in gm.documents.get_owned_documents():
		if document_id != "ledger" and not gm.documents.is_read(document_id):
			gm.request_open_document(document_id)
			return
	gm.request_open_document("ledger")


func open_document(document: Dictionary) -> void:
	_document_overlay.open_document(document)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _document_overlay.visible:
		_document_overlay.close()
		get_viewport().set_input_as_handled()

func _update_gold_display() -> void:
	var gm = get_node("/root/GameManager")
	if gm != null:
		_gold_label.text = "金币：" + str(gm.economy.gold)

func _build_tab_buttons() -> void:
	var map_area = $MapArea
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.custom_minimum_size = Vector2(0, 40)

	_gather_tab_btn = Button.new()
	_gather_tab_btn.text = "采集"
	_gather_tab_btn.custom_minimum_size = Vector2(100, 36)
	ThemeColors.style_button(_gather_tab_btn, 16)
	_gather_tab_btn.pressed.connect(_switch_tab.bind(false))
	tab_row.add_child(_gather_tab_btn)

	_shop_tab_btn = Button.new()
	_shop_tab_btn.text = "商店"
	_shop_tab_btn.custom_minimum_size = Vector2(100, 36)
	ThemeColors.style_button(_shop_tab_btn, 16)
	_shop_tab_btn.pressed.connect(_switch_tab.bind(true))
	tab_row.add_child(_shop_tab_btn)

	map_area.add_child(tab_row)
	map_area.move_child(tab_row, 0)

	var title_label = map_area.get_node("TitleLabel")
	title_label.offset_top = 45
	title_label.offset_bottom = 80
	var location_list = map_area.get_node("LocationList")
	location_list.offset_top = 95
	location_list.offset_bottom = 420

	_update_tab_appearance()

func _switch_tab(shop: bool) -> void:
	_is_shop_tab = shop
	_update_tab_appearance()

	var map_area = $MapArea
	map_area.get_node("TitleLabel").visible = not shop
	map_area.get_node("LocationList").visible = not shop
	_shop_panel.visible = shop

	if shop:
		_refresh_shop_ui()

		# 教程：首次访问商店
		var tm = get_node_or_null("/root/TutorialManager")
		if tm != null and not tm.shop_first_visited:
			tm.shop_first_visited = true
			tm._save_state()
			call_deferred("_trigger_shop_tutorial")

	_go_button.visible = not shop

func _update_tab_appearance() -> void:
	if _gather_tab_btn == null or _shop_tab_btn == null:
		return
	_gather_tab_btn.modulate = Color.DIM_GRAY if _is_shop_tab else Color.WHITE
	_shop_tab_btn.modulate = Color.WHITE if _is_shop_tab else Color.DIM_GRAY

func _build_shop_ui() -> void:
	_shop_panel = ScrollContainer.new()
	_shop_panel.anchor_left = 0.0; _shop_panel.anchor_right = 1.0
	_shop_panel.offset_left = 0; _shop_panel.offset_top = 95
	_shop_panel.offset_right = 1000; _shop_panel.offset_bottom = 420
	_shop_panel.visible = false
	$MapArea.add_child(_shop_panel)

	var shop_content = VBoxContainer.new()
	shop_content.add_theme_constant_override("separation", 8)
	_shop_panel.add_child(shop_content)

	_shop_title = Label.new()
	_shop_title.custom_minimum_size = Vector2(0, 36)
	ThemeColors.style_header(_shop_title, 22)
	shop_content.add_child(_shop_title)

	var mat_title = Label.new()
	mat_title.text = "—— 购买材料 ——"
	mat_title.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	mat_title.add_theme_font_size_override("font_size", 16)
	mat_title.custom_minimum_size = Vector2(0, 30)
	shop_content.add_child(mat_title)

	_material_list = VBoxContainer.new()
	_material_list.add_theme_constant_override("separation", 4)
	shop_content.add_child(_material_list)

	var recipe_title = Label.new()
	recipe_title.text = "—— 解锁配方 ——"
	recipe_title.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	recipe_title.add_theme_font_size_override("font_size", 16)
	recipe_title.custom_minimum_size = Vector2(0, 30)
	shop_content.add_child(recipe_title)

	_recipe_list = VBoxContainer.new()
	_recipe_list.add_theme_constant_override("separation", 4)
	shop_content.add_child(_recipe_list)

func _refresh_shop_ui() -> void:
	var gm = get_node("/root/GameManager")
	if gm == null:
		return

	_is_mira_shop = gm.is_mira_in_shop_today()
	_shop_title.text = "米拉的旅行商店" if _is_mira_shop else "商店"

	_build_material_rows(gm)
	_build_recipe_rows(gm)
	_update_gold_display()

func _build_material_rows(gm) -> void:
	for child in _material_list.get_children():
		child.queue_free()

	var materials = [
		["ale", "麦芽"], ["grape", "葡萄"], ["flour", "面粉"],
		["meat_raw", "生肉"], ["herb", "草药"]
	]

	for pair in materials:
		var key: String = pair[0]
		var mat_name: String = pair[1]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 40)

		var name_label = Label.new()
		name_label.text = mat_name
		name_label.custom_minimum_size = Vector2(70, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 16)
		row.add_child(name_label)

		var discount: float = 0.8 if _is_mira_shop else 1.0
		var price: int = gm.shop.get_material_price(key, discount)
		var price_label = Label.new()
		if _is_mira_shop:
			price_label.text = str(gm.shop.get_material_price(key)) + "\u2192" + str(price) + "\u91d1"
		else:
			price_label.text = str(price) + "金"
		price_label.custom_minimum_size = Vector2(70, 0)
		price_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
		price_label.add_theme_font_size_override("font_size", 14)
		row.add_child(price_label)

		var sub_btn = Button.new()
		sub_btn.text = "-"
		sub_btn.custom_minimum_size = Vector2(36, 30)
		ThemeColors.style_button(sub_btn, 14)
		var qty_label = Label.new()
		qty_label.text = "0"
		qty_label.custom_minimum_size = Vector2(30, 0)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
		qty_label.add_theme_font_size_override("font_size", 18)
		var add_btn = Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(36, 30)
		ThemeColors.style_button(add_btn, 14)

		sub_btn.pressed.connect(func():
			var cur = int(qty_label.text)
			if cur > 0:
				cur -= 1
				qty_label.text = str(cur)
		)
		add_btn.pressed.connect(func():
			var cur = int(qty_label.text)
			cur += 1
			qty_label.text = str(cur)
		)

		var buy_btn = Button.new()
		buy_btn.text = "购买"
		buy_btn.custom_minimum_size = Vector2(56, 30)
		ThemeColors.style_button(buy_btn, 14)
		buy_btn.pressed.connect(func():
			var qty = int(qty_label.text)
			if qty < 1:
				return
			if gm.buy_material(key, qty, 0.8 if _is_mira_shop else 1.0):
				qty_label.text = "0"
				_update_gold_display()
		)

		row.add_child(sub_btn)
		row.add_child(qty_label)
		row.add_child(add_btn)
		row.add_child(buy_btn)
		_material_list.add_child(row)

func _build_recipe_rows(gm) -> void:
	for child in _recipe_list.get_children():
		child.queue_free()

	var unlocks = [
		["herbal_ale", "草药麦酒"], ["spiced_wine", "香料红酒"],
		["meat_sand", "肉夹面包"], ["meat_stew", "肉汤"]
	]

	for pair in unlocks:
		var key: String = pair[0]
		var mat_name: String = pair[1]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 40)

		var name_label = Label.new()
		name_label.text = mat_name
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 16)
		row.add_child(name_label)

		if gm.craft.is_recipe_unlocked(key):
			var owned = Label.new()
			owned.text = "已拥有"
			owned.custom_minimum_size = Vector2(80, 0)
			owned.add_theme_color_override("font_color", ThemeColors.TEXT_DIM)
			owned.add_theme_font_size_override("font_size", 14)
			row.add_child(owned)
		else:
			var price: int = gm.shop.get_recipe_unlock_price(key)
			if price < 0:
				_recipe_list.add_child(row)
				continue
			var price_label = Label.new()
			price_label.text = str(price) + "金"
			price_label.custom_minimum_size = Vector2(60, 0)
			price_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
			price_label.add_theme_font_size_override("font_size", 14)
			row.add_child(price_label)

			var unlock_btn = Button.new()
			unlock_btn.text = "解锁"
			unlock_btn.custom_minimum_size = Vector2(56, 30)
			ThemeColors.style_button(unlock_btn, 14)
			unlock_btn.pressed.connect(func():
				if gm.buy_recipe_unlock(key):
					_update_gold_display()
					_build_recipe_rows(gm)
			)
			row.add_child(unlock_btn)

		_recipe_list.add_child(row)


# 教程触发方法
func _trigger_gather_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	var rects = {
		"MapArea": [140, 80, 1000, 420],
		"TopBar": [30, 5, 320, 55],
		"GoButton": [540, 520, 200, 50],
	}
	tm.start_tutorial("gather", rects)


func _trigger_shop_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	var rects = {
		"MapArea": [140, 80, 1000, 420],
	}
	tm.start_tutorial("shop", rects)


func _on_exp_tavern_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ExperimentalTavern.tscn")
