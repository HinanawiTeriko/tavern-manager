extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_tabletop_art_layer()
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


func _test_tabletop_art_layer() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var table := tavern.get_node_or_null("TabletopArt") as Sprite2D
	_ok(table != null, "Tavern has visual-only TabletopArt node")
	if table != null:
		_ok(_texture_path(table.texture) == "res://assets/textures/tavern/table/tabletop.png", "TabletopArt uses runtime tabletop texture")
		_ok(table.z_index > tavern.get_node("Background").z_index, "TabletopArt draws over full-screen background")
		_ok(table.z_index < 0, "TabletopArt stays behind gameplay props")
		_ok(table.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "TabletopArt uses nearest texture filter")

	var ground := tavern.get_node("BarWorkspace/World/Walls/Ground") as CollisionShape2D
	var left_wall := tavern.get_node("BarWorkspace/World/Walls/LeftWall") as CollisionShape2D
	var right_wall := tavern.get_node("BarWorkspace/World/Walls/RightWall") as CollisionShape2D
	_ok(_segment_points(ground.shape) == [Vector2(150, 655), Vector2(1130, 655)], "ground segment contract is unchanged")
	_ok(_segment_points(left_wall.shape) == [Vector2(150, 410), Vector2(150, 655)], "left wall segment contract is unchanged")
	_ok(_segment_points(right_wall.shape) == [Vector2(1130, 410), Vector2(1130, 655)], "right wall segment contract is unchanged")

	var customer_drop := tavern.get_node_or_null("BarWorkspace/CustomerDropArea/Shape") as CollisionShape2D
	_ok(customer_drop != null and customer_drop.shape is RectangleShape2D, "customer drop area shape remains present")

	tavern.queue_free()
