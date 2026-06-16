class_name TavernView
extends Node2D

var _bg_sprite: Sprite2D
var _customer_sprite: TextureRect
var _customer_name: Label
var _order_bubble: Label
var _reaction_bubble: Label
var _timer_bar: ProgressBar
var _patience_fill_clip: Control
var _patience_fill_art: TextureRect
var _gold_label: Label
var _rep_label: Label
var _day_label: Label
var _gold_progress: Control
var _gold_progress_fill_clip: Control
var _gold_progress_fill_art: TextureRect
var _gold_progress_ornate: TextureRect
var _rep_progress: Control
var _rep_progress_fill_clip: Control
var _rep_progress_fill_art: TextureRect
var _rep_progress_ornate: TextureRect
var _reward_layer: CanvasLayer
var _reward_particles: Node2D
var _reward_coin_layer: Node2D
var _reward_coin_texture: Texture2D
var _reward_rep_texture: Texture2D
var _reward_spark_texture: Texture2D
var _pending_reward_coin_bodies: Array[RigidBody2D] = []
var _displayed_gold_total: int = 0
var _displayed_gold_progress_total: int = 0
var _displayed_rep_total: int = 0
var _deferred_gold_total: int = -1
var _deferred_gold_previous_total: int = -1
var _deferred_gold_progress_total: int = -1
var _deferred_gold_previous_progress_total: int = -1
var _gold_collection_apply_scheduled: bool = false
var _menu_panel: Panel
var _end_night_btn: Button
var _stage_caption: Label
var _caption_tween: Tween
var _inference_ready_notice: Label
var _inference_ready_notice_tween: Tween
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
var _current_order_text: String = ""
var _current_order_status_text: String = ""
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
const RYAN_TEXTURE_CONFIDENT := "ryan_confident"
const RYAN_TEXTURE_HESITANT := "ryan_hesitant"
const RYAN_TEXTURE_ALARMED := "ryan_alarmed"
const RYAN_TEXTURE_RESOLVED := "ryan_resolved"
const RYAN_TEXTURE_RELIEVED := "ryan_relieved"
const RYAN_TEXTURE_WARY := "ryan_wary"
const RYAN_TEXTURE_BROKEN := "ryan_broken"
const MIRA_TEXTURE_NEUTRAL := "mira_neutral"
const MIRA_TEXTURE_SMILE := "mira_smile"
const MIRA_TEXTURE_SURPRISED := "mira_surprised"
const MIRA_TEXTURE_SERIOUS := "mira_serious"
const MIRA_TEXTURE_GUILTY := "mira_guilty"
const MIRA_TEXTURE_CONFLICTED := "mira_conflicted"
const MIRA_TEXTURE_RESOLVED := "mira_resolved"
const MIRA_TEXTURE_DETACHED := "mira_detached"
const TOBY_TEXTURE_NEUTRAL := "toby_neutral"
const TOBY_TEXTURE_WARMED := "toby_warmed"
const TOBY_TEXTURE_HURT := "toby_hurt"
const TOBY_TEXTURE_AFRAID := "toby_afraid"
const GREY_LEDGER_LADY_TEXTURE_NEUTRAL := "grey_ledger_lady_neutral"
const GREY_LEDGER_LADY_TEXTURE_SMILE := "grey_ledger_lady_smile"
const GREY_LEDGER_LADY_TEXTURE_ASSESSING := "grey_ledger_lady_assessing"
const GREY_LEDGER_LADY_TEXTURE_CRACKED := "grey_ledger_lady_cracked"
const TOPBAR_LEFT_INSET := Vector2(28, 48)
const TOPBAR_RIGHT_INSET := Vector2(28, 48)
const TOPBAR_LABEL_HEIGHT := 48.0
const REWARD_PROGRESS_SIZE := Vector2(192.0, 48.0)
const REWARD_PROGRESS_FILL_INSET := Vector2(24.0, 12.0)
const REWARD_PROGRESS_FILL_SIZE := Vector2(144.0, 24.0)
const REWARD_REP_PROGRESS_ART_OFFSET := Vector2(0.0, 4.0)
const REWARD_COIN_COLLISION_LAYER := 524288
const REWARD_TRAVEL_SECONDS := 0.68
const GOLD_PROGRESS_THRESHOLDS := [0, 50, 100, 200, 400]
const REP_PROGRESS_THRESHOLDS := [0, 50, 150]
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
	_reaction_bubble = $CustomerArea/ReactionBubble
	_timer_bar = $CustomerArea/TimerBar
	_patience_fill_clip = $CustomerArea/PatienceFillClip
	_patience_fill_art = $CustomerArea/PatienceFillClip/PatienceFillArt
	_gold_label = $TopPanel/GoldLabel
	_rep_label = $TopPanel/ReputationLabel
	_day_label = $TopPanel/DayLabel
	_gold_progress = $TopPanel/GoldProgress
	_gold_progress_fill_clip = $TopPanel/GoldProgress/FillClip
	_gold_progress_fill_art = $TopPanel/GoldProgress/FillClip/Fill
	_gold_progress_ornate = $TopPanel/GoldProgress/Ornate
	_rep_progress = $TopPanel/ReputationProgress
	_rep_progress_fill_clip = $TopPanel/ReputationProgress/FillClip
	_rep_progress_fill_art = $TopPanel/ReputationProgress/FillClip/Fill
	_rep_progress_ornate = $TopPanel/ReputationProgress/Ornate
	_reward_layer = $RewardFeedbackLayer
	_reward_particles = $RewardFeedbackLayer/Particles
	_reward_coin_layer = $RewardCoinPhysicsLayer
	_end_night_btn = $TopPanel/EndNightBtn
	_stage_caption = $StageCaption
	_inference_ready_notice = get_node_or_null("InferenceReadyNotice") as Label
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
	_refresh_ledger_hint()

	_apply_theme()

	_gm.register_view(self)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		if _dialogue_overlay != null and _dialogue_overlay.visible:
			return
		_collect_pending_reward_coins()

func _apply_theme() -> void:
	_configure_customer_input_passthrough()
	_configure_topbar_layout()
	_configure_shortcut_bar_layout()
	_configure_reward_hud()

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
	ThemeColors.style_brush_label(_order_bubble, 18, ThemeColors.TEXT_LIGHT)
	_order_bubble.add_theme_constant_override("outline_size", 3)
	_order_bubble.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02, 0.95))
	_order_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_order_bubble.clip_text = true
	_order_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ThemeColors.style_brush_label(_reaction_bubble, 16, ThemeColors.AMBER_PRIMARY)
	_reaction_bubble.add_theme_constant_override("outline_size", 3)
	_reaction_bubble.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01, 0.95))
	_reaction_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reaction_bubble.clip_text = true
	_reaction_bubble.visible = false
	var patience_icon := get_node_or_null("CustomerArea/PatienceIcon") as TextureRect
	if patience_icon != null:
		patience_icon.texture = TextureManager.try_load("res://assets/textures/ui/icon_patience.png")
		patience_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		patience_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _patience_fill_clip != null:
		_patience_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_patience_fill_clip.clip_contents = true
	if _patience_fill_art != null:
		_patience_fill_art.texture = TextureManager.try_load("res://assets/textures/ui/bar_patience_groove_fill.png")
		_patience_fill_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_patience_fill_art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	ThemeColors.style_brush_label(_gold_label, 16, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label(_rep_label, 16, ThemeColors.TEXT_LIGHT)
	ThemeColors.style_brush_label(_day_label, 15, ThemeColors.TEXT_SUBTITLE)

	ThemeColors.style_topbar_button($TopPanel/MenuButton, "menu", 14)
	ThemeColors.style_topbar_button(_end_night_btn, "end_night", 14)

	# 娣诲姞鏁欑▼鎸夐挳鍒拌彍鍗?
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
	# 銆岃儗鍖呫€嶆敼涓烘墦寮€鍙嫋鎷界殑 InventoryOverlay锛堜笌 E 閿悓涓€涓級锛屼笉鍐嶇敤鑿滃崟鍐呯殑鍙鍒楄〃锛岄伩鍏嶄袱涓儗鍖呮贩娣嗐€?
	$OverlayMenu/TabBtns/BtnBackpack.pressed.connect(toggle_inventory_overlay)

	_gm.inventory_changed.connect(_on_inventory_changed)

	var patience_bg = TextureManager.try_load_style_box("res://assets/textures/ui/bar_patience_groove_bg.png")
	if patience_bg != null:
		_timer_bar.add_theme_stylebox_override("background", patience_bg)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(ThemeColors.SURFACE_HIGH, 0.8)
		sb.border_width_left = 1; sb.border_width_top = 1
		sb.border_width_right = 1; sb.border_width_bottom = 1
		sb.border_color = ThemeColors.PANEL_BORDER
		_timer_bar.add_theme_stylebox_override("background", sb)
	var empty_fill := StyleBoxFlat.new()
	empty_fill.bg_color = Color(0, 0, 0, 0)
	_timer_bar.add_theme_stylebox_override("fill", empty_fill)
	_timer_bar.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_set_patience_fill_ratio(_timer_bar.value / 100.0)

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
	if _inference_ready_notice != null:
		ThemeColors.style_brush_label(_inference_ready_notice, 72, ThemeColors.AMBER_PRIMARY)
		_inference_ready_notice.add_theme_constant_override("outline_size", 5)
		_inference_ready_notice.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01, 0.95))
		_inference_ready_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inference_ready_notice.visible = false
		_inference_ready_notice.modulate.a = 0.0


func _configure_customer_input_passthrough() -> void:
	for path in [
		"CustomerArea",
		"CustomerArea/CustomerSprite",
		"CustomerArea/CustomerName",
		"CustomerArea/OrderBubble",
		"CustomerArea/ReactionBubble",
		"CustomerArea/PatienceIcon",
		"CustomerArea/TimerBar",
		"CustomerArea/PatienceFillClip",
		"CustomerArea/PatienceFillClip/PatienceFillArt",
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
	top_panel.move_child(_gold_progress, 2)
	top_panel.move_child(_rep_label, 3)
	top_panel.move_child(_rep_progress, 4)
	top_panel.move_child(_day_label, 5)
	top_panel.move_child(action_spacer, 6)
	top_panel.move_child($TopPanel/MenuButton, 7)
	top_panel.move_child(_end_night_btn, 8)
	top_panel.move_child(right_inset, 9)
	_configure_topbar_label(_gold_label, Vector2(150, TOPBAR_LABEL_HEIGHT), HORIZONTAL_ALIGNMENT_CENTER)
	_configure_topbar_progress(_gold_progress)
	_configure_topbar_label(_rep_label, Vector2(150, TOPBAR_LABEL_HEIGHT), HORIZONTAL_ALIGNMENT_CENTER)
	_configure_topbar_progress(_rep_progress)
	_configure_topbar_label(_day_label, Vector2(130, TOPBAR_LABEL_HEIGHT), HORIZONTAL_ALIGNMENT_CENTER)


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


func _configure_topbar_progress(progress: Control) -> void:
	progress.custom_minimum_size = REWARD_PROGRESS_SIZE
	progress.size_flags_horizontal = Control.SIZE_FILL
	progress.size_flags_vertical = Control.SIZE_FILL
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_reward_hud() -> void:
	_reward_coin_texture = TextureManager.try_load("res://assets/textures/ui/reward_hud/reward_coin_particle.png")
	_reward_rep_texture = TextureManager.try_load("res://assets/textures/ui/reward_hud/reward_rep_particle.png")
	_reward_spark_texture = TextureManager.try_load("res://assets/textures/ui/reward_hud/reward_spark.png")
	_configure_reward_progress_art(
		_gold_progress,
		"res://assets/textures/ui/reward_hud/reward_gold_progress_bg.png",
		"res://assets/textures/ui/reward_hud/reward_gold_progress_fill.png",
		"res://assets/textures/ui/reward_hud/reward_gold_progress_ornate.png"
	)
	_configure_reward_progress_art(
		_rep_progress,
		"res://assets/textures/ui/reward_hud/reward_rep_progress_bg.png",
		"res://assets/textures/ui/reward_hud/reward_rep_progress_fill.png",
		"res://assets/textures/ui/reward_hud/reward_rep_progress_ornate.png",
		REWARD_REP_PROGRESS_ART_OFFSET
	)
	var coin_ground := get_node_or_null("RewardCoinPhysicsLayer/CoinGround") as StaticBody2D
	if coin_ground != null:
		coin_ground.collision_layer = REWARD_COIN_COLLISION_LAYER
		coin_ground.collision_mask = 0
	if _gm != null and _gm.economy != null:
		_set_gold_display(_gm.economy.gold, _gm.economy.max_gold_held)
		_set_reputation_display(_gm.economy.reputation)


func _configure_reward_progress_art(progress: Control, bg_path: String, fill_path: String, ornate_path: String, art_offset: Vector2 = Vector2.ZERO) -> void:
	if progress == null:
		return
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := progress.get_node_or_null("Bg") as TextureRect
	var fill_clip := progress.get_node_or_null("FillClip") as Control
	var fill := progress.get_node_or_null("FillClip/Fill") as TextureRect
	var ornate := progress.get_node_or_null("Ornate") as TextureRect
	_configure_reward_texture(bg, bg_path)
	_configure_reward_texture(fill, fill_path)
	_configure_reward_texture(ornate, ornate_path)
	if fill_clip != null:
		fill_clip.z_index = 0
		fill_clip.position = art_offset + REWARD_PROGRESS_FILL_INSET
		fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill_clip.clip_contents = true
		fill_clip.size = Vector2(0.0, REWARD_PROGRESS_FILL_SIZE.y)
	if fill != null:
		fill.z_index = 0
		fill.size = REWARD_PROGRESS_SIZE
		fill.position = -REWARD_PROGRESS_FILL_INSET
	if ornate != null:
		ornate.z_index = 2
		ornate.position = art_offset
		ornate.visible = false
		ornate.modulate = Color.WHITE
	if bg != null:
		bg.z_index = 1
		bg.position = art_offset
	if fill_clip != null:
		progress.move_child(fill_clip, 0)
	if bg != null:
		progress.move_child(bg, 1)
	if ornate != null:
		progress.move_child(ornate, 2)


func _configure_reward_texture(texture_rect: TextureRect, texture_path: String) -> void:
	if texture_rect == null:
		return
	texture_rect.texture = TextureManager.try_load(texture_path)
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.size = REWARD_PROGRESS_SIZE
	texture_rect.position = Vector2.ZERO


func _refresh_reward_progress(gold: int, rep: int, max_gold_held: int = -1) -> void:
	var progress_gold := _gold_progress_value(gold, max_gold_held)
	_set_reward_progress_fill(_gold_progress_fill_clip, _gold_progress_fill_art, _gold_progress_ratio(progress_gold))
	_set_reward_progress_fill(_rep_progress_fill_clip, _rep_progress_fill_art, _threshold_progress_ratio(rep, REP_PROGRESS_THRESHOLDS))


func _set_gold_display(gold: int, max_gold_held: int = -1) -> void:
	_displayed_gold_total = gold
	_displayed_gold_progress_total = _gold_progress_value(gold, max_gold_held)
	if _gold_label != null:
		_gold_label.text = "金币：" + str(gold)
	_set_reward_progress_fill(_gold_progress_fill_clip, _gold_progress_fill_art, _gold_progress_ratio(_displayed_gold_progress_total))


func _set_reputation_display(rep: int) -> void:
	_displayed_rep_total = rep
	if _rep_label != null:
		_rep_label.text = "声望：" + str(rep)
	_set_reward_progress_fill(_rep_progress_fill_clip, _rep_progress_fill_art, _threshold_progress_ratio(rep, REP_PROGRESS_THRESHOLDS))


func _is_gold_display_deferred() -> bool:
	return _deferred_gold_total >= 0 or _gold_collection_apply_scheduled or _has_pending_reward_coins()


func _has_pending_reward_coins() -> bool:
	for body in _pending_reward_coin_bodies:
		if body != null and is_instance_valid(body):
			return true
	return false


func _gold_progress_value(gold: int, max_gold_held: int = -1) -> int:
	if max_gold_held < 0:
		return maxi(gold, _displayed_gold_progress_total)
	return maxi(gold, max_gold_held)


func _set_reward_progress_fill(fill_clip: Control, fill_art: TextureRect, ratio: float) -> void:
	if fill_clip == null:
		return
	var clamped := clampf(ratio, 0.0, 1.0)
	fill_clip.position = _reward_progress_art_offset(fill_clip) + REWARD_PROGRESS_FILL_INSET
	fill_clip.size = Vector2(floor(REWARD_PROGRESS_FILL_SIZE.x * clamped + 0.5), REWARD_PROGRESS_FILL_SIZE.y)
	if fill_art != null:
		fill_art.size = REWARD_PROGRESS_SIZE
		fill_art.position = -REWARD_PROGRESS_FILL_INSET
		fill_art.scale = Vector2.ONE


func _reward_progress_art_offset(fill_clip: Control) -> Vector2:
	if fill_clip == _rep_progress_fill_clip:
		return REWARD_REP_PROGRESS_ART_OFFSET
	return Vector2.ZERO


func _gold_progress_ratio(gold: int) -> float:
	if gold < 400:
		return _threshold_progress_ratio(gold, GOLD_PROGRESS_THRESHOLDS)
	return float((gold - 400) % 400) / 400.0


func _threshold_progress_ratio(value: int, thresholds: Array) -> float:
	if thresholds.size() < 2:
		return 1.0
	for index in range(thresholds.size() - 1):
		var start := int(thresholds[index])
		var finish := int(thresholds[index + 1])
		if value < finish:
			return clampf(float(value - start) / float(finish - start), 0.0, 1.0)
	return 1.0


func _gold_progress_band(gold: int) -> int:
	if gold < 50:
		return 0
	if gold < 100:
		return 1
	if gold < 200:
		return 2
	if gold < 400:
		return 3
	return 4 + int(floor(float(gold - 400) / 400.0))


func _rep_progress_band(rep: int) -> int:
	if rep < 50:
		return 0
	if rep < 150:
		return 1
	return 2


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

func show_customer(customer_name: String, order: String, npc_id: String = "guest", order_key: String = "") -> void:
	if _customer_dialogue_highlight_active:
		_set_customer_dialogue_highlight(false)
	_current_customer_npc_id = npc_id
	_current_customer_reaction_outcome = ""
	_current_order_text = order
	_current_order_status_text = ""
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
	_refresh_order_groove_text()
	_order_bubble.visible = true
	_reaction_bubble.text = ""
	_reaction_bubble.visible = false
	_timer_bar.modulate = Color.WHITE
	if _patience_fill_art != null:
		_patience_fill_art.modulate = Color.WHITE
	if _dialogue_overlay != null and _dialogue_overlay.visible:
		_set_customer_dialogue_highlight(true)

func _refresh_order_groove_text() -> void:
	if _current_order_text == "":
		_order_bubble.text = ""
		return
	var text := "需要 · " + _current_order_text
	if _current_order_status_text != "":
		text += "  ·  " + _current_order_status_text
	_order_bubble.text = text

func show_order_warning() -> void:
	if _patience_fill_art != null:
		_patience_fill_art.modulate = Color(1.22, 0.74, 0.52, 1.0)

func show_order_timeout(status_text: String = "等太久了") -> void:
	_current_order_status_text = status_text
	_refresh_order_groove_text()
	if _patience_fill_art != null:
		_patience_fill_art.modulate = Color(1.3, 0.48, 0.4, 1.0)
	_order_bubble.visible = true

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
	if npc_id == "toby":
		return _toby_texture_key(outcome)
	if npc_id == "grey_ledger_lady":
		return _grey_ledger_lady_texture_key(outcome)
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
		return RYAN_TEXTURE_ALARMED
	var story_key := _ryan_story_texture_key()
	if outcome == "success":
		if story_key != RYAN_TEXTURE_NEUTRAL:
			return story_key
		return RYAN_TEXTURE_CONFIDENT
	return story_key

func _ryan_story_texture_key() -> String:
	var narrative = null
	if _gm != null:
		narrative = _gm.narrative
	if narrative == null:
		return RYAN_TEXTURE_NEUTRAL
	if _story_flag(narrative, "ryan_drugged") or _story_flag(narrative, "ryan_alternative_declined"):
		return RYAN_TEXTURE_BROKEN
	var ending := _story_string(narrative, "ryan_ending")
	if ending != "":
		return RYAN_TEXTURE_RELIEVED if ending == "alternative_survivor" else RYAN_TEXTURE_BROKEN
	if _story_flag(narrative, "ryan_has_alternative"):
		return RYAN_TEXTURE_RESOLVED
	if _story_flag(narrative, "ryan_alternative_pending"):
		return RYAN_TEXTURE_WARY
	if _story_flag(narrative, "ryan_informed"):
		return RYAN_TEXTURE_HESITANT
	return RYAN_TEXTURE_NEUTRAL

func _toby_texture_key(outcome: String = "") -> String:
	if outcome == "success":
		return TOBY_TEXTURE_WARMED
	if outcome in ["fail_wrong", "fail_weird", "fail", "impatient"]:
		return TOBY_TEXTURE_HURT
	var narrative = _gm.narrative if _gm != null else null
	if _story_flag(narrative, "toby_danger_known") and not _story_flag(narrative, "toby_secured"):
		return TOBY_TEXTURE_AFRAID
	return TOBY_TEXTURE_NEUTRAL

func _grey_ledger_lady_texture_key(outcome: String = "") -> String:
	if outcome == "success":
		return GREY_LEDGER_LADY_TEXTURE_SMILE
	if outcome in ["fail_wrong", "fail_weird", "fail", "impatient"]:
		return GREY_LEDGER_LADY_TEXTURE_ASSESSING
	if outcome in ["cracked", "threat", "revealed"]:
		return GREY_LEDGER_LADY_TEXTURE_CRACKED
	return GREY_LEDGER_LADY_TEXTURE_NEUTRAL

func _story_flag(narrative, key: String) -> bool:
	return narrative != null and narrative.get_var(key) == true

func _story_string(narrative, key: String) -> String:
	if narrative == null:
		return ""
	var value = narrative.get_var(key)
	return "" if value == null else String(value)

func _mira_texture_key(outcome: String = "") -> String:
	if outcome in ["fail_wrong", "fail_weird", "fail", "impatient"]:
		return MIRA_TEXTURE_SERIOUS

	var current_day := _current_story_day()
	var narrative = _gm.narrative if _gm != null else null
	var told_truth := false
	var ending := ""
	if narrative != null:
		told_truth = _story_flag(narrative, "told_mira_truth")
		ending = _story_string(narrative, "mira_ending")

	if outcome == "success":
		if current_day >= 12:
			if ending == "she_finally_stopped":
				return MIRA_TEXTURE_RESOLVED
			if ending == "never_turned_back":
				return MIRA_TEXTURE_DETACHED
			if ending in ["closed_the_door", "another_light_out"]:
				return MIRA_TEXTURE_SMILE
			if told_truth:
				if narrative != null and narrative.get_affection("mira") >= narrative.MIRA_TRUST_THRESHOLD:
					return MIRA_TEXTURE_RESOLVED
				return MIRA_TEXTURE_CONFLICTED
			return MIRA_TEXTURE_SMILE
		return MIRA_TEXTURE_SMILE

	if current_day >= 12:
		if told_truth and ending == "":
			return MIRA_TEXTURE_GUILTY
		return MIRA_TEXTURE_DETACHED
	return MIRA_TEXTURE_NEUTRAL

func _current_story_day() -> int:
	if _gm == null or _gm.economy == null:
		return 0
	return int(_gm.economy.current_day)

func hide_customer() -> void:
	_set_customer_dialogue_highlight(false)
	_current_customer_npc_id = ""
	_current_customer_reaction_outcome = ""
	_current_order_text = ""
	_current_order_status_text = ""
	_customer_sprite.visible = false
	_customer_name.text = "等待中……"
	_order_bubble.visible = false
	_reaction_bubble.visible = false
	_reaction_bubble.text = ""
	_timer_bar.modulate = Color.WHITE
	if _patience_fill_art != null:
		_patience_fill_art.modulate = Color.WHITE

func update_timer(ratio: float) -> void:
	_timer_bar.value = ratio * 100.0
	_set_patience_fill_ratio(ratio)

func _set_patience_fill_ratio(ratio: float) -> void:
	if _patience_fill_clip == null or _timer_bar == null:
		return
	var clamped: float = clampf(ratio, 0.0, 1.0)
	var full_size: Vector2 = _timer_bar.size
	var clipped_width: float = floor(full_size.x * clamped + 0.5)
	_patience_fill_clip.size = Vector2(clipped_width, full_size.y)
	if _patience_fill_art != null:
		_patience_fill_art.size = full_size
		_patience_fill_art.position = Vector2.ZERO
		_patience_fill_art.scale = Vector2.ONE

func update_top_bar(gold: int, rep: int, day: int, max_day: int, max_gold_held: int = -1) -> void:
	if _is_gold_display_deferred():
		_set_gold_display(_displayed_gold_total, _displayed_gold_progress_total)
	else:
		_set_gold_display(gold, max_gold_held)
	_set_reputation_display(rep)
	_day_label.text = "第%d/%d天" % [day, max_day]


func show_order_reward_feedback(earned_gold: int, earned_rep: int, previous_gold: int, previous_rep: int, previous_max_gold: int = -1, new_max_gold: int = -1) -> void:
	var new_gold := previous_gold + earned_gold
	var new_rep := previous_rep + earned_rep
	var previous_progress_gold := _gold_progress_value(previous_gold, previous_max_gold)
	var new_progress_gold := _gold_progress_value(new_gold, new_max_gold)
	if earned_gold > 0:
		if _deferred_gold_previous_total < 0:
			_deferred_gold_previous_total = previous_gold
			_deferred_gold_previous_progress_total = previous_progress_gold
		_deferred_gold_total = new_gold
		_deferred_gold_progress_total = new_progress_gold
		_set_gold_display(_displayed_gold_total if _gold_collection_apply_scheduled else previous_gold, previous_progress_gold)
		_spawn_reward_coins(earned_gold)
		if not _has_pending_reward_coins() and not _gold_collection_apply_scheduled:
			_apply_deferred_gold_display()
	elif not _is_gold_display_deferred():
		_set_gold_display(new_gold, new_progress_gold)
	if earned_rep > 0:
		_set_reputation_display(new_rep)
		_spawn_reward_reputation_particles(earned_rep)
		_pulse_reward_label(_rep_label)
	if _rep_progress_band(new_rep) > _rep_progress_band(previous_rep):
		_activate_reward_ornate(_rep_progress_ornate)


func _spawn_reward_coins(earned_gold: int) -> void:
	if _reward_coin_layer == null:
		return
	var coin_count := clampi(earned_gold, 1, 8)
	for index in range(coin_count):
		_spawn_reward_coin(index, coin_count)


func _spawn_reward_coin(index: int, coin_count: int) -> void:
	var body := RigidBody2D.new()
	body.name = "RewardCoin"
	body.gravity_scale = 1.15
	body.mass = 0.22
	body.collision_layer = 0
	body.collision_mask = REWARD_COIN_COLLISION_LAYER
	var material := PhysicsMaterial.new()
	material.bounce = 0.36
	material.friction = 0.62
	body.physics_material_override = material
	var spread := float(index) - (float(coin_count - 1) * 0.5)
	body.position = Vector2(640.0 + spread * 9.0, 500.0 - float(index % 3) * 4.0)
	body.linear_velocity = Vector2(spread * 32.0, -210.0 - float(index % 4) * 22.0)
	body.angular_velocity = -10.0 + float(index % 6) * 4.0

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	body.add_child(shape)

	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = _reward_coin_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	_reward_coin_layer.add_child(body)
	_pending_reward_coin_bodies.append(body)


func _collect_pending_reward_coins() -> void:
	if _pending_reward_coin_bodies.is_empty():
		return
	var bodies := _pending_reward_coin_bodies.duplicate()
	_pending_reward_coin_bodies.clear()
	for body in bodies:
		if body != null and is_instance_valid(body):
			_pull_reward_coin_to_ui(body)
	_schedule_deferred_gold_display()


func _pull_reward_coin_to_ui(body: RigidBody2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	_pending_reward_coin_bodies.erase(body)
	var start_position := body.global_position
	body.queue_free()
	_spawn_reward_travel_particle(_reward_coin_texture, start_position, _control_center(_gold_progress), Color.WHITE, 1.0)


func _schedule_deferred_gold_display() -> void:
	if _deferred_gold_total < 0 or _gold_collection_apply_scheduled:
		return
	_gold_collection_apply_scheduled = true
	var timer := get_tree().create_timer(REWARD_TRAVEL_SECONDS)
	timer.timeout.connect(_apply_deferred_gold_display)


func _apply_deferred_gold_display() -> void:
	_gold_collection_apply_scheduled = false
	if _has_pending_reward_coins():
		_schedule_deferred_gold_display()
		return
	if _deferred_gold_total < 0:
		return
	var final_gold := _deferred_gold_total
	var previous_gold := _deferred_gold_previous_total
	if previous_gold < 0:
		previous_gold = _displayed_gold_total
	var final_progress_gold := _gold_progress_value(final_gold, _deferred_gold_progress_total)
	var previous_progress_gold := _gold_progress_value(previous_gold, _deferred_gold_previous_progress_total)
	_deferred_gold_total = -1
	_deferred_gold_previous_total = -1
	_deferred_gold_progress_total = -1
	_deferred_gold_previous_progress_total = -1
	_set_gold_display(final_gold, final_progress_gold)
	_pulse_reward_label(_gold_label)
	if _gold_progress_band(final_progress_gold) > _gold_progress_band(previous_progress_gold):
		_activate_reward_ornate(_gold_progress_ornate)


func _spawn_reward_reputation_particles(earned_rep: int) -> void:
	if _reward_particles == null:
		return
	var particle_count := clampi(earned_rep + 1, 1, 5)
	for index in range(particle_count):
		var offset := Vector2((float(index) - float(particle_count - 1) * 0.5) * 18.0, -float(index % 2) * 10.0)
		_spawn_reward_travel_particle(
			_reward_rep_texture,
			Vector2(640.0, 500.0) + offset,
			_control_center(_rep_progress),
			Color(0.72, 0.96, 1.0, 1.0),
			0.92
		)
	if _reward_spark_texture != null:
		_spawn_reward_travel_particle(_reward_spark_texture, Vector2(640.0, 510.0), _control_center(_rep_progress), Color.WHITE, 0.8)


func _spawn_reward_travel_particle(texture: Texture2D, start_position: Vector2, target_position: Vector2, tint: Color, scale_amount: float) -> void:
	if _reward_particles == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "RewardParticle"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = start_position
	sprite.modulate = tint
	sprite.scale = Vector2.ONE * scale_amount
	_reward_particles.add_child(sprite)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", target_position, REWARD_TRAVEL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.35, 0.35), REWARD_TRAVEL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, REWARD_TRAVEL_SECONDS).set_delay(REWARD_TRAVEL_SECONDS * 0.62)
	tween.finished.connect(sprite.queue_free)


func _activate_reward_ornate(ornate: TextureRect) -> void:
	if ornate == null:
		return
	ornate.visible = true
	ornate.modulate = Color(1.0, 1.0, 1.0, 1.0)
	ornate.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_interval(0.72)
	tween.tween_property(ornate, "modulate:a", 0.0, 0.32)
	tween.finished.connect(func():
		if is_instance_valid(ornate):
			ornate.visible = false
			ornate.modulate = Color.WHITE
	)


func _pulse_reward_label(label: Label) -> void:
	if label == null:
		return
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.08, 1.08), 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14)


func _control_center(control: Control) -> Vector2:
	if control == null:
		return Vector2(640.0, 24.0)
	return control.global_position + control.size * 0.5


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

## 鍑哄彛鈶狅細瀹汉鍦ㄥ璇濇皵娉￠噷鐢ㄨ嚜宸辩殑鍙ｅ惢鍙嶅簲锛堝彴璇嶅惈銆屻€嶏級銆?
func customer_say(text: String) -> void:
	_reaction_bubble.text = text
	_reaction_bubble.visible = text != ""

## 鍑哄彛鈶★細鑸炲彴鎻愮ず娴瓧鈥斺€旂涓変汉绉板姩浣滄弿鍐欙紝娣″叆鈫掑仠鐣欌啋娣″嚭銆?
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

func show_inference_ready_notice() -> void:
	if _inference_ready_notice == null:
		return
	if _inference_ready_notice_tween != null and _inference_ready_notice_tween.is_valid():
		_inference_ready_notice_tween.kill()
	_inference_ready_notice.text = "?"
	_inference_ready_notice.visible = true
	_inference_ready_notice.modulate = Color(1, 1, 1, 0)
	_inference_ready_notice.scale = Vector2(0.72, 0.72)
	_inference_ready_notice.pivot_offset = _inference_ready_notice.size * 0.5
	_inference_ready_notice_tween = create_tween()
	_inference_ready_notice_tween.tween_property(_inference_ready_notice, "modulate:a", 1.0, 0.18)
	_inference_ready_notice_tween.parallel().tween_property(_inference_ready_notice, "scale", Vector2(1.18, 1.18), 0.18)
	_inference_ready_notice_tween.tween_interval(0.75)
	_inference_ready_notice_tween.tween_property(_inference_ready_notice, "modulate:a", 0.0, 0.45)
	_inference_ready_notice_tween.parallel().tween_property(_inference_ready_notice, "scale", Vector2(1.36, 1.36), 0.45)
	_inference_ready_notice_tween.tween_callback(func():
		_inference_ready_notice.visible = false
		_inference_ready_notice.scale = Vector2.ONE
	)

func show_recipe_discovery_notice(_product_key: String) -> void:
	return

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
	_refresh_ledger_hint()


func open_ledger() -> void:
	_gm.request_open_document("ledger")


func _refresh_ledger_hint() -> void:
	var ledger := get_node_or_null("BarWorkspace/World/Ledger") as ReadableDeskItem
	if ledger == null or not ledger.has_method("set_unread_hint_visible"):
		return
	var unread := false
	if _gm != null and _gm.documents != null and _gm.documents.has_method("has_unread_ledger_entries"):
		unread = _gm.documents.has_unread_ledger_entries()
	ledger.set_unread_hint_visible(unread)


func _on_inventory_item_dropped(item_key: String, global_position: Vector2) -> void:
	var bar = get_node_or_null("BarWorkspace")
	if bar != null and bar.has_method("bind_shortcut_at_position"):
		if bar.bind_shortcut_at_position(item_key, global_position):
			return
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


func get_tutorial_highlight_rects(group_key: String) -> Dictionary:
	match group_key:
		"craft":
			return _craft_tutorial_rects()
		"serve":
			return _serve_tutorial_rects()
	return {}


func trigger_craft_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	tm.start_tutorial("craft", get_tutorial_highlight_rects("craft"))


func _craft_tutorial_rects() -> Dictionary:
	var brewery_rect := _sprite_screen_rect("BarWorkspace/World/Brewery/Art", "BarWorkspace/World/Brewery", Vector2(116.0, 136.0), Vector2(14.0, 14.0))
	var recovery_rects := [
		_available_sprite_screen_rect("BarWorkspace/World/Brewery/Art", "BarWorkspace/World/Brewery", Vector2(116.0, 136.0), Vector2(10.0, 10.0)),
		_available_sprite_screen_rect("BarWorkspace/World/SeasoningShaker/Art", "BarWorkspace/World/SeasoningShaker", Vector2(74.0, 118.0), Vector2(10.0, 10.0)),
		_available_sprite_screen_rect("BarWorkspace/World/Pot/Art", "BarWorkspace/World/Pot", Vector2(112.0, 124.0), Vector2(10.0, 10.0)),
	]
	var recovery_rect := _union_screen_rects(recovery_rects)
	if recovery_rect.size() < 4:
		recovery_rect = brewery_rect
	return {
		"CraftBarrel": brewery_rect,
		"ShortcutBar": _control_screen_rect(get_node_or_null("ShortcutBar") as Control),
		"RecoveryContainer": recovery_rect,
	}


func _serve_tutorial_rects() -> Dictionary:
	return {
		"CustomerNode": _control_screen_rect(get_node_or_null("CustomerArea") as Control),
	}


func _control_screen_rect(control: Control) -> Array:
	if control == null:
		return [0.0, 0.0, 0.0, 0.0]
	var rect := control.get_global_rect()
	return _rect_to_array(rect)


func _available_sprite_screen_rect(sprite_path: String, fallback_node_path: String, fallback_size: Vector2, padding: Vector2 = Vector2.ZERO) -> Array:
	var node := get_node_or_null(fallback_node_path)
	if node == null:
		return []
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return []
	if node.process_mode == Node.PROCESS_MODE_DISABLED:
		return []
	return _sprite_screen_rect(sprite_path, fallback_node_path, fallback_size, padding)


func _sprite_screen_rect(sprite_path: String, fallback_node_path: String, fallback_size: Vector2, padding: Vector2 = Vector2.ZERO) -> Array:
	var sprite := get_node_or_null(sprite_path) as Sprite2D
	if sprite != null and sprite.texture != null:
		return _rect_to_array(_grow_rect(_sprite_global_rect(sprite), padding))
	return _node_centered_screen_rect(fallback_node_path, fallback_size, padding)


func _sprite_global_rect(sprite: Sprite2D) -> Rect2:
	var local_rect := sprite.get_rect()
	var transform := sprite.get_global_transform()
	var points := [
		transform * local_rect.position,
		transform * (local_rect.position + Vector2(local_rect.size.x, 0.0)),
		transform * (local_rect.position + Vector2(0.0, local_rect.size.y)),
		transform * (local_rect.position + local_rect.size),
	]
	var min_x := (points[0] as Vector2).x
	var min_y := (points[0] as Vector2).y
	var max_x := min_x
	var max_y := min_y
	for point in points:
		var p := point as Vector2
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _node_centered_screen_rect(node_path: String, size: Vector2, padding: Vector2 = Vector2.ZERO) -> Array:
	var node := get_node_or_null(node_path) as Node2D
	if node == null:
		return [0.0, 0.0, 0.0, 0.0]
	var rect := Rect2(node.global_position - size * 0.5, size)
	return _rect_to_array(_grow_rect(rect, padding))


func _union_screen_rects(rect_arrays: Array) -> Array:
	var has_rect := false
	var union_rect := Rect2()
	for values in rect_arrays:
		var rect := _rect_from_array(values as Array)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if not has_rect:
			union_rect = rect
			has_rect = true
		else:
			union_rect = union_rect.merge(rect)
	if not has_rect:
		return []
	return _rect_to_array(union_rect)


func _rect_from_array(values: Array) -> Rect2:
	if values.size() < 4:
		return Rect2()
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))


func _rect_to_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _grow_rect(rect: Rect2, padding: Vector2) -> Rect2:
	return Rect2(rect.position - padding, rect.size + padding * 2.0)

## 閰嶆柟琛細鎸?recipes.json 鏄剧ず銆屼骇鐗?浠锋牸 鈫?閰嶆枡 [瀹瑰櫒]銆嶏紝璁╃帺瀹惰兘瀛︿細鎬庝箞鍋氥€?
## 闇€璐拱涓旀湭瑙ｉ攣鐨勯厤鏂规爣鐏板苟娉ㄦ槑锛堥渶瑙ｉ攣锛夈€?
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

		var text: String = "%s  %d金  -> %s  [%s]" % [product_name, price, "、".join(ingr_names), container_name]
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
		_add_recipe_new_marker(row, product_key)
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
	var cleared_new_marker := false
	if _gm != null and _gm.craft != null and _gm.craft.has_method("is_recipe_new") \
			and _gm.craft.has_method("clear_recipe_new") \
			and _gm.craft.call("is_recipe_new", product_key):
		cleared_new_marker = bool(_gm.craft.call("clear_recipe_new", product_key))
	if product_key == _recipe_selected_product_key:
		if cleared_new_marker:
			_build_recipe_list()
		return
	_recipe_selected_product_key = product_key
	_build_recipe_list()


func _add_recipe_new_marker(row: Button, product_key: String) -> void:
	if _gm == null or _gm.craft == null or not _gm.craft.has_method("is_recipe_new"):
		return
	if not bool(_gm.craft.call("is_recipe_new", product_key)):
		return
	var marker := Label.new()
	marker.name = "NewMark"
	marker.text = "新"
	marker.position = Vector2(RECIPE_LEFT_COLUMN_WIDTH - 42.0, 9.0)
	marker.size = Vector2(28.0, 22.0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeColors.style_brush_label(marker, 12, ThemeColors.AMBER_PRIMARY)
	marker.add_theme_constant_override("outline_size", 2)
	marker.add_theme_color_override("font_outline_color", Color(0.06, 0.035, 0.015, 0.92))
	row.add_child(marker)


func _is_recipe_discovered(product_key: String) -> bool:
	return _gm != null and _gm.craft != null and _gm.craft.is_recipe_discovered(product_key)


func _recipe_row_text(product_key: String) -> String:
	var recipe: Dictionary = _gm.craft.recipes.get(product_key, {})
	var product_data: Dictionary = _gm.craft.get_item(product_key)
	if not _is_recipe_discovered(product_key):
		return "???  未研制"
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
	var discovered := _is_recipe_discovered(product_key)
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
	if discovered:
		var product_icon := _new_recipe_icon(product_key, product_data, Vector2(60.0, 56.0))
		product_icon.name = "ProductIcon"
		product_slot_center.add_child(product_icon)
	else:
		var unknown_icon := _new_recipe_label("ProductIcon", "?", 26, ThemeColors.TEXT_DIM)
		unknown_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown_icon.custom_minimum_size = Vector2(60.0, 56.0)
		product_slot_center.add_child(unknown_icon)
	header.add_child(product_slot)

	var title_box := VBoxContainer.new()
	title_box.name = "TitleBox"
	title_box.custom_minimum_size = Vector2(190.0, 0.0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)
	var title_text := String(product_data.get("name", product_key)) if discovered else "???"
	var title_label := _new_recipe_label("Title", title_text, 16, ThemeColors.AMBER_PRIMARY)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.custom_minimum_size = Vector2(180.0, 22.0)
	title_box.add_child(title_label)
	var meta_text := "售价 %d金 · %s" % [int(product_data.get("price", 0)), String(CONTAINER_NAMES.get(container_key, container_key))] if discovered else "%s · 未研制" % String(CONTAINER_NAMES.get(container_key, container_key))
	title_box.add_child(_new_recipe_label("Meta", meta_text, 12, ThemeColors.TEXT_SUBTITLE))
	title_box.add_child(_new_recipe_label("Status", _recipe_status_text(product_key, recipe), 12, ThemeColors.TEXT_LIGHT))

	body.add_child(_new_recipe_label("IngredientTitle", "材料", 13, ThemeColors.AMBER_PRIMARY))
	var ingredient_grid := GridContainer.new()
	ingredient_grid.name = "IngredientGrid"
	ingredient_grid.columns = 3
	ingredient_grid.add_theme_constant_override("h_separation", 6)
	ingredient_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(ingredient_grid)
	for index in ingredients.size():
		if discovered:
			ingredient_grid.add_child(_new_recipe_ingredient_cell(String(ingredients[index])))
		else:
			ingredient_grid.add_child(_new_unknown_recipe_ingredient_cell(index))

	var instruction := String(RECIPE_CONTAINER_INSTRUCTIONS.get(container_key, "")) if discovered else "继续尝试%s里的材料组合。" % String(CONTAINER_NAMES.get(container_key, container_key))
	body.add_child(_new_recipe_instruction_panel(instruction))


func _recipe_status_text(product_key: String, recipe: Dictionary) -> String:
	if not _is_recipe_discovered(product_key):
		return "状态：未研制"
	var locked: bool = bool(recipe.get("requires_purchase", false)) and not _gm.craft.is_recipe_unlocked(product_key)
	if locked:
		return "状态：需商店解锁"
	return "状态：已掌握"


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


func _new_unknown_recipe_ingredient_cell(index: int) -> PanelContainer:
	var cell := _new_recipe_slot_panel("Ingredient_Unknown_%d" % index, Vector2(88.0, 80.0))
	cell.set_meta("item_key", "")

	var box := VBoxContainer.new()
	box.name = "Body"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	cell.add_child(box)

	var icon := _new_recipe_label("Icon", "?", 18, ThemeColors.TEXT_DIM)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(32.0, 30.0)
	box.add_child(icon)

	var label := _new_recipe_label("Name", "???", 10, ThemeColors.TEXT_LIGHT)
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
