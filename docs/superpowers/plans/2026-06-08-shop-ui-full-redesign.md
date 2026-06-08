# Shop UI Full Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the DayMap shop as an integrated native-pixel traveling merchant stall: central ledger, scene-object controls, no full merchant character, and preserved purchase behavior.

**Architecture:** Keep `ShopOverlay` as the shop behavior boundary, but replace its visual construction with fixed scene-object zones over a unified native-pixel stall reference. Replace low-detail procedural card/button assets with reference-derived native sources exported by Pillow. Keep `DayMapView` integration stable so the map still opens/closes the overlay as it does today.

**Tech Stack:** Godot 4.6 GDScript, Godot headless scene tests, Python unittest, Pillow, built-in image generation for project-bound raster reference art, Fusion Pixel Chinese font.

---

## Commit Safety

The current worktree contains unrelated DayMap and asset changes. Do not use `git add .` or `git add -A`. Before every commit step, run `git status --short` and stage only files listed in that task. If unrelated files are dirty, leave them alone.

## File Structure

| Path | Action | Responsibility |
| --- | --- | --- |
| `assets/source/daymap/shop_redesign/reference/shop_stall_reference_generated.png` | Create | Project-bound AI reference art for the whole merchant stall and ledger composition. |
| `assets/source/daymap/shop_redesign/*.png` | Replace/Create | Native-pixel sources derived from the reference: scene, ledger, bookmarks, item rows, seal, tags, quantity controls, status marks. |
| `assets/textures/daymap/shop_redesign/*.png` | Replace/Create | Runtime textures exported exactly from native sources with nearest-neighbor scaling. |
| `scripts/tools/export_daymap_shop_redesign_assets.py` | Replace | Deterministic reference-driven exporter; no `ImageDraw` for core UI. |
| `scripts/test/test_daymap_ui_asset_pipeline.py` | Modify | Add hard tests for reference use, exact exports, and non-placeholder visual density. |
| `scripts/test/test_shop_overlay.gd` | Modify | Change UI contract from tabs/grid/buttons to ledger/bookmark/scene-object zones. |
| `scripts/ui/shop_overlay.gd` | Replace visual layer | Preserve purchase/data methods, rebuild view hierarchy around scene-object nodes and transparent click zones. |
| `scenes/ui/ShopOverlay.tscn` | Keep | Minimal `Control` root wired to `shop_overlay.gd`. |
| `data/shop_ui.json` | Keep/extend only if needed | Presentation metadata for descriptions, usage, ordering. |

## Verification Commands

Use these from repo root:

```powershell
python -m unittest scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_exporter_uses_reference_art -v
python -m unittest scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_assets_are_exact_native_exports -v
python -m unittest scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_assets_have_integrated_scene_materials -v
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_shop_overlay.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_day_map_scrollbars.tscn
```

If that Godot path is not present on the machine, locate the console binary with:

```powershell
Get-ChildItem -Path 'C:\Program Files' -Recurse -Filter '*Godot*console*.exe' -ErrorAction SilentlyContinue | Select-Object -First 5 -ExpandProperty FullName
```

---

### Task 1: Lock the Reference-Driven Asset Contract

**Files:**
- Modify: `scripts/test/test_daymap_ui_asset_pipeline.py`
- Test-only expected red: `scripts/tools/export_daymap_shop_redesign_assets.py`

- [ ] **Step 1: Add shop redesign constants**

In `scripts/test/test_daymap_ui_asset_pipeline.py`, replace the current shop redesign constants:

```python
SHOP_SCENE_NATIVE_SIZE = (320, 180)
SHOP_SCENE_RUNTIME_SIZE = (1280, 720)
SHOP_BOOK_NATIVE_SIZE = (240, 104)
SHOP_BOOK_RUNTIME_SIZE = (960, 416)
SHOP_TAB_NATIVE_SIZE = (42, 14)
SHOP_TAB_RUNTIME_SIZE = (168, 56)
SHOP_CARD_NATIVE_SIZE = (58, 28)
SHOP_CARD_RUNTIME_SIZE = (232, 112)
SHOP_ACTION_NATIVE_SIZE = (44, 14)
SHOP_ACTION_RUNTIME_SIZE = (176, 56)
```

with:

```python
SHOP_REFERENCE = SHOP_REDESIGN_SOURCE / "reference" / "shop_stall_reference_generated.png"
SHOP_SCENE_NATIVE_SIZE = (320, 180)
SHOP_SCENE_RUNTIME_SIZE = (1280, 720)
SHOP_BOOK_NATIVE_SIZE = (248, 104)
SHOP_BOOK_RUNTIME_SIZE = (992, 416)
SHOP_BOOKMARK_NATIVE_SIZE = (36, 16)
SHOP_BOOKMARK_RUNTIME_SIZE = (144, 64)
SHOP_ITEM_ROW_NATIVE_SIZE = (116, 18)
SHOP_ITEM_ROW_RUNTIME_SIZE = (464, 72)
SHOP_SEAL_NATIVE_SIZE = (46, 18)
SHOP_SEAL_RUNTIME_SIZE = (184, 72)
SHOP_TAG_NATIVE_SIZE = (44, 16)
SHOP_TAG_RUNTIME_SIZE = (176, 64)
SHOP_QUANTITY_NATIVE_SIZE = (48, 18)
SHOP_QUANTITY_RUNTIME_SIZE = (192, 72)
SHOP_STATUS_NATIVE_SIZE = (40, 14)
SHOP_STATUS_RUNTIME_SIZE = (160, 56)
```

- [ ] **Step 2: Replace the exact-export test cases**

Replace the `cases` list inside `test_shop_redesign_assets_are_exact_native_exports` with:

```python
cases = [
    ("shop_scene", SHOP_SCENE_NATIVE_SIZE, SHOP_SCENE_RUNTIME_SIZE),
    ("shop_book", SHOP_BOOK_NATIVE_SIZE, SHOP_BOOK_RUNTIME_SIZE),
    ("bookmark_materials_normal", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
    ("bookmark_materials_selected", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
    ("bookmark_recipes_normal", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
    ("bookmark_recipes_selected", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
    ("bookmark_abilities_normal", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
    ("bookmark_abilities_selected", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
    ("item_row_normal", SHOP_ITEM_ROW_NATIVE_SIZE, SHOP_ITEM_ROW_RUNTIME_SIZE),
    ("item_row_selected", SHOP_ITEM_ROW_NATIVE_SIZE, SHOP_ITEM_ROW_RUNTIME_SIZE),
    ("item_row_disabled", SHOP_ITEM_ROW_NATIVE_SIZE, SHOP_ITEM_ROW_RUNTIME_SIZE),
    ("purchase_seal_normal", SHOP_SEAL_NATIVE_SIZE, SHOP_SEAL_RUNTIME_SIZE),
    ("purchase_seal_pressed", SHOP_SEAL_NATIVE_SIZE, SHOP_SEAL_RUNTIME_SIZE),
    ("purchase_seal_disabled", SHOP_SEAL_NATIVE_SIZE, SHOP_SEAL_RUNTIME_SIZE),
    ("close_tag_normal", SHOP_TAG_NATIVE_SIZE, SHOP_TAG_RUNTIME_SIZE),
    ("close_tag_selected", SHOP_TAG_NATIVE_SIZE, SHOP_TAG_RUNTIME_SIZE),
    ("quantity_abacus", SHOP_QUANTITY_NATIVE_SIZE, SHOP_QUANTITY_RUNTIME_SIZE),
    ("status_owned", SHOP_STATUS_NATIVE_SIZE, SHOP_STATUS_RUNTIME_SIZE),
    ("status_discount", SHOP_STATUS_NATIVE_SIZE, SHOP_STATUS_RUNTIME_SIZE),
]
```

- [ ] **Step 3: Add exporter reference tests**

Add these methods to `DayMapUiAssetPipelineTest` after `test_shop_reference_sources_are_retained`:

```python
def test_shop_redesign_reference_source_is_retained(self) -> None:
    self.assertTrue(SHOP_REFERENCE.exists(), f"{SHOP_REFERENCE}: missing retained generated reference art")
    self.assertGreater(SHOP_REFERENCE.stat().st_size, 0, f"{SHOP_REFERENCE}: reference art is empty")

def test_shop_redesign_exporter_uses_reference_art(self) -> None:
    source = (ROOT / "scripts" / "tools" / "export_daymap_shop_redesign_assets.py").read_text(encoding="utf-8")
    self.assertIn("SHOP_REFERENCE", source, "shop redesign exporter must retain and consume generated reference art")
    self.assertIn("crop_reference", source, "shop redesign exporter must crop from the generated reference")
    self.assertNotIn("ImageDraw", source, "shop redesign core UI must not be procedurally rectangle-drawn")
    self.assertNotIn("rectangle(", source, "shop redesign core UI must not be built from drawn rectangles")
```

- [ ] **Step 4: Replace visual quality tests**

Replace `test_shop_redesign_scene_reads_as_counter_and_book` and `test_shop_redesign_book_has_transparent_margin_and_parchment_body` with:

```python
def test_shop_redesign_assets_have_integrated_scene_materials(self) -> None:
    scene = load_rgba(SHOP_REDESIGN_SOURCE / "shop_scene_native.png")
    pixels = list(scene.get_flattened_data())
    teal_shadow = sum(
        1 for r, g, b, a in pixels
        if a >= 220 and 5 <= r <= 50 and 18 <= g <= 78 and 18 <= b <= 85
    )
    amber_light = sum(
        1 for r, g, b, a in pixels
        if a >= 200 and r >= 145 and 60 <= g <= 175 and b <= 95
    )
    wood_counter = sum(
        1 for r, g, b, a in pixels
        if a >= 200 and 45 <= r <= 145 and 25 <= g <= 95 and 12 <= b <= 65
    )
    parchment = sum(
        1 for r, g, b, a in pixels
        if a >= 200 and 110 <= r <= 220 and 70 <= g <= 170 and 35 <= b <= 120
    )
    visible_colors = {
        (r, g, b)
        for r, g, b, a in pixels
        if a >= 200
    }
    self.assertGreaterEqual(teal_shadow, 2600, "shop scene needs dark teal underground shadow mass")
    self.assertGreaterEqual(amber_light, 180, "shop scene needs sparse amber stall light")
    self.assertGreaterEqual(wood_counter, 1700, "shop scene needs wooden counter/stall pixels")
    self.assertGreaterEqual(parchment, 5200, "shop scene needs readable ledger parchment area")
    self.assertGreaterEqual(len(visible_colors), 24, "shop scene needs enough tonal variation to sit with title art")

def test_shop_redesign_interaction_assets_are_not_flat_rectangles(self) -> None:
    cases = [
        "bookmark_materials_normal",
        "item_row_normal",
        "item_row_selected",
        "purchase_seal_normal",
        "close_tag_normal",
        "quantity_abacus",
        "status_owned",
        "status_discount",
    ]
    for name in cases:
        with self.subTest(name=name):
            native = load_rgba(SHOP_REDESIGN_SOURCE / f"{name}_native.png")
            pixels = list(native.get_flattened_data())
            visible_colors = {
                (r, g, b)
                for r, g, b, a in pixels
                if a >= 120
            }
            alpha_min, alpha_max = native.getchannel("A").getextrema()
            amber = sum(
                1 for r, g, b, a in pixels
                if a >= 160 and r >= 145 and 55 <= g <= 175 and b <= 100
            )
            dark = sum(
                1 for r, g, b, a in pixels
                if a >= 160 and r <= 70 and 18 <= g <= 90 and 15 <= b <= 90
            )
            self.assertEqual(alpha_min, 0, f"{name}: needs transparent irregular edge pixels")
            self.assertGreater(alpha_max, 0, f"{name}: has no visible pixels")
            self.assertGreaterEqual(len(visible_colors), 8, f"{name}: too few colors; looks like a flat rectangle")
            self.assertGreaterEqual(amber + dark, 8, f"{name}: needs scene-material accent/shadow pixels")
```

- [ ] **Step 5: Run red asset tests**

Run:

```powershell
python -m unittest scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_reference_source_is_retained scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_exporter_uses_reference_art scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_assets_are_exact_native_exports scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_assets_have_integrated_scene_materials scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_interaction_assets_are_not_flat_rectangles -v
```

Expected: FAIL because the new reference file and renamed native/runtime assets do not exist, and the exporter still imports `ImageDraw`.

- [ ] **Step 6: Commit checkpoint**

Run:

```powershell
git status --short
git add scripts/test/test_daymap_ui_asset_pipeline.py
git commit -m "test: lock integrated shop asset pipeline"
```

Expected: commit contains only `scripts/test/test_daymap_ui_asset_pipeline.py`.

---

### Task 2: Generate and Retain the Merchant Stall Reference

**Files:**
- Create: `assets/source/daymap/shop_redesign/reference/shop_stall_reference_generated.png`

- [ ] **Step 1: Generate the project-bound reference image**

Use the built-in image generation tool with this prompt:

```text
Use case: stylized-concept
Asset type: native-pixel game UI reference for a 1280x720 shop overlay
Primary request: a full-screen underground traveling merchant stall UI composition with no complete merchant character, designed so interface and background feel like one image.
Scene/backdrop: dark teal underground stone market stall, wooden counter, shelves, crates, bottles, rolled scrolls, small sacks, candle and lantern clutter.
Subject: a large open ledger centered in the lower middle, left page reserved for a vertical product list, right page reserved for selected item details, bottom counter reserved for coin tray, small abacus quantity control, purchase seal, and exit wooden tag.
Style/medium: chunky low-density pixel art, title-screen style, native pixel grid feeling, crisp edges, no antialias blur.
Composition/framing: 16:9 landscape, UI-readable low-noise ledger pages, no complete merchant; include only a sleeve, hand shadow, half backpack, or partial arm behind the counter for presence.
Lighting/mood: dark teal shadows with sparse amber candle and lantern accents, moody underground tavern tone.
Color palette: dark teal stone, deep brown wood, muted parchment, old-gold amber highlights, low saturation.
Materials/textures: rough stone wall, worn wooden counter, parchment ledger, wax seal, brass coins, cloth tags.
Text: no readable text, no letters, no numbers.
Constraints: leave clean readable zones on ledger pages and small physical controls; all UI controls must look like scene objects, not modern buttons.
Avoid: complete person, modern UI panels, bright gold mall look, neon, glassmorphism, smooth vector art, high-resolution painted detail, text, watermark.
```

After generation, copy the selected output into:

```text
assets/source/daymap/shop_redesign/reference/shop_stall_reference_generated.png
```

- [ ] **Step 2: Inspect the generated reference**

Open the image and verify:

```powershell
python - <<'PY'
from PIL import Image
path = 'assets/source/daymap/shop_redesign/reference/shop_stall_reference_generated.png'
im = Image.open(path)
print(im.size, im.mode)
PY
```

Expected: image exists, is landscape, and visibly contains the ledger, stall objects, and no complete merchant.

- [ ] **Step 3: Re-run red reference test**

Run:

```powershell
python -m unittest scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_reference_source_is_retained -v
```

Expected: PASS for reference existence. Other asset tests still fail.

- [ ] **Step 4: Commit checkpoint**

Run:

```powershell
git status --short
git add assets/source/daymap/shop_redesign/reference/shop_stall_reference_generated.png
git commit -m "art: add integrated shop stall reference"
```

Expected: commit contains only the generated reference image.

---

### Task 3: Replace the Shop Redesign Exporter

**Files:**
- Modify: `scripts/tools/export_daymap_shop_redesign_assets.py`
- Create/Replace generated: `assets/source/daymap/shop_redesign/*_native.png`
- Create/Replace generated: `assets/textures/daymap/shop_redesign/*.png`

- [ ] **Step 1: Replace exporter with reference-cropping pipeline**

Replace `scripts/tools/export_daymap_shop_redesign_assets.py` with:

```python
from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_redesign"
REFERENCE_DIR = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_redesign"
SHOP_REFERENCE = REFERENCE_DIR / "shop_stall_reference_generated.png"

ASSET_SPECS = {
    "shop_scene": ((0.00, 0.00, 1.00, 1.00), (320, 180), (1280, 720)),
    "shop_book": ((0.1125, 0.355, 0.8875, 0.933), (248, 104), (992, 416)),
    "bookmark_materials_normal": ((0.134, 0.332, 0.247, 0.421), (36, 16), (144, 64)),
    "bookmark_materials_selected": ((0.134, 0.315, 0.247, 0.404), (36, 16), (144, 64)),
    "bookmark_recipes_normal": ((0.252, 0.332, 0.365, 0.421), (36, 16), (144, 64)),
    "bookmark_recipes_selected": ((0.252, 0.315, 0.365, 0.404), (36, 16), (144, 64)),
    "bookmark_abilities_normal": ((0.370, 0.332, 0.483, 0.421), (36, 16), (144, 64)),
    "bookmark_abilities_selected": ((0.370, 0.315, 0.483, 0.404), (36, 16), (144, 64)),
    "item_row_normal": ((0.155, 0.485, 0.518, 0.585), (116, 18), (464, 72)),
    "item_row_selected": ((0.155, 0.592, 0.518, 0.692), (116, 18), (464, 72)),
    "item_row_disabled": ((0.155, 0.699, 0.518, 0.799), (116, 18), (464, 72)),
    "purchase_seal_normal": ((0.648, 0.835, 0.792, 0.935), (46, 18), (184, 72)),
    "purchase_seal_pressed": ((0.648, 0.815, 0.792, 0.915), (46, 18), (184, 72)),
    "purchase_seal_disabled": ((0.648, 0.855, 0.792, 0.955), (46, 18), (184, 72)),
    "close_tag_normal": ((0.817, 0.823, 0.955, 0.912), (44, 16), (176, 64)),
    "close_tag_selected": ((0.817, 0.800, 0.955, 0.889), (44, 16), (176, 64)),
    "quantity_abacus": ((0.445, 0.830, 0.595, 0.930), (48, 18), (192, 72)),
    "status_owned": ((0.705, 0.610, 0.830, 0.688), (40, 14), (160, 56)),
    "status_discount": ((0.705, 0.695, 0.830, 0.773), (40, 14), (160, 56)),
}

TRANSPARENT_ASSETS = {
    "shop_book",
    "bookmark_materials_normal",
    "bookmark_materials_selected",
    "bookmark_recipes_normal",
    "bookmark_recipes_selected",
    "bookmark_abilities_normal",
    "bookmark_abilities_selected",
    "item_row_normal",
    "item_row_selected",
    "item_row_disabled",
    "purchase_seal_normal",
    "purchase_seal_pressed",
    "purchase_seal_disabled",
    "close_tag_normal",
    "close_tag_selected",
    "quantity_abacus",
    "status_owned",
    "status_discount",
}


def load_reference() -> Image.Image:
    if not SHOP_REFERENCE.exists():
        raise FileNotFoundError(f"Missing generated shop reference: {SHOP_REFERENCE}")
    return Image.open(SHOP_REFERENCE).convert("RGBA")


def crop_reference(reference: Image.Image, box_ratio: tuple[float, float, float, float]) -> Image.Image:
    width, height = reference.size
    left = round(box_ratio[0] * width)
    top = round(box_ratio[1] * height)
    right = round(box_ratio[2] * width)
    bottom = round(box_ratio[3] * height)
    return reference.crop((left, top, right, bottom)).convert("RGBA")


def pixel_normalize(image: Image.Image, native_size: tuple[int, int], transparent: bool) -> Image.Image:
    fitted = ImageOps.fit(image, native_size, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5)).convert("RGBA")
    fitted = ImageEnhance.Color(fitted).enhance(0.82)
    fitted = ImageEnhance.Contrast(fitted).enhance(1.12)
    fitted = fitted.quantize(colors=32, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    if transparent:
        fitted = apply_irregular_alpha(fitted)
    return fitted


def apply_irregular_alpha(image: Image.Image) -> Image.Image:
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            edge = x == 0 or y == 0 or x == width - 1 or y == height - 1
            corner_cut = (x < 2 and y < 2) or (x >= width - 2 and y < 2) or (x < 2 and y >= height - 2) or (x >= width - 2 and y >= height - 2)
            dark_background = red < 24 and green < 34 and blue < 38
            if corner_cut or (edge and dark_background):
                pixels[x, y] = (red, green, blue, 0)
    return image


def nearest_export(native: Image.Image, runtime_size: tuple[int, int]) -> Image.Image:
    return native.resize(runtime_size, Image.Resampling.NEAREST)


def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native.save(SOURCE / f"{name}_native.png")
    nearest_export(native, runtime_size).save(RUNTIME / f"{name}.png")


def main() -> None:
    reference = load_reference()
    for name, (box_ratio, native_size, runtime_size) in ASSET_SPECS.items():
        crop = crop_reference(reference, box_ratio)
        native = pixel_normalize(crop, native_size, name in TRANSPARENT_ASSETS)
        save_pair(name, native, runtime_size)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run exporter**

Run:

```powershell
python scripts/tools/export_daymap_shop_redesign_assets.py
```

Expected: native and runtime PNGs are created or replaced under `assets/source/daymap/shop_redesign/` and `assets/textures/daymap/shop_redesign/`.

- [ ] **Step 3: Run asset tests**

Run:

```powershell
python -m unittest scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_reference_source_is_retained scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_exporter_uses_reference_art scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_assets_are_exact_native_exports scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_assets_have_integrated_scene_materials scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_interaction_assets_are_not_flat_rectangles -v
```

Expected: PASS. If visual thresholds fail because the generated reference composition differs, inspect the reference and adjust crop ratios only; do not reintroduce procedural drawing.

- [ ] **Step 4: Commit checkpoint**

Run:

```powershell
git status --short
git add scripts/tools/export_daymap_shop_redesign_assets.py assets/source/daymap/shop_redesign assets/textures/daymap/shop_redesign
git commit -m "art: export integrated shop overlay assets"
```

Expected: commit contains exporter plus shop_redesign reference/native/runtime assets only.

---

### Task 4: Replace the Shop Overlay Visual Contract Test

**Files:**
- Modify: `scripts/test/test_shop_overlay.gd`

- [ ] **Step 1: Replace `_test_core_layout`**

Replace `_test_core_layout` in `scripts/test/test_shop_overlay.gd` with:

```gdscript
func _test_core_layout(overlay) -> void:
	_ok(overlay.visible, "overlay is visible after open")
	_ok(overlay.get_node_or_null("SceneBackdrop") is TextureRect, "overlay has native-pixel stall backdrop")
	_ok(overlay.get_node_or_null("BookLayer") is TextureRect, "overlay has integrated ledger layer")
	_ok(overlay.get_node_or_null("CategoryBookmarks/MaterialsZone") is Button, "materials bookmark click zone exists")
	_ok(overlay.get_node_or_null("CategoryBookmarks/RecipesZone") is Button, "recipes bookmark click zone exists")
	_ok(overlay.get_node_or_null("CategoryBookmarks/AbilitiesZone") is Button, "abilities bookmark click zone exists")
	_ok(overlay.get_node_or_null("ItemRows") is Control, "ledger item row zone exists")
	_ok(overlay.get_node_or_null("DetailPage/Title") is Label, "ledger detail title exists")
	_ok(overlay.get_node_or_null("CoinTray/GoldLabel") is Label, "coin tray gold label exists")
	_ok(overlay.get_node_or_null("QuantityAbacus/MinusZone") is Button, "quantity abacus minus click zone exists")
	_ok(overlay.get_node_or_null("QuantityAbacus/PlusZone") is Button, "quantity abacus plus click zone exists")
	_ok(overlay.get_node_or_null("PurchaseSeal/PurchaseZone") is Button, "purchase seal click zone exists")
	_ok(overlay.get_node_or_null("CloseTag/CloseZone") is Button, "close tag click zone exists")
	var purchase := overlay.get_node("PurchaseSeal/PurchaseZone") as Button
	_ok(purchase.text == "", "purchase input zone is textless")
	_ok(not purchase.has_theme_stylebox_override("normal"), "purchase input zone does not expose normal button skin")
```

- [ ] **Step 2: Update node paths in behavior assertions**

Make these replacements in `scripts/test/test_shop_overlay.gd`:

```text
Detail/Title -> DetailPage/Title
Detail/Uses -> DetailPage/Uses
CounterBar/TotalLabel -> CoinTray/TotalLabel
Detail/State -> DetailPage/State
CounterBar/PurchaseButton -> PurchaseSeal/PurchaseZone
```

- [ ] **Step 3: Add nearest-filter assertion**

Add this helper test and call it from `_ready()` after `_test_core_layout(overlay)`:

```gdscript
func _test_nearest_filtering(overlay) -> void:
	for path in ["SceneBackdrop", "BookLayer"]:
		var rect := overlay.get_node(path) as TextureRect
		_ok(rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, path + " uses nearest texture filtering")
```

- [ ] **Step 4: Run red Godot test**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_shop_overlay.tscn
```

Expected: FAIL because current `ShopOverlay` still builds `Tabs`, `ItemGrid`, and `CounterBar` with ordinary button skins.

- [ ] **Step 5: Commit checkpoint**

Run:

```powershell
git status --short
git add scripts/test/test_shop_overlay.gd
git commit -m "test: require integrated shop overlay structure"
```

Expected: commit contains only `scripts/test/test_shop_overlay.gd`.

---

### Task 5: Rebuild `ShopOverlay` Around Scene-Object Zones

**Files:**
- Modify: `scripts/ui/shop_overlay.gd`

- [ ] **Step 1: Replace texture constants**

Replace existing `TAB_*`, `CARD_*`, and `BUTTON_*` constants with:

```gdscript
const BOOKMARK_MATERIALS_NORMAL := "res://assets/textures/daymap/shop_redesign/bookmark_materials_normal.png"
const BOOKMARK_MATERIALS_SELECTED := "res://assets/textures/daymap/shop_redesign/bookmark_materials_selected.png"
const BOOKMARK_RECIPES_NORMAL := "res://assets/textures/daymap/shop_redesign/bookmark_recipes_normal.png"
const BOOKMARK_RECIPES_SELECTED := "res://assets/textures/daymap/shop_redesign/bookmark_recipes_selected.png"
const BOOKMARK_ABILITIES_NORMAL := "res://assets/textures/daymap/shop_redesign/bookmark_abilities_normal.png"
const BOOKMARK_ABILITIES_SELECTED := "res://assets/textures/daymap/shop_redesign/bookmark_abilities_selected.png"
const ITEM_ROW_NORMAL := "res://assets/textures/daymap/shop_redesign/item_row_normal.png"
const ITEM_ROW_SELECTED := "res://assets/textures/daymap/shop_redesign/item_row_selected.png"
const ITEM_ROW_DISABLED := "res://assets/textures/daymap/shop_redesign/item_row_disabled.png"
const PURCHASE_SEAL_NORMAL := "res://assets/textures/daymap/shop_redesign/purchase_seal_normal.png"
const PURCHASE_SEAL_PRESSED := "res://assets/textures/daymap/shop_redesign/purchase_seal_pressed.png"
const PURCHASE_SEAL_DISABLED := "res://assets/textures/daymap/shop_redesign/purchase_seal_disabled.png"
const CLOSE_TAG_NORMAL := "res://assets/textures/daymap/shop_redesign/close_tag_normal.png"
const CLOSE_TAG_SELECTED := "res://assets/textures/daymap/shop_redesign/close_tag_selected.png"
const QUANTITY_ABACUS := "res://assets/textures/daymap/shop_redesign/quantity_abacus.png"
const STATUS_OWNED := "res://assets/textures/daymap/shop_redesign/status_owned.png"
const STATUS_DISCOUNT := "res://assets/textures/daymap/shop_redesign/status_discount.png"
```

- [ ] **Step 2: Replace visual member vars**

Replace `_tabs`, `_grid`, `_gold_label`, `_total_label`, `_purchase_btn`, `_minus_btn`, `_plus_btn` declarations with:

```gdscript
var _bookmarks: Control
var _bookmark_textures: Dictionary = {}
var _item_rows: Control
var _row_nodes: Dictionary = {}
var _detail_page: Control
var _coin_tray: Control
var _quantity_abacus: Control
var _purchase_seal: Control
var _close_tag: Control
var _gold_label: Label
var _total_label: Label
var _qty_label: Label
var _purchase_btn: Button
var _minus_btn: Button
var _plus_btn: Button
var _owned_mark: TextureRect
var _discount_mark: TextureRect
```

- [ ] **Step 3: Add scene-object helpers**

Add these helper methods before `_build()`:

```gdscript
func _add_texture(parent: Node, node_name: String, path: String, pos: Vector2, node_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = TextureManager.try_load(path)
	rect.position = pos
	rect.size = node_size
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(rect)
	return rect


func _make_input_zone(node_name: String, node_size: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.size = node_size
	button.custom_minimum_size = node_size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _set_label_style(label: Label, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
```

- [ ] **Step 4: Replace `_build()` body**

Replace the body of `_build()` from `set_anchors_and_offsets_preset` through creation of the close button with this structure:

```gdscript
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_backdrop = _add_texture(self, "SceneBackdrop", SCENE_TEX, Vector2.ZERO, Vector2(1280, 720))
	_book = _add_texture(self, "BookLayer", BOOK_TEX, Vector2(144, 256), Vector2(992, 416))

	_bookmarks = Control.new()
	_bookmarks.name = "CategoryBookmarks"
	_bookmarks.position = Vector2(160, 228)
	_bookmarks.size = Vector2(520, 90)
	add_child(_bookmarks)
	_add_bookmark("materials", "Materials", Vector2(0, 8), BOOKMARK_MATERIALS_NORMAL, BOOKMARK_MATERIALS_SELECTED)
	_add_bookmark("recipes", "Recipes", Vector2(152, 8), BOOKMARK_RECIPES_NORMAL, BOOKMARK_RECIPES_SELECTED)
	_add_bookmark("abilities", "Abilities", Vector2(304, 8), BOOKMARK_ABILITIES_NORMAL, BOOKMARK_ABILITIES_SELECTED)

	_item_rows = Control.new()
	_item_rows.name = "ItemRows"
	_item_rows.position = Vector2(184, 350)
	_item_rows.size = Vector2(464, 232)
	add_child(_item_rows)

	_detail_page = Control.new()
	_detail_page.name = "DetailPage"
	_detail_page.position = Vector2(706, 320)
	_detail_page.size = Vector2(332, 246)
	add_child(_detail_page)
	_detail_title = _add_label(_detail_page, "Title", Vector2(0, 0), Vector2(332, 40), 22, ThemeColors.AMBER_PRIMARY)
	_detail_desc = _add_label(_detail_page, "Description", Vector2(0, 48), Vector2(332, 56), 15, ThemeColors.TEXT_SUBTITLE)
	_detail_uses = _add_label(_detail_page, "Uses", Vector2(0, 112), Vector2(332, 82), 15, ThemeColors.TEXT_LIGHT)
	_detail_state = _add_label(_detail_page, "State", Vector2(0, 202), Vector2(332, 34), 15, ThemeColors.TEXT_DIM)
	_owned_mark = _add_texture(_detail_page, "OwnedMark", STATUS_OWNED, Vector2(224, 198), Vector2(160, 56))
	_discount_mark = _add_texture(_detail_page, "DiscountMark", STATUS_DISCOUNT, Vector2(214, 158), Vector2(160, 56))

	_coin_tray = Control.new()
	_coin_tray.name = "CoinTray"
	_coin_tray.position = Vector2(164, 628)
	_coin_tray.size = Vector2(360, 64)
	add_child(_coin_tray)
	_gold_label = _add_label(_coin_tray, "GoldLabel", Vector2(0, 8), Vector2(180, 40), 16, ThemeColors.TEXT_LIGHT)
	_total_label = _add_label(_coin_tray, "TotalLabel", Vector2(178, 8), Vector2(180, 40), 16, ThemeColors.AMBER_PRIMARY)

	_quantity_abacus = Control.new()
	_quantity_abacus.name = "QuantityAbacus"
	_quantity_abacus.position = Vector2(530, 624)
	_quantity_abacus.size = Vector2(192, 72)
	add_child(_quantity_abacus)
	_add_texture(_quantity_abacus, "AbacusArt", QUANTITY_ABACUS, Vector2.ZERO, Vector2(192, 72))
	_minus_btn = _make_input_zone("MinusZone", Vector2(56, 56))
	_minus_btn.position = Vector2(0, 8)
	_minus_btn.pressed.connect(func(): set_quantity(_quantity - 1))
	_quantity_abacus.add_child(_minus_btn)
	_qty_label = _add_label(_quantity_abacus, "QuantityLabel", Vector2(64, 12), Vector2(62, 40), 18, ThemeColors.AMBER_PRIMARY)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_btn = _make_input_zone("PlusZone", Vector2(56, 56))
	_plus_btn.position = Vector2(134, 8)
	_plus_btn.pressed.connect(func(): set_quantity(_quantity + 1))
	_quantity_abacus.add_child(_plus_btn)

	_purchase_seal = Control.new()
	_purchase_seal.name = "PurchaseSeal"
	_purchase_seal.position = Vector2(744, 622)
	_purchase_seal.size = Vector2(184, 72)
	add_child(_purchase_seal)
	_add_texture(_purchase_seal, "SealArt", PURCHASE_SEAL_NORMAL, Vector2.ZERO, Vector2(184, 72))
	_purchase_btn = _make_input_zone("PurchaseZone", Vector2(184, 72))
	_purchase_btn.pressed.connect(purchase_selected)
	_purchase_seal.add_child(_purchase_btn)
	var purchase_label := _add_label(_purchase_seal, "PurchaseLabel", Vector2(32, 14), Vector2(122, 40), 16, ThemeColors.TEXT_LIGHT)
	purchase_label.text = "购买"
	purchase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_close_tag = Control.new()
	_close_tag.name = "CloseTag"
	_close_tag.position = Vector2(960, 626)
	_close_tag.size = Vector2(176, 64)
	add_child(_close_tag)
	_add_texture(_close_tag, "TagArt", CLOSE_TAG_NORMAL, Vector2.ZERO, Vector2(176, 64))
	var close_zone := _make_input_zone("CloseZone", Vector2(176, 64))
	close_zone.pressed.connect(close)
	_close_tag.add_child(close_zone)
	var close_label := _add_label(_close_tag, "CloseLabel", Vector2(30, 12), Vector2(116, 38), 16, ThemeColors.TEXT_LIGHT)
	close_label.text = "离开"
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
```

- [ ] **Step 5: Add `_add_bookmark`**

Add after `_build()`:

```gdscript
func _add_bookmark(category: String, title: String, pos: Vector2, normal_path: String, selected_path: String) -> void:
	var art := _add_texture(_bookmarks, title + "Art", normal_path, pos, Vector2(144, 64))
	var zone := _make_input_zone(title + "Zone", Vector2(144, 64))
	zone.position = pos
	zone.pressed.connect(select_category.bind(category))
	_bookmarks.add_child(zone)
	var label := _add_label(_bookmarks, title + "Label", pos + Vector2(20, 10), Vector2(104, 34), 16, ThemeColors.TEXT_LIGHT)
	label.text = CATEGORIES[category]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bookmark_textures[category] = {
		"art": art,
		"normal": normal_path,
		"selected": selected_path,
	}
```

- [ ] **Step 6: Replace `_refresh_items()`**

Replace `_refresh_items()` with:

```gdscript
func _refresh_items() -> void:
	for child in _item_rows.get_children():
		child.queue_free()
	_row_nodes.clear()
	_items_by_category = {
		"materials": _material_keys(),
		"recipes": _recipe_keys(),
		"abilities": _ability_keys(),
	}
	for category in _bookmark_textures.keys():
		var data: Dictionary = _bookmark_textures[category]
		var art := data["art"] as TextureRect
		art.texture = TextureManager.try_load(data["selected"] if category == _active_category else data["normal"])
	var y := 0
	for key in _items_by_category.get(_active_category, []):
		_add_item_row(String(key), y)
		y += 40
```

- [ ] **Step 7: Add `_add_item_row`**

Add after `_refresh_items()`:

```gdscript
func _add_item_row(key: String, y: int) -> void:
	var row := Control.new()
	row.name = "Item_%s" % key
	row.position = Vector2(0, y)
	row.size = Vector2(464, 72)
	_item_rows.add_child(row)
	var art := _add_texture(row, "RowArt", ITEM_ROW_NORMAL, Vector2.ZERO, Vector2(464, 72))
	var zone := _make_input_zone("ClickZone", Vector2(464, 72))
	zone.pressed.connect(select_item.bind(key))
	row.add_child(zone)
	var name_label := _add_label(row, "Name", Vector2(24, 10), Vector2(240, 28), 15, ThemeColors.TEXT_LIGHT)
	name_label.text = _display_name(key)
	var price_label := _add_label(row, "Price", Vector2(306, 10), Vector2(120, 28), 15, ThemeColors.AMBER_PRIMARY)
	price_label.text = str(_price_for(key)) + "金"
	_row_nodes[key] = {"root": row, "art": art}
```

- [ ] **Step 8: Update `_sync()` visual state paths**

Inside `_sync()`, after setting `_purchase_btn.disabled`, add:

```gdscript
	for key in _row_nodes.keys():
		var data: Dictionary = _row_nodes[key]
		var art := data["art"] as TextureRect
		var owned := _active_category != "materials" and _is_owned(String(key))
		if owned:
			art.texture = TextureManager.try_load(ITEM_ROW_DISABLED)
		elif String(key) == _selected_key:
			art.texture = TextureManager.try_load(ITEM_ROW_SELECTED)
		else:
			art.texture = TextureManager.try_load(ITEM_ROW_NORMAL)
	_quantity_abacus.visible = material_mode
	_owned_mark.visible = _active_category != "materials" and _is_owned(_selected_key)
	_discount_mark.visible = _active_category == "materials" and _discount() < 1.0
	var seal_art := _purchase_seal.get_node("SealArt") as TextureRect
	seal_art.texture = TextureManager.try_load(PURCHASE_SEAL_DISABLED if _purchase_btn.disabled else PURCHASE_SEAL_NORMAL)
```

- [ ] **Step 9: Run green Godot test**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_shop_overlay.tscn
```

Expected: PASS.

- [ ] **Step 10: Commit checkpoint**

Run:

```powershell
git status --short
git add scripts/ui/shop_overlay.gd
git commit -m "feat: rebuild shop overlay as integrated stall"
```

Expected: commit contains only `scripts/ui/shop_overlay.gd`.

---

### Task 6: Update DayMap Shop Integration Regression

**Files:**
- Modify: `scripts/test/test_day_map_scrollbars.gd`

- [ ] **Step 1: Update overlay integration expectations**

In `_test_shop_overlay_integration(view)`, replace old node assertions:

```gdscript
_ok(overlay.get_node_or_null("ItemGrid") is GridContainer, "ShopOverlay exposes item grid")
_ok(overlay.get_node_or_null("Detail/Title") is Label, "ShopOverlay exposes selected item detail")
```

with:

```gdscript
_ok(overlay.get_node_or_null("ItemRows") is Control, "ShopOverlay exposes ledger item rows")
_ok(overlay.get_node_or_null("DetailPage/Title") is Label, "ShopOverlay exposes selected item detail on ledger page")
_ok(overlay.get_node_or_null("PurchaseSeal/PurchaseZone") is Button, "ShopOverlay exposes purchase seal input zone")
```

- [ ] **Step 2: Run DayMap integration test**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_day_map_scrollbars.tscn
```

Expected: PASS. If it fails because the scene path is different, locate the test scene with `rg --files scenes/test | rg scrollbars` and run the matching `.tscn`.

- [ ] **Step 3: Commit checkpoint**

Run:

```powershell
git status --short
git add scripts/test/test_day_map_scrollbars.gd
git commit -m "test: update daymap shop overlay integration"
```

Expected: commit contains only `scripts/test/test_day_map_scrollbars.gd`.

---

### Task 7: Full Verification and Visual QA

**Files:**
- No planned source edits unless verification exposes a defect.

- [ ] **Step 1: Run focused Python pipeline tests**

Run:

```powershell
python -m unittest scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_reference_source_is_retained scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_exporter_uses_reference_art scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_assets_are_exact_native_exports scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_assets_have_integrated_scene_materials scripts.test.test_daymap_ui_asset_pipeline.DayMapUiAssetPipelineTest.test_shop_redesign_interaction_assets_are_not_flat_rectangles -v
```

Expected: all selected tests PASS.

- [ ] **Step 2: Run full DayMap UI asset pipeline**

Run:

```powershell
python -m unittest scripts.test.test_daymap_ui_asset_pipeline -v
```

Expected: PASS. If unrelated tests fail because the current worktree has other DayMap UI changes, record the failing test names and do not alter unrelated files.

- [ ] **Step 3: Run shop overlay Godot test**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_shop_overlay.tscn
```

Expected: `[TEST-SHOP-OVERLAY] ALL PASS`.

- [ ] **Step 4: Run DayMap integration Godot test**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_day_map_scrollbars.tscn
```

Expected: PASS.

- [ ] **Step 5: Inspect runtime assets**

Open these images:

```powershell
python - <<'PY'
from PIL import Image
for path in [
    'assets/textures/daymap/shop_redesign/shop_scene.png',
    'assets/textures/daymap/shop_redesign/shop_book.png',
    'assets/textures/daymap/shop_redesign/item_row_selected.png',
    'assets/textures/daymap/shop_redesign/purchase_seal_normal.png',
]:
    im = Image.open(path)
    print(path, im.size, im.mode)
PY
```

Expected: `shop_scene.png` is `1280x720`, assets use nearest-scaled pixel edges, and the selected row/seal/tag do not read as flat rectangles.

- [ ] **Step 6: Final status**

Run:

```powershell
git status --short
```

Expected: only intentional files remain modified or untracked. Report any unrelated pre-existing dirty files separately.

---

## Self-Review

- Spec coverage: the plan covers reference art generation, native-pixel export, anti-procedural asset tests, scene-object overlay structure, preserved purchase behavior, Mira discount, DayMap integration, and visual QA.
- Placeholder scan: the plan contains no unresolved placeholders or unspecified test-writing steps.
- Type consistency: the planned Godot node paths are `CategoryBookmarks/*Zone`, `ItemRows`, `DetailPage/*`, `CoinTray/*`, `QuantityAbacus/*Zone`, `PurchaseSeal/PurchaseZone`, and `CloseTag/CloseZone`; tests and implementation steps use the same names.
