# Mine Investigation AI Item Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the abandoned mine investigation's always-labeled geometric item visuals with AI-sourced native-pixel production item art while preserving all existing investigation logic and node contracts.

**Architecture:** Generate one AI reference sheet for the eight mine investigation props, normalize it through a deterministic manifest-driven pipeline, and export exact `4x` runtime PNGs. Add a compatibility layer to `MineItem` that maps `item_tag` to runtime textures, hides labels only for mapped production art, and falls back to the current `Polygon2D` plus `Label` for unmapped items.

**Tech Stack:** Godot 4.6.3 GDScript, `RigidBody2D` item nodes, Python 3, Pillow, `unittest`, built-in image generation, nearest-neighbor PNG export.

---

## Scope Check

The approved spec covers one bounded surface: `MineInvestigation` item art. It does not include the mine background, Toby lodging, DayMap, DocumentOverlay, or investigation mechanics. This plan keeps the work as one testable project because the AI sheet, asset pipeline, `MineItem` visual adapter, and validation all ship together as one production art path.

## File Structure

Create:

- `art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png`  
  Raw AI-generated source sheet. Never referenced by runtime Godot files.
- `assets/source/investigation/mine_items/reference/mine_item_sheet_v1_reference.png`  
  Stable `2048x1024` reference canvas derived from the raw AI sheet for fixed-grid manifest crops.
- `assets/source/investigation/mine_items/mine_item_art_manifest.json`  
  Manifest with one entry per `MineItem.item_tag`, fixed `source_rect`, native/runtime size, safe area, and intended use.
- `assets/source/investigation/mine_items/*_native.png`  
  Native-pixel production source images.
- `assets/ui/generated/investigation/mine_items/*.png`  
  Runtime images exported only from native files via exact `4x` nearest-neighbor scaling.
- `docs/art/mine_investigation_item_art_contact_sheet.png`  
  Visual QA sheet showing reference, native previews, and runtime previews.
- `scripts/tools/prepare_mine_investigation_item_sources.py`  
  Copies the selected raw AI sheet into a stable reference canvas.
- `scripts/tools/export_mine_investigation_item_assets.py`  
  Reads the manifest, crops fixed rectangles, cleans/quantizes native images, exports runtime images, and writes the contact sheet.
- `scripts/test/test_mine_investigation_item_art_pipeline.py`  
  Asset pipeline contract tests.
- `scripts/test/test_mine_item_visual_contract.gd`  
  Godot contract test for `MineItem` visual fallback and production texture behavior.
- `scenes/test/test_mine_item_visual_contract.tscn`  
  Test scene for the GDScript contract test.

Modify:

- `scripts/ui/components/mine_item.gd`  
  Add a production texture adapter keyed by `item_tag`. Preserve `setup()` signature, child node names, physics shape sizing, and old fallback visuals.

Do not modify:

- `scripts/ui/mine_investigation.gd`
- `scenes/ui/MineInvestigation.tscn`
- `scripts/ui/day_map_view.gd`
- `scripts/game_manager.gd`
- `data/locations.json`

---

### Task 1: Generate and Save the AI Reference Sheet

**Files:**
- Create: `art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png`

- [ ] **Step 1: Generate the source sheet with image generation**

Use the built-in image generation tool with this exact prompt:

```text
Asset sheet for a pixel-game dungeon tavern investigation scene. Eight isolated forensic props in a strict 4 columns by 2 rows grid on a flat pure magenta background (#ff00ff). Top row left to right: broken arrow, dented round shield, lost worn boot, collapsed rubble pile. Bottom row left to right: torn leather backpack, small scattered coins, red axe mercenary token, blood-stained torn paper. No labels, no letters, no numbers, no logos, no UI, no characters, no hands. Dark teal dungeon palette, cold stone dust, old leather, rusted metal, dried dark red blood, sparse amber highlights, rough ink outlines, crisp silhouettes, chunky low-detail shapes suitable for later native-pixel cleanup, orthographic three-quarter tabletop view, high contrast against the magenta background.
```

Reject and regenerate if the sheet contains readable text, character hands, UI frames, labels, or if the eight props are not isolated in a readable grid.

- [ ] **Step 2: Save the approved raw image**

Save the generated image as:

```text
art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png
```

Expected: the raw PNG exists and visually contains exactly the eight requested props.

- [ ] **Step 3: Commit the raw source**

```bash
git add art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png
git commit -m "art: add mine investigation item source sheet"
```

Expected: commit includes only the raw AI source image.

---

### Task 2: Write the Failing Pipeline Test

**Files:**
- Create: `scripts/test/test_mine_investigation_item_art_pipeline.py`

- [ ] **Step 1: Add the test file**

Create `scripts/test/test_mine_investigation_item_art_pipeline.py` with this content:

```python
from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "assets" / "source" / "investigation" / "mine_items" / "reference" / "mine_item_sheet_v1_reference.png"
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_items"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_items"
MANIFEST = SOURCE / "mine_item_art_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_item_art_contact_sheet.png"
SCALE = 4

EXPECTED_ITEMS = {
    "broken_arrow": (24, 12),
    "dented_shield": (32, 32),
    "lost_boot": (28, 18),
    "rubble": (60, 45),
    "torn_backpack": (36, 28),
    "coins": (10, 10),
    "warhammer_token": (14, 14),
    "bloodied_paper": (20, 26),
}


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.copy()


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    return sum(alpha.histogram()[1:])


def alpha_bbox_size(image: Image.Image) -> tuple[int, int]:
    box = image.convert("RGBA").getchannel("A").getbbox()
    if box is None:
        return (0, 0)
    return (box[2] - box[0], box[3] - box[1])


class MineInvestigationItemArtPipelineTest(unittest.TestCase):
    def test_manifest_has_all_contract_items(self) -> None:
        self.assertTrue(MANIFEST.exists(), "mine item art manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        entries = manifest.get("items", [])
        by_id = {entry.get("id"): entry for entry in entries}
        self.assertEqual(set(EXPECTED_ITEMS), set(by_id), "manifest item ids must match MineInvestigation item tags")
        self.assertEqual(manifest.get("scale"), SCALE, "manifest scale must be 4")
        self.assertEqual(manifest.get("reference"), str(REFERENCE.relative_to(ROOT)).replace("\\", "/"))

        for item_id, native_size in EXPECTED_ITEMS.items():
            entry = by_id[item_id]
            self.assertEqual(entry.get("native_size"), list(native_size), f"{item_id}: wrong native size")
            self.assertEqual(entry.get("runtime_size"), [native_size[0] * SCALE, native_size[1] * SCALE], f"{item_id}: wrong runtime size")
            self.assertEqual(len(entry.get("source_rect", [])), 4, f"{item_id}: source_rect must be explicit")
            self.assertEqual(len(entry.get("safe_area", [])), 4, f"{item_id}: safe_area must be explicit")
            self.assertIn("intended_godot_use", entry, f"{item_id}: missing intended Godot use")

    def test_reference_and_contact_sheet_exist(self) -> None:
        self.assertTrue(REFERENCE.exists(), "stable reference sheet is missing")
        reference = load_image(REFERENCE)
        self.assertEqual(reference.size, (2048, 1024), "stable reference sheet must be 2048x1024 for fixed 4x2 crops")
        self.assertTrue(CONTACT_SHEET.exists(), "contact sheet is missing")
        contact = load_image(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 900, "contact sheet is too narrow to review")
        self.assertGreaterEqual(contact.height, 600, "contact sheet is too short to review")

    def test_native_and_runtime_assets_are_valid(self) -> None:
        for item_id, native_size in EXPECTED_ITEMS.items():
            native_path = SOURCE / f"{item_id}_native.png"
            runtime_path = RUNTIME / f"{item_id}.png"
            self.assertTrue(native_path.exists(), f"{item_id}: native file missing")
            self.assertTrue(runtime_path.exists(), f"{item_id}: runtime file missing")

            native = load_image(native_path).convert("RGBA")
            runtime = load_image(runtime_path).convert("RGBA")
            self.assertEqual(native.size, native_size, f"{item_id}: native size mismatch")
            self.assertEqual(runtime.size, (native.width * SCALE, native.height * SCALE), f"{item_id}: runtime size mismatch")
            self.assertEqual(runtime.tobytes(), native.resize(runtime.size, Image.Resampling.NEAREST).tobytes(), f"{item_id}: runtime is not exact nearest-neighbor export")

            alpha_extrema = native.getchannel("A").getextrema()
            self.assertEqual(alpha_extrema[0], 0, f"{item_id}: native needs transparent pixels")
            self.assertGreater(alpha_extrema[1], 0, f"{item_id}: native has no visible pixels")
            self.assertGreaterEqual(visible_pixel_count(native), max(12, native.width * native.height // 8), f"{item_id}: too few visible pixels")
            bbox_width, bbox_height = alpha_bbox_size(native)
            self.assertGreaterEqual(bbox_width, max(4, native.width // 3), f"{item_id}: alpha bbox too narrow")
            self.assertGreaterEqual(bbox_height, max(4, native.height // 3), f"{item_id}: alpha bbox too short")

    def test_runtime_files_do_not_reference_raw_sources(self) -> None:
        forbidden = [
            "art_sources/generated_raw/mine_investigation",
            "assets/source/investigation/mine_items/reference",
            "mine_item_sheet_v1.png",
        ]
        checked_roots = [ROOT / "scripts" / "ui", ROOT / "scenes" / "ui"]
        for root in checked_roots:
            for path in root.rglob("*"):
                if path.suffix not in {".gd", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                for marker in forbidden:
                    self.assertNotIn(marker, text.replace("\\", "/"), f"{path.relative_to(ROOT)} references raw/reference art")


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
python scripts/test/test_mine_investigation_item_art_pipeline.py
```

Expected: FAIL because `mine_item_art_manifest.json`, native PNGs, runtime PNGs, and contact sheet do not exist yet.

- [ ] **Step 3: Commit the failing test**

```bash
git add scripts/test/test_mine_investigation_item_art_pipeline.py
git commit -m "test: cover mine investigation item art pipeline"
```

Expected: commit contains only the new Python test.

---

### Task 3: Add Prepare Script and Manifest

**Files:**
- Create: `scripts/tools/prepare_mine_investigation_item_sources.py`
- Create: `assets/source/investigation/mine_items/mine_item_art_manifest.json`
- Create: `assets/source/investigation/mine_items/reference/mine_item_sheet_v1_reference.png`

- [ ] **Step 1: Add the prepare script**

Create `scripts/tools/prepare_mine_investigation_item_sources.py`:

```python
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "mine_investigation" / "mine_item_sheet_v1.png"
REFERENCE = ROOT / "assets" / "source" / "investigation" / "mine_items" / "reference" / "mine_item_sheet_v1_reference.png"
REFERENCE_SIZE = (2048, 1024)


def build_reference(raw: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", REFERENCE_SIZE, (255, 0, 255, 255))
    fitted = ImageOps.contain(raw.convert("RGBA"), REFERENCE_SIZE, Image.Resampling.LANCZOS)
    x = (REFERENCE_SIZE[0] - fitted.width) // 2
    y = (REFERENCE_SIZE[1] - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def main() -> None:
    if not RAW.exists():
        raise FileNotFoundError(f"missing raw mine item sheet: {RAW}")
    with Image.open(RAW) as raw:
        reference = build_reference(raw)
    REFERENCE.parent.mkdir(parents=True, exist_ok=True)
    reference.save(REFERENCE)
    print(f"prepared mine item reference: {REFERENCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run prepare script**

```bash
python scripts/tools/prepare_mine_investigation_item_sources.py
```

Expected: prints `prepared mine item reference: assets\source\investigation\mine_items\reference\mine_item_sheet_v1_reference.png`.

- [ ] **Step 3: Add the manifest**

Create `assets/source/investigation/mine_items/mine_item_art_manifest.json`:

```json
{
  "reference": "assets/source/investigation/mine_items/reference/mine_item_sheet_v1_reference.png",
  "scale": 4,
  "background_rgb": [255, 0, 255],
  "background_tolerance": 58,
  "items": [
    {
      "id": "broken_arrow",
      "source": "art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png",
      "source_rect": [0, 0, 512, 512],
      "native": "assets/source/investigation/mine_items/broken_arrow_native.png",
      "runtime": "assets/ui/generated/investigation/mine_items/broken_arrow.png",
      "native_size": [24, 12],
      "runtime_size": [96, 48],
      "safe_area": [2, 1, 22, 11],
      "intended_godot_use": "MineItem visual texture for broken_arrow observation prop"
    },
    {
      "id": "dented_shield",
      "source": "art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png",
      "source_rect": [512, 0, 512, 512],
      "native": "assets/source/investigation/mine_items/dented_shield_native.png",
      "runtime": "assets/ui/generated/investigation/mine_items/dented_shield.png",
      "native_size": [32, 32],
      "runtime_size": [128, 128],
      "safe_area": [3, 3, 29, 29],
      "intended_godot_use": "MineItem visual texture for dented_shield observation prop"
    },
    {
      "id": "lost_boot",
      "source": "art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png",
      "source_rect": [1024, 0, 512, 512],
      "native": "assets/source/investigation/mine_items/lost_boot_native.png",
      "runtime": "assets/ui/generated/investigation/mine_items/lost_boot.png",
      "native_size": [28, 18],
      "runtime_size": [112, 72],
      "safe_area": [2, 2, 26, 17],
      "intended_godot_use": "MineItem visual texture for lost_boot observation prop"
    },
    {
      "id": "rubble",
      "source": "art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png",
      "source_rect": [1536, 0, 512, 512],
      "native": "assets/source/investigation/mine_items/rubble_native.png",
      "runtime": "assets/ui/generated/investigation/mine_items/rubble.png",
      "native_size": [60, 45],
      "runtime_size": [240, 180],
      "safe_area": [4, 4, 56, 42],
      "intended_godot_use": "MineItem visual texture for rubble reveal blocker"
    },
    {
      "id": "torn_backpack",
      "source": "art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png",
      "source_rect": [0, 512, 512, 512],
      "native": "assets/source/investigation/mine_items/torn_backpack_native.png",
      "runtime": "assets/ui/generated/investigation/mine_items/torn_backpack.png",
      "native_size": [36, 28],
      "runtime_size": [144, 112],
      "safe_area": [3, 3, 33, 26],
      "intended_godot_use": "MineItem visual texture for torn_backpack spill container"
    },
    {
      "id": "coins",
      "source": "art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png",
      "source_rect": [512, 512, 512, 512],
      "native": "assets/source/investigation/mine_items/coins_native.png",
      "runtime": "assets/ui/generated/investigation/mine_items/coins.png",
      "native_size": [10, 10],
      "runtime_size": [40, 40],
      "safe_area": [1, 1, 9, 9],
      "intended_godot_use": "MineItem visual texture for spilled coins"
    },
    {
      "id": "warhammer_token",
      "source": "art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png",
      "source_rect": [1024, 512, 512, 512],
      "native": "assets/source/investigation/mine_items/warhammer_token_native.png",
      "runtime": "assets/ui/generated/investigation/mine_items/warhammer_token.png",
      "native_size": [14, 14],
      "runtime_size": [56, 56],
      "safe_area": [1, 1, 13, 13],
      "intended_godot_use": "MineItem visual texture for blood axe mercenary token"
    },
    {
      "id": "bloodied_paper",
      "source": "art_sources/generated_raw/mine_investigation/mine_item_sheet_v1.png",
      "source_rect": [1536, 512, 512, 512],
      "native": "assets/source/investigation/mine_items/bloodied_paper_native.png",
      "runtime": "assets/ui/generated/investigation/mine_items/bloodied_paper.png",
      "native_size": [20, 26],
      "runtime_size": [80, 104],
      "safe_area": [2, 2, 18, 24],
      "intended_godot_use": "MineItem visual texture for bloodied contract pickup"
    }
  ]
}
```

- [ ] **Step 4: Run the pipeline test and verify it still fails later**

```bash
python scripts/test/test_mine_investigation_item_art_pipeline.py
```

Expected: FAIL because native PNGs, runtime PNGs, and contact sheet do not exist yet. Manifest and reference assertions should now pass.

- [ ] **Step 5: Commit prepare script, manifest, and reference**

```bash
git add scripts/tools/prepare_mine_investigation_item_sources.py assets/source/investigation/mine_items/mine_item_art_manifest.json assets/source/investigation/mine_items/reference/mine_item_sheet_v1_reference.png
git commit -m "build: prepare mine investigation item references"
```

Expected: commit contains only the prepare script, manifest, and stable reference sheet.

---

### Task 4: Implement the Exporter and Generate Production Assets

**Files:**
- Create: `scripts/tools/export_mine_investigation_item_assets.py`
- Create: `assets/source/investigation/mine_items/*_native.png`
- Create: `assets/ui/generated/investigation/mine_items/*.png`
- Create: `docs/art/mine_investigation_item_art_contact_sheet.png`

- [ ] **Step 1: Add the export script**

Create `scripts/tools/export_mine_investigation_item_assets.py`:

```python
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_items"
MANIFEST = SOURCE / "mine_item_art_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_item_art_contact_sheet.png"


def load_manifest() -> dict[str, Any]:
    if not MANIFEST.exists():
        raise FileNotFoundError(f"missing manifest: {MANIFEST}")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def remove_chroma_background(image: Image.Image, background_rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    br, bg, bb = background_rgb
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            distance = abs(r - br) + abs(g - bg) + abs(b - bb)
            if a == 0 or distance <= tolerance:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, 255)
    return rgba


def quantize_visible(image: Image.Image, colors: int = 18) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha.point(lambda value: 255 if value >= 96 else 0))
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return quantized


def fit_to_native(crop: Image.Image, native_size: tuple[int, int], background_rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    clean = remove_chroma_background(crop, background_rgb, tolerance)
    alpha_box = clean.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("crop has no visible pixels after chroma cleanup")
    trimmed = clean.crop(alpha_box)
    padded_size = (max(1, native_size[0] - 2), max(1, native_size[1] - 2))
    fitted = ImageOps.contain(trimmed, padded_size, Image.Resampling.LANCZOS)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    x = (native.width - fitted.width) // 2
    y = (native.height - fitted.height) // 2
    native.alpha_composite(fitted, (x, y))
    return quantize_visible(native)


def validate_native(item_id: str, native: Image.Image, native_size: tuple[int, int]) -> None:
    if native.size != native_size:
        raise ValueError(f"{item_id}: native size {native.size} != {native_size}")
    alpha = native.getchannel("A")
    alpha_min, alpha_max = alpha.getextrema()
    if alpha_min != 0 or alpha_max == 0:
        raise ValueError(f"{item_id}: native needs transparent and visible pixels")
    if alpha.getbbox() is None:
        raise ValueError(f"{item_id}: native alpha bbox is empty")


def export_item(reference: Image.Image, item: dict[str, Any], background_rgb: tuple[int, int, int], tolerance: int, scale: int) -> tuple[Image.Image, Image.Image]:
    x, y, width, height = item["source_rect"]
    crop = reference.crop((x, y, x + width, y + height))
    native_size = tuple(item["native_size"])
    runtime_size = tuple(item["runtime_size"])
    native = fit_to_native(crop, native_size, background_rgb, tolerance)
    validate_native(item["id"], native, native_size)
    runtime = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
    if runtime.size != runtime_size:
        raise ValueError(f"{item['id']}: runtime size {runtime.size} != {runtime_size}")
    expected = native.resize(runtime.size, Image.Resampling.NEAREST)
    if runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{item['id']}: runtime is not exact nearest-neighbor output")
    return native, runtime


def make_contact_sheet(reference: Image.Image, outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    cell_width = 220
    cell_height = 184
    sheet = Image.new("RGBA", (cell_width * 4, 96 + cell_height * 2), (18, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((18, 16), "Mine investigation AI item art pipeline", fill=(226, 210, 178, 255))
    draw.text((18, 42), "top: native 4x preview / bottom: runtime preview source parity", fill=(169, 151, 124, 255))
    for index, (item, native, runtime) in enumerate(outputs):
        column = index % 4
        row = index // 4
        origin_x = column * cell_width + 14
        origin_y = 78 + row * cell_height
        draw.text((origin_x, origin_y), item["id"], fill=(226, 210, 178, 255))
        native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
        native_preview = ImageOps.contain(native_preview, (180, 70), Image.Resampling.NEAREST)
        runtime_preview = ImageOps.contain(runtime, (180, 70), Image.Resampling.NEAREST)
        sheet.alpha_composite(native_preview, (origin_x, origin_y + 24))
        sheet.alpha_composite(runtime_preview, (origin_x, origin_y + 104))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    manifest = load_manifest()
    scale = int(manifest["scale"])
    background_rgb = tuple(manifest["background_rgb"])
    tolerance = int(manifest["background_tolerance"])
    reference_path = ROOT / manifest["reference"]
    if not reference_path.exists():
        raise FileNotFoundError(f"missing reference sheet: {reference_path}")
    reference = Image.open(reference_path).convert("RGBA")

    outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]] = []
    for item in manifest["items"]:
        native, runtime = export_item(reference, item, background_rgb, tolerance, scale)
        native_path = ROOT / item["native"]
        runtime_path = ROOT / item["runtime"]
        native_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        native.save(native_path)
        runtime.save(runtime_path)
        outputs.append((item, native, runtime))
        print(f"{item['id']}: {native.size} -> {runtime.size}")
    make_contact_sheet(reference, outputs)
    print(f"contact sheet: {CONTACT_SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the exporter**

```bash
python scripts/tools/export_mine_investigation_item_assets.py
```

Expected: prints one line per item and `contact sheet: docs\art\mine_investigation_item_art_contact_sheet.png`.

- [ ] **Step 3: Run the pipeline test**

```bash
python scripts/test/test_mine_investigation_item_art_pipeline.py
```

Expected: PASS.

- [ ] **Step 4: Inspect the contact sheet**

Open `docs/art/mine_investigation_item_art_contact_sheet.png`. Confirm:

- no readable text in item art;
- `bloodied_paper` is the clearest clue;
- `rubble` is the largest obstacle;
- all props are readable without item labels;
- palette stays cold/dark with sparse amber.

- [ ] **Step 5: Commit exporter and generated production assets**

```bash
git add scripts/tools/export_mine_investigation_item_assets.py assets/source/investigation/mine_items assets/ui/generated/investigation/mine_items docs/art/mine_investigation_item_art_contact_sheet.png
git commit -m "art: export mine investigation item textures"
```

Expected: commit includes exporter, manifest if modified by review, native assets, runtime assets, and contact sheet.

---

### Task 5: Add MineItem Visual Contract Test

**Files:**
- Create: `scripts/test/test_mine_item_visual_contract.gd`
- Create: `scenes/test/test_mine_item_visual_contract.tscn`

- [ ] **Step 1: Add the GDScript test**

Create `scripts/test/test_mine_item_visual_contract.gd`:

```gdscript
extends Node

const MINE_ITEM_SCENE := preload("res://scenes/ui/components/MineItem.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_production_item_hides_debug_visuals()
	_test_unknown_item_keeps_legacy_visuals()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MINE-ITEM-VISUAL] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MINE-ITEM-VISUAL] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MINE-ITEM-VISUAL] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _spawn_item() -> MineItem:
	var item: MineItem = MINE_ITEM_SCENE.instantiate()
	add_child(item)
	return item


func _test_production_item_hides_debug_visuals() -> void:
	var item := _spawn_item()
	item.setup("broken_arrow", "observation", Vector2(48, 16), Color.RED, "debug label", "observation")
	_ok(item.get_node_or_null("Shape") is CollisionShape2D, "Shape node is preserved")
	_ok(item.get_node_or_null("Visual") is Polygon2D, "Visual node is preserved")
	_ok(item.get_node_or_null("Label") is Label, "Label node is preserved")
	_ok(item.get_node_or_null("TextureVisual") is Sprite2D, "production item creates TextureVisual")
	_ok(not item.get_node("Visual").visible, "production item hides polygon debug visual")
	_ok(not item.get_node("Label").visible, "production item hides always-on debug label")
	var sprite := item.get_node("TextureVisual") as Sprite2D
	_ok(sprite.visible, "production sprite is visible")
	_ok(sprite.texture != null, "production sprite has texture")
	_ok(item.item_tag == "broken_arrow", "item_tag contract remains set by setup")
	_ok(item.kind == "observation", "kind contract remains set by setup")
	item.queue_free()


func _test_unknown_item_keeps_legacy_visuals() -> void:
	var item := _spawn_item()
	item.setup("unmapped_debug_item", "plain", Vector2(32, 32), Color.GREEN, "debug label", "")
	_ok(item.get_node("Visual").visible, "unmapped item keeps polygon visual")
	_ok(item.get_node("Label").visible, "unmapped item keeps debug label")
	_ok(item.get_node_or_null("TextureVisual") == null or not item.get_node("TextureVisual").visible, "unmapped item does not show production sprite")
	item.queue_free()
```

- [ ] **Step 2: Add the test scene**

Create `scenes/test/test_mine_item_visual_contract.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_mine_item_visual_contract.gd" id="1"]

[node name="TestMineItemVisualContract" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: Run the test and verify it fails**

```bash
godot --headless --path . scenes/test/test_mine_item_visual_contract.tscn
```

Expected: FAIL because `MineItem` does not create `TextureVisual` and still shows the debug label.

- [ ] **Step 4: Commit the failing Godot test**

```bash
git add scripts/test/test_mine_item_visual_contract.gd scenes/test/test_mine_item_visual_contract.tscn
git commit -m "test: cover mine item texture visual contract"
```

Expected: commit includes only the new GDScript test and scene.

---

### Task 6: Implement MineItem Texture Adapter

**Files:**
- Modify: `scripts/ui/components/mine_item.gd`

- [ ] **Step 1: Update `MineItem` with a texture map and adapter**

Modify `scripts/ui/components/mine_item.gd` so the complete file reads:

```gdscript
class_name MineItem
extends RigidBody2D

## 矿道场景的可拾取物件。生产美术按 item_tag 走纹理映射；
## 未映射物件保留旧 Polygon2D + Label 调试外观。
## kind: "observation"=捡起给一句台词；"contract"=捡起触发授予；"rubble"=可扒开的遮蔽物；
##       "backpack"=可倾倒的容器；"plain"=纯洒落物，无特殊效果。

const ITEM_TEXTURES := {
	"broken_arrow": "res://assets/ui/generated/investigation/mine_items/broken_arrow.png",
	"dented_shield": "res://assets/ui/generated/investigation/mine_items/dented_shield.png",
	"lost_boot": "res://assets/ui/generated/investigation/mine_items/lost_boot.png",
	"rubble": "res://assets/ui/generated/investigation/mine_items/rubble.png",
	"torn_backpack": "res://assets/ui/generated/investigation/mine_items/torn_backpack.png",
	"coins": "res://assets/ui/generated/investigation/mine_items/coins.png",
	"warhammer_token": "res://assets/ui/generated/investigation/mine_items/warhammer_token.png",
	"bloodied_paper": "res://assets/ui/generated/investigation/mine_items/bloodied_paper.png",
}

@onready var _shape: CollisionShape2D = $Shape
@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $Label

var item_tag: String = ""
var kind: String = "plain"
var observation: String = ""
var _texture_visual: Sprite2D = null


func setup(p_tag: String, p_kind: String, p_size: Vector2, p_color: Color, p_label: String, p_observation: String = "") -> void:
	item_tag = p_tag
	kind = p_kind
	observation = p_observation
	var hx := p_size.x * 0.5
	var hy := p_size.y * 0.5
	# 每个实例独立的碰撞形状——.tscn 里的 sub_resource 在多实例间默认共享，
	# 原地改 size 会牵连其他 MineItem；这里换成全新 RectangleShape2D 隔离。
	var rect := RectangleShape2D.new()
	rect.size = p_size
	_shape.shape = rect
	_visual.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	_visual.color = p_color
	_label.text = p_label
	_label.position = Vector2(-hx, -hy - 18.0)
	_apply_texture_visual(p_tag, p_size)


func _apply_texture_visual(p_tag: String, p_size: Vector2) -> void:
	var path: String = String(ITEM_TEXTURES.get(p_tag, ""))
	if path == "":
		_show_legacy_visual()
		return
	var texture := load(path)
	if not (texture is Texture2D):
		push_warning("MineItem texture missing or invalid for %s: %s" % [p_tag, path])
		_show_legacy_visual()
		return
	_ensure_texture_visual()
	_texture_visual.texture = texture
	_texture_visual.visible = true
	_texture_visual.z_index = _visual.z_index + 1
	var texture_size := texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		_texture_visual.scale = Vector2(p_size.x / texture_size.x, p_size.y / texture_size.y)
	else:
		_texture_visual.scale = Vector2.ONE
	_visual.visible = false
	_label.visible = false


func _ensure_texture_visual() -> void:
	if _texture_visual != null:
		return
	_texture_visual = Sprite2D.new()
	_texture_visual.name = "TextureVisual"
	_texture_visual.centered = true
	_texture_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_texture_visual)


func _show_legacy_visual() -> void:
	_visual.visible = true
	_label.visible = true
	if _texture_visual != null:
		_texture_visual.visible = false
```

- [ ] **Step 2: Run the visual contract test**

```bash
godot --headless --path . scenes/test/test_mine_item_visual_contract.tscn
```

Expected: PASS.

- [ ] **Step 3: Run existing investigation tests**

```bash
godot --headless --path . scenes/test/test_mine_investigation.tscn
godot --headless --path . scenes/test/test_toby_lodging_investigation.tscn
```

Expected: both PASS. Toby items use unmapped `contract_fragment` and keep fallback visuals.

- [ ] **Step 4: Commit MineItem adapter**

```bash
git add scripts/ui/components/mine_item.gd
git commit -m "feat: map mine items to production textures"
```

Expected: commit includes only `scripts/ui/components/mine_item.gd`.

---

### Task 7: Full Verification and Runtime Review

**Files:**
- Read: `docs/art/mine_investigation_item_art_contact_sheet.png`
- Read: Godot headless outputs

- [ ] **Step 1: Run all mine item art tests**

```bash
python scripts/test/test_mine_investigation_item_art_pipeline.py
godot --headless --path . scenes/test/test_mine_item_visual_contract.tscn
godot --headless --path . scenes/test/test_mine_investigation.tscn
godot --headless --path . scenes/test/test_toby_lodging_investigation.tscn
```

Expected: all PASS.

- [ ] **Step 2: Run a status check**

```bash
git status --short
```

Expected: only intentional generated files remain uncommitted. If files outside the plan are listed, leave them untouched and mention them in the handoff.

- [ ] **Step 3: Review runtime scene manually**

Open `scenes/ui/MineInvestigation.tscn` in Godot or run the DayMap path in the editor. Verify:

- production item sprites appear in the abandoned mine scene;
- no always-on item labels are visible for the eight mapped mine items;
- item pickup, rubble reveal, backpack spill, and bloodied paper pickup still work;
- observation text still appears in `UI/ObservationLabel`;
- `UI/LeaveButton` remains unchanged.

- [ ] **Step 4: Capture final evidence**

Record:

- exact test commands and PASS/FAIL output summaries;
- contact sheet path;
- any unrelated dirty worktree entries that were present before this work.

No commit is required in this task if Tasks 1 through 6 already committed their changes. If Task 7 uncovers small visual-export tuning, rerun Task 4 exporter, rerun all tests, and commit with:

```bash
git add assets/source/investigation/mine_items assets/ui/generated/investigation/mine_items docs/art/mine_investigation_item_art_contact_sheet.png
git commit -m "art: tune mine investigation item readability"
```

Expected: final worktree still contains no uncommitted files from this feature.

---

## Self-Review

Spec coverage:

- All eight item tags are covered by the AI sheet, manifest, exporter, tests, runtime texture map, and contact sheet.
- AI images remain raw/reference only; runtime paths point to `assets/ui/generated/investigation/mine_items/`.
- `MineItem.setup()` signature and child contracts are preserved.
- Always-on labels are hidden only for mapped production textures; fallback behavior remains for Toby and debug items.
- Background, DayMap, DocumentOverlay, GameManager, and location data stay out of scope.

Type consistency:

- Manifest ids match the exact tags used in `scripts/ui/mine_investigation.gd`: `broken_arrow`, `dented_shield`, `lost_boot`, `rubble`, `torn_backpack`, `coins`, `warhammer_token`, `bloodied_paper`.
- GDScript test expects `TextureVisual`, matching the node name created by `MineItem._ensure_texture_visual()`.
- Runtime texture paths in tests and `MineItem.ITEM_TEXTURES` both use `res://assets/ui/generated/investigation/mine_items/`.

Execution order:

- The failing Python test lands before the exporter.
- The generated production assets land before `MineItem` tries to load them.
- The failing Godot contract test lands before the adapter implementation.
- Existing mine and Toby investigation tests run after the shared `MineItem` change.

