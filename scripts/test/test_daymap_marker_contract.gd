extends Node

var _checks := 0
var _failures := 0

const EXPECTED_MARKERS := {
	"market_shop": "res://assets/textures/daymap/markers/market_shop.png",
	"mira_stall": "res://assets/textures/daymap/markers/mira_stall.png",
	"toby_lodging": "res://assets/textures/daymap/markers/toby_lodging.png",
	"fixer_den": "res://assets/textures/daymap/markers/fixer_den.png",
}


func _ready() -> void:
	_test_map_point_marker_declares_story_icons()
	_test_locations_bind_story_marker_keys()
	_test_marker_instances_load_story_textures()
	_finish()


func _test_map_point_marker_declares_story_icons() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/map_point_marker.gd")
	for marker_id in EXPECTED_MARKERS:
		_ok(source.contains("\"%s\"" % marker_id), marker_id + " icon key is declared")
		_ok(source.contains(String(EXPECTED_MARKERS[marker_id])), marker_id + " runtime texture path is declared")


func _test_locations_bind_story_marker_keys() -> void:
	var locations := _load_locations()
	for marker_id in EXPECTED_MARKERS:
		var loc := _find_location(locations, marker_id)
		_ok(not loc.is_empty(), marker_id + " location exists")
		_ok(String(loc.get("marker", "")) == marker_id, marker_id + " location binds its marker key explicitly")


func _test_marker_instances_load_story_textures() -> void:
	for marker_id in EXPECTED_MARKERS:
		var marker := MapPointMarker.new()
		add_child(marker)
		marker.setup({
			"id": marker_id,
			"name": marker_id,
			"marker": marker_id,
			"pos": [100, 100],
		})
		_ok(marker.has_icon_texture(), marker_id + " marker loads a texture")
		if marker.has_icon_texture():
			_ok(
				marker._icon.texture.resource_path == String(EXPECTED_MARKERS[marker_id]),
				marker_id + " marker loads the expected runtime texture"
			)
		marker.queue_free()


func _load_locations() -> Array:
	var file := FileAccess.open("res://data/locations.json", FileAccess.READ)
	_ok(file != null, "locations data is readable")
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(parsed is Dictionary, "locations data parses as a dictionary")
	if not (parsed is Dictionary):
		return []
	return (parsed as Dictionary).get("locations", [])


func _find_location(locations: Array, location_id: String) -> Dictionary:
	for loc in locations:
		if loc is Dictionary and String(loc.get("id", "")) == location_id:
			return loc
	return {}


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAYMAP-MARKER] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DAYMAP-MARKER] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DAYMAP-MARKER] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
