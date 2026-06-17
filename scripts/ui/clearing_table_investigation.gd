class_name ClearingTableInvestigation
extends InvestigationScene

const STAMP_STATION_SCENE := preload("res://scenes/ui/components/StampPressStation.tscn")
const SLOT_RADIUS := 64.0
const SLOT_POSITIONS := [
	Vector2(500, 340),
	Vector2(630, 310),
	Vector2(760, 310),
	Vector2(890, 310),
	Vector2(1030, 302),
]
const TRAY_POSITIONS := [
	Vector2(170, 270),
	Vector2(170, 375),
	Vector2(170, 480),
	Vector2(325, 540),
	Vector2(480, 540),
]
const LEAVE_BUTTON_NORMAL := "res://assets/ui/generated/investigation/clearing_table/ui/leave_button_normal.png"
const LEAVE_BUTTON_HOVER := "res://assets/ui/generated/investigation/clearing_table/ui/leave_button_hover.png"
const LEAVE_BUTTON_PRESSED := "res://assets/ui/generated/investigation/clearing_table/ui/leave_button_pressed.png"
const LEAVE_BUTTON_SIZE := Vector2(280, 100)
const LEAVE_BUTTON_BOTTOM_RIGHT := Vector2(1240, 684)
const CARD_LABEL_SIZE := Vector2(150, 26)
const SLOT_LABEL_SIZE := Vector2(120, 26)
const SLOT_LABEL_OFFSET := Vector2(-60, 72)
const STAMP_STATION_POSITION := Vector2(1100, 350)
const STAMP_SOCKET_FALLBACK_OFFSET := Vector2(0, 70)
const STAMP_OUTPUT_POSITION := Vector2(970, 500)
const STAMP_OUTPUT_SCALE := Vector2(0.82, 0.82)
const STAMP_READY_OFFSET := Vector2(0, -58)
const STAMP_PRESS_Y_MARGIN := 10.0
const STAMP_PRESS_X_RADIUS := 46.0
const STAMP_PRESS_ZONE_SIZE := Vector2(108, 92)
const STAMP_PRESS_GUIDE_OVERSHOOT := 8.0
const STAMP_PRESS_IDLE_COLOR := Color(0.18, 0.11, 0.07, 0.42)
const STAMP_PRESS_ACTIVE_COLOR := Color(0.72, 0.42, 0.18, 0.58)
const STAMP_PRESS_BLOCKED_COLOR := Color(0.58, 0.10, 0.08, 0.56)

const ROUND_SPECS := [
	{
		"title": "莱恩案卷",
		"document": "grey_payout_closure",
		"required_documents": ["grey_ryan_case_number", "grey_old_payout_register", "grey_missing_page"],
		"locked_hint": "先去赔付登记处抄下莱恩案卷、旧赔付登记和缺页名单，再回来压出赔付顺序。",
		"intro": "清算台等着第一批旧案：姓名、地点、状态、赔付和结案章。",
		"complete": "莱恩的案卷先写赔付，再被盖成结案。",
		"items": [
			{"tag": "clearing_ryan_name", "label": "莱恩牌", "slot_label": "名牌", "slot": 0, "size": Vector2(224, 104), "obs": "姓名牌被磨得很浅，只剩边角的旧编号。"},
			{"tag": "clearing_north_mine", "label": "北矿道", "slot_label": "案源", "slot": 1, "size": Vector2(224, 144), "obs": "北矿道路线卡被放进同一批清算。"},
			{"tag": "clearing_unreturned", "label": "未归", "slot_label": "状态", "slot": 2, "size": Vector2(176, 112), "obs": "状态卡没有写死亡，只写未归。"},
			{"tag": "clearing_payout_slip", "label": "赔付", "slot_label": "待盖", "slot": 3, "stamp_target": true, "size": Vector2(168, 112), "obs": "赔付款被送到压章口，等证据放齐后才能落印。"},
		],
	},
	{
		"title": "托比委托",
		"document": "grey_renamed_escort",
		"required_documents": ["grey_blacktooth_batch", "grey_closure_method"],
		"locked_hint": "先查黑齿转运账，拿到批次号和封账办法，再回来压出托比委托的改名证明。",
		"intro": "第二批账把一个孩子的护送委托改成临时转运。",
		"complete": "托比的名字被挪进临时人名栏，护送委托被改名。",
		"items": [
			{"tag": "clearing_toby_name", "label": "托比牌", "slot_label": "名牌", "slot": 0, "size": Vector2(224, 104), "obs": "这个名字写得太新，像刚被补进账里。"},
			{"tag": "clearing_blacktooth_batch", "label": "黑齿批次", "slot_label": "案源", "slot": 1, "size": Vector2(224, 144), "obs": "黑齿矿脉批次号和莱恩案卷压在同一条轨上。"},
			{"tag": "clearing_high_pay", "label": "高额护送", "slot_label": "诱因", "slot": 2, "size": Vector2(176, 112), "obs": "高额报酬卡被压得很平，像诱饵也像凭据。"},
			{"tag": "clearing_temp_name", "label": "临时人名", "slot_label": "待盖", "slot": 3, "stamp_target": true, "size": Vector2(224, 104), "obs": "临时人名牌压进盖章位，就能遮住真正的委托。"},
		],
	},
	{
		"title": "米拉供应",
		"document": "grey_supply_stamp",
		"required_locations": ["mira_supply_copy"],
		"locked_hint": "先查米拉旧供应副本，确认旧协议和押金栏位，再回来压出灰契印。",
		"intro": "最后一批账把供应协议、押金和灰契印接到旧路赔付栏。",
		"complete": "米拉的供应协议背面盖着同一枚灰契印。",
		"items": [
			{"tag": "clearing_mira_name", "label": "米拉牌", "slot_label": "名牌", "slot": 0, "size": Vector2(176, 112), "obs": "米拉的名字没有在正面，压痕在背面。"},
			{"tag": "clearing_deposit_token", "label": "旧路押金", "slot_label": "入账", "slot": 1, "size": Vector2(136, 168), "obs": "押金牌被接到赔付栏，像一条备用路。"},
			{"tag": "clearing_supply_contract", "label": "供应协议", "slot_label": "待盖", "slot": 2, "stamp_target": true, "size": Vector2(168, 192), "obs": "旧供应协议进了压章口，背面才会留下灰契印。"},
		],
	},
]

var _round_index := 0
var _items_by_tag: Dictionary = {}
var _locked_tags: Dictionary = {}
var _placed_target_tags: Dictionary = {}
var _stamp_completed_tags: Dictionary = {}
var _complete := false
var _awaiting_next_round := false
var _slot_label_root: Control = null
var _stamp_station = null
var _pending_stamp_tags: Dictionary = {}
var _stamp_imprints_by_tag: Dictionary = {}
var _stamped_outputs_by_tag: Dictionary = {}
var _stamp_press_zone_root: Node2D = null
var _stamp_press_zones_by_tag: Dictionary = {}
var _stamp_press_progress_by_tag: Dictionary = {}
var _round_locked := false


func _setup_scene() -> void:
	_apply_clearing_table_ui_style()
	_ensure_stamp_station()
	_spawn_round()


func _input(event: InputEvent) -> void:
	if _awaiting_next_round and _is_round_advance_event(event):
		_advance_to_next_round()
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func get_round_count() -> int:
	return ROUND_SPECS.size()


func get_current_round_index() -> int:
	return _round_index


func is_complete() -> bool:
	return _complete


func current_round_item_tags() -> Array:
	var tags := []
	if _complete or _awaiting_next_round or _round_locked or _round_index >= ROUND_SPECS.size():
		return tags
	for item in ROUND_SPECS[_round_index]["items"]:
		tags.append(String(item["tag"]))
	return tags


func is_current_round_item(item_tag: String) -> bool:
	return current_round_item_tags().has(item_tag)


func is_stamp_target_item(item_tag: String) -> bool:
	if _round_index >= ROUND_SPECS.size():
		return false
	for item in ROUND_SPECS[_round_index]["items"]:
		if String(item["tag"]) == item_tag:
			return bool(item.get("stamp_target", false))
	return false


func slot_position_for_item(item_tag: String) -> Vector2:
	if _round_index >= ROUND_SPECS.size():
		return Vector2.ZERO
	for item in ROUND_SPECS[_round_index]["items"]:
		if String(item["tag"]) == item_tag:
			return _slot_position_for_spec(item)
	return Vector2.ZERO


func stamp_output_position() -> Vector2:
	return STAMP_OUTPUT_POSITION


func is_stamp_waiting_for_press(item_tag: String) -> bool:
	return _pending_stamp_tags.has(item_tag) and not _locked_tags.has(item_tag)


func stamp_press_progress(item_tag: String) -> float:
	return float(_stamp_press_progress_by_tag.get(item_tag, 0.0))


func _apply_clearing_table_ui_style() -> void:
	ThemeColors.style_brush_label(_obs_label, 20, ThemeColors.TEXT_LIGHT)
	ThemeColors.style_brush_label(_hint_label, 16, ThemeColors.TEXT_SUBTITLE)
	_apply_label_outline(_obs_label)
	_apply_label_outline(_hint_label)
	_apply_leave_button_style()


func _apply_leave_button_style() -> void:
	var font := ThemeColors.menu_font()
	if font != null:
		_leave_btn.add_theme_font_override("font", font)
	_leave_btn.add_theme_font_size_override("font_size", 18)
	_leave_btn.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_leave_btn.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	_leave_btn.add_theme_color_override("font_pressed_color", ThemeColors.AMBER_BRIGHT)
	_leave_btn.add_theme_stylebox_override("normal", _leave_button_stylebox(LEAVE_BUTTON_NORMAL))
	_leave_btn.add_theme_stylebox_override("hover", _leave_button_stylebox(LEAVE_BUTTON_HOVER))
	_leave_btn.add_theme_stylebox_override("pressed", _leave_button_stylebox(LEAVE_BUTTON_PRESSED))
	_leave_btn.add_theme_stylebox_override("disabled", _leave_button_stylebox(LEAVE_BUTTON_NORMAL))
	_leave_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_leave_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_leave_btn.offset_right = LEAVE_BUTTON_BOTTOM_RIGHT.x
	_leave_btn.offset_bottom = LEAVE_BUTTON_BOTTOM_RIGHT.y
	_leave_btn.offset_left = LEAVE_BUTTON_BOTTOM_RIGHT.x - LEAVE_BUTTON_SIZE.x
	_leave_btn.offset_top = LEAVE_BUTTON_BOTTOM_RIGHT.y - LEAVE_BUTTON_SIZE.y


func _leave_button_stylebox(path: String) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		style = StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, 58.0)
	style.set_content_margin(SIDE_RIGHT, 58.0)
	style.set_content_margin(SIDE_TOP, 30.0)
	style.set_content_margin(SIDE_BOTTOM, 30.0)
	return style


func _apply_label_outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.018, 0.015, 0.9))


func _style_clearing_helper_label(label: Label, font_size: int, color: Color) -> void:
	var font := ThemeColors.menu_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.018, 0.015, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _spawn_round() -> void:
	_clear_round_items()
	_clear_slot_labels()
	_locked_tags.clear()
	_placed_target_tags.clear()
	_stamp_completed_tags.clear()
	_pending_stamp_tags.clear()
	_stamp_press_progress_by_tag.clear()
	_items_by_tag.clear()
	_awaiting_next_round = false
	_round_locked = false
	if _stamp_station != null and is_instance_valid(_stamp_station):
		_stamp_station.call("disarm")
	_round_index = _first_unfinished_round_index()
	if _round_index >= ROUND_SPECS.size():
		_complete = true
		_obs_label.text = "三批灰账都已经从清算台吐出。"
		_hint_label.text = "带着这些窄纸回到伊芙琳面前，账本就不再只属于公会。"
		return
	var round: Dictionary = ROUND_SPECS[_round_index]
	if not _round_requirements_met(round):
		_round_locked = true
		_obs_label.text = String(round["intro"])
		_hint_label.text = String(round.get("locked_hint", "先把相关旧账查清，再回来使用清算台。"))
		return
	_obs_label.text = String(round["intro"])
	_hint_label.text = "先按槽位放齐证据纸，再把待盖纸送到压章口，按下压杆。"
	_create_slot_labels(round)
	var index := 0
	for item_spec in round["items"]:
		var tag := String(item_spec["tag"])
		var pos: Vector2 = TRAY_POSITIONS[index % TRAY_POSITIONS.size()]
		var item := _spawn_item(tag, "clearing_record", item_spec["size"] as Vector2,
			Color(0.52, 0.44, 0.28), String(item_spec["label"]), String(item_spec["obs"]), pos)
		_attach_card_label(item, String(item_spec["label"]), item_spec["size"] as Vector2)
		_prepare_item_at(item, pos)
		_items_by_tag[tag] = item
		index += 1


func _clear_round_items() -> void:
	for item in _items_by_tag.values():
		if is_instance_valid(item):
			item.queue_free()
	for imprint in _stamp_imprints_by_tag.values():
		if is_instance_valid(imprint):
			imprint.queue_free()
	for output in _stamped_outputs_by_tag.values():
		if is_instance_valid(output):
			output.queue_free()
	_clear_stamp_press_zones()
	_items_by_tag.clear()
	_stamp_imprints_by_tag.clear()
	_stamped_outputs_by_tag.clear()
	_stamp_press_progress_by_tag.clear()


func _ensure_slot_label_root() -> Control:
	if _slot_label_root != null and is_instance_valid(_slot_label_root):
		return _slot_label_root
	_slot_label_root = Control.new()
	_slot_label_root.name = "SlotLabels"
	_slot_label_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_slot_label_root)
	return _slot_label_root


func _clear_slot_labels() -> void:
	if _slot_label_root == null or not is_instance_valid(_slot_label_root):
		return
	for child in _slot_label_root.get_children():
		child.queue_free()


func _create_slot_labels(round: Dictionary) -> void:
	var root := _ensure_slot_label_root()
	var labels_by_slot := {}
	for item_spec in round["items"]:
		labels_by_slot[int(item_spec["slot"])] = {
			"text": String(item_spec.get("slot_label", item_spec["label"])),
			"position": _slot_position_for_spec(item_spec),
		}
	for slot_index in labels_by_slot.keys():
		var entry: Dictionary = labels_by_slot[slot_index]
		var label := Label.new()
		label.text = String(entry["text"])
		label.position = (entry["position"] as Vector2) + SLOT_LABEL_OFFSET
		label.size = SLOT_LABEL_SIZE
		label.z_index = 30
		_style_clearing_helper_label(label, 14, ThemeColors.TEXT_SUBTITLE)
		root.add_child(label)


func _attach_card_label(item: MineItem, text: String, item_size: Vector2) -> void:
	var label := Label.new()
	label.name = "ClearingCardLabel"
	label.text = text
	label.position = Vector2(-CARD_LABEL_SIZE.x * 0.5, -item_size.y * 0.5 - 24.0)
	label.size = CARD_LABEL_SIZE
	label.z_index = 60
	_style_clearing_helper_label(label, 13, ThemeColors.TEXT_LIGHT)
	item.add_child(label)


func _prepare_item_at(item: MineItem, pos: Vector2) -> void:
	item.gravity_scale = 0.0
	item.linear_velocity = Vector2.ZERO
	item.angular_velocity = 0.0
	item.global_position = pos
	item.global_rotation = 0.0
	item.freeze = true


func _priority_kinds() -> Array:
	return ["clearing_record"]


func _can_pickup(item: MineItem) -> bool:
	if _complete or _awaiting_next_round:
		return false
	if not is_current_round_item(item.item_tag):
		return false
	if _placed_target_tags.has(item.item_tag):
		return false
	return not _locked_tags.has(item.item_tag)


func _investigation_physics(_delta: float) -> void:
	if _complete or _awaiting_next_round:
		return
	if _drag_ctrl.is_dragging():
		return
	_check_slots()


func _check_slots() -> void:
	if _round_index >= ROUND_SPECS.size():
		return
	var round: Dictionary = ROUND_SPECS[_round_index]
	for item_spec in round["items"]:
		var tag := String(item_spec["tag"])
		if _locked_tags.has(tag):
			continue
		var item: MineItem = _items_by_tag.get(tag, null)
		if not is_instance_valid(item):
			continue
		var target: Vector2 = _slot_position_for_spec(item_spec)
		if _placed_target_tags.has(tag):
			continue
		if item.global_position.distance_to(target) <= SLOT_RADIUS:
			if _is_stamp_target_spec(item_spec):
				_place_target_paper(item, target, item_spec)
			else:
				_lock_item_at(item, target)
				_locked_tags[tag] = true
				_obs_label.text = String(item_spec["obs"])
	_update_stamp_station_availability()


func _is_stamp_target_spec(item_spec: Dictionary) -> bool:
	return bool(item_spec.get("stamp_target", false))


func _slot_position_for_spec(item_spec: Dictionary) -> Vector2:
	if _is_stamp_target_spec(item_spec):
		return _stamp_socket_position()
	return SLOT_POSITIONS[int(item_spec["slot"])]


func _stamp_socket_position() -> Vector2:
	_ensure_stamp_station()
	if _stamp_station != null and is_instance_valid(_stamp_station) \
			and _stamp_station.has_method("socket_global_position"):
		return _stamp_station.call("socket_global_position")
	return STAMP_STATION_POSITION + STAMP_SOCKET_FALLBACK_OFFSET


func _current_target_tag() -> String:
	if _round_index >= ROUND_SPECS.size():
		return ""
	for item_spec in ROUND_SPECS[_round_index]["items"]:
		if _is_stamp_target_spec(item_spec):
			return String(item_spec["tag"])
	return ""


func _place_target_paper(item: MineItem, target: Vector2, item_spec: Dictionary) -> void:
	var tag := String(item_spec["tag"])
	_lock_item_at(item, target)
	_set_card_label_visible(item, false)
	item.z_index = 2
	_placed_target_tags[tag] = true
	_obs_label.text = String(item_spec["obs"])
	_ensure_stamp_station()
	_update_stamp_station_availability()
	if _all_non_target_items_locked():
		_hint_label.text = "待盖纸已经入位。按住右侧压杆往下压到底，再松手。"
	else:
		_hint_label.text = "待盖纸已经入位。先把其它证据纸放齐，压杆才会落下。"


func _update_stamp_station_availability() -> void:
	if _stamp_station == null or not is_instance_valid(_stamp_station):
		return
	var tag := _current_target_tag()
	if tag == "":
		_stamp_station.call("disarm")
		return
	if _stamp_completed_tags.has(tag):
		return
	if not _placed_target_tags.has(tag):
		_stamp_station.call("disarm")
		return
	var item: MineItem = _items_by_tag.get(tag, null)
	if not is_instance_valid(item):
		_stamp_station.call("disarm")
		return
	var can_press := _all_non_target_items_locked()
	if String(_stamp_station.call("target_tag")) != tag:
		_stamp_station.call("arm", tag, item, can_press)
	else:
		_stamp_station.call("set_press_enabled", can_press)


func _all_non_target_items_locked() -> bool:
	if _round_index >= ROUND_SPECS.size():
		return false
	for item_spec in ROUND_SPECS[_round_index]["items"]:
		if _is_stamp_target_spec(item_spec):
			continue
		if not _locked_tags.has(String(item_spec["tag"])):
			return false
	return true


func _first_unfinished_round_index() -> int:
	for i in range(ROUND_SPECS.size()):
		var round: Dictionary = ROUND_SPECS[i]
		if not _owns_document(String(round["document"])):
			return i
	return ROUND_SPECS.size()


func _round_requirements_met(round: Dictionary) -> bool:
	for document_id in round.get("required_documents", []):
		if not _owns_document(String(document_id)):
			return false
	for location_id in round.get("required_locations", []):
		if not _is_location_completed(String(location_id)):
			return false
	return true


func _owns_document(document_id: String) -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.documents == null:
		return false
	return gm.documents.owns_document(document_id)


func _is_location_completed(location_id: String) -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.day_map == null:
		return false
	return gm.day_map.is_completed(location_id)


func _ensure_stamp_station() -> Node:
	if _stamp_station != null and is_instance_valid(_stamp_station):
		return _stamp_station
	_stamp_station = STAMP_STATION_SCENE.instantiate()
	_stamp_station.name = "StampPressStation"
	_stamp_station.global_position = STAMP_STATION_POSITION
	_world.add_child(_stamp_station)
	_stamp_station.connect("stamp_completed", Callable(self, "_on_stamp_station_completed"))
	return _stamp_station


func _on_stamp_station_completed(item_tag: String) -> void:
	if not _placed_target_tags.has(item_tag):
		return
	if not _all_non_target_items_locked():
		_update_stamp_station_availability()
		_hint_label.text = "证据纸还没放齐，这枚印不能入账。"
		return
	_stamp_completed_tags[item_tag] = true
	_locked_tags[item_tag] = true
	_create_stamped_output(item_tag)
	_hint_label.text = "印已经压到目标纸上，盖好的窄纸从出纸口弹了出来。"
	_complete_round()


func _is_stamp_spec(item_spec: Dictionary) -> bool:
	return String(item_spec.get("tag", "")).ends_with("_stamp")


func _stamp_ready_position(target: Vector2) -> Vector2:
	return target + STAMP_READY_OFFSET


func _dragged_pending_stamp() -> MineItem:
	if not _drag_ctrl.is_dragging():
		return null
	var body := _drag_ctrl.get_body()
	if not (body is MineItem):
		return null
	var item := body as MineItem
	if not _pending_stamp_tags.has(item.item_tag):
		return null
	return item


func _update_dragged_stamp_press_feedback(raw_pos: Vector2) -> bool:
	var item := _dragged_pending_stamp()
	if item == null:
		return false
	_update_stamp_press_drag_feedback(item, raw_pos)
	return true


func _update_stamp_press_drag_feedback(item: MineItem, raw_pos: Vector2) -> void:
	var target := slot_position_for_item(item.item_tag)
	if target == Vector2.ZERO:
		return
	var constrained := _constrain_stamp_press_position(target, raw_pos)
	_drag_ctrl.update_target_global(constrained)
	item.freeze = false
	item.linear_velocity = Vector2.ZERO
	item.angular_velocity = 0.0
	item.global_position = constrained
	item.global_rotation = 0.0
	var progress := _stamp_press_progress_for_position(target, constrained)
	var blocked := progress >= 0.96 and not _all_non_stamp_items_locked()
	_set_stamp_press_progress(item.item_tag, progress, blocked)


func _constrain_stamp_press_position(target: Vector2, raw_pos: Vector2) -> Vector2:
	var ready_y := _stamp_ready_position(target).y
	var pressed_y := target.y + STAMP_PRESS_GUIDE_OVERSHOOT
	return Vector2(target.x, clamp(raw_pos.y, ready_y, pressed_y))


func _stamp_press_progress_for_position(target: Vector2, pos: Vector2) -> float:
	var ready_y := _stamp_ready_position(target).y
	var travel := maxf(target.y - ready_y, 1.0)
	return clamp((pos.y - ready_y) / travel, 0.0, 1.0)


func _ensure_stamp_press_zone_root() -> Node2D:
	if _stamp_press_zone_root != null and is_instance_valid(_stamp_press_zone_root):
		return _stamp_press_zone_root
	_stamp_press_zone_root = Node2D.new()
	_stamp_press_zone_root.name = "StampPressZones"
	_world.add_child(_stamp_press_zone_root)
	return _stamp_press_zone_root


func _ensure_stamp_press_zone(item_tag: String, target: Vector2) -> Area2D:
	var existing = _stamp_press_zones_by_tag.get(item_tag, null)
	if existing is Area2D and is_instance_valid(existing):
		var existing_area := existing as Area2D
		existing_area.global_position = target
		existing_area.visible = true
		return existing_area
	var root := _ensure_stamp_press_zone_root()
	var zone := Area2D.new()
	zone.name = "StampPressZone_" + item_tag
	zone.global_position = target
	zone.collision_layer = 1
	zone.collision_mask = 0
	zone.monitoring = true
	zone.monitorable = true
	zone.visible = true
	root.add_child(zone)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = STAMP_PRESS_ZONE_SIZE
	shape.shape = rect
	shape.disabled = false
	zone.add_child(shape)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(-STAMP_PRESS_ZONE_SIZE.x * 0.5, -STAMP_PRESS_ZONE_SIZE.y * 0.5),
		Vector2(STAMP_PRESS_ZONE_SIZE.x * 0.5, -STAMP_PRESS_ZONE_SIZE.y * 0.5),
		Vector2(STAMP_PRESS_ZONE_SIZE.x * 0.5, STAMP_PRESS_ZONE_SIZE.y * 0.5),
		Vector2(-STAMP_PRESS_ZONE_SIZE.x * 0.5, STAMP_PRESS_ZONE_SIZE.y * 0.5),
	])
	visual.color = STAMP_PRESS_IDLE_COLOR
	visual.z_index = -2
	visual.visible = true
	zone.add_child(visual)
	_stamp_press_zones_by_tag[item_tag] = zone
	return zone


func _set_stamp_press_progress(item_tag: String, progress: float, blocked := false) -> void:
	var clamped: float = clampf(progress, 0.0, 1.0)
	_stamp_press_progress_by_tag[item_tag] = clamped
	_update_stamp_press_zone_visual(item_tag, clamped, blocked)


func _update_stamp_press_zone_visual(item_tag: String, progress: float, blocked: bool) -> void:
	var zone = _stamp_press_zones_by_tag.get(item_tag, null)
	if not (zone is Area2D) or not is_instance_valid(zone):
		return
	var visual := (zone as Area2D).get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	visual.color = STAMP_PRESS_BLOCKED_COLOR if blocked else STAMP_PRESS_IDLE_COLOR.lerp(STAMP_PRESS_ACTIVE_COLOR, progress)
	visual.scale = Vector2(1.0 + progress * 0.04, 1.0 + progress * 0.08)


func _clear_stamp_press_zones() -> void:
	for zone in _stamp_press_zones_by_tag.values():
		if is_instance_valid(zone):
			zone.queue_free()
	if _stamp_press_zone_root != null and is_instance_valid(_stamp_press_zone_root):
		for child in _stamp_press_zone_root.get_children():
			child.queue_free()
	_stamp_press_zones_by_tag.clear()


func _prepare_stamp_for_press(item: MineItem, target: Vector2, item_spec: Dictionary) -> void:
	var tag := String(item_spec["tag"])
	_pending_stamp_tags[tag] = true
	_ensure_stamp_press_zone(tag, target)
	_set_stamp_press_progress(tag, 0.0)
	_move_item_to_stamp_ready(item, target)
	_obs_label.text = String(item_spec["obs"])
	_hint_label.text = "按住这枚章，往下压进槽里再松手；压浅了不会盖上。"


func _check_pending_stamp_press(item: MineItem, target: Vector2, item_spec: Dictionary) -> void:
	var tag := String(item_spec["tag"])
	_set_stamp_press_progress(tag, _stamp_press_progress_for_position(target, item.global_position))
	var pressed_deep_enough := item.global_position.y >= target.y - STAMP_PRESS_Y_MARGIN
	var centered_enough := absf(item.global_position.x - target.x) <= STAMP_PRESS_X_RADIUS
	if pressed_deep_enough and centered_enough:
		if _all_non_stamp_items_locked():
			_lock_stamp_after_press(item, target, item_spec)
		else:
			_move_item_to_stamp_ready(item, target)
			_set_stamp_press_progress(tag, 0.0, true)
			_hint_label.text = "先把案牌放齐，再压下这枚章。"
	else:
		_move_item_to_stamp_ready(item, target)
		_set_stamp_press_progress(tag, 0.0)
		_hint_label.text = "章还没压到底。按住它往下压进槽里，再松手。"


func _all_non_stamp_items_locked() -> bool:
	if _round_index >= ROUND_SPECS.size():
		return false
	for item_spec in ROUND_SPECS[_round_index]["items"]:
		if _is_stamp_spec(item_spec):
			continue
		if not _locked_tags.has(String(item_spec["tag"])):
			return false
	return true


func _move_item_to_stamp_ready(item: MineItem, target: Vector2) -> void:
	item.linear_velocity = Vector2.ZERO
	item.angular_velocity = 0.0
	item.global_position = _stamp_ready_position(target)
	item.global_rotation = 0.0
	item.freeze = true


func _lock_stamp_after_press(item: MineItem, target: Vector2, item_spec: Dictionary) -> void:
	var tag := String(item_spec["tag"])
	_create_stamp_imprint(tag, item, target)
	_pending_stamp_tags.erase(tag)
	_locked_tags[tag] = true
	_set_stamp_press_progress(tag, 1.0)
	_move_item_to_stamp_ready(item, target)
	_obs_label.text = String(item_spec["obs"])
	_hint_label.text = "印已经压进清算槽。"


func _create_stamp_imprint(item_tag: String, item: MineItem, target: Vector2) -> void:
	if _stamp_imprints_by_tag.has(item_tag):
		return
	var imprint := Sprite2D.new()
	imprint.name = "StampImprint_" + item_tag
	var texture_visual := item.get_node_or_null("TextureVisual") as Sprite2D
	if texture_visual != null:
		imprint.texture = texture_visual.texture
		imprint.scale = texture_visual.scale * Vector2(0.72, 0.48)
	imprint.centered = true
	imprint.global_position = target + Vector2(0, 6)
	imprint.global_rotation = 0.0
	imprint.z_index = -1
	imprint.modulate = Color(0.12, 0.11, 0.10, 0.62)
	imprint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world.add_child(imprint)
	_stamp_imprints_by_tag[item_tag] = imprint


func _set_card_label_visible(item: MineItem, visible: bool) -> void:
	var label := item.get_node_or_null("ClearingCardLabel") as Label
	if label != null:
		label.visible = visible


func _create_stamped_output(item_tag: String) -> void:
	if _stamped_outputs_by_tag.has(item_tag):
		return
	var item: MineItem = _items_by_tag.get(item_tag, null)
	if not is_instance_valid(item):
		return
	var texture_visual := item.get_node_or_null("TextureVisual") as Sprite2D
	if texture_visual == null or texture_visual.texture == null:
		return
	var output := Node2D.new()
	output.name = "StampedOutput_" + item_tag
	output.z_index = 42
	output.global_position = STAMP_OUTPUT_POSITION + Vector2(0, -22)
	output.scale = Vector2(0.74, 0.74)
	output.modulate = Color(1, 1, 1, 0.0)
	output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world.add_child(output)

	var paper := Sprite2D.new()
	paper.name = "Paper"
	paper.texture = texture_visual.texture
	paper.centered = true
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.scale = STAMP_OUTPUT_SCALE
	paper.modulate = Color(0.92, 0.88, 0.78, 1.0)
	output.add_child(paper)

	var imprint := Sprite2D.new()
	imprint.name = "Imprint"
	imprint.texture = _stamped_output_imprint_texture()
	imprint.centered = true
	imprint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imprint.position = Vector2(8, 0)
	imprint.scale = Vector2(0.52, 0.52)
	imprint.modulate = Color(0.12, 0.11, 0.10, 0.76)
	imprint.z_index = 2
	output.add_child(imprint)

	_stamped_outputs_by_tag[item_tag] = output
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(output, "global_position", STAMP_OUTPUT_POSITION, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(output, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(output, "modulate:a", 1.0, 0.08)


func _stamped_output_imprint_texture() -> Texture2D:
	if _stamp_station != null and is_instance_valid(_stamp_station) \
			and _stamp_station.has_method("imprint_texture"):
		return _stamp_station.call("imprint_texture")
	return TextureManager.try_load("res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_imprint.png")


func _lock_item_at(item: MineItem, pos: Vector2) -> void:
	item.linear_velocity = Vector2.ZERO
	item.angular_velocity = 0.0
	item.global_position = pos
	item.global_rotation = 0.0
	item.freeze = true


func _complete_round() -> void:
	if _round_index >= ROUND_SPECS.size():
		return
	var round: Dictionary = ROUND_SPECS[_round_index]
	var document_id := String(round["document"])
	_grant_document(document_id)
	_obs_label.text = String(round["complete"])
	if _round_index >= ROUND_SPECS.size() - 1:
		_complete = true
		_round_index = ROUND_SPECS.size()
		_hint_label.text = "最后一张盖好的窄纸已经从清算台弹出。带着这些证据回到伊芙琳面前。"
		return
	_awaiting_next_round = true
	_hint_label.text = "盖好的窄纸弹到出纸口。点一下清算台，继续下一批旧账。"


func _advance_to_next_round() -> void:
	if not _awaiting_next_round:
		return
	_round_index += 1
	_spawn_round()


func _is_round_advance_event(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false
	if _leave_btn != null and _leave_btn.get_global_rect().has_point(mouse_event.position):
		return false
	return true


func _has_deep_progress() -> bool:
	return _complete or _awaiting_next_round or _round_locked or _round_index > 0 \
		or not _locked_tags.is_empty() or not _placed_target_tags.is_empty()


func _leave_hint_text() -> String:
	return "清算台还没有吐出任何窄纸。先把这一批案牌放进槽位。"
