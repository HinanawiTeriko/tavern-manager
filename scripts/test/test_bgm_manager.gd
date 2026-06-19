extends Node

const BGM_SCRIPT_PATHS := [
	"res://scripts/ui/title_screen.gd",
	"res://scripts/ui/day_map_view.gd",
	"res://scripts/ui/tavern_view.gd",
	"res://scripts/ui/ledger_screen.gd",
	"res://scripts/ui/mine_investigation.gd",
	"res://scripts/ui/ending_screen.gd",
]

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_scene_scripts_do_not_preload_raw_bgm_wavs()
	_test_bgm_manager_owns_path_loading_and_looping()
	_test_transparent_shade_out_is_noop()
	BGMManager.stop_immediate()
	_finish()


func _test_scene_scripts_do_not_preload_raw_bgm_wavs() -> void:
	for path in BGM_SCRIPT_PATHS:
		var file := FileAccess.open(path, FileAccess.READ)
		_ok(file != null, "BGM scene script exists: " + path)
		if file == null:
			continue
		var text := file.get_as_text()
		file.close()
		_ok(
			not text.contains("preload(\"res://assets/audio/bgm/"),
			path + " avoids parse-time BGM wav preload"
		)


func _test_bgm_manager_owns_path_loading_and_looping() -> void:
	var file := FileAccess.open("res://scripts/systems/bgm_manager.gd", FileAccess.READ)
	_ok(file != null, "BGM manager script exists")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_ok(text.contains("func crossfade_to_path"), "BGM manager exposes path-based crossfade")
	_ok(text.contains("_current_stream_key"), "BGM manager tracks source identity for idempotent path playback")
	_ok(text.contains("LOOP_FORWARD"), "BGM manager prepares WAV streams for looping")
	_ok(text.contains("settings.apply_all()"), "BGM manager reapplies loaded settings after Music bus setup")


func _test_transparent_shade_out_is_noop() -> void:
	var shade_rect := BGMManager.get("_shade_rect") as ColorRect
	_ok(shade_rect != null, "BGM shade rect exists")
	if shade_rect == null:
		return
	shade_rect.modulate.a = 0.0
	BGMManager.set("_shade_state", 0)
	BGMManager.fade_shade_out()
	_ok(int(BGMManager.get("_shade_state")) == 0, "transparent fade_shade_out remains hidden")
	_ok(is_zero_approx(shade_rect.modulate.a), "transparent fade_shade_out keeps alpha at zero")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-BGM] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-BGM] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-BGM] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
