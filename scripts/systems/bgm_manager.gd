extends Node

## 全局 BGM 管理器（Autoload）。跨场景持久，手动 _process 驱动淡入淡出。
## Tween 在 change_scene 时会被 kill，故改用帧驱动音量渐变。
##
## 用法：BGMManager.crossfade_to(stream, duration)

const DEFAULT_CROSSFADE: float = 1.5
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 0.0

enum State { IDLE, CROSSFADE, FADE_OUT }

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: String = "a"                       # "a" or "b"
var _current_stream: AudioStream = null

# 交叉淡变状态
var _state: int = State.IDLE
var _elapsed: float = 0.0
var _duration: float = 0.0
var _fade_out_player: AudioStreamPlayer = null
var _fade_in_player: AudioStreamPlayer = null


func _ready() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	_player_a.bus = "Music"
	_player_b.bus = "Music"
	_player_a.volume_db = MIN_VOLUME_DB
	_player_b.volume_db = MIN_VOLUME_DB
	add_child(_player_a)
	add_child(_player_b)
	_active = "a"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(delta: float) -> void:
	if _state == State.IDLE:
		return

	_elapsed += delta
	var t: float = clamp(_elapsed / _duration, 0.0, 1.0)

	if _state == State.CROSSFADE and _fade_out_player != null and _fade_in_player != null:
		_fade_out_player.volume_db = lerp(MAX_VOLUME_DB, MIN_VOLUME_DB, t)
		_fade_in_player.volume_db  = lerp(MIN_VOLUME_DB, MAX_VOLUME_DB, t)

	elif _state == State.FADE_OUT and _fade_out_player != null:
		_fade_out_player.volume_db = lerp(MAX_VOLUME_DB, MIN_VOLUME_DB, t)

	if t >= 1.0:
		_finish()


func _finish() -> void:
	if _state == State.CROSSFADE:
		if is_instance_valid(_fade_out_player):
			_fade_out_player.stop()
			_fade_out_player.stream = null
		_active = "b" if _active == "a" else "a"
	elif _state == State.FADE_OUT:
		if is_instance_valid(_fade_out_player):
			_fade_out_player.stop()
			_fade_out_player.stream = null

	_fade_out_player = null
	_fade_in_player = null
	_state = State.IDLE


## 淡入淡出切换到新 BGM。已播放同一曲目则跳过。
func crossfade_to(stream: AudioStream, duration: float = DEFAULT_CROSSFADE) -> void:
	if stream == null:
		return
	if stream == _current_stream:
		return
	_current_stream = stream

	_fade_out_player = _player_a if _active == "a" else _player_b
	_fade_in_player  = _player_b if _active == "a" else _player_a

	# 准备新音源（从静音开始）
	_fade_in_player.stream = stream
	_fade_in_player.volume_db = MIN_VOLUME_DB
	_fade_in_player.play()

	_elapsed = 0.0
	_duration = max(duration, 0.05)
	_state = State.CROSSFADE


## 淡出停止 BGM
func fade_out(duration: float = 0.5) -> void:
	_current_stream = null
	_fade_out_player = _player_a if _active == "a" else _player_b
	_fade_in_player = null
	if not is_instance_valid(_fade_out_player) or not _fade_out_player.playing:
		_state = State.IDLE
		return
	_fade_out_player.volume_db = MAX_VOLUME_DB
	_elapsed = 0.0
	_duration = max(duration, 0.05)
	_state = State.FADE_OUT


## 立即静音
func stop_immediate() -> void:
	_current_stream = null
	_state = State.IDLE
	_player_a.stop(); _player_a.stream = null
	_player_b.stop(); _player_b.stream = null
