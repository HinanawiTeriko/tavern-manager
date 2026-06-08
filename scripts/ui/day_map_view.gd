class_name DayMapView
extends Node2D

signal gathering_confirmed(assignments: Dictionary)

const MINE_SCENE := preload("res://scenes/ui/MineInvestigation.tscn")
const POINT_MARKER := preload("res://scenes/ui/MapPointMarker.tscn")
const DAYMAP_BACKGROUND := preload("res://assets/textures/daymap/daymap_bg.png")

const HOME_ID := "__home__"
const HOME_POS := Vector2(345, 500)
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
var _gathering_toast: GatheringToast

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
var _status_label: Label
var _option_btn: Button
var _ledger_btn: Button
var _overlay_menu: Panel
var _recipe_panel: Control
var _backpack_panel: Control
var _encyclopedia_panel: Control
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

	# 右上角按钮
	_option_btn = $UILayer/TopBar/RightArea/OptionBtn
	_ledger_btn = $UILayer/TopBar/RightArea/LedgerBtn
	_status_label = $UILayer/TopBar/RightArea/StatusPanel/StatusLabel

	var right_area = $UILayer/TopBar/RightArea
	right_area.add_theme_constant_override("separation", 8)

	var status_panel = $UILayer/TopBar/RightArea/StatusPanel
	ThemeColors.style_brush_panel(status_panel)

	ThemeColors.style_button(_option_btn, 14)
	ThemeColors.style_button(_ledger_btn, 14)
	_status_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_status_label.add_theme_font_size_override("font_size", 13)

	_option_btn.pressed.connect(_toggle_menu)
	_ledger_btn.pressed.connect(open_ledger)

	_build_overlay_menu()

	_setup_detail_panel()

	var gm = get_node("/root/GameManager")
	if gm != null:
		gm.register_view(self)
		gm.inventory_changed.connect(_on_inventory_changed)

	# 采集提示 Toast
	_gathering_toast = GatheringToast.new()
	_gathering_toast.visible = false
	_gathering_toast.anchor_left = 0.5
	_gathering_toast.anchor_right = 0.5
	_gathering_toast.anchor_top = 0.0
	_gathering_toast.offset_left = -210.0
	_gathering_toast.offset_right = 210.0
	_gathering_toast.offset_top = 10.0
	_gathering_toast.offset_bottom = 54.0
	$UILayer.add_child(_gathering_toast)

	_build_tab_buttons()
	_build_shop_ui()
	_setup_background()


func _setup_background() -> void:
	var gm = get_node("/root/GameManager")
	var map_world := $MapWorld
	var regions: Array = gm.day_map.get_regions()
	# 复用 .tscn 里的 Background 节点作第一块，其余程序生成
	var existing: Sprite2D = get_node_or_null("MapWorld/Background") as Sprite2D
	for i in regions.size():
		var r: Dictionary = regions[i]
		var rid := String(r.get("id", ""))
		var o = r.get("origin", [0, 0])
		var s = r.get("size", [1280, 720])
		var center := Vector2(float(o[0]) + float(s[0]) * 0.5, float(o[1]) + float(s[1]) * 0.5)
		var tile: Sprite2D
		if i == 0 and existing != null:
			tile = existing
		else:
			tile = Sprite2D.new()
			tile.z_index = -10
			map_world.add_child(tile)
		tile.name = "RegionTile_" + rid
		tile.centered = true
		tile.position = center
		tile.texture = _region_texture(rid, Vector2(float(s[0]), float(s[1])))
	# 注入相机边界（区域并集）→ 动态最小缩放 + 钳制
	var b: Dictionary = gm.day_map.get_map_bounds()
	_camera.set_bounds(b["min"], b["max"])


## 区域背景纹理：优先 runtime PNG；缺席（Codex 美术未到）回退到按 id tint 的纯色占位。
func _region_texture(rid: String, size: Vector2) -> Texture2D:
	var path := "res://assets/textures/daymap/regions/%s.png" % rid
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex != null:
			return tex
	var tints := {
		"market": Color(0.32, 0.27, 0.20),
		"wilds": Color(0.20, 0.30, 0.22),
		"north_road": Color(0.26, 0.24, 0.28),
		"fog": Color(0.16, 0.17, 0.19),
	}
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	img.fill(tints.get(rid, Color(0.2, 0.2, 0.2)))
	return ImageTexture.create_from_image(img)


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
	_update_status_bar()
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
		return
	# 已亮相地点的贴文更新 → 重新拉镜头高亮 + 刷新描述（地点持久、内容演变）
	_play_update_sequence(gm.day_map.get_updated_locations())


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
		await _camera.fly_to(Vector2(1280, 720), _camera.min_zoom).finished
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


## 已亮相地点的贴文更新：相机飞过去、marker 脉冲一次、刷新描述，并标记已宣告。
func _play_update_sequence(updated: Array) -> void:
	if updated.is_empty():
		return
	_revealing = true
	var gm = get_node("/root/GameManager")
	for loc in updated:
		var id := String(loc.get("id", ""))
		var pos_arr: Array = loc.get("pos", [1280, 720])
		var wp := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		await _camera.fly_to(wp, 1.0).finished
		if not is_instance_valid(self):
			return
		var marker = _markers.get(id, null)
		if marker != null and is_instance_valid(marker):
			_fade_in_marker(marker)
		gm.day_map.mark_posting_announced(id)
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(self):
			return
	_revealing = false
	# 若当前选中的是被更新的地点，刷新其详情描述
	if _selected_id != "":
		_show_detail(_selected_id)


func _fade_in_marker(marker: MapPointMarker) -> void:
	if marker.has_method("play_reveal"):
		marker.play_reveal()
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
	var message := String(result.get("message", "访问完成。"))
	var reward_counts: Dictionary = result.get("reward_counts", {})
	if bool(result.get("success", false)):
		_gathering_toast.show_rewards(reward_counts, message)
	else:
		_gathering_toast.show_rewards({}, message)
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
	# 让出地图相机：矿道场景按 world==screen 的恒等坐标编写（物品在世界坐标拾取/命中），
	# 而 DayMapCamera 此刻是缩放/平移过的当前相机。禁用它使视口回到恒等变换，否则
	# 物品渲染错位、event.global_position 命中测试全落空（表现为"什么都点不到"）。
	_camera.set_active(false)
	_camera.enabled = false
	# DocumentOverlay 提到高层 CanvasLayer，确保挖出委托书时压在矿道场景(含其 UI CanvasLayer)之上
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)
	_document_overlay.reparent(_overlay_layer, false)
	# 整层隐藏 DayMap UI（含运行时建的采集/商店标签与商店面板），避免与矿道 UI 并存、截获输入。
	# DocumentOverlay 已先移出 $UILayer 到 _overlay_layer，故不受此隐藏影响。
	_hidden_for_mine = [$MapWorld, $UILayer]
	for n in _hidden_for_mine:
		if n != null:
			n.visible = false
	_mine_scene.finished.connect(_on_mine_finished)


func _on_mine_finished() -> void:
	if _mine_scene != null:
		_mine_scene.queue_free()
		_mine_scene = null
	if _overlay_layer != null:
		# 归位到 $UILayer（其本就声明于此 CanvasLayer，屏幕空间），避免相机恢复后在世界空间错位。
		_document_overlay.reparent($UILayer, false)
		_overlay_layer.queue_free()
		_overlay_layer = null
	for n in _hidden_for_mine:
		if n != null and is_instance_valid(n):
			n.visible = true
	_hidden_for_mine.clear()
	_camera.enabled = true
	_camera.set_active(true)
	_refresh_map()


func _update_stamina_display() -> void:
	_stamina_label.text = "体力：" + str(_stamina_left) + "/" + str(_max_stamina)

func _on_continue() -> void:
	_result_panel.visible = false


func open_ledger() -> void:
	get_node("/root/GameManager").request_open_document("ledger")


func open_document(document: Dictionary) -> void:
	_document_overlay.open_document(document)


func _toggle_menu() -> void:
	_inventory_overlay.close()
	_document_overlay.close()
	_overlay_menu.visible = not _overlay_menu.visible
	if _overlay_menu.visible:
		_build_recipe_list_overlay()
		_build_backpack_list_overlay()
		_build_encyclopedia_content()
		_recipe_panel.visible = true
		_backpack_panel.visible = false
		_encyclopedia_panel.visible = false
		_select_overlay_tab(_overlay_menu.get_node("TabBtns/BtnRecipes") as Button)


func _build_overlay_menu() -> void:
	_overlay_menu = Panel.new()
	_overlay_menu.name = "OverlayMenu"
	_overlay_menu.visible = false
	_overlay_menu.z_index = 200
	_overlay_menu.offset_left = 300.0
	_overlay_menu.offset_top = 64.0
	_overlay_menu.offset_right = 980.0
	_overlay_menu.offset_bottom = 440.0
	$UILayer.add_child(_overlay_menu)
	ThemeColors.style_brush_panel(_overlay_menu)

	# 选项卡按钮行
	var tab_btns := HBoxContainer.new()
	tab_btns.name = "TabBtns"
	tab_btns.add_theme_constant_override("separation", 2)
	tab_btns.offset_left = 14.0
	tab_btns.offset_top = 10.0
	tab_btns.offset_right = 666.0
	tab_btns.offset_bottom = 42.0
	_overlay_menu.add_child(tab_btns)

	var tab_configs: Array = [
		["BtnRecipes", "配方"], ["BtnBackpack", "背包"],
		["BtnEncyclopedia", "图鉴"], ["BtnTutorial", "教程"],
	]
	for pair in tab_configs:
		var id: String = pair[0]
		var label: String = pair[1]
		var btn := Button.new()
		btn.name = id
		btn.text = label
		btn.custom_minimum_size = Vector2(60, 30)
		ThemeColors.style_brush_tab_button(btn)
		tab_btns.add_child(btn)

	# 配方面板
	_recipe_panel = Control.new()
	_recipe_panel.name = "RecipePanel"
	_recipe_panel.visible = true
	_recipe_panel.offset_left = 10.0
	_recipe_panel.offset_top = 50.0
	_recipe_panel.offset_right = 670.0
	_recipe_panel.offset_bottom = 370.0
	_overlay_menu.add_child(_recipe_panel)

	var recipe_scroll := ScrollContainer.new()
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.offset_right = 660.0
	recipe_scroll.offset_bottom = 320.0
	_recipe_panel.add_child(recipe_scroll)

	var recipe_list := VBoxContainer.new()
	recipe_list.name = "RecipeList"
	recipe_scroll.add_child(recipe_list)

	# 背包面板
	_backpack_panel = Control.new()
	_backpack_panel.name = "BackpackPanel"
	_backpack_panel.visible = false
	_backpack_panel.offset_left = 10.0
	_backpack_panel.offset_top = 50.0
	_backpack_panel.offset_right = 670.0
	_backpack_panel.offset_bottom = 370.0
	_overlay_menu.add_child(_backpack_panel)

	var backpack_scroll := ScrollContainer.new()
	backpack_scroll.name = "BackpackScroll"
	backpack_scroll.offset_right = 660.0
	backpack_scroll.offset_bottom = 320.0
	_backpack_panel.add_child(backpack_scroll)

	var backpack_list := VBoxContainer.new()
	backpack_list.name = "BackpackList"
	backpack_scroll.add_child(backpack_list)

	# 图鉴面板
	_encyclopedia_panel = Control.new()
	_encyclopedia_panel.name = "EncyclopediaPanel"
	_encyclopedia_panel.visible = false
	_encyclopedia_panel.offset_left = 10.0
	_encyclopedia_panel.offset_top = 50.0
	_encyclopedia_panel.offset_right = 670.0
	_encyclopedia_panel.offset_bottom = 370.0
	_overlay_menu.add_child(_encyclopedia_panel)

	var encyc_scroll := ScrollContainer.new()
	encyc_scroll.name = "EncycScroll"
	encyc_scroll.offset_right = 660.0
	encyc_scroll.offset_bottom = 320.0
	_encyclopedia_panel.add_child(encyc_scroll)

	var encyc_content := VBoxContainer.new()
	encyc_content.name = "EncycContent"
	encyc_scroll.add_child(encyc_content)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(80, 34)
	close_btn.offset_left = 300.0
	close_btn.offset_top = 378.0
	close_btn.offset_right = 380.0
	close_btn.offset_bottom = 414.0
	close_btn.pressed.connect(_toggle_menu)
	_overlay_menu.add_child(close_btn)
	ThemeColors.style_brush_button(close_btn, 14)

	# 整理按钮
	var tidy_btn := Button.new()
	tidy_btn.name = "BtnTidy"
	tidy_btn.text = "整理桌面"
	tidy_btn.custom_minimum_size = Vector2(80, 34)
	tidy_btn.offset_left = 385.0
	tidy_btn.offset_top = 378.0
	tidy_btn.offset_right = 465.0
	tidy_btn.offset_bottom = 414.0
	_overlay_menu.add_child(tidy_btn)
	ThemeColors.style_brush_button(tidy_btn, 14)

	# 选项卡信号
	tab_btns.get_node("BtnRecipes").pressed.connect(func():
		_recipe_panel.visible = true
		_backpack_panel.visible = false
		_encyclopedia_panel.visible = false
		_select_overlay_tab(tab_btns.get_node("BtnRecipes") as Button)
	)
	tab_btns.get_node("BtnBackpack").pressed.connect(func():
		_recipe_panel.visible = false
		_inventory_overlay.close()
		_inventory_overlay.open()
		_overlay_menu.visible = false
	)
	tab_btns.get_node("BtnEncyclopedia").pressed.connect(func():
		_recipe_panel.visible = false
		_backpack_panel.visible = false
		_encyclopedia_panel.visible = true
		_select_overlay_tab(tab_btns.get_node("BtnEncyclopedia") as Button)
	)
	tab_btns.get_node("BtnTutorial").pressed.connect(func():
		var tm = get_node_or_null("/root/TutorialManager")
		if tm != null:
			tm.replay_all()
			# 显示简单提示
		_select_overlay_tab(tab_btns.get_node("BtnTutorial") as Button)
	)


func _select_overlay_tab(selected: Button) -> void:
	var tab_btns = selected.get_parent()
	for child in tab_btns.get_children():
		if child is Button:
			ThemeColors.set_brush_selected(child, child == selected)


func _build_recipe_list_overlay() -> void:
	var gm = get_node("/root/GameManager")
	var recipe_list = _overlay_menu.get_node("RecipePanel/RecipeScroll/RecipeList")
	for child in recipe_list.get_children():
		child.queue_free()

	var keys: Array = gm.craft.recipes.keys()
	keys.sort()
	for product_key in keys:
		var recipe: Dictionary = gm.craft.recipes[product_key]
		var container: String = recipe.get("container", "")
		var ingredients: Array = recipe.get("ingredients", [])
		if container == "" or ingredients.is_empty():
			continue

		var product_data: Dictionary = gm.craft.get_item(product_key)
		var locked: bool = bool(recipe.get("requires_purchase", false)) and not gm.craft.is_recipe_unlocked(product_key)

		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0.0, 34.0)
		ThemeColors.style_brush_content_panel(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row_panel.add_child(row)

		var icon_tex = gm.try_load_material_icon(product_key)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(28, 28)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)

		var ingr_names := PackedStringArray()
		for ing in ingredients:
			ingr_names.append(String(gm.craft.get_item(ing).get("name", ing)))
		var product_name: String = product_data.get("name", product_key)
		var price: int = int(product_data.get("price", 0))

		var text: String = "%s  %d金   ← %s" % [product_name, price, "＋".join(ingr_names)]
		if locked:
			text += "  （需解锁）"

		var name_label = Label.new()
		name_label.text = " " + text
		ThemeColors.style_brush_label(name_label, 13, Color(0.55, 0.5, 0.45) if locked else ThemeColors.TEXT_LIGHT)
		row.add_child(name_label)

		recipe_list.add_child(row_panel)


func _build_backpack_list_overlay() -> void:
	var gm = get_node("/root/GameManager")
	var inventory: Dictionary = gm.inventory
	var backpack_list = _overlay_menu.get_node("BackpackPanel/BackpackScroll/BackpackList")
	for child in backpack_list.get_children():
		child.queue_free()

	for mat in inventory:
		var count: int = inventory[mat]
		if count <= 0:
			continue

		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0.0, 30.0)
		ThemeColors.style_brush_content_panel(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row_panel.add_child(row)

		var icon_tex = gm.try_load_material_icon(mat)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(24, 24)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)

		var mat_item: Dictionary = gm.craft.get_item(mat)
		var display_name = mat_item.get("name", mat)
		var label = Label.new()
		label.text = display_name + "  x" + str(count)
		label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)

		backpack_list.add_child(row_panel)


const ATTRIBUTE_NAMES: Dictionary = {
	"might": "蛮勇之力",
	"alacrity": "疾风之敏",
	"fortune": "命运眷顾",
	"arcana": "奥术灵韵",
	"vitality": "磐石之躯",
	"charm": "魅惑之息",
}


func _build_encyclopedia_content() -> void:
	var gm = get_node("/root/GameManager")
	var content: VBoxContainer = _encyclopedia_panel.get_node("EncycScroll/EncycContent")
	for child in content.get_children():
		child.queue_free()

	# 食品图鉴
	var food_header := Label.new()
	food_header.text = "— 食品图鉴 —"
	food_header.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	food_header.add_theme_font_size_override("font_size", 16)
	content.add_child(food_header)
	content.add_child(_make_spacer(4))

	var attr_data: Dictionary = _load_food_attributes()

	var product_keys: Array = []
	for key in gm.craft.items:
		var item: Dictionary = gm.craft.items[key]
		if item.get("type", "") == "product":
			product_keys.append(key)
	product_keys.sort()

	for product_key in product_keys:
		var item: Dictionary = gm.craft.get_item(product_key)
		var attrs: Dictionary = attr_data.get(product_key, {})
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 28)
		ThemeColors.style_brush_content_panel(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row_panel.add_child(row)

		var icon_tex = gm.try_load_material_icon(product_key)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(20, 20)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)

		var name_label := Label.new()
		name_label.text = " %s  %d金" % [item.get("name", product_key), int(item.get("price", 0))]
		name_label.custom_minimum_size = Vector2(170, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_label)

		if attrs.is_empty():
			var none_l := Label.new()
			none_l.text = "（无特殊属性）"
			none_l.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
			none_l.add_theme_font_size_override("font_size", 11)
			row.add_child(none_l)
		else:
			for attr_key in attrs:
				var val: int = int(attrs[attr_key])
				var attr_name: String = ATTRIBUTE_NAMES.get(attr_key, attr_key)
				var sign := "+" if val >= 0 else ""
				var al := Label.new()
				al.text = "%s%s%d" % [attr_name, sign, val]
				al.add_theme_color_override("font_color", _attribute_color(attr_key))
				al.add_theme_font_size_override("font_size", 11)
				row.add_child(al)

		content.add_child(row_panel)

	# 剧情道具
	content.add_child(_make_spacer(6))
	var story_header := Label.new()
	story_header.text = "— 剧情道具 —"
	story_header.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	story_header.add_theme_font_size_override("font_size", 16)
	content.add_child(story_header)
	content.add_child(_make_spacer(4))

	var doc_sys = gm.documents if gm != null else null
	if doc_sys != null and doc_sys.has_method("get_owned_documents"):
		for doc_id in doc_sys.get_owned_documents():
			if doc_id == "ledger":
				continue
			var doc: Dictionary = doc_sys.get_document(doc_id)
			if doc.is_empty():
				continue
			var dp := PanelContainer.new()
			dp.custom_minimum_size = Vector2(0, 28)
			ThemeColors.style_brush_content_panel(dp)
			var dh := HBoxContainer.new()
			dp.add_child(dh)
			var dn := Label.new()
			dn.text = " %s" % doc.get("title", doc_id)
			dn.custom_minimum_size = Vector2(180, 0)
			dn.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
			dn.add_theme_font_size_override("font_size", 13)
			dh.add_child(dn)
			var dd := Label.new()
			dd.text = doc.get("description", "")
			dd.custom_minimum_size = Vector2(420, 0)
			dd.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
			dd.add_theme_font_size_override("font_size", 11)
			dh.add_child(dd)
			content.add_child(dp)


func _make_spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _attribute_color(attr_key: String) -> Color:
	match attr_key:
		"might": return Color(0.95, 0.3, 0.2)
		"alacrity": return Color(0.2, 0.7, 0.4)
		"fortune": return Color(0.95, 0.85, 0.1)
		"arcana": return Color(0.5, 0.3, 0.9)
		"vitality": return Color(0.3, 0.5, 0.8)
		"charm": return Color(0.95, 0.45, 0.65)
		_: return ThemeColors.TEXT_SUBTITLE


func _load_food_attributes() -> Dictionary:
	var file = FileAccess.open("res://data/food_attributes.json", FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		return {}
	return data


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _document_overlay.visible:
			_document_overlay.close()
			get_viewport().set_input_as_handled()
		elif _inventory_overlay.visible:
			_inventory_overlay.close()
			get_viewport().set_input_as_handled()
		elif _overlay_menu != null and _overlay_menu.visible:
			_overlay_menu.visible = false
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

func _update_status_bar() -> void:
	var gm = get_node("/root/GameManager")
	if gm != null:
		_status_label.text = "金币：%d | 声望：%d" % [gm.economy.gold, gm.economy.reputation]

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
	_update_status_bar()

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
				_update_status_bar()
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
					_update_status_bar()
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
					_update_status_bar()
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


func _on_inventory_changed() -> void:
	if not is_instance_valid(self):
		return
	if _overlay_menu != null and _overlay_menu.visible:
		_build_backpack_list_overlay()


func _exit_tree() -> void:
	var gm = get_node("/root/GameManager")
	if gm != null and gm.inventory_changed.is_connected(_on_inventory_changed):
		gm.inventory_changed.disconnect(_on_inventory_changed)
