class_name DayMapView
extends Node2D

signal gathering_confirmed(assignments: Dictionary)

const MINE_SCENE := preload("res://scenes/ui/MineInvestigation.tscn")
const TOBY_SCENE := preload("res://scenes/ui/TobyLodgingInvestigation.tscn")
const INVESTIGATION_SCENES := {
	"abandoned_mine": MINE_SCENE,
	"toby_lodging": TOBY_SCENE,
}
const POINT_MARKER := preload("res://scenes/ui/MapPointMarker.tscn")
const DAYMAP_BACKGROUND := preload("res://assets/textures/daymap/daymap_full.png")
const DAYMAP_FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const DAYMAP_BUTTON_PRIMARY_NORMAL := "res://assets/textures/daymap/ui/button_primary_normal.png"
const DAYMAP_BUTTON_PRIMARY_HOVER := "res://assets/textures/daymap/ui/button_primary_hover.png"
const DAYMAP_BUTTON_PRIMARY_PRESSED := "res://assets/textures/daymap/ui/button_primary_pressed.png"
const DAYMAP_PRIMARY_BUTTON_SIZE := Vector2(280, 72)
const DAYMAP_BUTTON_LEDGER_NORMAL := "res://assets/textures/daymap/ui/button_ledger_normal.png"
const DAYMAP_BUTTON_LEDGER_HOVER := "res://assets/textures/daymap/ui/button_ledger_hover.png"
const DAYMAP_BUTTON_LEDGER_PRESSED := "res://assets/textures/daymap/ui/button_ledger_pressed.png"
const DAYMAP_LEDGER_BUTTON_SIZE := Vector2(132, 44)
const DAYMAP_PANEL_DETAIL := "res://assets/textures/daymap/ui/panel_detail.png"
const DAYMAP_PANEL_RESULT := "res://assets/textures/daymap/ui/panel_result.png"
const DAYMAP_PANEL_SHOP := "res://assets/textures/daymap/ui/panel_shop.png"
const DAYMAP_SHOP_BACKDROP := "res://assets/textures/daymap/ui/shop_backdrop.png"
const DAYMAP_SCROLL_TRACK := "res://assets/textures/daymap/ui/scroll_track.png"
const DAYMAP_SCROLL_GRABBER := "res://assets/textures/daymap/ui/scroll_grabber.png"
const DAYMAP_TOPBAR_STRIP := "res://assets/textures/daymap/ui/topbar_strip.png"
const DAYMAP_BUTTON_SHOP_SQUARE_NORMAL := "res://assets/textures/daymap/ui/button_shop_square_normal.png"
const DAYMAP_BUTTON_SHOP_SQUARE_HOVER := "res://assets/textures/daymap/ui/button_shop_square_hover.png"
const DAYMAP_BUTTON_SHOP_SQUARE_PRESSED := "res://assets/textures/daymap/ui/button_shop_square_pressed.png"
const DAYMAP_BUTTON_SHOP_WIDE_NORMAL := "res://assets/textures/daymap/ui/button_shop_wide_normal.png"
const DAYMAP_BUTTON_SHOP_WIDE_HOVER := "res://assets/textures/daymap/ui/button_shop_wide_hover.png"
const DAYMAP_BUTTON_SHOP_WIDE_PRESSED := "res://assets/textures/daymap/ui/button_shop_wide_pressed.png"
const DAYMAP_SHOP_SQUARE_BUTTON_SIZE := Vector2(36, 36)
const DAYMAP_SHOP_WIDE_BUTTON_SIZE := Vector2(72, 36)
const DAYMAP_STATUS_FONT_SIZE := 18
const DAYMAP_HEADER_FONT_SIZE := 20
const DAYMAP_BODY_FONT_SIZE := 15
const DAYMAP_RESULT_FONT_SIZE := 16
const DAYMAP_PRIMARY_BUTTON_FONT_SIZE := 18
const DAYMAP_LEDGER_BUTTON_FONT_SIZE := 15
const DAYMAP_SHOP_SECTION_FONT_SIZE := 15
const DAYMAP_SHOP_ROW_FONT_SIZE := 15
const DAYMAP_SHOP_META_FONT_SIZE := 13
const DAYMAP_SHOP_QTY_FONT_SIZE := 16
const DAYMAP_SHOP_BUTTON_FONT_SIZE := 13
const DAYMAP_TOPBAR_DAY_POS := Vector2(72, 10)
const DAYMAP_TOPBAR_DAY_SIZE := Vector2(300, 40)
const DAYMAP_TOPBAR_STAMINA_POS := Vector2(420, 10)
const DAYMAP_TOPBAR_STAMINA_SIZE := Vector2(170, 40)
const DAYMAP_TOPBAR_GOLD_POS := Vector2(610, 10)
const DAYMAP_TOPBAR_GOLD_SIZE := Vector2(170, 40)
const DAYMAP_LEDGER_BUTTON_POS := Vector2(1060, 8)
const DAYMAP_DETAIL_INSET := Vector2(36, 34)
const DAYMAP_DETAIL_BODY_X := 58.0
const DAYMAP_DETAIL_BODY_WIDTH := 204.0
const DAYMAP_RESULT_INSET := Vector2(48, 42)
const DAYMAP_RESULT_TEXT_POS := Vector2(90, 76)
const DAYMAP_RESULT_TEXT_SIZE := Vector2(520, 210)
const DAYMAP_SHOP_BACKGROUND_POS := Vector2(0, 84)
const DAYMAP_SHOP_BACKGROUND_SIZE := Vector2(1000, 336)
const DAYMAP_SHOP_SCROLL_POS := Vector2(28, 106)
const DAYMAP_SHOP_SCROLL_SIZE := Vector2(944, 300)
const DAYMAP_SHOP_CONTENT_WIDTH := 900.0
const DAYMAP_BUTTON_TEXT_MARGIN_X := 28.0
const DAYMAP_BUTTON_TEXT_MARGIN_Y := 9.0

const HOME_ID := "__home__"
const HOME_POS := Vector2(760, 845)
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

var _investigation_scene: Node = null
var _hidden_for_investigation: Array = []
var _overlay_layer: CanvasLayer = null

# Shop
var _shop_open: bool = false
var _shop_close_btn: Button
var _shop_backdrop: TextureRect
var _shop_background: Panel
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
	_setup_topbar_material()

	_stamina_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_stamina_label.add_theme_font_size_override("font_size", DAYMAP_STATUS_FONT_SIZE)
	_apply_daymap_label_font(_stamina_label)
	ThemeColors.style_header(_day_label, DAYMAP_HEADER_FONT_SIZE)
	_apply_daymap_label_font(_day_label)
	_style_daymap_primary_button(_continue_btn, DAYMAP_PRIMARY_BUTTON_FONT_SIZE)
	_continue_btn.position = Vector2(210, 312)
	_continue_btn.size = DAYMAP_PRIMARY_BUTTON_SIZE
	_result_panel.add_theme_stylebox_override("panel", _daymap_panel_style(DAYMAP_PANEL_RESULT))
	_result_label.position = DAYMAP_RESULT_TEXT_POS
	_result_label.size = DAYMAP_RESULT_TEXT_SIZE
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_result_label.add_theme_font_size_override("font_size", DAYMAP_RESULT_FONT_SIZE)
	_apply_daymap_label_font(_result_label)

	_continue_btn.pressed.connect(_on_continue)
	var documents_btn: Button = $UILayer/TopBar/DocumentsBtn
	_style_daymap_ledger_button(documents_btn, DAYMAP_LEDGER_BUTTON_FONT_SIZE)
	documents_btn.pressed.connect(_open_latest_document)

	_gold_label = $UILayer/TopBar/GoldLabel
	_gold_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_gold_label.add_theme_font_size_override("font_size", DAYMAP_STATUS_FONT_SIZE)
	_apply_daymap_label_font(_gold_label)
	_apply_topbar_layout(documents_btn)

	_setup_detail_panel()

	var gm = get_node("/root/GameManager")
	if gm != null:
		gm.register_view(self)

	_build_shop_ui()
	_setup_background()


func _setup_background() -> void:
	var gm = get_node("/root/GameManager")
	var map_world := $MapWorld
	var bounds: Dictionary = gm.day_map.get_map_bounds()
	# The art is one full-map texture; logical region data only defines bounds/anchors.
	for child in map_world.get_children():
		if String(child.name).begins_with("RegionTile_"):
			child.queue_free()
	var background: Sprite2D = get_node_or_null("MapWorld/Background") as Sprite2D
	if background == null:
		background = Sprite2D.new()
		background.name = "Background"
		map_world.add_child(background)
		map_world.move_child(background, 0)
	background.z_index = -10
	background.centered = true
	background.position = (bounds["min"] + bounds["max"]) * 0.5
	background.texture = DAYMAP_BACKGROUND
	_camera.set_bounds(bounds["min"], bounds["max"])


func _setup_topbar_material() -> void:
	var topbar := $UILayer/TopBar
	var strip := topbar.get_node_or_null("TopStrip") as TextureRect
	if strip == null:
		strip = TextureRect.new()
		strip.name = "TopStrip"
		topbar.add_child(strip)
		topbar.move_child(strip, 0)
	strip.texture = load(DAYMAP_TOPBAR_STRIP) as Texture2D
	strip.position = Vector2.ZERO
	strip.size = Vector2(1280, 60)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.stretch_mode = TextureRect.STRETCH_SCALE


func _apply_topbar_layout(documents_btn: Button) -> void:
	_day_label.position = DAYMAP_TOPBAR_DAY_POS
	_day_label.size = DAYMAP_TOPBAR_DAY_SIZE
	_stamina_label.position = DAYMAP_TOPBAR_STAMINA_POS
	_stamina_label.size = DAYMAP_TOPBAR_STAMINA_SIZE
	_gold_label.position = DAYMAP_TOPBAR_GOLD_POS
	_gold_label.size = DAYMAP_TOPBAR_GOLD_SIZE
	documents_btn.position = DAYMAP_LEDGER_BUTTON_POS
	documents_btn.size = DAYMAP_LEDGER_BUTTON_SIZE


func _setup_detail_panel() -> void:
	_detail_panel.size = Vector2(320, 480)
	_detail_panel.add_theme_stylebox_override("panel", _daymap_panel_style(DAYMAP_PANEL_DETAIL))
	var content_width := _detail_panel.size.x - DAYMAP_DETAIL_INSET.x * 2.0
	var name_label: Label = _detail_panel.get_node("Name")
	name_label.position = DAYMAP_DETAIL_INSET
	name_label.size = Vector2(content_width, 36)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeColors.style_header(name_label, DAYMAP_HEADER_FONT_SIZE)
	_apply_daymap_label_font(name_label)
	var desc_label: Label = _detail_panel.get_node("Desc")
	desc_label.position = Vector2(DAYMAP_DETAIL_BODY_X, 88)
	desc_label.size = Vector2(DAYMAP_DETAIL_BODY_WIDTH, 140)
	var cost_label: Label = _detail_panel.get_node("Cost")
	cost_label.position = Vector2(DAYMAP_DETAIL_BODY_X, 256)
	cost_label.size = Vector2(DAYMAP_DETAIL_BODY_WIDTH, 36)
	var yield_label: Label = _detail_panel.get_node("Yield")
	yield_label.position = Vector2(DAYMAP_DETAIL_BODY_X, 306)
	yield_label.size = Vector2(DAYMAP_DETAIL_BODY_WIDTH, 62)
	for lbl in [desc_label, cost_label, yield_label]:
		lbl.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
		lbl.add_theme_font_size_override("font_size", DAYMAP_BODY_FONT_SIZE)
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.38))
		_apply_daymap_label_font(lbl)
	var go_here: Button = _detail_panel.get_node("GoHereBtn")
	_style_daymap_primary_button(go_here, DAYMAP_PRIMARY_BUTTON_FONT_SIZE)
	go_here.position = Vector2(20, 388)
	go_here.size = DAYMAP_PRIMARY_BUTTON_SIZE
	go_here.pressed.connect(_on_go_here_pressed)
	_detail_panel.visible = false


func _style_daymap_primary_button(button: Button, font_size: int = DAYMAP_PRIMARY_BUTTON_FONT_SIZE) -> void:
	button.custom_minimum_size = DAYMAP_PRIMARY_BUTTON_SIZE
	button.size = DAYMAP_PRIMARY_BUTTON_SIZE
	button.add_theme_font_override("font", DAYMAP_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ThemeColors.TEXT_SUBTITLE)
	button.add_theme_color_override("font_disabled_color", ThemeColors.TEXT_DIM)
	button.add_theme_stylebox_override("normal", _daymap_texture_style(DAYMAP_BUTTON_PRIMARY_NORMAL))
	button.add_theme_stylebox_override("hover", _daymap_texture_style(DAYMAP_BUTTON_PRIMARY_HOVER))
	button.add_theme_stylebox_override("pressed", _daymap_texture_style(DAYMAP_BUTTON_PRIMARY_PRESSED))
	button.add_theme_stylebox_override("disabled", _daymap_texture_style(DAYMAP_BUTTON_PRIMARY_NORMAL))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_daymap_label_font(label: Label) -> void:
	label.add_theme_font_override("font", DAYMAP_FONT)


func _daymap_texture_style(path: String) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		return StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, DAYMAP_BUTTON_TEXT_MARGIN_X)
	style.set_content_margin(SIDE_RIGHT, DAYMAP_BUTTON_TEXT_MARGIN_X)
	style.set_content_margin(SIDE_TOP, DAYMAP_BUTTON_TEXT_MARGIN_Y)
	style.set_content_margin(SIDE_BOTTOM, DAYMAP_BUTTON_TEXT_MARGIN_Y + 1.0)
	return style


func _style_daymap_ledger_button(button: Button, font_size: int = DAYMAP_LEDGER_BUTTON_FONT_SIZE) -> void:
	button.custom_minimum_size = DAYMAP_LEDGER_BUTTON_SIZE
	button.size = DAYMAP_LEDGER_BUTTON_SIZE
	button.add_theme_font_override("font", DAYMAP_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ThemeColors.TEXT_SUBTITLE)
	button.add_theme_color_override("font_disabled_color", ThemeColors.TEXT_DIM)
	button.add_theme_stylebox_override("normal", _daymap_ledger_texture_style(DAYMAP_BUTTON_LEDGER_NORMAL))
	button.add_theme_stylebox_override("hover", _daymap_ledger_texture_style(DAYMAP_BUTTON_LEDGER_HOVER))
	button.add_theme_stylebox_override("pressed", _daymap_ledger_texture_style(DAYMAP_BUTTON_LEDGER_PRESSED))
	button.add_theme_stylebox_override("disabled", _daymap_ledger_texture_style(DAYMAP_BUTTON_LEDGER_NORMAL))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _daymap_ledger_texture_style(path: String) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		return StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, 16.0)
	style.set_content_margin(SIDE_RIGHT, 16.0)
	style.set_content_margin(SIDE_TOP, 5.0)
	style.set_content_margin(SIDE_BOTTOM, 6.0)
	return style


func _daymap_panel_style(path: String) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		return StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, 34.0)
	style.set_content_margin(SIDE_RIGHT, 34.0)
	style.set_content_margin(SIDE_TOP, 32.0)
	style.set_content_margin(SIDE_BOTTOM, 32.0)
	return style


func _daymap_shop_panel_style() -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(DAYMAP_PANEL_SHOP)
	if style == null:
		return StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, 36.0)
	style.set_content_margin(SIDE_RIGHT, 36.0)
	style.set_content_margin(SIDE_TOP, 38.0)
	style.set_content_margin(SIDE_BOTTOM, 28.0)
	return style


func _style_daymap_shop_square_button(button: Button, font_size: int = DAYMAP_SHOP_BUTTON_FONT_SIZE) -> void:
	_style_daymap_shop_button(
		button,
		font_size,
		DAYMAP_SHOP_SQUARE_BUTTON_SIZE,
		DAYMAP_BUTTON_SHOP_SQUARE_NORMAL,
		DAYMAP_BUTTON_SHOP_SQUARE_HOVER,
		DAYMAP_BUTTON_SHOP_SQUARE_PRESSED
	)


func _style_daymap_shop_wide_button(button: Button, font_size: int = DAYMAP_SHOP_BUTTON_FONT_SIZE) -> void:
	_style_daymap_shop_button(
		button,
		font_size,
		DAYMAP_SHOP_WIDE_BUTTON_SIZE,
		DAYMAP_BUTTON_SHOP_WIDE_NORMAL,
		DAYMAP_BUTTON_SHOP_WIDE_HOVER,
		DAYMAP_BUTTON_SHOP_WIDE_PRESSED
	)


func _style_daymap_shop_button(button: Button, font_size: int, size: Vector2, normal: String, hover: String, pressed: String) -> void:
	button.custom_minimum_size = size
	button.size = size
	button.add_theme_font_override("font", DAYMAP_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ThemeColors.TEXT_SUBTITLE)
	button.add_theme_stylebox_override("normal", _daymap_shop_texture_style(normal))
	button.add_theme_stylebox_override("hover", _daymap_shop_texture_style(hover))
	button.add_theme_stylebox_override("pressed", _daymap_shop_texture_style(pressed))
	button.add_theme_stylebox_override("disabled", _daymap_shop_texture_style(normal))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _daymap_shop_texture_style(path: String) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		return StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 5.0)
	return style


func _style_daymap_shop_scrollbar(scroll: ScrollContainer) -> void:
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	vbar.custom_minimum_size = Vector2(16, 0)
	var track := _daymap_scroll_texture_style(DAYMAP_SCROLL_TRACK)
	var grabber := _daymap_scroll_texture_style(DAYMAP_SCROLL_GRABBER)
	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("scroll_focus", track)
	vbar.add_theme_stylebox_override("grabber", grabber)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber)


func _daymap_scroll_texture_style(path: String) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		return StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func show_day(day: int, total_days: int) -> void:
	_day_label.text = "第 %d/%d 天 — 白天·行动" % [day, total_days]
	var gm = get_node("/root/GameManager")
	_max_stamina = gm.day_map.max_stamina
	_stamina_left = gm.day_map.stamina
	_update_stamina_display()
	_result_panel.visible = false
	_continue_btn.visible = true
	_shop_open = false
	if _shop_panel != null:
		_shop_panel.visible = false
	if _shop_backdrop != null:
		_shop_backdrop.visible = false
	if _shop_background != null:
		_shop_background.visible = false
	if _shop_close_btn != null:
		_shop_close_btn.visible = false
	_camera.set_active(true)
	_detail_panel.visible = false
	_clear_selection()
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
	_clear_selection()
	_selected_id = location_id
	_set_marker_selected(location_id, true)
	_show_detail(location_id)


## 撤掉当前选中 marker 的金圈并清空 _selected_id。
## 所有清空选中的入口都必须走这里，否则常驻 marker（home/已访问/商店）会残留金圈，
## 下一次选中再叠一个 → 地图上出现两个金色选中圈。
func _clear_selection() -> void:
	_set_marker_selected(_selected_id, false)
	_selected_id = ""


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
	if bool(loc.get("opensShop", false)):
		_detail_panel.get_node("Cost").text = ""
		_detail_panel.get_node("Yield").text = ""
		go_here.text = "进入"
	else:
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
	if _is_shop_location(_selected_id):
		_open_shop()
		return
	_visit_location(_selected_id)


func _is_shop_location(location_id: String) -> bool:
	var gm = get_node("/root/GameManager")
	for l in gm.day_map.get_locations():
		if String(l.get("id", "")) == location_id:
			return bool(l.get("opensShop", false))
	return false


func _visit_location(location_id: String) -> void:
	var gm = get_node("/root/GameManager")
	var result: Dictionary = gm.visit_day_location(location_id)
	if INVESTIGATION_SCENES.has(location_id) and bool(result.get("success", false)):
		_stamina_left = gm.day_map.stamina
		_update_stamina_display()
		_enter_investigation(INVESTIGATION_SCENES[location_id])
		return
	_result_label.text = String(result.get("message", "访问完成。"))
	_result_panel.visible = true
	_continue_btn.text = "知道了"
	_stamina_left = gm.day_map.stamina
	_update_stamina_display()
	_detail_panel.visible = false
	_clear_selection()
	_refresh_map()


func _enter_investigation(scene: PackedScene) -> void:
	if _investigation_scene != null:
		return
	_investigation_scene = scene.instantiate()
	add_child(_investigation_scene)
	# 让出地图相机：调查场景按 world==screen 的恒等坐标编写（物品在世界坐标拾取/命中），
	# 而 DayMapCamera 此刻是缩放/平移过的当前相机。禁用它使视口回到恒等变换，否则
	# 物品渲染错位、event.global_position 命中测试全落空（表现为"什么都点不到"）。
	_camera.set_active(false)
	_camera.enabled = false
	# DocumentOverlay 提到高层 CanvasLayer，确保挖出/拼出委托书时压在调查场景(含其 UI CanvasLayer)之上
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)
	_document_overlay.reparent(_overlay_layer, false)
	# 整层隐藏 DayMap UI（含运行时建的商店面板与离开按钮），避免与调查 UI 并存、截获输入。
	# DocumentOverlay 已先移出 $UILayer 到 _overlay_layer，故不受此隐藏影响。
	_hidden_for_investigation = [$MapWorld, $UILayer]
	for n in _hidden_for_investigation:
		if n != null:
			n.visible = false
	_investigation_scene.finished.connect(_on_investigation_finished)


func _on_investigation_finished() -> void:
	if _investigation_scene != null:
		_investigation_scene.queue_free()
		_investigation_scene = null
	if _overlay_layer != null:
		# 归位到 $UILayer（其本就声明于此 CanvasLayer，屏幕空间），避免相机恢复后在世界空间错位。
		_document_overlay.reparent($UILayer, false)
		_overlay_layer.queue_free()
		_overlay_layer = null
	for n in _hidden_for_investigation:
		if n != null and is_instance_valid(n):
			n.visible = true
	_hidden_for_investigation.clear()
	# 恢复 DayMap 相机：_enter_investigation 让出了相机（enabled/active=false），离开时必须复位，
	# 否则退出调查后地图无法平移/缩放（test_mine_enter_exit 守此）。
	_camera.enabled = true
	_camera.set_active(true)


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
		elif _shop_open:
			_close_shop()
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

func _open_shop() -> void:
	_shop_open = true
	$MapWorld.visible = false
	_detail_panel.visible = false
	_clear_selection()
	_camera.set_active(false)
	if _shop_backdrop != null:
		_shop_backdrop.visible = true
	if _shop_background != null:
		_shop_background.visible = true
	_shop_panel.visible = true
	if _shop_close_btn != null:
		_shop_close_btn.visible = true
	_refresh_shop_ui()
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null and not tm.shop_first_visited:
		tm.shop_first_visited = true
		tm._save_state()
		call_deferred("_trigger_shop_tutorial")

func _close_shop() -> void:
	_shop_open = false
	if _shop_backdrop != null:
		_shop_backdrop.visible = false
	if _shop_background != null:
		_shop_background.visible = false
	_shop_panel.visible = false
	if _shop_close_btn != null:
		_shop_close_btn.visible = false
	$MapWorld.visible = true
	_camera.set_active(true)
	_refresh_map()

func _build_shop_ui() -> void:
	var ui_layer := $UILayer
	_shop_backdrop = TextureRect.new()
	_shop_backdrop.name = "ShopBackdrop"
	_shop_backdrop.texture = load(DAYMAP_SHOP_BACKDROP) as Texture2D
	_shop_backdrop.position = Vector2.ZERO
	_shop_backdrop.size = Vector2(1280, 720)
	_shop_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_shop_backdrop.visible = false
	ui_layer.add_child(_shop_backdrop)
	ui_layer.move_child(_shop_backdrop, 0)

	_shop_close_btn = Button.new()
	_shop_close_btn.name = "ShopCloseBtn"
	_shop_close_btn.text = "离开"
	_style_daymap_ledger_button(_shop_close_btn, DAYMAP_LEDGER_BUTTON_FONT_SIZE)
	_shop_close_btn.position = Vector2(1088, 90)
	_shop_close_btn.size = DAYMAP_LEDGER_BUTTON_SIZE
	_shop_close_btn.visible = false
	_shop_close_btn.pressed.connect(_close_shop)
	ui_layer.add_child(_shop_close_btn)

	var map_area := $UILayer/MapArea
	_shop_background = Panel.new()
	_shop_background.name = "ShopBackground"
	_shop_background.position = DAYMAP_SHOP_BACKGROUND_POS
	_shop_background.size = DAYMAP_SHOP_BACKGROUND_SIZE
	_shop_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_background.visible = false
	_shop_background.add_theme_stylebox_override("panel", _daymap_shop_panel_style())
	map_area.add_child(_shop_background)

	_shop_panel = ScrollContainer.new()
	_shop_panel.position = DAYMAP_SHOP_SCROLL_POS
	_shop_panel.size = DAYMAP_SHOP_SCROLL_SIZE
	_shop_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_panel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_shop_panel.visible = false
	_style_daymap_shop_scrollbar(_shop_panel)
	map_area.add_child(_shop_panel)

	var shop_content = VBoxContainer.new()
	shop_content.add_theme_constant_override("separation", 8)
	shop_content.custom_minimum_size = Vector2(DAYMAP_SHOP_CONTENT_WIDTH, 0)
	_shop_panel.add_child(shop_content)

	_shop_title = Label.new()
	_shop_title.custom_minimum_size = Vector2(0, 36)
	ThemeColors.style_header(_shop_title, DAYMAP_HEADER_FONT_SIZE)
	_apply_daymap_label_font(_shop_title)
	shop_content.add_child(_shop_title)

	var mat_title = Label.new()
	mat_title.text = "—— 购买材料 ——"
	mat_title.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	mat_title.add_theme_font_size_override("font_size", DAYMAP_SHOP_SECTION_FONT_SIZE)
	_apply_daymap_label_font(mat_title)
	mat_title.custom_minimum_size = Vector2(0, 30)
	shop_content.add_child(mat_title)

	_material_list = VBoxContainer.new()
	_material_list.add_theme_constant_override("separation", 4)
	shop_content.add_child(_material_list)

	var recipe_title = Label.new()
	recipe_title.text = "—— 解锁配方 ——"
	recipe_title.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	recipe_title.add_theme_font_size_override("font_size", DAYMAP_SHOP_SECTION_FONT_SIZE)
	_apply_daymap_label_font(recipe_title)
	recipe_title.custom_minimum_size = Vector2(0, 30)
	shop_content.add_child(recipe_title)

	_recipe_list = VBoxContainer.new()
	_recipe_list.add_theme_constant_override("separation", 4)
	shop_content.add_child(_recipe_list)

	var ability_title = Label.new()
	ability_title.text = "—— 技法 ——"
	ability_title.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	ability_title.add_theme_font_size_override("font_size", DAYMAP_SHOP_SECTION_FONT_SIZE)
	_apply_daymap_label_font(ability_title)
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
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
		name_label.add_theme_font_size_override("font_size", DAYMAP_SHOP_ROW_FONT_SIZE)
		_apply_daymap_label_font(name_label)
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
		price_label.add_theme_font_size_override("font_size", DAYMAP_SHOP_META_FONT_SIZE)
		_apply_daymap_label_font(price_label)
		row.add_child(price_label)

		var sub_btn = Button.new()
		sub_btn.text = "-"
		_style_daymap_shop_square_button(sub_btn, DAYMAP_SHOP_BUTTON_FONT_SIZE)
		var qty_label = Label.new()
		qty_label.text = "0"
		qty_label.custom_minimum_size = Vector2(30, 0)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
		qty_label.add_theme_font_size_override("font_size", DAYMAP_SHOP_QTY_FONT_SIZE)
		_apply_daymap_label_font(qty_label)
		var add_btn = Button.new()
		add_btn.text = "+"
		_style_daymap_shop_square_button(add_btn, DAYMAP_SHOP_BUTTON_FONT_SIZE)

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
		_style_daymap_shop_wide_button(buy_btn, DAYMAP_SHOP_BUTTON_FONT_SIZE)
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
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
		name_label.add_theme_font_size_override("font_size", DAYMAP_SHOP_ROW_FONT_SIZE)
		_apply_daymap_label_font(name_label)
		row.add_child(name_label)

		if gm.craft.is_recipe_unlocked(key):
			var owned = Label.new()
			owned.text = "已拥有"
			owned.custom_minimum_size = Vector2(80, 0)
			owned.add_theme_color_override("font_color", ThemeColors.TEXT_DIM)
			owned.add_theme_font_size_override("font_size", DAYMAP_SHOP_META_FONT_SIZE)
			_apply_daymap_label_font(owned)
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
			price_label.add_theme_font_size_override("font_size", DAYMAP_SHOP_META_FONT_SIZE)
			_apply_daymap_label_font(price_label)
			row.add_child(price_label)

			var unlock_btn = Button.new()
			unlock_btn.text = "解锁"
			_style_daymap_shop_wide_button(unlock_btn, DAYMAP_SHOP_BUTTON_FONT_SIZE)
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
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
		name_label.add_theme_font_size_override("font_size", DAYMAP_SHOP_ROW_FONT_SIZE)
		_apply_daymap_label_font(name_label)
		row.add_child(name_label)

		var owned: bool = gm.is_ability_owned(key)
		if owned:
			var owned_label = Label.new()
			owned_label.text = "已掌握"
			owned_label.custom_minimum_size = Vector2(80, 0)
			owned_label.add_theme_color_override("font_color", ThemeColors.TEXT_DIM)
			owned_label.add_theme_font_size_override("font_size", DAYMAP_SHOP_META_FONT_SIZE)
			_apply_daymap_label_font(owned_label)
			row.add_child(owned_label)
		else:
			var price_label = Label.new()
			price_label.text = str(gm.shop.get_ability_price(key)) + "金"
			price_label.custom_minimum_size = Vector2(60, 0)
			price_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
			price_label.add_theme_font_size_override("font_size", DAYMAP_SHOP_META_FONT_SIZE)
			_apply_daymap_label_font(price_label)
			row.add_child(price_label)

			var buy_btn = Button.new()
			buy_btn.text = "购买"
			_style_daymap_shop_wide_button(buy_btn, DAYMAP_SHOP_BUTTON_FONT_SIZE)
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
