class_name SeasoningPanel
extends Control

signal seasoning_applied(key: String)
signal seasoning_skipped()

var _btn_row: HBoxContainer
var _gm
var _current_item_key: String = ""

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_btn_row = HBoxContainer.new()
	add_child(_btn_row)
	visible = false

func show_for(item_key: String) -> void:
	if not _gm.craft.is_product(item_key):
		visible = false
		return

	_current_item_key = item_key

	for child in _btn_row.get_children():
		child.queue_free()

	for key in _gm.seasoning.seasonings:
		var data: Dictionary = _gm.seasoning.seasonings[key]
		var btn = Button.new()
		btn.text = data.get("name", key)
		ThemeColors.style_small_button(btn, 12)
		btn.pressed.connect(func(): seasoning_applied.emit(key); hide())
		_btn_row.add_child(btn)

	var skip_btn = Button.new()
	skip_btn.text = "不加"
	ThemeColors.style_small_button(skip_btn, 12)
	skip_btn.pressed.connect(func(): seasoning_skipped.emit(); hide())
	_btn_row.add_child(skip_btn)

	visible = true
