class_name InventoryGridSlot
extends Button

signal hovered(item_key: String, slot: Control)
signal unhovered
signal open_requested(item_key: String)

const SLOT_SIZE := Vector2(80.0, 80.0)
const ICON_RECT := Rect2(10.0, 8.0, 60.0, 56.0)
const COUNT_RECT := Rect2(8.0, 60.0, 64.0, 18.0)
const READABLE_MARK_RECT := Rect2(6.0, 5.0, 18.0, 16.0)
const SLOT_NORMAL_ART := "res://assets/textures/ui/inventory_slot_normal.png"
const SLOT_HOVER_ART := "res://assets/textures/ui/inventory_slot_hover.png"
const SLOT_PRESSED_ART := "res://assets/textures/ui/inventory_slot_pressed.png"
const SLOT_READABLE_ART := "res://assets/textures/ui/inventory_slot_readable.png"

var item_key: String = ""
var item_count: int = 0
var is_readable: bool = false
var display_name: String = ""
var item_icon: Texture2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_child_nodes()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_slot_style(false)
	_sync_visuals()


func configure(key: String, name_text: String, count: int, icon_texture: Texture2D, readable: bool) -> void:
	item_key = key
	display_name = name_text
	item_count = count
	item_icon = icon_texture
	is_readable = readable
	set_meta("item_key", item_key)
	tooltip_text = display_name
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	text = ""
	focus_mode = Control.FOCUS_NONE
	_ensure_child_nodes()
	_apply_slot_style(false)
	_sync_visuals()


func _ensure_child_nodes() -> void:
	var icon := get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(icon)
	icon.position = ICON_RECT.position
	icon.size = ICON_RECT.size
	var count := get_node_or_null("Count") as Label
	if count == null:
		count = Label.new()
		count.name = "Count"
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ThemeColors.style_brush_label(count, 10, ThemeColors.AMBER_PRIMARY)
		add_child(count)
	count.position = COUNT_RECT.position
	count.size = COUNT_RECT.size
	var readable_mark := get_node_or_null("ReadableMark") as Label
	if readable_mark == null:
		readable_mark = Label.new()
		readable_mark.name = "ReadableMark"
		readable_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		readable_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		readable_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ThemeColors.style_brush_label(readable_mark, 10, ThemeColors.TEXT_SUBTITLE)
		add_child(readable_mark)
	readable_mark.position = READABLE_MARK_RECT.position
	readable_mark.size = READABLE_MARK_RECT.size


func _sync_visuals() -> void:
	var icon := get_node_or_null("Icon") as TextureRect
	if icon != null:
		icon.texture = item_icon
	var count := get_node_or_null("Count") as Label
	if count != null:
		count.text = "x%d" % item_count
	var readable_mark := get_node_or_null("ReadableMark") as Label
	if readable_mark != null:
		readable_mark.text = "*" if is_readable else ""


func _apply_slot_style(hovered_now: bool) -> void:
	var normal_path := SLOT_READABLE_ART if is_readable else SLOT_NORMAL_ART
	var normal := TextureManager.try_load_style_box(normal_path)
	var hover := TextureManager.try_load_style_box(SLOT_HOVER_ART)
	var pressed := TextureManager.try_load_style_box(SLOT_PRESSED_ART)
	if normal != null and hover != null and pressed != null:
		add_theme_stylebox_override("normal", hover if hovered_now else normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", pressed)
	else:
		var fallback_normal := _slot_style(Color(ThemeColors.SURFACE_LOW, 0.92), ThemeColors.PANEL_BORDER)
		var fallback_hover := _slot_style(Color(ThemeColors.SURFACE_HIGH, 0.96), ThemeColors.AMBER_PRIMARY)
		var fallback_pressed := _slot_style(Color(ThemeColors.AMBER_DARK, 0.35), ThemeColors.AMBER_BRIGHT)
		add_theme_stylebox_override("normal", fallback_hover if hovered_now else fallback_normal)
		add_theme_stylebox_override("hover", fallback_hover)
		add_theme_stylebox_override("pressed", fallback_pressed)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _slot_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _get_drag_data(_at_position: Vector2):
	if item_key == "":
		return null
	if get_viewport() != null and get_viewport().gui_is_dragging():
		var preview := Label.new()
		preview.text = "%s x%d" % [display_name, item_count]
		ThemeColors.style_brush_label(preview, 14)
		set_drag_preview(preview)
	return {"item_key": item_key}


func _gui_input(event: InputEvent) -> void:
	if not is_readable:
		return
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.double_click:
		open_requested.emit(item_key)
		accept_event()


func _on_mouse_entered() -> void:
	_apply_slot_style(true)
	hovered.emit(item_key, self)


func _on_mouse_exited() -> void:
	_apply_slot_style(false)
	unhovered.emit()
