# Intro Second Beat Redraw Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace only `intro_hearth_memory` with a title-screen-matched redraw that preserves the approved cinematic composition, fixes the left doorway, and retains the crowded tavern scale.

**Architecture:** Generate versioned high-resolution candidates by editing the current approved second-beat reference with the title composite as the style reference. Add a tested single-still preparation path so candidate iteration rebuilds only `intro_hearth_memory_native.png`; promote a candidate only after full-size and `320x180` visual review, then export the runtime texture through the existing exact-nearest pipeline.

**Tech Stack:** Built-in image generation/editing, PNG, Python 3, Pillow, `unittest`, Godot 4.6.

---

## File Map

- Approved design: `docs/superpowers/specs/2026-06-07-intro-second-beat-redraw-design.md`
- Composition edit target: `assets/source/intro/reference/intro_hearth_memory.png`
- Style reference: `assets/source/title/reference/title_pixel_composite_reference.png`
- Versioned candidates: `assets/source/intro/reference/intro_hearth_memory-v3.png`, `intro_hearth_memory-v4.png`
- Approved reference after review: `assets/source/intro/reference/intro_hearth_memory.png`
- Native output: `assets/source/intro/intro_hearth_memory_native.png`
- Runtime output: `assets/textures/intro/intro_hearth_memory.png`
- Native preparation: `scripts/tools/prepare_intro_sources.py`
- Runtime export: `scripts/tools/export_intro_assets.py`
- Pipeline tests: `scripts/test/test_intro_asset_pipeline.py`

### Task 1: Add a Single-Still Native Build Path

**Files:**
- Modify: `scripts/tools/prepare_intro_sources.py`
- Test: `scripts/test/test_intro_asset_pipeline.py`

- [ ] **Step 1: Write the failing single-still test**

Add imports:

```python
from unittest.mock import patch

from scripts.tools.prepare_intro_sources import prepare_named_outputs
```

Add this test:

```python
def test_prepare_named_outputs_builds_only_requested_still(self) -> None:
    sentinel = Image.new("RGBA", NATIVE_SIZE, (12, 24, 36, 255))
    with patch(
        "scripts.tools.prepare_intro_sources.build_native",
        return_value=sentinel,
    ) as build_native_mock, patch(
        "scripts.tools.prepare_intro_sources.validate_still",
    ) as validate_still_mock:
        outputs = prepare_named_outputs(["intro_hearth_memory"])

    self.assertEqual(
        list(outputs),
        [SOURCE / "intro_hearth_memory_native.png"],
    )
    self.assertIs(outputs[SOURCE / "intro_hearth_memory_native.png"], sentinel)
    build_native_mock.assert_called_once_with("intro_hearth_memory")
    validate_still_mock.assert_called_once_with("intro_hearth_memory", sentinel)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline.IntroAssetPipelineTest.test_prepare_named_outputs_builds_only_requested_still -v
```

Expected: import failure because `prepare_named_outputs` does not exist.

- [ ] **Step 3: Implement the minimal named-output function**

Add to `scripts/tools/prepare_intro_sources.py`:

```python
def prepare_named_outputs(names: list[str]) -> dict[Path, Image.Image]:
    unknown = [name for name in names if name not in STILLS]
    if unknown:
        raise ValueError(f"Unknown intro stills: {', '.join(unknown)}")

    outputs: dict[Path, Image.Image] = {}
    for name in names:
        image = build_native(name)
        validate_still(name, image)
        outputs[SOURCE / f"{name}_native.png"] = image
    return outputs
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline.IntroAssetPipelineTest.test_prepare_named_outputs_builds_only_requested_still -v
```

Expected: `OK`.

- [ ] **Step 5: Add failure coverage for unknown names**

Add:

```python
def test_prepare_named_outputs_rejects_unknown_still(self) -> None:
    with self.assertRaisesRegex(ValueError, "Unknown intro stills: missing"):
        prepare_named_outputs(["missing"])
```

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline.IntroAssetPipelineTest.test_prepare_named_outputs_rejects_unknown_still -v
```

Expected: `OK`.

- [ ] **Step 6: Commit the focused preparation API**

```powershell
git add -- scripts/tools/prepare_intro_sources.py scripts/test/test_intro_asset_pipeline.py
git commit -m "feat(intro): prepare individual still assets"
```

### Task 2: Generate Composition-Locked Redraw Candidates

**Files:**
- Read: `assets/source/intro/reference/intro_hearth_memory.png`
- Read: `assets/source/title/reference/title_pixel_composite_reference.png`
- Read: `docs/superpowers/specs/2026-06-07-intro-second-beat-redraw-design.md`
- Create: `assets/source/intro/reference/intro_hearth_memory-v3.png`
- Create if needed: `assets/source/intro/reference/intro_hearth_memory-v4.png`

- [ ] **Step 1: Load both input images into visual context**

Treat `intro_hearth_memory.png` as the edit target and strict composition template. Treat `title_pixel_composite_reference.png` only as the palette, pixel-cluster, edge, and lighting style reference.

- [ ] **Step 2: Generate the first edited candidate**

Use built-in image editing with this production prompt:

```text
Use case: style-transfer
Asset type: 16:9 game cinematic still reference
Primary request: Redraw the edit target in the exact visual language of the title-screen reference while preserving the edit target's composition.
Input images: Image 1 is the edit target and strict composition template; Image 2 is the strict style reference.
Composition/framing: Preserve Image 1's camera height, central hearth position and size, floor vanishing path, crowded table distribution, right-side shelving, ceiling beams, chandelier position, and foreground/midground/background rhythm. Change only the left entrance structure: remove the oversized wooden door slab and replace it with a thick dark stone doorway frame plus a very narrow shadowed door edge.
Subjects: Keep approximately 10 to 14 patrons in the existing crowded distribution. Render them as broad anonymous silhouette groups with only readable head-and-shoulder, seated, standing, side-facing, and back-facing shapes.
Style/medium: Hand-authored dark fantasy pixel illustration designed for later cleanup on a 320x180 native grid. Match Image 2's low-density chunky pixel clusters, stepped edges, large flat masses, hard-edged shadows, and sparse grouped highlights.
Lighting/mood: The central hearth is the only strong amber focal point. Keep the chandelier, wall lamps, and table candles as dim secondary marks. Preserve the solemn, ancient, crowded last-drink atmosphere and cinematic depth.
Color palette: Dark teal, blue-green black, coal black, muted brown, and restrained amber.
Constraints: Preserve composition before style. No text, logo, UI, border, or watermark.
Avoid: large visible door slab, changed camera, moved or resized hearth, altered vanishing path, sparse seating, four-person tavern, detailed faces, costume detail, individual bottle rendering, photorealism, oil painting, cinematic photography, smooth gradients, bloom, volumetric light, depth of field, detailed stone texture, detailed wood grain, orange wash, dithering, or high-frequency noise.
```

- [ ] **Step 3: Save the candidate non-destructively**

Copy the generated file into:

```text
assets/source/intro/reference/intro_hearth_memory-v3.png
```

Do not overwrite `intro_hearth_memory.png`.

- [ ] **Step 4: Review against the fixed rejection list**

Reject the candidate if any item is true:

```text
- The central hearth, floor path, crowd masses, tables, shelves, or chandelier drift visibly from the edit target.
- A large wooden door slab remains on the left.
- The doorway becomes bright or competes with the hearth.
- The crowd reads as fewer than about 10 people or as isolated character portraits.
- Faces, costumes, bottles, stone, or wood regain high-frequency detail.
- The image looks like realistic concept art with a pixel filter.
- Amber spreads across most of the image.
- The lower narration area contains a new key focal point.
```

- [ ] **Step 5: Make at most one targeted regeneration**

If the first candidate fails, generate `intro_hearth_memory-v4.png` by repeating all invariants and changing only the failed property. Do not broaden the prompt or redesign the room.

- [ ] **Step 6: Present passing candidate at full size**

Show the candidate and report which invariants passed. Do not promote it until the user approves the visual result.

### Task 3: Validate the Candidate at Native Resolution

**Files:**
- Read: approved versioned candidate
- Create temporary review output: `tmp/intro_hearth_memory_candidate_native.png`

- [ ] **Step 1: Build a temporary `320x180` preview without replacing production**

Run:

```powershell
@'
from pathlib import Path
from PIL import Image
from scripts.tools.prepare_intro_sources import grade_native, normalize_reference, quantize_native

source = Path("assets/source/intro/reference/intro_hearth_memory-v3.png")
target = Path("tmp/intro_hearth_memory_candidate_native.png")
target.parent.mkdir(parents=True, exist_ok=True)
with Image.open(source) as image:
    native = quantize_native(
        grade_native(normalize_reference(image.convert("RGB")), "intro_hearth_memory"),
        "intro_hearth_memory",
    )
native.save(target)
print(target)
'@ | python -
```

Use `-v4` instead if that is the passing candidate.

Expected: a `320x180` PNG is written without modifying approved assets.

- [ ] **Step 2: Inspect the native preview**

Reject unless all remain legible at actual size:

```text
- central hearth
- stone floor path
- left doorway frame
- left and right crowd masses
- chandelier silhouette
- right shelving
```

Also reject if the crowd turns into scattered noise, the doorway merges with the wall, or the hearth loses clear dominance.

- [ ] **Step 3: Compare quantitative guardrails**

Run:

```powershell
@'
from pathlib import Path
from PIL import Image
from scripts.tools.prepare_intro_sources import edge_change_ratio, pixel_counts

path = Path("tmp/intro_hearth_memory_candidate_native.png")
with Image.open(path) as image:
    colors = image.convert("RGB").getcolors(maxcolors=65536)
    print("size", image.size)
    print("colors", len(colors) if colors else 65536)
    print("dark_cool_warm", pixel_counts(image))
    print("edge_change_ratio", round(edge_change_ratio(image), 4))
'@ | python -
```

Expected:

```text
size (320, 180)
colors <= 64
dark >= 18000
cool >= 4000
warm >= 200
edge_change_ratio >= 0.08
```

- [ ] **Step 4: Obtain final visual approval**

Show both the full-size candidate and `tmp/intro_hearth_memory_candidate_native.png`. Approval requires both views to pass; full-size quality alone is insufficient.

### Task 4: Promote and Rebuild Only the Second Beat

**Files:**
- Replace after approval: `assets/source/intro/reference/intro_hearth_memory.png`
- Replace: `assets/source/intro/intro_hearth_memory_native.png`
- Replace: `assets/textures/intro/intro_hearth_memory.png`

- [ ] **Step 1: Promote the approved candidate**

Copy the approved versioned candidate over:

```text
assets/source/intro/reference/intro_hearth_memory.png
```

Keep the versioned candidate as provenance.

- [ ] **Step 2: Build and validate only the second native still**

Run:

```powershell
@'
from scripts.tools.prepare_intro_sources import prepare_named_outputs

for path, image in prepare_named_outputs(["intro_hearth_memory"]).items():
    image.save(path)
    print(f"prepared {path}")
'@ | python -
```

Expected: only `assets/source/intro/intro_hearth_memory_native.png` is written.

- [ ] **Step 3: Export runtime assets**

Run:

```powershell
python scripts/tools/export_intro_assets.py
```

Expected: six successful exact-nearest export lines. Verify with `git diff --name-only` that only `assets/textures/intro/intro_hearth_memory.png` changed among runtime stills.

- [ ] **Step 4: Run the pipeline tests**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: all tests pass.

- [ ] **Step 5: Commit the approved second beat**

```powershell
git add -- assets/source/intro/reference/intro_hearth_memory.png assets/source/intro/reference/intro_hearth_memory-v3.png assets/source/intro/reference/intro_hearth_memory-v4.png assets/source/intro/intro_hearth_memory_native.png assets/textures/intro/intro_hearth_memory.png
git commit -m "art(intro): redraw second beat in title style"
```

Omit `-v4.png` if it was not generated.

### Task 5: Verify the Second Beat in Godot

**Files:**
- Verify: `data/intro.json`
- Verify: `scenes/test/test_intro_sequence.tscn`
- Verify: `assets/textures/intro/intro_hearth_memory.png`

- [ ] **Step 1: Run the intro regression scene**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_intro_sequence.tscn'
```

Expected: output contains `[TEST-INTRO] ALL PASS` and no new `SCRIPT ERROR`.

- [ ] **Step 2: Play the opening sequence**

Check the second beat at runtime:

```text
- The first read is the central hearth, not the doorway or chandelier.
- The slow zoom and lateral movement do not expose an edge.
- The narration does not cover the hearth or a newly introduced focal point.
- The crowd still reads as a full tavern at 1280x720.
- The image reads as the title screen's visual family at first glance.
```

- [ ] **Step 3: Correct only reference-level defects**

If runtime review exposes a visual defect, revise the versioned high-resolution reference, repeat native review, then rebuild through the pipeline. Do not paint directly on the runtime PNG.

- [ ] **Step 4: Run final verification**

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_intro_sequence.tscn'
```

Expected: Python suite passes and Godot prints `[TEST-INTRO] ALL PASS`.
