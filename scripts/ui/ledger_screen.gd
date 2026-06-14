class_name LedgerScreen
extends Node2D

const SETTLEMENT_BACKDROP := "res://assets/textures/ui/night_settlement/night_settlement_backdrop.png"
const SETTLEMENT_PANEL_STATS := "res://assets/textures/ui/night_settlement/night_settlement_panel_stats.png"
const SETTLEMENT_PANEL_FATES := "res://assets/textures/ui/night_settlement/night_settlement_panel_fates.png"
const CONTINUE_NORMAL := "res://assets/textures/ui/night_settlement/night_settlement_continue_normal.png"
const CONTINUE_HOVER := "res://assets/textures/ui/night_settlement/night_settlement_continue_hover.png"
const CONTINUE_PRESSED := "res://assets/textures/ui/night_settlement/night_settlement_continue_pressed.png"
const PIXEL_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const RYAN_FATE_TEXTURES := {
	"uninformed_fallen": "res://assets/textures/endings/ryan/ryan_uninformed_fallen.png",
	"drugged_survivor": "res://assets/textures/endings/ryan/ryan_drugged_survivor.png",
	"informed_fallen": "res://assets/textures/endings/ryan/ryan_informed_fallen.png",
	"alternative_survivor": "res://assets/textures/endings/ryan/ryan_alternative_survivor.png",
}
const ICONS := {
	"gold": "res://assets/textures/ui/night_settlement/night_settlement_icon_gold.png",
	"reputation": "res://assets/textures/ui/night_settlement/night_settlement_icon_reputation.png",
	"guests": "res://assets/textures/ui/night_settlement/night_settlement_icon_guests.png",
	"success": "res://assets/textures/ui/night_settlement/night_settlement_icon_success.png",
	"failed": "res://assets/textures/ui/night_settlement/night_settlement_icon_failed.png",
	"fate": "res://assets/textures/ui/night_settlement/night_settlement_icon_fate.png",
}

var _title_label: Label
var _stats_list: VBoxContainer
var _fate_title: Label
var _fate_list: VBoxContainer
var _continue_btn: Button
var _settlement_backdrop: TextureRect
var _stats_panel_art: TextureRect
var _fate_panel_art: TextureRect
var _ryan_fate_cinematic: Control


func _ready() -> void:
	_title_label = $UI/TitleLabel
	_stats_list = $UI/StatsList
	_fate_title = $UI/FateTitle
	_fate_list = $UI/FateList
	_continue_btn = $UI/ContinueBtn
	_settlement_backdrop = get_node_or_null("ArtLayer/SettlementBackdrop") as TextureRect
	_stats_panel_art = get_node_or_null("ArtLayer/StatsPanelArt") as TextureRect
	_fate_panel_art = get_node_or_null("ArtLayer/FatePanelArt") as TextureRect

	_apply_settlement_art()
	_style_settlement_button(_continue_btn)
	_continue_btn.pressed.connect(_on_continue)

	var gm = get_node("/root/GameManager")
	var data = gm.current_ledger_data
	if data != null:
		_render(data)
		_show_ryan_fate_cinematic_if_needed(data)

	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null and not tm.first_ledger_shown:
		tm.first_ledger_shown = true
		tm._save_state()
		call_deferred("_trigger_ledger_tutorial")


func _render(data: LedgerData) -> void:
	_clear_container(_stats_list)
	_clear_container(_fate_list)
	_stats_list.add_theme_constant_override("separation", 0)
	_fate_title.visible = true

	_title_label.text = "第 %d 天 · 打烊回声" % data.day
	ThemeColors.style_header(_title_label, 28)
	_apply_pixel_font(_title_label)

	_add_stat_row("gold", "金币", "+%d / %d" % [data.gold_today, data.gold_total])
	_add_stat_row("reputation", "声望", "%+d / %d" % [data.rep_today, data.rep_total])
	_add_stat_row("guests", "客人", "%d 位" % data.guests_served)
	_add_stat_row("success", "成功", "%d 单" % data.orders_success)
	_add_stat_row("failed", "失败", "%d 单" % data.orders_failed)

	_fate_title.text = "今晚余波"
	ThemeColors.style_header(_fate_title, 20)
	_apply_pixel_font(_fate_title)

	var fates: Array = data.npc_fates
	if fates.size() > 0:
		for fate in fates:
			_add_fate_card(fate)
	else:
		_add_empty_fate_line("没有特别的传闻留下。")


func _show_ryan_fate_cinematic_if_needed(data: LedgerData) -> void:
	var fate := _find_ryan_fate(data.npc_fates)
	if fate.is_empty():
		return
	var route := String(fate.get("ending_key", ""))
	if not RYAN_FATE_TEXTURES.has(route):
		return
	var texture_path := String(RYAN_FATE_TEXTURES[route])
	var texture := _load_runtime_texture(texture_path)
	if texture == null:
		return
	_ryan_fate_cinematic = _create_ryan_fate_cinematic(texture, String(fate.get("fate_text", "")))
	add_child(_ryan_fate_cinematic)
	_play_ryan_fate_intro(_ryan_fate_cinematic)


func _find_ryan_fate(fates: Array) -> Dictionary:
	for fate in fates:
		if not fate is Dictionary:
			continue
		var data: Dictionary = fate
		if String(data.get("npc_id", "")) == "ryan":
			return data
	return {}


func _load_runtime_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	return texture


func _create_ryan_fate_cinematic(texture: Texture2D, fate_text: String) -> Control:
	var overlay := Control.new()
	overlay.name = "RyanFateCinematic"
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.focus_mode = Control.FOCUS_ALL
	overlay.gui_input.connect(_on_ryan_fate_cinematic_gui_input)

	var black := ColorRect.new()
	black.name = "BlackBG"
	black.position = Vector2.ZERO
	black.size = Vector2(1280, 720)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.color = Color.BLACK
	overlay.add_child(black)

	var still := TextureRect.new()
	still.name = "Still"
	still.position = Vector2(0, 80)
	still.size = Vector2(1280, 560)
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_SCALE
	still.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	still.texture = texture
	still.modulate.a = 0.0
	overlay.add_child(still)

	var fate_label := Label.new()
	fate_label.name = "FateLabel"
	fate_label.position = Vector2(180, 642)
	fate_label.size = Vector2(920, 72)
	fate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fate_label.text = fate_text
	fate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fate_label.add_theme_font_override("font", PIXEL_FONT)
	fate_label.add_theme_font_size_override("font_size", 18)
	fate_label.add_theme_color_override("font_color", Color(0.86, 0.76, 0.64, 1.0))
	fate_label.add_theme_constant_override("outline_size", 3)
	fate_label.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.008, 0.78))
	fate_label.modulate.a = 0.0
	overlay.add_child(fate_label)
	return overlay


func _play_ryan_fate_intro(overlay: Control) -> void:
	var still := overlay.get_node_or_null("Still") as TextureRect
	var fate_label := overlay.get_node_or_null("FateLabel") as Label
	if still == null or fate_label == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(still, "modulate:a", 1.0, 0.55)
	tween.tween_property(fate_label, "modulate:a", 1.0, 0.55).set_delay(0.2)


func _dismiss_ryan_fate_cinematic() -> void:
	if _ryan_fate_cinematic == null or not is_instance_valid(_ryan_fate_cinematic):
		return
	_ryan_fate_cinematic.visible = false
	_ryan_fate_cinematic.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_ryan_fate_cinematic_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_ryan_fate_cinematic()
		get_viewport().set_input_as_handled()


func _load_texture(path: String) -> Texture2D:
	return load(path) as Texture2D


func _make_texture_style(path: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _load_texture(path)
	return style


func _apply_pixel_font(control: Control) -> void:
	control.add_theme_font_override("font", PIXEL_FONT)


func _apply_settlement_art() -> void:
	if _settlement_backdrop != null:
		_settlement_backdrop.texture = _load_texture(SETTLEMENT_BACKDROP)
		_settlement_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_settlement_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _stats_panel_art != null:
		_stats_panel_art.texture = _load_texture(SETTLEMENT_PANEL_STATS)
		_stats_panel_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_stats_panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fate_panel_art != null:
		_fate_panel_art.texture = _load_texture(SETTLEMENT_PANEL_FATES)
		_fate_panel_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fate_panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style_settlement_button(button: Button) -> void:
	button.text = "熄灯"
	button.add_theme_stylebox_override("normal", _make_texture_style(CONTINUE_NORMAL))
	button.add_theme_stylebox_override("hover", _make_texture_style(CONTINUE_HOVER))
	button.add_theme_stylebox_override("pressed", _make_texture_style(CONTINUE_PRESSED))
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_ALL


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_stat_row(icon_id: String, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.add_theme_constant_override("separation", 6)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _load_texture(ICONS.get(icon_id, ICONS["fate"]))
	row.add_child(icon)

	var name := Label.new()
	name.text = label_text
	name.custom_minimum_size = Vector2(66, 24)
	name.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_apply_pixel_font(name)
	name.add_theme_font_size_override("font_size", 14)
	row.add_child(name)

	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(146, 24)
	value.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_apply_pixel_font(value)
	value.add_theme_font_size_override("font_size", 14)
	row.add_child(value)

	_stats_list.add_child(row)


func _add_fate_card(fate: Dictionary) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = "%s · %s" % [String(fate.get("npc_name", "")), String(fate.get("npc_title", ""))]
	name_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_apply_pixel_font(name_label)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.clip_text = true
	card.add_child(name_label)

	var fate_label := Label.new()
	fate_label.text = String(fate.get("fate_text", ""))
	fate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fate_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_apply_pixel_font(fate_label)
	fate_label.add_theme_font_size_override("font_size", 14)
	card.add_child(fate_label)

	_fate_list.add_child(card)


func _add_empty_fate_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", 15)
	_fate_list.add_child(label)


func _on_continue() -> void:
	var gm = get_node("/root/GameManager")
	gm.day_cycle.next_phase()


func _unhandled_input(event: InputEvent) -> void:
	if _ryan_fate_cinematic == null or not is_instance_valid(_ryan_fate_cinematic) or not _ryan_fate_cinematic.visible:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo
	if pressed:
		_dismiss_ryan_fate_cinematic()
		get_viewport().set_input_as_handled()


func _trigger_ledger_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	var rects = {
		"UI": [90, 50, 1100, 560],
	}
	tm.start_tutorial("ledger", rects)
