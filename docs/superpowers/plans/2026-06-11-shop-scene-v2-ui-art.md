# Shop Scene V2 UI Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new title-screen-style `shop_scene_v2` art pipeline and wire it into `ShopOverlay` without changing shop behavior.

**Architecture:** Add an independent native-pixel asset pipeline under `assets/source/daymap/shop_scene_v2/` and `assets/textures/daymap/shop_scene_v2/`. Generate and approve a full-screen shop reference first, normalize it to a `320x180` native source, crop fixed manifest-driven UI carriers, export all runtime textures by exact `4x` nearest-neighbor scaling, then switch `ShopOverlay` to the v2 art while preserving legacy `shop_brush` assets and behavior contracts.

**Tech Stack:** Godot 4.6.3, GDScript, Python 3, Pillow, `unittest`, built-in image generation, exact nearest-neighbor PNG export.

---

## File Map

- Create `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_master_reference.png`: approved retained full-screen shop reference.
- Create `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_reference_prompt.md`: exact accepted prompt and review notes.
- Create `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_manifest.json`: fixed native crop boxes, runtime placement, and safe areas.
- Create `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_native_preview.png`: `320x180` preview for approval.
- Create `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_runtime_preview.png`: `1280x720` nearest preview for approval.
- Create generated files under `assets/source/daymap/shop_scene_v2/*.png`: native source textures.
- Create generated files under `assets/textures/daymap/shop_scene_v2/*.png`: runtime textures.
- Create `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`: Python contract tests for the new asset pipeline.
- Create `scripts/tools/prepare_daymap_shop_scene_v2_sources.py`: reference-to-native prep script.
- Create `scripts/tools/export_daymap_shop_scene_v2_assets.py`: native-to-runtime exporter.
- Modify `scripts/ui/shop_overlay.gd`: add v2 texture constants and build v2 visual tree while keeping behavior.
- Modify `scripts/test/test_shop_overlay.gd`: update overlay structure and behavior tests for v2.
- Modify `scripts/test/test_day_map_scrollbars.gd`: update DayMap shop integration assertions to the currently exposed shop node names.

## Native Layout Contract

The implementation uses these fixed native coordinates. Runtime coordinates are always `native * 4`.

```text
Full canvas:             320x180 -> 1280x720
List panel:              (14, 28, 204, 127)  size 190x99  -> pos (56,112), size 760x396
Detail panel:            (216, 28, 306, 127) size 90x99   -> pos (864,112), size 360x396
Checkout bar:            (30, 142, 290, 174) size 260x32  -> pos (120,568), size 1040x128
Materials tab:           (35, 14, 83, 30)    size 48x16   -> pos (140,56), size 192x64
Recipes tab:             (88, 14, 136, 30)   size 48x16   -> pos (352,56), size 192x64
Abilities tab:           (141, 14, 189, 30)  size 48x16   -> pos (564,56), size 192x64
Row source:              (29, 39, 174, 55)   size 145x16  -> size 580x64
Quantity minus:          (104, 149, 122, 167) size 18x18 -> size 72x72
Quantity body:           (122, 149, 166, 167) size 44x18 -> size 176x72
Quantity plus:           (166, 149, 184, 167) size 18x18 -> size 72x72
Purchase button:         (184, 149, 248, 167) size 64x18 -> size 256x72
Close button:            (254, 149, 272, 167) size 18x18 -> size 72x72
Owned status mark:       derived from purchase button, size 14x12 -> size 56x48
Discount status mark:    derived from purchase button, size 14x13 -> size 56x52
```

Text safe areas in native coordinates:

```text
List safe area:       (24, 36, 187, 120)
Detail safe area:     (226, 38, 296, 118)
Checkout safe area:   (43, 149, 278, 167)
Row text area:        (37, 43, 132, 52)
Row price area:       (136, 43, 168, 52)
```

## Task 1: Establish Baseline

**Files:**
- Read: `scripts/test/test_shop_overlay.gd`
- Read: `scripts/test/test_day_map_scrollbars.gd`
- Read: `scripts/test/test_daymap_shop_brush_asset_pipeline.py`
- Read: `scripts/ui/shop_overlay.gd`

- [ ] **Step 1: Confirm branch and dirty scope**

Run:

```powershell
git branch --show-current
git status --short
```

Expected:

```text
feat/shop-scene-v2-ui-art
```

The status may show unrelated untracked local files. Do not stage, delete, or modify unrelated untracked files.

- [ ] **Step 2: Run current shop overlay baseline**

Run:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' 'res://scenes/test/test_shop_overlay.tscn'
```

Expected: output contains `[TEST-SHOP-OVERLAY] ALL PASS`. If it fails before edits, record the failure in the task notes and keep it separate from new v2 work.

- [ ] **Step 3: Run current shop brush asset baseline**

Run:

```powershell
python -m unittest scripts.test.test_daymap_shop_brush_asset_pipeline -v
```

Expected: all `DayMapShopBrushAssetPipelineTest` tests pass.

## Task 2: Add Failing Shop Scene V2 Asset Pipeline Tests

**Files:**
- Create: `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`
- Test: `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`

- [ ] **Step 1: Create the asset pipeline test**

Create `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py` with this content:

```python
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_scene_v2"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_scene_v2"
PREPARE_SCRIPT = ROOT / "scripts" / "tools" / "prepare_daymap_shop_scene_v2_sources.py"
EXPORT_SCRIPT = ROOT / "scripts" / "tools" / "export_daymap_shop_scene_v2_assets.py"
SCALE = 4

EXPECTED_ASSETS = {
    "shop_scene_bg": ((320, 180), (1280, 720), False),
    "shop_scene_list_panel": ((190, 99), (760, 396), False),
    "shop_scene_detail_panel": ((90, 99), (360, 396), False),
    "shop_scene_checkout": ((260, 32), (1040, 128), False),
    "shop_scene_tab_materials_normal": ((48, 16), (192, 64), True),
    "shop_scene_tab_materials_selected": ((48, 16), (192, 64), True),
    "shop_scene_tab_recipes_normal": ((48, 16), (192, 64), True),
    "shop_scene_tab_recipes_selected": ((48, 16), (192, 64), True),
    "shop_scene_tab_abilities_normal": ((48, 16), (192, 64), True),
    "shop_scene_tab_abilities_selected": ((48, 16), (192, 64), True),
    "shop_scene_row_normal": ((145, 16), (580, 64), True),
    "shop_scene_row_hover": ((145, 16), (580, 64), True),
    "shop_scene_row_selected": ((145, 16), (580, 64), True),
    "shop_scene_row_disabled": ((145, 16), (580, 64), True),
    "shop_scene_button_normal": ((64, 18), (256, 72), True),
    "shop_scene_button_hover": ((64, 18), (256, 72), True),
    "shop_scene_button_pressed": ((64, 18), (256, 72), True),
    "shop_scene_button_disabled": ((64, 18), (256, 72), True),
    "shop_scene_quantity_minus": ((18, 18), (72, 72), True),
    "shop_scene_quantity_body": ((44, 18), (176, 72), True),
    "shop_scene_quantity_plus": ((18, 18), (72, 72), True),
    "shop_scene_close_normal": ((18, 18), (72, 72), True),
    "shop_scene_close_hover": ((18, 18), (72, 72), True),
    "shop_scene_close_pressed": ((18, 18), (72, 72), True),
    "shop_scene_status_owned": ((14, 12), (56, 48), True),
    "shop_scene_status_discount": ((14, 13), (56, 52), True),
}

SAFE_AREAS = {
    "shop_scene_list_panel": (10, 8, 173, 92),
    "shop_scene_detail_panel": (10, 10, 80, 90),
    "shop_scene_checkout": (13, 7, 248, 25),
    "shop_scene_row_normal": (8, 4, 108, 13),
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def exact_runtime_export(
    test_case: unittest.TestCase,
    name: str,
    native_size: tuple[int, int],
    runtime_size: tuple[int, int],
) -> Image.Image:
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    test_case.assertTrue(native_path.exists(), f"{native_path}: missing native source")
    test_case.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
    native = load_rgba(native_path)
    runtime = load_rgba(runtime_path)
    test_case.assertEqual(native.size, native_size, f"{name}: wrong native size")
    test_case.assertEqual(runtime.size, runtime_size, f"{name}: wrong runtime size")
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: not exact nearest export")
    return native


def dark_teal_readable_ratio(image: Image.Image) -> float:
    visible = 0
    readable = 0
    for red, green, blue, alpha in image.getdata():
        if alpha < 180:
            continue
        visible += 1
        if red <= 95 and 18 <= green <= 120 and 18 <= blue <= 125:
            readable += 1
    return readable / max(1, visible)


def amber_ratio(image: Image.Image) -> float:
    visible = 0
    amber = 0
    for red, green, blue, alpha in image.getdata():
        if alpha <= 0:
            continue
        visible += 1
        if red >= 150 and 45 <= green <= 180 and blue <= 115 and red >= blue * 1.25:
            amber += 1
    return amber / max(1, visible)


def magenta_fringe_ratio(image: Image.Image) -> float:
    visible = 0
    fringe = 0
    for red, green, blue, alpha in image.getdata():
        if alpha <= 0:
            continue
        visible += 1
        if red >= 65 and blue >= 65 and green <= 90 and red > green * 1.4 and blue > green * 1.4:
            fringe += 1
    return fringe / max(1, visible)


class DayMapShopSceneV2AssetPipelineTest(unittest.TestCase):
    def test_reference_art_and_manifest_are_retained(self) -> None:
        required = [
            "shop_scene_v2_master_reference.png",
            "shop_scene_v2_reference_prompt.md",
            "shop_scene_v2_manifest.json",
            "shop_scene_v2_native_preview.png",
            "shop_scene_v2_runtime_preview.png",
        ]
        for filename in required:
            path = REFERENCE / filename
            self.assertTrue(path.exists(), f"{path}: missing retained reference artifact")
            self.assertGreater(path.stat().st_size, 0, f"{path}: retained reference artifact is empty")

    def test_scripts_exist_and_do_not_use_abacus_language(self) -> None:
        for script in [PREPARE_SCRIPT, EXPORT_SCRIPT]:
            self.assertTrue(script.exists(), f"{script}: missing pipeline script")
            text = script.read_text(encoding="utf-8")
            self.assertNotIn("abacus", text.lower(), f"{script.name}: abacus language must not return")
            self.assertNotIn("quantity_abacus", text, f"{script.name}: old quantity_abacus naming must not return")

    def test_assets_are_exact_native_exports(self) -> None:
        for name, (native_size, runtime_size, _transparent) in EXPECTED_ASSETS.items():
            with self.subTest(name=name):
                exact_runtime_export(self, name, native_size, runtime_size)

    def test_transparent_assets_have_alpha_and_visible_pixels(self) -> None:
        for name, (native_size, runtime_size, transparent) in EXPECTED_ASSETS.items():
            if not transparent:
                continue
            with self.subTest(name=name):
                native = exact_runtime_export(self, name, native_size, runtime_size)
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, f"{name}: needs transparent pixels")
                self.assertGreater(alpha_max, 0, f"{name}: transparent layer is empty")
                self.assertGreater(visible_pixel_count(native), 12, f"{name}: too sparse")
                self.assertLessEqual(magenta_fringe_ratio(native), 0.002, f"{name}: magenta extraction fringe remains")

    def test_opaque_scene_surfaces_have_readable_text_safe_areas(self) -> None:
        for name, safe_box in SAFE_AREAS.items():
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                safe_area = native.crop(safe_box).convert("RGBA")
                self.assertGreaterEqual(
                    dark_teal_readable_ratio(safe_area),
                    0.46,
                    f"{name}: text safe area is too noisy or too bright",
                )

    def test_background_keeps_title_style_palette(self) -> None:
        native = load_rgba(SOURCE / "shop_scene_bg_native.png")
        pixels = list(native.getdata())
        dark = sum(1 for red, green, blue, alpha in pixels if alpha >= 250 and max(red, green, blue) <= 64)
        teal = sum(
            1
            for red, green, blue, alpha in pixels
            if alpha >= 250 and blue >= 30 and green >= 26 and blue >= red * 0.95
        )
        warm = sum(
            1
            for red, green, blue, alpha in pixels
            if alpha >= 250 and red >= 110 and green >= 40 and red >= blue * 1.35
        )
        self.assertGreaterEqual(dark, 18000, "shop background needs enough dark dungeon mass")
        self.assertGreaterEqual(teal, 2500, "shop background needs visible dark teal depth")
        self.assertGreaterEqual(warm, 120, "shop background needs sparse amber accents")
        self.assertLessEqual(warm, 9500, "shop background amber accents are too dominant")

    def test_state_assets_are_distinct(self) -> None:
        groups = [
            ["shop_scene_row_normal", "shop_scene_row_hover", "shop_scene_row_selected", "shop_scene_row_disabled"],
            ["shop_scene_button_normal", "shop_scene_button_hover", "shop_scene_button_pressed", "shop_scene_button_disabled"],
            ["shop_scene_close_normal", "shop_scene_close_hover", "shop_scene_close_pressed"],
            ["shop_scene_tab_materials_normal", "shop_scene_tab_materials_selected"],
        ]
        for group in groups:
            seen: set[bytes] = set()
            for name in group:
                with self.subTest(name=name):
                    data = load_rgba(SOURCE / f"{name}_native.png").tobytes()
                    self.assertNotIn(data, seen, f"{name}: duplicates another state")
                    seen.add(data)

    def test_amber_is_sparse_except_emphasis_states(self) -> None:
        exempt = {
            "shop_scene_row_selected",
            "shop_scene_button_hover",
            "shop_scene_button_pressed",
            "shop_scene_close_hover",
            "shop_scene_close_pressed",
            "shop_scene_quantity_minus",
            "shop_scene_quantity_plus",
            "shop_scene_status_owned",
            "shop_scene_status_discount",
        }
        for name in EXPECTED_ASSETS:
            if name in exempt:
                continue
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                self.assertLessEqual(amber_ratio(native), 0.18, f"{name}: amber overused")


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Run the new test and verify RED**

Run:

```powershell
python -m unittest scripts.test.test_daymap_shop_scene_v2_asset_pipeline -v
```

Expected: FAIL because `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_master_reference.png` and the new pipeline scripts do not exist yet.

- [ ] **Step 3: Commit the failing asset test**

Run:

```powershell
git add scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py
git commit -m "test: add shop scene v2 asset pipeline contract"
```

Expected: commit contains only `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`.

## Task 3: Generate And Approve The Shop Scene V2 Reference

**Files:**
- Create: `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_master_reference.png`
- Create: `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_reference_prompt.md`
- Create: `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_native_preview.png`
- Create: `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_runtime_preview.png`

- [ ] **Step 1: Generate one candidate with the built-in image generation tool**

Use the built-in `image_gen` tool with this prompt:

```text
Use case: stylized-concept.
Asset type: project-bound Godot 1280x720 shop UI reference, later normalized to a 320x180 native pixel grid and nearest-neighbor scaled 4x.
Reference target: match the existing title-screen visual language: dark teal dungeon tavern palette, broad blocky silhouettes, rough ink-like pixel clusters, sparse amber candle and coin accents, low-density chunky pixel composition.
Primary request: Create a full-screen in-world shop UI scene for a dungeon tavern management game. The composition must be readable after downscaling to 320x180.
Fixed native layout to respect after 320x180 normalization: left item board at x14 y28 w190 h99, right detail board at x216 y28 w90 h99, bottom checkout board at x30 y142 w260 h32, three top cloth tabs at x35/y14, x88/y14, x141/y14 each about 48x16.
Visual carriers: five clean blank horizontal item rows inside the left board, one clean blank detail writing surface inside the right board, bottom coin/status plaque, simple minus-count-plus quantity plaque, wax or brass purchase button, small hanging close tag.
Merchant presence: weak background presence only. Show a withdrawn hooded shopkeeper silhouette or partial hands behind the counter, low contrast, mostly in shadow, not centered, not bright, not overlapping text boards.
Scene details: quiet underground tavern market stall, dark stone arch blocks, old wood counter, shelves in shadow, rope, coins, one small lantern, dusty air, warm amber pin lights.
Style: chunky native-pixel concept art with hard nearest-neighbor-feeling edges, simple flat masses, restrained detail, no smooth glossy rendering, no anime, no cute character, no modern dashboard UI.
Text rule: no readable text, no numbers, no letters, no logo, no watermark. Plus and minus marks may appear only as simple block symbols.
Strict avoid: abacus, beads, rollers, counting rods, tilted readable panels, open-book perspective, bright yellow parchment, dense tiny inventory clutter, large portrait, floating cards, modern app panels, watermark, signature.
```

Expected: the image tool returns a generated PNG path under `C:\Users\zzc45\.codex\generated_images\...`.

- [ ] **Step 2: Copy the newest generated candidate into the workspace**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'assets/source/daymap/shop_scene_v2/reference'
$latest = Get-ChildItem -Path 'C:\Users\zzc45\.codex\generated_images' -Recurse -Filter '*.png' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($latest -eq $null) { throw 'No generated PNG found under C:\Users\zzc45\.codex\generated_images' }
Copy-Item -LiteralPath $latest.FullName -Destination 'assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_master_reference.png' -Force
Write-Output $latest.FullName
```

Expected: `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_master_reference.png` exists.

- [ ] **Step 3: Save the accepted prompt and review criteria**

Create `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_reference_prompt.md` with:

```markdown
# Shop Scene V2 Reference Prompt

## Accepted Prompt

Use case: stylized-concept.
Asset type: project-bound Godot 1280x720 shop UI reference, later normalized to a 320x180 native pixel grid and nearest-neighbor scaled 4x.
Reference target: match the existing title-screen visual language: dark teal dungeon tavern palette, broad blocky silhouettes, rough ink-like pixel clusters, sparse amber candle and coin accents, low-density chunky pixel composition.
Primary request: Create a full-screen in-world shop UI scene for a dungeon tavern management game. The composition must be readable after downscaling to 320x180.
Fixed native layout to respect after 320x180 normalization: left item board at x14 y28 w190 h99, right detail board at x216 y28 w90 h99, bottom checkout board at x30 y142 w260 h32, three top cloth tabs at x35/y14, x88/y14, x141/y14 each about 48x16.
Visual carriers: five clean blank horizontal item rows inside the left board, one clean blank detail writing surface inside the right board, bottom coin/status plaque, simple minus-count-plus quantity plaque, wax or brass purchase button, small hanging close tag.
Merchant presence: weak background presence only. Show a withdrawn hooded shopkeeper silhouette or partial hands behind the counter, low contrast, mostly in shadow, not centered, not bright, not overlapping text boards.
Scene details: quiet underground tavern market stall, dark stone arch blocks, old wood counter, shelves in shadow, rope, coins, one small lantern, dusty air, warm amber pin lights.
Style: chunky native-pixel concept art with hard nearest-neighbor-feeling edges, simple flat masses, restrained detail, no smooth glossy rendering, no anime, no cute character, no modern dashboard UI.
Text rule: no readable text, no numbers, no letters, no logo, no watermark. Plus and minus marks may appear only as simple block symbols.
Strict avoid: abacus, beads, rollers, counting rods, tilted readable panels, open-book perspective, bright yellow parchment, dense tiny inventory clutter, large portrait, floating cards, modern app panels, watermark, signature.

## Review Decision

Approved for native-pixel pipeline only. This reference is retained source art and must not be loaded directly by Godot runtime scenes.

The approved image satisfies:

- Left item board, right detail board, top tabs, and bottom checkout board are readable after `320x180` normalization.
- The merchant is a weak background presence and does not overlap text safe zones.
- The quantity control does not read as an abacus, beads, rollers, or counting rods.
- The palette is dark teal with sparse amber accents.
- No readable generated text, numbers, logos, or watermarks are present.
```

Expected: prompt file exists and documents the accepted image.

- [ ] **Step 4: Create native and runtime approval previews**

Run:

```powershell
@'
from pathlib import Path
from PIL import Image, ImageOps

root = Path(r"D:\game\tavern-manager")
reference = root / "assets" / "source" / "daymap" / "shop_scene_v2" / "reference"
source = reference / "shop_scene_v2_master_reference.png"
native_path = reference / "shop_scene_v2_native_preview.png"
runtime_path = reference / "shop_scene_v2_runtime_preview.png"
image = Image.open(source).convert("RGBA")
native = ImageOps.fit(image, (320, 180), method=Image.Resampling.NEAREST, centering=(0.5, 0.5))
native.save(native_path)
native.resize((1280, 720), Image.Resampling.NEAREST).save(runtime_path)
print(native_path)
print(runtime_path)
'@ | python -
```

Expected: `shop_scene_v2_native_preview.png` and `shop_scene_v2_runtime_preview.png` exist.

- [ ] **Step 5: Inspect the runtime preview**

Open or view:

```text
assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_runtime_preview.png
```

Pass criteria:

- The layout matches the native layout contract closely enough for fixed crop boxes.
- Text boards are front-facing and clean.
- The weak merchant presence stays outside the list, detail, and checkout safe areas.
- The palette matches the title style: dark teal mass, sparse amber accents.
- There is no abacus, no readable generated text, and no watermark.

If the candidate fails, generate a new candidate with the same prompt plus one sentence naming the failed criterion. Replace only `shop_scene_v2_master_reference.png` and regenerate previews before repeating this inspection.

- [ ] **Step 6: Commit approved retained reference**

Run:

```powershell
git add assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_master_reference.png assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_reference_prompt.md assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_native_preview.png assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_runtime_preview.png
git commit -m "art: add shop scene v2 approved reference"
```

Expected: commit contains only retained reference artifacts for `shop_scene_v2`.

## Task 4: Add Fixed Manifest

**Files:**
- Create: `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_manifest.json`
- Test: `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`

- [ ] **Step 1: Create the crop manifest**

Create `assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_manifest.json` with:

```json
{
  "native_size": [320, 180],
  "runtime_scale": 4,
  "full_layers": {
    "shop_scene_bg": {
      "box": [0, 0, 320, 180],
      "safe_area": [0, 0, 320, 180],
      "transparent": false
    },
    "shop_scene_list_panel": {
      "box": [14, 28, 204, 127],
      "safe_area": [24, 36, 187, 120],
      "transparent": false
    },
    "shop_scene_detail_panel": {
      "box": [216, 28, 306, 127],
      "safe_area": [226, 38, 296, 118],
      "transparent": false
    },
    "shop_scene_checkout": {
      "box": [30, 142, 290, 174],
      "safe_area": [43, 149, 278, 167],
      "transparent": false
    }
  },
  "component_layers": {
    "shop_scene_tab_materials_normal": {"box": [35, 14, 83, 30], "transparent": true},
    "shop_scene_tab_recipes_normal": {"box": [88, 14, 136, 30], "transparent": true},
    "shop_scene_tab_abilities_normal": {"box": [141, 14, 189, 30], "transparent": true},
    "shop_scene_row_normal": {"box": [29, 39, 174, 55], "transparent": true},
    "shop_scene_button_normal": {"box": [184, 149, 248, 167], "transparent": true},
    "shop_scene_quantity_minus": {"box": [104, 149, 122, 167], "transparent": true},
    "shop_scene_quantity_body": {"box": [122, 149, 166, 167], "transparent": true},
    "shop_scene_quantity_plus": {"box": [166, 149, 184, 167], "transparent": true},
    "shop_scene_close_normal": {"box": [254, 149, 272, 167], "transparent": true}
  }
}
```

Expected: manifest has fixed rectangles and no auto-detection instructions.

- [ ] **Step 2: Commit the manifest**

Run:

```powershell
git add assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_manifest.json
git commit -m "art: add shop scene v2 crop manifest"
```

Expected: commit contains only the manifest.

## Task 5: Implement Native Source Preparation

**Files:**
- Create: `scripts/tools/prepare_daymap_shop_scene_v2_sources.py`
- Create generated: `assets/source/daymap/shop_scene_v2/*_native.png`
- Test: `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`

- [ ] **Step 1: Create the prepare script**

Create `scripts/tools/prepare_daymap_shop_scene_v2_sources.py` with this content:

```python
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_scene_v2"
REFERENCE = SOURCE / "reference"
MASTER_REFERENCE = REFERENCE / "shop_scene_v2_master_reference.png"
MANIFEST_PATH = REFERENCE / "shop_scene_v2_manifest.json"
NATIVE_SIZE = (320, 180)


def load_manifest() -> dict:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Missing shop scene v2 manifest: {MANIFEST_PATH}")
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def load_master_native() -> Image.Image:
    if not MASTER_REFERENCE.exists():
        raise FileNotFoundError(f"Missing shop scene v2 master reference: {MASTER_REFERENCE}")
    with Image.open(MASTER_REFERENCE) as image:
        native = ImageOps.fit(
            image.convert("RGBA"),
            NATIVE_SIZE,
            method=Image.Resampling.NEAREST,
            centering=(0.5, 0.5),
        )
    native = ImageEnhance.Brightness(native).enhance(0.82)
    native = ImageEnhance.Contrast(native).enhance(1.06)
    native = ImageEnhance.Color(native).enhance(0.92)
    return native


def crop_layer(native: Image.Image, box: list[int], transparent: bool) -> Image.Image:
    layer = native.crop(tuple(box)).convert("RGBA")
    if transparent:
        layer = rectangular_alpha_from_edges(layer)
    return layer


def rectangular_alpha_from_edges(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    mask = Image.new("L", rgba.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((1, 1, width - 2, height - 2), fill=255)
    rgba.putalpha(mask)
    return rgba


def tint_visible(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    rgba = image.convert("RGBA")
    overlay = Image.new("RGBA", rgba.size, color + (0,))
    alpha = rgba.getchannel("A").point(lambda value: int(value * strength))
    overlay.putalpha(alpha)
    return Image.alpha_composite(rgba, overlay)


def darken_visible(image: Image.Image, factor: float) -> Image.Image:
    rgba = image.convert("RGBA")
    rgb = ImageEnhance.Brightness(rgba.convert("RGB")).enhance(factor).convert("RGBA")
    rgb.putalpha(rgba.getchannel("A"))
    return rgb


def add_amber_pixels(image: Image.Image, mode: str) -> Image.Image:
    rgba = image.convert("RGBA")
    draw = ImageDraw.Draw(rgba)
    width, height = rgba.size
    if mode == "hover":
        draw.line((3, height - 3, width - 4, height - 3), fill=(209, 132, 35, 220), width=1)
    elif mode == "selected":
        draw.rectangle((2, 2, width - 3, height - 3), outline=(218, 142, 36, 235), width=1)
        draw.line((6, height - 4, width - 7, height - 4), fill=(245, 176, 57, 220), width=1)
    elif mode == "pressed":
        draw.rectangle((2, 2, width - 3, height - 3), outline=(162, 85, 28, 240), width=1)
    elif mode == "status":
        draw.rectangle((2, 2, width - 3, height - 3), outline=(232, 153, 43, 235), width=1)
    return rgba


def make_status(size: tuple[int, int], kind: str) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if kind == "owned":
        draw.rectangle((1, 2, size[0] - 2, size[1] - 3), fill=(20, 55, 58, 210), outline=(218, 142, 36, 235))
        draw.line((3, size[1] // 2, size[0] - 4, size[1] // 2), fill=(236, 170, 62, 240), width=1)
    else:
        draw.polygon(
            [(1, size[1] - 3), (size[0] // 2, 1), (size[0] - 2, size[1] - 3)],
            fill=(31, 72, 71, 220),
            outline=(218, 142, 36, 235),
        )
        draw.line((4, size[1] - 4, size[0] - 5, size[1] - 4), fill=(236, 170, 62, 240), width=1)
    return image


def save_native(name: str, image: Image.Image) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    path = SOURCE / f"{name}_native.png"
    image.save(path)
    print(path)


def validate_safe_areas(native: Image.Image, manifest: dict) -> None:
    forbidden_boxes = [
        (24, 36, 187, 120),
        (226, 38, 296, 118),
        (43, 149, 278, 167),
    ]
    for box in forbidden_boxes:
        crop = native.crop(box).convert("RGBA")
        bright_pixels = 0
        for red, green, blue, alpha in crop.getdata():
            if alpha >= 220 and max(red, green, blue) >= 185:
                bright_pixels += 1
        if bright_pixels > crop.width * crop.height * 0.18:
            raise ValueError(f"Shop scene v2 safe area is too bright/noisy: {box}")


def main() -> None:
    manifest = load_manifest()
    native = load_master_native()
    validate_safe_areas(native, manifest)

    for name, spec in manifest["full_layers"].items():
        save_native(name, crop_layer(native, spec["box"], bool(spec["transparent"])))

    components: dict[str, Image.Image] = {}
    for name, spec in manifest["component_layers"].items():
        components[name] = crop_layer(native, spec["box"], bool(spec["transparent"]))
        save_native(name, components[name])

    for base in ["materials", "recipes", "abilities"]:
        normal_name = f"shop_scene_tab_{base}_normal"
        selected_name = f"shop_scene_tab_{base}_selected"
        save_native(selected_name, add_amber_pixels(tint_visible(components[normal_name], (38, 84, 82), 0.18), "selected"))

    row = components["shop_scene_row_normal"]
    save_native("shop_scene_row_hover", add_amber_pixels(tint_visible(row, (48, 92, 90), 0.18), "hover"))
    save_native("shop_scene_row_selected", add_amber_pixels(tint_visible(row, (70, 92, 70), 0.26), "selected"))
    save_native("shop_scene_row_disabled", darken_visible(row, 0.55))

    button = components["shop_scene_button_normal"]
    save_native("shop_scene_button_hover", add_amber_pixels(tint_visible(button, (65, 90, 72), 0.18), "hover"))
    save_native("shop_scene_button_pressed", add_amber_pixels(darken_visible(button, 0.70), "pressed"))
    save_native("shop_scene_button_disabled", darken_visible(button, 0.48))

    close = components["shop_scene_close_normal"]
    save_native("shop_scene_close_hover", add_amber_pixels(tint_visible(close, (65, 90, 72), 0.18), "hover"))
    save_native("shop_scene_close_pressed", add_amber_pixels(darken_visible(close, 0.70), "pressed"))

    save_native("shop_scene_status_owned", make_status((14, 12), "owned"))
    save_native("shop_scene_status_discount", make_status((14, 13), "discount"))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the prepare script**

Run:

```powershell
python scripts/tools/prepare_daymap_shop_scene_v2_sources.py
```

Expected: native PNG files are created under `assets/source/daymap/shop_scene_v2/`.

- [ ] **Step 3: Run the asset test and verify the expected partial failure**

Run:

```powershell
python -m unittest scripts.test.test_daymap_shop_scene_v2_asset_pipeline -v
```

Expected: reference and native-source checks move forward; runtime export checks still fail because `assets/textures/daymap/shop_scene_v2/*.png` do not exist yet.

- [ ] **Step 4: Commit native prep script and native outputs**

Run:

```powershell
git add scripts/tools/prepare_daymap_shop_scene_v2_sources.py assets/source/daymap/shop_scene_v2
git commit -m "art: prepare shop scene v2 native sources"
```

Expected: commit contains the prepare script, retained manifest/reference files already committed earlier remain unchanged, and native outputs are tracked.

## Task 6: Implement Runtime Exporter

**Files:**
- Create: `scripts/tools/export_daymap_shop_scene_v2_assets.py`
- Create generated: `assets/textures/daymap/shop_scene_v2/*.png`
- Test: `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`

- [ ] **Step 1: Create the exporter script**

Create `scripts/tools/export_daymap_shop_scene_v2_assets.py` with this content:

```python
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_scene_v2"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_scene_v2"
SCALE = 4

EXPECTED_ASSETS = {
    "shop_scene_bg": ((320, 180), False),
    "shop_scene_list_panel": ((190, 99), False),
    "shop_scene_detail_panel": ((90, 99), False),
    "shop_scene_checkout": ((260, 32), False),
    "shop_scene_tab_materials_normal": ((48, 16), True),
    "shop_scene_tab_materials_selected": ((48, 16), True),
    "shop_scene_tab_recipes_normal": ((48, 16), True),
    "shop_scene_tab_recipes_selected": ((48, 16), True),
    "shop_scene_tab_abilities_normal": ((48, 16), True),
    "shop_scene_tab_abilities_selected": ((48, 16), True),
    "shop_scene_row_normal": ((145, 16), True),
    "shop_scene_row_hover": ((145, 16), True),
    "shop_scene_row_selected": ((145, 16), True),
    "shop_scene_row_disabled": ((145, 16), True),
    "shop_scene_button_normal": ((64, 18), True),
    "shop_scene_button_hover": ((64, 18), True),
    "shop_scene_button_pressed": ((64, 18), True),
    "shop_scene_button_disabled": ((64, 18), True),
    "shop_scene_quantity_minus": ((18, 18), True),
    "shop_scene_quantity_body": ((44, 18), True),
    "shop_scene_quantity_plus": ((18, 18), True),
    "shop_scene_close_normal": ((18, 18), True),
    "shop_scene_close_hover": ((18, 18), True),
    "shop_scene_close_pressed": ((18, 18), True),
    "shop_scene_status_owned": ((14, 12), True),
    "shop_scene_status_discount": ((14, 13), True),
}


def load_native(name: str) -> Image.Image:
    path = SOURCE / f"{name}_native.png"
    if not path.exists():
        raise FileNotFoundError(f"Missing shop scene v2 native source: {path}")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def validate_native(name: str, image: Image.Image, size: tuple[int, int], transparent: bool) -> None:
    if image.size != size:
        raise ValueError(f"{name}: expected native size {size}, got {image.size}")
    alpha_min, alpha_max = image.getchannel("A").getextrema()
    if transparent:
        if alpha_min != 0 or alpha_max == 0:
            raise ValueError(f"{name}: transparent asset needs both transparent and visible pixels")
    else:
        if alpha_min != 255 or alpha_max != 255:
            raise ValueError(f"{name}: opaque asset must have full alpha")


def nearest_export(native: Image.Image) -> Image.Image:
    return native.resize((native.width * SCALE, native.height * SCALE), Image.Resampling.NEAREST)


def main() -> None:
    outputs: dict[str, Image.Image] = {}
    for name, (size, transparent) in EXPECTED_ASSETS.items():
        native = load_native(name)
        validate_native(name, native, size, transparent)
        runtime = nearest_export(native)
        expected = native.resize(runtime.size, Image.Resampling.NEAREST)
        if runtime.tobytes() != expected.tobytes():
            raise RuntimeError(f"{name}: runtime is not exact nearest export")
        outputs[name] = runtime

    RUNTIME.mkdir(parents=True, exist_ok=True)
    for name, runtime in outputs.items():
        path = RUNTIME / f"{name}.png"
        runtime.save(path)
        print(f"{name}: {runtime.size}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the exporter**

Run:

```powershell
python scripts/tools/export_daymap_shop_scene_v2_assets.py
```

Expected: runtime textures are created under `assets/textures/daymap/shop_scene_v2/`.

- [ ] **Step 3: Run the asset test and verify GREEN**

Run:

```powershell
python -m unittest scripts.test.test_daymap_shop_scene_v2_asset_pipeline -v
```

Expected: all `DayMapShopSceneV2AssetPipelineTest` tests pass.

- [ ] **Step 4: Commit exporter and runtime textures**

Run:

```powershell
git add scripts/tools/export_daymap_shop_scene_v2_assets.py assets/textures/daymap/shop_scene_v2
git commit -m "art: export shop scene v2 runtime textures"
```

Expected: commit contains exporter and runtime PNG files only.

## Task 7: Add Failing ShopOverlay V2 Structure Tests

**Files:**
- Modify: `scripts/test/test_shop_overlay.gd`
- Test: `scenes/test/test_shop_overlay.tscn`

- [ ] **Step 1: Update shop overlay test helpers and calls**

In `scripts/test/test_shop_overlay.gd`, replace these calls in `_ready()`:

```gdscript
	_test_core_layout(overlay)
	_test_nearest_filtering(overlay)
	_test_shop_brush_texture_paths(overlay)
```

with:

```gdscript
	_test_core_layout(overlay)
	_test_nearest_filtering(overlay)
	_test_shop_scene_v2_texture_paths(overlay)
	_test_shop_scene_v2_text_safe_layout(overlay)
```

- [ ] **Step 2: Replace `_test_core_layout` and `_test_brush_layout_sizes`**

Replace both functions with:

```gdscript
func _test_core_layout(overlay) -> void:
	_ok(overlay.visible, "overlay is visible after open")
	_ok(overlay.get_node_or_null("ShopBackdrop") is TextureRect, "overlay has shop scene v2 backdrop")
	_ok(overlay.get_node_or_null("ShopStage") == null, "old dark shop stage is removed")
	_ok(overlay.get_node_or_null("MainShopPanel") is Control, "overlay has main shop panel root")
	_ok(overlay.get_node_or_null("MainShopPanel/ListPanel") is TextureRect, "overlay has v2 list panel art")
	_ok(overlay.get_node_or_null("MainShopPanel/DetailPanelArt") is TextureRect, "overlay has v2 detail panel art")
	_ok(overlay.get_node_or_null("MainBrushPanel") is Control, "legacy MainBrushPanel compatibility root remains")
	_ok(overlay.get_node_or_null("CategoryTabs/MaterialsZone") is Button, "materials category zone exists")
	_ok(overlay.get_node_or_null("CategoryTabs/RecipesZone") is Button, "recipes category zone exists")
	_ok(overlay.get_node_or_null("CategoryTabs/AbilitiesZone") is Button, "abilities category zone exists")
	_ok(overlay.get_node_or_null("ItemList") is Control, "item list exists")
	_ok(overlay.get_node_or_null("DetailPanel/Title") is Label, "detail title exists")
	_ok(overlay.get_node_or_null("CheckoutBar/CheckoutArt") is TextureRect, "checkout v2 art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/GoldLabel") is Label, "checkout gold label exists")
	_ok(overlay.get_node_or_null("CheckoutBar/TotalLabel") is Label, "checkout total label exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusArt") is TextureRect, "quantity minus art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/BodyArt") is TextureRect, "quantity body art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusArt") is TextureRect, "quantity plus art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusZone") is Button, "quantity minus zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusZone") is Button, "quantity plus zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") is Button, "purchase zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/CloseButton/CloseZone") is Button, "close zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/CloseButton/CloseLabel") == null, "close button is icon-only")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/ControlArt") == null, "old single quantity art is not used")
	_test_v2_layout_sizes(overlay)
	var purchase := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") as Button
	if purchase != null:
		_ok(purchase.text == "", "purchase input zone is textless")
		_ok(not purchase.has_theme_stylebox_override("normal"), "purchase input zone does not expose normal button skin")
	_ok(overlay.get_node_or_null("BookLayer") == null, "old large ledger layer is removed")
	_ok(overlay.get_node_or_null("Tabs") == null, "old tab container is removed")
	_ok(overlay.get_node_or_null("ItemGrid") == null, "old item card grid is removed")


func _test_v2_layout_sizes(overlay) -> void:
	var list_panel := overlay.get_node_or_null("MainShopPanel/ListPanel") as TextureRect
	var detail_panel := overlay.get_node_or_null("MainShopPanel/DetailPanelArt") as TextureRect
	var checkout := overlay.get_node_or_null("CheckoutBar") as Control
	var item_list := overlay.get_node_or_null("ItemList") as Control
	var quantity := overlay.get_node_or_null("CheckoutBar/QuantityControl") as Control
	if list_panel != null:
		_ok(list_panel.position == Vector2(56, 112), "list panel uses v2 runtime position")
		_ok(list_panel.size == Vector2(760, 396), "list panel uses v2 runtime size")
	if detail_panel != null:
		_ok(detail_panel.position == Vector2(864, 112), "detail panel uses v2 runtime position")
		_ok(detail_panel.size == Vector2(360, 396), "detail panel uses v2 runtime size")
	if checkout != null:
		_ok(checkout.position == Vector2(120, 568), "checkout bar uses v2 runtime position")
		_ok(checkout.size == Vector2(1040, 128), "checkout bar uses v2 runtime size")
	if item_list != null:
		var first_row := item_list.get_node_or_null("Item_ale") as Control
		if first_row != null:
			_ok(first_row.size == Vector2(580, 64), "item row uses v2 runtime size")
		var rows := item_list.get_children()
		if rows.size() >= 2 and rows[0] is Control and rows[1] is Control:
			var first := rows[0] as Control
			var second := rows[1] as Control
			_ok(second.position.y - first.position.y >= first.size.y + 12, "item rows have breathing room")
	if quantity != null:
		_ok(quantity.size == Vector2(320, 72), "quantity control uses three-piece runtime size")
```

- [ ] **Step 3: Replace texture path and safe layout tests**

Replace `_test_nearest_filtering` and `_test_shop_brush_texture_paths` with:

```gdscript
func _test_nearest_filtering(overlay) -> void:
	for path in ["ShopBackdrop", "MainShopPanel/ListPanel", "MainShopPanel/DetailPanelArt", "CheckoutBar/CheckoutArt"]:
		var rect := overlay.get_node_or_null(path) as TextureRect
		if rect != null:
			_ok(rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, path + " uses nearest texture filtering")


func _test_shop_scene_v2_texture_paths(overlay) -> void:
	for path in ["ShopBackdrop", "MainShopPanel/ListPanel", "MainShopPanel/DetailPanelArt", "CheckoutBar/CheckoutArt"]:
		var rect := overlay.get_node_or_null(path) as TextureRect
		if rect != null:
			_ok(rect.texture != null, path + " has texture")
			if rect.texture != null:
				_ok(rect.texture.resource_path.contains("/shop_scene_v2/"), path + " uses shop_scene_v2 texture")


func _test_shop_scene_v2_text_safe_layout(overlay) -> void:
	var title := overlay.get_node_or_null("DetailPanel/Title") as Label
	var description := overlay.get_node_or_null("DetailPanel/Description") as Label
	var uses := overlay.get_node_or_null("DetailPanel/Uses") as Label
	var state := overlay.get_node_or_null("DetailPanel/State") as Label
	var gold := overlay.get_node_or_null("CheckoutBar/GoldLabel") as Label
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	_ok(title != null and Rect2(Vector2(0, 8), Vector2(288, 42)).encloses(Rect2(title.position, title.size)), "detail title stays inside v2 detail safe area")
	_ok(description != null and description.position.x >= 0.0 and description.position.x + description.size.x <= 288.0, "description stays inside v2 detail width")
	_ok(uses != null and uses.position.x >= 0.0 and uses.position.x + uses.size.x <= 288.0, "uses stays inside v2 detail width")
	_ok(state != null and state.position.y >= 260.0 and state.position.y + state.size.y <= 352.0, "state stays inside v2 detail lower area")
	_ok(gold != null and gold.position.x >= 176.0 and gold.position.x + gold.size.x <= 426.0, "gold label stays in checkout safe area")
	_ok(total != null and total.position.x >= 176.0 and total.position.x + total.size.x <= 426.0, "total label stays in checkout safe area")
```

- [ ] **Step 4: Run the updated Godot test and verify RED**

Run:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' 'res://scenes/test/test_shop_overlay.tscn'
```

Expected: FAIL because `ShopOverlay` still builds `MainBrushPanel` as the primary tree and uses `/shop_brush/` textures.

- [ ] **Step 5: Commit failing Godot contract update**

Run:

```powershell
git add scripts/test/test_shop_overlay.gd
git commit -m "test: expect shop scene v2 overlay contract"
```

Expected: commit contains only `scripts/test/test_shop_overlay.gd`.

## Task 8: Wire ShopOverlay To Shop Scene V2 Art

**Files:**
- Modify: `scripts/ui/shop_overlay.gd`
- Test: `scenes/test/test_shop_overlay.tscn`

- [ ] **Step 1: Add v2 texture constants below existing brush constants**

In `scripts/ui/shop_overlay.gd`, add:

```gdscript
const SHOP_SCENE_V2_BACKDROP := "res://assets/textures/daymap/shop_scene_v2/shop_scene_bg.png"
const SHOP_SCENE_V2_LIST_PANEL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_list_panel.png"
const SHOP_SCENE_V2_DETAIL_PANEL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_detail_panel.png"
const SHOP_SCENE_V2_CHECKOUT := "res://assets/textures/daymap/shop_scene_v2/shop_scene_checkout.png"
const SHOP_SCENE_V2_TAB_MATERIALS_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_materials_normal.png"
const SHOP_SCENE_V2_TAB_MATERIALS_SELECTED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_materials_selected.png"
const SHOP_SCENE_V2_TAB_RECIPES_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_recipes_normal.png"
const SHOP_SCENE_V2_TAB_RECIPES_SELECTED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_recipes_selected.png"
const SHOP_SCENE_V2_TAB_ABILITIES_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_abilities_normal.png"
const SHOP_SCENE_V2_TAB_ABILITIES_SELECTED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_abilities_selected.png"
const SHOP_SCENE_V2_ROW_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_row_normal.png"
const SHOP_SCENE_V2_ROW_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_row_hover.png"
const SHOP_SCENE_V2_ROW_SELECTED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_row_selected.png"
const SHOP_SCENE_V2_ROW_DISABLED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_row_disabled.png"
const SHOP_SCENE_V2_BUTTON_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_button_normal.png"
const SHOP_SCENE_V2_BUTTON_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_button_hover.png"
const SHOP_SCENE_V2_BUTTON_PRESSED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_button_pressed.png"
const SHOP_SCENE_V2_BUTTON_DISABLED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_button_disabled.png"
const SHOP_SCENE_V2_QUANTITY_MINUS := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_minus.png"
const SHOP_SCENE_V2_QUANTITY_BODY := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_body.png"
const SHOP_SCENE_V2_QUANTITY_PLUS := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_plus.png"
const SHOP_SCENE_V2_CLOSE_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_close_normal.png"
const SHOP_SCENE_V2_CLOSE_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_close_hover.png"
const SHOP_SCENE_V2_CLOSE_PRESSED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_close_pressed.png"
const SHOP_SCENE_V2_STATUS_OWNED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_status_owned.png"
const SHOP_SCENE_V2_STATUS_DISCOUNT := "res://assets/textures/daymap/shop_scene_v2/shop_scene_status_discount.png"
```

Expected: existing `SHOP_BRUSH_*` constants remain in the file for fallback and comparison.

- [ ] **Step 2: Replace `_build` with the v2 visual tree**

Replace the full `_build()` function in `scripts/ui/shop_overlay.gd` with:

```gdscript
func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_backdrop = _add_texture(self, "ShopBackdrop", SHOP_SCENE_V2_BACKDROP, Vector2.ZERO, Vector2(1280, 720))

	_main_panel = Control.new()
	_main_panel.name = "MainShopPanel"
	_main_panel.size = Vector2(1280, 720)
	add_child(_main_panel)
	_add_texture(_main_panel, "ListPanel", SHOP_SCENE_V2_LIST_PANEL, Vector2(56, 112), Vector2(760, 396))
	_add_texture(_main_panel, "DetailPanelArt", SHOP_SCENE_V2_DETAIL_PANEL, Vector2(864, 112), Vector2(360, 396))

	var legacy_panel := Control.new()
	legacy_panel.name = "MainBrushPanel"
	legacy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legacy_panel.size = Vector2(1280, 720)
	add_child(legacy_panel)

	_bookmarks = Control.new()
	_bookmarks.name = "CategoryTabs"
	_bookmarks.size = Vector2(1280, 720)
	add_child(_bookmarks)
	_add_bookmark("materials", "Materials", Vector2(140, 56), SHOP_SCENE_V2_TAB_MATERIALS_NORMAL, SHOP_SCENE_V2_TAB_MATERIALS_SELECTED)
	_add_bookmark("recipes", "Recipes", Vector2(352, 56), SHOP_SCENE_V2_TAB_RECIPES_NORMAL, SHOP_SCENE_V2_TAB_RECIPES_SELECTED)
	_add_bookmark("abilities", "Abilities", Vector2(564, 56), SHOP_SCENE_V2_TAB_ABILITIES_NORMAL, SHOP_SCENE_V2_TAB_ABILITIES_SELECTED)

	_item_rows = Control.new()
	_item_rows.name = "ItemList"
	_item_rows.position = Vector2(116, 132)
	_item_rows.size = Vector2(580, 368)
	add_child(_item_rows)

	_detail_page = Control.new()
	_detail_page.name = "DetailPanel"
	_detail_page.position = Vector2(908, 140)
	_detail_page.size = Vector2(288, 360)
	add_child(_detail_page)
	_detail_title = _add_label(_detail_page, "Title", Vector2(0, 8), Vector2(288, 42), 19, ThemeColors.AMBER_PRIMARY)
	_detail_desc = _add_label(_detail_page, "Description", Vector2(0, 60), Vector2(288, 80), 14, ThemeColors.TEXT_SUBTITLE)
	_detail_uses = _add_label(_detail_page, "Uses", Vector2(0, 150), Vector2(288, 100), 14, ThemeColors.TEXT_LIGHT)
	_detail_state = _add_label(_detail_page, "State", Vector2(0, 270), Vector2(288, 46), 14, ThemeColors.TEXT_DIM)
	_owned_mark = _add_texture(_detail_page, "OwnedMark", SHOP_SCENE_V2_STATUS_OWNED, Vector2(0, 304), Vector2(56, 48))
	_discount_mark = _add_texture(_detail_page, "DiscountMark", SHOP_SCENE_V2_STATUS_DISCOUNT, Vector2(72, 304), Vector2(56, 52))

	_coin_tray = Control.new()
	_coin_tray.name = "CheckoutBar"
	_coin_tray.position = Vector2(120, 568)
	_coin_tray.size = Vector2(1040, 128)
	add_child(_coin_tray)
	_add_texture(_coin_tray, "CheckoutArt", SHOP_SCENE_V2_CHECKOUT, Vector2.ZERO, Vector2(1040, 128))
	_gold_label = _add_label(_coin_tray, "GoldLabel", Vector2(176, 20), Vector2(250, 30), 16, ThemeColors.TEXT_LIGHT)
	_total_label = _add_label(_coin_tray, "TotalLabel", Vector2(176, 64), Vector2(250, 30), 16, ThemeColors.AMBER_PRIMARY)

	_quantity_control = Control.new()
	_quantity_control.name = "QuantityControl"
	_quantity_control.position = Vector2(410, 28)
	_quantity_control.size = Vector2(320, 72)
	_coin_tray.add_child(_quantity_control)
	_add_texture(_quantity_control, "MinusArt", SHOP_SCENE_V2_QUANTITY_MINUS, Vector2.ZERO, Vector2(72, 72))
	_add_texture(_quantity_control, "BodyArt", SHOP_SCENE_V2_QUANTITY_BODY, Vector2(72, 0), Vector2(176, 72))
	_add_texture(_quantity_control, "PlusArt", SHOP_SCENE_V2_QUANTITY_PLUS, Vector2(248, 0), Vector2(72, 72))
	_minus_btn = _make_input_zone("MinusZone", Vector2(72, 72))
	_minus_btn.pressed.connect(func(): set_quantity(_quantity - 1))
	_quantity_control.add_child(_minus_btn)
	_qty_label = _add_label(_quantity_control, "QuantityLabel", Vector2(102, 12), Vector2(116, 44), 18, ThemeColors.AMBER_PRIMARY)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_btn = _make_input_zone("PlusZone", Vector2(72, 72))
	_plus_btn.position = Vector2(248, 0)
	_plus_btn.pressed.connect(func(): set_quantity(_quantity + 1))
	_quantity_control.add_child(_plus_btn)

	_purchase_seal = Control.new()
	_purchase_seal.name = "PurchaseButton"
	_purchase_seal.position = Vector2(720, 28)
	_purchase_seal.size = Vector2(256, 72)
	_coin_tray.add_child(_purchase_seal)
	_seal_art = _add_texture(_purchase_seal, "ButtonArt", SHOP_SCENE_V2_BUTTON_NORMAL, Vector2.ZERO, Vector2(256, 72))
	_purchase_btn = _make_input_zone("PurchaseZone", Vector2(256, 72))
	_purchase_btn.mouse_entered.connect(func():
		if not _purchase_btn.disabled:
			_seal_art.texture = TextureManager.try_load(SHOP_SCENE_V2_BUTTON_HOVER)
	)
	_purchase_btn.mouse_exited.connect(_sync_purchase_seal)
	_purchase_btn.button_down.connect(_set_purchase_pressed)
	_purchase_btn.button_up.connect(_sync)
	_purchase_btn.pressed.connect(purchase_selected)
	_purchase_seal.add_child(_purchase_btn)
	var purchase_label := _add_label(_purchase_seal, "PurchaseLabel", Vector2(36, 14), Vector2(168, 42), 16, ThemeColors.TEXT_LIGHT)
	purchase_label.text = "购买"
	purchase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_close_tag = Control.new()
	_close_tag.name = "CloseButton"
	_close_tag.position = Vector2(992, 28)
	_close_tag.size = Vector2(72, 72)
	_coin_tray.add_child(_close_tag)
	_close_tag_art = _add_texture(_close_tag, "ButtonArt", SHOP_SCENE_V2_CLOSE_NORMAL, Vector2.ZERO, Vector2(72, 72))
	var close_zone := _make_input_zone("CloseZone", Vector2(72, 72))
	close_zone.mouse_entered.connect(func(): _close_tag_art.texture = TextureManager.try_load(SHOP_SCENE_V2_CLOSE_HOVER))
	close_zone.mouse_exited.connect(func(): _close_tag_art.texture = TextureManager.try_load(SHOP_SCENE_V2_CLOSE_NORMAL))
	close_zone.button_down.connect(func(): _close_tag_art.texture = TextureManager.try_load(SHOP_SCENE_V2_CLOSE_PRESSED))
	close_zone.button_up.connect(func(): _close_tag_art.texture = TextureManager.try_load(SHOP_SCENE_V2_CLOSE_HOVER if close_zone.is_hovered() else SHOP_SCENE_V2_CLOSE_NORMAL))
	close_zone.pressed.connect(close)
	_close_tag.add_child(close_zone)
```

- [ ] **Step 3: Update item row art paths**

In `_add_item_row`, replace:

```gdscript
	var art := _add_texture(row, "RowArt", SHOP_BRUSH_ROW_NORMAL, Vector2.ZERO, Vector2(580, 64))
```

with:

```gdscript
	var art := _add_texture(row, "RowArt", SHOP_SCENE_V2_ROW_NORMAL, Vector2.ZERO, Vector2(580, 64))
```

- [ ] **Step 4: Update row state texture paths**

Replace `_sync_rows()` with:

```gdscript
func _sync_rows() -> void:
	for key in _row_nodes.keys():
		var data: Dictionary = _row_nodes[key]
		var art := data["art"] as TextureRect
		var owned := _active_category != "materials" and _is_owned(String(key))
		if owned:
			art.texture = TextureManager.try_load(SHOP_SCENE_V2_ROW_DISABLED)
		elif String(key) == _selected_key:
			art.texture = TextureManager.try_load(SHOP_SCENE_V2_ROW_SELECTED)
		elif bool(data.get("hover", false)):
			art.texture = TextureManager.try_load(SHOP_SCENE_V2_ROW_HOVER)
		else:
			art.texture = TextureManager.try_load(SHOP_SCENE_V2_ROW_NORMAL)
```

- [ ] **Step 5: Update purchase button state texture paths**

Replace `_set_purchase_pressed()` and `_sync_purchase_seal()` with:

```gdscript
func _set_purchase_pressed() -> void:
	if _purchase_btn != null and not _purchase_btn.disabled:
		_seal_art.texture = TextureManager.try_load(SHOP_SCENE_V2_BUTTON_PRESSED)


func _sync_purchase_seal() -> void:
	if _seal_art == null:
		return
	var path := SHOP_SCENE_V2_BUTTON_NORMAL
	if _purchase_btn.disabled:
		path = SHOP_SCENE_V2_BUTTON_DISABLED
	_seal_art.texture = TextureManager.try_load(path)
```

- [ ] **Step 6: Run shop overlay test**

Run:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' 'res://scenes/test/test_shop_overlay.tscn'
```

Expected: output contains `[TEST-SHOP-OVERLAY] ALL PASS`.

- [ ] **Step 7: Commit ShopOverlay v2 hookup**

Run:

```powershell
git add scripts/ui/shop_overlay.gd
git commit -m "feat: wire shop overlay to scene v2 art"
```

Expected: commit contains only `scripts/ui/shop_overlay.gd`.

## Task 9: Update DayMap Shop Integration Assertions

**Files:**
- Modify: `scripts/test/test_day_map_scrollbars.gd`
- Test: `scenes/test/test_day_map_scrollbars.tscn`

- [ ] **Step 1: Replace stale shop integration node expectations**

In `scripts/test/test_day_map_scrollbars.gd`, replace `_test_shop_overlay_integration` with:

```gdscript
func _test_shop_overlay_integration(view) -> void:
	var overlay := view.get_node_or_null("UILayer/ShopOverlay") as ShopOverlay
	_ok(overlay != null, "DayMap uses ShopOverlay scene")
	if overlay == null:
		return
	_ok(overlay.visible, "ShopOverlay is visible while shop is open")
	_ok(not view.get_node("MapWorld").visible, "map world hides while shop overlay is open")
	_ok(overlay.get_node_or_null("ItemList") is Control, "ShopOverlay exposes item list")
	_ok(overlay.get_node_or_null("DetailPanel/Title") is Label, "ShopOverlay exposes selected item detail")
	_ok(overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") is Button, "ShopOverlay exposes purchase input zone")
	_ok(overlay.get_node_or_null("CategoryTabs/MaterialsZone") is Button, "ShopOverlay exposes materials tab input zone")
```

Expected: test now matches the actual `ShopOverlay` contract instead of stale `ItemRows`, `DetailPage`, and `PurchaseSeal` names.

- [ ] **Step 2: Run DayMap integration test**

Run:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' 'res://scenes/test/test_day_map_scrollbars.tscn'
```

Expected: output contains `[TEST-DAYMAP-SCROLLBARS] ALL PASS`.

- [ ] **Step 3: Commit DayMap integration test update**

Run:

```powershell
git add scripts/test/test_day_map_scrollbars.gd
git commit -m "test: align daymap shop integration with shop overlay contract"
```

Expected: commit contains only `scripts/test/test_day_map_scrollbars.gd`.

## Task 10: Final Verification And Review Artifacts

**Files:**
- Verify: `assets/source/daymap/shop_scene_v2/**`
- Verify: `assets/textures/daymap/shop_scene_v2/**`
- Verify: `scripts/tools/prepare_daymap_shop_scene_v2_sources.py`
- Verify: `scripts/tools/export_daymap_shop_scene_v2_assets.py`
- Verify: `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`
- Verify: `scripts/ui/shop_overlay.gd`
- Verify: `scripts/test/test_shop_overlay.gd`
- Verify: `scripts/test/test_day_map_scrollbars.gd`

- [ ] **Step 1: Run all focused Python asset tests**

Run:

```powershell
python -m unittest scripts.test.test_daymap_shop_scene_v2_asset_pipeline -v
python -m unittest scripts.test.test_daymap_shop_brush_asset_pipeline -v
```

Expected: both test modules pass. The `shop_brush` test remains passing to prove legacy art has not been broken.

- [ ] **Step 2: Run focused Godot tests**

Run:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' 'res://scenes/test/test_shop_overlay.tscn'
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' 'res://scenes/test/test_day_map_scrollbars.tscn'
```

Expected: both tests pass.

- [ ] **Step 3: Rescan Godot imports**

Run:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' --editor --quit
```

Expected: no blocking import errors for `shop_scene_v2` PNG files.

- [ ] **Step 4: Inspect final runtime preview and key textures**

Open or view:

```text
assets/source/daymap/shop_scene_v2/reference/shop_scene_v2_runtime_preview.png
assets/textures/daymap/shop_scene_v2/shop_scene_bg.png
assets/textures/daymap/shop_scene_v2/shop_scene_list_panel.png
assets/textures/daymap/shop_scene_v2/shop_scene_row_selected.png
assets/textures/daymap/shop_scene_v2/shop_scene_button_pressed.png
```

Pass criteria:

- The shop reads as one cohesive title-style dark teal dungeon tavern screen.
- The weak merchant presence stays behind the UI and does not compete with rows/detail text.
- Dynamic text zones are front-facing and readable.
- Amber accents are sparse.
- Quantity control does not read as abacus, beads, rollers, or rods.

- [ ] **Step 5: Inspect git status**

Run:

```powershell
git status --short
```

Expected: only unrelated pre-existing untracked local files remain. Do not stage or delete unrelated untracked files.

## Plan Self-Review

- Spec coverage: Tasks 2-6 implement the independent reference/native/runtime asset pipeline; Tasks 7-9 preserve and test `ShopOverlay` and DayMap contracts; Task 10 verifies Python, Godot, imports, and visual artifacts.
- Open-item scan: this plan contains fixed file paths, concrete crop boxes, and complete command examples.
- Type consistency: Asset names use the `shop_scene_*` prefix consistently; `ShopOverlay` node names match the design spec and updated tests; runtime texture paths all use `res://assets/textures/daymap/shop_scene_v2/`.
