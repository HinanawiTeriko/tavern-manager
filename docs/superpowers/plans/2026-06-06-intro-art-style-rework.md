# Intro Art Style Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the five overly realistic intro references with title-screen-matched pixel illustrations, then rebuild and verify the existing native and runtime assets.

**Architecture:** The user generates reference candidates in controlled batches using the approved prompts. Codex reviews composition, style, and continuity before any candidate replaces an approved reference. The existing Pillow pipeline remains responsible only for native-grid normalization, palette unification, exact nearest-neighbor export, and automated validation.

**Tech Stack:** Image generation UI, PNG references, Python 3, Pillow, `unittest`, Godot 4.6.

---

## File Map

- Style reference: `assets/source/title/reference/title_pixel_composite_reference.png`
- Approved design and prompts: `docs/superpowers/specs/2026-06-06-intro-art-pipeline-design.md`
- Candidate and approved inputs: `assets/source/intro/reference/`
- Native outputs: `assets/source/intro/*_native.png`
- Runtime outputs: `assets/textures/intro/*.png`
- Native preparation: `scripts/tools/prepare_intro_sources.py`
- Runtime export: `scripts/tools/export_intro_assets.py`
- Pipeline tests: `scripts/test/test_intro_asset_pipeline.py`
- Playback manifest: `data/intro.json`

### Task 1: Generate the Tavern Continuity Master

**Files:**
- Read: `assets/source/title/reference/title_pixel_composite_reference.png`
- Read: `docs/superpowers/specs/2026-06-06-intro-art-pipeline-design.md`
- Create: `assets/source/intro/reference/tavern_continuity_master-v2.png`
- Create if needed: `assets/source/intro/reference/tavern_continuity_master-v3.png`

- [x] **Step 1: Upload the title composite as the sole style reference**

Use `assets/source/title/reference/title_pixel_composite_reference.png`, not the current realistic intro images.

- [x] **Step 2: Generate two master candidates**

Use the `tavern_continuity_master` scene prompt, followed by the common prompt and common negative prompt from the approved design document. Generate at 16:9 and at least `1280x720`.

- [x] **Step 3: Save candidates without replacing the approved file**

Save the first two viable outputs as:

```text
assets/source/intro/reference/tavern_continuity_master-v2.png
assets/source/intro/reference/tavern_continuity_master-v3.png
```

- [x] **Step 4: Review the candidates with Codex**

Reject a candidate if any of these are true:

```text
- It looks like realistic concept art with a pixel filter.
- Stone, wood, dust, or metal contain dense uniform texture.
- The hearth, left-side door, arch, lantern, tables, and right-side entrance props are not large readable shapes.
- A sign, plaque, banner, interior barrel, or interior crate appears anywhere.
- The exterior mug has two handles, or the exterior barrel has an object on top.
- Amber light spreads across most of the image.
- The composition cannot support both an exterior/entrance view and a threshold-to-hearth view.
- It does not look like the title screen was made by the same artist.
```

- [x] **Step 5: Promote only the approved candidate**

After visual approval, replace:

```text
assets/source/intro/reference/tavern_continuity_master.png
```

Keep rejected and alternate candidates with version suffixes.

- [x] **Step 6: Commit the approved master**

```powershell
git add -- assets/source/intro/reference/tavern_continuity_master.png assets/source/intro/reference/tavern_continuity_master-v*.png
git commit -m "art(intro): approve pixel tavern continuity master"
```

### Task 2: Generate the Interior Spatial Master

**Files:**
- Read: `assets/source/intro/reference/tavern_continuity_master.png`
- Read: `assets/source/title/reference/title_pixel_composite_reference.png`
- Create: `assets/source/intro/reference/tavern_interior_spatial_master-v2.png`
- Replace after approval: `assets/source/intro/reference/tavern_interior_spatial_master.png`

- [ ] **Step 1: Generate an unoccupied interior spatial master**

Use the approved unified interior design. The image must lock the right-rear stone
fireplace, foreground L-shaped bar, left-rear entrance door, sparse left-wall shelves,
top timber beams, central passage, and low-density decoration.

- [ ] **Step 2: Review the master at full and native size**

Reject it unless:

```text
- The fireplace is the primary architectural identity in the right rear.
- The L-shaped bar reads clearly and can support a future behind-the-bar camera.
- The left entrance door matches the approved entrance master.
- The left wall has only 2–3 broad shelf levels with sparse bottle silhouettes.
- The center remains low contrast and usable as a customer stage.
- The interior contains no barrels, crates, sign, bottle wall, cookware wall or clutter.
- At 320x180, the door, shelves, bar and fireplace remain distinct large shapes.
```

- [ ] **Step 3: Promote and commit the approved interior master**

```powershell
git add -- assets/source/intro/reference/tavern_interior_spatial_master*.png
git commit -m "art(intro): approve unified tavern interior master"
```

### Task 3: Generate the Warm Memory and Dark Tavern Pair

**Files:**
- Read: `assets/source/intro/reference/tavern_interior_spatial_master.png`
- Create: `assets/source/intro/reference/intro_hearth_memory-v2.png`
- Create: `assets/source/intro/reference/intro_tavern_dark-v2.png`
- Replace after approval: `assets/source/intro/reference/intro_hearth_memory.png`
- Replace after approval: `assets/source/intro/reference/intro_tavern_dark.png`

- [ ] **Step 1: Generate `intro_hearth_memory` as an edit of the interior master**

Preserve the approved interior architecture and camera. Include exactly four broad
anonymous patrons in varied directions: two conversing, one attending to a mug, and
one near the entrance. Do not arrange them around the fireplace.

- [ ] **Step 2: Review the warm memory before generating the dark version**

The candidate passes only when:

```text
- The hearth is the sole strong amber focal point.
- Patrons read as large silhouettes without faces or clothing detail.
- The scene feels like a quiet last drink before a dangerous descent, not crowded,
  festive, religious or ceremonial.
- At least about 70% of the frame remains dark teal or coal black.
```

- [ ] **Step 3: Generate `intro_tavern_dark` by editing the approved warm image**

Do not regenerate from text alone. Preserve the exact camera and architecture. Remove patrons and almost all warm light.

- [ ] **Step 4: Review both images side by side**

Reject the pair unless the left-side door, arch, lantern, hearth, tables, and right-side
barrel/crate/mug group occupy matching positions. The emotional contrast must come from
removed light and people, not added decay texture. Neither image may introduce a sign,
interior barrel, or interior crate.

- [ ] **Step 5: Promote and commit the approved pair**

```powershell
git add -- assets/source/intro/reference/intro_hearth_memory*.png assets/source/intro/reference/intro_tavern_dark*.png
git commit -m "art(intro): approve tavern memory contrast pair"
```

### Task 4: Generate the Threshold Shot

**Files:**
- Read: `assets/source/intro/reference/tavern_continuity_master.png`
- Create: `assets/source/intro/reference/intro_threshold-v2.png`
- Replace after approval: `assets/source/intro/reference/intro_threshold.png`

- [ ] **Step 1: Generate the threshold as an edit of the master**

Use the approved `intro_threshold` prompt plus the common prompt and negative prompt. Preserve the established back-wall hearth position.

- [ ] **Step 2: Review narrative and composition**

The candidate passes only when:

```text
- The anonymous traveler is a broad shoulder-and-head silhouette.
- The cold interior occupies most of the image.
- The established hearth is visible and contains only one tiny amber ember.
- There is no bright sunbeam, volumetric glow, triumphant light, or realistic dust.
- The lower 24% contains no critical narrative detail because narration overlays it.
```

- [ ] **Step 3: Promote and commit the approved threshold**

```powershell
git add -- assets/source/intro/reference/intro_threshold*.png
git commit -m "art(intro): approve tavern threshold shot"
```

### Task 5: Generate the Descent and Rusted Key Shots

**Files:**
- Read: `assets/source/title/reference/title_pixel_composite_reference.png`
- Create: `assets/source/intro/reference/intro_descent-v2.png`
- Create: `assets/source/intro/reference/intro_rusted_key-v2.png`
- Replace after approval: `assets/source/intro/reference/intro_descent.png`
- Replace after approval: `assets/source/intro/reference/intro_rusted_key.png`

- [ ] **Step 1: Generate the descent using only the title style reference**

Use the approved `intro_descent` prompt plus the common prompt and negative prompt. Keep the traveler extremely small and use large concentric shaft shapes.

- [ ] **Step 2: Generate the key using only the title style reference**

Use the approved `intro_rusted_key` prompt plus the common prompt and negative prompt. Keep the hand simplified and the key readable as one bold silhouette.

- [ ] **Step 3: Review both independent shots**

Reject the descent if it becomes a detailed cathedral, realistic cave, or foggy cinematic scene. Reject the key if it contains realistic skin, reflective metal, fingernails, paper contracts, or scattered props.

- [ ] **Step 4: Promote and commit the approved shots**

```powershell
git add -- assets/source/intro/reference/intro_descent*.png assets/source/intro/reference/intro_rusted_key*.png
git commit -m "art(intro): approve descent and inherited key shots"
```

### Task 6: Rebuild Native and Runtime Assets

**Files:**
- Replace: `assets/source/intro/intro_descent_native.png`
- Replace: `assets/source/intro/intro_hearth_memory_native.png`
- Replace: `assets/source/intro/intro_tavern_dark_native.png`
- Replace: `assets/source/intro/intro_rusted_key_native.png`
- Replace: `assets/source/intro/intro_threshold_native.png`
- Replace: `assets/source/intro/intro_contact_sheet.png`
- Replace: `assets/textures/intro/intro_descent.png`
- Replace: `assets/textures/intro/intro_hearth_memory.png`
- Replace: `assets/textures/intro/intro_tavern_dark.png`
- Replace: `assets/textures/intro/intro_rusted_key.png`
- Replace: `assets/textures/intro/intro_threshold.png`

- [ ] **Step 1: Prepare native assets**

Run:

```powershell
python scripts/tools/prepare_intro_sources.py
```

Expected: six `prepared assets/source/intro/...` lines with no traceback.

- [ ] **Step 2: Inspect the native contact sheet**

Open:

```text
assets/source/intro/intro_contact_sheet.png
```

Reject the build if the images regain realistic noise after downsampling, if the warm memory becomes orange-washed, or if the dark and threshold shots lose readable midtone structure.

- [ ] **Step 3: Export runtime textures**

Run:

```powershell
python scripts/tools/export_intro_assets.py
```

Expected: six `320x180 -> 1280x720 nearest` lines.

- [ ] **Step 4: Run the asset pipeline test**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: all tests pass.

- [ ] **Step 5: Commit rebuilt assets**

```powershell
git add -- assets/source/intro assets/textures/intro
git commit -m "art(intro): rebuild title-matched opening stills"
```

### Task 7: Verify the Intro in Godot

**Files:**
- Verify: `data/intro.json`
- Verify: `scenes/ui/IntroSequence.tscn`
- Verify: `scripts/ui/intro_sequence.gd`
- Test: `scenes/test/test_intro_sequence.tscn`

- [ ] **Step 1: Run the intro regression scene**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_intro_sequence.tscn'
```

Expected: output contains `[TEST-INTRO] ALL PASS` and no new `SCRIPT ERROR`.

- [ ] **Step 2: Play the opening sequence in the editor**

Check all five beats at runtime:

```text
- Narration does not cover a key, face, ember, doorway, or hearth.
- Ken Burns movement does not expose an edge or crop the primary silhouette.
- Each image reads as the title screen's visual language at first glance.
- The second and third beats clearly use the same location and camera.
- The fifth beat preserves the same hearth location and leads naturally into DayMap.
```

- [ ] **Step 3: Fix only concrete visual defects**

Prefer correcting the approved reference and rebuilding through the pipeline. Do not paint over runtime textures or add post-processing to hide reference problems.

- [ ] **Step 4: Run final verification**

```powershell
python scripts/tools/prepare_intro_sources.py
python scripts/tools/export_intro_assets.py
python -m unittest scripts.test.test_intro_asset_pipeline -v
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_intro_sequence.tscn'
```

Expected: all Python tests pass and Godot prints `[TEST-INTRO] ALL PASS`.

- [ ] **Step 5: Commit final visual corrections**

```powershell
git add -- assets/source/intro assets/textures/intro
git commit -m "fix(intro): finalize opening art composition"
```
