class_name MapPointMarker
extends Area2D

signal clicked(location_id: String)

const RADIUS := 20.0
const HOME_RADIUS := 28.0
const CLICK_PADDING := 10.0
const ICON_DISPLAY_SIZE := 54.0
const HOME_ICON_DISPLAY_SIZE := 64.0
const BASE_DISPLAY_SIZE := 72.0
const HOME_BASE_DISPLAY_SIZE := 86.0
const SELECTED_RING_DISPLAY_SIZE := 92.0
const REVEAL_DISPLAY_SIZE := 104.0

const STATE_TEXTURES := {
	"base": "res://assets/textures/daymap/markers/marker_base.png",
	"hover": "res://assets/textures/daymap/markers/marker_hover_ring.png",
	"selected": "res://assets/textures/daymap/markers/marker_selected_ring.png",
	"reveal": "res://assets/textures/daymap/markers/marker_reveal_burst.png",
}

const ICON_TEXTURES := {
	"home": "res://assets/textures/daymap/markers/home.png",
	"mushroom_forest": "res://assets/textures/daymap/markers/mushroom_forest.png",
	"dark_river": "res://assets/textures/daymap/markers/dark_river.png",
	"grape_trellis": "res://assets/textures/daymap/markers/grape_trellis.png",
	"mill_farm": "res://assets/textures/daymap/markers/mill_farm.png",
	"mercenary_board": "res://assets/textures/daymap/markers/mercenary_board.png",
	"abandoned_mine": "res://assets/textures/daymap/markers/abandoned_mine.png",
	"guild_counter": "res://assets/textures/daymap/markers/guild_counter.png",
}

var location_id: String = ""
var _icon_key: String = ""
var _hovered := false
var _selected := false
var _is_home := false
var _label: Label
var _shape: CollisionShape2D
var _base: Sprite2D
var _hover_ring: Sprite2D
var _selected_ring: Sprite2D
var _reveal_burst: Sprite2D
var _icon: Sprite2D


func setup(loc: Dictionary) -> void:
	location_id = String(loc.get("id", ""))
	_icon_key = String(loc.get("marker", location_id))
	var pos_arr: Array = loc.get("pos", [640, 360])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	if _label != null:
		_label.text = String(loc.get("name", ""))
	_apply_icon_texture()


func _ready() -> void:
	_base = _new_sprite("base", 0)
	_hover_ring = _new_sprite("hover", 1)
	_selected_ring = _new_sprite("selected", 1)
	_reveal_burst = _new_sprite("reveal", 3)
	_icon = Sprite2D.new()
	_icon.centered = true
	_icon.z_index = 2
	add_child(_icon)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius() + CLICK_PADDING
	shape.shape = circle
	add_child(shape)
	_shape = shape

	_label = Label.new()
	_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_label.add_theme_font_size_override("font_size", 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-60, _radius() + 8)
	_label.custom_minimum_size = Vector2(120, 0)
	_label.size = Vector2(120, 24)
	add_child(_label)

	_hover_ring.visible = false
	_selected_ring.visible = false
	_reveal_burst.visible = false
	mouse_entered.connect(func(): _hovered = true; _sync_state())
	mouse_exited.connect(func(): _hovered = false; _sync_state())
	input_event.connect(_on_input_event)
	_apply_icon_texture()
	_sync_state()


func set_selected(value: bool) -> void:
	_selected = value
	_sync_state()


func set_home(value: bool) -> void:
	_is_home = value
	if _shape != null and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = _radius() + CLICK_PADDING
	if _label != null:
		_label.position = Vector2(-60, _radius() + 8)
	if _icon_key == "" or _icon_key == location_id:
		_icon_key = "home"
	_apply_icon_texture()
	_sync_state()


func has_icon_texture() -> bool:
	return _icon != null and _icon.texture != null


func play_reveal() -> void:
	if _reveal_burst == null:
		return
	_reveal_burst.visible = true
	_reveal_burst.modulate.a = 0.0
	_reveal_burst.scale = _scale_for(_reveal_burst, REVEAL_DISPLAY_SIZE * 0.7)
	var tw := create_tween()
	tw.tween_property(_reveal_burst, "modulate:a", 0.85, 0.08)
	tw.parallel().tween_property(_reveal_burst, "scale", _scale_for(_reveal_burst, REVEAL_DISPLAY_SIZE), 0.16)
	tw.tween_property(_reveal_burst, "modulate:a", 0.0, 0.24)
	tw.tween_callback(func(): _reveal_burst.visible = false)


func _radius() -> float:
	return HOME_RADIUS if _is_home else RADIUS


func _new_sprite(state: String, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture = load(String(STATE_TEXTURES[state])) as Texture2D
	sprite.z_index = z
	add_child(sprite)
	return sprite


func _apply_icon_texture() -> void:
	if _icon == null:
		return
	var key := "home" if _is_home else _icon_key
	var texture_path := String(ICON_TEXTURES.get(key, ICON_TEXTURES.get("mercenary_board", "")))
	_icon.texture = load(texture_path) as Texture2D
	_icon.scale = _scale_for(_icon, HOME_ICON_DISPLAY_SIZE if _is_home else ICON_DISPLAY_SIZE)


func _sync_state() -> void:
	if _base != null:
		_base.scale = _scale_for(_base, HOME_BASE_DISPLAY_SIZE if _is_home else BASE_DISPLAY_SIZE)
		_base.modulate.a = 0.92 if _is_home else 0.82
	if _hover_ring != null:
		_hover_ring.visible = _hovered and not _selected
		_hover_ring.scale = _scale_for(_hover_ring, SELECTED_RING_DISPLAY_SIZE * 0.88)
	if _selected_ring != null:
		_selected_ring.visible = _selected
		_selected_ring.scale = _scale_for(_selected_ring, SELECTED_RING_DISPLAY_SIZE)


func _scale_for(sprite: Sprite2D, display_size: float) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ONE
	var longest := maxf(float(sprite.texture.get_width()), float(sprite.texture.get_height()))
	return Vector2.ONE * (display_size / longest)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(location_id)
