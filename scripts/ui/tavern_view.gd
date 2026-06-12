class_name TavernView
extends Node2D

var _bg_sprite: Sprite2D
var _customer_sprite: TextureRect
var _customer_name: Label
var _order_bubble: Label
var _timer_bar: ProgressBar
var _gold_label: Label
var _rep_label: Label
var _day_label: Label
var _menu_panel: Panel
var _end_night_btn: Button
var _stage_caption: Label
var _caption_tween: Tween
var _dialogue_overlay: ColorRect
var _inventory_overlay: InventoryOverlay
var _document_overlay: DocumentOverlay
var _settings_panel: SettingsPanel
var _gm
var _today_gold: int = 0
var _customer_sprite_normal_z_index: int = 0
var _customer_sprite_normal_modulate: Color = Color.WHITE
var _customer_dialogue_highlight_active: bool = false
var _current_customer_npc_id: String = ""
var _current_customer_reaction_outcome: String = ""
var _recipe_filter_container: String = "barrel"
var _recipe_selected_product_key: String = ""

var daily_menu: Dictionary = {}
var daily_menu_confirmed: bool = true

const CONTAINER_NAMES: Dictionary = {"barrel": "酒桶", "grill": "烤架", "pot": "炖锅"}

const RECIPE_CONTAINER_ORDER := ["barrel", "grill", "pot"]
const RECIPE_CONTAINER_INSTRUCTIONS: Dictionary = {
	"barrel": "投入酒桶后摇晃，完成后从桶口取出。",
	"grill": "放到烤架上，到时间后取下成品。",
	"pot": "投入炖锅后用勺子搅拌，完成后从锅口取出。",
}
const RECIPE_LAYOUT_MIN_SIZE := Vector2(660.0, 360.0)
const RECIPE_LEFT_COLUMN_WIDTH := 300.0
const RECIPE_DETAIL_WIDTH := 340.0
const RECIPE_DETAIL_PANEL_ART := "res://assets/textures/ui/menu_brush_panel.png"
const RECIPE_DETAIL_BAND_ART := "res://assets/textures/ui/menu_brush_band.png"
const RECIPE_SLOT_ART := "res://assets/textures/ui/inventory_slot_normal.png"

const NPC_TEXTURE_KEYS: Dictionary = {
	"ryan": "ryan_neutral",
	"mira": "mira_neutral",
	"toby": "toby_neutral",
	"mercenary_a": "mercenary_a",
}
const RYAN_TEXTURE_NEUTRAL := "ryan_neutral"
const RYAN_TEXTURE_SATISFIED := "ryan_excited"
const RYAN_TEXTURE_HESITANT := "ryan_hesitant"
const RYAN_TEXTURE_DISSATISFIED := "ryan_dejected"
const MIRA_TEXTURE_NEUTRAL := "mira_neutral"
const MIRA_TEXTURE_SMILE := "mira_smile"
const MIRA_TEXTURE_SURPRISED := "mira_surprised"
const MIRA_TEXTURE_SERIOUS := "mira_serious"
const TOPBAR_LEFT_INSET := Vector2(28, 48)
const TOPBAR_RIGHT_INSET := Vector2(28, 48)
const TOPBAR_LABEL_HEIGHT := 48.0
const SHORTCUT_SLOT_SIZE := Vector2(96, 40)
const SHORTCUT_SEPARATION := 4
const DIALOGUE_SPEAKER_Z_INDEX := 10
const DIALOGUE_SPEAKER_MODULATE := Color(1.18, 1.1, 0.95, 1.0)

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_refresh_default_daily_menu()
	_bg_sprite = $Background
	_customer_sprite = $CustomerArea/CustomerSprite
	_customer_sprite_normal_z_index = _customer_sprite.z_index
	_customer_sprite_normal_modulate = _customer_sprite.modulate
	_customer_name = $CustomerArea/CustomerName
	_order_bubble = $CustomerArea/OrderBubble
	_timer_bar = $CustomerArea/TimerBar
	_gold_label = $TopPanel/GoldLabel
	_rep_label = $TopPanel/ReputationLabel
	_day_label = $TopPanel/DayLabel
	_end_night_btn = $TopPanel/EndNightBtn
	_stage_caption = $StageCaption
	_dialogue_overlay = $DialogueOverlay
	_inventory_overlay = $InventoryOverlay
	_inventory_overlay.configure(_gm)
	_inventory_overlay.item_dropped.connect(_on_inventory_item_dropped)
	_document_overlay = $DocumentOverlay
	_settings_panel = $SettingsPanel
	_settings_panel.configure(_gm.settings)
	_settings_panel.closed.connect(_on_settings_closed)
	_settings_panel.tutorial_reset_requested.connect(_on_tutorial_reset_requested)

	_menu_panel = $OverlayMenu
	$TopPanel/MenuButton.pressed.connect(_toggle_menu)
	$OverlayMenu/CloseBtn.pressed.connect(_toggle_menu)
	$OverlayMenu/TabBtns/BtnSettings.pressed.connect(_open_settings)
	var tidy_btn = $OverlayMenu/BtnTidy
	if tidy_btn != null and not tidy_btn.pressed.is_connected(_on_tidy_desk_pressed):
		tidy_btn.pressed.connect(_on_tidy_desk_pressed)
	_menu_panel.visible = false

	_end_night_btn.pressed.connect(_on_end_night)
	var ledger := get_node_or_null("BarWorkspace/World/Ledger") as ReadableDeskItem
	if ledger != null and not ledger.open_requested.is_connected(_gm.request_open_document):
		ledger.open_requested.connect(_gm.request_open_document)

	_apply_theme()

	_gm.register_view(self)

func _apply_theme() -> void:
	_configure_customer_input_passthrough()
	_configure_topbar_layout()
	_configure_shortcut_bar_layout()

	var bg_tex = TextureManager.try_load("res://assets/textures/tavern/background/tavern_bg.png")
	if bg_tex == null:
		bg_tex = TextureManager.try_load("res://assets/textures/backgrounds/tavern_bg.png")
	if bg_tex != null:
		_bg_sprite.texture = bg_tex
	else:
		var grad = GradientTexture2D.new()
		grad.width = 1280; grad.height = 720
		var g = Gradient.new()
		g.colors = [ThemeColors.BACKGROUND_DEEP, ThemeColors.SURFACE_LOW]
		g.offsets = [0.0, 1.0]
		grad.gradient = g
		_bg_sprite.texture = grad

	ThemeColors.style_brush_label(_customer_name, 18, ThemeColors.TEXT_LIGHT)
	ThemeColors.style_brush_label(_order_bubble, 15, ThemeColors.TEXT_SUBTITLE)
	var patience_icon := get_node_or_null("CustomerArea/PatienceIcon") as TextureRect
	if patience_icon != null:
		patience_icon.texture = TextureManager.try_load("res://assets/textures/ui/icon_patience.png")
		patience_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		patience_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	ThemeColors.style_brush_label(_gold_label, 16, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label(_rep_label, 16, ThemeColors.TEXT_LIGHT)
	ThemeColors.style_brush_label(_day_label, 15, ThemeColors.TEXT_SUBTITLE)

	ThemeColors.style_topbar_button($TopPanel/MenuButton, "menu", 14)
	ThemeColors.style_topbar_button(_end_night_btn, "end_night", 14)

	# 添加教程按钮到菜单
	_add_tutorial_button_to_menu()

	ThemeColors.style_brush_panel(_menu_panel)

	ThemeColors.style_brush_tab_button($OverlayMenu/TabBtns/BtnRecipes)
	ThemeColors.style_brush_tab_button($OverlayMenu/TabBtns/BtnBackpack)
	ThemeColors.style_brush_tab_button($OverlayMenu/TabBtns/BtnSettings)
	ThemeColors.style_brush_button($OverlayMenu/BtnTidy, 14)
	ThemeColors.style_brush_button($OverlayMenu/CloseBtn, 14)

	var recipe_panel = $OverlayMenu/RecipePanel
	var backpack_panel = $OverlayMenu/BackpackPanel
	recipe_panel.visible = true
	backpack_panel.visible = false
	_select_overlay_tab($OverlayMenu/TabBtns/BtnRecipes)
	$OverlayMenu/TabBtns/BtnRecipes.pressed.connect(func(): recipe_panel.visible = true; backpack_panel.visible = false; _select_overlay_tab($OverlayMenu/TabBtns/BtnRecipes))
	# 「背包」改为打开可拖拽的 InventoryOverlay（与 E 键同一个），不再用菜单内的只读列表，避免两个背包混淆。
	$OverlayMenu/TabBtns/BtnBackpack.pressed.connect(toggle_inventory_overlay)

	_gm.inventory_changed.connect(_on_inventory_changed)

	var patience_bg = TextureManager.try_load_style_box("res://assets/textures/ui/bar_patience_bg.png")
	var patience_fill = TextureManager.try_load_style_box("res://assets/textures/ui/bar_patience_fill.png")
	if patience_bg != null:
		_timer_bar.add_theme_stylebox_override("background", patience_bg)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(ThemeColors.SURFACE_HIGH, 0.8)
		sb.border_width_left = 1; sb.border_width_top = 1
		sb.border_width_right = 1; sb.border_width_bottom = 1
		sb.border_color = ThemeColors.PANEL_BORDER
		_timer_bar.add_theme_stylebox_override("background", sb)
	if patience_fill != null:
		_timer_bar.add_theme_stylebox_override("fill", patience_fill)
	_timer_bar.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)

	var top_bar_tex = ThemeColors.instance().bar_top_panel()
	var top_panel_bg = get_node_or_null("TopPanelBg")
	if top_panel_bg != null:
		if top_bar_tex != null:
			top_panel_bg.add_theme_stylebox_override("panel", top_bar_tex)
		else:
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(ThemeColors.BACKGROUND_DEEP, 0.85)
			sb.border_width_bottom = 1
			sb.border_color = ThemeColors.PANEL_BORDER
			top_panel_bg.add_theme_stylebox_override("panel", sb)

	var shortcut_bg = get_node_or_null("ShortcutBarBg")
	if shortcut_bg != null:
		var shortcut_style := ThemeColors.instance().bar_shortcut_bg()
		if shortcut_style != null:
			shortcut_bg.add_theme_stylebox_override("panel", shortcut_style)
		else:
			ThemeColors.style_brush_panel(shortcut_bg)

	_stage_caption.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_stage_caption.add_theme_font_size_override("font_size", 15)


func _configure_customer_input_passthrough() -> void:
	for path in [
		"CustomerArea",
		"CustomerArea/CustomerSprite",
		"CustomerArea/CustomerName",
		"CustomerArea/OrderBubble",
		"CustomerArea/PatienceIcon",
		"CustomerArea/TimerBar",
	]:
		var control := get_node_or_null(path) as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_topbar_layout() -> void:
	var top_panel := $TopPanel as HBoxContainer
	top_panel.add_theme_constant_override("separation", 8)
	var left_inset := _configure_topbar_spacer(top_panel, "TopbarLeftInset", TOPBAR_LEFT_INSET, false)
	var action_spacer := _configure_topbar_spacer(top_panel, "TopbarActionSpacer", Vector2(0, TOPBAR_LABEL_HEIGHT), true)
	var right_inset := _configure_topbar_spacer(top_panel, "TopbarRightInset", TOPBAR_RIGHT_INSET, false)
	top_panel.move_child(left_inset, 0)
	top_panel.move_child(_gold_label, 1)
	top_panel.move_child(_rep_label, 2)
	top_panel.move_child(_day_label, 3)
	top_panel.move_child(action_spacer, 4)
	top_panel.move_child($TopPanel/MenuButton, 5)
	top_panel.move_child(_end_night_btn, 6)
	top_panel.move_child(right_inset, 7)
	_configure_topbar_label(_gold_label, Vector2(220, TOPBAR_LABEL_HEIGHT), HORIZONTAL_ALIGNMENT_CENTER)
	_configure_topbar_label(_rep_label, Vector2(210, TOPBAR_LABEL_HEIGHT), HORIZONTAL_ALIGNMENT_CENTER)
	_configure_topbar_label(_day_label, Vector2(170, TOPBAR_LABEL_HEIGHT), HORIZONTAL_ALIGNMENT_CENTER)


func _configure_topbar_spacer(top_panel: HBoxContainer, spacer_name: String, minimum_size: Vector2, expand: bool) -> Control:
	var spacer := top_panel.get_node_or_null(spacer_name) as Control
	if spacer == null:
		spacer = Control.new()
		spacer.name = spacer_name
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_panel.add_child(spacer)
	spacer.custom_minimum_size = minimum_size
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	spacer.size_flags_vertical = Control.SIZE_FILL
	return spacer


func _configure_topbar_label(label: Label, minimum_size: Vector2, alignment: HorizontalAlignment) -> void:
	label.custom_minimum_size = minimum_size
	label.size_flags_vertical = Control.SIZE_FILL
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_shortcut_bar_layout() -> void:
	var shortcut_bar := get_node_or_null("ShortcutBar") as HBoxContainer
	if shortcut_bar == null:
		return
	shortcut_bar.add_theme_constant_override("separation", SHORTCUT_SEPARATION)
	for slot_index in range(10):
		var slot := shortcut_bar.get_node_or_null("Slot%d" % slot_index) as Control
		if slot == null:
			continue
		slot.custom_minimum_size = SHORTCUT_SLOT_SIZE
		slot.size_flags_horizontal = Control.SIZE_FILL
		slot.size_flags_vertical = Control.SIZE_FILL

func show_customer(customer_name: String, order: String, npc_id: String = "guest") -> void:
	if _customer_dialogue_highlight_active:
		_set_customer_dialogue_highlight(false)
	_current_customer_npc_id = npc_id
	_current_customer_reaction_outcome = ""
	var tex_key: String = _customer_texture_key(npc_id)
	var tex = TextureManager.try_load("res://assets/textures/characters/" + tex_key + ".png")
	if tex != null:
		_customer_sprite.texture = tex
		_customer_sprite.modulate = Color.WHITE
	else:
		var grad = GradientTexture2D.new()
		grad.width = 200; grad.height = 250
		var g = Gradient.new()
		g.colors = [Color(0.35, 0.25, 0.4), Color(0.2, 0.15, 0.25)]
		g.offsets = [0.0, 1.0]
		grad.gradient = g
		_customer_sprite.texture = grad
		_customer_sprite.modulate = Color.WHITE

	_customer_sprite.visible = true
	_customer_name.text = customer_name
	_order_bubble.text = "「来一份" + order + "！」"
	_order_bubble.visible = true
	if _dialogue_overlay != null and _dialogue_overlay.visible:
		_set_customer_dialogue_highlight(true)

func show_customer_reaction(outcome: String, npc_id: String = "") -> void:
	var target_npc_id := npc_id if npc_id != "" else _current_customer_npc_id
	if target_npc_id == "":
		return
	_current_customer_npc_id = target_npc_id
	_current_customer_reaction_outcome = outcome
	_apply_customer_texture_key(_customer_texture_key(target_npc_id, outcome))

func _apply_customer_texture_key(tex_key: String) -> void:
	var tex = TextureManager.try_load("res://assets/textures/characters/" + tex_key + ".png")
	if tex != null:
		_customer_sprite.texture = tex
		_customer_sprite.modulate = Color.WHITE

func _customer_texture_key(npc_id: String, outcome: String = "") -> String:
	if npc_id == "ryan":
		return _ryan_texture_key(outcome)
	if npc_id == "mira":
		return _mira_texture_key(outcome)
	if npc_id.begins_with("regular_"):
		return _regular_customer_texture_key(npc_id, outcome)
	return NPC_TEXTURE_KEYS.get(npc_id, npc_id)

func _regular_customer_texture_key(customer_id: String, outcome: String = "") -> String:
	var state := "neutral"
	if outcome == "success":
		state = "satisfied"
	elif outcome in ["fail_wrong", "fail_weird", "fail", "impatient"]:
		state = "dissatisfied"
	return "%s_%s" % [customer_id, state]

func _ryan_texture_key(outcome: String = "") -> String:
	if outcome in ["fail_wrong", "fail_weird", "fail", "impatient"]:
		return RYAN_TEXTURE_DISSATISFIED
	var story_key := _ryan_story_texture_key()
	if outcome == "success":
		if story_key != RYAN_TEXTURE_NEUTRAL:
			return story_key
		return RYAN_TEXTURE_SATISFIED
	return story_key

func _ryan_story_texture_key() -> String:
	var narrative = null
	if _gm != null:
		narrative = _gm.narrative
	if narrative == null:
		return RYAN_TEXTURE_NEUTRAL
	if bool(narrative.get_var("ryan_drugged")) or bool(narrative.get_var("ryan_alternative_declined")):
		return RYAN_TEXTURE_DISSATISFIED
	var ending := String(narrative.get_var("ryan_ending"))
	if ending != "":
		return RYAN_TEXTURE_SATISFIED if ending == "alternative_survivor" else RYAN_TEXTURE_DISSATISFIED
	if bool(narrative.get_var("ryan_has_alternative")):
		return RYAN_TEXTURE_SATISFIED
	if bool(narrative.get_var("ryan_informed")) or bool(narrative.get_var("ryan_alternative_pending")):
		return RYAN_TEXTURE_HESITANT
	return RYAN_TEXTURE_NEUTRAL

func _mira_texture_key(outcome: String = "") -> String:
	if outcome in ["fail_wrong", "fail_weird", "fail", "impatient"]:
		return MIRA_TEXTURE_SERIOUS

	var current_day := _current_story_day()
	var narrative = _gm.narrative if _gm != null else null
	var told_truth := false
	var ending := ""
	if narrative != null:
		told_truth = bool(narrative.get_var("told_mira_truth"))
		ending = String(narrative.get_var("mira_ending"))

	if outcome == "success":
		if current_day >= 12:
			if ending == "she_finally_stopped":
				return MIRA_TEXTURE_SURPRISED
			if ending == "never_turned_back":
				return MIRA_TEXTURE_SERIOUS
			if ending in ["closed_the_door", "another_light_out"]:
				return MIRA_TEXTURE_SMILE
			return MIRA_TEXTURE_SURPRISED if told_truth else MIRA_TEXTURE_SMILE
		return MIRA_TEXTURE_SMILE

	if current_day >= 12:
		if told_truth and ending == "":
			return MIRA_TEXTURE_SURPRISED
		return MIRA_TEXTURE_SERIOUS
	return MIRA_TEXTURE_NEUTRAL

func _current_story_day() -> int:
	if _gm == null or _gm.economy == null:
		return 0
	return int(_gm.economy.current_day)

func hide_customer() -> void:
	_set_customer_dialogue_highlight(false)
	_current_customer_npc_id = ""
	_current_customer_reaction_outcome = ""
	_customer_sprite.visible = false
	_customer_name.text = "等待中……"
	_order_bubble.visible = false

func update_timer(ratio: float) -> void:
	_timer_bar.value = ratio * 100.0

func update_top_bar(gold: int, rep: int, day: int, max_day: int) -> void:
	_gold_label.text = "金币：" + str(gold)
	_rep_label.text = "声望：" + str(rep)
	_day_label.text = "第%d/%d天" % [day, max_day]


func reset_today_gold() -> void:
	_today_gold = 0


func get_daily_menu_items() -> Array[Dictionary]:
	if daily_menu.is_empty():
		_refresh_default_daily_menu()
	var result: Array[Dictionary] = []
	for key in daily_menu:
		var entry: Dictionary = daily_menu[key]
		if not bool(entry.get("enabled", true)):
			continue
		var item: Dictionary = _gm.craft.get_item(key) if _gm != null and _gm.craft != null else {}
		result.append({
			"key": key,
			"price": int(entry.get("price", item.get("price", 0))),
			"name": String(item.get("name", key)),
		})
	return result


func is_preparation_phase() -> bool:
	return false


func is_business_phase() -> bool:
	return true


func is_menu_config_open() -> bool:
	return false


func _refresh_default_daily_menu() -> void:
	daily_menu.clear()
	daily_menu_confirmed = true
	if _gm == null or _gm.craft == null:
		return
	var products: Array = _gm.craft.get_orderable_products(_gm.economy.current_day)
	for key in products:
		var item: Dictionary = _gm.craft.get_item(key)
		daily_menu[key] = {
			"price": int(item.get("price", 0)),
			"enabled": true,
		}

## 出口①：客人在对话气泡里用自己的口吻反应（台词含「」）。
func customer_say(text: String) -> void:
	_order_bubble.text = text
	_order_bubble.visible = true

## 出口②：舞台提示浮字——第三人称动作描写，淡入→停留→淡出。
func show_stage_caption(text: String, color: Color = Color.WHITE) -> void:
	_stage_caption.text = text
	_stage_caption.add_theme_color_override("font_color", color)
	if _caption_tween != null and _caption_tween.is_valid():
		_caption_tween.kill()
	_stage_caption.modulate.a = 0.0
	_caption_tween = create_tween()
	_caption_tween.tween_property(_stage_caption, "modulate:a", 1.0, 0.3)
	_caption_tween.tween_interval(2.5)
	_caption_tween.tween_property(_stage_caption, "modulate:a", 0.0, 0.5)

## 出口③：打烊按钮可用状态（有客人/pending/上菜停留中时禁用）。
func set_close_enabled(enabled: bool) -> void:
	_end_night_btn.disabled = not enabled

func configure_slice_day(day: int) -> void:
	var bar = get_node_or_null("BarWorkspace")
	if bar != null and bar.has_method("configure_day"):
		bar.configure_day(day)

func set_dialogue_mode(active: bool) -> void:
	_dialogue_overlay.visible = active
	_set_customer_dialogue_highlight(active)


func _set_customer_dialogue_highlight(active: bool) -> void:
	if _customer_sprite == null:
		return
	if active:
		if not _customer_dialogue_highlight_active:
			_customer_sprite_normal_z_index = _customer_sprite.z_index
			_customer_sprite_normal_modulate = _customer_sprite.modulate
		_customer_dialogue_highlight_active = true
		var overlay_z := _dialogue_overlay.z_index if _dialogue_overlay != null else 0
		_customer_sprite.z_index = max(DIALOGUE_SPEAKER_Z_INDEX, overlay_z + 1)
		_customer_sprite.modulate = DIALOGUE_SPEAKER_MODULATE
	else:
		if not _customer_dialogue_highlight_active:
			return
		_customer_sprite.z_index = _customer_sprite_normal_z_index
		_customer_sprite.modulate = _customer_sprite_normal_modulate
		_customer_dialogue_highlight_active = false

func _exit_tree() -> void:
	if _gm != null and _gm.inventory_changed.is_connected(_on_inventory_changed):
		_gm.inventory_changed.disconnect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if not is_instance_valid(self):
		return
	if _menu_panel.visible:
		_build_backpack_list()

func _toggle_menu() -> void:
	toggle_menu()

func toggle_menu() -> void:
	_inventory_overlay.close()
	_document_overlay.close()
	_menu_panel.visible = not _menu_panel.visible
	if _menu_panel.visible:
		_build_recipe_list()
		_build_backpack_list()

func is_menu_open() -> bool:
	return (_menu_panel != null and _menu_panel.visible) \
		or _inventory_overlay.visible \
		or _document_overlay.visible \
		or (_settings_panel != null and _settings_panel.visible)


func _open_settings() -> void:
	_select_overlay_tab($OverlayMenu/TabBtns/BtnSettings)
	_menu_panel.visible = false
	_settings_panel.open()


func _on_settings_closed() -> void:
	_menu_panel.visible = true


func _select_overlay_tab(selected: Button) -> void:
	for tab_button in $OverlayMenu/TabBtns.get_children():
		if tab_button is Button:
			ThemeColors.set_brush_selected(tab_button, tab_button == selected)


func toggle_inventory_overlay() -> void:
	_menu_panel.visible = false
	_document_overlay.close()
	if _inventory_overlay.visible:
		_inventory_overlay.close()
	else:
		_inventory_overlay.open()


func open_document(document: Dictionary) -> void:
	_menu_panel.visible = false
	_inventory_overlay.close()
	_document_overlay.open_document(document)


func open_ledger() -> void:
	_gm.request_open_document("ledger")


func _on_inventory_item_dropped(item_key: String, global_position: Vector2) -> void:
	var bar = get_node_or_null("BarWorkspace")
	if bar != null and bar.has_method("spawn_inventory_item_at"):
		bar.spawn_inventory_item_at(item_key, global_position)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_panel.visible:
		_settings_panel.close()
	elif _document_overlay.visible:
		_document_overlay.close()
	elif _inventory_overlay.visible:
		_inventory_overlay.close()
	else:
		return
	get_viewport().set_input_as_handled()

func _on_end_night() -> void:
	_gm.end_night()

func _add_tutorial_button_to_menu() -> void:
	var tab_btns = $OverlayMenu/TabBtns
	if tab_btns == null:
		return
	if tab_btns.get_node_or_null("BtnTutorial") != null:
		return

	var tutorial_btn = Button.new()
	tutorial_btn.name = "BtnTutorial"
	tutorial_btn.text = "重置教程"
	tutorial_btn.custom_minimum_size = Vector2(96, 30)
	ThemeColors.style_brush_tab_button(tutorial_btn)
	tutorial_btn.pressed.connect(_on_tutorial_btn_pressed)
	tab_btns.add_child(tutorial_btn)


func _on_tutorial_btn_pressed() -> void:
	_reset_tutorial_progress_from_ui()


func _on_tutorial_reset_requested() -> void:
	_reset_tutorial_progress_from_ui()


func _reset_tutorial_progress_from_ui() -> void:
	if _gm == null or not _gm.has_method("reset_tutorial_progress"):
		return
	_gm.reset_tutorial_progress()
	show_stage_caption("教程已重置！下次进入对应场景时将重新显示。", ThemeColors.AMBER_PRIMARY)


func trigger_craft_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	var rects = {
		"BarWorkspace": [820, 480, 280, 200],
		"ShortcutBar": [140, 675, 1000, 40],
	}
	tm.start_tutorial("craft", rects)

## 配方表：按 recipes.json 显示「产物 价格 ← 配料 [容器]」，让玩家能学会怎么做。
## 需购买且未解锁的配方标灰并注明（需解锁）。
func _new_brush_recipe_row() -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 36.0)
	ThemeColors.style_brush_content_panel(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	return {"panel": panel, "row": row}


func _build_recipe_list() -> void:
	_build_split_recipe_list()
	return

	var recipe_list = _menu_panel.get_node("RecipePanel/RecipeList")
	for child in recipe_list.get_children():
		child.queue_free()

	var keys: Array = _gm.craft.recipes.keys()
	keys.sort()
	for product_key in keys:
		var recipe: Dictionary = _gm.craft.recipes[product_key]
		var container: String = recipe.get("container", "")
		var ingredients: Array = recipe.get("ingredients", [])
		if container == "" or ingredients.is_empty():
			continue

		var product_data: Dictionary = _gm.craft.get_item(product_key)
		var locked: bool = bool(recipe.get("requires_purchase", false)) and not _gm.craft.is_recipe_unlocked(product_key)

		var recipe_row := _new_brush_recipe_row()
		var row_panel := recipe_row["panel"] as PanelContainer
		var row := recipe_row["row"] as HBoxContainer

		var icon_tex = _gm.try_load_material_icon(product_key)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)
		else:
			var col_arr = product_data.get("color", [])
			var mat_color = Color.GRAY
			if col_arr is Array and col_arr.size() >= 3:
				mat_color = Color(col_arr[0], col_arr[1], col_arr[2])
			var box = ColorRect.new()
			box.color = mat_color
			box.custom_minimum_size = Vector2(36, 20)
			row.add_child(box)

		var ingr_names := PackedStringArray()
		for ing in ingredients:
			ingr_names.append(String(_gm.craft.get_item(ing).get("name", ing)))
		var container_name: String = CONTAINER_NAMES.get(container, container)
		var product_name: String = product_data.get("name", product_key)
		var price: int = int(product_data.get("price", 0))

		var text: String = "%s  %d金   ← %s  [%s]" % [product_name, price, "＋".join(ingr_names), container_name]
		if locked:
			text += "  （需解锁）"

		var name_label = Label.new()
		name_label.text = " " + text
		ThemeColors.style_brush_label(name_label, 14, Color(0.55, 0.5, 0.45) if locked else ThemeColors.TEXT_LIGHT)
		row.add_child(name_label)

		recipe_list.add_child(row_panel)


func _build_split_recipe_list() -> void:
	var recipe_list := _menu_panel.get_node("RecipePanel/RecipeList") as VBoxContainer
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()

	recipe_list.custom_minimum_size = RECIPE_LAYOUT_MIN_SIZE
	var keys := _recipe_keys_for_container(_recipe_filter_container)
	if keys.is_empty():
		_recipe_filter_container = "barrel"
		keys = _recipe_keys_for_container(_recipe_filter_container)
	if _recipe_selected_product_key == "" or not keys.has(_recipe_selected_product_key):
		_recipe_selected_product_key = keys[0] if not keys.is_empty() else ""

	var layout := HBoxContainer.new()
	layout.name = "RecipeLayout"
	layout.custom_minimum_size = RECIPE_LAYOUT_MIN_SIZE
	layout.add_theme_constant_override("separation", 12)
	recipe_list.add_child(layout)

	var left_column := VBoxContainer.new()
	left_column.name = "LeftColumn"
	left_column.custom_minimum_size = Vector2(RECIPE_LEFT_COLUMN_WIDTH, 0.0)
	left_column.add_theme_constant_override("separation", 8)
	layout.add_child(left_column)

	var tabs := HBoxContainer.new()
	tabs.name = "ContainerTabs"
	tabs.add_theme_constant_override("separation", 6)
	left_column.add_child(tabs)
	for container_key in RECIPE_CONTAINER_ORDER:
		var tab := Button.new()
		tab.name = "Tab_%s" % container_key
		tab.text = String(CONTAINER_NAMES.get(container_key, container_key))
		tab.custom_minimum_size = Vector2(92.0, 34.0)
		tab.set_meta("container_key", container_key)
		ThemeColors.style_brush_tab_button(tab, 13)
		ThemeColors.set_brush_selected(tab, container_key == _recipe_filter_container)
		tab.pressed.connect(_on_recipe_container_tab_pressed.bind(tab))
		tabs.add_child(tab)

	var rows := VBoxContainer.new()
	rows.name = "RecipeRows"
	rows.add_theme_constant_override("separation", 6)
	left_column.add_child(rows)
	for product_key in keys:
		var row := Button.new()
		row.name = "Recipe_%s" % product_key
		row.text = _recipe_row_text(product_key)
		row.custom_minimum_size = Vector2(RECIPE_LEFT_COLUMN_WIDTH, 42.0)
		row.set_meta("product_key", product_key)
		row.set_meta("container_key", _recipe_filter_container)
		ThemeColors.style_brush_button(row, 13)
		ThemeColors.set_brush_selected(row, product_key == _recipe_selected_product_key)
		row.pressed.connect(_on_recipe_row_pressed.bind(product_key))
		rows.add_child(row)

	var detail := PanelContainer.new()
	detail.name = "RecipeDetail"
	detail.custom_minimum_size = Vector2(RECIPE_DETAIL_WIDTH, 0.0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_recipe_panel_art(detail, RECIPE_DETAIL_PANEL_ART, Vector4(14.0, 14.0, 14.0, 14.0))
	layout.add_child(detail)
	_render_recipe_detail(detail, _recipe_selected_product_key)


func _recipe_keys_for_container(container_key: String) -> Array[String]:
	var keys: Array[String] = []
	for product_key in _gm.craft.recipes.keys():
		var recipe: Dictionary = _gm.craft.recipes[product_key]
		if String(recipe.get("container", "")) == container_key and not Array(recipe.get("ingredients", [])).is_empty():
			keys.append(String(product_key))
	keys.sort()
	return keys


func _on_recipe_container_tab_pressed(tab: Button) -> void:
	var container_key := String(tab.get_meta("container_key", ""))
	if container_key == "" or container_key == _recipe_filter_container:
		return
	_recipe_filter_container = container_key
	var keys := _recipe_keys_for_container(_recipe_filter_container)
	_recipe_selected_product_key = keys[0] if not keys.is_empty() else ""
	_build_recipe_list()


func _on_recipe_row_pressed(product_key: String) -> void:
	if product_key == _recipe_selected_product_key:
		return
	_recipe_selected_product_key = product_key
	_build_recipe_list()


func _recipe_row_text(product_key: String) -> String:
	var recipe: Dictionary = _gm.craft.recipes.get(product_key, {})
	var product_data: Dictionary = _gm.craft.get_item(product_key)
	var product_name := String(product_data.get("name", product_key))
	var price := int(product_data.get("price", 0))
	var locked: bool = bool(recipe.get("requires_purchase", false)) and not _gm.craft.is_recipe_unlocked(product_key)
	var status := "需解锁" if locked else "已掌握"
	return "%s  %d金  %s" % [product_name, price, status]


func _render_recipe_detail(detail: PanelContainer, product_key: String) -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()

	var recipe: Dictionary = _gm.craft.recipes.get(product_key, {})
	var container_key := String(recipe.get("container", ""))
	var ingredients: Array = recipe.get("ingredients", [])
	var product_data: Dictionary = _gm.craft.get_item(product_key)
	detail.set_meta("product_key", product_key)
	detail.set_meta("container_key", container_key)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 8)
	detail.add_child(body)

	if product_key == "" or recipe.is_empty():
		body.add_child(_new_recipe_label("Empty", "暂无配方", 14, ThemeColors.TEXT_DIM))
		return

	var header_frame := PanelContainer.new()
	header_frame.name = "HeaderFrame"
	header_frame.custom_minimum_size = Vector2(0.0, 96.0)
	header_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_recipe_panel_art(header_frame, RECIPE_DETAIL_BAND_ART, Vector4(8.0, 7.0, 8.0, 7.0))
	body.add_child(header_frame)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	header_frame.add_child(header)

	var product_slot := _new_recipe_slot_panel("ProductSlot", Vector2(80.0, 80.0))
	var product_slot_center := CenterContainer.new()
	product_slot_center.name = "Center"
	product_slot.add_child(product_slot_center)
	var product_icon := _new_recipe_icon(product_key, product_data, Vector2(60.0, 56.0))
	product_icon.name = "ProductIcon"
	product_slot_center.add_child(product_icon)
	header.add_child(product_slot)

	var title_box := VBoxContainer.new()
	title_box.name = "TitleBox"
	title_box.custom_minimum_size = Vector2(190.0, 0.0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)
	var title_label := _new_recipe_label("Title", String(product_data.get("name", product_key)), 16, ThemeColors.AMBER_PRIMARY)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.custom_minimum_size = Vector2(180.0, 22.0)
	title_box.add_child(title_label)
	title_box.add_child(_new_recipe_label("Meta", "售价 %d金 · %s" % [int(product_data.get("price", 0)), String(CONTAINER_NAMES.get(container_key, container_key))], 12, ThemeColors.TEXT_SUBTITLE))
	title_box.add_child(_new_recipe_label("Status", _recipe_status_text(product_key, recipe), 12, ThemeColors.TEXT_LIGHT))

	body.add_child(_new_recipe_label("IngredientTitle", "材料", 13, ThemeColors.AMBER_PRIMARY))
	var ingredient_grid := GridContainer.new()
	ingredient_grid.name = "IngredientGrid"
	ingredient_grid.columns = 3
	ingredient_grid.add_theme_constant_override("h_separation", 6)
	ingredient_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(ingredient_grid)
	for ingredient in ingredients:
		ingredient_grid.add_child(_new_recipe_ingredient_cell(String(ingredient)))

	body.add_child(_new_recipe_instruction_panel(String(RECIPE_CONTAINER_INSTRUCTIONS.get(container_key, ""))))


func _recipe_status_text(product_key: String, recipe: Dictionary) -> String:
	var locked: bool = bool(recipe.get("requires_purchase", false)) and not _gm.craft.is_recipe_unlocked(product_key)
	if locked:
		return "状态 需商店解锁"
	return "状态 已掌握"


func _new_recipe_label(label_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ThemeColors.style_brush_label(label, font_size, color)
	return label


func _apply_recipe_panel_art(panel: Control, texture_path: String, margins: Vector4) -> void:
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var style := TextureManager.try_load_style_box(texture_path)
	if style == null:
		if panel is PanelContainer:
			ThemeColors.style_brush_content_panel(panel)
		return
	style.set_texture_margin(SIDE_LEFT, margins.x)
	style.set_texture_margin(SIDE_TOP, margins.y)
	style.set_texture_margin(SIDE_RIGHT, margins.z)
	style.set_texture_margin(SIDE_BOTTOM, margins.w)
	style.set_content_margin(SIDE_LEFT, margins.x)
	style.set_content_margin(SIDE_TOP, margins.y)
	style.set_content_margin(SIDE_RIGHT, margins.z)
	style.set_content_margin(SIDE_BOTTOM, margins.w)
	panel.add_theme_stylebox_override("panel", style)


func _new_recipe_slot_panel(panel_name: String, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_recipe_panel_art(panel, RECIPE_SLOT_ART, Vector4(4.0, 4.0, 4.0, 4.0))
	return panel


func _new_recipe_instruction_panel(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "InstructionPanel"
	_apply_recipe_panel_art(panel, RECIPE_DETAIL_BAND_ART, Vector4(10.0, 6.0, 10.0, 6.0))
	var label := _new_recipe_label("Instruction", text, 12, ThemeColors.TEXT_LIGHT)
	panel.add_child(label)
	return panel


func _new_recipe_icon(item_key: String, item_data: Dictionary, size: Vector2) -> Control:
	var icon_tex = _gm.try_load_material_icon(item_key)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return icon

	var swatch := ColorRect.new()
	var rgb: Array = item_data.get("color", [0.55, 0.5, 0.45])
	swatch.color = Color(rgb[0], rgb[1], rgb[2])
	swatch.custom_minimum_size = size
	return swatch


func _new_recipe_ingredient_cell(item_key: String) -> PanelContainer:
	var item_data: Dictionary = _gm.craft.get_item(item_key)
	var cell := _new_recipe_slot_panel("Ingredient_%s" % item_key, Vector2(88.0, 80.0))
	cell.set_meta("item_key", item_key)

	var box := VBoxContainer.new()
	box.name = "Body"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	cell.add_child(box)

	var icon := _new_recipe_icon(item_key, item_data, Vector2(32.0, 30.0))
	icon.name = "Icon"
	box.add_child(icon)

	var label := _new_recipe_label("Name", String(item_data.get("name", item_key)), 10, ThemeColors.TEXT_LIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(72.0, 24.0)
	box.add_child(label)
	return cell


func _build_backpack_list() -> void:
	var inventory: Dictionary = _gm.inventory
	var backpack_list = _menu_panel.get_node("BackpackPanel/BackpackList")
	for child in backpack_list.get_children():
		child.queue_free()

	for mat in inventory:
		var count: int = inventory[mat]
		if count <= 0:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size = Vector2(0, 32)
		row.set_meta("material_key", mat)

		var icon_tex = _gm.try_load_material_icon(mat)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)
		else:
			var mat_item: Dictionary = _gm.craft.get_item(mat)
			var col_arr = mat_item.get("color", [])
			var mat_color = Color.GRAY
			if col_arr is Array and col_arr.size() >= 3:
				mat_color = Color(col_arr[0], col_arr[1], col_arr[2])
			var box = ColorRect.new()
			box.color = mat_color
			box.custom_minimum_size = Vector2(36, 20)
			row.add_child(box)

		var mat_item2: Dictionary = _gm.craft.get_item(mat)
		var display_name = mat_item2.get("name", mat)
		var label = Label.new()
		label.text = display_name + "  x" + str(count)
		label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)

		backpack_list.add_child(row)


func _on_tidy_desk_pressed() -> void:
	var bar = get_node_or_null("BarWorkspace")
	if bar != null and bar.has_method("tidy_desk"):
		bar.tidy_desk()
	if has_method("toggle_menu"):
		toggle_menu()
