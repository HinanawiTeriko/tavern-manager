class_name BarWorkspace
extends Node2D

## 正式吧台物理工作面（从 gravity_test 沙盘移植的胶水）。
## 取材：点 ShortcutBar 槽位 → 在鼠标处生成 DeskItem 物理体并钉住。
## 抓桶：点酒桶 → 唤醒 + 钉住，可移动可摇。
## 上菜：成品拖进 CustomerDropArea 松手 → GameManager.request_serve()。
## 只跟 GameManager 说话，不引用 tavern_view（守 mediator 规则）。

const DESK_ITEM_SCENE := preload("res://scenes/ui/components/DeskItem.tscn")
const KITCHEN_CONTAINER_SCRIPT := preload("res://scripts/ui/kitchen_container.gd")
const TAVERN_ITEM_ICON_PREFIX := "res://assets/textures/tavern/icons/"
const TAVERN_ITEM_ART_PREFIX := "res://assets/textures/tavern/items/"
const ITEM_ICON_PREFIX := "res://assets/textures/icons/items/"
const PRODUCT_ICON_PREFIX := "res://assets/textures/icons/products/"
const SUBMERGED_ITEM_Z_INDEX := -1
const MAX_SLOTS := 10
const KILL_Y := 800.0
const TABLE_DRAG_CLEARANCE_PADDING := 4.0
const DEFAULT_DRAG_ITEM_CLEARANCE := 34.0
const SHORTCUT_DRAG_PREVIEW_Z_INDEX := 300
const NO_RELEASE_GLOBAL_POSITION := Vector2(-999999.0, -999999.0)
const DESK_RETURN_MIN_X := 260.0
const DESK_RETURN_MAX_X := 1020.0
const PHYSICS_LAW_META_BASE_GRAVITY := "base_gravity_scale"
const PHYSICS_LAW_META_BASE_LINEAR_DAMP := "base_linear_damp"
const PHYSICS_LAW_META_BASE_ANGULAR_DAMP := "base_angular_damp"
const PHYSICS_LAW_META_HAS_BASE_MATERIAL := "has_base_physics_material_override"
const PHYSICS_LAW_META_BASE_MATERIAL := "base_physics_material_override"
const PHYSICS_LAW_META_APPLIED_ID := "applied_physics_law_id"
const PHYSICS_LAW_MIN_GRAVITY := 0.2
const PHYSICS_LAW_MAX_GRAVITY := 2.0
const PHYSICS_LAW_MIN_BOUNCE := 0.0
const PHYSICS_LAW_MAX_BOUNCE := 1.0
const COMEDY_RELEASE_MIN_SPEED := 420.0
const COMEDY_RELEASE_FULL_SPEED := 900.0
const COMEDY_RELEASE_SPIN_MIN := 2.4
const COMEDY_RELEASE_SPIN_MAX := 7.0
const COMEDY_RELEASE_LINEAR_BOOST_MIN := 12.0
const COMEDY_RELEASE_LINEAR_BOOST_MAX := 56.0
const COMEDY_RELEASE_MAX_LINEAR_SPEED := 1200.0
const COMEDY_RELEASE_MAX_ANGULAR_SPEED := 18.0
const PHYSICS_LAW_MAX_DRAMATIC_MULTIPLIER := 4.0
const PHYSICS_LAW_MAX_CUSTOMER_PULL := 240.0
const PHYSICS_LAW_MAX_RANDOM_LIFT := 360.0
const PHYSICS_LAW_COLLISION_MIN_SPEED := 110.0
const PHYSICS_LAW_COLLISION_SIDE_KICK := 46.0
const PHYSICS_LAW_COLLISION_HOP := 62.0
const PHYSICS_LAW_PULL_MAX_LINEAR_SPEED := 980.0
const PHYSICS_LAW_PULSE_SPIN := 2.6
const CHAOS_GHOST_TEXTURE_PATH := "res://assets/textures/characters/chaos_phoebe_chupi_ghost.png"
const CHAOS_GHOST_GRAB_TEXTURE_PATH := "res://assets/textures/characters/chaos_phoebe_chupi_ghost_grab.png"
const CHAOS_GHOST_FADE_TEXTURE_PATH := "res://assets/textures/characters/chaos_phoebe_chupi_ghost_fade.png"
const CHAOS_GHOST_TUTORIAL_GROUP := "chaos_ghost"
const CHAOS_GHOST_TARGET_META := "chaos_ghost_target"
const CHAOS_GHOST_STOLEN_META := "chaos_ghost_stolen_once"
const CHAOS_GHOST_BASE_MODULATE_META := "chaos_ghost_base_modulate"
const CHAOS_LEVEL_MAX := 4.0
const CHAOS_GHOST_TRIGGER_LEVEL := 1.0
const CHAOS_GHOST_APPROACH_SECONDS := 2.2
const CHAOS_GHOST_ESCAPE_SECONDS := 1.8
const CHAOS_GHOST_CANCEL_FADE_SECONDS := 0.8
const CHAOS_GHOST_EDGE_MARGIN := 96.0
const CHAOS_GHOST_COOLDOWN_SECONDS := 6.0
const CHAOS_GHOST_Z_INDEX := 360
const CHAOS_GHOST_SPRITE_SCALE := 0.42
const CHAOS_GHOST_TARGET_TINT := Color(0.7, 0.9, 1.0, 1.0)
const CHAOS_GHOST_HOVER_OFFSET := Vector2(0.0, -58.0)
const CHAOS_GHOST_CARRY_OFFSET := Vector2(0.0, 34.0)
const CHAOS_GUEST_WAIT_PATIENCE_RATIO := 0.28
const CHAOS_GUEST_WAIT_PER_SECOND := 0.13
const CHAOS_CROWDED_DESK_MIN_ITEMS := 4
const CHAOS_CROWDED_DESK_PER_ITEM_SECOND := 0.06
const CHAOS_GHOST_EVENT_WEIGHTS := {
	"guest_wait": 1.0,
	"crowded_desk": 1.0,
	"fast_release": 0.42,
	"desk_item_fell": 0.55,
	"collision": 0.35,
}

@onready var _drag_ctrl: DragController = $DragCtrl
@onready var _items_node: Node2D = $World/Items
@onready var _ground_shape: CollisionShape2D = $World/Walls/Ground
@onready var _brewery: Brewery = $World/Brewery
@onready var _shaker: SeasoningShaker = $World/SeasoningShaker
@onready var _grill: KitchenContainer = $World/Grill
@onready var _pot: KitchenContainer = $World/Pot
@onready var _spoon: StirSpoon = $World/Spoon
@onready var _ledger: ReadableDeskItem = $World/Ledger
@onready var _customer_area: Area2D = $CustomerDropArea
@onready var _shortcut_bar: Control = get_node("../ShortcutBar")
@onready var _inventory_overlay: InventoryOverlay = get_node_or_null("../InventoryOverlay") as InventoryOverlay

var _gm
var _slot_rects: Array[Rect2] = []
var _slot_item_keys: Array[String] = []
var _dragged_item_surface_z_indices: Dictionary = {}
var _shortcut_preview_body: DeskItem = null
var _shortcut_preview_body_layer: int = 0
var _shortcut_preview_body_mask: int = 0
var _seasoning_tutorial_retry_armed := false
var _active_physics_law: Dictionary = {}
var _physics_law_pulse_elapsed := 0.0
var _chaos_level := 0.0
var _chaos_ghost_cooldown := 0.0
var _chaos_ghost_phase := ""
var _chaos_ghost_elapsed := 0.0
var _chaos_ghost_frames := 0
var _chaos_ghost_target: RigidBody2D = null
var _chaos_ghost_node: Node2D = null
var _chaos_ghost_entry_position := Vector2.ZERO
var _chaos_ghost_capture_position := Vector2.ZERO
var _chaos_ghost_escape_position := Vector2.ZERO
var _chaos_ghost_fade_alpha_from := 1.0
var _chaos_ghost_waiting_for_tutorial := false
var _chaos_ghost_target_collision_layer := 0
var _chaos_ghost_target_collision_mask := 0
var _chaos_ghost_target_freeze := false
@onready var _recycle_anchor: Marker2D = $World/RecycleAnchor
var _docks: Dictionary = {}   # RigidBody2D -> Vector2 初始泊位


func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_shortcut_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brewery.recipe_consumed.connect(_on_recipe_consumed)
	_grill.recipe_consumed.connect(_on_recipe_consumed)
	_pot.recipe_consumed.connect(_on_recipe_consumed)
	_drag_ctrl.drag_started.connect(_on_drag_started)
	_drag_ctrl.drag_ended.connect(_on_drag_ended)
	_items_node.child_entered_tree.connect(_on_items_child_added)
	_gm.inventory_changed.connect(_init_material_slots)
	_gm.inventory_changed.connect(_maybe_trigger_seasoning_tutorial)
	call_deferred("_capture_docks")
	call_deferred("_init_material_slots")   # 等 HBox 布局完成再读 slot 位置
	call_deferred("_maybe_trigger_seasoning_tutorial")


func _on_recipe_consumed(product_key: String) -> void:
	print("[BarWorkspace] 产出 ", product_key)
	if _gm != null and _gm.has_method("discover_recipe"):
		_gm.discover_recipe(product_key, true)


func configure_day(day: int) -> void:
	_set_body_available(_brewery, _gm.workspace.is_container_unlocked("barrel", day))
	_set_body_available(_grill, _gm.workspace.is_container_unlocked("grill", day))
	_set_body_available(_pot, _gm.workspace.is_container_unlocked("pot", day))
	_set_body_available(_spoon, _gm.workspace.is_container_unlocked("spoon", day))


func apply_physics_law(law: Dictionary) -> void:
	if String(law.get("scope", "desk_items")) != "desk_items":
		return
	if not _active_physics_law.is_empty():
		clear_physics_law()
	_active_physics_law = law.duplicate(true)
	_physics_law_pulse_elapsed = 0.0
	for child in _items_node.get_children():
		_apply_active_physics_law_to_body(child)


func clear_physics_law() -> void:
	for child in _items_node.get_children():
		_restore_body_physics_law(child)
	_active_physics_law.clear()
	_physics_law_pulse_elapsed = 0.0


func record_chaos_event(event_id: String, amount: float = 1.0) -> void:
	if amount <= 0.0:
		return
	var weight := float(CHAOS_GHOST_EVENT_WEIGHTS.get(event_id, 1.0))
	_chaos_level = clampf(_chaos_level + amount * weight, 0.0, CHAOS_LEVEL_MAX)


func try_trigger_chaos_event() -> bool:
	if _chaos_ghost_phase != "" or _chaos_ghost_cooldown > 0.0:
		return false
	if _chaos_level < CHAOS_GHOST_TRIGGER_LEVEL:
		return false
	var target := _find_chaos_ghost_target()
	if target == null:
		return false
	_start_chaos_ghost_approach(target)
	return true


func is_chaos_ghost_active() -> bool:
	return _chaos_ghost_phase != ""


func _maybe_trigger_seasoning_tutorial() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null or tm.first_product_seasoned:
		return
	if not _has_inventory_seasoning():
		return
	if not tm.is_group_completed("craft"):
		_arm_seasoning_tutorial_retry(tm)
		return
	if tm._is_active:
		_arm_seasoning_tutorial_retry(tm)
		return
	tm.first_product_seasoned = true
	tm._save_state()
	tm.start_tutorial("seasoning", _seasoning_tutorial_rects())


func _has_inventory_seasoning() -> bool:
	if _gm == null or _gm.seasoning == null or not (_gm.inventory is Dictionary):
		return false
	for raw_key in _gm.inventory.keys():
		var item_key := String(raw_key)
		if int(_gm.inventory.get(raw_key, 0)) > 0 and _gm.seasoning.is_seasoning(item_key):
			return true
	return false


func _arm_seasoning_tutorial_retry(tm) -> void:
	if _seasoning_tutorial_retry_armed:
		return
	if tm == null or not tm.has_signal("tutorial_sequence_ended"):
		return
	_seasoning_tutorial_retry_armed = true
	tm.tutorial_sequence_ended.connect(_on_tutorial_sequence_ended_for_seasoning, CONNECT_ONE_SHOT)


func _on_tutorial_sequence_ended_for_seasoning(_group_id: String) -> void:
	_seasoning_tutorial_retry_armed = false
	call_deferred("_maybe_trigger_seasoning_tutorial")


func _seasoning_tutorial_rects() -> Dictionary:
	var tavern := get_parent()
	if tavern != null and tavern.has_method("get_tutorial_highlight_rects"):
		var live_rects: Dictionary = tavern.call("get_tutorial_highlight_rects", "seasoning")
		if not live_rects.is_empty():
			return live_rects
	return {
		"SeasoningShaker": _node_centered_screen_rect(_shaker, Vector2(74.0, 118.0), Vector2(14.0, 14.0)),
		"ShortcutBar": _control_screen_rect(_shortcut_bar),
	}


func _control_screen_rect(control: Control) -> Array:
	if control == null:
		return [0.0, 0.0, 0.0, 0.0]
	var rect := control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _node_centered_screen_rect(node: Node2D, size: Vector2, padding: Vector2 = Vector2.ZERO) -> Array:
	if node == null:
		return [0.0, 0.0, 0.0, 0.0]
	var rect := Rect2(node.global_position - size * 0.5, size)
	rect = Rect2(rect.position - padding, rect.size + padding * 2.0)
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _set_body_available(body: RigidBody2D, available: bool) -> void:
	body.visible = available
	body.process_mode = Node.PROCESS_MODE_INHERIT if available else Node.PROCESS_MODE_DISABLED
	for child in body.find_children("*", "CollisionShape2D", true, false):
		child.set_deferred("disabled", not available)
	for child in body.find_children("*", "CollisionPolygon2D", true, false):
		child.set_deferred("disabled", not available)


func _process(delta: float) -> void:
	_update_shortcut_hover(get_global_mouse_position())
	_update_chaos_director(delta)


func _update_chaos_director(delta: float) -> void:
	var dt := maxf(delta, 0.0)
	_feed_ambient_chaos(dt)
	if _chaos_ghost_cooldown > 0.0:
		_chaos_ghost_cooldown = maxf(0.0, _chaos_ghost_cooldown - dt)
	if _chaos_ghost_phase == "":
		try_trigger_chaos_event()
		return
	if _chaos_ghost_phase == "approach":
		_update_chaos_ghost_approach(dt)
	elif _chaos_ghost_phase == "escape":
		_update_chaos_ghost_escape(dt)
	elif _chaos_ghost_phase == "fade":
		_update_chaos_ghost_fade(dt)


func _feed_ambient_chaos(delta: float) -> void:
	if delta <= 0.0 or _chaos_ghost_phase != "":
		return
	var stealable_count := _stealable_chaos_item_count()
	if stealable_count <= 0 and _stealable_chaos_cookware_count() <= 0:
		return
	if _current_guest_patience_ratio() <= CHAOS_GUEST_WAIT_PATIENCE_RATIO:
		record_chaos_event("guest_wait", delta * CHAOS_GUEST_WAIT_PER_SECOND)
	if stealable_count >= CHAOS_CROWDED_DESK_MIN_ITEMS:
		var overflow := stealable_count - CHAOS_CROWDED_DESK_MIN_ITEMS + 1
		record_chaos_event("crowded_desk", delta * CHAOS_CROWDED_DESK_PER_ITEM_SECOND * float(overflow))


func _current_guest_patience_ratio() -> float:
	if _gm == null or _gm.guests == null or not _gm.guests.has_guest:
		return 1.0
	var guest: GuestData = _gm.guests.current_guest as GuestData
	if guest == null:
		return 1.0
	var max_patience := GuestData.BASE_PATIENCE
	if guest.has_dialogue:
		max_patience = GuestData.BASE_PATIENCE * 1.5
	return clampf(guest.patience / maxf(max_patience, 1.0), 0.0, 1.0)


func _stealable_chaos_item_count() -> int:
	var count := 0
	for child in _items_node.get_children():
		if child is DeskItem and _is_chaos_ghost_targetable(child):
			count += 1
	return count


func _stealable_chaos_cookware_count() -> int:
	var count := 0
	for body in _chaos_ghost_cookware_targets():
		if _is_chaos_ghost_targetable(body):
			count += 1
	return count


func _update_chaos_ghost_approach(delta: float) -> void:
	if not _is_chaos_ghost_targetable(_chaos_ghost_target):
		_cancel_chaos_ghost_event()
		return
	if _chaos_ghost_waiting_for_tutorial:
		_chaos_ghost_elapsed = CHAOS_GHOST_APPROACH_SECONDS
		_pulse_chaos_ghost_target()
		_update_chaos_ghost_approach_visual()
		var tm = get_node_or_null("/root/TutorialManager")
		if _chaos_ghost_tutorial_is_active(tm):
			return
		if _formal_dialogue_blocks_chaos_ghost():
			return
		if _chaos_ghost_tutorial_is_pending(tm):
			if _maybe_trigger_chaos_ghost_tutorial():
				return
		_chaos_ghost_waiting_for_tutorial = false
		_start_chaos_ghost_escape()
		return
	_chaos_ghost_elapsed += delta
	_chaos_ghost_frames += 1
	_pulse_chaos_ghost_target()
	_update_chaos_ghost_approach_visual()
	if _chaos_ghost_elapsed >= CHAOS_GHOST_APPROACH_SECONDS:
		if _formal_dialogue_blocks_chaos_ghost():
			_chaos_ghost_waiting_for_tutorial = true
			_chaos_ghost_elapsed = CHAOS_GHOST_APPROACH_SECONDS
			return
		if _maybe_trigger_chaos_ghost_tutorial():
			_chaos_ghost_waiting_for_tutorial = true
			_chaos_ghost_elapsed = CHAOS_GHOST_APPROACH_SECONDS
			return
		_start_chaos_ghost_escape()


func _update_chaos_ghost_escape(delta: float) -> void:
	if _chaos_ghost_target == null or not is_instance_valid(_chaos_ghost_target) or _chaos_ghost_target.is_queued_for_deletion():
		_complete_chaos_ghost_escape()
		return
	_chaos_ghost_elapsed += delta
	_chaos_ghost_frames += 1
	_update_chaos_ghost_escape_visual()
	if _chaos_ghost_elapsed >= CHAOS_GHOST_ESCAPE_SECONDS:
		_complete_chaos_ghost_escape()


func _update_chaos_ghost_fade(delta: float) -> void:
	if _chaos_ghost_node == null or not is_instance_valid(_chaos_ghost_node):
		_complete_chaos_ghost_fade()
		return
	_chaos_ghost_elapsed += delta
	var ratio := clampf(_chaos_ghost_elapsed / CHAOS_GHOST_CANCEL_FADE_SECONDS, 0.0, 1.0)
	_chaos_ghost_node.visible = true
	_chaos_ghost_node.modulate = Color(1.0, 1.0, 1.0, lerpf(_chaos_ghost_fade_alpha_from, 0.0, ratio))
	if ratio >= 1.0:
		_complete_chaos_ghost_fade()


func _find_chaos_ghost_target() -> RigidBody2D:
	for child in _items_node.get_children():
		if child is DeskItem and _is_chaos_ghost_targetable(child):
			return child
	for body in _chaos_ghost_cookware_targets():
		if _is_chaos_ghost_targetable(body):
			return body
	return null


func _is_chaos_ghost_targetable(item) -> bool:
	if item == null or not is_instance_valid(item) or not item is DeskItem:
		return _is_chaos_ghost_cookware_targetable(item)
	var desk_item := item as DeskItem
	if desk_item.is_queued_for_deletion():
		return false
	if desk_item.item_key == "" or desk_item.is_held:
		return false
	if _drag_ctrl != null and _drag_ctrl.get_body() == desk_item:
		return false
	if not desk_item.visible or _is_item_inside_any_container(desk_item):
		return false
	if bool(desk_item.get_meta(CHAOS_GHOST_STOLEN_META, false)):
		return false
	if desk_item.document_id != "":
		return false
	if _gm != null and _gm.inventory_sys != null and _gm.inventory_sys.is_story_item(desk_item.item_key):
		return false
	return true


func _chaos_ghost_cookware_targets() -> Array[RigidBody2D]:
	var targets: Array[RigidBody2D] = []
	for body in [_brewery, _shaker, _grill, _pot, _spoon]:
		if body is RigidBody2D:
			targets.append(body)
	return targets


func _is_chaos_ghost_cookware_targetable(body) -> bool:
	if body == null or not is_instance_valid(body) or not body is RigidBody2D:
		return false
	var rigid := body as RigidBody2D
	if rigid.is_queued_for_deletion():
		return false
	if not _docks.has(rigid):
		return false
	if not _chaos_ghost_cookware_targets().has(rigid):
		return false
	if not rigid.visible or rigid.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if _drag_ctrl != null and _drag_ctrl.get_body() == rigid:
		return false
	return true


func _start_chaos_ghost_approach(target: RigidBody2D) -> void:
	_chaos_ghost_target = target
	_chaos_ghost_phase = "approach"
	_chaos_ghost_elapsed = 0.0
	_chaos_ghost_frames = 0
	_chaos_ghost_waiting_for_tutorial = false
	_chaos_level = maxf(0.0, _chaos_level - CHAOS_GHOST_TRIGGER_LEVEL)
	_chaos_ghost_entry_position = _random_chaos_ghost_edge_position()
	_chaos_ghost_escape_position = _chaos_ghost_entry_position
	target.set_meta(CHAOS_GHOST_TARGET_META, true)
	if not target.has_meta(CHAOS_GHOST_BASE_MODULATE_META):
		target.set_meta(CHAOS_GHOST_BASE_MODULATE_META, target.modulate)
	_pulse_chaos_ghost_target()
	var ghost := _ensure_chaos_ghost_node()
	_set_chaos_ghost_texture(CHAOS_GHOST_TEXTURE_PATH)
	ghost.visible = true
	ghost.global_position = _chaos_ghost_entry_position
	ghost.scale = Vector2.ONE * 0.78
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.18)


func _maybe_trigger_chaos_ghost_tutorial() -> bool:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null or tm._is_active:
		return false
	if _formal_dialogue_blocks_chaos_ghost():
		return false
	if tm.has_method("is_group_completed") and tm.is_group_completed(CHAOS_GHOST_TUTORIAL_GROUP):
		return false
	tm.start_tutorial(CHAOS_GHOST_TUTORIAL_GROUP, _chaos_ghost_tutorial_rects())
	return tm._is_active


func _chaos_ghost_tutorial_is_pending(tm) -> bool:
	if tm == null:
		return false
	if tm.has_method("is_group_completed") and tm.is_group_completed(CHAOS_GHOST_TUTORIAL_GROUP):
		return false
	return true


func _chaos_ghost_tutorial_is_active(tm) -> bool:
	if tm == null or not tm._is_active or tm._current_sequence.is_empty():
		return false
	return String(tm._current_sequence[0].get("group", "")) == CHAOS_GHOST_TUTORIAL_GROUP


func _formal_dialogue_blocks_chaos_ghost() -> bool:
	if _gm == null or not is_instance_valid(_gm):
		return false
	if String(_gm._dialogue_phase) != "":
		return true
	return bool(_gm._is_dialogue_active)


func _chaos_ghost_tutorial_rects() -> Dictionary:
	return {
		"ChaosGhostEvent": _union_screen_rects([
			_node_centered_screen_rect(_chaos_ghost_node, Vector2(100.0, 112.0), Vector2(18.0, 18.0)),
			_node_centered_screen_rect(_chaos_ghost_target, Vector2(72.0, 72.0), Vector2(18.0, 18.0)),
		]),
	}


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
	return [union_rect.position.x, union_rect.position.y, union_rect.size.x, union_rect.size.y]


func _rect_from_array(values: Array) -> Rect2:
	if values.size() < 4:
		return Rect2()
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))


func _pulse_chaos_ghost_target() -> void:
	if _chaos_ghost_target == null or not is_instance_valid(_chaos_ghost_target):
		return
	var base: Color = _chaos_ghost_target.get_meta(CHAOS_GHOST_BASE_MODULATE_META, _chaos_ghost_target.modulate)
	var pulse := 0.35 + 0.25 * sin(float(_chaos_ghost_frames) * 0.9)
	_chaos_ghost_target.modulate = base.lerp(CHAOS_GHOST_TARGET_TINT, pulse)


func _start_chaos_ghost_escape() -> void:
	var target := _chaos_ghost_target
	if not _is_chaos_ghost_targetable(target):
		_cancel_chaos_ghost_event()
		return
	_restore_chaos_ghost_target_visual(target)
	target.remove_meta(CHAOS_GHOST_TARGET_META)
	if target is DeskItem:
		target.set_meta(CHAOS_GHOST_STOLEN_META, true)
		target.set_physics_process(false)
	_chaos_ghost_target_collision_layer = target.collision_layer
	_chaos_ghost_target_collision_mask = target.collision_mask
	_chaos_ghost_target_freeze = target.freeze
	target.freeze = true
	target.sleeping = true
	target.linear_velocity = Vector2.ZERO
	target.angular_velocity = 0.0
	target.collision_layer = 0
	target.collision_mask = 0
	target.z_as_relative = false
	target.z_index = CHAOS_GHOST_Z_INDEX + 1
	_chaos_ghost_phase = "escape"
	_chaos_ghost_elapsed = 0.0
	_chaos_ghost_frames = 0
	var ghost := _ensure_chaos_ghost_node()
	_set_chaos_ghost_texture(CHAOS_GHOST_GRAB_TEXTURE_PATH)
	_chaos_ghost_capture_position = ghost.global_position
	_chaos_ghost_escape_position = _chaos_ghost_exit_position_from(_chaos_ghost_capture_position)
	_update_carried_chaos_ghost_target(ghost.global_position)
	if _gm != null and _gm.has_method("play_audio_event"):
		_gm.play_audio_event("drop")


func _cancel_chaos_ghost_event() -> void:
	if _chaos_ghost_target != null and is_instance_valid(_chaos_ghost_target):
		if _chaos_ghost_target.has_meta(CHAOS_GHOST_TARGET_META):
			_chaos_ghost_target.remove_meta(CHAOS_GHOST_TARGET_META)
		_restore_chaos_ghost_target_visual(_chaos_ghost_target)
	_chaos_ghost_target = null
	_chaos_ghost_waiting_for_tutorial = false
	if _chaos_ghost_node == null or not is_instance_valid(_chaos_ghost_node):
		_complete_chaos_ghost_fade()
		return
	_set_chaos_ghost_texture(CHAOS_GHOST_FADE_TEXTURE_PATH)
	_chaos_ghost_phase = "fade"
	_chaos_ghost_elapsed = 0.0
	_chaos_ghost_frames = 0
	_chaos_ghost_node.visible = true
	_chaos_ghost_fade_alpha_from = clampf(_chaos_ghost_node.modulate.a, 0.1, 0.92)
	_chaos_ghost_node.modulate = Color(1.0, 1.0, 1.0, _chaos_ghost_fade_alpha_from)


func _restore_chaos_ghost_target_visual(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_meta(CHAOS_GHOST_BASE_MODULATE_META):
		target.modulate = target.get_meta(CHAOS_GHOST_BASE_MODULATE_META)
		target.remove_meta(CHAOS_GHOST_BASE_MODULATE_META)


func _complete_chaos_ghost_escape() -> void:
	if _chaos_ghost_target != null and is_instance_valid(_chaos_ghost_target) and not _chaos_ghost_target.is_queued_for_deletion():
		if _chaos_ghost_target is DeskItem:
			_chaos_ghost_target.queue_free()
		else:
			_restore_chaos_ghost_cookware_target(_chaos_ghost_target)
	_hide_chaos_ghost_visual()
	_chaos_ghost_target = null
	_chaos_ghost_phase = ""
	_chaos_ghost_waiting_for_tutorial = false
	_chaos_ghost_cooldown = CHAOS_GHOST_COOLDOWN_SECONDS


func _complete_chaos_ghost_fade() -> void:
	_hide_chaos_ghost_visual()
	_chaos_ghost_target = null
	_chaos_ghost_phase = ""
	_chaos_ghost_waiting_for_tutorial = false
	_chaos_ghost_cooldown = CHAOS_GHOST_COOLDOWN_SECONDS * 0.35


func _restore_chaos_ghost_cookware_target(target: RigidBody2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_meta(CHAOS_GHOST_TARGET_META):
		target.remove_meta(CHAOS_GHOST_TARGET_META)
	target.collision_layer = _chaos_ghost_target_collision_layer
	target.collision_mask = _chaos_ghost_target_collision_mask
	target.freeze = _chaos_ghost_target_freeze
	if _docks.has(target):
		_dock_body(target)


func _update_chaos_ghost_approach_visual() -> void:
	if _chaos_ghost_target == null or not is_instance_valid(_chaos_ghost_target):
		return
	var ghost := _ensure_chaos_ghost_node()
	ghost.visible = true
	var target_position := _chaos_ghost_target.global_position + CHAOS_GHOST_HOVER_OFFSET
	var ratio := clampf(_chaos_ghost_elapsed / CHAOS_GHOST_APPROACH_SECONDS, 0.0, 1.0)
	var eased := _ease_in_out_chaos(ratio)
	ghost.global_position = _chaos_ghost_entry_position.lerp(target_position, eased)
	ghost.scale = Vector2.ONE * (lerpf(0.78, 0.98, ratio) + 0.02 * sin(float(_chaos_ghost_frames) * 0.45))
	ghost.modulate = Color(1.0, 1.0, 1.0, lerpf(0.18, 0.92, ratio))


func _update_chaos_ghost_escape_visual() -> void:
	var ghost := _ensure_chaos_ghost_node()
	ghost.visible = true
	var ratio := clampf(_chaos_ghost_elapsed / CHAOS_GHOST_ESCAPE_SECONDS, 0.0, 1.0)
	var eased := _ease_in_out_chaos(ratio)
	ghost.global_position = _chaos_ghost_capture_position.lerp(_chaos_ghost_escape_position, eased)
	ghost.scale = Vector2.ONE * (0.98 + 0.05 * ratio)
	ghost.modulate = Color(1.0, 1.0, 1.0, lerpf(0.92, 0.1, ratio))
	_update_carried_chaos_ghost_target(ghost.global_position)


func _update_carried_chaos_ghost_target(ghost_position: Vector2) -> void:
	if _chaos_ghost_target == null or not is_instance_valid(_chaos_ghost_target) or _chaos_ghost_target.is_queued_for_deletion():
		return
	_chaos_ghost_target.global_position = ghost_position + CHAOS_GHOST_CARRY_OFFSET
	_chaos_ghost_target.linear_velocity = Vector2.ZERO
	_chaos_ghost_target.angular_velocity = 0.0


func _random_chaos_ghost_edge_position() -> Vector2:
	var rect := get_viewport().get_visible_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		rect = Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	var min_x := rect.position.x
	var max_x := rect.position.x + rect.size.x
	var min_y := rect.position.y
	var max_y := rect.position.y + rect.size.y
	match randi() % 4:
		0:
			return Vector2(min_x - CHAOS_GHOST_EDGE_MARGIN, randf_range(min_y + 90.0, max_y - 90.0))
		1:
			return Vector2(max_x + CHAOS_GHOST_EDGE_MARGIN, randf_range(min_y + 90.0, max_y - 90.0))
		2:
			return Vector2(randf_range(min_x + 120.0, max_x - 120.0), min_y - CHAOS_GHOST_EDGE_MARGIN)
		_:
			return Vector2(randf_range(min_x + 120.0, max_x - 120.0), max_y + CHAOS_GHOST_EDGE_MARGIN)


func _chaos_ghost_exit_position_from(capture_position: Vector2) -> Vector2:
	var rect := get_viewport().get_visible_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		rect = Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	var direction := (capture_position - _chaos_ghost_entry_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	return capture_position + direction * (rect.size.length() + CHAOS_GHOST_EDGE_MARGIN * 2.0)


func _ease_in_out_chaos(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _hide_chaos_ghost_visual() -> void:
	if _chaos_ghost_node != null and is_instance_valid(_chaos_ghost_node):
		_chaos_ghost_node.visible = false
		_chaos_ghost_node.modulate = Color.WHITE


func _ensure_chaos_ghost_node() -> Node2D:
	if _chaos_ghost_node != null and is_instance_valid(_chaos_ghost_node):
		return _chaos_ghost_node
	_chaos_ghost_node = get_node_or_null("ChaosGhost") as Node2D
	if _chaos_ghost_node == null:
		_chaos_ghost_node = Node2D.new()
		_chaos_ghost_node.name = "ChaosGhost"
		_chaos_ghost_node.z_index = CHAOS_GHOST_Z_INDEX
		_chaos_ghost_node.z_as_relative = false
		add_child(_chaos_ghost_node)
	_build_chaos_ghost_visual(_chaos_ghost_node)
	return _chaos_ghost_node


func _build_chaos_ghost_visual(root: Node2D) -> void:
	for child in root.get_children():
		child.queue_free()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_chaos_ghost_sprite_texture(sprite, CHAOS_GHOST_TEXTURE_PATH)
	if sprite.texture != null:
		sprite.scale = Vector2.ONE * CHAOS_GHOST_SPRITE_SCALE
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.92)
		root.add_child(sprite)
		return
	var fallback := Polygon2D.new()
	fallback.name = "FallbackShape"
	fallback.polygon = PackedVector2Array([
		Vector2(0, -42),
		Vector2(34, -18),
		Vector2(28, 30),
		Vector2(12, 20),
		Vector2(0, 34),
		Vector2(-12, 20),
		Vector2(-28, 30),
		Vector2(-34, -18),
	])
	fallback.color = Color(0.62, 0.85, 1.0, 0.56)
	root.add_child(fallback)


func _set_chaos_ghost_texture(texture_path: String) -> void:
	var ghost := _ensure_chaos_ghost_node()
	var sprite := ghost.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	_apply_chaos_ghost_sprite_texture(sprite, texture_path)


func _apply_chaos_ghost_sprite_texture(sprite: Sprite2D, texture_path: String) -> void:
	if sprite == null or not ResourceLoader.exists(texture_path):
		return
	var texture := load(texture_path) as Texture2D
	if texture != null:
		sprite.texture = texture


func _ensure_shortcut_slot_visuals(slot: ColorRect) -> void:
	ThemeColors.style_shortcut_slot(slot)
	var icon := slot.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = 32.0
		icon.offset_bottom = 32.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)
	var count := slot.get_node_or_null("Count") as Label
	if count == null:
		count = Label.new()
		count.name = "Count"
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.offset_left = 68.0
		count.offset_top = 17.0
		count.offset_right = 88.0
		count.offset_bottom = 34.0
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ThemeColors.style_brush_label(count, 11, ThemeColors.AMBER_PRIMARY)
		slot.add_child(count)
	var label := slot.get_node_or_null("Label") as Label
	if label != null:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.offset_left = 34.0
		label.offset_top = 4.0
		label.offset_right = 88.0
		label.offset_bottom = 22.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeColors.style_brush_label(label, 11)


func _update_shortcut_hover(mouse_position: Vector2) -> void:
	for index in _slot_rects.size():
		var slot := _shortcut_bar.get_node_or_null("Slot%d" % index) as ColorRect
		if slot != null:
			ThemeColors.set_shortcut_slot_hover(slot, _slot_rects[index].has_point(mouse_position))


func _on_drag_started(body: RigidBody2D) -> void:
	if not _is_body_usable(body):
		return
	if body is DeskItem:
		body.is_held = true
		_dragged_item_surface_z_indices[body] = body.z_index


func _on_drag_ended(body: RigidBody2D) -> void:
	if not is_instance_valid(body):
		return
	if body is DeskItem:
		var item := body as DeskItem
		if not item.is_queued_for_deletion():
			item.is_held = false
			_apply_comedy_release_to_item(item)
		_finish_shortcut_drag_preview(item, true)
		_restore_dragged_item_depth(item)


func _init_material_slots() -> void:
	## 从库存把可用材料填进 ShortcutBar 槽位（无限源；库存扣减为后续）。
	_slot_rects.clear()
	_slot_item_keys.clear()
	var keys: Array = []
	if _gm != null and _gm.has_method("get_shortcut_bindings"):
		keys = _gm.get_shortcut_bindings()
	for i in range(MAX_SLOTS):
		var slot := _shortcut_bar.get_node_or_null("Slot%d" % i) as ColorRect
		if slot == null:
			break
		_ensure_shortcut_slot_visuals(slot)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key: String = keys[i] if i < keys.size() else ""
		_slot_item_keys.append(key)
		_slot_rects.append(Rect2(slot.global_position, slot.size))
		var label := slot.get_node_or_null("Label") as Label
		var icon := slot.get_node_or_null("Icon") as TextureRect
		var count := slot.get_node_or_null("Count") as Label
		if key == "":
			slot.color = Color(ThemeColors.SURFACE_LOW, 0.86)
			ThemeColors.set_shortcut_slot_filled(slot, false)
			if label != null:
				label.text = ""
			if icon != null:
				icon.texture = null
			if count != null:
				count.text = ""
			continue
		var item_data: Dictionary = _gm.craft.get_item(key)
		ThemeColors.set_shortcut_slot_filled(slot, true)
		var rgb: Array = item_data.get("color", [0.8, 0.8, 0.8])
		slot.color = Color(rgb[0], rgb[1], rgb[2], 0.22)
		if label != null:
			label.text = item_data.get("name", key)
		if icon != null:
			icon.texture = _gm.try_load_material_icon(key)
		if count != null:
			count.text = str(_gm.inventory_sys.get_count(key))


func bind_shortcut_at_position(item_key: String, global_position: Vector2) -> bool:
	if _gm == null or not _gm.has_method("bind_shortcut_item"):
		return false
	if _slot_rects.is_empty():
		_init_material_slots()
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(global_position):
			var bound: bool = _gm.bind_shortcut_item(i, item_key)
			if bound:
				_init_material_slots()
				_gm.play_audio_event("drop")
			return bound
	return false


func _input(event: InputEvent) -> void:
	if not _drag_ctrl.is_dragging():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_dragged_body()
	elif event is InputEventMouseMotion:
		_update_drag_target(event.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_RIGHT \
		and event.pressed \
		and not _drag_ctrl.is_dragging():
		_try_eject_last_ingredient(event.global_position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.global_position
		if event.pressed and not _drag_ctrl.is_dragging():
			_try_pickup(pos)
		elif not event.pressed and _drag_ctrl.is_dragging():
			var dragged := _drag_ctrl.get_body()
			_drag_ctrl.end_drag()
			if not _is_body_usable(dragged):
				return
			if dragged == _brewery:
				_brewery.end_shake_session()
			elif dragged == _shaker:
				_shaker.end_shake_session()
			elif _is_kitchen_container(dragged):
				dragged.end_action_session()
			elif dragged is DeskItem:
				if _try_return_to_backpack(dragged, pos):
					return
				if _try_store_released_item_in_container(dragged, pos):
					return
				_try_deliver(dragged)
	elif event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		_update_drag_target(event.global_position)


func _release_dragged_body() -> void:
	var dragged := _drag_ctrl.get_body()
	_drag_ctrl.end_drag()
	if not _is_body_usable(dragged):
		return
	if dragged == _brewery:
		_brewery.end_shake_session()
	elif dragged == _shaker:
		_shaker.end_shake_session()
	elif dragged is DeskItem:
		if _try_return_to_backpack(dragged, get_global_mouse_position()):
			return
		if _try_store_released_item_in_container(dragged, get_global_mouse_position()):
			return
		_try_deliver(dragged)


func _is_body_usable(body: RigidBody2D) -> bool:
	return body != null and is_instance_valid(body) and not body.is_queued_for_deletion()


func _try_pickup(pos: Vector2) -> void:
	var hit_item: DeskItem = _hit_test_item(pos)
	if hit_item != null:
		_prepare_body_for_drag(hit_item)
		_drag_ctrl.start_drag(hit_item, pos)
		return
	var readable_item := _hit_test_readable_item(pos)
	if readable_item != null:
		_prepare_body_for_drag(readable_item)
		_drag_ctrl.start_drag(readable_item, pos)
		return
	if _hit_test_brewery(pos):
		_brewery.begin_shake_session()
		_drag_ctrl.start_drag(_brewery, pos)
		return
	if _hit_test_shaker(pos):
		_shaker.begin_shake_session()
		_drag_ctrl.start_drag(_shaker, pos)
		return
	var spoon := _hit_test_spoon(pos)
	if spoon != null:
		_prepare_body_for_drag(spoon)
		_drag_ctrl.start_drag(spoon, pos)
		return
	var kitchen = _hit_test_kitchen_container(pos)
	if kitchen != null:
		kitchen.begin_action_session()
		_drag_ctrl.start_drag(kitchen, pos)
		return
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos) and _slot_item_keys[i] != "":
			var body := spawn_inventory_item_at(_slot_item_keys[i], pos)
			if body != null:
				var drag_start := _desk_item_drag_target(body, pos)
				body.global_position = drag_start
				_begin_shortcut_drag_preview(body, pos)
				_drag_ctrl.start_drag(body, drag_start)
			return


func _prepare_body_for_drag(body: RigidBody2D) -> void:
	body.freeze = false
	body.sleeping = false


func _update_drag_target(mouse_global_position: Vector2) -> void:
	var body := _drag_ctrl.get_body()
	if _is_body_usable(body) and body is DeskItem:
		var item := body as DeskItem
		var target := _desk_item_drag_target(item, mouse_global_position)
		_update_shortcut_drag_preview(item, mouse_global_position, target)
		_drag_ctrl.update_target_global(target)
		return
	_drag_ctrl.update_target_global(mouse_global_position)


func _desk_item_drag_target(item: DeskItem, mouse_global_position: Vector2) -> Vector2:
	var baseline_y := _table_baseline_y()
	if baseline_y == INF:
		return mouse_global_position
	var target := mouse_global_position
	var max_target_y := baseline_y - _desk_item_lower_clearance(item) - TABLE_DRAG_CLEARANCE_PADDING
	if target.y > max_target_y:
		target.y = max_target_y
	return target


func _table_baseline_y() -> float:
	if _ground_shape == null or _ground_shape.shape == null:
		return INF
	if _ground_shape.shape is SegmentShape2D:
		var segment := _ground_shape.shape as SegmentShape2D
		var a := _ground_shape.to_global(segment.a)
		var b := _ground_shape.to_global(segment.b)
		return maxf(a.y, b.y)
	return _ground_shape.global_position.y


func _desk_item_lower_clearance(item: DeskItem) -> float:
	if item == null or not is_instance_valid(item):
		return DEFAULT_DRAG_ITEM_CLEARANCE
	var shape_node := item.get_node_or_null("Shape") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return DEFAULT_DRAG_ITEM_CLEARANCE
	var shape := shape_node.shape
	var shape_offset := shape_node.position
	var lower := DEFAULT_DRAG_ITEM_CLEARANCE
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		lower = shape_offset.y + rect.size.y * 0.5
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		lower = shape_offset.y + circle.radius
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		lower = shape_offset.y + capsule.height * 0.5
	elif shape is ConvexPolygonShape2D:
		var convex := shape as ConvexPolygonShape2D
		lower = -INF
		for point in convex.points:
			lower = maxf(lower, shape_offset.y + point.y)
		if lower == -INF:
			lower = DEFAULT_DRAG_ITEM_CLEARANCE
	return maxf(8.0, lower)


func _apply_comedy_release_to_item(item: DeskItem) -> void:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return
	var speed := item.linear_velocity.length()
	if speed < COMEDY_RELEASE_MIN_SPEED:
		return
	var ratio := clampf(
		(speed - COMEDY_RELEASE_MIN_SPEED) / maxf(COMEDY_RELEASE_FULL_SPEED - COMEDY_RELEASE_MIN_SPEED, 0.01),
		0.0,
		1.0
	)
	var direction := item.linear_velocity.normalized()
	if direction == Vector2.ZERO:
		return
	var sign := 1.0 if item.linear_velocity.x >= 0.0 else -1.0
	var release_impulse_multiplier := clampf(
		float(_active_physics_law.get("release_impulse_multiplier", 1.0)),
		0.0,
		PHYSICS_LAW_MAX_DRAMATIC_MULTIPLIER)
	item.linear_velocity += direction * lerpf(
		COMEDY_RELEASE_LINEAR_BOOST_MIN,
		COMEDY_RELEASE_LINEAR_BOOST_MAX,
		ratio) * release_impulse_multiplier
	_clamp_desk_item_linear_velocity(item, COMEDY_RELEASE_MAX_LINEAR_SPEED)
	var release_spin_multiplier := clampf(
		float(_active_physics_law.get("release_spin_multiplier", 1.0)),
		0.0,
		PHYSICS_LAW_MAX_DRAMATIC_MULTIPLIER)
	item.angular_velocity = clampf(
		item.angular_velocity + sign * lerpf(COMEDY_RELEASE_SPIN_MIN, COMEDY_RELEASE_SPIN_MAX, ratio) * release_spin_multiplier,
		-COMEDY_RELEASE_MAX_ANGULAR_SPEED,
		COMEDY_RELEASE_MAX_ANGULAR_SPEED
	)
	item.sleeping = false
	record_chaos_event("fast_release", 1.0 + _active_law_chaos_feed())


func _begin_shortcut_drag_preview(item: DeskItem, mouse_global_position: Vector2) -> void:
	if item == null or not is_instance_valid(item):
		return
	_finish_shortcut_drag_preview(null, false)
	_shortcut_preview_body = item
	_shortcut_preview_body_layer = item.collision_layer
	_shortcut_preview_body_mask = item.collision_mask
	item.visible = false
	item.collision_layer = 0
	item.collision_mask = 0
	var preview := _ensure_shortcut_drag_preview()
	preview.texture = _shortcut_drag_preview_texture(item)
	preview.scale = _shortcut_drag_preview_scale(item)
	preview.global_position = mouse_global_position
	preview.visible = preview.texture != null


func _update_shortcut_drag_preview(item: DeskItem, mouse_global_position: Vector2, clamped_target: Vector2) -> void:
	if item == null or item != _shortcut_preview_body:
		return
	if mouse_global_position.distance_to(clamped_target) <= 0.5:
		_finish_shortcut_drag_preview(item, true)
		return
	var preview := _ensure_shortcut_drag_preview()
	preview.global_position = mouse_global_position
	preview.visible = preview.texture != null


func _finish_shortcut_drag_preview(item: DeskItem, restore_body: bool) -> void:
	if item != null and item != _shortcut_preview_body:
		return
	if restore_body and _shortcut_preview_body != null and is_instance_valid(_shortcut_preview_body):
		_shortcut_preview_body.visible = true
		_shortcut_preview_body.collision_layer = _shortcut_preview_body_layer
		_shortcut_preview_body.collision_mask = _shortcut_preview_body_mask
	_shortcut_preview_body = null
	_shortcut_preview_body_layer = 0
	_shortcut_preview_body_mask = 0
	var preview := get_node_or_null("ShortcutDragPreview") as Sprite2D
	if preview != null:
		preview.visible = false


func _ensure_shortcut_drag_preview() -> Sprite2D:
	var preview := get_node_or_null("ShortcutDragPreview") as Sprite2D
	if preview != null:
		return preview
	preview = Sprite2D.new()
	preview.name = "ShortcutDragPreview"
	preview.centered = true
	preview.z_index = SHORTCUT_DRAG_PREVIEW_Z_INDEX
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(preview)
	return preview


func _shortcut_drag_preview_texture(item: DeskItem) -> Texture2D:
	var icon_art := item.get_node_or_null("IconArt") as Sprite2D
	if icon_art != null and icon_art.texture != null:
		return icon_art.texture
	return _desk_item_art_texture(item.item_key)


func _shortcut_drag_preview_scale(item: DeskItem) -> Vector2:
	var icon_art := item.get_node_or_null("IconArt") as Sprite2D
	if icon_art != null:
		return icon_art.scale
	return Vector2.ONE


func _try_eject_last_ingredient(pos: Vector2) -> void:
	if _hit_test_brewery(pos):
		_eject_last_ingredient(_brewery)
		return
	if _hit_test_shaker(pos):
		_eject_last_ingredient(_shaker)
		return
	var kitchen = _hit_test_kitchen_container(pos)
	if kitchen != null and kitchen.container_key == "pot":
		_eject_last_ingredient(kitchen)


func _eject_last_ingredient(container) -> void:
	var item_key: String = container.pop_last_ingredient()
	if item_key == "":
		return
	var item := _spawn_desk_item_at(container.ingredient_output_position(), item_key)
	if container.has_method("configure_ejected_item"):
		container.configure_ejected_item(item)
	if container.has_method("ingredient_eject_velocity"):
		item.linear_velocity = container.ingredient_eject_velocity()
	else:
		item.linear_velocity = Vector2(randf_range(-70.0, 70.0), -180.0)


## 释放桌面物品时的统一分流：
##   1) 落在客人区：正式订单成品 → 正常上菜；剧情物品/叙事载体成品 → 叙事递交中介。
##   2) 其它落点 → 不处理，留在桌面（越界自走回收）。
##   注：香料装罐由 SeasoningShaker.Mouth Area2D 自动吸入（body_entered），不走本方法。
func _try_deliver(item: DeskItem) -> void:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return
	if item.item_key == "":
		return

	# 递交给客人
	if not _customer_area.get_overlapping_bodies().has(item):
		return
	var is_product: bool = _gm.inventory_sys.is_product(item.item_key)
	var is_deliverable_product: bool = _gm.inventory_sys.is_deliverable_product(item.item_key)
	var is_story_item: bool = _gm.inventory_sys.is_story_item(item.item_key)
	if not is_deliverable_product and not is_story_item:
		return
	# 无顾客等待时，普通成品弹回桌面（避免被 _serve_formal 中 queue_free 吞掉）
	if is_deliverable_product and item.product_tags.is_empty() and _gm.current_order_key() == "":
		_on_desk_item_fell(item)
		return
	# 带叙事 tag 的成品（如药酒）必须先走叙事中介，不能被订单匹配直接正常上菜吞掉。
	if is_deliverable_product and item.product_tags.is_empty() and item.item_key == _gm.current_order_key():
		_serve_formal(item)
		return
	var r: Dictionary = _gm.request_narrative_delivery(item.item_key, item.product_tags)
	if not r.get("handled", false):
		if is_deliverable_product:
			_serve_formal(item)   # 普通错单成品：正常上菜（失败反馈）
		else:
			_on_desk_item_fell(item)
		return
	if r.get("consume", false):
		item.queue_free()
	else:
		_on_desk_item_fell(item)   # 被拒：剧情物品回背包 / 成品回回收区


func _serve_formal(item: DeskItem) -> void:
	var speed: float = _drag_ctrl.get_serve_speed()
	_gm.request_serve(item.item_key, {"serve_drop_speed": speed, "quality": item.quality}, item.attribute)
	item.queue_free()


func _hit_test_item(pos: Vector2) -> DeskItem:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 8)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is DeskItem:
			return collider
	return null


func _hit_test_readable_item(pos: Vector2) -> ReadableDeskItem:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 8)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is ReadableDeskItem:
			return collider
	return null


func _hit_test_brewery(pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var hits := space.intersect_point(params, 8)
	for h in hits:
		var collider = h.get("collider")
		if collider == _brewery:
			return true
		if collider is Area2D and collider.get_parent() == _brewery:
			return true
	return false


func _hit_test_shaker(pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var hits := space.intersect_point(params, 8)
	for h in hits:
		var collider = h.get("collider")
		if collider == _shaker:
			return true
		if collider is Area2D and collider.get_parent() == _shaker:
			return true
	return false


func _hit_test_spoon(pos: Vector2) -> StirSpoon:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 4)
	for h in hits:
		if h.get("collider") is StirSpoon:
			return h.get("collider")
	return null


func _hit_test_kitchen_container(pos: Vector2):
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var hits := space.intersect_point(params, 8)
	for h in hits:
		var collider = h.get("collider")
		if _is_kitchen_container(collider):
			return collider
		if collider is Area2D and _is_kitchen_container(collider.get_parent()):
			return collider.get_parent()
	return null


func _is_kitchen_container(node: Node) -> bool:
	return node != null and node.get_script() == KITCHEN_CONTAINER_SCRIPT


func _spawn_desk_item_at(pos: Vector2, item_key: String) -> DeskItem:
	var item: DeskItem = DESK_ITEM_SCENE.instantiate()
	var item_data: Dictionary = _gm.craft.get_item(item_key)
	item.set_item(item_key, item_data, _gm.craft.get_item_physics_profiles())
	var art_texture := _desk_item_art_texture(item_key)
	if art_texture != null:
		item.set_art_texture(art_texture)
	_items_node.add_child(item)
	item.global_position = pos
	_apply_active_physics_law_to_body(item)
	# 可阅读物品：设为可拾取输入，双击时打开关联文档
	var capabilities: Array[String] = _gm.inventory_sys.get_capabilities(item_key)
	if capabilities.has("readable"):
		item.input_pickable = true
		item.document_id = item_key
		item.open_requested.connect(_gm.request_open_document)
	return item


func _desk_item_art_texture(item_key: String) -> Texture2D:
	if _gm == null:
		return null
	var texture: Texture2D = _gm.try_load_material_icon(item_key)
	if texture == null:
		return null
	var resource_path := String(texture.resource_path)
	for prefix in [TAVERN_ITEM_ICON_PREFIX, TAVERN_ITEM_ART_PREFIX, ITEM_ICON_PREFIX, PRODUCT_ICON_PREFIX]:
		if resource_path.begins_with(prefix):
			return texture
	return null


## 从背包/快捷栏拖出物品的统一入口：先扣库存，再生成桌面物理体。
func spawn_inventory_item_at(item_key: String, pos: Vector2) -> DeskItem:
	if not _gm.remove_from_inventory(item_key, 1):
		return null
	_gm.play_audio_event("drop")
	return _spawn_desk_item_at(pos, item_key)


func _try_return_to_backpack(item: DeskItem, release_global_position: Vector2) -> bool:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return false
	if item.item_key == "":
		return false
	if _inventory_overlay == null or not _inventory_overlay.accepts_world_drop(release_global_position, item.item_key):
		return false
	var target: String = _gm.recover_desk_item_key(item.item_key)
	if target != "backpack":
		return true
	item.queue_free()
	_inventory_overlay.refresh()
	_gm.play_audio_event("drop")
	return true


func _try_store_released_item_in_container(item: DeskItem, release_global_position: Vector2 = NO_RELEASE_GLOBAL_POSITION) -> bool:
	if not _is_body_usable(item):
		return false
	if _brewery.visible and _brewery.process_mode != Node.PROCESS_MODE_DISABLED:
		_brewery._try_accept_mouth_body_at_release(item, release_global_position)
		if not _is_body_usable(item):
			return true
	if _shaker.visible and _shaker.process_mode != Node.PROCESS_MODE_DISABLED:
		_shaker._try_accept_mouth_body(item)
		if not _is_body_usable(item):
			return true
	if _pot.visible and _pot.process_mode != Node.PROCESS_MODE_DISABLED:
		_pot._try_accept_body(item)
		if not _is_body_usable(item):
			return true
	return false


## 记录容器/勺子的初始位置作为泊位（越界/整理时归位）。延迟到布局稳定后调用。
func _capture_docks() -> void:
	_docks[_brewery] = _brewery.global_position
	_docks[_shaker] = _shaker.global_position
	if _ledger != null:
		_docks[_ledger] = _ledger.global_position
	for child in _items_node.get_parent().get_children():
		if _is_kitchen_container(child) or child is StirSpoon:
			_docks[child] = child.global_position


## 任何加进 Items 的 DeskItem（取材/容器产出）都连越界信号；is_connected 守卫避免重复。
func _on_items_child_added(child: Node) -> void:
	if child is DeskItem:
		if not child.fell_out_of_bounds.is_connected(_on_desk_item_fell):
			child.fell_out_of_bounds.connect(_on_desk_item_fell)
		if not child.body_entered.is_connected(_on_item_collision.bind(child)):
			child.body_entered.connect(_on_item_collision.bind(child))
		_apply_active_physics_law_to_body(child)


func _apply_active_physics_law_to_body(body: Node) -> void:
	if _active_physics_law.is_empty():
		return
	if not is_instance_valid(body) or not body is DeskItem:
		return
	_store_body_physics_law_base(body)
	var multiplier := float(_active_physics_law.get("gravity_scale_multiplier", 1.0))
	var base_gravity := float(body.get_meta(PHYSICS_LAW_META_BASE_GRAVITY))
	body.gravity_scale = clampf(base_gravity * multiplier, PHYSICS_LAW_MIN_GRAVITY, PHYSICS_LAW_MAX_GRAVITY)
	var linear_damp_multiplier := float(_active_physics_law.get("linear_damp_multiplier", 1.0))
	var angular_damp_multiplier := float(_active_physics_law.get("angular_damp_multiplier", 1.0))
	body.linear_damp = float(body.get_meta(PHYSICS_LAW_META_BASE_LINEAR_DAMP)) * linear_damp_multiplier
	body.angular_damp = float(body.get_meta(PHYSICS_LAW_META_BASE_ANGULAR_DAMP)) * angular_damp_multiplier
	if _active_physics_law.has("bounce_override"):
		_apply_bounce_override(body, float(_active_physics_law.get("bounce_override", 0.0)))
	body.set_meta(PHYSICS_LAW_META_APPLIED_ID, String(_active_physics_law.get("id", "")))


func _restore_body_physics_law(body: Node) -> void:
	if not is_instance_valid(body) or not body is DeskItem:
		return
	if body.has_meta(PHYSICS_LAW_META_BASE_GRAVITY):
		body.gravity_scale = float(body.get_meta(PHYSICS_LAW_META_BASE_GRAVITY))
		body.remove_meta(PHYSICS_LAW_META_BASE_GRAVITY)
	if body.has_meta(PHYSICS_LAW_META_BASE_LINEAR_DAMP):
		body.linear_damp = float(body.get_meta(PHYSICS_LAW_META_BASE_LINEAR_DAMP))
		body.remove_meta(PHYSICS_LAW_META_BASE_LINEAR_DAMP)
	if body.has_meta(PHYSICS_LAW_META_BASE_ANGULAR_DAMP):
		body.angular_damp = float(body.get_meta(PHYSICS_LAW_META_BASE_ANGULAR_DAMP))
		body.remove_meta(PHYSICS_LAW_META_BASE_ANGULAR_DAMP)
	if body.has_meta(PHYSICS_LAW_META_HAS_BASE_MATERIAL):
		if bool(body.get_meta(PHYSICS_LAW_META_HAS_BASE_MATERIAL)):
			body.physics_material_override = body.get_meta(PHYSICS_LAW_META_BASE_MATERIAL) as PhysicsMaterial
		else:
			body.physics_material_override = null
		body.remove_meta(PHYSICS_LAW_META_HAS_BASE_MATERIAL)
	if body.has_meta(PHYSICS_LAW_META_BASE_MATERIAL):
		body.remove_meta(PHYSICS_LAW_META_BASE_MATERIAL)
	if body.has_meta(PHYSICS_LAW_META_APPLIED_ID):
		body.remove_meta(PHYSICS_LAW_META_APPLIED_ID)


func _store_body_physics_law_base(body: DeskItem) -> void:
	if not body.has_meta(PHYSICS_LAW_META_BASE_GRAVITY):
		body.set_meta(PHYSICS_LAW_META_BASE_GRAVITY, float(body.gravity_scale))
	if not body.has_meta(PHYSICS_LAW_META_BASE_LINEAR_DAMP):
		body.set_meta(PHYSICS_LAW_META_BASE_LINEAR_DAMP, float(body.linear_damp))
	if not body.has_meta(PHYSICS_LAW_META_BASE_ANGULAR_DAMP):
		body.set_meta(PHYSICS_LAW_META_BASE_ANGULAR_DAMP, float(body.angular_damp))
	if not body.has_meta(PHYSICS_LAW_META_HAS_BASE_MATERIAL):
		var base_material := body.physics_material_override as PhysicsMaterial
		body.set_meta(PHYSICS_LAW_META_HAS_BASE_MATERIAL, base_material != null)
		if base_material != null:
			body.set_meta(PHYSICS_LAW_META_BASE_MATERIAL, base_material)


func _apply_bounce_override(body: DeskItem, bounce: float) -> void:
	var material := body.physics_material_override as PhysicsMaterial
	if material != null:
		material = material.duplicate(true) as PhysicsMaterial
	else:
		material = PhysicsMaterial.new()
	material.bounce = clampf(bounce, PHYSICS_LAW_MIN_BOUNCE, PHYSICS_LAW_MAX_BOUNCE)
	body.physics_material_override = material


## 应急整理（spec §6.5）：散落桌面物品按分类恢复，容器/勺子归泊位，
## 容器内部料状态保留（不清空）。
func tidy_desk() -> void:
	for child in _items_node.get_children():
		if child is DeskItem:
			_on_desk_item_fell(child)
	for body in _docks:
		if not is_instance_valid(body):
			continue
		_dock_body(body)


## 桌面物品越界：材料/剧情物品回背包（释放物体），成品移回回收锚点。
func _on_desk_item_fell(item: DeskItem) -> void:
	if not is_instance_valid(item):
		return
	var target: String = _gm.recover_desk_item_key(item.item_key)
	if target == "recycle":
		item.linear_velocity = Vector2.ZERO
		item.angular_velocity = 0.0
		item.global_position = _desk_item_return_position(item)
		item.freeze = true
		item.sleeping = true
		item.reset_fall_state()
	else:
		item.queue_free()


func _desk_item_return_position(item: DeskItem) -> Vector2:
	var x := clampf(item.global_position.x, DESK_RETURN_MIN_X, DESK_RETURN_MAX_X)
	var baseline_y := _table_baseline_y()
	if baseline_y == INF:
		return Vector2(x, _recycle_anchor.global_position.y)
	return Vector2(x, baseline_y - _desk_item_lower_clearance(item) - TABLE_DRAG_CLEARANCE_PADDING)


func _physics_process(_delta: float) -> void:
	_recover_docked_bodies()
	_apply_active_customer_pull(_delta)
	_update_active_physics_law_pulse(_delta)
	_update_spoon_depth()
	_update_dragged_item_depth()


func _apply_active_customer_pull(delta: float) -> void:
	if _active_physics_law.is_empty() or delta <= 0.0:
		return
	var pull := clampf(
		float(_active_physics_law.get("near_customer_pull", 0.0)),
		0.0,
		PHYSICS_LAW_MAX_CUSTOMER_PULL)
	if pull <= 0.0:
		return
	var target_position := _customer_area.global_position
	for child in _items_node.get_children():
		if not _is_physics_law_motion_target(child):
			continue
		var item := child as DeskItem
		var to_customer := target_position - item.global_position
		var distance := to_customer.length()
		if distance <= 8.0:
			continue
		var falloff := clampf(1.0 - distance / 900.0, 0.65, 1.0)
		item.linear_velocity += to_customer.normalized() * pull * delta * falloff
		_clamp_desk_item_linear_velocity(item, PHYSICS_LAW_PULL_MAX_LINEAR_SPEED)
		item.sleeping = false


func _update_active_physics_law_pulse(delta: float) -> void:
	if _active_physics_law.is_empty() or delta <= 0.0:
		return
	var lift := clampf(
		float(_active_physics_law.get("random_lift_impulse", 0.0)),
		0.0,
		PHYSICS_LAW_MAX_RANDOM_LIFT)
	if lift <= 0.0:
		return
	var interval := maxf(float(_active_physics_law.get("pulse_interval_seconds", 2.5)), 0.5)
	_physics_law_pulse_elapsed += delta
	if _physics_law_pulse_elapsed < interval:
		return
	_physics_law_pulse_elapsed = fmod(_physics_law_pulse_elapsed, interval)
	var candidates: Array[DeskItem] = []
	for child in _items_node.get_children():
		if _is_physics_law_motion_target(child):
			candidates.append(child as DeskItem)
	if candidates.is_empty():
		return
	var item := candidates[randi() % candidates.size()]
	item.linear_velocity += Vector2(randf_range(-lift * 0.18, lift * 0.18), -lift)
	item.angular_velocity = clampf(
		item.angular_velocity + randf_range(-PHYSICS_LAW_PULSE_SPIN, PHYSICS_LAW_PULSE_SPIN),
		-COMEDY_RELEASE_MAX_ANGULAR_SPEED,
		COMEDY_RELEASE_MAX_ANGULAR_SPEED)
	_clamp_desk_item_linear_velocity(item, COMEDY_RELEASE_MAX_LINEAR_SPEED)
	item.sleeping = false
	record_chaos_event("fast_release", _active_law_chaos_feed())


func _is_physics_law_motion_target(node: Node) -> bool:
	if not is_instance_valid(node) or not node is DeskItem:
		return false
	var item := node as DeskItem
	return (
		not item.is_queued_for_deletion()
		and item.item_key != ""
		and not item.is_held
		and not item.freeze
	)


func _clamp_desk_item_linear_velocity(item: DeskItem, max_speed: float) -> void:
	if item == null or max_speed <= 0.0:
		return
	if item.linear_velocity.length() > max_speed:
		item.linear_velocity = item.linear_velocity.normalized() * max_speed


func _active_law_chaos_feed() -> float:
	if _active_physics_law.is_empty():
		return 0.0
	return clampf(float(_active_physics_law.get("stage_chaos_feed", 0.0)), 0.0, 2.0)


func _update_spoon_depth() -> void:
	_spoon.set_submerged(
		_brewery.is_spoon_inside(_spoon)
		or _grill.is_spoon_inside(_spoon)
		or _pot.is_spoon_inside(_spoon)
	)


## 容器/工具越界时自动回泊位，避免关键工作台对象永久丢失。
func _update_dragged_item_depth() -> void:
	var body := _drag_ctrl.get_body()
	if not _is_body_usable(body):
		return
	if not body is DeskItem:
		return
	var item := body as DeskItem
	if not _dragged_item_surface_z_indices.has(item):
		_dragged_item_surface_z_indices[item] = item.z_index
	if _is_item_inside_any_container(item):
		item.z_index = SUBMERGED_ITEM_Z_INDEX
	else:
		item.z_index = int(_dragged_item_surface_z_indices[item])


func _restore_dragged_item_depth(item: DeskItem) -> void:
	if item == null:
		return
	if not is_instance_valid(item) or item.is_queued_for_deletion():
		_dragged_item_surface_z_indices.erase(item)
		return
	if not _dragged_item_surface_z_indices.has(item):
		return
	item.z_index = int(_dragged_item_surface_z_indices[item])
	_dragged_item_surface_z_indices.erase(item)


func _is_item_inside_any_container(item: DeskItem) -> bool:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return false
	return _brewery.is_item_inside_mouth(item) \
		or _shaker.is_item_inside_mouth(item) \
		or _grill.is_item_inside_intake(item) \
		or _pot.is_item_inside_intake(item)


func _recover_docked_bodies() -> void:
	for body in _docks:
		if is_instance_valid(body) and body.global_position.y > KILL_Y:
			_dock_body(body)


func _dock_body(body: RigidBody2D) -> void:
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.global_position = _docks[body]
	body.sleeping = true


func _exit_tree() -> void:
	clear_physics_law()
	if _gm != null and _gm.inventory_changed.is_connected(_init_material_slots):
		_gm.inventory_changed.disconnect(_init_material_slots)
	if _gm != null and _gm.inventory_changed.is_connected(_maybe_trigger_seasoning_tutorial):
		_gm.inventory_changed.disconnect(_maybe_trigger_seasoning_tutorial)
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null and tm.tutorial_sequence_ended.is_connected(_on_tutorial_sequence_ended_for_seasoning):
		tm.tutorial_sequence_ended.disconnect(_on_tutorial_sequence_ended_for_seasoning)


## 两个材料 DeskItem 高速对撞 → 按力度窗口砸合成。
## b=被撞对象（body_entered 传入），a=信号发出者（bind 的自己）。产物/容器/低速碰撞不触发。
func _on_item_collision(b: Node, a: DeskItem) -> void:
	if not is_instance_valid(a) or a.is_queued_for_deletion():
		return
	if not is_instance_valid(b) or b.is_queued_for_deletion():
		return
	if not (b is DeskItem):
		return
	var other: DeskItem = b as DeskItem
	if other.is_queued_for_deletion():
		return
	var key_a: String = a.item_key
	var key_b: String = other.item_key
	if key_a == "" or key_b == "":
		return
	# 仅材料参与砸合成（产物不可再砸）
	if _gm.craft.is_product(key_a) or _gm.craft.is_product(key_b):
		return
	var rel_speed: float = (a.linear_velocity - other.linear_velocity).length()
	_apply_active_collision_impulse(a, other, rel_speed)
	var force_tier: String = _gm.craft.classify_slam_force(rel_speed)
	if force_tier == "none":
		return
	var recipe: Dictionary = _gm.craft.find_slam_recipe([key_a, key_b])
	var center: Vector2 = (a.global_position + other.global_position) * 0.5
	var conserved: Vector2 = (a.linear_velocity + other.linear_velocity) * 0.5
	if recipe.is_empty():
		var combined_key: String = _gm.craft.get_combine_result(key_a, key_b)
		if combined_key == "":
			return
		call_deferred("_do_collision_combine", a, other, combined_key, center, conserved)
		return
	call_deferred("_do_slam_merge", a, other, recipe, force_tier, center, conserved)


func _apply_active_collision_impulse(a: DeskItem, other: DeskItem, rel_speed: float) -> void:
	if _active_physics_law.is_empty() or rel_speed < PHYSICS_LAW_COLLISION_MIN_SPEED:
		return
	var multiplier := clampf(
		float(_active_physics_law.get("collision_impulse_multiplier", 1.0)),
		0.0,
		PHYSICS_LAW_MAX_DRAMATIC_MULTIPLIER)
	if multiplier <= 1.0:
		return
	var normal := (a.global_position - other.global_position).normalized()
	if normal == Vector2.ZERO:
		normal = (a.linear_velocity - other.linear_velocity).normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.RIGHT
	var ratio := clampf((rel_speed - PHYSICS_LAW_COLLISION_MIN_SPEED) / 520.0, 0.0, 1.0)
	var side_kick := normal * PHYSICS_LAW_COLLISION_SIDE_KICK * multiplier * ratio
	var hop := Vector2(0.0, -PHYSICS_LAW_COLLISION_HOP * multiplier * ratio)
	a.linear_velocity += side_kick + hop
	other.linear_velocity -= side_kick
	other.linear_velocity += hop
	_clamp_desk_item_linear_velocity(a, COMEDY_RELEASE_MAX_LINEAR_SPEED)
	_clamp_desk_item_linear_velocity(other, COMEDY_RELEASE_MAX_LINEAR_SPEED)
	a.sleeping = false
	other.sleeping = false
	record_chaos_event("collision", _active_law_chaos_feed())


func _do_collision_combine(a: DeskItem, other: DeskItem, result_key: String, center: Vector2, conserved: Vector2) -> void:
	if not is_instance_valid(a) or not is_instance_valid(other):
		return
	if a.is_queued_for_deletion() or other.is_queued_for_deletion():
		return
	a.queue_free()
	other.queue_free()
	var combined := _spawn_desk_item_at(center, result_key)
	combined.linear_velocity = conserved
	_gm.play_audio_event("product_ready")


func _do_slam_merge(a: DeskItem, other: DeskItem, recipe: Dictionary, force_tier: String, center: Vector2, conserved: Vector2) -> void:
	if not is_instance_valid(a) or not is_instance_valid(other):
		return
	if a.is_queued_for_deletion() or other.is_queued_for_deletion():
		return
	a.queue_free()
	other.queue_free()
	var quality: String = "poor" if force_tier == "poor" else "normal"
	var product_key: String = recipe["product"]
	if bool(recipe.get("double", false)):
		var p1 := _spawn_slam_product(center + Vector2(-18, 0), product_key, quality)
		p1.linear_velocity = conserved + Vector2(0, -40)
		var p2 := _spawn_slam_product(center + Vector2(18, 0), product_key, quality)
		p2.linear_velocity = conserved + Vector2(0, 40)
	else:
		var p := _spawn_slam_product(center, product_key, quality)
		p.linear_velocity = conserved
	_gm.play_audio_event("product_ready")
	if _gm != null and _gm.has_method("discover_recipe"):
		_gm.discover_recipe(product_key, true)
	if quality == "poor":
		_gm.notify_stage_caption("手重了，砸出了次品", ThemeColors.TEXT_SUBTITLE)


func _spawn_slam_product(pos: Vector2, product_key: String, quality: String) -> DeskItem:
	var item := _spawn_desk_item_at(pos, product_key)
	item.quality = quality
	return item
