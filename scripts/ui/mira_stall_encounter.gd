class_name MiraStallEncounter
extends Node2D

signal finished()

const DIALOGUE_BALLOON_SCENE := preload("res://scenes/ui/DialogueBalloon.tscn")
const DIALOGUE_PATH := "res://dialogue/mira_stall_encounter.dialogue"
const DEFAULT_MIRA_PORTRAIT := "res://assets/textures/characters/mira_neutral.png"
const MIRA_PORTRAIT_BY_STATE := {
	"after_truth_trusted": "res://assets/textures/characters/mira_resolved.png",
	"after_truth_guarded": "res://assets/textures/characters/mira_detached.png",
	"responsibility": "res://assets/textures/characters/mira_guilty.png",
	"old_relation": "res://assets/textures/characters/mira_conflicted.png",
	"phrase": "res://assets/textures/characters/mira_serious.png",
	"mentor": "res://assets/textures/characters/mira_serious.png",
}

@export var auto_start_dialogue: bool = true

var _dialogue_active: bool = false

@onready var _mira_portrait: Sprite2D = $MiraPortrait


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _mira_portrait != null:
		_mira_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_apply_mira_portrait_expression_for_state(_current_mira_stall_state())
	if auto_start_dialogue:
		call_deferred("_start_dialogue")


func _start_dialogue() -> void:
	var dialogue_resource = load(DIALOGUE_PATH)
	if dialogue_resource == null:
		printerr("[MiraStallEncounter] dialogue failed to load: ", DIALOGUE_PATH)
		_finish()
		return

	var extra_states: Array = []
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.narrative != null:
		extra_states.append(gm.narrative.dialogue_vars)

	var ended := Callable(self, "_on_dialogue_ended")
	if not DialogueManager.dialogue_ended.is_connected(ended):
		DialogueManager.dialogue_ended.connect(ended)

	_dialogue_active = true
	var balloon = DialogueManager.show_dialogue_balloon_scene(
		DIALOGUE_BALLOON_SCENE,
		dialogue_resource,
		"start",
		extra_states
	)
	if balloon == null:
		printerr("[MiraStallEncounter] dialogue balloon failed to show")
		_dialogue_active = false
		_disconnect_dialogue_signal()
		_finish()
		return
	balloon.will_block_other_input = false


func _current_mira_stall_state() -> String:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.narrative != null:
		return str(gm.narrative.get_var("mira_stall_encounter_state"))
	return ""


func _apply_mira_portrait_expression_for_state(state: String) -> void:
	if _mira_portrait == null:
		return
	var texture_path := str(MIRA_PORTRAIT_BY_STATE.get(state, DEFAULT_MIRA_PORTRAIT))
	var texture := load(texture_path) as Texture2D
	if texture != null:
		_mira_portrait.texture = texture


func _on_dialogue_ended(_resource = null) -> void:
	if not _dialogue_active:
		return
	_dialogue_active = false
	_disconnect_dialogue_signal()
	call_deferred("_finish")


func _finish() -> void:
	finished.emit()


func _exit_tree() -> void:
	_disconnect_dialogue_signal()


func _disconnect_dialogue_signal() -> void:
	var ended := Callable(self, "_on_dialogue_ended")
	if DialogueManager.dialogue_ended.is_connected(ended):
		DialogueManager.dialogue_ended.disconnect(ended)
