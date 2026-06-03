# Runtime UI Art And Title Intro Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the landed dark-brush UI art integration for settings, Tavern menus, shortcut slots, inventory, and dialogue, then add the approved staged title-screen intro.

**Architecture:** Keep gameplay state and interaction paths unchanged. Extend `ThemeColors` as the shared runtime styling boundary, derive slider parts deterministically from the approved existing brush sheet, keep Tavern inventory ownership in `GameManager`, use Dialogue Manager's public `show_dialogue_balloon_scene()` helper with a project-owned balloon scene, and isolate title intro sequencing inside `TitleScreen`.

**Tech Stack:** Godot 4.6 standard, GDScript, Dialogue Manager addon public runtime API, Pillow exporter for deterministic PNG slices, scene-based headless smoke tests.

---

## Scope And File Map

This plan covers one cohesive runtime UI pass. The surfaces are visually related and share the same style helpers, but each task produces a working commit that can be tested independently.

**Create:**

- `assets/textures/ui/menu_brush_slider_track.png` - approved slider texture with the center grabber removed.
- `assets/textures/ui/menu_brush_slider_grabber.png` - movable amber slider grabber derived from the approved slider texture.
- `scripts/ui/dialogue_balloon.gd` - project-owned visual extension of the addon example balloon behavior.
- `scenes/ui/DialogueBalloon.tscn` - project-owned dialogue balloon layout.
- `scripts/test/test_dialogue_balloon.gd` - project balloon runtime smoke test.
- `scenes/test/test_dialogue_balloon.tscn` - test entry scene.

**Modify:**

- `scripts/tools/export_menu_brush_assets.py` - export deterministic slider track and grabber parts.
- `scripts/ui/theme_colors.gd` - shared brush popup, slider, content-panel, shortcut-slot, and dialogue styling helpers.
- `scripts/test/test_brush_theme.gd` - focused style-helper assertions.
- `scenes/ui/SettingsPanel.tscn` - point the decorative volume track at the derived no-grabber texture.
- `scripts/ui/settings_panel.gd` - apply popup and slider helpers.
- `scripts/test/test_settings_panel.gd` - verify expanded settings styling.
- `scripts/ui/bar_workspace.gd` - render shortcut slot icon, name, count, and hover state without changing pickup logic.
- `scripts/ui/inventory_overlay.gd` - apply double-column inventory art and supply item icons.
- `scripts/ui/inventory_drag_row.gd` - render draggable brush rows with icons.
- `scripts/ui/tavern_view.gd` - apply brush art to shortcut background and dynamic recipe rows.
- `scripts/test/test_workspace_scene_recovery.gd` - verify Tavern visuals preserve behavior.
- `scripts/game_manager.gd` - switch dialogue startup from the addon example helper to the project balloon scene.
- `scripts/ui/title_screen.gd` - stage black screen, background, logo, and staggered menu reveal.
- `scripts/test/test_title_screen_assets.gd` - verify intro initial and completed states.

**Do not modify:**

- `addons/dialogue_manager/`
- `docs/07_美术需求文档.md`
- `tmp/`

## Task 1: Derive Slider Parts And Add Shared Brush Helpers

**Files:**

- Modify: `scripts/tools/export_menu_brush_assets.py`
- Create: `assets/textures/ui/menu_brush_slider_track.png`
- Create: `assets/textures/ui/menu_brush_slider_grabber.png`
- Modify: `scripts/ui/theme_colors.gd`
- Modify: `scripts/test/test_brush_theme.gd`

- [ ] **Step 1: Extend the brush-theme test with failing assertions**

Add these assertions near the end of `scripts/test/test_brush_theme.gd`, before freeing the controls:

```gdscript
	var popup := PopupMenu.new()
	ThemeColors.style_brush_popup(popup)
	assert(popup.get_theme_stylebox("panel") != null)
	assert(popup.get_theme_stylebox("hover") != null)
	assert(popup.get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH)

	var option := OptionButton.new()
	ThemeColors.style_brush_option_button(option)
	assert(option.get_popup().get_theme_stylebox("panel") != null)

	var slider := HSlider.new()
	ThemeColors.style_brush_slider(slider)
	assert(slider.get_theme_stylebox("slider") != null)
	assert(slider.get_theme_icon("grabber") != null)
	assert(slider.get_theme_icon("grabber_highlight") != null)

	var content_panel := PanelContainer.new()
	ThemeColors.style_brush_content_panel(content_panel)
	assert(content_panel.get_theme_stylebox("panel") != null)

	var slot := ColorRect.new()
	ThemeColors.style_shortcut_slot(slot)
	assert(slot.get_node_or_null("BrushBackground") != null)
	ThemeColors.set_shortcut_slot_hover(slot, true)
	assert(slot.get_node("BrushBackground").modulate == ThemeColors.AMBER_PRIMARY)
	ThemeColors.set_shortcut_slot_hover(slot, false)
	assert(slot.get_node("BrushBackground").modulate == Color.WHITE)

	assert(ResourceLoader.exists(ThemeColors.MENU_BRUSH_SLIDER_TRACK))
	assert(ResourceLoader.exists(ThemeColors.MENU_BRUSH_SLIDER_GRABBER))
```

Add the matching cleanup:

```gdscript
	popup.free()
	option.free()
	slider.free()
	content_panel.free()
	slot.free()
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_brush_theme.tscn
```

Expected: failure because the new `ThemeColors` helpers and slider-part constants do not exist.

- [ ] **Step 3: Extend the deterministic brush exporter**

In `scripts/tools/export_menu_brush_assets.py`, keep the existing `EXPORTS` dictionary and add:

```python
SLIDER_GRABBER_BOX = (99, 0, 127, 32)
SLIDER_TRACK_FILL_BOX = (128, 0, 156, 32)


def export_slider_parts(slider: Image.Image) -> None:
    grabber = slider.crop(SLIDER_GRABBER_BOX)
    grabber.save(OUTPUT / "menu_brush_slider_grabber.png")

    track = slider.copy()
    track.paste(slider.crop(SLIDER_TRACK_FILL_BOX), SLIDER_GRABBER_BOX)
    track.save(OUTPUT / "menu_brush_slider_track.png")
```

After the existing export loop, add:

```python
slider = Image.open(OUTPUT / "menu_brush_slider.png").convert("RGBA")
export_slider_parts(slider)
print("menu_brush_slider_track.png: (256, 32)")
print("menu_brush_slider_grabber.png: (28, 32)")
```

This reuses the approved existing slider art. It does not generate a new visual direction.

- [ ] **Step 4: Export and inspect the slider parts**

Run:

```powershell
python scripts/tools/export_menu_brush_assets.py
```

Expected output includes:

```text
menu_brush_slider_track.png: (256, 32)
menu_brush_slider_grabber.png: (28, 32)
```

Inspect both PNGs at native resolution. Confirm that the track has no fixed amber grabber and the grabber contains the approved amber block with transparent surroundings.

- [ ] **Step 5: Add shared style constants and helpers**

In `scripts/ui/theme_colors.gd`, add these constants beside the existing brush constants:

```gdscript
const MENU_BRUSH_SLIDER_TRACK := "res://assets/textures/ui/menu_brush_slider_track.png"
const MENU_BRUSH_SLIDER_GRABBER := "res://assets/textures/ui/menu_brush_slider_grabber.png"
```

Add these helpers after the existing brush-button helpers:

```gdscript
static func style_brush_popup(popup: PopupMenu) -> void:
	var font := menu_font()
	if font != null:
		popup.add_theme_font_override("font", font)
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", TEXT_LIGHT)
	popup.add_theme_color_override("font_hover_color", AMBER_PRIMARY)
	popup.add_theme_color_override("font_separator_color", TEXT_DIM)
	popup.add_theme_stylebox_override("panel", _brush_texture_style(MENU_BRUSH_PANEL))
	popup.add_theme_stylebox_override("hover", _brush_hover_style())


static func style_brush_option_button(button: OptionButton) -> void:
	_apply_brush_button_style(button, MENU_BRUSH_TAB, 14)
	style_brush_popup(button.get_popup())


static func style_brush_slider(slider: HSlider) -> void:
	var empty := StyleBoxEmpty.new()
	slider.add_theme_stylebox_override("slider", empty)
	slider.add_theme_stylebox_override("grabber_area", empty)
	slider.add_theme_stylebox_override("grabber_area_highlight", empty)
	var grabber := TextureManager.try_load(MENU_BRUSH_SLIDER_GRABBER)
	if grabber != null:
		slider.add_theme_icon_override("grabber", grabber)
		slider.add_theme_icon_override("grabber_highlight", grabber)
		slider.add_theme_icon_override("grabber_disabled", grabber)


static func style_brush_content_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _brush_texture_style(MENU_BRUSH_TAB))


static func style_shortcut_slot(slot: ColorRect) -> void:
	slot.color = Color(SURFACE_LOW, 0.86)
	var background := slot.get_node_or_null("BrushBackground") as TextureRect
	if background == null:
		background = TextureRect.new()
		background.name = "BrushBackground"
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.texture = TextureManager.try_load(MENU_BRUSH_TAB)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(background)
		slot.move_child(background, 0)


static func set_shortcut_slot_hover(slot: ColorRect, hovered: bool) -> void:
	var background := slot.get_node_or_null("BrushBackground") as TextureRect
	if background != null:
		background.modulate = AMBER_PRIMARY if hovered else Color.WHITE


static func _brush_texture_style(texture_path: String) -> StyleBox:
	var loaded := TextureManager.try_load_style_box(texture_path)
	return loaded if loaded != null else _brush_fallback()


static func _brush_hover_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(AMBER_DARK, 0.28)
	return style
```

Change `style_brush_panel()` and `_apply_brush_button_style()` to call `_brush_texture_style()` so all brush surfaces share the same fallback:

```gdscript
static func style_brush_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", _brush_texture_style(MENU_BRUSH_PANEL))
```

Inside `_apply_brush_button_style()`:

```gdscript
	var style := _brush_texture_style(texture_path)
```

- [ ] **Step 6: Run the focused style test**

Run:

```powershell
godot --headless --editor --quit --path .
godot --headless --path . res://scenes/test/test_brush_theme.tscn
```

Expected: import exits without parse errors and the test prints `[TEST-BRUSH-THEME] ALL PASS`.

- [ ] **Step 7: Commit the shared art infrastructure**

```powershell
git add scripts/tools/export_menu_brush_assets.py assets/textures/ui/menu_brush_slider_track.png assets/textures/ui/menu_brush_slider_grabber.png scripts/ui/theme_colors.gd scripts/test/test_brush_theme.gd
git commit -m "feat(ui): add shared brush control styles"
```

## Task 2: Apply Popup And Slider Art To Settings

**Files:**

- Modify: `scenes/ui/SettingsPanel.tscn`
- Modify: `scripts/ui/settings_panel.gd`
- Modify: `scripts/test/test_settings_panel.gd`

- [ ] **Step 1: Extend the settings-panel test with failing style checks**

After `panel.open()` in `scripts/test/test_settings_panel.gd`, add:

```gdscript
	var mode := panel.get_node("Shade/Panel/Mode") as OptionButton
	var resolution := panel.get_node("Shade/Panel/Resolution") as OptionButton
	var volume := panel.get_node("Shade/Panel/Volume") as HSlider
	var volume_track := panel.get_node("Shade/Panel/VolumeTrack") as TextureRect
	assert(mode.get_popup().get_theme_stylebox("panel") != null)
	assert(resolution.get_popup().get_theme_stylebox("panel") != null)
	assert(mode.get_popup().get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH)
	assert(resolution.get_popup().get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH)
	assert(volume.get_theme_stylebox("slider") != null)
	assert(volume.get_theme_icon("grabber") != null)
	assert(volume_track.texture.resource_path == ThemeColors.MENU_BRUSH_SLIDER_TRACK)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_settings_panel.tscn
```

Expected: failure because the settings panel has not applied the new popup and slider helpers.

- [ ] **Step 3: Point the decorative volume track at the no-grabber texture**

In `scenes/ui/SettingsPanel.tscn`, replace the slider texture resource:

```ini
[ext_resource type="Texture2D" path="res://assets/textures/ui/menu_brush_slider_track.png" id="2"]
```

The `VolumeTrack` node remains the decorative track layer. The overlaid `HSlider` draws only the movable approved amber grabber.

- [ ] **Step 4: Apply the shared settings-control helpers**

In `scripts/ui/settings_panel.gd`, replace:

```gdscript
	ThemeColors.style_brush_tab_button(_mode)
	ThemeColors.style_brush_tab_button(_resolution)
```

with:

```gdscript
	ThemeColors.style_brush_option_button(_mode)
	ThemeColors.style_brush_option_button(_resolution)
	ThemeColors.style_brush_slider(_volume)
```

Remove the local popup-font override block because `style_brush_option_button()` now owns popup styling:

```gdscript
	var popup_font := ThemeColors.menu_font()
	if popup_font != null:
		_mode.get_popup().add_theme_font_override("font", popup_font)
		_resolution.get_popup().add_theme_font_override("font", popup_font)
```

Keep `VolumeTrack` in `SettingsPanel.tscn`: it remains the decorative track layer. The `HSlider` helper removes the default slider-area visuals and supplies the moving approved amber grabber.

- [ ] **Step 5: Run the focused settings tests**

Run:

```powershell
godot --headless --path . res://scenes/test/test_settings_panel.tscn
godot --headless --path . res://scenes/test/test_settings_manager.tscn
```

Expected: settings panel prints `[TEST-SETTINGS-PANEL] ALL PASS`; settings manager exits cleanly.

- [ ] **Step 6: Commit the settings art integration**

```powershell
git add scenes/ui/SettingsPanel.tscn scripts/ui/settings_panel.gd scripts/test/test_settings_panel.gd
git commit -m "feat(settings): style popup lists and volume slider"
```

## Task 3: Apply Tavern Menu, Shortcut Bar, And Double-Column Inventory Art

**Files:**

- Modify: `scripts/ui/bar_workspace.gd`
- Modify: `scripts/ui/inventory_overlay.gd`
- Modify: `scripts/ui/inventory_drag_row.gd`
- Modify: `scripts/ui/tavern_view.gd`
- Modify: `scripts/test/test_workspace_scene_recovery.gd`

- [ ] **Step 1: Add failing Tavern visual assertions**

In `_test_inventory_overlay_lists_and_drop()` in `scripts/test/test_workspace_scene_recovery.gd`, after opening the overlay, add:

```gdscript
	var inventory_panel := overlay.get_node("Panel") as Panel
	_ok(inventory_panel.get_theme_stylebox("panel") != null, "inventory overlay uses brush panel art")
	var material_list := overlay.get_node("Panel/MaterialList") as VBoxContainer
	_ok(material_list.get_child_count() > 0, "inventory material list renders rows")
	var first_inventory_row := material_list.get_child(0) as InventoryDragRow
	_ok(first_inventory_row.get_theme_stylebox("normal") != null, "inventory rows use brush art")
	_ok(first_inventory_row.icon != null, "inventory rows render item icons or color swatches")
```

In the same test, after retrieving `bar`, add:

```gdscript
	var slot0 := tavern.get_node("ShortcutBar/Slot0") as ColorRect
	_ok(slot0.get_node_or_null("BrushBackground") != null, "shortcut slot uses brush background")
	_ok(slot0.get_node_or_null("Icon") != null, "shortcut slot renders an icon node")
	_ok(slot0.get_node_or_null("Count") != null, "shortcut slot renders a count node")
```

In `_test_settings_menu_entry()`, after opening the menu, add:

```gdscript
	var shortcut_bg := tavern.get_node("ShortcutBarBg") as Panel
	_ok(shortcut_bg.get_theme_stylebox("panel") != null, "shortcut bar background uses brush art")
```

- [ ] **Step 2: Run the workspace scene test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected: failures for missing shortcut visual children and unstyled inventory rows.

- [ ] **Step 3: Render draggable inventory rows as brush buttons with icons**

Replace `scripts/ui/inventory_drag_row.gd` with:

```gdscript
class_name InventoryDragRow
extends Button

var item_key: String = ""


func configure(key: String, display_text: String, item_icon: Texture2D) -> void:
	item_key = key
	text = display_text
	icon = item_icon
	expand_icon = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	ThemeColors.style_brush_button(self, 14)


func _get_drag_data(_at_position: Vector2):
	if item_key == "":
		return null
	var preview := Label.new()
	preview.text = text
	ThemeColors.style_brush_label(preview, 14)
	set_drag_preview(preview)
	return {"item_key": item_key}
```

- [ ] **Step 4: Style the double-column inventory panel and provide icon fallbacks**

In `scripts/ui/inventory_overlay.gd`, add:

```gdscript
func _ready() -> void:
	ThemeColors.style_brush_panel(_panel)
	ThemeColors.style_brush_label($Panel/Title, 18, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Panel/MaterialTitle, 16, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Panel/StoryTitle, 16, ThemeColors.AMBER_PRIMARY)
```

Update `_rebuild_list()`:

```gdscript
func _rebuild_list(list: VBoxContainer, keys: Array[String]) -> void:
	for child in list.get_children():
		child.queue_free()
	for key in keys:
		var item_data: Dictionary = _gm.craft.get_item(key)
		var row := InventoryDragRow.new()
		row.custom_minimum_size = Vector2(250.0, 34.0)
		row.configure(
			key,
			"%s  x%d" % [item_data.get("name", key), _gm.inventory_sys.get_count(key)],
			_item_icon_or_swatch(key, item_data)
		)
		list.add_child(row)
```

Add:

```gdscript
func _item_icon_or_swatch(key: String, item_data: Dictionary) -> Texture2D:
	var icon_texture = _gm.try_load_material_icon(key)
	if icon_texture != null:
		return icon_texture
	var rgb: Array = item_data.get("color", [0.55, 0.5, 0.45])
	var gradient := Gradient.new()
	var color := Color(rgb[0], rgb[1], rgb[2])
	gradient.colors = PackedColorArray([color, color])
	var texture := GradientTexture2D.new()
	texture.width = 20
	texture.height = 20
	texture.gradient = gradient
	return texture
```

- [ ] **Step 5: Add shortcut slot visuals without changing pickup behavior**

In `scripts/ui/bar_workspace.gd`, add:

```gdscript
func _process(_delta: float) -> void:
	_update_shortcut_hover(get_global_mouse_position())


func _ensure_shortcut_slot_visuals(slot: ColorRect) -> void:
	ThemeColors.style_shortcut_slot(slot)
	var icon := slot.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = 32.0
		icon.offset_bottom = 32.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)
	var count := slot.get_node_or_null("Count") as Label
	if count == null:
		count = Label.new()
		count.name = "Count"
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.offset_left = 68.0
		count.offset_top = 17.0
		count.offset_right = 88.0
		count.offset_bottom = 34.0
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ThemeColors.style_brush_label(count, 11, ThemeColors.AMBER_PRIMARY)
		slot.add_child(count)
	var label := slot.get_node_or_null("Label") as Label
	if label != null:
		label.offset_left = 34.0
		label.offset_top = 4.0
		label.offset_right = 88.0
		label.offset_bottom = 22.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeColors.style_brush_label(label, 11)


func _update_shortcut_hover(mouse_position: Vector2) -> void:
	for index in _slot_rects.size():
		var slot := _shortcut_bar.get_node_or_null("Slot%d" % index) as ColorRect
		if slot != null:
			ThemeColors.set_shortcut_slot_hover(slot, _slot_rects[index].has_point(mouse_position))
```

Inside `_init_material_slots()`, immediately after the `slot == null` guard, add:

```gdscript
		_ensure_shortcut_slot_visuals(slot)
```

Replace the slot-content section with:

```gdscript
		var label := slot.get_node_or_null("Label") as Label
		var icon := slot.get_node_or_null("Icon") as TextureRect
		var count := slot.get_node_or_null("Count") as Label
		if key == "":
			slot.color = Color(ThemeColors.SURFACE_LOW, 0.86)
			if label != null:
				label.text = ""
			if icon != null:
				icon.texture = null
			if count != null:
				count.text = ""
			continue
		var item_data: Dictionary = _gm.craft.get_item(key)
		var rgb: Array = item_data.get("color", [0.8, 0.8, 0.8])
		slot.color = Color(rgb[0], rgb[1], rgb[2], 0.22)
		if label != null:
			label.text = item_data.get("name", key)
		if icon != null:
			icon.texture = _gm.try_load_material_icon(key)
		if count != null:
			count.text = str(_gm.inventory_sys.get_count(key))
```

- [ ] **Step 6: Style Tavern shortcut background and dynamic recipe rows**

In `_apply_theme()` in `scripts/ui/tavern_view.gd`, replace the `bar_shortcut_bg()` branch with:

```gdscript
	var shortcut_bg = get_node_or_null("ShortcutBarBg")
	if shortcut_bg != null:
		ThemeColors.style_brush_panel(shortcut_bg)
```

Add this helper:

```gdscript
func _new_brush_recipe_row() -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 36.0)
	ThemeColors.style_brush_content_panel(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	return {"panel": panel, "row": row}
```

In `_build_recipe_list()`, replace row creation:

```gdscript
		var recipe_row := _new_brush_recipe_row()
		var row_panel := recipe_row["panel"] as PanelContainer
		var row := recipe_row["row"] as HBoxContainer
```

Replace:

```gdscript
		name_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45) if locked else ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 14)
```

with:

```gdscript
		ThemeColors.style_brush_label(name_label, 14, Color(0.55, 0.5, 0.45) if locked else ThemeColors.TEXT_LIGHT)
```

Replace:

```gdscript
		recipe_list.add_child(row)
```

with:

```gdscript
		recipe_list.add_child(row_panel)
```

- [ ] **Step 7: Run the Tavern regression test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected: `[TEST-WORKSPACE-SCENE] ALL PASS`.

- [ ] **Step 8: Commit Tavern UI art**

```powershell
git add scripts/ui/bar_workspace.gd scripts/ui/inventory_overlay.gd scripts/ui/inventory_drag_row.gd scripts/ui/tavern_view.gd scripts/test/test_workspace_scene_recovery.gd
git commit -m "feat(tavern): style shortcut bar and inventory overlay"
```

## Task 4: Add A Project-Owned Brush Dialogue Balloon

**Files:**

- Create: `scripts/ui/dialogue_balloon.gd`
- Create: `scenes/ui/DialogueBalloon.tscn`
- Create: `scripts/test/test_dialogue_balloon.gd`
- Create: `scenes/test/test_dialogue_balloon.tscn`
- Modify: `scripts/game_manager.gd`

- [ ] **Step 1: Write the failing dialogue balloon smoke test**

Create `scripts/test/test_dialogue_balloon.gd`:

```gdscript
extends Node

const BALLOON_SCENE := preload("res://scenes/ui/DialogueBalloon.tscn")


func _ready() -> void:
	var resource = DialogueManager.create_resource_from_text(
		"~ start\nRyan: choose\n- Accept\n    => END\n- Decline\n    => END"
	)
	var balloon = DialogueManager.show_dialogue_balloon_scene(BALLOON_SCENE, resource, "start")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(balloon is TavernDialogueBalloon)
	assert(balloon.balloon.visible)
	balloon.dialogue_label.skip_typing()
	await get_tree().process_frame
	var panel := balloon.get_node("Balloon/MarginContainer/PanelContainer") as PanelContainer
	assert(panel.get_theme_stylebox("panel") != null)
	assert(balloon.responses_menu.visible)
	assert(balloon.responses_menu.get_menu_items().size() == 2)
	var response := balloon.responses_menu.get_menu_items()[0] as Button
	assert(response.get_theme_stylebox("normal") != null)
	var source := FileAccess.get_file_as_string("res://scripts/game_manager.gd")
	assert(source.contains("show_dialogue_balloon_scene(DIALOGUE_BALLOON_SCENE"))
	assert(not source.contains("show_example_dialogue_balloon"))
	balloon.queue_free()
	print("[TEST-DIALOGUE-BALLOON] ALL PASS")
	get_tree().quit()
```

Create `scenes/test/test_dialogue_balloon.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_dialogue_balloon.gd" id="1"]

[node name="TestDialogueBalloon" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_dialogue_balloon.tscn
```

Expected: load failure because `scenes/ui/DialogueBalloon.tscn` does not exist.

- [ ] **Step 3: Create the project-owned visual script**

Create `scripts/ui/dialogue_balloon.gd`:

```gdscript
class_name TavernDialogueBalloon
extends "res://addons/dialogue_manager/example_balloon/example_balloon.gd"

var _intro_tween: Tween = null


func _ready() -> void:
	super._ready()
	ThemeColors.style_brush_panel($Balloon/MarginContainer/PanelContainer)
	ThemeColors.style_brush_label($Balloon/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/CharacterLabel, 16, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Balloon/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/DialogueLabel, 18)
	ThemeColors.style_brush_button($Balloon/ResponsesMenu/ResponseExample, 16)
	balloon.visibility_changed.connect(_on_balloon_visibility_changed)


func _on_balloon_visibility_changed() -> void:
	if not balloon.visible:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	balloon.modulate.a = 0.0
	_intro_tween = create_tween()
	_intro_tween.tween_property(balloon, "modulate:a", 1.0, 0.16)


func _exit_tree() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
```

`DialogueLabel` and `RichTextLabel` are both `Control` subclasses, so `ThemeColors.style_brush_label()` must accept `Control` rather than `Label`. In `scripts/ui/theme_colors.gd`, widen the signature:

```gdscript
static func style_brush_label(label: Control, font_size: int = 16, color: Color = TEXT_LIGHT) -> void:
```

- [ ] **Step 4: Copy the addon example scene into the project and point it at the visual script**

Run:

```powershell
Copy-Item -LiteralPath 'addons\dialogue_manager\example_balloon\example_balloon.tscn' -Destination 'scenes\ui\DialogueBalloon.tscn'
```

In `scenes/ui/DialogueBalloon.tscn`, replace the first script resource:

```ini
[ext_resource type="Script" path="res://scripts/ui/dialogue_balloon.gd" id="1_36de5"]
```

Replace the copied scene header to remove the addon's UID:

```ini
[gd_scene format=3]
```

Rename the root:

```ini
[node name="DialogueBalloon" type="CanvasLayer" unique_id=1434168376]
```

Keep the plugin-owned `dialogue_label.tscn` and `dialogue_responses_menu.gd` resources referenced by the copied scene. Those are runtime components, not edited files.

- [ ] **Step 5: Switch GameManager to the public custom-balloon helper**

In `scripts/game_manager.gd`, add beside the other constants:

```gdscript
const DIALOGUE_BALLOON_SCENE := preload("res://scenes/ui/DialogueBalloon.tscn")
```

Inside `_start_dialogue_deferred()`, replace:

```gdscript
	var balloon = DialogueManager.show_example_dialogue_balloon(dialogue_resource, "start", extra_states)
```

with:

```gdscript
	var balloon = DialogueManager.show_dialogue_balloon_scene(
		DIALOGUE_BALLOON_SCENE,
		dialogue_resource,
		"start",
		extra_states
	)
```

Keep:

```gdscript
	balloon.will_block_other_input = false
```

- [ ] **Step 6: Import resources and run the dialogue smoke test**

Run:

```powershell
godot --headless --editor --quit --path .
godot --headless --path . res://scenes/test/test_dialogue_balloon.tscn
```

Expected: import exits without parse errors and the test prints `[TEST-DIALOGUE-BALLOON] ALL PASS`.

- [ ] **Step 7: Commit the project dialogue balloon**

```powershell
git add scripts/ui/dialogue_balloon.gd scenes/ui/DialogueBalloon.tscn scripts/test/test_dialogue_balloon.gd scenes/test/test_dialogue_balloon.tscn scripts/game_manager.gd scripts/ui/theme_colors.gd
git commit -m "feat(dialogue): add brush-style project balloon"
```

## Task 5: Add The Staged Title-Screen Intro

**Files:**

- Modify: `scripts/ui/title_screen.gd`
- Modify: `scripts/test/test_title_screen_assets.gd`

- [ ] **Step 1: Extend the title test with failing intro assertions**

In `scripts/test/test_title_screen_assets.gd`, after retrieving `start_button`, add:

```gdscript
	var quit_button := title_screen.get_node("UI/QuitButton") as Button
	var dark_overlay := title_screen.get_node("DarkOverlay") as ColorRect
	_check(not title_screen._intro_complete, "Title intro must start incomplete", failures)
	_check(start_button.disabled, "Start button must stay disabled during intro", failures)
	_check(quit_button.disabled, "Quit button must stay disabled during intro", failures)
	_check(dark_overlay.visible, "Black overlay must cover the initial title frame", failures)
	title_screen.finish_intro_immediately()
	_check(title_screen._intro_complete, "Title intro must expose a deterministic completed state", failures)
	_check(not start_button.disabled, "Start button must unlock after intro", failures)
	_check(not quit_button.disabled, "Quit button must unlock after intro", failures)
	_check(not dark_overlay.visible, "Black overlay must hide after intro", failures)
```

- [ ] **Step 2: Run the title test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
```

Expected: parse or assertion failure because title intro state and `finish_intro_immediately()` do not exist.

- [ ] **Step 3: Add title intro state and node references**

In `scripts/ui/title_screen.gd`, add:

```gdscript
const INTRO_BUTTON_PATHS := [
	"UI/StartButton",
	"UI/ContinueButton",
	"UI/SettingsButton",
	"UI/QuitButton",
]
const LOGO_REST_Y := 300.0

var _intro_tween: Tween = null
var _button_intro_tween: Tween = null
var _intro_complete := false

@onready var _background: Sprite2D = $Background
@onready var _dark_overlay: ColorRect = $DarkOverlay
@onready var _menu_bands: TextureRect = $UI/MenuBands
@onready var _version_label: Label = $UI/VersionLabel
```

At the end of `_ready()`, call:

```gdscript
	_play_intro()
```

- [ ] **Step 4: Gate ambient motion until intro completion**

Replace `_process()` with:

```gdscript
func _process(delta: float) -> void:
	_motion_time += delta
	if not _intro_complete:
		return
	_glow_overlay.modulate.a = 0.14 + sin(_motion_time * 2.1) * 0.025 + sin(_motion_time * 3.7) * 0.01
	_logo.position.y = LOGO_REST_Y + sin(_motion_time * 0.9) * 1.0
```

- [ ] **Step 5: Implement the staged intro and deterministic finish hook**

Add:

```gdscript
func _play_intro() -> void:
	_intro_complete = false
	_dark_overlay.visible = true
	_dark_overlay.color = Color.BLACK
	_dark_overlay.modulate.a = 1.0
	_background.modulate.a = 0.0
	_glow_overlay.modulate.a = 0.0
	_logo.modulate.a = 0.0
	_logo.position.y = LOGO_REST_Y + 18.0
	_menu_bands.modulate.a = 0.0
	_version_label.modulate.a = 0.0
	for button in _intro_buttons():
		button.set_meta("intro_disabled_before", button.disabled)
		button.disabled = true
		button.modulate.a = 0.0

	_intro_tween = create_tween()
	_intro_tween.tween_interval(0.4)
	_intro_tween.tween_property(_dark_overlay, "modulate:a", 0.0, 0.7)
	_intro_tween.parallel().tween_property(_background, "modulate:a", 1.0, 0.7)
	_intro_tween.parallel().tween_property(_glow_overlay, "modulate:a", 0.14, 0.7)
	_intro_tween.tween_callback(_dark_overlay.hide)
	_intro_tween.tween_property(_logo, "modulate:a", 1.0, 0.5)
	_intro_tween.parallel().tween_property(_logo, "position:y", LOGO_REST_Y, 0.5)
	_intro_tween.tween_property(_menu_bands, "modulate:a", 1.0, 0.2)
	_intro_tween.tween_callback(_play_button_intro)


func _play_button_intro() -> void:
	_button_intro_tween = create_tween().set_parallel(true)
	var buttons := _intro_buttons()
	for index in buttons.size():
		_button_intro_tween.tween_property(buttons[index], "modulate:a", 1.0, 0.18).set_delay(index * 0.1)
	_button_intro_tween.tween_property(_version_label, "modulate:a", 1.0, 0.18).set_delay(buttons.size() * 0.1)
	_button_intro_tween.chain().tween_callback(_apply_intro_final_state)


func finish_intro_immediately() -> void:
	_kill_intro_tweens()
	_apply_intro_final_state()


func _apply_intro_final_state() -> void:
	_dark_overlay.hide()
	_background.modulate.a = 1.0
	_glow_overlay.modulate.a = 0.14
	_logo.modulate.a = 1.0
	_logo.position.y = LOGO_REST_Y
	_menu_bands.modulate.a = 1.0
	_version_label.modulate.a = 1.0
	for button in _intro_buttons():
		button.modulate.a = 1.0
		button.disabled = bool(button.get_meta("intro_disabled_before", false))
	_intro_complete = true


func _intro_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for node_path in INTRO_BUTTON_PATHS:
		buttons.append(get_node(node_path) as Button)
	return buttons


func _kill_intro_tweens() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if _button_intro_tween != null and _button_intro_tween.is_valid():
		_button_intro_tween.kill()
	_intro_tween = null
	_button_intro_tween = null


func _exit_tree() -> void:
	_kill_intro_tweens()
```

The original disabled state is restored after the intro, so `ContinueButton` remains disabled when no save exists.

- [ ] **Step 6: Run the title-screen regression test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
```

Expected: `TEST_TITLE_SCREEN_ASSETS_PASS`.

- [ ] **Step 7: Commit the title intro**

```powershell
git add scripts/ui/title_screen.gd scripts/test/test_title_screen_assets.gd
git commit -m "feat(title): add staged intro reveal"
```

## Task 6: Unified Verification

**Files:**

- Verify only

- [ ] **Step 1: Import resources headlessly**

Run:

```powershell
godot --headless --editor --quit --path .
```

Expected: no GDScript parse errors. Ignore MCP Mono-only `.NET: Assemblies not found` noise unless the standard editor reproduces it.

- [ ] **Step 2: Run focused UI tests**

Run:

```powershell
godot --headless --path . res://scenes/test/test_brush_theme.tscn
godot --headless --path . res://scenes/test/test_settings_manager.tscn
godot --headless --path . res://scenes/test/test_settings_panel.tscn
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
godot --headless --path . res://scenes/test/test_dialogue_balloon.tscn
godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
```

Expected: every scene exits cleanly with its pass marker.

- [ ] **Step 3: Run the broader gameplay regression scenes**

Run:

```powershell
godot --headless --path . res://scenes/test/test_inventory_system.tscn
godot --headless --path . res://scenes/test/test_document_overlay.tscn
godot --headless --path . res://scenes/test/test_ryan_actions.tscn
godot --headless --path . res://scenes/test/test_ryan_delivery.tscn
godot --headless --path . res://scenes/test/test_save_roundtrip.tscn
```

Expected: every scene exits cleanly.

- [ ] **Step 4: Run the required standard-editor path**

In Godot 4.6.x standard editor, run:

```text
TitleScreen -> DayMap -> Tavern -> LedgerScreen -> DayMap
```

Verify:

- title intro shows black screen, background, logo, then four right-side buttons in sequence;
- buttons do not respond before intro completion;
- display-mode and resolution popup lists use dark brush styling;
- volume slider uses the brush track and movable amber grabber;
- Tavern recipe, backpack, settings, and tutorial entries remain visually consistent;
- shortcut slots show icon, name, and count while preserving click-to-pickup;
- double-column inventory keeps material and story-item drag-out behavior;
- one Ryan runtime dialogue line uses the project brush balloon, and `test_dialogue_balloon.tscn` renders its generated response menu with the same art;
- the full path reports 0 errors/warnings.

- [ ] **Step 5: Check repository hygiene**

Run:

```powershell
git status --short
rg -n "<<<<<<<|>>>>>>>" --glob "!tmp/**" --glob "!.godot/**" .
```

Expected: only intentional files remain changed, `tmp/` is not staged, and no conflict markers exist.
