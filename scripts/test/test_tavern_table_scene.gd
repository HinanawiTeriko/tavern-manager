extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_bar_counter_art_layer()
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


func _test_bar_counter_art_layer() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var counter := tavern.get_node_or_null("BarCounterArt") as Sprite2D
	_ok(counter != null, "Tavern has visual-only BarCounterArt node")
	if counter != null:
		_ok(_texture_path(counter.texture) == "res://assets/textures/tavern/table/bar_counter.png", "BarCounterArt uses runtime bar counter texture")
		_ok(counter.z_index > tavern.get_node("Background").z_index, "BarCounterArt draws over full-screen background")
		_ok(counter.z_index < 0, "BarCounterArt stays behind gameplay props")
		_ok(counter.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "BarCounterArt uses nearest texture filter")
		_ok(counter.position == Vector2(640, 624), "BarCounterArt is a smaller bottom bar counter layer")

	var ground := tavern.get_node("BarWorkspace/World/Walls/Ground") as CollisionShape2D
	var left_wall := tavern.get_node("BarWorkspace/World/Walls/LeftWall") as CollisionShape2D
	var right_wall := tavern.get_node("BarWorkspace/World/Walls/RightWall") as CollisionShape2D
	_ok(_segment_points(ground.shape) == [Vector2(150, 655), Vector2(1130, 655)], "ground segment contract is unchanged")
	_ok(_segment_points(left_wall.shape) == [Vector2(150, 410), Vector2(150, 655)], "left wall segment contract is unchanged")
	_ok(_segment_points(right_wall.shape) == [Vector2(1130, 410), Vector2(1130, 655)], "right wall segment contract is unchanged")

	var customer_drop := tavern.get_node_or_null("BarWorkspace/CustomerDropArea/Shape") as CollisionShape2D
	_ok(customer_drop != null and customer_drop.shape is RectangleShape2D, "customer drop area shape remains present")

	tavern.queue_free()
