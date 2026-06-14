class_name ReadableDeskItem
extends RigidBody2D

signal open_requested(document_id: String)

const PROMPT_FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const UNREAD_HINT_TEXT := "新页"

@export var document_id: String = "ledger"
@export var display_label: String = "账本"

@onready var _label: Label = $Label


func _ready() -> void:
	_label.text = display_label
	_style_hint_label()
	_label.visible = false
	contact_monitor = true
	max_contacts_reported = 4


func set_unread_hint_visible(value: bool) -> void:
	if _label == null:
		return
	if value:
		_label.text = UNREAD_HINT_TEXT
		_label.visible = true
	else:
		_label.text = display_label
		_label.visible = false


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed \
		and event.double_click:
		request_open()


func request_open() -> void:
	if document_id != "":
		open_requested.emit(document_id)


func _style_hint_label() -> void:
	if _label == null:
		return
	_label.position = Vector2(-46.0, -58.0)
	_label.size = Vector2(92.0, 24.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", PROMPT_FONT)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
