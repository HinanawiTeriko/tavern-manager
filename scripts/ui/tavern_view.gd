class_name TavernView
extends Node2D

enum Phase { PREPARATION, BUSINESS }

var _phase: Phase = Phase.PREPARATION
var _bg_sprite: Sprite2D
var _customer_sprite: Sprite2D
var _customer_name: Label
var _order_bubble: Label
var _timer_bar: ProgressBar
var _revenue_label: Label
var _day_label: Label
var _menu_panel: Panel
var _end_night_btn: Button
var _ledger_btn: Button
var _menu_config_btn: Button
var _option_btn: Button
var _stage_caption: Label
var _caption_tween: Tween
var _dialogue_dim: Sprite2D
var _desk_overlay: Sprite2D
var _revenue_panel: Panel
var _inventory_overlay: InventoryOverlay
var _document_overlay: DocumentOverlay
var _settings_panel: SettingsPanel
var _menu_config_panel: Panel
var _cyclopedia_panel: Control
var _gm
var _today_gold: int = 0
var _inventory_opened_from_menu: bool = false

## 当日菜单配置: {product_key: {"price": int, "enabled": bool}}
var daily_menu: Dictionary = {}
var daily_menu_confirmed: bool = false

const CONTAINER_NAMES: Dictionary = {"barrel": "酒桶", "grill": "烤架", "pot": "炖锅"}

const NPC_TEXTURE_KEYS: Dictionary = {
	"ryan": "ryan_neutral",
	"mira": "mira_neutral",
}
const TOPBAR_LEFT_INSET := Vector2(28, 48)
const TOPBAR_RIGHT_INSET := Vector2(28, 48)
const TOPBAR_LABEL_HEIGHT := 48.0
const SHORTCUT_SLOT_SIZE := Vector2(96, 40)
const SHORTCUT_SEPARATION := 4

## 食物属性名（魔幻化名称）
const ATTRIBUTE_NAMES: Dictionary = {
	"might": "蛮勇之力",
	"alacrity": "疾风之敏",
	"fortune": "命运眷顾",
	"arcana": "奥术灵韵",
	"vitality": "磐石之躯",
	"charm": "魅惑之息",
}

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_bg_sprite = $Background
	_customer_sprite = $CustomerNode/CustomerSprite
	_customer_name = $CustomerName
	_order_bubble = $OrderBubble
	_timer_bar = $TimerBar
	_revenue_label = $RightArea/RevenuePanel/RevenueLabel
	_ledger_btn = $RightArea/LedgerBtn
	_menu_config_btn = $RightArea/MenuConfigBtn
	_option_btn = $RightArea/OptionButton
	_day_label = $DayLabel
	_end_night_btn = $RightArea/EndNightBtn
	_stage_caption = $StageCaption
	_dialogue_dim = $DialogueDim
	_desk_overlay = $DeskOverlay
	_revenue_panel = $RightArea/RevenuePanel
	_inventory_overlay = $InventoryOverlay
	_inventory_overlay.configure(_gm)
	_inventory_overlay.item_dropped.connect(_on_inventory_item_dropped)
	_inventory_overlay.closed.connect(_on_inventory_closed)
	_document_overlay = $DocumentOverlay
	_settings_panel = $SettingsPanel
	_settings_panel.configure(_gm.settings)
	_settings_panel.closed.connect(_on_settings_closed)

	_menu_panel = $OverlayMenu
	_option_btn.pressed.connect(_toggle_menu)
	_menu_config_btn.pressed.connect(_toggle_menu_config)
	$OverlayMenu/CloseBtn.pressed.connect(_toggle_menu)
	$OverlayMenu/TabBtns/BtnSettings.pressed.connect(_open_settings)
	var tidy_btn = $OverlayMenu/BtnTidy
	if tidy_btn != null and not tidy_btn.pressed.is_connected(_on_tidy_desk_pressed):
		tidy_btn.pressed.connect(_on_tidy_desk_pressed)
	_menu_panel.visible = false

	_end_night_btn.pressed.connect(_on_end_night)
	_ledger_btn.pressed.connect(open_ledger)

	_create_menu_config_panel()
	_create_encyclopedia_panel()

	_apply_theme()

	# 进入准备阶段
	_enter_preparation_phase()
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
	ThemeColors.style_brush_tab_button($OverlayMenu/TabBtns/BtnEncyclopedia)
	ThemeColors.style_brush_button($OverlayMenu/BtnTidy, 14)
	ThemeColors.style_brush_button($OverlayMenu/CloseBtn, 14)

	var recipe_panel = $OverlayMenu/RecipePanel
	var backpack_panel = $OverlayMenu/BackpackPanel
	recipe_panel.visible = true
	backpack_panel.visible = false
	_cyclopedia_panel.visible = false
	_select_overlay_tab($OverlayMenu/TabBtns/BtnRecipes)
	$OverlayMenu/TabBtns/BtnRecipes.pressed.connect(func(): recipe_panel.visible = true; backpack_panel.visible = false; _cyclopedia_panel.visible = false; _select_overlay_tab($OverlayMenu/TabBtns/BtnRecipes))
	# 「背包」改为打开可拖拽的 InventoryOverlay（与 E 键同一个），不再用菜单内的只读列表，避免两个背包混淆。
	$OverlayMenu/TabBtns/BtnBackpack.pressed.connect(toggle_inventory_overlay)
	# 图鉴选项卡
	$OverlayMenu/TabBtns/BtnEncyclopedia.pressed.connect(func(): recipe_panel.visible = false; backpack_panel.visible = false; _cyclopedia_panel.visible = true; _select_overlay_tab($OverlayMenu/TabBtns/BtnEncyclopedia))

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
	var tex_key: String = NPC_TEXTURE_KEYS.get(npc_id, npc_id)
	var tex = TextureManager.try_load("res://assets/textures/characters/" + tex_key + ".png")
	if tex != null:
		_customer_sprite.texture = tex
		_customer_sprite.scale = Vector2(1.0, 1.0)
		# 200×250 半身像, 左侧, 吧台后方.
		# 画面 1280x720, 桌面遮罩 y=410 起. 角色腰部在 y≈350, 上半身完整露出.
		_customer_sprite.position = Vector2(60, 100)
		_customer_sprite.modulate = Color.WHITE
	else:
		_customer_sprite.texture = _make_placeholder_texture(200, 250, Color(0.35, 0.25, 0.4), Color(0.2, 0.15, 0.25))
		_customer_sprite.scale = Vector2(1.0, 1.0)
		_customer_sprite.position = Vector2(60, 100)
		_customer_sprite.modulate = Color.WHITE

	_customer_sprite.visible = true
	_customer_name.text = customer_name
	_order_bubble.text = "「来一份" + order + "！」"
	_order_bubble.visible = true

func _make_placeholder_texture(width: int, height: int, color1: Color, color2: Color) -> GradientTexture2D:
	var grad = GradientTexture2D.new()
	grad.width = width; grad.height = height
	var g = Gradient.new()
	g.colors = [color1, color2]
	g.offsets = [0.0, 1.0]
	grad.gradient = g
	return grad

func hide_customer() -> void:
	_customer_sprite.visible = false
	_customer_name.text = "等待中……"
	_order_bubble.visible = false

func update_timer(ratio: float) -> void:
	_timer_bar.value = ratio * 100.0

func update_top_bar(gold: int, rep: int, day: int, max_day: int) -> void:
	_day_label.text = "第%d/%d天" % [day, max_day]
	_revenue_label.text = "今日+%d金 | 共%d金 | ★%d" % [_today_gold, gold, rep]

## 更新今日收入（供 GameManager 在上菜后调用）
func add_today_gold(amount: int) -> void:
	_today_gold += amount
	# 同步更新收入面板单行文本
	var total_gold = _gm.economy.gold if _gm != null else 0
	var rep = _gm.economy.reputation if _gm != null else 0
	_revenue_label.text = "今日+%d金 | 共%d金 | ★%d" % [_today_gold, total_gold, rep]

## 重置每日收入（新的一天开始）
func reset_today_gold() -> void:
	_today_gold = 0
	_revenue_label.text = "今日+0金 | 共%d金 | ★%d" % [_gm.economy.gold if _gm != null else 0, _gm.economy.reputation if _gm != null else 0]

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
	_dialogue_dim.visible = active

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
		_build_encyclopedia()
		# 默认显示配方选项卡
		$OverlayMenu/RecipePanel.visible = true
		$OverlayMenu/BackpackPanel.visible = false
		_cyclopedia_panel.visible = false
		_select_overlay_tab($OverlayMenu/TabBtns/BtnRecipes)

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


func _on_inventory_closed() -> void:
	if _inventory_opened_from_menu:
		_menu_panel.visible = true
	_inventory_opened_from_menu = false


func _select_overlay_tab(selected: Button) -> void:
	for tab_button in $OverlayMenu/TabBtns.get_children():
		if tab_button is Button:
			ThemeColors.set_brush_selected(tab_button, tab_button == selected)


func toggle_inventory_overlay() -> void:
	_document_overlay.close()
	if _inventory_overlay.visible:
		_inventory_overlay.close()
	else:
		_inventory_opened_from_menu = _menu_panel.visible
		_menu_panel.visible = false
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
		if _inventory_opened_from_menu:
			_menu_panel.visible = true
		_inventory_opened_from_menu = false
	else:
		return
	get_viewport().set_input_as_handled()

func _on_end_night() -> void:
	_gm.end_night()

func _add_tutorial_button_to_menu() -> void:
	var tab_btns = $OverlayMenu/TabBtns
	if tab_btns == null:
		return

	var tutorial_btn = Button.new()
	tutorial_btn.name = "BtnTutorial"
	tutorial_btn.text = "教程"
	tutorial_btn.custom_minimum_size = Vector2(60, 30)
	ThemeColors.style_brush_tab_button(tutorial_btn)
	tutorial_btn.pressed.connect(_on_tutorial_btn_pressed)
	tab_btns.add_child(tutorial_btn)


func _on_tutorial_btn_pressed() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	# 检查是否所有教程都已完成
	if tm.is_group_completed("gather") and tm.is_group_completed("shop") and \
	   tm.is_group_completed("craft") and tm.is_group_completed("seasoning") and \
	   tm.is_group_completed("serve") and tm.is_group_completed("ledger"):
		# 全部完成，点击重新开始
		tm.replay_all()
		show_stage_caption("教程已重置！下次进入对应场景时将重新显示。", ThemeColors.AMBER_PRIMARY)
	else:
		# 还有未完成的教程，重新开始全部
		tm.replay_all()
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

## ── 准备阶段 ──

func _enter_preparation_phase() -> void:
	_phase = Phase.PREPARATION
	daily_menu_confirmed = false
	# 初始化当日菜单：从可点单产品中，默认启用基础产品
	var products: Array = _gm.craft.get_orderable_products(_gm.economy.current_day)
	for key in products:
		var item: Dictionary = _gm.craft.get_item(key)
		daily_menu[key] = {"price": int(item.get("price", 0)), "enabled": false}
	# 默认启用前3项（至少3项要求）
	var default_enabled = products.slice(0, min(3, products.size()))
	for key in default_enabled:
		daily_menu[key]["enabled"] = true
	set_close_enabled(false)
	show_stage_caption("准备阶段 — 点击右上角「菜单」配置当日菜品", ThemeColors.AMBER_PRIMARY)
	_refresh_menu_config_panel()
	# 教程进行时不自动弹出菜单面板
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null or not tm._is_active:
		_toggle_menu_config()

func _confirm_menu() -> void:
	var enabled_count := 0
	for key in daily_menu:
		if daily_menu[key].get("enabled", false):
			enabled_count += 1
	if enabled_count < 3:
		show_stage_caption("至少需要选择3道菜品！", Color.ORANGE_RED)
		return
	daily_menu_confirmed = true
	_phase = Phase.BUSINESS
	_menu_config_panel.visible = false
	show_stage_caption("菜单已确认，准备迎接客人！", ThemeColors.AMBER_PRIMARY)
	set_close_enabled(not _gm.guests.has_guest)
	# 通知 GuestSystem 配置完毕，可以开始刷客人
	if _gm != null and _gm.guests != null:
		_gm.guests.configure_night(_gm.ryan_slice.normal_order_limit(_gm.economy.current_day), _gm.economy.current_day)
	# 通知 GM 准备阶段结束，可以生成重要NPC
	if _gm != null and _gm.has_method("on_menu_confirmed"):
		_gm.call_deferred("on_menu_confirmed")

func _toggle_menu_config() -> void:
	_menu_panel.visible = false
	_inventory_overlay.close()
	_document_overlay.close()
	_menu_config_panel.visible = not _menu_config_panel.visible
	if _menu_config_panel.visible:
		_refresh_menu_config_panel()

func _refresh_menu_config_panel() -> void:
	if _menu_config_panel == null:
		return
	var list: VBoxContainer = _menu_config_panel.get_node_or_null("Scroll/ProductList")
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()

	# 标题
	var status_label: Label = _menu_config_panel.get_node_or_null("StatusLabel")
	if status_label != null:
		var count := 0
		for key in daily_menu:
			if daily_menu[key].get("enabled", false):
				count += 1
		status_label.text = "已选 %d 道菜品（至少3项）" % count

	var products: Array = _gm.craft.get_orderable_products(_gm.economy.current_day)
	for product_key in products:
		var item: Dictionary = _gm.craft.get_item(product_key)
		var product_name: String = item.get("name", product_key)
		var base_price: int = int(item.get("price", 0))
		var menu_entry: Dictionary = daily_menu.get(product_key, {"price": base_price, "enabled": false})

		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 38)
		ThemeColors.style_brush_content_panel(row)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var cb := CheckBox.new()
		cb.text = product_name
		cb.button_pressed = menu_entry.get("enabled", false)
		cb.custom_minimum_size = Vector2(280, 0)
		var cb_key = product_key
		cb.pressed.connect(func():
			daily_menu[cb_key]["enabled"] = cb.button_pressed
			_refresh_menu_config_panel()
		)
		hbox.add_child(cb)

		var price_label := Label.new()
		price_label.text = "基础价 %d金" % base_price
		price_label.custom_minimum_size = Vector2(100, 0)

		var price_spin := SpinBox.new()
		price_spin.min_value = 1
		price_spin.max_value = 99
		price_spin.value = menu_entry.get("price", base_price)
		price_spin.custom_minimum_size = Vector2(70, 0)
		var pk_price = product_key
		price_spin.value_changed.connect(func(v: float):
			daily_menu[pk_price]["price"] = int(v)
		)
		price_spin.editable = true

		hbox.add_child(price_label)
		hbox.add_child(price_spin)

		list.add_child(row)

func _create_menu_config_panel() -> void:
	_menu_config_panel = Panel.new()
	_menu_config_panel.name = "MenuConfigPanel"
	_menu_config_panel.visible = false
	_menu_config_panel.layout_mode = 0
	_menu_config_panel.offset_left = 290.0
	_menu_config_panel.offset_top = 80.0
	_menu_config_panel.offset_right = 990.0
	_menu_config_panel.offset_bottom = 620.0
	_menu_config_panel.z_index = 200
	add_child(_menu_config_panel)

	ThemeColors.style_brush_panel(_menu_config_panel)

	# 标题
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "当日菜单配置"
	title.layout_mode = 0
	title.offset_left = 20; title.offset_top = 12
	title.offset_right = 680; title.offset_bottom = 40
	title.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 20)
	_menu_config_panel.add_child(title)

	# 状态提示
	var status := Label.new()
	status.name = "StatusLabel"
	status.text = "已选 0 道菜品（至少3项）"
	status.layout_mode = 0
	status.offset_left = 20; status.offset_top = 42
	status.offset_right = 680; status.offset_bottom = 64
	status.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	status.add_theme_font_size_override("font_size", 14)
	_menu_config_panel.add_child(status)

	# 滚动列表
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.layout_mode = 0
	scroll.offset_left = 20; scroll.offset_top = 72
	scroll.offset_right = 680; scroll.offset_bottom = 470
	_menu_config_panel.add_child(scroll)

	var product_list := VBoxContainer.new()
	product_list.name = "ProductList"
	product_list.layout_mode = 0
	scroll.add_child(product_list)

	# 提示文字
	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "勾选菜品并设定售价，至少选择3项。已解锁的配方产物均可选择。"
	hint.layout_mode = 0
	hint.offset_left = 20; hint.offset_top = 478
	hint.offset_right = 680; hint.offset_bottom = 500
	hint.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	hint.add_theme_font_size_override("font_size", 12)
	_menu_config_panel.add_child(hint)

	# 确认按钮
	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmBtn"
	confirm_btn.text = "确认菜单"
	confirm_btn.layout_mode = 0
	confirm_btn.offset_left = 280; confirm_btn.offset_top = 505
	confirm_btn.offset_right = 420; confirm_btn.offset_bottom = 540
	confirm_btn.pressed.connect(_confirm_menu)
	_menu_config_panel.add_child(confirm_btn)
	ThemeColors.style_button(confirm_btn, 16)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "关闭"
	close_btn.layout_mode = 0
	close_btn.offset_left = 430; close_btn.offset_top = 505
	close_btn.offset_right = 570; close_btn.offset_bottom = 540
	close_btn.pressed.connect(_toggle_menu_config)
	_menu_config_panel.add_child(close_btn)
	ThemeColors.style_button(close_btn, 16)

## ── 图鉴面板 ──

func _create_encyclopedia_panel() -> void:
	_cyclopedia_panel = Control.new()
	_cyclopedia_panel.name = "EncyclopediaPanel"
	_cyclopedia_panel.visible = false
	_cyclopedia_panel.layout_mode = 0
	_cyclopedia_panel.offset_left = 10; _cyclopedia_panel.offset_top = 60
	_cyclopedia_panel.offset_right = 690; _cyclopedia_panel.offset_bottom = 440
	# 添加到 OverlayMenu 下
	var menu = $OverlayMenu
	menu.add_child(_cyclopedia_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "EncycScroll"
	scroll.layout_mode = 0
	scroll.offset_left = 0; scroll.offset_top = 0
	scroll.offset_right = 680; scroll.offset_bottom = 370
	_cyclopedia_panel.add_child(scroll)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "EncycContent"
	main_vbox.layout_mode = 0
	scroll.add_child(main_vbox)

func _build_encyclopedia() -> void:
	var content: VBoxContainer = _cyclopedia_panel.get_node_or_null("EncycScroll/EncycContent")
	if content == null:
		return
	for child in content.get_children():
		child.queue_free()

	# === 食品图鉴 ===
	var food_header := Label.new()
	food_header.text = "— 食品图鉴 —"
	food_header.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	food_header.add_theme_font_size_override("font_size", 18)
	content.add_child(food_header)

	content.add_child(_make_spacer(4))

	# 加载属性数据
	var attr_data: Dictionary = _load_food_attributes()

	var product_keys: Array = []
	for key in _gm.craft.items:
		var item: Dictionary = _gm.craft.items[key]
		if item.get("type", "") == "product":
			product_keys.append(key)
	product_keys.sort()

	for product_key in product_keys:
		var item: Dictionary = _gm.craft.get_item(product_key)
		var attrs: Dictionary = attr_data.get(product_key, {})
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 32)
		ThemeColors.style_brush_content_panel(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row_panel.add_child(row)

		var icon_tex = _gm.try_load_material_icon(product_key)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(24, 24)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)

		var name_label := Label.new()
		name_label.text = " %s  %d金" % [item.get("name", product_key), int(item.get("price", 0))]
		name_label.custom_minimum_size = Vector2(180, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)

		# 属性标签
		if attrs.is_empty():
			var none_l := Label.new()
			none_l.text = "（无特殊属性）"
			none_l.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
			none_l.add_theme_font_size_override("font_size", 12)
			row.add_child(none_l)
		else:
			for attr_key in attrs:
				var val: int = int(attrs[attr_key])
				var attr_name: String = ATTRIBUTE_NAMES.get(attr_key, attr_key)
				var sign := "+" if val >= 0 else ""
				var al := Label.new()
				al.text = "%s%s%d" % [attr_name, sign, val]
				al.add_theme_color_override("font_color", _attribute_color(attr_key))
				al.add_theme_font_size_override("font_size", 12)
				row.add_child(al)

		content.add_child(row_panel)

	content.add_child(_make_spacer(8))

	# === 剧情道具 ===
	var story_header := Label.new()
	story_header.text = "— 剧情道具 —"
	story_header.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	story_header.add_theme_font_size_override("font_size", 18)
	content.add_child(story_header)

	content.add_child(_make_spacer(4))

	# 遍历已获得的文档/剧情道具（排除"账本"）
	var doc_sys = _gm.documents if _gm != null else null
	if doc_sys != null and doc_sys.has_method("get_owned_documents"):
		for doc_id in doc_sys.get_owned_documents():
			if doc_id == "ledger":
				continue  # 账本不显示在图鉴中
			var doc: Dictionary = doc_sys.get_document(doc_id)
			if doc.is_empty():
				continue
			var dp := PanelContainer.new()
			dp.custom_minimum_size = Vector2(0, 32)
			ThemeColors.style_brush_content_panel(dp)
			var dh := HBoxContainer.new()
			dp.add_child(dh)

			var dn := Label.new()
			dn.text = " %s" % doc.get("title", doc_id)
			dn.custom_minimum_size = Vector2(200, 0)
			dn.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
			dn.add_theme_font_size_override("font_size", 14)
			dh.add_child(dn)

			var dd := Label.new()
			dd.text = doc.get("description", "")
			dd.custom_minimum_size = Vector2(420, 0)
			dd.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
			dd.add_theme_font_size_override("font_size", 12)
			dh.add_child(dd)

			content.add_child(dp)

func _make_spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _attribute_color(attr_key: String) -> Color:
	match attr_key:
		"might": return Color(0.95, 0.3, 0.2)      # 红
		"alacrity": return Color(0.2, 0.7, 0.4)   # 绿
		"fortune": return Color(0.95, 0.85, 0.1)   # 金
		"arcana": return Color(0.5, 0.3, 0.9)      # 紫
		"vitality": return Color(0.3, 0.5, 0.8)    # 蓝
		"charm": return Color(0.95, 0.45, 0.65)    # 粉
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

## 获取当日菜单（供 GuestSystem 点单）: Array[{key, price, name}]
func get_daily_menu_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in daily_menu:
		var entry: Dictionary = daily_menu[key]
		if entry.get("enabled", false):
			var item: Dictionary = _gm.craft.get_item(key)
			result.append({
				"key": key,
				"price": int(entry.get("price", item.get("price", 0))),
				"name": item.get("name", key),
			})
	return result

## 当前阶段
func is_preparation_phase() -> bool:
	return _phase == Phase.PREPARATION

func is_business_phase() -> bool:
	return _phase == Phase.BUSINESS

## 菜单面板是否开启（用于暂停顾客生成）
func is_menu_config_open() -> bool:
	return _menu_config_panel != null and _menu_config_panel.visible
