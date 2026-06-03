# Ryan Neutral Portrait Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Ryan's neutral placeholder portrait with one project-fitting native-pixel-style baseline portrait.

**Architecture:** Generate one candidate image from the approved art direction, process it into a transparent PNG, inspect it, then replace only `assets/textures/characters/ryan_neutral.png`. No gameplay logic changes are required.

**Tech Stack:** Built-in image generation, Python/Pillow for alpha and size validation, Godot headless asset smoke test.

---

### Task 1: Generate Candidate

**Files:**
- Create: `tmp/imagegen/ryan_neutral_chroma.png`
- Create: `tmp/imagegen/ryan_neutral_candidate.png`

- [ ] **Step 1: Generate a chroma-key candidate**

Use the built-in image generation tool with the approved Ryan neutral portrait prompt. The image must use a perfectly flat `#00ff00` background so it can be removed locally.

- [ ] **Step 2: Copy generated source into the workspace**

Copy the selected generated file to:

```text
tmp/imagegen/ryan_neutral_chroma.png
```

- [ ] **Step 3: Remove chroma background**

Run:

```powershell
python "$env:CODEX_HOME/skills/.system/imagegen/scripts/remove_chroma_key.py" --input tmp/imagegen/ryan_neutral_chroma.png --out tmp/imagegen/ryan_neutral_candidate.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
```

Expected: `tmp/imagegen/ryan_neutral_candidate.png` exists and has an alpha channel.

### Task 2: Inspect And Install

**Files:**
- Modify: `assets/textures/characters/ryan_neutral.png`

- [ ] **Step 1: Inspect the candidate**

Open `tmp/imagegen/ryan_neutral_candidate.png` and verify:

- transparent background
- no text or watermark
- readable silhouette
- Ryan has messy brown hair, light armor, dark blue cloth, and a sword
- visual style fits current title/workspace assets better than the old placeholder

- [ ] **Step 2: Resize/pad if needed**

If the generated candidate is not `256x320`, resize or pad it to `256x320` while preserving transparency and nearest-neighbor readability.

- [ ] **Step 3: Replace only the neutral portrait**

Copy the approved candidate to:

```text
assets/textures/characters/ryan_neutral.png
```

Do not change:

```text
assets/textures/characters/ryan_excited.png
assets/textures/characters/ryan_hesitant.png
assets/textures/characters/ryan_dejected.png
```

### Task 3: Validate

**Files:**
- Test: `scripts/test/test_ryan_slice_assets.gd`
- Test scene: `scenes/test/test_ryan_slice_assets.tscn`

- [ ] **Step 1: Validate PNG properties**

Run a Python/Pillow check confirming:

- `assets/textures/characters/ryan_neutral.png` exists
- mode is RGBA or equivalent alpha-bearing mode
- size is `256x320`
- at least one corner pixel is transparent

- [ ] **Step 2: Run the Ryan slice asset smoke test**

Run:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_ryan_slice_assets.tscn'
```

Expected: no `SCRIPT ERROR` or `Parser Error`. Mono/.NET assembly noise from MCP or Mono-only launch paths is not considered a branch defect unless the standard editor reproduces it.

### Task 4: Commit

**Files:**
- Modify: `assets/textures/characters/ryan_neutral.png`

- [ ] **Step 1: Stage explicit files only**

Run:

```powershell
git add -- assets/textures/characters/ryan_neutral.png docs/superpowers/plans/2026-06-03-ryan-neutral-portrait.md
```

- [ ] **Step 2: Commit**

Run:

```powershell
git commit -m "feat(art): add Ryan neutral portrait"
```

