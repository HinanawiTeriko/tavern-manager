extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_physics_aligned_tabletop_art_layer()
	await _test_seasoning_shaker_stays_supported_by_midline_ground()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TAVERN-TABLE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TAVERN-TABLE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TAVERN-TABLE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.resource_path


func _segment_points(shape: Shape2D) -> Array:
	var segment := shape as SegmentShape2D
	if segment == null:
		return []
	return [segment.a, segment.b]


func _test_physics_aligned_tabletop_art_layer() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	_test_initial_workspace_positions(tavern)
	await get_tree().process_frame

	var background := tavern.get_node_or_null("Background") as Sprite2D
	_ok(background != null, "Tavern keeps the public Background node")
	if background != null:
		_ok(_texture_path(background.texture) == "res://assets/textures/tavern/background/tavern_bg.png",
			"Background uses Tavern no-people runtime background art")
		_ok(background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Background uses nearest texture filter")
		_ok(background.z_index < -90, "Background draws below the foreground counter")

	var tabletop := tavern.get_node_or_null("TabletopArt") as Sprite2D
	_ok(tabletop != null, "Tavern keeps the visual-only TabletopArt node")
	if tabletop != null:
		_ok(_texture_path(tabletop.texture) == "res://assets/textures/tavern/table/tabletop.png", "TabletopArt uses the background-matched foreground occluder")
		_ok(tabletop.z_index > tavern.get_node("Background").z_index, "TabletopArt draws over full-screen background")
		_ok(tabletop.z_index < 0, "TabletopArt stays behind gameplay props")
		_ok(tabletop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "TabletopArt uses nearest texture filter")
		_ok(tabletop.position == Vector2(640, 600), "TabletopArt stays aligned with the lower 280px of the background")

	var ground := tavern.get_node("BarWorkspace/World/Walls/Ground") as CollisionShape2D
	var left_wall := tavern.get_node("BarWorkspace/World/Walls/LeftWall") as CollisionShape2D
	var right_wall := tavern.get_node("BarWorkspace/World/Walls/RightWall") as CollisionShape2D
	_ok(_segment_points(ground.shape) == [Vector2(150, 536), Vector2(1130, 536)], "ground segment sits at the background table plane midline")
	_ok(not ground.one_way_collision, "background table midline ground is a solid support, not a one-way platform")
	_ok(_segment_points(left_wall.shape) == [Vector2(150, 410), Vector2(150, 536)], "left wall ends at the background table midline ground segment")
	_ok(_segment_points(right_wall.shape) == [Vector2(1130, 410), Vector2(1130, 536)], "right wall ends at the background table midline ground segment")

	var customer_drop := tavern.get_node_or_null("BarWorkspace/CustomerDropArea/Shape") as CollisionShape2D
	_ok(customer_drop != null and customer_drop.shape is RectangleShape2D, "customer drop area shape remains present")

	tavern.queue_free()


func _test_initial_workspace_positions(tavern: Node) -> void:
	_ok(tavern.get_node("BarWorkspace/World/SeasoningShaker").position == Vector2(720, 496), "seasoning shaker starts with its base on the background table midline")
	_ok(tavern.get_node("BarWorkspace/World/RecycleAnchor").position == Vector2(640, 450), "recycle anchor starts aligned with the background work surface")
	_ok(tavern.get_node("BarWorkspace/World/Ledger").position == Vector2(230, 461), "ledger starts on the background work surface")
	_ok(tavern.get_node("BarWorkspace/World/Brewery").position == Vector2(960, 481), "brewery starts on the background work surface")
	_ok(tavern.get_node("BarWorkspace/World/Grill").position == Vector2(330, 501), "grill starts on the background work surface")
	_ok(tavern.get_node("BarWorkspace/World/Pot").position == Vector2(520, 481), "pot starts on the background work surface")
	_ok(tavern.get_node("BarWorkspace/World/Spoon").position == Vector2(700, 471), "spoon starts on the background work surface")


func _test_seasoning_shaker_stays_supported_by_midline_ground() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var shaker := tavern.get_node("BarWorkspace/World/SeasoningShaker") as RigidBody2D
	var start_y := shaker.global_position.y
	for _i in range(30):
		await get_tree().physics_frame

	_ok(shaker.global_position.y <= start_y + 8.0,
		"seasoning shaker remains supported by tabletop midline ground: start %.2f, now %.2f" % [start_y, shaker.global_position.y])
	_ok(absf(shaker.linear_velocity.y) <= 20.0,
		"seasoning shaker is not still falling after settling: velocity %.2f" % shaker.linear_velocity.y)
	tavern.queue_free()
