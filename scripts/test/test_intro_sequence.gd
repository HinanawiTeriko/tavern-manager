extends Node

const INTRO_SCENE := preload("res://scenes/ui/IntroSequence.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_load_intro()
	_test_schema_contract()
	_test_visual_contract()
	_test_scene_tree()
	_test_missing_image_degrades()
	_test_skip_input_reachable()
	_test_handoff_flag()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-INTRO] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-INTRO] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-INTRO] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_load_intro() -> void:
	var data := IntroSequence.load_intro("res://data/intro.json")
	_ok(data.has("beats"), "load_intro returns dict with beats")
	var beats: Array = data["beats"]
	_ok(beats.size() >= 4, "intro has at least 4 beats")
	_ok(beats[0].has("text") and beats[0].has("fade_in") and beats[0].has("hold"), "beat carries text/fade_in/hold")
	_ok(String(beats[beats.size() - 1].get("text", "")).contains("推开"), "last beat is the door-push (match-cut anchor)")
	var empty := IntroSequence.load_intro("res://data/__no_such__.json")
	_ok(empty.get("beats", []).is_empty(), "missing file degrades to empty beats")


func _test_schema_contract() -> void:
	var data := IntroSequence.load_intro("res://data/intro.json")
	var beats: Array = data["beats"]
	for index in beats.size():
		var beat: Dictionary = beats[index]
		_ok(beat.has("image") and typeof(beat["image"]) == TYPE_STRING, "beat %d has string image field" % index)
		_ok(beat.has("kenburns"), "beat %d has kenburns" % index)
		var kb: Dictionary = beat.get("kenburns", {})
		_ok(kb.has("from") and kb.has("to"), "beat %d kenburns has from/to" % index)
		var from_off := _kb_offset(kb, "from")
		var to_off := _kb_offset(kb, "to")
		var zoom_delta := absf(_kb_zoom(kb, "to") - _kb_zoom(kb, "from"))
		_ok(from_off.distance_to(to_off) > 0.0 or zoom_delta > 0.0, "beat %d has Ken Burns motion" % index)


func _test_visual_contract() -> void:
	_ok(IntroSequence.INTRO_FONT != null, "IntroSequence exposes a pixel font")
	_ok(ResourceLoader.exists("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"), "pixel font resource exists")


func _test_handoff_flag() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.consume_intro_handoff() == false, "handoff defaults to false")
	gm._pending_intro_handoff = true
	_ok(gm.consume_intro_handoff() == true, "first consume returns true")
	_ok(gm.consume_intro_handoff() == false, "second consume returns false (one-shot)")
	gm.new_game()
	_ok(gm.consume_intro_handoff() == true, "new_game sets handoff for match-cut")


func _test_scene_tree() -> void:
	var intro := INTRO_SCENE.instantiate()
	_ok(intro.get_node_or_null("Still") != null, "scene has Still sprite")
	_ok(intro.get_node_or_null("BlackBG") != null, "scene has BlackBG")
	_ok(intro.get_node_or_null("NarrationLabel") != null, "scene has NarrationLabel")
	_ok(intro.get_node_or_null("LetterTop") != null, "scene has LetterTop")
	_ok(intro.get_node_or_null("LetterBottom") != null, "scene has LetterBottom")
	_ok(intro.get_node_or_null("BackgroundBack") == null, "old parallax layers removed")
	intro.queue_free()


func _test_missing_image_degrades() -> void:
	# 当前盘上无任何开场图：加入树触发 _ready→_play，应不抛错，且 Still 隐藏
	var intro := INTRO_SCENE.instantiate()
	add_child(intro)
	var still: Sprite2D = intro.get_node_or_null("Still")
	_ok(still != null and still.visible == false, "Still hidden when image missing")
	intro.queue_free()


func _test_skip_input_reachable() -> void:
	# 点击跳过依赖 _unhandled_input 收到鼠标事件；任何 mouse_filter=STOP 的装饰 Control 都会吞掉点击
	var intro := INTRO_SCENE.instantiate()
	var blockers := _controls_blocking_mouse(intro)
	_ok(blockers.is_empty(), "no decorative Control swallows the skip click (STOP filter on: %s)" % str(blockers))
	intro.queue_free()


func _controls_blocking_mouse(node: Node) -> Array:
	var blocking: Array = []
	if node is Control and (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		blocking.append(String(node.name))
	for child in node.get_children():
		blocking.append_array(_controls_blocking_mouse(child))
	return blocking


func _kb_offset(kb: Dictionary, key: String) -> Vector2:
	var seg: Dictionary = kb.get(key, {})
	var off: Array = seg.get("offset", [0, 0])
	return Vector2(float(off[0]), float(off[1]))


func _kb_zoom(kb: Dictionary, key: String) -> float:
	var seg: Dictionary = kb.get(key, {})
	return float(seg.get("zoom", 1.0))
