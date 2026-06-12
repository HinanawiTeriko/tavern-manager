class_name ReadableDeskItem
extends RigidBody2D

signal open_requested(document_id: String)

@export var document_id: String = "ledger"
@export var display_label: String = "账本"

@onready var _label: Label = $Label


func _ready() -> void:
	_label.text = display_label
	contact_monitor = true
	max_contacts_reported = 4


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed \
		and event.double_click:
		request_open()


func request_open() -> void:
	if document_id != "":
		open_requested.emit(document_id)
