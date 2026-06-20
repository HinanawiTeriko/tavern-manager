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
	_test_bgm_manager_defers_web_bgm_until_user_input()
	_test_web_bgm_immediate_start_uses_audible_volume()
	_test_web_bgm_routes_to_master_bus()
	_test_bgm_manager_does_not_duplicate_imported_wav_streams()
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
	_ok(text.contains("finished.connect"), "BGM manager loops music with player finished signals")
	_ok(text.contains("_on_bgm_player_finished"), "BGM manager owns player-level replay looping")
	_ok(text.contains("settings.apply_all()"), "BGM manager reapplies loaded settings after Music bus setup")


func _test_bgm_manager_defers_web_bgm_until_user_input() -> void:
	var file := FileAccess.open("res://scripts/systems/bgm_manager.gd", FileAccess.READ)
	_ok(file != null, "BGM manager script exists for web unlock checks")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_ok(text.contains("OS.has_feature(\"web\")"), "BGM manager detects web exports for browser audio policy")
	_ok(text.contains("_pending_web_bgm_stream"), "BGM manager stores the first web BGM request until input")
	_ok(text.contains("func _input"), "BGM manager listens before scene input can consume the first click")
	_ok(text.contains("_flush_pending_web_bgm"), "BGM manager flushes deferred BGM after the browser unlock input")
	_ok(text.contains("_is_web_audio_unlock_event"), "BGM manager filters real user gesture events")
	_ok(text.contains("InputEventMouseButton"), "mouse clicks unlock web BGM")
	_ok(text.contains("InputEventScreenTouch"), "touch taps unlock web BGM")
	_ok(text.contains("InputEventKey"), "keyboard input unlocks web BGM")


func _test_web_bgm_immediate_start_uses_audible_volume() -> void:
	_ok(BGMManager.has_method("_start_bgm_immediate"), "BGM manager has a no-fade Web start path")
	if not BGMManager.has_method("_start_bgm_immediate"):
		return
	BGMManager.stop_immediate()
	var stream := load("res://assets/audio/bgm/title.wav") as AudioStreamWAV
	_ok(stream != null, "title BGM loads for immediate start")
	if stream == null:
		return
	BGMManager.call("_start_bgm_immediate", stream, "test:web-immediate")
	var active := String(BGMManager.get("_active"))
	var player := BGMManager.get("_player_a") as AudioStreamPlayer
	if active == "b":
		player = BGMManager.get("_player_b") as AudioStreamPlayer
	_ok(player != null, "immediate start selects an active player")
	if player == null:
		return
	_ok(player.stream == stream, "immediate start assigns the requested stream")
	_ok(is_equal_approx(player.volume_db, 0.0), "immediate start begins at audible volume")
	_ok(player.playing, "immediate start begins playback")
	_ok(String(BGMManager.get("_current_stream_key")) == "test:web-immediate", "immediate start records stream key")
	_ok(int(BGMManager.get("_state")) == 0, "immediate start does not depend on fade state")
	BGMManager.stop_immediate()


func _test_web_bgm_routes_to_master_bus() -> void:
	_ok(BGMManager.has_method("_bgm_bus_name"), "BGM manager exposes a platform-aware BGM bus selector")
	if not BGMManager.has_method("_bgm_bus_name"):
		return
	_ok(String(BGMManager.call("_bgm_bus_name", true)) == "Master", "web BGM routes to Master to avoid WebAudio bus loops")
	_ok(String(BGMManager.call("_bgm_bus_name", false)) == "Music", "desktop BGM keeps the dedicated Music bus")
	var file := FileAccess.open("res://scripts/systems/bgm_manager.gd", FileAccess.READ)
	_ok(file != null, "BGM manager script exists for web bus checks")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_ok(text.contains("_ensure_music_bus"), "BGM manager isolates desktop Music bus creation behind a helper")
	_ok(text.contains("if not OS.has_feature(\"web\")"), "web export skips creating the dedicated Music bus")


func _test_bgm_manager_does_not_duplicate_imported_wav_streams() -> void:
	var stream := load("res://assets/audio/bgm/title.wav") as AudioStreamWAV
	_ok(stream != null, "title BGM loads as WAV")
	if stream == null:
		return
	var prepared := BGMManager.call("_prepare_bgm_stream", stream) as AudioStreamWAV
	_ok(prepared == stream, "BGM manager keeps imported WAV stream instance playable")
	_ok(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "BGM manager leaves imported WAV loop mode unchanged")


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
