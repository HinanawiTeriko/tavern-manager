extends Node

const TAVERN_SCENE := preload("res://scenes/ui/Tavern.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_fast_release_adds_comedy_spin()
	_finish()


func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST-DEFAULT-COMEDY-PHYSICS] FAIL: " + message)


func _test_fast_release_adds_comedy_spin() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	_ok(bar != null, "Tavern should expose BarWorkspace")
	if bar == null:
		tavern.queue_free()
		await get_tree().process_frame
		return

	var item := bar._spawn_desk_item_at(Vector2(540.0, 340.0), "ale")
	await get_tree().process_frame
	item.linear_velocity = Vector2(720.0, -160.0)
	item.angular_velocity = 0.0

	bar._on_drag_ended(item)
	await get_tree().process_frame

	_ok(absf(item.angular_velocity) >= 2.0, "fast desk item releases should add visible comedy spin")
	_ok(item.linear_velocity.length() <= 1200.1, "release impulse should stay under the DeskItem speed guardrail")

	tavern.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("[TEST-DEFAULT-COMEDY-PHYSICS] checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
