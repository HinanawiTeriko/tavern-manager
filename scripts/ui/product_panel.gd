class_name ProductPanel
extends Control

signal product_selected(key: String)

var _list: VBoxContainer
var _gm
var _mixing_area

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_mixing_area = get_node("../MixingArea")
	_list = VBoxContainer.new()
	add_child(_list)
	_mixing_area.contents_changed.connect(_refresh)

func _exit_tree() -> void:
	if _mixing_area != null:
		_mixing_area.contents_changed.disconnect(_refresh)

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var contents: Array = _mixing_area._items
	if contents.size() == 0:
		return

	var products: Array = []

	for key in contents:
		var ops: Dictionary = _gm.craft.get_operations(key)
		for result_key in ops.values():
			if not products.has(result_key):
				products.append(result_key)

	var distinct: Array = []
	for k in contents:
		if not distinct.has(k):
			distinct.append(k)

	if distinct.size() >= 2:
		for i in range(distinct.size()):
			for j in range(i + 1, distinct.size()):
				var combined = _gm.craft.get_combine_result(distinct[i], distinct[j])
				if combined != "" and not products.has(combined):
					products.append(combined)

	for key in products:
		var item: Dictionary = _gm.craft.get_item(key)
		if item.is_empty():
			continue
		var btn = Button.new()
		btn.text = item.get("name", key)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeColors.style_small_button(btn, 12)
		btn.pressed.connect(_on_product_selected.bind(key))
		_list.add_child(btn)

func _on_product_selected(key: String) -> void:
	var contents: Array = _mixing_area._items.duplicate()

	if contents.size() == 1 and contents[0] == key:
		return

	for c in contents:
		var ops: Dictionary = _gm.craft.get_operations(c)
		if ops.values().has(key):
			_mixing_area.consume_and_replace([c], key)
			return

	if contents.size() >= 2:
		for i in range(contents.size()):
			for j in range(i + 1, contents.size()):
				if _gm.craft.get_combine_result(contents[i], contents[j]) == key:
					_mixing_area.consume_and_replace([contents[i], contents[j]], key)
					return
