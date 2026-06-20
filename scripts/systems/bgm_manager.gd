extends Node

## 全局 BGM 管理器 + 场景过渡遮罩（Autoload）。跨场景持久。
## 用法：BGMManager.crossfade_to(stream) / BGMManager.fade_out()
##       BGMManager.fade_shade_in() / fade_shade_out()

const DEFAULT_CROSSFADE: float = 1.5
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 0.0
const SHADE_FADE_DURATION: float = 0.8

enum State { IDLE, CROSSFADE, FADE_OUT }

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: String = "a"
var _current_stream: AudioStream = null
var _current_stream_key: String = ""
var _pending_web_bgm_stream: AudioStream = null
var _pending_web_bgm_stream_key: String = ""
var _pending_web_bgm_duration: float = DEFAULT_CROSSFADE
var _web_audio_unlocked: bool = false

# 交叉淡变状态
var _state: int = State.IDLE
var _elapsed: float = 0.0
var _duration: float = 0.0
var _fade_out_player: AudioStreamPlayer = null
var _fade_in_player: AudioStreamPlayer = null

# 场景过渡遮罩（CanvasLayer 持久于 autoload）
var _shade_layer: CanvasLayer
var _shade_rect: ColorRect
var _shade_state: int = 0  # 0=hidden, 1=fading_in, 2=visible, 3=fading_out
var _shade_elapsed: float = 0.0
var _shade_fade_start_alpha: float = 1.0
var _shade_done_callback: Callable


func _ready() -> void:
	# 确保 "Music" 音频总线存在
	if AudioServer.get_bus_index("Music") < 0:
		var master_idx := AudioServer.get_bus_index("Master")
		AudioServer.add_bus(master_idx + 1)
		AudioServer.set_bus_name(master_idx + 1, "Music")
		AudioServer.set_bus_send(master_idx + 1, "Master")
	_apply_settings_volume()

	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	_player_a.bus = "Music"; _player_b.bus = "Music"
	_player_a.volume_db = MIN_VOLUME_DB; _player_b.volume_db = MIN_VOLUME_DB
	add_child(_player_a); add_child(_player_b)
	_player_a.finished.connect(_on_bgm_player_finished.bind(_player_a))
	_player_b.finished.connect(_on_bgm_player_finished.bind(_player_b))

	# 场景过渡遮罩
	_shade_layer = CanvasLayer.new()
	_shade_layer.layer = 999
	add_child(_shade_layer)

	_shade_rect = ColorRect.new()
	_shade_rect.color = Color.BLACK
	_shade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade_rect.modulate.a = 0.0
	_shade_layer.add_child(_shade_rect)

	_active = "a"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not OS.has_feature("web") or _web_audio_unlocked:
		return
	if not _is_web_audio_unlock_event(event):
		return
	_web_audio_unlocked = true
	_flush_pending_web_bgm()


func _process(delta: float) -> void:
	# BGM 淡变
	if _state != State.IDLE:
		_elapsed += delta
		var t: float = clamp(_elapsed / _duration, 0.0, 1.0)
		if _state == State.CROSSFADE and _fade_out_player != null and _fade_in_player != null:
			_fade_out_player.volume_db = lerp(MAX_VOLUME_DB, MIN_VOLUME_DB, t)
			_fade_in_player.volume_db  = lerp(MIN_VOLUME_DB, MAX_VOLUME_DB, t)
		elif _state == State.FADE_OUT and _fade_out_player != null:
			_fade_out_player.volume_db = lerp(MAX_VOLUME_DB, MIN_VOLUME_DB, t)
		if t >= 1.0:
			_bgm_finish()

	# 遮罩淡变
	match _shade_state:
		1:  # fading_in
			_shade_elapsed += delta
			var st: float = clamp(_shade_elapsed / SHADE_FADE_DURATION, 0.0, 1.0)
			_shade_rect.modulate.a = st
			if st >= 1.0:
				_shade_state = 2
				if _shade_done_callback.is_valid():
					_shade_done_callback.call()
		3:  # fading_out
			_shade_elapsed += delta
			var st: float = clamp(_shade_elapsed / SHADE_FADE_DURATION, 0.0, 1.0)
			_shade_rect.modulate.a = lerpf(_shade_fade_start_alpha, 0.0, st)
			if st >= 1.0:
				_shade_state = 0


# ============================================================
#  BGM
# ============================================================

func _bgm_finish() -> void:
	if _state == State.CROSSFADE:
		if is_instance_valid(_fade_out_player):
			_fade_out_player.stop()
			_fade_out_player.stream = null
		_active = "b" if _active == "a" else "a"
	elif _state == State.FADE_OUT:
		if is_instance_valid(_fade_out_player):
			_fade_out_player.stop()
			_fade_out_player.stream = null
	_fade_out_player = null; _fade_in_player = null
	_state = State.IDLE


func crossfade_to(stream: AudioStream, duration: float = DEFAULT_CROSSFADE) -> void:
	var stream_key := ""
	if stream != null:
		stream_key = "stream:%d" % stream.get_instance_id()
	_crossfade_to_stream(stream, stream_key, duration)


func crossfade_to_path(path: String, duration: float = DEFAULT_CROSSFADE) -> void:
	if path == "":
		return
	if path == _current_stream_key and _active_player_is_playing():
		return
	var resource := load(path)
	var stream := resource as AudioStream
	if stream == null:
		push_warning("BGMManager could not load BGM stream: " + path)
		return
	_crossfade_to_stream(stream, path, duration)


func _crossfade_to_stream(stream: AudioStream, stream_key: String, duration: float, ignore_web_gate: bool = false) -> void:
	if stream == null or stream_key == _current_stream_key:
		return
	if not ignore_web_gate and _should_defer_web_bgm():
		_defer_web_bgm(stream, stream_key, duration)
		return
	var prepared_stream := _prepare_bgm_stream(stream)
	_current_stream = prepared_stream
	_current_stream_key = stream_key
	_fade_out_player = _player_a if _active == "a" else _player_b
	_fade_in_player  = _player_b if _active == "a" else _player_a
	_fade_in_player.stream = prepared_stream
	_fade_in_player.volume_db = MIN_VOLUME_DB
	_fade_in_player.play()
	_elapsed = 0.0; _duration = max(duration, 0.05)
	_state = State.CROSSFADE


func _should_defer_web_bgm() -> bool:
	return OS.has_feature("web") and not _web_audio_unlocked


func _defer_web_bgm(stream: AudioStream, stream_key: String, duration: float) -> void:
	_pending_web_bgm_stream = stream
	_pending_web_bgm_stream_key = stream_key
	_pending_web_bgm_duration = duration


func _flush_pending_web_bgm() -> void:
	if _pending_web_bgm_stream == null or _pending_web_bgm_stream_key == "":
		return
	var stream := _pending_web_bgm_stream
	var stream_key := _pending_web_bgm_stream_key
	var duration := _pending_web_bgm_duration
	_pending_web_bgm_stream = null
	_pending_web_bgm_stream_key = ""
	_pending_web_bgm_duration = DEFAULT_CROSSFADE
	_crossfade_to_stream(stream, stream_key, duration, true)


func _is_web_audio_unlock_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _prepare_bgm_stream(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return stream
	# Imported compressed WAV resources can stop immediately when loop_mode is changed.
	# Keep the stream untouched; loop by replaying the active player on finished.
	return wav


func _active_player_is_playing() -> bool:
	var active_player := _player_a if _active == "a" else _player_b
	return is_instance_valid(active_player) and active_player.playing


func _on_bgm_player_finished(player: AudioStreamPlayer) -> void:
	if _state != State.IDLE or _current_stream_key == "":
		return
	var active_player := _player_a if _active == "a" else _player_b
	if player != active_player or player.stream == null:
		return
	player.play()


func fade_out(duration: float = 0.5) -> void:
	_current_stream = null
	_current_stream_key = ""
	_pending_web_bgm_stream = null
	_pending_web_bgm_stream_key = ""
	_fade_out_player = _player_a if _active == "a" else _player_b
	_fade_in_player = null
	if not is_instance_valid(_fade_out_player) or not _fade_out_player.playing:
		_state = State.IDLE; return
	_fade_out_player.volume_db = MAX_VOLUME_DB
	_elapsed = 0.0; _duration = max(duration, 0.05)
	_state = State.FADE_OUT


func stop_immediate() -> void:
	_current_stream = null; _state = State.IDLE
	_current_stream_key = ""
	_pending_web_bgm_stream = null
	_pending_web_bgm_stream_key = ""
	_player_a.stop(); _player_a.stream = null
	_player_b.stop(); _player_b.stream = null


func _apply_settings_volume() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var settings = gm.get("settings")
	if settings != null and settings.has_method("apply_all"):
		settings.apply_all()


# ============================================================
#  场景过渡遮罩
# ============================================================

## 黑幕渐入 → 完成后调用 callback（用于打烊→切场景）
func fade_shade_in(callback: Callable = Callable()) -> void:
	_shade_state = 1
	_shade_elapsed = 0.0
	_shade_rect.modulate.a = 0.0
	_shade_done_callback = callback


## 黑幕渐出（新场景 ready 时调用）
func fade_shade_out() -> void:
	if _shade_rect == null:
		return
	if _shade_state == 0 and _shade_rect.modulate.a <= 0.001:
		_shade_rect.modulate.a = 0.0
		return
	_shade_state = 3
	_shade_elapsed = 0.0
	_shade_fade_start_alpha = clampf(_shade_rect.modulate.a, 0.0, 1.0)
