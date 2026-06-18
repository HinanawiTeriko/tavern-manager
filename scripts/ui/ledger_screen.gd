class_name LedgerScreen
extends Node2D

const SETTLEMENT_BACKDROP := "res://assets/textures/ui/night_settlement/night_settlement_backdrop.png"
const SETTLEMENT_PANEL_STATS := "res://assets/textures/ui/night_settlement/night_settlement_panel_stats.png"
const SETTLEMENT_PANEL_FATES := "res://assets/textures/ui/night_settlement/night_settlement_panel_fates.png"
const CONTINUE_NORMAL := "res://assets/textures/ui/night_settlement/night_settlement_continue_normal.png"
const CONTINUE_HOVER := "res://assets/textures/ui/night_settlement/night_settlement_continue_hover.png"
const CONTINUE_PRESSED := "res://assets/textures/ui/night_settlement/night_settlement_continue_pressed.png"
const RESTART_DAY_NORMAL := "res://assets/textures/ui/restart_day/restart_day_button_normal.png"
const RESTART_DAY_HOVER := "res://assets/textures/ui/restart_day/restart_day_button_hover.png"
const RESTART_DAY_PRESSED := "res://assets/textures/ui/restart_day/restart_day_button_pressed.png"
const SILHOUETTE_SIZE := Vector2(144, 208)
const SILHOUETTE_ENTRY_X := 1368.0
const SILHOUETTE_QUEUE_X := 72.0
const SILHOUETTE_QUEUE_Y := 170.0
const SILHOUETTE_QUEUE_SPACING := 108.0
const SILHOUETTE_ARRIVAL_DURATION := 0.32
const SILHOUETTE_STEP_PAUSE := 0.08
const PIXEL_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const FATE_REVEAL_TEXT := "宿命轨迹已显现"
const FATE_PREVIEW_TEXT := "宿命轨迹即将显现"
const FATE_REVEAL_HOLD := 1.25
const FATE_REVEAL_FADE := 0.45
const RYAN_FATE_TEXTURES := {
	"uninformed_fallen": "res://assets/textures/endings/ryan/ryan_uninformed_fallen.png",
	"drugged_survivor": "res://assets/textures/endings/ryan/ryan_drugged_survivor.png",
	"informed_fallen": "res://assets/textures/endings/ryan/ryan_informed_fallen.png",
	"alternative_survivor": "res://assets/textures/endings/ryan/ryan_alternative_survivor.png",
}
const MIRA_FATE_TEXTURES := {
	"another_light_out": "res://assets/textures/endings/mira/mira_another_light_out.png",
	"closed_the_door": "res://assets/textures/endings/mira/mira_closed_the_door.png",
	"never_turned_back": "res://assets/textures/endings/mira/mira_never_turned_back.png",
	"she_finally_stopped": "res://assets/textures/endings/mira/mira_she_finally_stopped.png",
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
var _restart_day_btn: Button
var _settlement_backdrop: TextureRect
var _stats_panel_art: TextureRect
var _fate_panel_art: TextureRect
var _guest_silhouette_layer: Control
var _fate_reveal_overlay: Control
var _fate_cinematic: Control
var _ryan_fate_cinematic: Control
var _clock_rewind_overlay: Control
var _pending_fate_data: LedgerData = null
var _fate_presentation_shown := false
var _active_ledger_data: LedgerData = null
var _current_score := {"gold": 0, "reputation": 0, "guests": 0, "success": 0, "failed": 0}
var _target_score := {"gold": 0, "reputation": 0, "guests": 0, "success": 0, "failed": 0}
var _score_value_labels: Dictionary = {}
var _score_replay_active := false
var _score_replay_finished := false
var _score_replay_queued := false
var _score_replay_started := false
var _score_tween: Tween
var _stats_panel_base_position := Vector2.ZERO
var _stats_list_base_position := Vector2.ZERO
var _counter_impact_tween: Tween
var _fate_presentation_blockers := 0


func _ready() -> void:
	_title_label = $UI/TitleLabel
	_stats_list = $UI/StatsList
	_fate_title = $UI/FateTitle
	_fate_list = $UI/FateList
	_continue_btn = $UI/ContinueBtn
	_restart_day_btn = $UI/RestartDayBtn
	_settlement_backdrop = get_node_or_null("ArtLayer/SettlementBackdrop") as TextureRect
	_stats_panel_art = get_node_or_null("ArtLayer/StatsPanelArt") as TextureRect
	_fate_panel_art = get_node_or_null("ArtLayer/FatePanelArt") as TextureRect
	_guest_silhouette_layer = get_node_or_null("ArtLayer/GuestSilhouetteLayer") as Control
	_clock_rewind_overlay = get_node_or_null("ClockRewindOverlay") as Control

	_apply_settlement_art()
	_style_settlement_button(_continue_btn)
	_style_restart_day_button(_restart_day_btn)
	_continue_btn.pressed.connect(_on_continue)
	_restart_day_btn.pressed.connect(_on_restart_day)
	if _clock_rewind_overlay != null:
		_clock_rewind_overlay.connect("rewind_completed", Callable(self, "_on_clock_rewind_completed"))

	var gm = get_node("/root/GameManager")
	var tm = get_node_or_null("/root/TutorialManager")
	var should_start_ledger_tutorial := _should_start_ledger_tutorial(tm)
	var data = gm.current_ledger_data
	if data != null:
		_render(data)
		if should_start_ledger_tutorial:
			_pending_fate_data = data
		else:
			_show_fate_presentation(data)
			_queue_score_replay_after_presentations()

	if tm != null and not tm.first_ledger_shown:
		tm.first_ledger_shown = true
		tm._save_state()
		if should_start_ledger_tutorial:
			tm.tutorial_sequence_ended.connect(_on_ledger_tutorial_sequence_ended, CONNECT_ONE_SHOT)
			call_deferred("_trigger_ledger_tutorial")


func _render(data: LedgerData) -> void:
	_clear_container(_stats_list)
	_clear_container(_fate_list)
	_stats_list.add_theme_constant_override("separation", 0)
	_active_ledger_data = data
	_hide_legacy_aftermath_panel()
	_target_score = {
		"gold": data.gold_today,
		"reputation": data.rep_today,
		"guests": data.guests_served,
		"success": data.orders_success,
		"failed": data.orders_failed,
	}
	_reset_score_labels()

	_title_label.text = "第 %d 天 · 打烊回声" % data.day
	ThemeColors.style_header(_title_label, 28)
	_apply_pixel_font(_title_label)

	_add_score_row("gold", "金币", "+0 / %d" % data.gold_total)
	_add_score_row("reputation", "声望", "+0 / %d" % data.rep_total)
	_add_score_row("guests", "客人", "0 位")
	_add_score_row("success", "成功", "0 单")
	_add_score_row("failed", "失败", "0 单")
	if not data.rumor_summary.is_empty():
		_add_score_row("rumor", "今晚传闻影响", "待复盘")
	_create_guest_silhouettes(data.guest_entries)


func _should_start_ledger_tutorial(tm) -> bool:
	if tm == null or bool(tm.first_ledger_shown):
		return false
	if tm.has_method("is_group_completed") and tm.is_group_completed("ledger"):
		return false
	return true


func _show_fate_presentation(data: LedgerData) -> void:
	if data == null or _fate_presentation_shown:
		return
	_fate_presentation_shown = true
	_show_fate_cinematic_if_needed(data)
	_show_fate_reveal_notice_if_needed(data)
	_show_fate_preview_notice_if_needed(data)


func _on_ledger_tutorial_sequence_ended(group_id: String) -> void:
	if group_id != "ledger":
		return
	_show_fate_presentation(_pending_fate_data)
	_pending_fate_data = null
	_queue_score_replay_after_presentations()


func _show_fate_cinematic_if_needed(data: LedgerData) -> void:
	var fate := _find_first_cinematic_fate(data.npc_fates)
	if fate.is_empty():
		return
	var npc_id := String(fate.get("npc_id", ""))
	var route := String(fate.get("ending_key", ""))
	var texture_path := _fate_texture_path(npc_id, route)
	if texture_path == "":
		return
	var texture := _load_runtime_texture(texture_path)
	if texture == null:
		return
	_fate_cinematic = _create_fate_cinematic(_fate_cinematic_node_name(npc_id), texture, String(fate.get("fate_text", "")))
	if npc_id == "ryan":
		_ryan_fate_cinematic = _fate_cinematic
	_register_fate_presentation_blocker()
	add_child(_fate_cinematic)
	_play_fate_cinematic_intro(_fate_cinematic)


func _show_fate_reveal_notice_if_needed(data: LedgerData) -> void:
	if data.npc_fates.is_empty():
		return
	_fate_reveal_overlay = _create_fate_reveal_overlay()
	add_child(_fate_reveal_overlay)
	_play_fate_reveal_notice(_fate_reveal_overlay)


func _show_fate_preview_notice_if_needed(data: LedgerData) -> void:
	if not data.fate_warning_next_day or not data.npc_fates.is_empty():
		return
	var overlay := _create_fate_notice_overlay(
		"FatePreviewOverlay",
		"FatePreviewShade",
		"FatePreviewLabel",
		FATE_PREVIEW_TEXT
	)
	add_child(overlay)
	_play_fate_reveal_notice(overlay)


func _create_fate_reveal_overlay() -> Control:
	return _create_fate_notice_overlay(
		"FateRevealOverlay",
		"FateRevealShade",
		"FateRevealLabel",
		FATE_REVEAL_TEXT
	)


func _create_fate_notice_overlay(overlay_name: String, shade_name: String, label_name: String, label_text: String) -> Control:
	var overlay := Control.new()
	overlay.name = overlay_name
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.z_index = 400
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := ColorRect.new()
	shade.name = shade_name
	shade.position = Vector2.ZERO
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.0, 0.0, 0.0, 0.64)
	overlay.add_child(shade)

	var label := Label.new()
	label.name = label_name
	label.position = Vector2(0, 284)
	label.size = Vector2(1280, 112)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.96, 0.77, 0.36, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.008, 0.92))
	overlay.add_child(label)

	return overlay


func _play_fate_reveal_notice(overlay: Control) -> void:
	if overlay == null:
		return
	_register_fate_presentation_blocker()
	var tween := create_tween()
	tween.tween_interval(FATE_REVEAL_HOLD)
	tween.tween_property(overlay, "modulate:a", 0.0, FATE_REVEAL_FADE)
	tween.tween_callback(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
		_finish_fate_presentation_blocker()
	)


func _show_ryan_fate_cinematic_if_needed(data: LedgerData) -> void:
	_show_fate_cinematic_if_needed(data)


func _find_first_cinematic_fate(fates: Array) -> Dictionary:
	for fate in fates:
		if not fate is Dictionary:
			continue
		var data: Dictionary = fate
		var npc_id := String(data.get("npc_id", ""))
		var route := String(data.get("ending_key", ""))
		if _fate_texture_path(npc_id, route) != "":
			return data
	return {}


func _fate_texture_path(npc_id: String, route: String) -> String:
	match npc_id:
		"ryan":
			return String(RYAN_FATE_TEXTURES.get(route, ""))
		"mira":
			return String(MIRA_FATE_TEXTURES.get(route, ""))
	return ""


func _fate_cinematic_node_name(npc_id: String) -> String:
	match npc_id:
		"ryan":
			return "RyanFateCinematic"
		"mira":
			return "MiraFateCinematic"
	return "FateCinematic"


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


func _create_fate_cinematic(node_name: String, texture: Texture2D, fate_text: String) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.focus_mode = Control.FOCUS_ALL
	overlay.gui_input.connect(_on_fate_cinematic_gui_input)

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


func _create_ryan_fate_cinematic(texture: Texture2D, fate_text: String) -> Control:
	return _create_fate_cinematic("RyanFateCinematic", texture, fate_text)


func _play_fate_cinematic_intro(overlay: Control) -> void:
	var still := overlay.get_node_or_null("Still") as TextureRect
	var fate_label := overlay.get_node_or_null("FateLabel") as Label
	if still == null or fate_label == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(still, "modulate:a", 1.0, 0.55)
	tween.tween_property(fate_label, "modulate:a", 1.0, 0.55).set_delay(0.2)


func _play_ryan_fate_intro(overlay: Control) -> void:
	_play_fate_cinematic_intro(overlay)


func _dismiss_fate_cinematic() -> void:
	if _fate_cinematic == null or not is_instance_valid(_fate_cinematic):
		return
	var was_visible := _fate_cinematic.visible
	_fate_cinematic.visible = false
	_fate_cinematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if was_visible:
		_finish_fate_presentation_blocker()


func _dismiss_ryan_fate_cinematic() -> void:
	if _ryan_fate_cinematic == null or not is_instance_valid(_ryan_fate_cinematic):
		return
	if _ryan_fate_cinematic == _fate_cinematic:
		_dismiss_fate_cinematic()
		return
	_ryan_fate_cinematic.visible = false
	_ryan_fate_cinematic.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_fate_cinematic_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_fate_cinematic()
		get_viewport().set_input_as_handled()


func _on_ryan_fate_cinematic_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_ryan_fate_cinematic()
		get_viewport().set_input_as_handled()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	return texture


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
		_stats_panel_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_stats_panel_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_stats_panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fate_panel_art != null:
		_fate_panel_art.texture = _load_texture(SETTLEMENT_PANEL_FATES)
		_fate_panel_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fate_panel_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fate_panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _hide_legacy_aftermath_panel() -> void:
	if _fate_panel_art != null:
		_fate_panel_art.visible = false
	if _fate_title != null:
		_apply_pixel_font(_fate_title)
		_fate_title.visible = false
	if _fate_list != null:
		_fate_list.visible = false


func _reset_score_labels() -> void:
	_current_score = {"gold": 0, "reputation": 0, "guests": 0, "success": 0, "failed": 0}
	_score_value_labels.clear()
	_score_replay_active = false
	_score_replay_finished = false
	_score_replay_queued = false
	_score_replay_started = false
	_fate_presentation_blockers = 0


func _add_score_row(icon_id: String, label_text: String, value_text: String) -> void:
	_add_stat_row(icon_id, label_text, value_text)
	if _stats_list.get_child_count() <= 0:
		return
	var row := _stats_list.get_child(_stats_list.get_child_count() - 1) as HBoxContainer
	if row == null:
		return
	for sub in row.get_children():
		if sub is Label and (sub as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			_score_value_labels[icon_id] = sub
			return


func _create_guest_silhouettes(entries: Array) -> void:
	if _guest_silhouette_layer == null:
		return
	for child in _guest_silhouette_layer.get_children():
		child.queue_free()
	var count := entries.size()
	if count <= 0:
		return
	var spacing := minf(SILHOUETTE_QUEUE_SPACING, 880.0 / maxf(float(count), 1.0))
	for i in range(count):
		var entry: Dictionary = entries[i]
		var figure := TextureRect.new()
		figure.name = "GuestSilhouette%d" % (i + 1)
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		figure.size = SILHOUETTE_SIZE
		var entry_position := Vector2(SILHOUETTE_ENTRY_X + float(i) * 24.0, SILHOUETTE_QUEUE_Y + float(i % 2) * 6.0)
		var target_position := Vector2(SILHOUETTE_QUEUE_X + float(i) * spacing, SILHOUETTE_QUEUE_Y + float(i % 2) * 6.0)
		figure.position = entry_position
		figure.modulate = Color(0.005, 0.005, 0.004, 0.9)
		figure.texture = _load_guest_texture(entry)
		figure.set_meta("entry_position", entry_position)
		figure.set_meta("target_position", target_position)
		figure.set_meta("arrival_duration", SILHOUETTE_ARRIVAL_DURATION)
		_guest_silhouette_layer.add_child(figure)


func _load_guest_texture(entry: Dictionary) -> Texture2D:
	var texture_id := String(entry.get("portrait_id", ""))
	if texture_id == "":
		texture_id = String(entry.get("npc_id", ""))
	var texture_key := _guest_texture_key(texture_id)
	var texture_path := "res://assets/textures/characters/%s.png" % texture_key
	if ResourceLoader.exists(texture_path):
		return _load_runtime_texture(texture_path)
	return _load_runtime_texture("res://assets/textures/characters/regular_noel_neutral.png")


func _guest_texture_key(npc_id: String) -> String:
	if npc_id == "ryan":
		return "ryan_neutral"
	if npc_id == "mira":
		return "mira_neutral"
	if npc_id == "toby":
		return "toby_neutral"
	if npc_id == "grey_ledger_lady":
		return "grey_ledger_lady_neutral"
	if npc_id.begins_with("regular_"):
		return "%s_neutral" % npc_id
	return npc_id


func _start_score_replay() -> void:
	if _active_ledger_data == null:
		return
	if _score_replay_started or _score_replay_finished:
		return
	_score_replay_started = true
	_score_replay_active = true
	_score_replay_finished = false
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	var entries: Array = _active_ledger_data.guest_entries
	if entries.is_empty():
		_score_tween.tween_callback(_complete_score_replay)
		return
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var figure := _guest_silhouette_at(i)
		if figure != null:
			_score_tween.tween_callback(_set_silhouette_entry.bind(i))
			_score_tween.tween_property(figure, "position", _silhouette_target_position(figure), SILHOUETTE_ARRIVAL_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_score_tween.tween_callback(_apply_guest_replay_step.bind(i, entry))
		_score_tween.tween_interval(SILHOUETTE_STEP_PAUSE)
	_score_tween.tween_callback(_apply_rumor_replay_summary)
	_score_tween.tween_callback(_complete_score_replay)


func _apply_guest_replay_step(index: int, entry: Dictionary) -> void:
	var changed_keys := _changed_score_keys(entry)
	_apply_guest_entry_to_score(entry, changed_keys)
	_set_silhouette_final(index)
	_play_counter_impact(changed_keys)


func _apply_guest_entry_to_score(entry: Dictionary, changed_keys: Array = []) -> void:
	_current_score["gold"] = int(_current_score["gold"]) + int(entry.get("gold_delta", 0))
	_current_score["reputation"] = int(_current_score["reputation"]) + int(entry.get("rep_delta", 0))
	_current_score["guests"] = int(_current_score["guests"]) + int(entry.get("served_delta", 0))
	_current_score["success"] = int(_current_score["success"]) + int(entry.get("success_delta", 0))
	_current_score["failed"] = int(_current_score["failed"]) + int(entry.get("failed_delta", 0))
	_refresh_score_labels(changed_keys)


func _changed_score_keys(entry: Dictionary) -> Array:
	var keys: Array = []
	if int(entry.get("gold_delta", 0)) != 0:
		keys.append("gold")
	if int(entry.get("rep_delta", 0)) != 0:
		keys.append("reputation")
	if int(entry.get("served_delta", 0)) != 0:
		keys.append("guests")
	if int(entry.get("success_delta", 0)) != 0:
		keys.append("success")
	if int(entry.get("failed_delta", 0)) != 0:
		keys.append("failed")
	return keys


func _guest_silhouette_at(index: int) -> TextureRect:
	if _guest_silhouette_layer == null or index < 0 or index >= _guest_silhouette_layer.get_child_count():
		return null
	return _guest_silhouette_layer.get_child(index) as TextureRect


func _set_silhouette_entry(index: int) -> void:
	var figure := _guest_silhouette_at(index)
	if figure == null:
		return
	var entry_position = figure.get_meta("entry_position", figure.position)
	if entry_position is Vector2:
		figure.position = entry_position


func _silhouette_target_position(figure: TextureRect) -> Vector2:
	var target = figure.get_meta("target_position", figure.position)
	if target is Vector2:
		return target
	return figure.position


func _set_silhouette_final(index: int) -> void:
	var figure := _guest_silhouette_at(index)
	if figure == null:
		return
	figure.position = _silhouette_target_position(figure)


func _refresh_score_labels(changed_keys: Array = []) -> void:
	if _active_ledger_data == null:
		return
	_set_score_text("gold", "%+d / %d" % [int(_current_score["gold"]), _active_ledger_data.gold_total], changed_keys.has("gold"))
	_set_score_text("reputation", "%+d / %d" % [int(_current_score["reputation"]), _active_ledger_data.rep_total], changed_keys.has("reputation"))
	_set_score_text("guests", "%d 位" % int(_current_score["guests"]), changed_keys.has("guests"))
	_set_score_text("success", "%d 单" % int(_current_score["success"]), changed_keys.has("success"))
	_set_score_text("failed", "%d 单" % int(_current_score["failed"]), changed_keys.has("failed"))


func _apply_rumor_replay_summary() -> void:
	if _active_ledger_data == null or _active_ledger_data.rumor_summary.is_empty():
		return
	var changed := int(_active_ledger_data.rumor_summary.get("hit_count", 0)) > 0
	_refresh_rumor_summary_label(changed)
	if changed:
		_play_counter_impact(["rumor"])


func _refresh_rumor_summary_label(punch: bool = false) -> void:
	if _active_ledger_data == null:
		return
	var label := _score_value_labels.get("rumor", null) as Label
	if label == null:
		return
	label.text = _rumor_summary_text(_active_ledger_data.rumor_summary)
	if punch:
		_punch_score_label(label)


func _rumor_summary_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return ""
	var hit_count := int(summary.get("hit_count", 0))
	if hit_count <= 0:
		var missed := _summary_names_text(summary.get("missed_customers", []))
		if missed != "":
			return "未命中 · %s 来了但菜单没对上" % missed
		if _summary_names_text(summary.get("affected_customers", [])) != "":
			return "未命中 · 相关客人未到店"
		return "未命中 · 菜单未贴近"
	var parts := PackedStringArray()
	parts.append("命中 %d 次" % hit_count)
	parts.append("+%dG" % int(summary.get("bonus_gold", 0)))
	parts.append("%+d REP" % int(summary.get("bonus_rep", 0)))
	var tags := _summary_tags_text(summary.get("tags", []))
	if tags != "":
		parts.append(tags)
	var matched := _summary_names_text(summary.get("matched_customers", []))
	if matched != "":
		parts.append("影响 " + matched)
	var memory := _summary_first_text(summary.get("memory_notes", []))
	if memory != "":
		parts.append(memory)
	var word_of_mouth := _summary_first_text(summary.get("word_of_mouth_labels", []))
	if word_of_mouth != "":
		parts.append(word_of_mouth)
	return " ".join(parts)


func _summary_tags_text(tags) -> String:
	if not tags is Array:
		return ""
	var result := PackedStringArray()
	for tag in tags:
		var tag_text := String(tag)
		if tag_text == "":
			continue
		result.append(tag_text)
		if result.size() >= 3:
			break
	return "/".join(result)


func _summary_names_text(names) -> String:
	if not names is Array:
		return ""
	var result := PackedStringArray()
	for name in names:
		var text := String(name)
		if text == "":
			continue
		result.append(text)
		if result.size() >= 3:
			break
	return "/".join(result)


func _summary_first_text(values) -> String:
	if not values is Array:
		return ""
	for value in values:
		var text := String(value)
		if text != "":
			return text
	return ""


func _set_score_text(icon_id: String, text: String, punch: bool) -> void:
	var label := _score_value_labels.get(icon_id, null) as Label
	if label == null:
		return
	label.text = text
	if punch:
		_punch_score_label(label)


func _punch_score_label(label: Label) -> void:
	label.scale = Vector2(1.18, 1.18)
	label.modulate = Color(1.0, 0.78, 0.32, 1.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, 0.18)


func _play_counter_impact(changed_keys: Array) -> void:
	set_meta("last_counter_impact_keys", changed_keys.duplicate())
	if changed_keys.is_empty():
		return
	if _stats_panel_art != null:
		if not _stats_panel_art.has_meta("impact_base_position"):
			_stats_panel_art.set_meta("impact_base_position", _stats_panel_art.position)
		_stats_panel_base_position = _stats_panel_art.get_meta("impact_base_position", _stats_panel_art.position)
	if _stats_list != null:
		if not _stats_list.has_meta("impact_base_position"):
			_stats_list.set_meta("impact_base_position", _stats_list.position)
		_stats_list_base_position = _stats_list.get_meta("impact_base_position", _stats_list.position)
	if _counter_impact_tween != null and _counter_impact_tween.is_valid():
		_counter_impact_tween.kill()
	var bump := Vector2(-6.0, -2.0)
	if _stats_panel_art != null:
		_stats_panel_art.position = _stats_panel_base_position + bump
	if _stats_list != null:
		_stats_list.position = _stats_list_base_position + bump
	_counter_impact_tween = create_tween().set_parallel(true)
	if _stats_panel_art != null:
		_counter_impact_tween.tween_property(_stats_panel_art, "position", _stats_panel_base_position, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _stats_list != null:
		_counter_impact_tween.tween_property(_stats_list, "position", _stats_list_base_position, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _complete_score_replay() -> void:
	if _active_ledger_data == null:
		return
	_score_replay_queued = false
	_score_replay_started = true
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	var silhouette_count := 0
	if _guest_silhouette_layer != null:
		silhouette_count = _guest_silhouette_layer.get_child_count()
	for i in range(silhouette_count):
		_set_silhouette_final(i)
	_current_score = _target_score.duplicate()
	_refresh_score_labels([])
	_refresh_rumor_summary_label(false)
	_score_replay_active = false
	_score_replay_finished = true


func _queue_score_replay_after_presentations() -> void:
	if _score_replay_started or _score_replay_finished:
		return
	_score_replay_queued = true
	_maybe_start_queued_score_replay()


func _register_fate_presentation_blocker() -> void:
	_fate_presentation_blockers += 1


func _finish_fate_presentation_blocker() -> void:
	_fate_presentation_blockers = maxi(0, _fate_presentation_blockers - 1)
	_maybe_start_queued_score_replay()


func _maybe_start_queued_score_replay() -> void:
	if not _score_replay_queued:
		return
	if _fate_presentation_blockers > 0:
		return
	if _score_replay_started or _score_replay_finished:
		_score_replay_queued = false
		return
	_score_replay_queued = false
	call_deferred("_start_score_replay")


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


func _style_restart_day_button(button: Button) -> void:
	if button == null:
		return
	button.text = "重写今日"
	button.add_theme_stylebox_override("normal", _make_texture_style(RESTART_DAY_NORMAL))
	button.add_theme_stylebox_override("hover", _make_texture_style(RESTART_DAY_HOVER))
	button.add_theme_stylebox_override("pressed", _make_texture_style(RESTART_DAY_PRESSED))
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.focus_mode = Control.FOCUS_ALL


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_stat_row(icon_id: String, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.add_theme_constant_override("separation", 10)

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
	name_label.text = "%s 路 %s" % [String(fate.get("npc_name", "")), String(fate.get("npc_title", ""))]
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
	if _score_replay_active:
		_complete_score_replay()
		return
	var gm = get_node("/root/GameManager")
	gm.day_cycle.next_phase()


func _on_restart_day() -> void:
	if _score_replay_active:
		_complete_score_replay()
	if _clock_rewind_overlay == null:
		return
	var gm = get_node("/root/GameManager")
	_clock_rewind_overlay.call("open_with_events", gm.get_current_day_events())


func _on_clock_rewind_completed() -> void:
	var gm = get_node("/root/GameManager")
	gm.restart_current_day()


func _unhandled_input(event: InputEvent) -> void:
	if _fate_cinematic == null or not is_instance_valid(_fate_cinematic) or not _fate_cinematic.visible:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo
	if pressed:
		_dismiss_fate_cinematic()
		get_viewport().set_input_as_handled()


func _trigger_ledger_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return

	var rects = {
		"UI": [90, 50, 1100, 560],
	}
	tm.start_tutorial("ledger", rects)
