class_name DayMapView
extends Node2D

signal gathering_confirmed(assignments: Dictionary)

const MINE_SCENE := preload("res://scenes/ui/MineInvestigation.tscn")
const POINT_MARKER := preload("res://scenes/ui/MapPointMarker.tscn")

const HOME_ID := "__home__"
const HOME_POS := Vector2(1000, 1080)
const INTRO_HANDOFF_ZOOM := 1.32
const INTRO_HANDOFF_DURATION := 1.8

var _camera: DayMapCamera
var _points_root: Node2D
var _detail_panel: Panel
var _markers: Dictionary = {}      # location_id -> MapPointMarker
var _home_marker: MapPointMarker
var _selected_id: String = ""
var _revealing: bool = false

var _stamina_label: Label
var _day_label: Label
var _result_panel: Panel
var _result_label: Label
var _continue_btn: Button
var _document_overlay: DocumentOverlay
var _inventory_overlay: InventoryOverlay

var _stamina_left: int = 0
var _max_stamina: int = 5

var _mine_scene: Node = null
var _hidden_for_mine: Array = []
var _overlay_layer: CanvasLayer = null

# Shop
var _is_shop_tab: bool = false
var _gather_tab_btn: Button
var _shop_tab_btn: Button
var _shop_panel: ScrollContainer
var _shop_title: Label
var _gold_label: Label
var _material_list: VBoxContainer
var _recipe_list: VBoxContainer
var _ability_list: VBoxContainer
var _is_mira_shop: bool = false

func _ready() -> void:
	_stamina_label = $UILayer/TopBar/StaminaLabel
	_day_label = $UILayer/TopBar/DayLabel
	_result_panel = $UILayer/ResultPanel
	_result_label = $UILayer/ResultPanel/ResultLabel
	_continue_btn = $UILayer/ResultPanel/ContinueBtn
	_document_overlay = $UILayer/DocumentOverlay
	_inventory_overlay = $UILayer/InventoryOverlay
	_inventory_overlay.configure(get_node("/root/GameManager"))
	_inventory_overlay.item_dropped.connect(_on_inventory_item_dropped)

	_camera = $MapWorld/Camera2D
	_points_root = $MapWorld/Points
	_detail_panel = $UILayer/DetailPanel

	_stamina_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_stamina_label.add_theme_font_size_override("font_size", 20)
	ThemeColors.style_header(_day_label, 22)
	ThemeColors.style_button(_continue_btn, 16)
	_result_panel.add_theme_stylebox_override("panel", ThemeColors.parchment_panel())
	_result_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_result_label.add_theme_font_size_override("font_size", 18)

	_continue_btn.pressed.connect(_on_continue)
	$UILayer/TopBar/DocumentsBtn.pressed.connect(_open_latest_document)

	var exp_btn = $UILayer/TopBar/ExpTavernBtn
	ThemeColors.style_small_button(exp_btn, 13)
	exp_btn.pressed.connect(_on_exp_tavern_pressed)

	_gold_label = $UILayer/TopBar/GoldLabel
	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 20)

	_setup_detail_panel()

	var gm = get_node("/root/GameManager")
	if gm != null:
		gm.register_view(self)

	_build_tab_buttons()
	_build_shop_ui()
	_setup_background()


func _setup_background() -> void:
	var bg: Sprite2D = get_node_or_null("MapWorld/Background") as Sprite2D
	if bg == null:
		return
	var grad := GradientTexture2D.new()
	grad.width = 2000; grad.height = 1400
	var g := Gradient.new()
	g.colors = [ThemeColors.BACKGROUND_DEEP, ThemeColors.SURFACE_MID]
	g.offsets = [0.0, 1.0]
	grad.gradient = g
	bg.texture = grad


func _setup_detail_panel() -> void:
	_detail_panel.add_theme_stylebox_override("panel", ThemeColors.parchment_panel())
	var name_label: Label = _detail_panel.get_node("Name")
	ThemeColors.style_header(name_label, 22)
	for n in ["Desc", "Cost", "Yield"]:
		var lbl: Label = _detail_panel.get_node(n)
		lbl.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		lbl.add_theme_font_size_override("font_size", 16)
	var go_here: Button = _detail_panel.get_node("GoHereBtn")
	ThemeColors.style_button(go_here, 18)
	go_here.pressed.connect(_on_go_here_pressed)
	_detail_panel.visible = false


func show_day(day: int, total_days: int) -> void:
	_day_label.text = "第 %d/%d 天 — 白天·行动" % [day, total_days]
	var gm = get_node("/root/GameManager")
	_max_stamina = gm.day_map.max_stamina
	_stamina_left = gm.day_map.stamina
	_update_stamina_display()
	_result_panel.visible = false
	_continue_btn.visible = true
	_is_shop_tab = false
	if _gather_tab_btn != null:
		_update_tab_appearance()
	if _shop_panel != null:
		_shop_panel.visible = false
	_camera.set_active(true)
	_detail_panel.visible = false
	_selected_id = ""
	_update_gold_display()
	_ensure_home_marker()
	if gm.consume_intro_handoff():
		_play_intro_handoff()
	else:
		_camera.position = HOME_POS
		_refresh_map()
		_maybe_trigger_gather_tutorial()


func _play_intro_handoff() -> void:
	# match-cut：相机先贴紧酒馆(紧 zoom)，再拉开到正常视距，然后才 reveal 地点
	_camera.position = HOME_POS
	_camera.zoom = Vector2(INTRO_HANDOFF_ZOOM, INTRO_HANDOFF_ZOOM)
	await _camera.fly_to(HOME_POS, 1.0, INTRO_HANDOFF_DURATION).finished
	if not is_instance_valid(self):
		return
	_refresh_map()
	# 教程在拉镜+亮相之后才触发，避免盖在空地图上（与 else 分支同序）
	_maybe_trigger_gather_tutorial()


func _maybe_trigger_gather_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null and not tm.daymap_first_shown:
		tm.daymap_first_shown = true
		tm._save_state()
		call_deferred("_trigger_gather_tutorial")


func _refresh_map() -> void:
	if _revealing:
		return
	var gm = get_node("/root/GameManager")
	var locations: Array = gm.day_map.get_locations()
	var current_ids := {}
	for loc in locations:
		current_ids[String(loc.get("id", ""))] = loc

	for id in _markers.keys():
		if not current_ids.has(id):
			_fade_out_marker(_markers[id])
			_markers.erase(id)
			if _selected_id == id:
				_selected_id = ""
				_detail_panel.visible = false

	for id in current_ids:
		if not _markers.has(id) and gm.day_map.is_revealed(id):
			_create_marker(current_ids[id], false)

	var new_locs: Array = gm.day_map.get_new_locations()
	if not new_locs.is_empty():
		_play_reveal_sequence(new_locs)


func _create_marker(loc: Dictionary, hidden: bool) -> MapPointMarker:
	var marker: MapPointMarker = POINT_MARKER.instantiate()
	_points_root.add_child(marker)
	marker.setup(loc)
	marker.clicked.connect(_on_marker_clicked)
	marker.modulate.a = 0.0 if hidden else 1.0
	_markers[String(loc.get("id", ""))] = marker
	return marker


func _ensure_home_marker() -> void:
	# 酒馆/家：常驻专用标记，不进 _markers、不参与采集 diff 与亮相
	if _home_marker != null and is_instance_valid(_home_marker):
		return
	var marker: MapPointMarker = POINT_MARKER.instantiate()
	_points_root.add_child(marker)
	marker.setup({"id": HOME_ID, "name": "你的酒馆", "pos": [HOME_POS.x, HOME_POS.y]})
	marker.set_home(true)
	marker.clicked.connect(_on_marker_clicked)
	_home_marker = marker


func _fade_out_marker(marker: MapPointMarker) -> void:
	if marker == null or not is_instance_valid(marker):
		return
	var tw := create_tween()
	tw.tween_property(marker, "modulate:a", 0.0, 0.4)
	tw.tween_callback(marker.queue_free)


func _play_reveal_sequence(new_locs: Array) -> void:
	_revealing = true
	var gm = get_node("/root/GameManager")
	if new_locs.size() > 3:
		await _camera.fly_to(Vector2(1000, 700), _camera.MIN_ZOOM).finished
		if not is_instance_valid(self):
			return  # 亮相中切换了场景，协程被遗弃
		for loc in new_locs:
			var m := _create_marker(loc, true)
			_fade_in_marker(m)
			gm.day_map.mark_revealed(String(loc.get("id", "")))
	else:
		for loc in new_locs:
			var pos_arr: Array = loc.get("pos", [1000, 700])
			var wp := Vector2(float(pos_arr[0]), float(pos_arr[1]))
			await _camera.fly_to(wp, 1.0).finished
			if not is_instance_valid(self):
				return
			var m := _create_marker(loc, true)
			_fade_in_marker(m)
			gm.day_map.mark_revealed(String(loc.get("id", "")))
			await get_tree().create_timer(0.3).timeout
			if not is_instance_valid(self):
				return
	_revealing = false
	# 亮相期间若有访问/解锁被 _revealing 拦下，这里补刷一次
	_refresh_map()


func _fade_in_marker(marker: MapPointMarker) -> void:
	var tw := create_tween()
	tw.tween_property(marker, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(marker, "scale", Vector2(1.25, 1.25), 0.18)
	tw.tween_property(marker, "scale", Vector2(1, 1), 0.18)


func _on_marker_clicked(location_id: String) -> void:
	_select_marker(location_id)


func _select_marker(location_id: String) -> void:
	_set_marker_selected(_selected_id, false)
	_selected_id = location_id
	_set_marker_selected(location_id, true)
	_show_detail(location_id)


func _set_marker_selected(id: String, value: bool) -> void:
	if id == HOME_ID:
		if _home_marker != null and is_instance_valid(_home_marker):
			_home_marker.set_selected(value)
	elif _markers.has(id):
		_markers[id].set_selected(value)


func _show_detail(location_id: String) -> void:
	var go_here: Button = _detail_panel.get_node("GoHereBtn")
	if location_id == HOME_ID:
		_detail_panel.get_node("Name").text = "你的酒馆"
		_detail_panel.get_node("Desc").text = "今晚开门营业，结束今天的白天。"
		_detail_panel.get_node("Cost").text = ("还有 %d 点体力未用" % _stamina_left) if _stamina_left > 0 else ""
		_detail_panel.get_node("Yield").text = ""
		go_here.text = "开门营业"
		_detail_panel.visible = true
		return
	var gm = get_node("/root/GameManager")
	var loc: Dictionary = {}
	for l in gm.day_map.get_locations():
		if String(l.get("id", "")) == location_id:
			loc = l
			break
	if loc.is_empty():
		_detail_panel.visible = false
		return
	_detail_panel.get_node("Name").text = String(loc.get("name", ""))
	_detail_panel.get_node("Desc").text = String(loc.get("description", ""))
	_detail_panel.get_node("Cost").text = "体力消耗：%d" % int(loc.get("cost", 1))
	_detail_panel.get_node("Yield").text = _yield_text(loc)
	go_here.text = "前往"
	_detail_panel.visible = true


func _yield_text(loc: Dictionary) -> String:
	var day := int(get_node("/root/GameManager").day_map.current_day)
	var day_rewards: Dictionary = loc.get("dayRewards", {})
	var items: Array = []
	if day_rewards.has(str(day)):
		items = day_rewards[str(day)]
	elif not loc.get("rewards", []).is_empty():
		items = loc.get("rewards", [])
	elif not loc.get("materials", []).is_empty():
		items = loc.get("materials", [])
	if items.is_empty():
		return "产出：—"
	return "产出：" + ", ".join(PackedStringArray(items))


func _on_go_here_pressed() -> void:
	if _selected_id == "":
		return
	if _selected_id == HOME_ID:
		if _revealing:
			return  # 亮相动画中防误触结束白天
		get_node("/root/GameManager").enter_night_from_day_map()
		return
	_visit_location(_selected_id)


func _visit_location(location_id: String) -> void:
	var gm = get_node("/root/GameManager")
	var result: Dictionary = gm.visit_day_location(location_id)
	if location_id == "abandoned_mine" and bool(result.get("success", false)):
		_stamina_left = gm.day_map.stamina
		_update_stamina_display()
		_enter_mine_investigation()
		return
	_result_label.text = String(result.get("message", "访问完成。"))
	_result_panel.visible = true
	_continue_btn.text = "知道了"
	_stamina_left = gm.day_map.stamina
	_update_stamina_display()
	_detail_panel.visible = false
	_selected_id = ""
	_refresh_map()


func _enter_mine_investigation() -> void:
	if _mine_scene != null:
		return
	_mine_scene = MINE_SCENE.instantiate()
	add_child(_mine_scene)
	# DocumentOverlay 提到高层 CanvasLayer，确保挖出委托书时压在矿道场景(含其 UI CanvasLayer)之上
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)
	_document_overlay.reparent(_overlay_layer, false)
	# 隐藏 DayMap 主体，避免输入穿透到下面的按钮
	_hidden_for_mine = [$MapWorld, $UILayer/TopBar, $UILayer/ResultPanel, _detail_panel]
	for n in _hidden_for_mine:
		if n != null:
			n.visible = false
	_mine_scene.finished.connect(_on_mine_finished)


func _on_mine_finished() -> void:
	if _mine_scene != null:
		_mine_scene.queue_free()
		_mine_scene = null
	if _overlay_layer != null:
		_document_overlay.reparent(self, false)
		_overlay_layer.queue_free()
		_overlay_layer = null
	for n in _hidden_for_mine:
		if n != null and is_instance_valid(n):
			n.visible = true
	_hidden_for_mine.clear()
	_camera.set_active(true)
	_refresh_map()


func _update_stamina_display() -> void:
	_stamina_label.text = "体力：" + str(_stamina_left) + "/" + str(_max_stamina)

func _on_continue() -> void:
	_result_panel.visible = false


func _open_latest_document() -> void:
	# 简化：点击按钮直接打开账本（证据文档从背包双击阅读）
	get_node("/root/GameManager").request_open_document("ledger")


func open_document(document: Dictionary) -> void:
	_document_overlay.open_document(document)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _document_overlay.visible:
			_document_overlay.close()
			get_viewport().set_input_as_handled()
		elif _inventory_overlay.visible:
			_inventory_overlay.close()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("inventory_toggle"):
		if _inventory_overlay.visible:
			_inventory_overlay.close()
		else:
			_inventory_overlay.open()
		get_viewport().set_input_as_handled()


func _on_inventory_item_dropped(item_key: String, _global_position: Vector2) -> void:
	# DayMap 场景无法拖出物品使用，意外拖出时放回背包
	get_node("/root/GameManager").add_to_inventory(item_key, 1)

func _update_gold_display() -> void:
	var gm = get_node("/root/GameManager")
	if gm != null:
		_gold_label.text = "金币：" + str(gm.economy.gold)

func _build_tab_buttons() -> void:
	# 居中分段标签页，挂在 UILayer 顶部（不放进 MapArea，避免随商店容器移动）
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	tab_row.position = Vector2(530, 66)

	_gather_tab_btn = Button.new()
	_gather_tab_btn.text = "采集"
	_gather_tab_btn.custom_minimum_size = Vector2(110, 38)
	ThemeColors.style_button(_gather_tab_btn, 16)
	_gather_tab_btn.pressed.connect(_switch_tab.bind(false))
	tab_row.add_child(_gather_tab_btn)

	_shop_tab_btn = Button.new()
	_shop_tab_btn.text = "商店"
	_shop_tab_btn.custom_minimum_size = Vector2(110, 38)
	ThemeColors.style_button(_shop_tab_btn, 16)
	_shop_tab_btn.pressed.connect(_switch_tab.bind(true))
	tab_row.add_child(_shop_tab_btn)

	$UILayer.add_child(tab_row)

	_update_tab_appearance()

func _switch_tab(shop: bool) -> void:
	_is_shop_tab = shop
	_update_tab_appearance()
	$MapWorld.visible = not shop
	_detail_panel.visible = false
	_camera.set_active(not shop)
	_shop_panel.visible = shop
	if shop:
		_refresh_shop_ui()
		var tm = get_node_or_null("/root/TutorialManager")
		if tm != null and not tm.shop_first_visited:
			tm.shop_first_visited = true
			tm._save_state()
			call_deferred("_trigger_shop_tutorial")

func _update_tab_appearance() -> void:
	if _gather_tab_btn == null or _shop_tab_btn == null:
		return
	_gather_tab_btn.modulate = Color.DIM_GRAY if _is_shop_tab else Color.WHITE
	_shop_tab_btn.modulate = Color.WHITE if _is_shop_tab else Color.DIM_GRAY

func _build_shop_ui() -> void:
	_shop_panel = ScrollContainer.new()
	_shop_panel.anchor_left = 0.0; _shop_panel.anchor_right = 1.0
	_shop_panel.offset_left = 0; _shop_panel.offset_top = 95
	_shop_panel.offset_right = 0; _shop_panel.offset_bottom = 420
	_shop_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_panel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_shop_panel.visible = false
	$UILayer/MapArea.add_child(_shop_panel)

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

	var ability_title = Label.new()
	ability_title.text = "—— 技法 ——"
	ability_title.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	ability_title.add_theme_font_size_override("font_size", 16)
	ability_title.custom_minimum_size = Vector2(0, 30)
	shop_content.add_child(ability_title)

	_ability_list = VBoxContainer.new()
	_ability_list.add_theme_constant_override("separation", 4)
	shop_content.add_child(_ability_list)

func _refresh_shop_ui() -> void:
	var gm = get_node("/root/GameManager")
	if gm == null:
		return

	_is_mira_shop = gm.is_mira_in_shop_today()
	_shop_title.text = "米拉的旅行商店" if _is_mira_shop else "商店"

	_build_material_rows(gm)
	_build_recipe_rows(gm)
	_build_ability_rows(gm)
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
			price_label.text = str(gm.shop.get_material_price(key)) + "→" + str(price) + "金"
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

func _build_ability_rows(gm) -> void:
	for child in _ability_list.get_children():
		child.queue_free()

	for key in gm.shop.get_ability_keys():
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 40)

		var name_label = Label.new()
		name_label.text = gm.shop.get_ability_name(key)
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 16)
		row.add_child(name_label)

		var owned: bool = gm.is_ability_owned(key)
		if owned:
			var owned_label = Label.new()
			owned_label.text = "已掌握"
			owned_label.custom_minimum_size = Vector2(80, 0)
			owned_label.add_theme_color_override("font_color", ThemeColors.TEXT_DIM)
			owned_label.add_theme_font_size_override("font_size", 14)
			row.add_child(owned_label)
		else:
			var price_label = Label.new()
			price_label.text = str(gm.shop.get_ability_price(key)) + "金"
			price_label.custom_minimum_size = Vector2(60, 0)
			price_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
			price_label.add_theme_font_size_override("font_size", 14)
			row.add_child(price_label)

			var buy_btn = Button.new()
			buy_btn.text = "购买"
			buy_btn.custom_minimum_size = Vector2(56, 30)
			ThemeColors.style_button(buy_btn, 14)
			buy_btn.pressed.connect(func():
				if gm.buy_ability(key):
					_update_gold_display()
					_build_ability_rows(gm)
			)
			row.add_child(buy_btn)

		_ability_list.add_child(row)


# 教程触发方法
func _trigger_gather_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	var rects = {
		"MapArea": [140, 80, 1000, 420],
		"TopBar": [30, 5, 320, 55],
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
