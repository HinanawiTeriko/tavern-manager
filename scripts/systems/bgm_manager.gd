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
var _shade_done_callback: Callable


func _ready() -> void:
	# 确保 "Music" 音频总线存在
	if AudioServer.get_bus_index("Music") < 0:
		var master_idx := AudioServer.get_bus_index("Master")
		AudioServer.add_bus(master_idx + 1)
		AudioServer.set_bus_name(master_idx + 1, "Music")
		AudioServer.set_bus_send(master_idx + 1, "Master")

	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	_player_a.bus = "Music"; _player_b.bus = "Music"
	_player_a.volume_db = MIN_VOLUME_DB; _player_b.volume_db = MIN_VOLUME_DB
	add_child(_player_a); add_child(_player_b)

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
			_shade_rect.modulate.a = 1.0 - st
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
	if stream == null or stream == _current_stream:
		return
	_current_stream = stream
	_fade_out_player = _player_a if _active == "a" else _player_b
	_fade_in_player  = _player_b if _active == "a" else _player_a
	_fade_in_player.stream = stream
	_fade_in_player.volume_db = MIN_VOLUME_DB
	_fade_in_player.play()
	_elapsed = 0.0; _duration = max(duration, 0.05)
	_state = State.CROSSFADE


func fade_out(duration: float = 0.5) -> void:
	_current_stream = null
	_fade_out_player = _player_a if _active == "a" else _player_b
	_fade_in_player = null
	if not is_instance_valid(_fade_out_player) or not _fade_out_player.playing:
		_state = State.IDLE; return
	_fade_out_player.volume_db = MAX_VOLUME_DB
	_elapsed = 0.0; _duration = max(duration, 0.05)
	_state = State.FADE_OUT


func stop_immediate() -> void:
	_current_stream = null; _state = State.IDLE
	_player_a.stop(); _player_a.stream = null
	_player_b.stop(); _player_b.stream = null


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
	_shade_state = 3
	_shade_elapsed = 0.0
