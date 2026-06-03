# Title Screen Native Pixel Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current mixed-scale TitleScreen textures with one approved `320x180` native pixel-art source set, export deterministic `4x` runtime layers, and expose crisp common 16:9 display sizes without changing other scenes.

**Architecture:** Preserve `1280x720` as the runtime UI coordinate system. Use the approved image-generation preview as the visual reference, isolate its background, logo, and menu bands into staging cutouts, normalize every production layer onto one `320x180` grid, and export runtime PNGs with nearest-neighbor scaling only. Keep display adaptation in `SettingsManager` and lock CanvasItem filtering to Godot 4.6 nearest-neighbor mode.

**Tech Stack:** Godot 4.6 standard, GDScript, Python 3, Pillow, built-in `image_gen`, local chroma-key cleanup helper.

---

## Scope And File Map

**Create:**

- `assets/source/title/reference/title_pixel_composite_reference.png` - approved high-resolution image-generation preview retained for future source revisions.
- `assets/source/title/reference/title_pixel_bg_clean_reference.png` - cleaned text-free and UI-free generated reference.
- `assets/source/title/reference/title_pixel_logo_cutout.png` - transparent isolated logo cutout.
- `assets/source/title/reference/title_pixel_menu_bands_cutout.png` - transparent isolated four-band cutout.
- `assets/source/title/title_pixel_bg_clean_native.png` - normalized `320x180` environment source.
- `assets/source/title/title_pixel_glow_mask_native.png` - normalized `320x180` transparent warm-light source.
- `assets/source/title/title_pixel_logo_native.png` - normalized `320x180` transparent logo layer.
- `assets/source/title/title_pixel_menu_bands_native.png` - normalized `320x180` transparent menu-band layer.
- `assets/source/title/title_pixel_menu_marker_native.png` - deterministic `61x7` transparent marker source.
- `scripts/tools/prepare_title_screen_sources.py` - normalize generated references into native grid-aligned source layers.
- `scripts/tools/export_title_screen_assets.py` - validate and export native title sources to runtime textures.
- `scripts/test/test_title_screen_asset_pipeline.py` - direct Python regression test for source and runtime assets.

**Modify:**

- `assets/textures/title/title_pixel_bg_clean.png` - replace with exact `4x` nearest-neighbor export.
- `assets/textures/title/title_pixel_glow_mask.png` - replace with exact `4x` nearest-neighbor export.
- `assets/textures/title/title_pixel_logo.png` - replace with exact `4x` nearest-neighbor export.
- `assets/textures/title/title_pixel_menu_bands.png` - replace with exact `4x` nearest-neighbor export.
- `assets/textures/title/title_pixel_menu_marker.png` - replace with exact `4x` nearest-neighbor export.
- `scenes/ui/TitleScreen.tscn` - align full-canvas title layers and buttons.
- `scripts/ui/title_screen.gd` - snap logo motion to the native title grid.
- `scripts/test/test_title_screen_assets.gd` - validate full-canvas layers, source sizes, export scaling, and runtime layout.
- `scripts/systems/settings_manager.gd` - add `2560x1440` and `3840x2160`.
- `scripts/test/test_settings_manager.gd` - verify supported display sizes and project rendering settings.
- `project.godot` - preserve the existing unstaged `canvas_items + keep` changes and explicitly lock nearest-neighbor CanvasItem filtering.

**Do not modify:**

- `addons/`
- Tavern, DayMap, LedgerScreen, EndingScreen, dialogue, or gameplay files
- generated `.import` files
- `.godot/`

## Task 1: Materialize The Approved Visual Reference And Isolated Cutouts

**Files:**

- Create: `assets/source/title/reference/title_pixel_composite_reference.png`
- Create: `assets/source/title/reference/title_pixel_bg_clean_reference.png`
- Create: `assets/source/title/reference/title_pixel_logo_cutout.png`
- Create: `assets/source/title/reference/title_pixel_menu_bands_cutout.png`

- [ ] **Step 1: Create the source and temporary directories**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'assets\source\title\reference', 'tmp\title_imagegen' | Out-Null
```

Expected: both directories exist.

- [ ] **Step 2: Copy the approved preview into the repository reference directory**

Run:

```powershell
Copy-Item -LiteralPath 'C:\Users\zzc45\.codex\generated_images\019e87ff-0899-7ff2-b8ca-51426759cf7f\ig_03cba320162e8e3c016a1eb9cc17848191bd341d5b9380da90.png' -Destination 'assets\source\title\reference\title_pixel_composite_reference.png'
```

Expected: the copied image is `1672x941`.

- [ ] **Step 3: Generate the clean background plate**

Use built-in `image_gen` in edit mode with `title_pixel_composite_reference.png` as the edit target:

```text
Use case: precise-object-edit
Asset type: TitleScreen clean background plate
Primary request: Remove only the large LAST CALL / BELOW title logo and the four right-side horizontal menu bands. Reconstruct the underlying cavern wall, passage, and tavern environment naturally in the same native low-density pixel-art style.
Input images: Image 1 is the approved title-screen composite edit target.
Constraints: Preserve the tavern entrance, crooked lantern, oversized barrel, uneven crates, central teal passage, palette, lighting, composition, and pixel-cluster scale. Return a text-free, UI-free 16:9 background. Change nothing else.
Avoid: letters, pseudo-text, menu bands, extra props, smooth gradients, anti-aliasing, high-resolution painterly detail, watermark.
```

Copy the selected generated output to:

```text
assets/source/title/reference/title_pixel_bg_clean_reference.png
```

Inspect with `view_image`. Reject any output that leaves logo fragments, menu-band ghosts, or changes the doorway composition.

- [ ] **Step 4: Generate the isolated logo cutout**

Use built-in `image_gen` in edit mode with the approved composite as the edit target:

```text
Use case: precise-object-edit
Asset type: isolated TitleScreen logo cutout source
Primary request: Preserve the existing title logo exactly and remove every other visual element. Place only the two-line logo on a perfectly flat solid #00ff00 chroma-key background.
Text (verbatim): "LAST CALL\nBELOW"
Constraints: Preserve the existing lettering gesture, proportions, cream-yellow palette, hard pixel stair-step edges, dry-brush pixel clusters, and two-line arrangement. The background must be one uniform #00ff00 color with no shadow, gradient, texture, or lighting variation.
Avoid: environment, menu bands, extra text, checkerboard, anti-aliasing, matte fringe, watermark.
```

Copy the selected generated output to `tmp/title_imagegen/title_pixel_logo_keyed.png`, then run:

```powershell
python "$env:USERPROFILE\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py" `
  --input 'tmp\title_imagegen\title_pixel_logo_keyed.png' `
  --out 'assets\source\title\reference\title_pixel_logo_cutout.png' `
  --auto-key border `
  --soft-matte `
  --transparent-threshold 12 `
  --opaque-threshold 220 `
  --despill
```

Inspect the transparent PNG. Reject checkerboard backgrounds, green fringe, altered text, or missing brush fragments.

- [ ] **Step 5: Generate the isolated menu-band cutout**

Use built-in `image_gen` in edit mode with the approved composite as the edit target:

```text
Use case: precise-object-edit
Asset type: isolated TitleScreen menu-band cutout source
Primary request: Preserve the existing four right-side empty dark horizontal pixel-brush menu bands exactly and remove every other visual element. Place only the four bands on a perfectly flat solid #00ff00 chroma-key background.
Constraints: Keep exactly four empty bands in one vertical column. Preserve their deep charcoal-teal color, chunky hard pixel edges, uneven handmade ends, relative sizes, and spacing. The background must be one uniform #00ff00 color with no shadow, gradient, texture, or lighting variation.
Avoid: letters, symbols, menu labels, environment, extra bands, checkerboard, anti-aliasing, matte fringe, watermark.
```

Copy the selected generated output to `tmp/title_imagegen/title_pixel_menu_bands_keyed.png`, then run:

```powershell
python "$env:USERPROFILE\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py" `
  --input 'tmp\title_imagegen\title_pixel_menu_bands_keyed.png' `
  --out 'assets\source\title\reference\title_pixel_menu_bands_cutout.png' `
  --auto-key border `
  --soft-matte `
  --transparent-threshold 12 `
  --opaque-threshold 220 `
  --despill
```

Inspect the transparent PNG. Reject outputs with labels, more or fewer than four bands, or visible green fringe.

- [ ] **Step 6: Check the retained references**

Run:

```powershell
@'
from pathlib import Path
from PIL import Image

root = Path("assets/source/title/reference")
for path in sorted(root.glob("*.png")):
    image = Image.open(path)
    print(f"{path.name}: {image.size} {image.mode}")
'@ | python -
```

Expected: four readable PNG files; both cutouts report `RGBA`.

## Task 2: Add The Native-Source Preparation And Runtime Export Pipeline

**Files:**

- Create: `scripts/tools/prepare_title_screen_sources.py`
- Create: `scripts/tools/export_title_screen_assets.py`
- Create: `scripts/test/test_title_screen_asset_pipeline.py`
- Create: `assets/source/title/title_pixel_bg_clean_native.png`
- Create: `assets/source/title/title_pixel_glow_mask_native.png`
- Create: `assets/source/title/title_pixel_logo_native.png`
- Create: `assets/source/title/title_pixel_menu_bands_native.png`
- Create: `assets/source/title/title_pixel_menu_marker_native.png`
- Modify: `assets/textures/title/*.png`

- [ ] **Step 1: Write the failing pipeline regression test**

Create `scripts/test/test_title_screen_asset_pipeline.py`:

```python
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "title"
RUNTIME = ROOT / "assets" / "textures" / "title"
SCALE = 4
FULL_LAYERS = [
    "title_pixel_bg_clean",
    "title_pixel_glow_mask",
    "title_pixel_logo",
    "title_pixel_menu_bands",
]
CROPPED_LAYERS = ["title_pixel_menu_marker"]
TRANSPARENT_LAYERS = [
    "title_pixel_glow_mask",
    "title_pixel_logo",
    "title_pixel_menu_bands",
    "title_pixel_menu_marker",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def assert_exact_scale(name: str) -> None:
    native = Image.open(SOURCE / f"{name}_native.png").convert("RGBA")
    runtime = Image.open(RUNTIME / f"{name}.png").convert("RGBA")
    require(
        runtime.size == (native.width * SCALE, native.height * SCALE),
        f"{name}: wrong runtime size {runtime.size}",
    )
    expected = native.resize(runtime.size, Image.Resampling.NEAREST)
    require(list(runtime.getdata()) == list(expected.getdata()), f"{name}: not an exact nearest-neighbor export")


for name in FULL_LAYERS:
    native = Image.open(SOURCE / f"{name}_native.png")
    require(native.size == (320, 180), f"{name}: wrong native size {native.size}")

marker = Image.open(SOURCE / "title_pixel_menu_marker_native.png")
require(marker.size == (61, 7), f"title_pixel_menu_marker: wrong native size {marker.size}")

for name in TRANSPARENT_LAYERS:
    native = Image.open(SOURCE / f"{name}_native.png")
    require("A" in native.getbands(), f"{name}: native source needs alpha")

for name in FULL_LAYERS + CROPPED_LAYERS:
    assert_exact_scale(name)

print("[TEST-TITLE-PIPELINE] ALL PASS")
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
python scripts/test/test_title_screen_asset_pipeline.py
```

Expected: failure because the native sources do not exist.

- [ ] **Step 3: Add the source-preparation script**

Create `scripts/tools/prepare_title_screen_sources.py`:

```python
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "title"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 180)
LOGO_BOX = (4, 8, 224, 120)
MENU_BANDS_BOX = (244, 36, 318, 148)


def fit_cover(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    return ImageOps.fit(image, NATIVE_SIZE, method=Image.Resampling.NEAREST, centering=(0.5, 0.5))


def place_cutout(path: Path, box: tuple[int, int, int, int]) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    alpha_box = image.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError(f"{path.name}: transparent cutout is empty")
    image = image.crop(alpha_box)
    box_width = box[2] - box[0]
    box_height = box[3] - box[1]
    scale = min(box_width / image.width, box_height / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    image = image.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    position = (
        box[0] + (box_width - image.width) // 2,
        box[1] + (box_height - image.height) // 2,
    )
    canvas.alpha_composite(image, position)
    return canvas


def build_glow(background: Image.Image) -> Image.Image:
    alpha = Image.new("L", NATIVE_SIZE, 0)
    alpha_pixels = alpha.load()
    for y in range(NATIVE_SIZE[1]):
        for x in range(NATIVE_SIZE[0]):
            red, green, blue, _ = background.getpixel((x, y))
            warmth = max(0, red - blue - 24)
            brightness = max(0, red - 72)
            value = min(112, ((warmth + brightness) // 24) * 16)
            alpha_pixels[x, y] = value
    alpha = alpha.filter(ImageFilter.MaxFilter(7))
    glow = Image.new("RGBA", NATIVE_SIZE, (255, 138, 32, 0))
    glow.putalpha(alpha)
    return glow


def build_marker() -> Image.Image:
    marker = Image.new("RGBA", (61, 7), (0, 0, 0, 0))
    draw = ImageDraw.Draw(marker)
    draw.rectangle((4, 1, 55, 5), fill=(155, 75, 0, 255))
    draw.rectangle((1, 2, 59, 4), fill=(224, 133, 0, 255))
    draw.rectangle((8, 2, 51, 3), fill=(255, 184, 24, 255))
    draw.rectangle((0, 3, 2, 4), fill=(224, 133, 0, 255))
    draw.rectangle((57, 2, 60, 3), fill=(224, 133, 0, 255))
    return marker


SOURCE.mkdir(parents=True, exist_ok=True)
background = fit_cover(REFERENCE / "title_pixel_bg_clean_reference.png")
background.save(SOURCE / "title_pixel_bg_clean_native.png")
build_glow(background).save(SOURCE / "title_pixel_glow_mask_native.png")
place_cutout(REFERENCE / "title_pixel_logo_cutout.png", LOGO_BOX).save(SOURCE / "title_pixel_logo_native.png")
place_cutout(REFERENCE / "title_pixel_menu_bands_cutout.png", MENU_BANDS_BOX).save(SOURCE / "title_pixel_menu_bands_native.png")
build_marker().save(SOURCE / "title_pixel_menu_marker_native.png")
print("Prepared native title sources on the 320x180 grid")
```

- [ ] **Step 4: Add the deterministic runtime exporter**

Create `scripts/tools/export_title_screen_assets.py`:

```python
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "title"
OUTPUT = ROOT / "assets" / "textures" / "title"
SCALE = 4
FULL_LAYERS = [
    "title_pixel_bg_clean",
    "title_pixel_glow_mask",
    "title_pixel_logo",
    "title_pixel_menu_bands",
]
CROPPED_LAYERS = ["title_pixel_menu_marker"]
TRANSPARENT_LAYERS = {
    "title_pixel_glow_mask",
    "title_pixel_logo",
    "title_pixel_menu_bands",
    "title_pixel_menu_marker",
}


def export(name: str, expected_size: tuple[int, int] | None = None) -> None:
    source_path = SOURCE / f"{name}_native.png"
    if not source_path.exists():
        raise FileNotFoundError(f"Missing native title source: {source_path}")
    source = Image.open(source_path)
    if expected_size is not None and source.size != expected_size:
        raise ValueError(f"{name}: expected {expected_size}, got {source.size}")
    if name in TRANSPARENT_LAYERS and "A" not in source.getbands():
        raise ValueError(f"{name}: expected alpha channel")
    runtime_size = (source.width * SCALE, source.height * SCALE)
    runtime = source.convert("RGBA").resize(runtime_size, Image.Resampling.NEAREST)
    runtime.save(OUTPUT / f"{name}.png")
    print(f"{name}: {source.size} -> {runtime_size}")


OUTPUT.mkdir(parents=True, exist_ok=True)
for layer in FULL_LAYERS:
    export(layer, (320, 180))
for layer in CROPPED_LAYERS:
    export(layer, (61, 7))
```

- [ ] **Step 5: Prepare and export the title assets**

Run:

```powershell
python scripts/tools/prepare_title_screen_sources.py
python scripts/tools/export_title_screen_assets.py
```

Expected:

```text
Prepared native title sources on the 320x180 grid
title_pixel_bg_clean: (320, 180) -> (1280, 720)
title_pixel_glow_mask: (320, 180) -> (1280, 720)
title_pixel_logo: (320, 180) -> (1280, 720)
title_pixel_menu_bands: (320, 180) -> (1280, 720)
title_pixel_menu_marker: (61, 7) -> (244, 28)
```

- [ ] **Step 6: Run the pipeline test**

Run:

```powershell
python scripts/test/test_title_screen_asset_pipeline.py
```

Expected:

```text
[TEST-TITLE-PIPELINE] ALL PASS
```

- [ ] **Step 7: Inspect the generated native and runtime layers**

Use `view_image` on:

```text
assets/source/title/title_pixel_bg_clean_native.png
assets/source/title/title_pixel_logo_native.png
assets/source/title/title_pixel_menu_bands_native.png
assets/textures/title/title_pixel_bg_clean.png
assets/textures/title/title_pixel_logo.png
assets/textures/title/title_pixel_menu_bands.png
```

Confirm:

- one consistent `320x180` source grid;
- logo text is readable;
- exactly four menu bands remain;
- no green or pale matte fringe survives;
- warm-light overlay affects the doorway and lantern rather than the whole screen.

- [ ] **Step 8: Commit the title asset pipeline**

Run:

```powershell
git add scripts/tools/prepare_title_screen_sources.py scripts/tools/export_title_screen_assets.py scripts/test/test_title_screen_asset_pipeline.py
git add assets/source/title assets/textures/title/title_pixel_bg_clean.png assets/textures/title/title_pixel_glow_mask.png assets/textures/title/title_pixel_logo.png assets/textures/title/title_pixel_menu_bands.png assets/textures/title/title_pixel_menu_marker.png
git commit -m "feat(title): add native pixel asset pipeline"
```

## Task 3: Align TitleScreen With Full-Canvas Native Layers

**Files:**

- Modify: `scripts/test/test_title_screen_assets.gd`
- Modify: `scenes/ui/TitleScreen.tscn`
- Modify: `scripts/ui/title_screen.gd`

- [ ] **Step 1: Extend the TitleScreen test before changing the scene**

In `scripts/test/test_title_screen_assets.gd`, add constants after `TITLE_SCENE`:

```gdscript
const SOURCE_DIR := "res://assets/source/title/"
const FULL_LAYER_SOURCES := {
	"Background": "title_pixel_bg_clean_native.png",
	"GlowOverlay": "title_pixel_glow_mask_native.png",
	"Logo": "title_pixel_logo_native.png",
	"UI/MenuBands": "title_pixel_menu_bands_native.png",
}
```

In `_ready()`, after the five `_check_textured_node()` calls, add:

```gdscript
	for node_path in FULL_LAYER_SOURCES:
		_check_native_runtime_dimensions(
			SOURCE_DIR + FULL_LAYER_SOURCES[node_path],
			title_screen.get_node(node_path).texture,
			node_path,
			failures,
		)
	_check_native_runtime_dimensions(
		SOURCE_DIR + "title_pixel_menu_marker_native.png",
		_menu_marker_texture(title_screen),
		"UI/MenuMarker",
		failures,
	)
```

Replace:

```gdscript
	var logo_right := logo.position.x + logo.texture.get_width() * 0.5
```

with:

```gdscript
	var logo_right := _visible_bounds(logo.texture).end.x
```

Add before `_check()`:

```gdscript
func _check_native_runtime_dimensions(native_path: String, texture: Texture2D, label: String, failures: Array[String]) -> void:
	var native := Image.load_from_file(native_path)
	var runtime := texture.get_image()
	_check(native != null and not native.is_empty(), "%s native source must load" % label, failures)
	if native == null or native.is_empty():
		return
	_check(runtime.get_width() == native.get_width() * 4, "%s runtime width must be native width * 4" % label, failures)
	_check(runtime.get_height() == native.get_height() * 4, "%s runtime height must be native height * 4" % label, failures)


func _visible_bounds(texture: Texture2D) -> Rect2i:
	var image := texture.get_image()
	var first := Vector2i(image.get_width(), image.get_height())
	var last := Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			first.x = mini(first.x, x)
			first.y = mini(first.y, y)
			last.x = maxi(last.x, x + 1)
			last.y = maxi(last.y, y + 1)
	return Rect2i(first, last - first)
```

- [ ] **Step 2: Run the test to verify it fails against the old layout**

Run:

```powershell
$godot = 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
```

Expected: failure because the new full-canvas logo overlaps the menu area while the old scene still positions it as a cropped texture.

- [ ] **Step 3: Align full-canvas layers and menu buttons**

In `scenes/ui/TitleScreen.tscn`, change the `Logo` node to:

```ini
[node name="Logo" type="Sprite2D" parent="."]
position = Vector2(640, 360)
texture = ExtResource("5")
```

Change the `MenuBands` node to:

```ini
[node name="MenuBands" type="TextureRect" parent="UI"]
offset_right = 1280.0
offset_bottom = 720.0
mouse_filter = 2
texture = ExtResource("6")
expand_mode = 1
```

Use these button bounds:

```ini
[node name="StartButton" type="Button" parent="UI" unique_id=2134529780]
offset_left = 980.0
offset_top = 148.0
offset_right = 1260.0
offset_bottom = 198.0

[node name="ContinueButton" type="Button" parent="UI"]
offset_left = 980.0
offset_top = 252.0
offset_right = 1260.0
offset_bottom = 302.0

[node name="SettingsButton" type="Button" parent="UI"]
offset_left = 980.0
offset_top = 356.0
offset_right = 1260.0
offset_bottom = 406.0

[node name="QuitButton" type="Button" parent="UI"]
offset_left = 980.0
offset_top = 460.0
offset_right = 1260.0
offset_bottom = 510.0
```

If native menu-band inspection shows a band top differs from the intended `144`, `248`, `352`, `456` runtime rows, adjust `MENU_BANDS_BOX` in `prepare_title_screen_sources.py`, rerun both asset scripts, and keep each button exactly `4` runtime pixels below its corresponding band top.

- [ ] **Step 4: Snap the logo motion to the native source grid**

In `scripts/ui/title_screen.gd`, add after `TITLE_MENU_FONT`:

```gdscript
const LOGO_REST_Y := 360.0
const NATIVE_PIXEL_SCALE := 4.0
```

Replace:

```gdscript
	_logo.position.y = 300.0 + sin(_motion_time * 0.9) * 1.0
```

with:

```gdscript
	_logo.position.y = LOGO_REST_Y + roundf(sin(_motion_time * 0.9)) * NATIVE_PIXEL_SCALE
```

- [ ] **Step 5: Update the alignment assertion**

In `_check_menu_button_band_alignment()` in `scripts/test/test_title_screen_assets.gd`, replace:

```gdscript
		_check(is_equal_approx(button.position.y - band_top, 3.0), "%s must sit 3 px below its menu band top: got %s" % [button.name, button.position.y - band_top], failures)
```

with:

```gdscript
		_check(is_equal_approx(button.position.y - band_top, 4.0), "%s must sit 4 px below its menu band top: got %s" % [button.name, button.position.y - band_top], failures)
```

- [ ] **Step 6: Import and run the TitleScreen regression**

Run:

```powershell
& $godot --headless --editor --quit --path .
& $godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
```

Expected:

```text
TEST_TITLE_SCREEN_ASSETS_PASS
```

- [ ] **Step 7: Commit the TitleScreen integration**

Run:

```powershell
git add scenes/ui/TitleScreen.tscn scripts/ui/title_screen.gd scripts/test/test_title_screen_assets.gd
git commit -m "feat(title): align native pixel layers"
```

## Task 4: Add Crisp Common 16:9 Display Sizes

**Files:**

- Modify: `scripts/test/test_settings_manager.gd`
- Modify: `scripts/systems/settings_manager.gd`
- Modify: `project.godot`

- [ ] **Step 1: Add failing settings assertions**

In `_ready()` in `scripts/test/test_settings_manager.gd`, add:

```gdscript
	_test_pixel_display_configuration()
```

Add:

```gdscript
func _test_pixel_display_configuration() -> void:
	assert(SettingsManager.RESOLUTIONS == [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	])
	assert(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items")
	assert(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep")
	assert(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 1)
```

- [ ] **Step 2: Run the settings test to verify it fails**

Run:

```powershell
& $godot --headless --path . res://scenes/test/test_settings_manager.tscn
```

Expected: failure because the two larger sizes and explicit rendering key are missing.

- [ ] **Step 3: Extend the supported settings sizes**

In `scripts/systems/settings_manager.gd`, replace `RESOLUTIONS` with:

```gdscript
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
```

- [ ] **Step 4: Preserve the approved stretch settings and lock CanvasItem nearest-neighbor filtering**

Keep the existing unstaged lines in `[display]`:

```ini
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

Add under `[rendering]`:

```ini
textures/canvas_textures/default_texture_filter=1
```

Do not add `window/stretch/scale_mode="integer"`. With this project's `1280x720` logical UI canvas, Godot would round `1920x1080` down from `1.5x` to `1x`. The title textures already preserve the intended `320x180` pixel grid because every authored pixel is exported as a `4x4` runtime block.

- [ ] **Step 5: Run settings regressions**

Run:

```powershell
& $godot --headless --path . res://scenes/test/test_settings_manager.tscn
& $godot --headless --path . res://scenes/test/test_settings_panel.tscn
```

Expected:

```text
[TEST-SETTINGS] ALL PASS
[TEST-SETTINGS-PANEL] ALL PASS
```

- [ ] **Step 6: Commit the display configuration**

Run:

```powershell
git add project.godot scripts/systems/settings_manager.gd scripts/test/test_settings_manager.gd
git commit -m "feat(settings): add crisp high-resolution display sizes"
```

## Task 5: Unified Verification

**Files:**

- Verify only

- [ ] **Step 1: Rebuild assets from retained sources**

Run:

```powershell
python scripts/tools/prepare_title_screen_sources.py
python scripts/tools/export_title_screen_assets.py
python scripts/test/test_title_screen_asset_pipeline.py
```

Expected: all five exports print their dimensions and the pipeline test prints `[TEST-TITLE-PIPELINE] ALL PASS`.

- [ ] **Step 2: Import resources and run focused Godot tests**

Run:

```powershell
& $godot --headless --editor --quit --path .
& $godot --headless --path . res://scenes/test/test_title_screen_assets.tscn
& $godot --headless --path . res://scenes/test/test_settings_manager.tscn
& $godot --headless --path . res://scenes/test/test_settings_panel.tscn
```

Expected:

```text
TEST_TITLE_SCREEN_ASSETS_PASS
[TEST-SETTINGS] ALL PASS
[TEST-SETTINGS-PANEL] ALL PASS
```

- [ ] **Step 3: Check repository hygiene**

Run:

```powershell
git status --short
rg -n "<<<<<<<|=======|>>>>>>>" --glob "!tmp/**" --glob "!.godot/**" .
```

Expected: no unintended files, no `.godot/`, no `.import` changes, and no conflict markers.

- [ ] **Step 4: Run the standard-editor TitleScreen visual pass**

Open the Godot 4.6.x standard editor and inspect only `TitleScreen`:

1. Run windowed at `1280x720`, `1600x900`, and `1920x1080`.
2. Use fullscreen on available `1920x1080`, `2560x1440`, or `3840x2160` hardware.
3. Confirm logo text readability, crisp native-grid pixels, right-side menu alignment, hover marker placement, and doorway glow animation.
4. Confirm non-16:9 windows preserve composition with black bars rather than stretching.
5. Confirm Settings opens and both new resolution choices are listed.

- [ ] **Step 5: Run the repository-required smoke path**

In the standard editor, run:

```text
TitleScreen -> DayMap -> Tavern -> LedgerScreen -> DayMap
```

Expected: `0 errors/warnings`. Treat MCP Mono-only `.NET: Assemblies not found` output as environment noise unless the standard editor reproduces it.
