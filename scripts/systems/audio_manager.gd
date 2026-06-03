class_name AudioManager
extends Node

const EVENT_PATHS := {
	"drop": "res://assets/audio/placeholders/drop.wav",
	"collision": "res://assets/audio/placeholders/collision.wav",
	"ingredient_drop": "res://assets/audio/placeholders/ingredient_drop.wav",
	"barrel_shake": "res://assets/audio/placeholders/barrel_shake.wav",
	"grill_sizzle": "res://assets/audio/placeholders/grill_sizzle.wav",
	"pot_stir": "res://assets/audio/placeholders/pot_stir.wav",
	"product_ready": "res://assets/audio/placeholders/product_ready.wav",
	"serve_success": "res://assets/audio/placeholders/serve_success.wav",
	"serve_fail": "res://assets/audio/placeholders/serve_fail.wav",
	"page_turn": "res://assets/audio/placeholders/page_turn.wav",
	"new_document": "res://assets/audio/placeholders/new_document.wav",
}

var _active_players: Array[AudioStreamPlayer] = []


func has_event(event_key: String) -> bool:
	return EVENT_PATHS.has(event_key)


func get_event_path(event_key: String) -> String:
	return String(EVENT_PATHS.get(event_key, ""))


func play_event(event_key: String) -> bool:
	if not has_event(event_key):
		return false
	if DisplayServer.get_name() == "headless":
		return true
	var stream = load(get_event_path(event_key))
	if stream == null:
		push_warning("[AudioManager] missing stream for event: " + event_key)
		return false
	var player := AudioStreamPlayer.new()
	add_child(player)
	_active_players.append(player)
	player.stream = stream
	player.pitch_scale = randf_range(0.96, 1.04) if event_key in ["drop", "collision"] else 1.0
	player.finished.connect(_on_player_finished.bind(player))
	player.play()
	return true


func _on_player_finished(player: AudioStreamPlayer) -> void:
	_active_players.erase(player)
	player.queue_free()


func _exit_tree() -> void:
	for player in _active_players:
		if is_instance_valid(player):
			player.stop()
			player.free()
	_active_players.clear()
