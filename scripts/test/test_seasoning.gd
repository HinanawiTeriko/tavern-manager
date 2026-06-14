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
	await _test_shaker_powder_sticks_to_product_while_shaking()
	await _test_shaker_consumes_loaded_seasoning_after_stuck_powder_release()
	await _test_mist_powder_does_not_become_surface_crumb()
	await _test_stuck_powder_builds_visible_pile_depth()
	await _test_stuck_powder_forms_mound_after_heavy_shaking()
	await _test_stuck_powder_height_keeps_growing_without_hard_cap()
	await _test_stuck_powder_can_visually_overhang_product_edge()
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


func _test_shaker_powder_sticks_to_product_while_shaking() -> void:
	var shaker := preload("res://scenes/ui/SeasoningShaker.tscn").instantiate() as SeasoningShaker
	add_child(shaker)
	await get_tree().process_frame
	shaker.global_position = Vector2(520.0, 220.0)

	var product := _spawn_desk_item("ale_beer")
	add_child(product)
	product.global_position = shaker.global_position + Vector2(-20.0, 56.0)
	product.freeze = true
	product.sleeping = false
	await get_tree().physics_frame

	shaker.load_seasoning("spice")
	shaker.begin_shake_session()
	_drive_shaker_combo_to(shaker, 6)
	_drive_shaker_powder_for_frames(shaker, 80)

	var first_surface_count := _product_seasoning_visual_count(product, "surface")
	var first_centroid := _product_seasoning_visual_centroid(product, "surface")
	var mouth_local := product.to_local(shaker.to_global(Vector2(0.0, -42.0)))
	_ok(first_surface_count >= 4,
		"falling shaker powder sticks to the product surface while shaking, before settlement")
	_ok(product.attribute == "",
		"falling powder does not apply the seasoning attribute before shake settlement")
	_ok(absf(first_centroid.x - mouth_local.x) <= 12.0,
		"stuck powder pile centers near the actual shaker mouth landing x: got %.2f expected %.2f" % [
			first_centroid.x,
			mouth_local.x,
		])

	_drive_shaker_powder_for_frames(shaker, 50)
	var second_surface_count := _product_seasoning_visual_count(product, "surface")
	_ok(second_surface_count >= first_surface_count + 4,
		"continued shaking keeps adding stuck powder crumbs to the product: first=%d second=%d" % [
			first_surface_count,
			second_surface_count,
		])

	shaker.end_shake_session()
	await get_tree().process_frame
	_ok(product.attribute != "",
		"settlement still applies the product attribute after powder has stuck during shaking")
	_ok(_product_seasoning_visual_count(product, "surface") >= second_surface_count,
		"settlement does not remove powder crumbs that already stuck to the food surface")

	product.queue_free()
	shaker.queue_free()
	await get_tree().process_frame


func _test_shaker_consumes_loaded_seasoning_after_stuck_powder_release() -> void:
	var shaker := preload("res://scenes/ui/SeasoningShaker.tscn").instantiate() as SeasoningShaker
	add_child(shaker)
	await get_tree().process_frame
	shaker.global_position = Vector2(520.0, 220.0)

	var product := _spawn_desk_item("ale_beer")
	add_child(product)
	product.global_position = shaker.global_position + Vector2(-20.0, 56.0)
	product.freeze = true
	product.sleeping = false
	await get_tree().physics_frame

	shaker.load_seasoning("spice")
	shaker.begin_shake_session()
	_drive_shaker_combo_to(shaker, 6)
	_drive_shaker_powder_for_frames(shaker, 80)
	_ok(_product_seasoning_visual_count(product, "surface") >= 4,
		"test setup sticks visible powder to the product before release")

	shaker.global_position = product.global_position + Vector2(180.0, -90.0)
	await get_tree().physics_frame
	shaker.end_shake_session()
	await get_tree().process_frame
	_ok(product.attribute != "",
		"stuck powder still applies seasoning even if the shaker is released off the product")
	_ok(shaker.loaded_key == "",
		"stuck powder release consumes the loaded seasoning instead of leaving the shaker full")

	product.queue_free()
	shaker.queue_free()
	await get_tree().process_frame


func _test_mist_powder_does_not_become_surface_crumb() -> void:
	var product := _spawn_desk_item("ale_beer")
	add_child(product)
	product.global_position = Vector2(520.0, 320.0)
	product.freeze = true
	product.sleeping = false
	await get_tree().process_frame

	var hit_local := Vector2(4.0, -7.0)
	var mist_region_rect := Rect2(Vector2(0.0, 192.0), Vector2(96.0, 96.0))
	var flake_region_rect := Rect2(Vector2(96.0, 0.0), Vector2(96.0, 96.0))
	_ok(not product.stick_seasoning_particle(
		product.to_global(hit_local),
		"spice",
		"mist",
		mist_region_rect,
		Color(0.96, 0.9, 0.68, 0.42),
		Vector2.ONE * 0.1,
		0.0
	), "mist powder should not become a lasting product surface crumb")
	_ok(_product_seasoning_visual_count(product, "surface") == 0,
		"rejecting mist leaves no persistent surface crumb")
	_ok(product.stick_seasoning_particle(
		product.to_global(hit_local),
		"spice",
		"flake",
		flake_region_rect,
		Color(1.0, 0.34, 0.14, 0.9),
		Vector2.ONE * 0.1,
		0.0
	), "flake powder can still become a lasting product surface crumb")
	_ok(_product_seasoning_visual_count(product, "surface") == 1,
		"surface crumbs still work for non-mist particles")

	product.queue_free()
	await get_tree().process_frame


func _test_stuck_powder_builds_visible_pile_depth() -> void:
	var product := _spawn_desk_item("ale_beer")
	add_child(product)
	product.global_position = Vector2(520.0, 320.0)
	product.freeze = true
	product.sleeping = false
	await get_tree().process_frame

	var hit_local := Vector2(6.0, -8.0)
	var region_rect := Rect2(Vector2(96.0, 0.0), Vector2(96.0, 96.0))
	for i in range(12):
		_ok(product.stick_seasoning_particle(
			product.to_global(hit_local),
			"spice",
			"flake",
			region_rect,
			Color(1.0, 0.34, 0.14, 0.9),
			Vector2.ONE * 0.1,
			0.0
		), "test powder particle sticks to the food surface")

	var surface_count := _product_seasoning_visual_count(product, "surface")
	var y_range := _product_seasoning_visual_y_range(product, "surface")
	var z_range := _product_seasoning_visual_z_range(product, "surface")
	var scale_range := _product_seasoning_visual_scale_range(product, "surface")
	_ok(surface_count >= 12,
		"repeated powder particles remain as accumulated surface crumbs")
	_ok(y_range.y - y_range.x >= 2.0,
		"repeated powder particles build visible pile height instead of staying flat: y_range=%s" % y_range)
	_ok(z_range.y >= z_range.x + 3,
		"repeated powder particles stack into higher draw layers: z_range=%s" % z_range)
	_ok(scale_range.y >= scale_range.x + 0.02,
		"repeated powder particles thicken the pile with larger top crumbs: scale_range=%s" % scale_range)

	product.queue_free()
	await get_tree().process_frame


func _test_stuck_powder_forms_mound_after_heavy_shaking() -> void:
	var product := _spawn_desk_item("ale_beer")
	add_child(product)
	product.global_position = Vector2(520.0, 320.0)
	product.freeze = true
	product.sleeping = false
	await get_tree().process_frame

	var hit_local := Vector2(4.0, -7.0)
	var region_rect := Rect2(Vector2(96.0, 0.0), Vector2(96.0, 96.0))
	for i in range(36):
		var local_jitter := Vector2(
			lerpf(-2.0, 2.0, float(posmod(i * 5, 9)) / 8.0),
			lerpf(-1.2, 1.2, float(posmod(i * 7, 5)) / 4.0)
		)
		_ok(product.stick_seasoning_particle(
			product.to_global(hit_local + local_jitter),
			"spice",
			"flake",
			region_rect,
			Color(1.0, 0.34, 0.14, 0.9),
			Vector2.ONE * 0.1,
			0.0
		), "heavy shake powder particle sticks to the food surface")

	var y_range := _product_seasoning_visual_y_range(product, "surface")
	var z_range := _product_seasoning_visual_z_range(product, "surface")
	var scale_range := _product_seasoning_visual_scale_range(product, "surface")
	var top_count := _product_seasoning_visual_count_above_y(product, "surface", y_range.y - 10.0)
	_ok(_product_seasoning_visual_count(product, "surface") >= 36,
		"heavy shaking keeps every accepted powder crumb on the product surface")
	_ok(y_range.y - y_range.x >= 12.0,
		"heavy shaking builds a small mound instead of a flat dust patch: y_range=%s" % y_range)
	_ok(z_range.y >= z_range.x + 24,
		"heavy shaking gives the mound enough draw depth for visible layering: z_range=%s" % z_range)
	_ok(scale_range.y >= scale_range.x + 0.08,
		"heavy shaking thickens top crumbs enough to read as a mound: scale_range=%s" % scale_range)
	_ok(top_count >= 6,
		"heavy shaking leaves several crumbs in the raised top area: top_count=%d y_range=%s" % [
			top_count,
			y_range,
		])

	product.queue_free()
	await get_tree().process_frame


func _test_stuck_powder_height_keeps_growing_without_hard_cap() -> void:
	var product := _spawn_desk_item("ale_beer")
	add_child(product)
	product.global_position = Vector2(520.0, 320.0)
	product.freeze = true
	product.sleeping = false
	await get_tree().process_frame

	var hit_local := Vector2(4.0, -7.0)
	var region_rect := Rect2(Vector2(96.0, 0.0), Vector2(96.0, 96.0))
	_stick_test_powder_cluster(product, hit_local, region_rect, 0, 36)
	var y_range_36 := _product_seasoning_visual_y_range(product, "surface")
	var z_range_36 := _product_seasoning_visual_z_range(product, "surface")
	_stick_test_powder_cluster(product, hit_local, region_rect, 36, 36)
	var y_range_72 := _product_seasoning_visual_y_range(product, "surface")
	var z_range_72 := _product_seasoning_visual_z_range(product, "surface")
	var height_36 := y_range_36.y - y_range_36.x
	var height_72 := y_range_72.y - y_range_72.x
	_ok(height_72 >= height_36 + 4.0,
		"continued shaking keeps raising the seasoning mound instead of hitting a hard height cap: h36=%.2f h72=%.2f" % [
			height_36,
			height_72,
		])
	_ok(z_range_72.y >= z_range_36.y + 24,
		"continued shaking keeps adding higher draw layers instead of hitting a small z cap: z36=%s z72=%s" % [
			z_range_36,
			z_range_72,
		])

	product.queue_free()
	await get_tree().process_frame


func _test_stuck_powder_can_visually_overhang_product_edge() -> void:
	var product := _spawn_desk_item("ale_beer")
	add_child(product)
	product.global_position = Vector2(520.0, 320.0)
	product.freeze = true
	product.sleeping = false
	await get_tree().process_frame

	var half_extents := product._seasoning_visual_half_extents()
	var edge_hit_local := Vector2(half_extents.x - 0.2, -7.0)
	var region_rect := Rect2(Vector2(96.0, 0.0), Vector2(96.0, 96.0))
	_ok(product.stick_seasoning_particle(
		product.to_global(edge_hit_local),
		"spice",
		"flake",
		region_rect,
		Color(1.0, 0.34, 0.14, 0.9),
		Vector2.ONE * 0.1,
		0.0
	), "edge powder particle still sticks when the hit point is on the food")

	var x_range := _product_seasoning_visual_x_range(product, "surface")
	_ok(x_range.y >= half_extents.x + 2.0,
		"edge crumbs can visibly overhang outside the product instead of being clamped inside: x_range=%s half_x=%.2f" % [
			x_range,
			half_extents.x,
		])

	product.queue_free()
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


func _drive_shaker_powder_for_frames(shaker: SeasoningShaker, frame_count: int) -> void:
	var direction := 1.0
	for i in range(frame_count):
		if i % 5 == 0:
			direction *= -1.0
		shaker.linear_velocity = Vector2(280.0 * direction, 0.0)
		shaker._physics_process(0.05)


func _stick_test_powder_cluster(product: DeskItem, hit_local: Vector2, region_rect: Rect2, start_index: int, count: int) -> void:
	for i in range(start_index, start_index + count):
		var local_jitter := Vector2(
			lerpf(-2.0, 2.0, float(posmod(i * 5, 9)) / 8.0),
			lerpf(-1.2, 1.2, float(posmod(i * 7, 5)) / 4.0)
		)
		_ok(product.stick_seasoning_particle(
			product.to_global(hit_local + local_jitter),
			"spice",
			"flake",
			region_rect,
			Color(1.0, 0.34, 0.14, 0.9),
			Vector2.ONE * 0.1,
			0.0
		), "test powder particle sticks to the food surface")


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


func _product_seasoning_visual_count(product: DeskItem, visual_kind: String) -> int:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("product_seasoning_visual_kind", "")) == visual_kind:
			count += 1
	return count


func _product_seasoning_sprite_count(product: DeskItem) -> int:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if not child is Node2D:
			continue
		if child.is_queued_for_deletion():
			continue
		var sprite := (child as Node2D).get_node_or_null("Sprite") as Sprite2D
		if _is_seasoning_particle_sprite(sprite):
			count += 1
	return count


func _product_seasoning_visual_centroid(product: DeskItem, visual_kind: String) -> Vector2:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var count := 0
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("product_seasoning_visual_kind", "")) == visual_kind:
			sum += (child as Node2D).position
			count += 1
	if count <= 0:
		return Vector2.ZERO
	return sum / float(count)


func _product_seasoning_visual_average_distance(product: DeskItem, visual_kind: String, center: Vector2) -> float:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return 0.0
	var total := 0.0
	var count := 0
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("product_seasoning_visual_kind", "")) == visual_kind:
			total += ((child as Node2D).position - center).length()
			count += 1
	if count <= 0:
		return 0.0
	return total / float(count)


func _product_seasoning_visual_y_range(product: DeskItem, visual_kind: String) -> Vector2:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return Vector2.ZERO
	var min_y := INF
	var max_y := -INF
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("product_seasoning_visual_kind", "")) == visual_kind:
			min_y = minf(min_y, (child as Node2D).position.y)
			max_y = maxf(max_y, (child as Node2D).position.y)
	if min_y == INF:
		return Vector2.ZERO
	return Vector2(min_y, max_y)


func _product_seasoning_visual_x_range(product: DeskItem, visual_kind: String) -> Vector2:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return Vector2.ZERO
	var min_x := INF
	var max_x := -INF
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("product_seasoning_visual_kind", "")) == visual_kind:
			min_x = minf(min_x, (child as Node2D).position.x)
			max_x = maxf(max_x, (child as Node2D).position.x)
	if min_x == INF:
		return Vector2.ZERO
	return Vector2(min_x, max_x)


func _product_seasoning_visual_z_range(product: DeskItem, visual_kind: String) -> Vector2i:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return Vector2i.ZERO
	var min_z := 2147483647
	var max_z := -2147483648
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("product_seasoning_visual_kind", "")) == visual_kind:
			min_z = mini(min_z, (child as Node2D).z_index)
			max_z = maxi(max_z, (child as Node2D).z_index)
	if min_z == 2147483647:
		return Vector2i.ZERO
	return Vector2i(min_z, max_z)


func _product_seasoning_visual_scale_range(product: DeskItem, visual_kind: String) -> Vector2:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return Vector2.ZERO
	var min_scale := INF
	var max_scale := -INF
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("product_seasoning_visual_kind", "")) == visual_kind:
			var scale_value := maxf((child as Node2D).scale.x, (child as Node2D).scale.y)
			min_scale = minf(min_scale, scale_value)
			max_scale = maxf(max_scale, scale_value)
	if min_scale == INF:
		return Vector2.ZERO
	return Vector2(min_scale, max_scale)


func _product_seasoning_visual_count_above_y(product: DeskItem, visual_kind: String, max_y: float) -> int:
	var layer := product.get_node_or_null("SeasoningVisual") as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta("product_seasoning_visual_kind", "")) == visual_kind \
				and (child as Node2D).position.y <= max_y:
			count += 1
	return count


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
