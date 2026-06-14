extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_marker_scale()
	_test_daymap_typography_source()
	_finish()


func _test_marker_scale() -> void:
	_ok(MapPointMarker.ICON_DISPLAY_SIZE >= 38.0 and MapPointMarker.ICON_DISPLAY_SIZE <= 42.0,
		"marker icon is large enough to read but still a map symbol")
	_ok(MapPointMarker.HOME_ICON_DISPLAY_SIZE >= 42.0 and MapPointMarker.HOME_ICON_DISPLAY_SIZE <= 48.0,
		"home marker icon is readable without becoming landmark art")
	_ok(MapPointMarker.BASE_DISPLAY_SIZE >= 56.0 and MapPointMarker.BASE_DISPLAY_SIZE <= 64.0,
		"marker base remains visible when the camera is zoomed out")
	_ok(MapPointMarker.HOME_BASE_DISPLAY_SIZE >= 64.0 and MapPointMarker.HOME_BASE_DISPLAY_SIZE <= 72.0,
		"home marker base has a clear tavern anchor presence")
	_ok(MapPointMarker.SELECTED_RING_DISPLAY_SIZE >= 74.0 and MapPointMarker.SELECTED_RING_DISPLAY_SIZE <= 82.0,
		"selected marker ring is readable at normal map distance")
	_ok(MapPointMarker.REVEAL_DISPLAY_SIZE >= 84.0 and MapPointMarker.REVEAL_DISPLAY_SIZE <= 92.0,
		"reveal marker burst has enough presence to be noticed")
	_ok(MapPointMarker.MARKER_LABEL_FONT_SIZE <= 12, "marker label font is subordinate to map art")
	_ok(MapPointMarker.MARKER_LABEL_DEFAULT_ALPHA >= 0.18 and MapPointMarker.MARKER_LABEL_DEFAULT_ALPHA <= 0.30,
		"default marker labels stay subtle but are no longer invisible")

	var source := FileAccess.get_file_as_string("res://scripts/ui/map_point_marker.gd")
	_ok(source.contains("MARKER_LABEL_FONT_SIZE"), "marker label size is controlled by a named constant")
	_ok(source.contains("MARKER_LABEL_DEFAULT_ALPHA"), "marker default label alpha is controlled by a named constant")


func _test_daymap_typography_source() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/day_map_view.gd")
	_ok(source.contains("DAYMAP_STATUS_FONT_SIZE"), "DayMap status font size is centralized")
	_ok(source.contains("DAYMAP_HEADER_FONT_SIZE"), "DayMap header font size is centralized")
	_ok(source.contains("DAYMAP_BODY_FONT_SIZE"), "DayMap body font size is centralized")
	_ok(source.contains("DAYMAP_RESULT_FONT_SIZE"), "DayMap result font size is centralized")
	_ok(source.contains("DAYMAP_TOPBAR_STRIP"), "DayMap top bar uses native texture material")
	_ok(source.contains("DAYMAP_PINNED_NOTE_PANEL"), "DayMap pinned note uses native texture material")
	_ok(source.contains("PINNED_NOTE_RIGHT_OFFSET"), "DayMap pinned note position is controlled by a named marker offset")
	_ok(source.contains("to_local(marker.global_position)"), "DayMap pinned note is anchored in map-world coordinates")
	_ok(source.contains("DAYMAP_DETAIL_INSET"), "DayMap detail text uses a named safe inset")
	_ok(source.contains("DAYMAP_RESULT_INSET"), "DayMap result text uses a named safe inset")
	_ok(source.contains("DAYMAP_BUTTON_TEXT_MARGIN_X"), "DayMap button text has a named horizontal safe margin")
	_ok(not source.contains("add_theme_font_size_override(\"font_size\", 22)"), "DayMap no longer applies hard-coded 22px text")
	_ok(not source.contains("add_theme_font_size_override(\"font_size\", 20)"), "DayMap no longer applies hard-coded 20px text")
	_ok(not source.contains("add_theme_font_size_override(\"font_size\", 18)"), "DayMap no longer applies hard-coded 18px text")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAYMAP-VISUAL] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DAYMAP-VISUAL] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DAYMAP-VISUAL] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
