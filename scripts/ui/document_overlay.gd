class_name DocumentOverlay
extends Control

signal closed()

@onready var _title: Label = $Panel/Title
@onready var _panel: Panel = $Panel
@onready var _left_body: Label = $Panel/LeftBody
@onready var _right_body: Label = $Panel/RightBody
@onready var _page_label: Label = $Panel/PageLabel
@onready var _previous_button: Button = $Panel/PreviousBtn
@onready var _next_button: Button = $Panel/NextBtn
@onready var _close_button: Button = $Panel/CloseBtn

var _pages: Array = []
var _page_index: int = 0
var _kind: String = ""
var _drag_start_x: float = -1.0


func _ready() -> void:
	_previous_button.pressed.connect(previous_page)
	_next_button.pressed.connect(next_page)
	_close_button.pressed.connect(close)
	_panel.gui_input.connect(_on_panel_gui_input)


func open_document(document: Dictionary) -> void:
	_title.text = String(document.get("title", "文档"))
	_kind = String(document.get("kind", "document"))
	_pages = document.get("pages", []).duplicate()
	if _pages.is_empty():
		_pages.append("")
	_page_index = 0
	_refresh_page()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func next_page() -> void:
	var step := _page_step()
	if _page_index + step < _pages.size():
		_page_index += step
		_refresh_page()
		GameManager.play_audio_event("page_turn")


func previous_page() -> void:
	if _page_index > 0:
		_page_index = maxi(0, _page_index - _page_step())
		_refresh_page()
		GameManager.play_audio_event("page_turn")


func get_current_page_text() -> String:
	return _left_body.text


func get_right_page_text() -> String:
	return _right_body.text


func _on_panel_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_drag_start_x = event.position.x
		return
	if _drag_start_x < 0.0:
		return
	var dragged: float = event.position.x - _drag_start_x
	_drag_start_x = -1.0
	if absf(dragged) < _panel.size.x * 0.4:
		return
	if dragged < 0.0:
		next_page()
	else:
		previous_page()


func _page_step() -> int:
	return 2 if _kind == "ledger" else 1


func _refresh_page() -> void:
	_left_body.text = String(_pages[_page_index])
	_right_body.visible = _kind == "ledger"
	_right_body.text = String(_pages[_page_index + 1]) if _kind == "ledger" and _page_index + 1 < _pages.size() else ""
	var last_visible_page := mini(_page_index + _page_step(), _pages.size())
	_page_label.text = "%d-%d / %d" % [_page_index + 1, last_visible_page, _pages.size()]
	_previous_button.disabled = _page_index == 0
	_next_button.disabled = _page_index + _page_step() >= _pages.size()
