# Tavern Static Art Redo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Tavern's static art with a coherent generated-reference-to-native-pixel asset pack and wire it into the night service scene without changing gameplay.

**Architecture:** Add a Tavern-specific asset pipeline under `assets/source/tavern/` and `assets/textures/tavern/`, with retained generated references, native source PNGs, and exact nearest-neighbor runtime exports. Keep gameplay code intact; add small texture/path helpers so `Tavern.tscn`, `TavernView`, `InventoryOverlay`, `DocumentOverlay`, and `BarWorkspace` consume the new art while preserving current node responsibilities.

**Tech Stack:** Godot 4.6 GDScript, Pillow, Python `unittest`, built-in `image_gen`, chroma-key alpha removal, existing headless Godot scene tests.

---

## File Structure

| Path | Action | Responsibility |
| --- | --- | --- |
| `assets/source/tavern/reference/` | Create | Retained image-generation references and review contact sheets. Godot must never load these. |
| `assets/source/tavern/background/` | Create | Native `320x180` Tavern background source. |
| `assets/source/tavern/ui/` | Create | Native UI panels, buttons, bars, slots, scrollbars, and small UI icons. |
| `assets/source/tavern/props/` | Create | Native barrel, grill, pot, spoon, shaker, and ledger source art. |
| `assets/source/tavern/icons/` | Create | Native item icon source art for materials, products, and story items. |
| `assets/source/tavern/characters/` | Create | Native Ryan, Mira, and normal guest portrait source art. |
| `assets/textures/tavern/` | Create | Runtime textures generated only by the exporter. |
| `scripts/tools/prepare_tavern_sources.py` | Create | Normalize approved references into native source files and contact sheets. |
| `scripts/tools/export_tavern_assets.py` | Create | Validate native sources and export exact nearest runtime textures. |
| `scripts/test/test_tavern_asset_pipeline.py` | Create | Python pipeline contract tests. |
| `scripts/test/test_tavern_static_art.gd` | Create | Godot test for runtime scene art, text safety rects, and fallback removal. |
| `scenes/test/test_tavern_static_art.tscn` | Create | Headless test scene for `test_tavern_static_art.gd`. |
| `scripts/ui/theme_colors.gd` | Modify | Add Tavern-specific stylebox helpers and content margins. |
| `scripts/ui/tavern_view.gd` | Modify | Load Tavern background/UI/character art and set text-safe layout. |
| `scripts/ui/bar_workspace.gd` | Modify | Use Tavern slot art and item icons; hide remaining old color-block fallback where new art exists. |
| `scripts/ui/inventory_overlay.gd` | Modify | Use Tavern panel/list row art and fixed text-safe columns. |
| `scripts/ui/document_overlay.gd` | Modify | Replace ledger-specific art paths with Tavern document overlay art while preserving page logic. |
| `scripts/game_manager.gd` | Modify only if needed | Add a single item icon lookup mapping to `assets/textures/tavern/icons/`. |
| `scenes/ui/Tavern.tscn` | Modify | Point ext resources and visual nodes at the new Tavern art; keep physics nodes intact. |

Use explicit `git add` paths for every commit. Do not run `git add .` because the working tree already contains unrelated DayMap changes.

## Asset Contract

The implementation must create these native/runtime pairs:

```text
background/tavern_bg_native.png                 320x180 -> background/tavern_bg.png                 1280x720
ui/topbar_native.png                            320x12  -> ui/topbar.png                            1280x48
ui/shortcut_bar_native.png                      300x14  -> ui/shortcut_bar.png                      1200x56
ui/shortcut_slot_native.png                     24x10   -> ui/shortcut_slot.png                     96x40
ui/order_bubble_native.png                      100x28  -> ui/order_bubble.png                      400x112
ui/patience_bg_native.png                       80x5    -> ui/patience_bg.png                       320x20
ui/patience_fill_native.png                     80x5    -> ui/patience_fill.png                     320x20
ui/panel_menu_native.png                        175x125 -> ui/panel_menu.png                        700x500
ui/panel_inventory_native.png                   155x135 -> ui/panel_inventory.png                   620x540
ui/panel_document_native.png                    320x180 -> ui/panel_document.png                    1280x720
ui/list_row_native.png                          70x10   -> ui/list_row.png                          280x40
ui/button_wide_{state}_native.png               70x18   -> ui/button_wide_{state}.png               280x72
ui/button_small_{state}_native.png              32x12   -> ui/button_small_{state}.png              128x48
ui/button_tab_{state}_native.png                36x12   -> ui/button_tab_{state}.png                144x48
ui/button_icon_{close,prev,next}_native.png     16x16   -> ui/button_icon_{close,prev,next}.png     64x64
ui/scroll_track_native.png                      4x80    -> ui/scroll_track.png                      16x320
ui/scroll_grabber_native.png                    4x16    -> ui/scroll_grabber.png                    16x64
props/{barrel,grill,pot,spoon,shaker,ledger}_native.png -> props/{name}.png, 4x
icons/{item_key}_native.png                     24x24   -> icons/{item_key}.png                     96x96
characters/{character_key}_native.png           70x90   -> characters/{character_key}.png           280x360
```

Button states are `normal`, `hover`, `pressed`, and `disabled`. Tab states are `normal` and `selected`.

---

### Task 1: Write the Tavern Pipeline Contract Tests

**Files:**
- Create: `scripts/test/test_tavern_asset_pipeline.py`
- Test: `scripts/test/test_tavern_asset_pipeline.py`

- [ ] **Step 1: Create the failing pipeline test**

Create `scripts/test/test_tavern_asset_pipeline.py` with this content:

```python
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "tavern"
RUNTIME = ROOT / "assets" / "textures" / "tavern"
REFERENCE = SOURCE / "reference"
SCALE = 4

OPAQUE_ASSETS = {
    "background/tavern_bg": (320, 180),
    "ui/topbar": (320, 12),
    "ui/shortcut_bar": (300, 14),
    "ui/patience_bg": (80, 5),
    "ui/patience_fill": (80, 5),
    "ui/panel_menu": (175, 125),
    "ui/panel_inventory": (155, 135),
    "ui/panel_document": (320, 180),
}

TRANSPARENT_ASSETS = {
    "ui/shortcut_slot": (24, 10),
    "ui/order_bubble": (100, 28),
    "ui/list_row": (70, 10),
    "ui/scroll_track": (4, 80),
    "ui/scroll_grabber": (4, 16),
    "props/barrel": (54, 46),
    "props/grill": (80, 28),
    "props/pot": (56, 46),
    "props/spoon": (16, 64),
    "props/shaker": (28, 42),
    "props/ledger": (40, 28),
}

for state in ["normal", "hover", "pressed", "disabled"]:
    TRANSPARENT_ASSETS[f"ui/button_wide_{state}"] = (70, 18)
    TRANSPARENT_ASSETS[f"ui/button_small_{state}"] = (32, 12)
for state in ["normal", "selected"]:
    TRANSPARENT_ASSETS[f"ui/button_tab_{state}"] = (36, 12)
for name in ["close", "prev", "next"]:
    TRANSPARENT_ASSETS[f"ui/button_icon_{name}"] = (16, 16)

ITEM_KEYS = [
    "ale", "flour", "meat_raw", "grape", "herb",
    "bread", "meat_cooked", "ale_beer", "wine", "herb_tea",
    "meat_sand", "herbal_ale", "spiced_wine", "meat_stew",
    "herb_broth", "malt_porridge", "sleep_powder",
    "bloodied_contract", "alternative_contract", "toby_contract",
]
CHARACTER_KEYS = [
    "ryan_neutral", "ryan_excited", "ryan_hesitant", "ryan_dejected",
    "mira_neutral", "guest_commoner", "guest_knight", "guest_merchant",
    "guest_rogue", "guest_wizard", "guest_dwarf",
]
for key in ITEM_KEYS:
    TRANSPARENT_ASSETS[f"icons/{key}"] = (24, 24)
for key in CHARACTER_KEYS:
    TRANSPARENT_ASSETS[f"characters/{key}"] = (70, 90)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def exact_runtime_export(test_case: unittest.TestCase, name: str, native_size: tuple[int, int]) -> Image.Image:
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    test_case.assertTrue(native_path.exists(), f"{native_path}: missing native source")
    test_case.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
    native = load_rgba(native_path)
    runtime = load_rgba(runtime_path)
    expected_size = (native_size[0] * SCALE, native_size[1] * SCALE)
    test_case.assertEqual(native.size, native_size, f"{name}: wrong native size")
    test_case.assertEqual(runtime.size, expected_size, f"{name}: wrong runtime size")
    expected = native.resize(expected_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: not exact nearest export")
    return native


class TavernAssetPipelineTest(unittest.TestCase):
    def test_reference_art_is_retained(self) -> None:
        required = [
            "tavern_background_reference.png",
            "tavern_ui_reference.png",
            "tavern_props_reference.png",
            "tavern_icons_reference.png",
            "tavern_characters_reference.png",
        ]
        for filename in required:
            path = REFERENCE / filename
            self.assertTrue(path.exists(), f"{path}: missing retained generated reference")
            self.assertGreater(path.stat().st_size, 0, f"{path}: retained reference is empty")

    def test_opaque_assets_are_exact_native_exports(self) -> None:
        for name, native_size in OPAQUE_ASSETS.items():
            with self.subTest(name=name):
                native = exact_runtime_export(self, name, native_size)
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual((alpha_min, alpha_max), (255, 255), f"{name}: must be fully opaque")

    def test_transparent_assets_have_alpha_and_exact_runtime_exports(self) -> None:
        for name, native_size in TRANSPARENT_ASSETS.items():
            with self.subTest(name=name):
                native = exact_runtime_export(self, name, native_size)
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, f"{name}: needs transparent pixels")
                self.assertGreater(alpha_max, 0, f"{name}: has no visible pixels")
                self.assertGreater(visible_pixel_count(native), 8, f"{name}: too sparse")

    def test_background_matches_tavern_palette_guardrails(self) -> None:
        native = exact_runtime_export(self, "background/tavern_bg", (320, 180))
        pixels = list(native.getdata())
        dark = sum(1 for r, g, b, a in pixels if a >= 250 and max(r, g, b) <= 58)
        teal = sum(1 for r, g, b, a in pixels if a >= 250 and b >= 34 and g >= 30 and b >= r * 1.05)
        warm = sum(1 for r, g, b, a in pixels if a >= 250 and r >= 105 and g >= 45 and r >= b * 1.45)
        self.assertGreaterEqual(dark, 20000, "background needs enough dark dungeon mass")
        self.assertGreaterEqual(teal, 3000, "background needs visible teal depth")
        self.assertGreaterEqual(warm, 160, "background needs sparse amber light accents")
        self.assertLessEqual(warm, 10000, "background amber accents are flooding the frame")

    def test_text_carrier_assets_have_clear_safe_areas(self) -> None:
        cases = {
            "ui/topbar": (48, 2, 300, 10),
            "ui/order_bubble": (8, 5, 92, 23),
            "ui/panel_menu": (10, 12, 165, 113),
            "ui/panel_inventory": (8, 10, 147, 125),
            "ui/panel_document": (54, 28, 266, 148),
            "ui/list_row": (8, 2, 66, 8),
        }
        for name, box in cases.items():
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                left, top, right, bottom = box
                area = native.crop((left, top, right, bottom)).convert("RGBA")
                pixels = list(area.getdata())
                readable_dark = sum(1 for r, g, b, a in pixels if a >= 240 and max(r, g, b) <= 92)
                readable_paper = sum(1 for r, g, b, a in pixels if a >= 240 and 80 <= r <= 185 and 50 <= g <= 145 and 28 <= b <= 120)
                self.assertGreater(readable_dark + readable_paper, len(pixels) * 0.68, f"{name}: text safe area is too noisy")


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
python -m unittest scripts.test.test_tavern_asset_pipeline.TavernAssetPipelineTest -v
```

Expected: FAIL with missing `assets/source/tavern/reference/...` and missing native/runtime files. This is the correct RED state.

- [ ] **Step 3: Commit the failing test**

Run:

```powershell
git add scripts/test/test_tavern_asset_pipeline.py
git commit -m "test: add Tavern static art pipeline contract"
```

---

### Task 2: Generate and Retain Tavern Reference Art

**Files:**
- Create: `assets/source/tavern/reference/tavern_background_reference.png`
- Create: `assets/source/tavern/reference/tavern_ui_reference.png`
- Create: `assets/source/tavern/reference/tavern_props_reference.png`
- Create: `assets/source/tavern/reference/tavern_icons_reference.png`
- Create: `assets/source/tavern/reference/tavern_characters_reference.png`
- Create: `assets/source/tavern/reference/prompts.md`

- [ ] **Step 1: Generate the background reference with built-in image generation**

Use the built-in `image_gen` tool with this prompt:

```text
Use case: stylized-concept
Asset type: 2D browser-game tavern service background reference
Primary request: A wide dark underground tavern interior seen from behind the bar, for a pixel-art native pipeline.
Scene/backdrop: ancient dungeon tavern, stone back wall, heavy wooden bar counter across the lower third, sparse shelves, a few mugs and bottles as broad silhouettes, dark negative space behind the customer stage.
Style/medium: painterly concept reference that will be normalized to chunky low-resolution pixel art; broad blocky shapes, hard-edged shadows, low-density detail.
Composition/framing: 16:9 wide frame. Leave the center upper-middle clear for a 280x360 customer portrait. Leave lower middle playable space readable for props. No UI panels, no text, no characters.
Lighting/mood: mostly dark teal and coal black, sparse amber candle and hearth accents, warm but not orange-dominant.
Color palette: dark teal, coal black, dark wood, muted parchment browns, sparse amber highlights.
Constraints: no text, no logo, no watermark, no modern UI, no characters, no readable signs, no dense bottle-wall texture.
Avoid: smooth neon glow, high saturation orange, realistic photo texture, tiny noise, clutter in the text/portrait areas.
```

Move/copy the selected output into:

```text
assets/source/tavern/reference/tavern_background_reference.png
```

- [ ] **Step 2: Generate the UI reference sheet**

Use built-in `image_gen` with this prompt:

```text
Use case: ui-mockup
Asset type: static UI texture reference sheet for a pixel-art tavern game
Primary request: A sheet of dark tavern UI panels and controls with large empty text-safe interiors.
Subject: top bar strip, shortcut bar strip, empty inventory panel, menu panel, document panel, order speech bubble, list row, wide buttons, small buttons, tab buttons, scrollbar pieces, close/prev/next icons.
Style/medium: dark teal dungeon tavern UI, chunky pixel-art reference, hand-painted but with clear cropable shapes.
Composition/framing: organized sheet on a flat solid #00ff00 chroma-key background, each UI piece separated with generous padding. No words or labels inside the art.
Lighting/mood: muted dark teal and charcoal with sparse amber trim.
Color palette: dark teal, coal black, muted parchment brown, sparse amber.
Constraints: every text carrier must have a clear simple interior safe area; no decorative marks in the center of text areas; no text; no logo; no watermark.
Avoid: modern glossy UI, neon outlines, rounded mobile-app buttons, crowded ornament in text areas.
```

Move/copy the selected output into:

```text
assets/source/tavern/reference/tavern_ui_reference.png
```

- [ ] **Step 3: Generate the props reference sheet**

Use built-in `image_gen` with this prompt:

```text
Use case: stylized-concept
Asset type: static transparent prop reference sheet for Tavern workspace objects
Primary request: A sheet of tavern workbench props: barrel, grill, stew pot, long spoon, seasoning shaker, closed ledger book.
Style/medium: chunky dark pixel-art reference, broad silhouettes, hard edges, low detail, dark teal and amber tavern palette.
Composition/framing: each object isolated and centered on a perfectly flat solid #00ff00 chroma-key background, generous padding between objects, no cast shadows.
Materials/textures: dark wood barrel with amber bands, iron grill, blackened stew pot, dull metal spoon, small clay/wood shaker, dark leather ledger with amber clasp.
Constraints: no text, no logo, no watermark, no contact shadow, no #00ff00 inside the objects.
Avoid: photorealism, tiny texture noise, soft glow, excessive orange.
```

Move/copy the selected output into:

```text
assets/source/tavern/reference/tavern_props_reference.png
```

- [ ] **Step 4: Generate the icons reference sheet**

Use built-in `image_gen` with this prompt:

```text
Use case: stylized-concept
Asset type: item icon reference sheet for a pixel-art tavern game
Primary request: A clean grid of small readable item icons for tavern ingredients, products, and story items.
Subject: malt/ale, flour, raw meat, grapes, herb, bread, cooked meat, ale beer, wine, herb tea, meat sandwich, herbal ale, spiced wine, meat stew, herb broth, malt porridge, sleep powder vial, bloodied contract, alternative contract, torn Toby contract.
Style/medium: chunky low-resolution pixel-art reference, bold silhouettes, flat readable colors, dark outline.
Composition/framing: 5 columns by 4 rows on a perfectly flat solid #00ff00 chroma-key background. Each icon centered with padding. No labels or text.
Color palette: muted tavern palette with item-specific accent colors, dark outlines, sparse amber.
Constraints: no text, no logo, no watermark, no shadows, no #00ff00 inside icons.
Avoid: detailed realism, thin line art, tiny unreadable marks, modern app icons.
```

Move/copy the selected output into:

```text
assets/source/tavern/reference/tavern_icons_reference.png
```

- [ ] **Step 5: Generate the character reference sheet**

Use built-in `image_gen` with this prompt:

```text
Use case: stylized-concept
Asset type: static character portrait reference sheet for Tavern customer area
Primary request: A sheet of static tavern customer portraits for Ryan, Mira, and normal guests.
Subject: Ryan neutral, Ryan excited, Ryan hesitant, Ryan dejected; Mira neutral; guest commoner, knight, merchant, rogue, wizard, dwarf.
Style/medium: chunky dark pixel-art character reference, broad silhouettes, simple faces, full-body or three-quarter portrait suitable for 70x90 native source.
Composition/framing: isolated characters in a grid on a perfectly flat solid #00ff00 chroma-key background, generous padding, no cast shadows.
Lighting/mood: dark tavern palette, subtle amber rim accents, readable silhouettes.
Constraints: no text, no logo, no watermark, no #00ff00 in characters.
Avoid: anime polish, photorealism, thin details, noisy clothing textures, oversized weapons that leave the cell.
```

Move/copy the selected output into:

```text
assets/source/tavern/reference/tavern_characters_reference.png
```

- [ ] **Step 6: Record prompts and review decisions**

Create `assets/source/tavern/reference/prompts.md` containing the five prompts above, the selected filenames, and these review decisions:

```markdown
# Tavern Static Art Reference Prompts

All generated images are retained as reference only. Godot runtime textures are generated from native source files by `scripts/tools/export_tavern_assets.py`.

Approved references:
- `tavern_background_reference.png`
- `tavern_ui_reference.png`
- `tavern_props_reference.png`
- `tavern_icons_reference.png`
- `tavern_characters_reference.png`

Rejected variants are not part of runtime. Transparent assets use chroma-key cleanup before native source creation.
```

- [ ] **Step 7: Commit retained references**

Run:

```powershell
git add assets/source/tavern/reference/tavern_background_reference.png assets/source/tavern/reference/tavern_ui_reference.png assets/source/tavern/reference/tavern_props_reference.png assets/source/tavern/reference/tavern_icons_reference.png assets/source/tavern/reference/tavern_characters_reference.png assets/source/tavern/reference/prompts.md
git commit -m "art: add Tavern static art references"
```

---

### Task 3: Implement the Tavern Native Prep Tool

**Files:**
- Create: `scripts/tools/prepare_tavern_sources.py`
- Modify generated files under: `assets/source/tavern/**`
- Test: `scripts/test/test_tavern_asset_pipeline.py`

- [ ] **Step 1: Write the prep tool**

Create `scripts/tools/prepare_tavern_sources.py` with this structure:

```python
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "tavern"
REFERENCE = SOURCE / "reference"
CHROMA = (0, 255, 0)

BACKGROUND = ("background/tavern_bg", (320, 180))
OPAQUE_UI = {
    "ui/topbar": (320, 12),
    "ui/shortcut_bar": (300, 14),
    "ui/patience_bg": (80, 5),
    "ui/patience_fill": (80, 5),
    "ui/panel_menu": (175, 125),
    "ui/panel_inventory": (155, 135),
    "ui/panel_document": (320, 180),
}
TRANSPARENT_UI = {
    "ui/shortcut_slot": (24, 10),
    "ui/order_bubble": (100, 28),
    "ui/list_row": (70, 10),
    "ui/scroll_track": (4, 80),
    "ui/scroll_grabber": (4, 16),
}
for state in ["normal", "hover", "pressed", "disabled"]:
    TRANSPARENT_UI[f"ui/button_wide_{state}"] = (70, 18)
    TRANSPARENT_UI[f"ui/button_small_{state}"] = (32, 12)
for state in ["normal", "selected"]:
    TRANSPARENT_UI[f"ui/button_tab_{state}"] = (36, 12)
for name in ["close", "prev", "next"]:
    TRANSPARENT_UI[f"ui/button_icon_{name}"] = (16, 16)

PROPS = {
    "props/barrel": (54, 46),
    "props/grill": (80, 28),
    "props/pot": (56, 46),
    "props/spoon": (16, 64),
    "props/shaker": (28, 42),
    "props/ledger": (40, 28),
}
ICONS = [
    "ale", "flour", "meat_raw", "grape", "herb",
    "bread", "meat_cooked", "ale_beer", "wine", "herb_tea",
    "meat_sand", "herbal_ale", "spiced_wine", "meat_stew",
    "herb_broth", "malt_porridge", "sleep_powder",
    "bloodied_contract", "alternative_contract", "toby_contract",
]
CHARACTERS = [
    "ryan_neutral", "ryan_excited", "ryan_hesitant", "ryan_dejected",
    "mira_neutral", "guest_commoner", "guest_knight", "guest_merchant",
    "guest_rogue", "guest_wizard", "guest_dwarf",
]


def load_reference(filename: str) -> Image.Image:
    path = REFERENCE / filename
    if not path.exists():
        raise FileNotFoundError(f"Missing Tavern reference: {path}")
    with Image.open(path) as image:
        return image.convert("RGBA")


def remove_chroma(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if green > 145 and green > red * 1.28 and green > blue * 1.28:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, alpha)
    return out


def fit_opaque(image: Image.Image, size: tuple[int, int], colors: int) -> Image.Image:
    fitted = ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
    fitted = ImageEnhance.Contrast(fitted).enhance(1.08)
    native = fitted.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    native.putalpha(Image.new("L", size, 255))
    return native


def fit_transparent(image: Image.Image, size: tuple[int, int], colors: int) -> Image.Image:
    keyed = remove_chroma(image)
    box = keyed.getchannel("A").getbbox()
    if box is None:
        raise ValueError("transparent reference crop is empty")
    trimmed = keyed.crop(box).convert("RGBA")
    contained = ImageOps.contain(trimmed, size, method=Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(contained, ((size[0] - contained.width) // 2, (size[1] - contained.height) // 2))
    alpha = canvas.getchannel("A").point(lambda value: 255 if value >= 32 else 0)
    rgb = canvas.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    rgb.putalpha(alpha)
    return rgb


def sheet_cell(sheet: Image.Image, columns: int, rows: int, index: int) -> Image.Image:
    cell_w = sheet.width / columns
    cell_h = sheet.height / rows
    col = index % columns
    row = index // columns
    return sheet.crop((round(col * cell_w), round(row * cell_h), round((col + 1) * cell_w), round((row + 1) * cell_h))).convert("RGBA")


def save_native(name: str, image: Image.Image) -> None:
    path = SOURCE / f"{name}_native.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"prepared {path.relative_to(ROOT)} {image.size}")


def prepare_background() -> None:
    name, size = BACKGROUND
    save_native(name, fit_opaque(load_reference("tavern_background_reference.png"), size, 56))


def prepare_ui() -> None:
    sheet = load_reference("tavern_ui_reference.png")
    names = [*OPAQUE_UI.keys(), *TRANSPARENT_UI.keys()]
    sizes = {**OPAQUE_UI, **TRANSPARENT_UI}
    for index, name in enumerate(names):
        cell = sheet_cell(sheet, 5, 6, index)
        if name in OPAQUE_UI:
            save_native(name, fit_opaque(cell, sizes[name], 24))
        else:
            save_native(name, fit_transparent(cell, sizes[name], 18))


def prepare_props() -> None:
    sheet = load_reference("tavern_props_reference.png")
    for index, (name, size) in enumerate(PROPS.items()):
        save_native(name, fit_transparent(sheet_cell(sheet, 3, 2, index), size, 20))


def prepare_icons() -> None:
    sheet = load_reference("tavern_icons_reference.png")
    for index, key in enumerate(ICONS):
        save_native(f"icons/{key}", fit_transparent(sheet_cell(sheet, 5, 4, index), (24, 24), 16))


def prepare_characters() -> None:
    sheet = load_reference("tavern_characters_reference.png")
    for index, key in enumerate(CHARACTERS):
        save_native(f"characters/{key}", fit_transparent(sheet_cell(sheet, 4, 3, index), (70, 90), 24))


def main() -> None:
    prepare_background()
    prepare_ui()
    prepare_props()
    prepare_icons()
    prepare_characters()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the prep tool**

Run:

```powershell
python scripts/tools/prepare_tavern_sources.py
```

Expected: files are created under `assets/source/tavern/background`, `ui`, `props`, `icons`, and `characters`. If a sheet crop is poor, regenerate that reference or adjust the sheet grid before continuing.

- [ ] **Step 3: Re-run the pipeline test and confirm it still fails at runtime exports**

Run:

```powershell
python -m unittest scripts.test.test_tavern_asset_pipeline.TavernAssetPipelineTest -v
```

Expected: reference/native checks move forward; runtime files under `assets/textures/tavern/` are still missing. This is the second RED state.

- [ ] **Step 4: Commit native prep outputs**

Run:

```powershell
git add scripts/tools/prepare_tavern_sources.py assets/source/tavern/background assets/source/tavern/ui assets/source/tavern/props assets/source/tavern/icons assets/source/tavern/characters
git commit -m "art: prepare Tavern native static sources"
```

---

### Task 4: Implement the Tavern Exporter

**Files:**
- Create: `scripts/tools/export_tavern_assets.py`
- Create generated files under: `assets/textures/tavern/**`
- Test: `scripts/test/test_tavern_asset_pipeline.py`

- [ ] **Step 1: Create the exporter**

Create `scripts/tools/export_tavern_assets.py` with this content:

```python
from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "tavern"
RUNTIME = ROOT / "assets" / "textures" / "tavern"
SCALE = 4

ASSETS = {
    "background/tavern_bg": (320, 180, False),
    "ui/topbar": (320, 12, False),
    "ui/shortcut_bar": (300, 14, False),
    "ui/shortcut_slot": (24, 10, True),
    "ui/order_bubble": (100, 28, True),
    "ui/patience_bg": (80, 5, False),
    "ui/patience_fill": (80, 5, False),
    "ui/panel_menu": (175, 125, False),
    "ui/panel_inventory": (155, 135, False),
    "ui/panel_document": (320, 180, False),
    "ui/list_row": (70, 10, True),
    "ui/scroll_track": (4, 80, True),
    "ui/scroll_grabber": (4, 16, True),
    "props/barrel": (54, 46, True),
    "props/grill": (80, 28, True),
    "props/pot": (56, 46, True),
    "props/spoon": (16, 64, True),
    "props/shaker": (28, 42, True),
    "props/ledger": (40, 28, True),
}

for state in ["normal", "hover", "pressed", "disabled"]:
    ASSETS[f"ui/button_wide_{state}"] = (70, 18, True)
    ASSETS[f"ui/button_small_{state}"] = (32, 12, True)
for state in ["normal", "selected"]:
    ASSETS[f"ui/button_tab_{state}"] = (36, 12, True)
for name in ["close", "prev", "next"]:
    ASSETS[f"ui/button_icon_{name}"] = (16, 16, True)
for key in [
    "ale", "flour", "meat_raw", "grape", "herb",
    "bread", "meat_cooked", "ale_beer", "wine", "herb_tea",
    "meat_sand", "herbal_ale", "spiced_wine", "meat_stew",
    "herb_broth", "malt_porridge", "sleep_powder",
    "bloodied_contract", "alternative_contract", "toby_contract",
]:
    ASSETS[f"icons/{key}"] = (24, 24, True)
for key in [
    "ryan_neutral", "ryan_excited", "ryan_hesitant", "ryan_dejected",
    "mira_neutral", "guest_commoner", "guest_knight", "guest_merchant",
    "guest_rogue", "guest_wizard", "guest_dwarf",
]:
    ASSETS[f"characters/{key}"] = (70, 90, True)


def load_native(name: str) -> Image.Image:
    path = SOURCE / f"{name}_native.png"
    if not path.exists():
        raise FileNotFoundError(f"Missing Tavern native source: {path}")
    with Image.open(path) as image:
        return image.convert("RGBA")


def validate_native(name: str, image: Image.Image, size: tuple[int, int], transparent: bool) -> None:
    if image.size != size:
        raise ValueError(f"{name}: native source must be {size}, got {image.size}")
    alpha_min, alpha_max = image.getchannel("A").getextrema()
    if transparent:
        if alpha_min != 0 or alpha_max == 0:
            raise ValueError(f"{name}: transparent asset must contain transparent and visible pixels")
    elif (alpha_min, alpha_max) != (255, 255):
        raise ValueError(f"{name}: opaque asset must be fully opaque, alpha range {(alpha_min, alpha_max)}")


def build_runtime(native: Image.Image) -> Image.Image:
    return native.resize((native.width * SCALE, native.height * SCALE), Image.Resampling.NEAREST)


def main() -> None:
    outputs: dict[str, Image.Image] = {}
    for name, (width, height, transparent) in ASSETS.items():
        native = load_native(name)
        validate_native(name, native, (width, height), transparent)
        runtime = build_runtime(native)
        expected = native.resize(runtime.size, Image.Resampling.NEAREST)
        if runtime.tobytes() != expected.tobytes():
            raise RuntimeError(f"{name}: runtime export is not exact nearest")
        outputs[name] = runtime

    for name, runtime in outputs.items():
        path = RUNTIME / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        runtime.save(path)
        print(f"{name}: {runtime.size}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the exporter**

Run:

```powershell
python scripts/tools/export_tavern_assets.py
```

Expected: runtime textures appear under `assets/textures/tavern/`.

- [ ] **Step 3: Run the pipeline test and confirm it passes**

Run:

```powershell
python -m unittest scripts.test.test_tavern_asset_pipeline.TavernAssetPipelineTest -v
```

Expected: PASS.

- [ ] **Step 4: Commit exporter and runtime textures**

Run:

```powershell
git add scripts/tools/export_tavern_assets.py assets/textures/tavern
git commit -m "art: export Tavern static runtime textures"
```

---

### Task 5: Add Tavern Runtime Art Helpers

**Files:**
- Modify: `scripts/ui/theme_colors.gd`
- Test: `scripts/test/test_tavern_static_art.gd` in Task 6

- [ ] **Step 1: Add Tavern texture constants and helpers**

Modify `scripts/ui/theme_colors.gd` by adding constants near the existing `MENU_BRUSH_*` constants:

```gdscript
const TAVERN_UI_ROOT := "res://assets/textures/tavern/ui/"
const TAVERN_FONT_PATH := "res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"
```

Add these static helpers near the brush helpers:

```gdscript
static func tavern_style_box(name: String, margin_left: float = 8.0, margin_top: float = 4.0, margin_right: float = 8.0, margin_bottom: float = 4.0) -> StyleBox:
	var style := TextureManager.try_load_style_box(TAVERN_UI_ROOT + name + ".png")
	if style == null:
		return _brush_fallback()
	style.set_content_margin(SIDE_LEFT, margin_left)
	style.set_content_margin(SIDE_TOP, margin_top)
	style.set_content_margin(SIDE_RIGHT, margin_right)
	style.set_content_margin(SIDE_BOTTOM, margin_bottom)
	return style


static func tavern_button_style(button: Button, base_name: String, font_size: int = 14) -> void:
	var font := menu_font()
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_SUBTITLE)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)
	button.add_theme_stylebox_override("normal", tavern_style_box(base_name + "_normal", 14.0, 5.0, 14.0, 6.0))
	button.add_theme_stylebox_override("hover", tavern_style_box(base_name + "_hover", 14.0, 5.0, 14.0, 6.0))
	button.add_theme_stylebox_override("pressed", tavern_style_box(base_name + "_pressed", 14.0, 6.0, 14.0, 5.0))
	button.add_theme_stylebox_override("disabled", tavern_style_box(base_name + "_disabled", 14.0, 5.0, 14.0, 6.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
```

- [ ] **Step 2: Do a syntax sanity check**

Run:

```powershell
rg -n "tavern_style_box|tavern_button_style|TAVERN_UI_ROOT" scripts/ui/theme_colors.gd
```

Expected: three helpers/constants are present.

- [ ] **Step 3: Commit theme helpers**

Run:

```powershell
git add scripts/ui/theme_colors.gd
git commit -m "feat: add Tavern art theme helpers"
```

---

### Task 6: Write the Godot Static Art Scene Test

**Files:**
- Create: `scripts/test/test_tavern_static_art.gd`
- Create: `scenes/test/test_tavern_static_art.tscn`

- [ ] **Step 1: Create the failing Godot test script**

Create `scripts/test/test_tavern_static_art.gd`:

```gdscript
extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_tavern_uses_static_art_pack()
	await _test_text_safe_layouts()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TAVERN-STATIC-ART] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TAVERN-STATIC-ART] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TAVERN-STATIC-ART] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.resource_path


func _has_style(control: Control, name: String) -> bool:
	return control.has_theme_stylebox_override(name) and control.get_theme_stylebox(name) != null


func _test_tavern_uses_static_art_pack() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	var background := tavern.get_node("Background") as Sprite2D
	_ok(_texture_path(background.texture) == "res://assets/textures/tavern/background/tavern_bg.png", "Tavern background uses new pipeline texture")

	var paths := [
		"BarWorkspace/World/Brewery/Art",
		"BarWorkspace/World/Grill/Art",
		"BarWorkspace/World/Pot/Art",
		"BarWorkspace/World/Spoon/Art",
		"BarWorkspace/World/SeasoningShaker/Art",
		"BarWorkspace/World/Ledger/Art",
	]
	for path in paths:
		var art := tavern.get_node_or_null(path) as Sprite2D
		_ok(art != null and art.texture != null, "art sprite exists: " + path)
		_ok(_texture_path(art.texture).begins_with("res://assets/textures/tavern/props/"), "art sprite uses Tavern props texture: " + path)

	for slot_index in range(10):
		var slot := tavern.get_node("ShortcutBar/Slot%d" % slot_index) as ColorRect
		var background_node := slot.get_node_or_null("BrushBackground") as TextureRect
		_ok(background_node != null and _texture_path(background_node.texture) == "res://assets/textures/tavern/ui/shortcut_slot.png", "shortcut slot uses Tavern slot art")

	var order_bubble := tavern.get_node("CustomerArea/OrderBubble") as Label
	_ok(_has_style(order_bubble, "normal"), "order bubble has Tavern stylebox")
	var timer := tavern.get_node("CustomerArea/TimerBar") as ProgressBar
	_ok(timer.has_theme_stylebox_override("background"), "timer has Tavern background stylebox")
	_ok(timer.has_theme_stylebox_override("fill"), "timer has Tavern fill stylebox")

	tavern.show_customer("路过的冒险者", "特别长的草药炖肉三明治订单", "missing_guest_kind")
	await get_tree().process_frame
	var sprite := tavern.get_node("CustomerArea/CustomerSprite") as TextureRect
	_ok(_texture_path(sprite.texture) == "res://assets/textures/tavern/characters/guest_commoner.png", "missing guest uses Tavern fallback portrait")

	tavern.queue_free()
	await get_tree().process_frame


func _test_text_safe_layouts() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var labels := [
		tavern.get_node("TopPanel/GoldLabel") as Label,
		tavern.get_node("TopPanel/ReputationLabel") as Label,
		tavern.get_node("TopPanel/DayLabel") as Label,
		tavern.get_node("CustomerArea/CustomerName") as Label,
		tavern.get_node("CustomerArea/OrderBubble") as Label,
	]
	for label in labels:
		_ok(label.size.x >= 120.0, label.name + " has enough width")
		_ok(label.get_theme_font_size("font_size") <= 18, label.name + " avoids oversized type")

	tavern.show_customer("很长名字的地下城旅人", "特别长的草药炖肉三明治订单", "guest_commoner")
	await get_tree().process_frame
	var bubble := tavern.get_node("CustomerArea/OrderBubble") as Label
	_ok(bubble.autowrap_mode != TextServer.AUTOWRAP_OFF, "order bubble wraps long Chinese text")
	_ok(bubble.size.y >= 64.0, "order bubble reserves multi-line height")

	tavern.toggle_menu()
	await get_tree().process_frame
	var menu := tavern.get_node("OverlayMenu") as Panel
	_ok(menu.has_theme_stylebox_override("panel"), "menu panel has Tavern style")
	_ok(menu.size == Vector2(700, 500), "menu panel keeps expected text-safe size")

	tavern.queue_free()
	await get_tree().process_frame
```

- [ ] **Step 2: Create the test scene**

Create `scenes/test/test_tavern_static_art.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_tavern_static_art.gd" id="1"]

[node name="TestTavernStaticArt" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: Run the focused Godot test and confirm it fails**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_static_art.tscn
```

Expected: FAIL because Tavern still references old paths and styles.

- [ ] **Step 4: Commit failing Godot test**

Run:

```powershell
git add scripts/test/test_tavern_static_art.gd scenes/test/test_tavern_static_art.tscn
git commit -m "test: add Tavern static art scene contract"
```

---

### Task 7: Wire TavernView to the New Background, UI, Text Layout, and Character Fallbacks

**Files:**
- Modify: `scripts/ui/tavern_view.gd`
- Modify: `scenes/ui/Tavern.tscn`
- Test: `scenes/test/test_tavern_static_art.tscn`

- [ ] **Step 1: Add Tavern art path constants**

In `scripts/ui/tavern_view.gd`, add near the top:

```gdscript
const TAVERN_BACKGROUND := "res://assets/textures/tavern/background/tavern_bg.png"
const TAVERN_CHAR_ROOT := "res://assets/textures/tavern/characters/"
const TAVERN_GUEST_FALLBACK := "guest_commoner"
```

Extend `NPC_TEXTURE_KEYS` to include current normal guest ids:

```gdscript
const NPC_TEXTURE_KEYS: Dictionary = {
	"ryan": "ryan_neutral",
	"mira": "mira_neutral",
	"guest": "guest_commoner",
	"guest_commoner": "guest_commoner",
	"guest_knight": "guest_knight",
	"guest_merchant": "guest_merchant",
	"guest_rogue": "guest_rogue",
	"guest_wizard": "guest_wizard",
	"guest_dwarf": "guest_dwarf",
}
```

- [ ] **Step 2: Replace background and character loading**

In `_apply_theme()`, replace the background path with `TAVERN_BACKGROUND`.

In `show_customer()`, replace the texture load block with:

```gdscript
	var tex_key: String = NPC_TEXTURE_KEYS.get(npc_id, TAVERN_GUEST_FALLBACK)
	var tex = TextureManager.try_load(TAVERN_CHAR_ROOT + tex_key + ".png")
	if tex == null:
		tex = TextureManager.try_load(TAVERN_CHAR_ROOT + TAVERN_GUEST_FALLBACK + ".png")
	if tex != null:
		_customer_sprite.texture = tex
		_customer_sprite.modulate = Color.WHITE
	else:
		_customer_sprite.texture = null
		_customer_sprite.modulate = Color.WHITE
```

- [ ] **Step 3: Apply Tavern UI styleboxes and text-safe layout**

In `_apply_theme()`, add after label setup:

```gdscript
	_order_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_order_bubble.custom_minimum_size = Vector2(400.0, 72.0)
	_order_bubble.add_theme_stylebox_override("normal", ThemeColors.tavern_style_box("order_bubble", 28.0, 14.0, 28.0, 14.0))
	_timer_bar.add_theme_stylebox_override("background", ThemeColors.tavern_style_box("patience_bg", 0.0, 0.0, 0.0, 0.0))
	_timer_bar.add_theme_stylebox_override("fill", ThemeColors.tavern_style_box("patience_fill", 0.0, 0.0, 0.0, 0.0))
```

Update top and end buttons:

```gdscript
	ThemeColors.tavern_button_style($TopPanel/MenuButton, "button_small", 13)
	ThemeColors.tavern_button_style(_end_night_btn, "button_small", 13)
```

Style overlay buttons:

```gdscript
	_menu_panel.add_theme_stylebox_override("panel", ThemeColors.tavern_style_box("panel_menu", 36.0, 40.0, 36.0, 36.0))
	ThemeColors.tavern_button_style($OverlayMenu/BtnTidy, "button_wide", 14)
	ThemeColors.tavern_button_style($OverlayMenu/CloseBtn, "button_small", 14)
```

- [ ] **Step 4: Adjust scene text-safe rectangles**

Modify `scenes/ui/Tavern.tscn`:

```text
CustomerArea offset_left=440 offset_top=72 offset_right=840 offset_bottom=456
OrderBubble offset_top=300 offset_bottom=388
TimerBar offset_top=396 offset_bottom=416
OverlayMenu offset_left=290 offset_top=100 offset_right=990 offset_bottom=600
```

Keep `CustomerDropArea` physics shape unchanged.

- [ ] **Step 5: Run the focused Godot test**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_static_art.tscn
```

Expected: background, order bubble, timer, and fallback checks pass; prop/slot checks may still fail until Tasks 8-9.

- [ ] **Step 6: Commit TavernView UI hookup**

Run:

```powershell
git add scripts/ui/tavern_view.gd scenes/ui/Tavern.tscn
git commit -m "feat: wire Tavern scene to static art pack"
```

---

### Task 8: Wire Workspace Props, Shortcut Slots, and Item Icons

**Files:**
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scripts/ui/bar_workspace.gd`
- Modify: `scripts/game_manager.gd` only if icon lookup lacks these paths
- Test: `scripts/test/test_tavern_static_art.gd`

- [ ] **Step 1: Update prop texture ext resources in `Tavern.tscn`**

Replace workspace texture ext_resource paths:

```text
res://assets/textures/tavern/props/barrel.png
res://assets/textures/tavern/props/grill.png
res://assets/textures/tavern/props/pot.png
res://assets/textures/tavern/props/spoon.png
```

Add ext_resources for:

```text
res://assets/textures/tavern/props/shaker.png
res://assets/textures/tavern/props/ledger.png
```

Attach `Sprite2D` child named `Art` to `BarWorkspace/World/SeasoningShaker` and `BarWorkspace/World/Ledger` if missing. Set `texture_filter = 1`, `texture` to the new ext_resource, and keep the existing script nodes.

- [ ] **Step 2: Update shortcut slot texture in `bar_workspace.gd`**

In `_ensure_shortcut_slot_visuals()`, set:

```gdscript
		background.texture = TextureManager.try_load("res://assets/textures/tavern/ui/shortcut_slot.png")
```

Keep existing `Icon`, `Count`, and `Label` child creation. Keep `ThemeColors.style_brush_label` for text until a Tavern label helper exists.

- [ ] **Step 3: Add Tavern item icon lookup**

In `scripts/game_manager.gd`, update `try_load_material_icon(key)` so Tavern icons are first:

```gdscript
func try_load_material_icon(key: String) -> Texture2D:
	var tavern_icon := TextureManager.try_load("res://assets/textures/tavern/icons/" + key + ".png")
	if tavern_icon != null:
		return tavern_icon
```

Keep the existing fallback lookup code after this block.

- [ ] **Step 4: Run existing and new workspace tests**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_static_art.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_ryan_slice_assets.tscn
```

Expected: all pass. If `test_ryan_slice_assets` still requires legacy character paths, keep the old files as compatibility aliases or update the test only if the code no longer references them.

- [ ] **Step 5: Commit workspace art hookup**

Run:

```powershell
git add scenes/ui/Tavern.tscn scripts/ui/bar_workspace.gd scripts/game_manager.gd scripts/test/test_ryan_slice_assets.gd
git commit -m "feat: wire Tavern workspace props and icons"
```

Only include `scripts/test/test_ryan_slice_assets.gd` if it was intentionally updated.

---

### Task 9: Wire Inventory and Document Overlays to Tavern Art and Text Safe Areas

**Files:**
- Modify: `scripts/ui/inventory_overlay.gd`
- Modify: `scripts/ui/document_overlay.gd`
- Modify: `scenes/ui/Tavern.tscn` if panel rects need adjustment
- Test: `scripts/test/test_workspace_scene_recovery.gd`, `scripts/test/test_tavern_static_art.gd`

- [ ] **Step 1: Style InventoryOverlay with Tavern art**

In `scripts/ui/inventory_overlay.gd`, replace `_ready()` style setup with:

```gdscript
func _ready() -> void:
	_panel.add_theme_stylebox_override("panel", ThemeColors.tavern_style_box("panel_inventory", 34.0, 36.0, 34.0, 34.0))
	ThemeColors.style_brush_label($Panel/Title, 18, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Panel/MaterialTitle, 16, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Panel/StoryTitle, 16, ThemeColors.AMBER_PRIMARY)
	$Panel/Title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
```

In `_rebuild_list()`, after `row.custom_minimum_size = Vector2(250.0, 34.0)`, add:

```gdscript
		row.add_theme_stylebox_override("normal", ThemeColors.tavern_style_box("list_row", 34.0, 4.0, 10.0, 4.0))
```

- [ ] **Step 2: Replace DocumentOverlay constants**

In `scripts/ui/document_overlay.gd`, replace ledger texture path constants with:

```gdscript
const LEDGER_BACKDROP_TEXTURE := "res://assets/textures/tavern/ui/panel_document.png"
const LEDGER_BUTTON_NAV_LEFT_NORMAL := "res://assets/textures/tavern/ui/button_icon_prev.png"
const LEDGER_BUTTON_NAV_LEFT_HOVER := "res://assets/textures/tavern/ui/button_icon_prev.png"
const LEDGER_BUTTON_NAV_LEFT_PRESSED := "res://assets/textures/tavern/ui/button_icon_prev.png"
const LEDGER_BUTTON_NAV_RIGHT_NORMAL := "res://assets/textures/tavern/ui/button_icon_next.png"
const LEDGER_BUTTON_NAV_RIGHT_HOVER := "res://assets/textures/tavern/ui/button_icon_next.png"
const LEDGER_BUTTON_NAV_RIGHT_PRESSED := "res://assets/textures/tavern/ui/button_icon_next.png"
const LEDGER_BUTTON_CLOSE_NORMAL := "res://assets/textures/tavern/ui/button_wide_normal.png"
const LEDGER_BUTTON_CLOSE_HOVER := "res://assets/textures/tavern/ui/button_wide_hover.png"
const LEDGER_BUTTON_CLOSE_PRESSED := "res://assets/textures/tavern/ui/button_wide_pressed.png"
```

Keep label positions unless text overlaps during verification. The document panel is full-screen, so the new art must preserve the same safe regions.

- [ ] **Step 3: Run overlay regression**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_static_art.tscn
```

Expected: inventory overlay, document overlay, and static art tests pass.

- [ ] **Step 4: Commit overlay art hookup**

Run:

```powershell
git add scripts/ui/inventory_overlay.gd scripts/ui/document_overlay.gd scenes/ui/Tavern.tscn
git commit -m "feat: apply Tavern art to overlays"
```

---

### Task 10: Final Verification and Visual Review

**Files:**
- No required source edits unless verification finds a defect.

- [ ] **Step 1: Run Python asset pipeline tests**

Run:

```powershell
python -m unittest scripts.test.test_tavern_asset_pipeline.TavernAssetPipelineTest -v
```

Expected: PASS.

- [ ] **Step 2: Run focused Godot tests**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_static_art.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_kitchen_containers.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_ryan_slice_assets.tscn
```

Expected: PASS. If the local Godot path differs, use the installed Godot 4.6 console binary and keep the command equivalent.

- [ ] **Step 3: Rescan Godot imports**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --editor --quit --path .
```

Expected: no blocking import errors. Mono `.NET: Assemblies not found` noise is acceptable only if standard editor does not reproduce it.

- [ ] **Step 4: Manual screenshot review**

Launch `scenes/ui/Tavern.tscn` in the editor or via headless screenshot tooling if available. Check:

- The full frame reads as one cohesive dark teal/amber Tavern scene.
- No old checkerboard/gradient placeholder art is visible.
- Customer portrait area is readable and not blocked by background details.
- Order bubble supports a long Chinese order string.
- Top bar text, shortcut labels/counts, menu tabs, recipe rows, inventory rows, and document text do not touch decorative borders.
- Props line up with their collision shapes and current interaction affordances.

- [ ] **Step 5: Inspect git status**

Run:

```powershell
git status --short
```

Expected: only unrelated pre-existing DayMap changes remain, or no Tavern task changes remain uncommitted.

## Self-Review

- Spec coverage: Tasks 1-4 cover retained generated references, native source files, exact nearest runtime exports, transparent alpha assets, and background palette guardrails. Tasks 5-9 cover Godot hookup for background, UI, props, icons, characters, overlays, and text-safe layouts. Task 10 covers Python, Godot, import, and manual visual verification.
- Placeholder scan: This plan contains no TBD/TODO/fill-in placeholders. The only fallback language is explicit runtime fallback behavior for missing textures and legacy compatibility.
- Type consistency: File paths use `assets/source/tavern/` and `assets/textures/tavern/` consistently. Godot helper names are `ThemeColors.tavern_style_box()` and `ThemeColors.tavern_button_style()`. The focused Godot scene is `scenes/test/test_tavern_static_art.tscn`.
