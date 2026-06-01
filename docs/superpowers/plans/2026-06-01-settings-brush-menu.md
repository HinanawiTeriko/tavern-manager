# Settings And Brush Menu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add persistent display and master-volume settings through one reusable panel, replace the title restart action with settings, expose the same panel from the tavern pause menu, and promote the approved dark brush menu art without removing the title screen's existing menu bands or short underline marker.

**Architecture:** Add a `SettingsManager` subsystem owned by `GameManager`. It stores settings in `user://settings.cfg`, applies them immediately, and stays separate from game saves. Add one `SettingsPanel` scene that is configured with the manager and reused by the title and tavern screens. Export deterministic runtime textures from the approved pure-brush source sheet, then add narrowly scoped `ThemeColors` helpers for brush panels, buttons, tabs, and dividers.

**Tech Stack:** Godot 4.6, GDScript, `ConfigFile`, `DisplayServer`, `AudioServer`, Python 3, Pillow.

---

### Task 1: Add Persistent Settings Manager

**Files:**
- Create: `scripts/systems/settings_manager.gd`
- Create: `scripts/test/test_settings_manager.gd`
- Create: `scenes/test/test_settings_manager.tscn`
- Modify: `scripts/game_manager.gd`

**Step 1: Write the failing settings tests**

Create `scripts/test/test_settings_manager.gd`:

```gdscript
extends Node

const TEST_PATH := "user://test_settings.cfg"

func _ready() -> void:
	_test_missing_file_uses_defaults()
	_test_save_and_reload()
	_test_invalid_values_are_normalized()
	print("PASS: settings_manager")
	get_tree().quit()

func _new_manager() -> SettingsManager:
	var manager := SettingsManager.new(TEST_PATH)
	manager.clear_settings()
	return manager

func _test_missing_file_uses_defaults() -> void:
	var manager := _new_manager()
	manager.load_settings()
	assert(not manager.fullscreen)
	assert(manager.resolution == Vector2i(1280, 720))
	assert(manager.master_volume_percent == 100.0)

func _test_save_and_reload() -> void:
	var manager := _new_manager()
	manager.fullscreen = true
	manager.resolution = Vector2i(1600, 900)
	manager.master_volume_percent = 35.0
	assert(manager.save_settings() == OK)
	var reloaded := SettingsManager.new(TEST_PATH)
	reloaded.load_settings()
	assert(reloaded.fullscreen)
	assert(reloaded.resolution == Vector2i(1600, 900))
	assert(reloaded.master_volume_percent == 35.0)
	reloaded.apply_all()
	reloaded.master_volume_percent = 100.0
	reloaded.apply_all()
	reloaded.clear_settings()

func _test_invalid_values_are_normalized() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "width", 123)
	config.set_value("display", "height", 456)
	config.set_value("audio", "master_volume_percent", 180.0)
	assert(config.save(TEST_PATH) == OK)
	var manager := SettingsManager.new(TEST_PATH)
	manager.load_settings()
	assert(manager.resolution == Vector2i(1280, 720))
	assert(manager.master_volume_percent == 100.0)
	manager.clear_settings()
```

Create `scenes/test/test_settings_manager.tscn` with one `Node` using the script.

**Step 2: Run the test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_settings_manager.tscn
```

Expected: failure because `SettingsManager` does not exist.

**Step 3: Implement the manager**

Create `scripts/systems/settings_manager.gd`:

```gdscript
class_name SettingsManager
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DEFAULT_MASTER_VOLUME_PERCENT := 100.0

var _path: String
var fullscreen := false
var resolution := DEFAULT_RESOLUTION
var master_volume_percent := DEFAULT_MASTER_VOLUME_PERCENT

func _init(path: String = SETTINGS_PATH) -> void:
	_path = path

func load_and_apply() -> void:
	load_settings()
	apply_all()

func load_settings() -> void:
	reset_defaults()
	var config := ConfigFile.new()
	if config.load(_path) != OK:
		return
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	resolution = _normalize_resolution(Vector2i(
		int(config.get_value("display", "width", DEFAULT_RESOLUTION.x)),
		int(config.get_value("display", "height", DEFAULT_RESOLUTION.y)),
	))
	master_volume_percent = clampf(
		float(config.get_value("audio", "master_volume_percent", DEFAULT_MASTER_VOLUME_PERCENT)),
		0.0,
		100.0,
	)

func save_settings() -> int:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("audio", "master_volume_percent", master_volume_percent)
	return config.save(_path)

func clear_settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display()
	save_settings()

func set_resolution(value: Vector2i) -> void:
	resolution = _normalize_resolution(value)
	_apply_display()
	save_settings()

func set_master_volume_percent(value: float) -> void:
	master_volume_percent = clampf(value, 0.0, 100.0)
	_apply_audio()
	save_settings()

func apply_all() -> void:
	_apply_display()
	_apply_audio()

func reset_defaults() -> void:
	fullscreen = false
	resolution = DEFAULT_RESOLUTION
	master_volume_percent = DEFAULT_MASTER_VOLUME_PERCENT

func _normalize_resolution(value: Vector2i) -> Vector2i:
	return value if RESOLUTIONS.has(value) else DEFAULT_RESOLUTION

func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not fullscreen:
		DisplayServer.window_set_size(resolution)

func _apply_audio() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	var muted := master_volume_percent <= 0.0
	AudioServer.set_bus_mute(bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume_percent / 100.0))
```

Initialize it in `scripts/game_manager.gd` before entering the title screen:

```gdscript
var settings: SettingsManager

func _ready() -> void:
	# Keep the existing subsystem initialization order.
	settings = SettingsManager.new()
	settings.load_and_apply()
```

**Step 4: Run the focused test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_settings_manager.tscn
```

Expected: `PASS: settings_manager`.

**Step 5: Commit**

```powershell
git add scripts/systems/settings_manager.gd scripts/test/test_settings_manager.gd scenes/test/test_settings_manager.tscn scripts/game_manager.gd
git commit -m "feat(settings): persist display and volume preferences"
```

### Task 2: Export Approved Pure-Brush Menu Assets

**Files:**
- Create: `assets/source/ui/menu_brush_components_approved.png`
- Create: `scripts/tools/export_menu_brush_assets.py`
- Create: `assets/textures/ui/menu_brush_panel.png`
- Create: `assets/textures/ui/menu_brush_band.png`
- Create: `assets/textures/ui/menu_brush_tab.png`
- Create: `assets/textures/ui/menu_brush_slider.png`
- Create: `assets/textures/ui/menu_brush_divider.png`

**Step 1: Promote the approved source sheet**

Copy `tmp/imagegen/menu-approval/menu_brush_alpha.png` to:

```text
assets/source/ui/menu_brush_components_approved.png
```

The promoted sheet must remain transparent and contain only the approved dark teal and near-black brush components. Do not promote the rejected full amber outline variants as runtime assets.

**Step 2: Add a deterministic exporter**

Create `scripts/tools/export_menu_brush_assets.py`:

```python
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/ui/menu_brush_components_approved.png"
OUTPUT = ROOT / "assets/textures/ui"
EXPORTS = {
    "menu_brush_panel.png": ((47, 49, 898, 447), (512, 240)),
    "menu_brush_band.png": ((942, 71, 1471, 163), (320, 56)),
    "menu_brush_tab.png": ((47, 678, 332, 768), (176, 56)),
    "menu_brush_slider.png": ((1072, 694, 1456, 741), (256, 32)),
    "menu_brush_divider.png": ((52, 835, 995, 855), (384, 12)),
}

OUTPUT.mkdir(parents=True, exist_ok=True)
source = Image.open(SOURCE).convert("RGBA")
for filename, (crop_box, output_size) in EXPORTS.items():
    source.crop(crop_box).resize(output_size, Image.Resampling.NEAREST).save(OUTPUT / filename)
```

**Step 3: Export and inspect the outputs**

Run:

```powershell
python scripts/tools/export_menu_brush_assets.py
```

Inspect the five runtime PNGs at native resolution and confirm:

- panel, band, and tab remain irregular brush fields rather than wood boards;
- slider and divider contain no RPG frame ornament;
- there are no full amber borders;
- alpha backgrounds remain transparent.

**Step 4: Commit**

```powershell
git add assets/source/ui/menu_brush_components_approved.png scripts/tools/export_menu_brush_assets.py assets/textures/ui/menu_brush_panel.png assets/textures/ui/menu_brush_band.png assets/textures/ui/menu_brush_tab.png assets/textures/ui/menu_brush_slider.png assets/textures/ui/menu_brush_divider.png
git commit -m "feat(ui): add approved brush menu assets"
```

### Task 3: Add Reusable Brush Styling Helpers

**Files:**
- Modify: `scripts/ui/theme_colors.gd`
- Create: `scripts/test/test_brush_theme.gd`
- Create: `scenes/test/test_brush_theme.tscn`

**Step 1: Write the failing style smoke test**

Create `scripts/test/test_brush_theme.gd`:

```gdscript
extends Node

func _ready() -> void:
	var panel := Panel.new()
	ThemeColors.style_brush_panel(panel)
	assert(panel.get_theme_stylebox("panel") != null)
	var button := Button.new()
	button.text = "设置"
	ThemeColors.style_brush_button(button)
	assert(button.get_theme_stylebox("normal") != null)
	assert(button.get_node_or_null("BrushHoverMarker") != null)
	var tab_button := Button.new()
	ThemeColors.style_brush_tab_button(tab_button)
	assert(tab_button.get_theme_stylebox("normal") != null)
	print("PASS: brush_theme")
	get_tree().quit()
```

Create `scenes/test/test_brush_theme.tscn` with one `Node` using the script.

**Step 2: Run the test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_brush_theme.tscn
```

Expected: failure because brush helpers do not exist.

**Step 3: Add the styling helpers**

Extend `scripts/ui/theme_colors.gd` with:

```gdscript
const MENU_BRUSH_PANEL := "res://assets/textures/ui/menu_brush_panel.png"
const MENU_BRUSH_BAND := "res://assets/textures/ui/menu_brush_band.png"
const MENU_BRUSH_TAB := "res://assets/textures/ui/menu_brush_tab.png"
const MENU_BRUSH_MARKER := "res://assets/textures/title/title_pixel_menu_marker.png"

static func style_brush_panel(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", TextureManager.try_load_style_box(MENU_BRUSH_PANEL))

static func style_brush_button(button: Button, font_size: int = 16) -> void:
	_apply_brush_button_style(button, MENU_BRUSH_BAND, font_size)

static func style_brush_tab_button(button: Button, font_size: int = 14) -> void:
	_apply_brush_button_style(button, MENU_BRUSH_TAB, font_size)

static func _apply_brush_button_style(button: Button, texture_path: String, font_size: int) -> void:
	var style := TextureManager.try_load_style_box(texture_path)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", AMBER_BRIGHT)
	if button.get_node_or_null("BrushHoverMarker") == null:
		var marker := TextureRect.new()
		marker.name = "BrushHoverMarker"
		marker.texture = TextureManager.try_load(MENU_BRUSH_MARKER)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		marker.offset_left = 8.0
		marker.offset_top = -7.0
		marker.offset_right = -8.0
		marker.offset_bottom = -1.0
		marker.visible = false
		button.add_child(marker)
		button.mouse_entered.connect(_sync_brush_marker.bind(button))
		button.mouse_exited.connect(_sync_brush_marker.bind(button))

static func set_brush_selected(button: Button, selected: bool) -> void:
	button.set_meta("brush_selected", selected)
	_sync_brush_marker(button)

static func _sync_brush_marker(button: Button) -> void:
	var marker := button.get_node_or_null("BrushHoverMarker") as TextureRect
	if marker != null:
		marker.visible = bool(button.get_meta("brush_selected", false)) or button.is_hovered()
```

If the existing color constants use different names, use the existing light text and amber constants rather than adding duplicates. Keep the title-screen-only `_style_title_menu_button()` helper intact: title menu bands and its short underline marker are deliberate, already approved behavior.

**Step 4: Run the focused test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_brush_theme.tscn
```

Expected: `PASS: brush_theme`.

**Step 5: Commit**

```powershell
git add scripts/ui/theme_colors.gd scripts/test/test_brush_theme.gd scenes/test/test_brush_theme.tscn
git commit -m "feat(ui): add brush menu theme helpers"
```

### Task 4: Add Reusable Settings Panel

**Files:**
- Create: `scripts/ui/settings_panel.gd`
- Create: `scenes/ui/SettingsPanel.tscn`
- Create: `scripts/test/test_settings_panel.gd`
- Create: `scenes/test/test_settings_panel.tscn`

**Step 1: Write the failing panel test**

Create `scripts/test/test_settings_panel.gd`:

```gdscript
extends Node

const TEST_PATH := "user://test_settings_panel.cfg"

func _ready() -> void:
	var panel: SettingsPanel = preload("res://scenes/ui/SettingsPanel.tscn").instantiate()
	add_child(panel)
	var manager := SettingsManager.new(TEST_PATH)
	manager.clear_settings()
	manager.load_settings()
	panel.configure(manager)
	panel.open()
	assert(panel.visible)
	panel._on_mode_selected(1)
	assert(manager.fullscreen)
	panel._on_resolution_selected(1)
	assert(manager.resolution == Vector2i(1600, 900))
	panel._on_volume_changed(42.0)
	assert(manager.master_volume_percent == 42.0)
	panel.close()
	assert(not panel.visible)
	manager.clear_settings()
	print("PASS: settings_panel")
	get_tree().quit()
```

Create `scenes/test/test_settings_panel.tscn` with one `Node` using the script.

**Step 2: Run the test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_settings_panel.tscn
```

Expected: failure because `SettingsPanel` does not exist.

**Step 3: Create the panel scene and script**

Create `scripts/ui/settings_panel.gd`:

```gdscript
class_name SettingsPanel
extends Control

signal closed

var _settings: SettingsManager
var _syncing := false

@onready var _panel: Panel = $Shade/Panel
@onready var _mode: OptionButton = $Shade/Panel/Mode
@onready var _resolution: OptionButton = $Shade/Panel/Resolution
@onready var _volume: HSlider = $Shade/Panel/Volume
@onready var _volume_value: Label = $Shade/Panel/VolumeValue

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ThemeColors.style_brush_panel(_panel)
	ThemeColors.style_brush_button($Shade/Panel/CloseButton)
	ThemeColors.style_brush_tab_button(_mode)
	ThemeColors.style_brush_tab_button(_resolution)
	_mode.add_item("窗口化")
	_mode.add_item("全屏")
	for size in SettingsManager.RESOLUTIONS:
		_resolution.add_item("%d x %d" % [size.x, size.y])
	_mode.item_selected.connect(_on_mode_selected)
	_resolution.item_selected.connect(_on_resolution_selected)
	_volume.value_changed.connect(_on_volume_changed)
	$Shade/Panel/CloseButton.pressed.connect(close)
	hide()

func configure(settings: SettingsManager) -> void:
	_settings = settings
	_sync_from_settings()

func open() -> void:
	show()
	_sync_from_settings()

func close() -> void:
	hide()
	closed.emit()

func is_open() -> bool:
	return visible

func _on_mode_selected(index: int) -> void:
	if not _syncing and _settings != null:
		_settings.set_fullscreen(index == 1)

func _on_resolution_selected(index: int) -> void:
	if not _syncing and _settings != null:
		_settings.set_resolution(SettingsManager.RESOLUTIONS[index])

func _on_volume_changed(value: float) -> void:
	_volume_value.text = "%d%%" % int(value)
	if not _syncing and _settings != null:
		_settings.set_master_volume_percent(value)

func _sync_from_settings() -> void:
	if _settings == null or not is_node_ready():
		return
	_syncing = true
	_mode.select(1 if _settings.fullscreen else 0)
	_resolution.select(SettingsManager.RESOLUTIONS.find(_settings.resolution))
	_volume.value = _settings.master_volume_percent
	_volume_value.text = "%d%%" % int(_settings.master_volume_percent)
	_syncing = false
```

Create `scenes/ui/SettingsPanel.tscn` with:

- root `Control` using `settings_panel.gd`, full-rect anchors, `z_index = 100`, initially hidden;
- full-rect `Shade` `ColorRect` with translucent near-black color and `mouse_filter = Control.MOUSE_FILTER_STOP`;
- centered `Panel` sized for the three controls;
- title label `设置`;
- `ModeLabel` and `Mode` `OptionButton`;
- `ResolutionLabel` and `Resolution` `OptionButton`;
- `VolumeLabel`, `VolumeTrack` `TextureRect` using `menu_brush_slider.png`, transparent-overlay `Volume` `HSlider`, and `VolumeValue`;
- `CloseButton` labeled `返回`;
- optional `Divider` `TextureRect` using `menu_brush_divider.png`.

Keep text white with amber hover/selected accents. Do not add a full amber border.

**Step 4: Run the focused panel test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_settings_panel.tscn
```

Expected: `PASS: settings_panel`.

**Step 5: Commit**

```powershell
git add scripts/ui/settings_panel.gd scenes/ui/SettingsPanel.tscn scripts/test/test_settings_panel.gd scenes/test/test_settings_panel.tscn
git commit -m "feat(settings): add reusable settings panel"
```

### Task 5: Replace Title Restart With Settings

**Files:**
- Modify: `scenes/ui/TitleScreen.tscn`
- Modify: `scripts/ui/title_screen.gd`
- Modify: `scripts/test/test_title_screen_assets.gd`

**Step 1: Update the title asset test first**

In `scripts/test/test_title_screen_assets.gd`:

- replace `RestartButton` assertions with `SettingsButton`;
- assert the button text is `设置`;
- update the required title menu button list to `StartButton`, `ContinueButton`, `SettingsButton`, `QuitButton`;
- keep the existing `MenuBands` and `MenuMarker` assertions.

**Step 2: Run the title asset test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
```

Expected: failure because the scene still has `RestartButton`.

**Step 3: Wire the reusable panel into the title scene**

In `scenes/ui/TitleScreen.tscn`:

- rename `RestartButton` to `SettingsButton`;
- change its label to `设置`;
- instance `res://scenes/ui/SettingsPanel.tscn` under the title UI canvas;
- preserve the existing four `MenuBands` visuals and the short `MenuMarker`.

In `scripts/ui/title_screen.gd`:

```gdscript
@onready var _settings_panel: SettingsPanel = $UI/SettingsPanel

func _ready() -> void:
	# Keep the existing title initialization.
	_settings_panel.configure(GameManager.settings)
	$UI/SettingsButton.pressed.connect(_settings_panel.open)
```

Remove only the old title `RestartButton` connection. Keep `GameManager.restart_current_day()` itself because it may still be useful from debug or future UI entry points.

**Step 4: Run the title asset test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
```

Expected: pass.

**Step 5: Commit**

```powershell
git add scenes/ui/TitleScreen.tscn scripts/ui/title_screen.gd scripts/test/test_title_screen_assets.gd
git commit -m "feat(title): replace restart action with settings"
```

### Task 6: Add Tavern Settings Entry And Brush Menu Styling

**Files:**
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scripts/ui/tavern_view.gd`
- Modify: `scripts/test/test_workspace_scene_recovery.gd`

**Step 1: Add failing tavern menu checks**

Extend `scripts/test/test_workspace_scene_recovery.gd`:

```gdscript
var settings_panel: SettingsPanel = tavern.get_node("SettingsPanel")
assert(settings_panel != null)
assert(tavern.get_node("OverlayMenu/TabBtns/BtnSettings").text == "设置")
```

Add a call through the tavern view:

```gdscript
tavern._open_settings()
assert(settings_panel.visible)
settings_panel.close()
assert(tavern.get_node("OverlayMenu").visible)
```

**Step 2: Run the focused tavern test to verify it fails**

Run:

```powershell
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected: failure because the tavern settings entry does not exist.

**Step 3: Add the panel instance and menu button**

In `scenes/ui/Tavern.tscn`:

- instance `res://scenes/ui/SettingsPanel.tscn` as root child `SettingsPanel`;
- add `OverlayMenu/TabBtns/BtnSettings` labeled `设置`;
- shift the existing menu controls only as needed to preserve spacing.

In `scripts/ui/tavern_view.gd`:

```gdscript
@onready var _settings_panel: SettingsPanel = $SettingsPanel

func _ready() -> void:
	# Keep existing setup.
	_settings_panel.configure(GameManager.settings)
	$OverlayMenu/TabBtns/BtnSettings.pressed.connect(_open_settings)
	_settings_panel.closed.connect(_on_settings_closed)
	ThemeColors.style_brush_panel($OverlayMenu)
	for tab_button in [
		$OverlayMenu/TabBtns/BtnRecipes,
		$OverlayMenu/TabBtns/BtnBackpack,
		$OverlayMenu/TabBtns/BtnSettings,
	]:
		ThemeColors.style_brush_tab_button(tab_button)
	for button in [$OverlayMenu/BtnTidy, $OverlayMenu/CloseBtn]:
		ThemeColors.style_brush_button(button, 14)

func _open_settings() -> void:
	$OverlayMenu.hide()
	_settings_panel.open()

func _on_settings_closed() -> void:
	$OverlayMenu.show()
```

Apply `style_brush_tab_button()` to the dynamically created tutorial button. Replace the existing parchment override with `style_brush_panel($OverlayMenu)`. Update `is_menu_open()` to count `_settings_panel.visible`, so gameplay input remains blocked while settings are open. Add `_settings_panel.close()` as the first branch in `_unhandled_input()` for `ui_cancel`, before the document and inventory overlay branches.

Add a small `_select_overlay_tab(selected: Button)` helper that calls `ThemeColors.set_brush_selected()` across `TabBtns`. Select `BtnRecipes` during menu initialization and whenever the recipe tab is pressed. Select `BtnSettings` immediately before opening the settings panel. The selected label keeps its short marker; do not add a full border.

Do not restyle the title screen's four existing menu buttons with this helper; title already uses its approved menu bands and short marker. Do not restyle unrelated HUD buttons in this task.

**Step 4: Run the tavern-focused test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected: pass.

**Step 5: Commit**

```powershell
git add scenes/ui/Tavern.tscn scripts/ui/tavern_view.gd scripts/test/test_workspace_scene_recovery.gd
git commit -m "feat(tavern): expose settings in brush menu"
```

### Task 7: Run Unified Acceptance

**Files:**
- Verify only

**Step 1: Import resources headlessly**

Run:

```powershell
godot --headless --editor --quit --path .
```

Expected: no GDScript parse errors. Ignore MCP Mono-only assembly noise unless reproduced by the standard editor.

**Step 2: Run focused tests**

Run:

```powershell
godot --headless --path . res://scenes/test/test_settings_manager.tscn
godot --headless --path . res://scenes/test/test_brush_theme.tscn
godot --headless --path . res://scenes/test/test_settings_panel.tscn
godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected: each test exits cleanly with its pass marker.

**Step 3: Run the required manual path in the standard editor**

Run:

```text
TitleScreen -> DayMap -> Tavern -> LedgerScreen -> DayMap
```

Verify:

- title still shows four existing dark menu bands and its short hover underline marker;
- title `设置` opens the shared settings panel;
- tavern menu `设置` opens the same panel layout;
- panel visuals read as dark brush fields, not wood boards or full amber frames;
- windowed/fullscreen changes apply immediately;
- 1280x720, 1600x900, and 1920x1080 window sizes apply immediately in windowed mode;
- master volume 0-100 applies immediately;
- settings survive a full restart independently of game save data;
- gameplay input stays blocked while tavern settings are open.

**Step 4: Check repository hygiene**

Run:

```powershell
git status --short
Get-ChildItem -Recurse -File | Select-String -Pattern '<<<<<<<|=======|>>>>>>>'
```

Expected: only intentional files changed, no conflict markers, and no `tmp/` or `.godot/` files staged.
