extends Node

## 香料系统单元测：数据查询 + resolve_seasoning_application 判定。
## 物理装罐/摇撒走人工编辑器验证。

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_seasoning_queries()
	_test_taste_applies_attribute()
	_test_sleep_powder_on_ale()
	_test_sleep_powder_rejects_non_ale()
	_test_non_seasoning_rejected()
	await _test_shaker_combo_visual_feedback()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SEASONING] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-SEASONING] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SEASONING] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _gm():
	return get_node("/root/GameManager")


func _test_seasoning_queries() -> void:
	var s = _gm().seasoning
	_ok(s.get_attribute("spice") == "辛辣", "spice attribute is 辛辣")
	_ok(s.get_category("spice") == "taste", "spice category is taste")
	_ok(s.get_category("sleep_powder") == "effect", "sleep_powder category is effect")
	_ok(s.get_product_tag("sleep_powder") == "sleep_powder", "sleep_powder carries product_tag")
	_ok(s.get_product_tag("spice") == "", "taste seasoning has no product_tag")


func _test_taste_applies_attribute() -> void:
	var r: Dictionary = _gm().resolve_seasoning_application("spice", "ale_beer")
	_ok(r.get("accepted", false), "taste seasoning always applies")
	_ok(String(r.get("attribute", "")) == "辛辣", "taste seasoning writes its attribute")
	_ok((r.get("product_tags", []) as Array).is_empty(), "taste seasoning carries no tag")


func _test_sleep_powder_on_ale() -> void:
	var r: Dictionary = _gm().resolve_seasoning_application("sleep_powder", "ale_beer")
	_ok(r.get("accepted", false), "sleep_powder applies to ale_beer")
	_ok(String(r.get("attribute", "")) == "安眠", "drugged ale gets 安眠 attribute")
	_ok((r.get("product_tags", []) as Array).has("sleep_powder"), "drugged ale carries sleep_powder tag")


func _test_sleep_powder_rejects_non_ale() -> void:
	var r: Dictionary = _gm().resolve_seasoning_application("sleep_powder", "bread")
	_ok(not r.get("accepted", true), "sleep_powder rejects non-ale products")


func _test_non_seasoning_rejected() -> void:
	var r: Dictionary = _gm().resolve_seasoning_application("ale", "ale_beer")
	_ok(not r.get("accepted", true), "non-seasoning key is rejected")


func _test_shaker_combo_visual_feedback() -> void:
	var shaker := preload("res://scenes/ui/SeasoningShaker.tscn").instantiate() as SeasoningShaker
	add_child(shaker)
	await get_tree().process_frame

	shaker.load_seasoning("spice")
	shaker.begin_shake_session()
	shaker.linear_velocity = Vector2(320.0, 0.0)
	for i in range(8):
		shaker._physics_process(0.05)
	_ok(_shaker_combo_value(shaker) == 0,
		"seasoning shaker combo does not increase from one-direction movement")
	_ok(shaker.get_node_or_null("SpiceComboHud") == null,
		"seasoning shaker combo HUD stays hidden until real shake cycles")
	shaker.end_shake_session()
	_clear_shaker_powder(shaker)

	shaker.load_seasoning("spice")
	shaker.begin_shake_session()
	_drive_shaker_combo_to(shaker, 1)
	var low_combo_powder_count := _spawn_shaker_test_powder(shaker, 260.0)
	_ok(_shaker_combo_value(shaker) == 1,
		"one full seasoning shake cycle counts exactly one combo")
	var combo_hud := shaker.get_node_or_null("SpiceComboHud") as CanvasLayer
	_ok(combo_hud != null,
		"seasoning shaker creates a combo HUD after real shake cycles")
	var combo_label := combo_hud.get_node_or_null("ComboLabel") as Label if combo_hud != null else null
	var rank_label := combo_hud.get_node_or_null("RankLabel") as Label if combo_hud != null else null
	_ok(combo_label != null and combo_label.text == "SPICE COMBO x1",
		"seasoning shaker combo HUD shows the current combo")
	_ok(rank_label != null and rank_label.text != "",
		"seasoning shaker combo HUD shows a seasoning rank word")
	_clear_shaker_powder(shaker)

	_drive_shaker_combo_to(shaker, 6)
	var high_combo_powder_count := _spawn_shaker_test_powder(shaker, 260.0)
	_ok(_shaker_combo_value(shaker) >= 6,
		"seasoning shaker combo keeps counting continued real shake cycles")
	_ok(high_combo_powder_count >= low_combo_powder_count + 4,
		"higher seasoning combo creates denser powder at the same movement speed")
	_ok(_shaker_powder_mist_count(shaker) >= 2,
		"higher seasoning combo adds visible powder mist")
	_ok(_shaker_powder_sprite_count(shaker) == high_combo_powder_count,
		"seasoning powder particles use the generated runtime sprite atlas")

	_drive_shaker_combo_to(shaker, 10)
	var combo_vfx := shaker.get_node_or_null("SpiceComboVfx") as Node2D
	_ok(combo_vfx != null,
		"higher seasoning combo creates a dedicated spice combo VFX layer")
	_ok(_shaker_spice_vfx_count(shaker, "rank") >= 3,
		"higher seasoning combo pops visible rank words at stage upgrades")
	_ok(_shaker_spice_vfx_count(shaker, "spark") >= 3,
		"higher seasoning combo throws extra individual sparkle particles")
	_ok(_shaker_spice_sprite_vfx_count(shaker, "spark") >= 3,
		"higher seasoning combo spark particles use the generated runtime sprite atlas")
	var shake_camera := shaker.get_node_or_null("SpiceShakeCamera") as Camera2D
	_ok(shake_camera != null and shake_camera.offset.length() > 0.0,
		"higher seasoning combo adds a light screen shake")

	var product := _spawn_desk_item("ale_beer")
	add_child(product)
	product.global_position = shaker.global_position + Vector2(0.0, 56.0)
	product.freeze = true
	product.sleeping = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	shaker.end_shake_session()
	await get_tree().process_frame
	_ok(product.attribute != "",
		"successful seasoning application still writes the product attribute")
	_ok(_shaker_spice_vfx_count(shaker, "settle_word") >= 1,
		"successful seasoning application leaves a visible verdict word")
	_ok(_shaker_spice_vfx_count(shaker, "settle_cloud") >= 8,
		"successful seasoning application bursts a dense powder cloud")
	_ok(_shaker_spice_sprite_vfx_count(shaker, "settle_cloud") >= 8,
		"successful seasoning application cloud particles use the generated runtime sprite atlas")

	product.queue_free()
	shaker.queue_free()
	await get_tree().process_frame


func _drive_shaker_combo_to(shaker: SeasoningShaker, target_combo: int) -> void:
	if not shaker.get("_session_active"):
		shaker.begin_shake_session()
	var direction := 1.0
	shaker.linear_velocity = Vector2(280.0, 0.0)
	shaker._physics_process(0.05)
	var guard := 0
	while _shaker_combo_value(shaker) < target_combo and guard < target_combo * 4 + 12:
		direction *= -1.0
		shaker.linear_velocity = Vector2(280.0 * direction, 0.0)
		shaker._physics_process(0.05)
		guard += 1


func _spawn_shaker_test_powder(shaker: SeasoningShaker, speed: float) -> int:
	_clear_shaker_powder(shaker)
	shaker.linear_velocity = Vector2(speed, 0.0)
	for i in range(8):
		shaker._physics_process(0.05)
	return _shaker_powder_count(shaker)


func _shaker_combo_value(shaker: SeasoningShaker) -> int:
	var value = shaker.get("_seasoning_combo")
	if value == null:
		return 0
	return int(value)


func _shaker_powder_count(shaker: SeasoningShaker) -> int:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func _shaker_powder_mist_count(shaker: SeasoningShaker) -> int:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D and String((child as Node2D).get_meta("seasoning_powder_kind", "")) == "mist":
			count += 1
	return count


func _shaker_powder_sprite_count(shaker: SeasoningShaker) -> int:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if not child is Node2D:
			continue
		var sprite := (child as Node2D).get_node_or_null("Sprite") as Sprite2D
		if _is_seasoning_particle_sprite(sprite):
			count += 1
	return count


func _shaker_spice_vfx_count(shaker: SeasoningShaker, element: String) -> int:
	var layer := shaker.get_node_or_null("SpiceComboVfx") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("spice_combo_element", "")) == element:
			count += 1
	return count


func _shaker_spice_sprite_vfx_count(shaker: SeasoningShaker, element: String) -> int:
	var layer := shaker.get_node_or_null("SpiceComboVfx") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if not child is Node2D:
			continue
		var effect := child as Node2D
		if String(effect.get_meta("spice_combo_element", "")) != element:
			continue
		var sprite := effect.get_node_or_null("Sprite") as Sprite2D
		if _is_seasoning_particle_sprite(sprite):
			count += 1
	return count


func _is_seasoning_particle_sprite(sprite: Sprite2D) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	return sprite.region_enabled \
		and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST \
		and String(sprite.texture.resource_path) == "res://assets/textures/seasoning_particles/seasoning_particles.png"


func _spawn_desk_item(item_key: String) -> DeskItem:
	var scene := preload("res://scenes/test/desk_item.tscn")
	var item := scene.instantiate() as DeskItem
	item.set_item(item_key, GameManager.craft.get_item(item_key), GameManager.craft.get_item_physics_profiles())
	return item


func _clear_shaker_powder(shaker: SeasoningShaker) -> void:
	var layer := shaker.get_node_or_null("SeasoningPowderLayer") as Node2D
	if layer != null:
		for child in layer.get_children():
			child.free()
	var particles = shaker.get("_powder_particles")
	if particles is Array:
		(particles as Array).clear()
