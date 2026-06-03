# Container Undo And Workspace Props Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the wash basin, let players right-click the barrel or pot to eject the most recently inserted ingredient, and replace placeholder polygons with the approved hand-drawn pixel workspace props.

**Architecture:** Containers own their ordered ingredient state and expose the same `pop_last_ingredient()` and `ingredient_output_position()` interface. `BarWorkspace` owns mouse hit-testing and spawns the returned ingredient as a normal `DeskItem`, so inventory ownership and out-of-bounds recovery remain unchanged. Approved `B`-direction native PNG sources are preserved under `assets/source/workspace/`; runtime PNGs are nearest-neighbor `2x` exports attached to independent `Sprite2D` nodes.

**Tech Stack:** Godot 4.6 standard, GDScript, headless scene tests, Python Pillow for deterministic nearest-neighbor PNG export.

---

## File Structure

- Modify: `scripts/systems/cook_station_state.gd` - pop the last pot ingredient and reset transient progress.
- Modify: `scripts/test/brewery.gd` - pop the last barrel ingredient and reset shake progress.
- Modify: `scripts/ui/kitchen_container.gd` - expose the shared pot ejection interface.
- Modify: `scripts/ui/bar_workspace.gd` - handle right-click ejection and remove wash-basin behavior.
- Modify: `scripts/test/brewery.gd` - remove the obsolete full-drain wash-basin API after adding LIFO pop.
- Modify: `scripts/ui/kitchen_container.gd` - remove the obsolete full-drain wash-basin API after adding LIFO pop.
- Modify: `scenes/ui/Tavern.tscn` - delete `WashBasin`, add prop sprites, hide placeholder polygons.
- Modify: `scripts/test/test_kitchen_containers.gd` - cover LIFO pot state.
- Modify: `scripts/test/test_workspace_scene_recovery.gd` - cover spawned ejection and remove wash-basin depth assertions.
- Modify: `data/tutorial_steps.json` - teach right-click correction.
- Modify: `scripts/test/test_ryan_slice_tutorials.gd` - require the new tutorial language.
- Modify: `scripts/systems/audio_manager.gd` - remove obsolete `wash_complete`.
- Modify: `scripts/test/test_audio_manager.gd` - remove obsolete event expectations.
- Modify: `scripts/test/test_ryan_slice_assets.gd` - stop requiring obsolete wash VFX and require prop PNGs.
- Create: `assets/source/workspace/*.png` - approved native-size `B` sources.
- Create: `assets/textures/workspace/*.png` - deterministic `2x` runtime exports.
- Create: `scripts/tools/export_workspace_props.py` - source-to-runtime nearest-neighbor exporter.

## Approved Art Inputs

Use the already reviewed `B` variants from the current workspace:

```text
tmp/imagegen/container-approval/barrel_hand_native.png
tmp/imagegen/container-approval/pot_hand_native.png
tmp/imagegen/container-approval/grill_hand_native.png
tmp/imagegen/container-approval/spoon_hand_native.png
```

Do not use the `A` variants or raw green-screen images. Preserve these visual rules:

- closed side-view barrel: no opening;
- closed-body side-view pot: narrow rim seam only, no visible liquid;
- side-view grill: narrow seam, no top-down grate;
- vertical spoon: handle up, bowl down;
- hidden gameplay intake areas remain separate from art.

---

### Task 1: Add LIFO Ingredient Pop APIs

**Files:**
- Modify: `scripts/systems/cook_station_state.gd`
- Modify: `scripts/test/brewery.gd`
- Modify: `scripts/ui/kitchen_container.gd`
- Modify: `scripts/test/test_kitchen_containers.gd`

- [ ] **Step 1: Write the failing pot-state test**

Add `_test_pot_pop_last_item()` to the `_ready()` call list in `scripts/test/test_kitchen_containers.gd`, then add:

```gdscript
func _test_pot_pop_last_item() -> void:
	var state = _new_state()
	state.configure_pot(3.0)
	state.add_item("ale")
	state.add_item("herb")
	state.add_stir(2.0)
	_ok(state.pop_last_item() == "herb", "pot pops newest ingredient first")
	_ok(state.ingredients() == ["ale"], "pot keeps older ingredients after pop")
	state.add_stir(1.0)
	_ok(not state.is_ready(), "pot pop resets prior stir progress")
	_ok(state.pop_last_item() == "ale", "pot pops remaining ingredient")
	_ok(state.pop_last_item() == "", "empty pot pop is a no-op")
```

- [ ] **Step 2: Run the failing test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_kitchen_containers.tscn
```

Expected: failure because `CookStationState.pop_last_item()` does not exist.

- [ ] **Step 3: Add the pure state implementation**

Append to `scripts/systems/cook_station_state.gd`:

```gdscript
func pop_last_item() -> String:
	if _ingredients.is_empty():
		return ""
	var item_key: String = _ingredients.pop_back()
	_elapsed = 0.0
	_stir_progress = 0.0
	return item_key
```

- [ ] **Step 4: Add the shared container interfaces**

Append to `scripts/test/brewery.gd`:

```gdscript
func pop_last_ingredient() -> String:
	if _pending_keys.is_empty():
		return ""
	var item_key: String = _pending_keys.pop_back()
	_shake.reset()
	return item_key

func ingredient_output_position() -> Vector2:
	return _output_anchor.global_position
```

Append to `scripts/ui/kitchen_container.gd`:

```gdscript
func pop_last_ingredient() -> String:
	if container_key != "pot":
		return ""
	return _state.pop_last_item()

func ingredient_output_position() -> Vector2:
	return _output_anchor.global_position
```

- [ ] **Step 5: Run the kitchen test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_kitchen_containers.tscn
```

Expected: `[TEST-KITCHEN] ALL PASS`.

- [ ] **Step 6: Commit**

```powershell
git add scripts/systems/cook_station_state.gd scripts/test/brewery.gd scripts/ui/kitchen_container.gd scripts/test/test_kitchen_containers.gd
git commit -m "feat(workspace): add LIFO ingredient pop interfaces"
```

---

### Task 2: Replace Wash Basin With Right-Click Ejection

**Files:**
- Modify: `scripts/ui/bar_workspace.gd`
- Modify: `scripts/test/brewery.gd`
- Modify: `scripts/ui/kitchen_container.gd`
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scripts/test/test_workspace_scene_recovery.gd`

- [ ] **Step 1: Write the failing workspace scene tests**

Add this call before `_test_spoon_renders_below_container_visuals()`:

```gdscript
	await _test_container_ejection_spawns_lifo_desk_items()
```

Add:

```gdscript
func _test_container_ejection_spawns_lifo_desk_items() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var items := tavern.get_node("BarWorkspace/World/Items")
	var brewery := tavern.get_node("BarWorkspace/World/Brewery") as Brewery
	brewery._pending_keys = ["ale", "herb"]
	var before := items.get_child_count()
	bar._eject_last_ingredient(brewery)
	_ok(items.get_child_count() == before + 1, "barrel right-click eject spawns one desk item")
	var spawned = items.get_child(items.get_child_count() - 1)
	_ok(spawned.item_key == "herb", "barrel ejects newest ingredient first")
	_ok(brewery._pending_keys == ["ale"], "barrel keeps older ingredient")

	var pot = tavern.get_node("BarWorkspace/World/Pot")
	pot._state.add_item("ale")
	pot._state.add_item("meat_raw")
	before = items.get_child_count()
	bar._eject_last_ingredient(pot)
	_ok(items.get_child_count() == before + 1, "pot right-click eject spawns one desk item")
	spawned = items.get_child(items.get_child_count() - 1)
	_ok(spawned.item_key == "meat_raw", "pot ejects newest ingredient first")
	_ok(pot._state.ingredients() == ["ale"], "pot keeps older ingredient")

	before = items.get_child_count()
	bar._eject_last_ingredient(pot)
	bar._eject_last_ingredient(pot)
	_ok(items.get_child_count() == before + 1, "empty pot eject is a no-op")
	_ok(tavern.get_node_or_null("BarWorkspace/World/WashBasin") == null, "wash basin node is removed")

	tavern.queue_free()
	await get_tree().process_frame
```

Delete the `WashBasin` block from `_test_spoon_renders_below_container_visuals()`.

- [ ] **Step 2: Run the failing scene test**

Run:

```powershell
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected: failure because `_eject_last_ingredient()` does not exist and `WashBasin` still exists.

- [ ] **Step 3: Wire right-click handling**

In `scripts/ui/bar_workspace.gd`, extend `_unhandled_input()` before left-click pickup handling:

```gdscript
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_RIGHT \
		and event.pressed \
		and not _drag_ctrl.is_dragging():
		_try_eject_last_ingredient(event.global_position)
		return
```

Add:

```gdscript
func _try_eject_last_ingredient(pos: Vector2) -> void:
	if _hit_test_brewery(pos):
		_eject_last_ingredient(_brewery)
		return
	var kitchen = _hit_test_kitchen_container(pos)
	if kitchen != null and kitchen.container_key == "pot":
		_eject_last_ingredient(kitchen)

func _eject_last_ingredient(container) -> void:
	var item_key: String = container.pop_last_ingredient()
	if item_key == "":
		return
	var item := _spawn_desk_item_at(container.ingredient_output_position(), item_key)
	item.linear_velocity = Vector2(randf_range(-70.0, 70.0), -180.0)
```

- [ ] **Step 4: Remove wash-basin code**

From `scripts/ui/bar_workspace.gd`:

- delete `_wash_basin`, `WASH_DWELL`, `_wash_dwell`;
- delete `_update_wash_basin(delta)` and `_do_wash(container)`;
- remove `_update_wash_basin(delta)` from `_physics_process`;
- rename the now-unused `_physics_process(delta)` parameter to `_delta`;
- remove `or _area_contains_spoon_tip(_wash_basin)` from `_update_spoon_depth`;
- delete `_area_contains_spoon_tip()` because no caller remains.

From `scripts/test/brewery.gd` and `scripts/ui/kitchen_container.gd`:

- delete both obsolete `drain_contents()` methods; right-click LIFO pop is now the only container correction API.

From `scenes/ui/Tavern.tscn`:

- delete `tv_basin`;
- delete `BarWorkspace/World/WashBasin`, its `Shape`, and its `Visual`.

- [ ] **Step 5: Rescan and run the scene test**

Run:

```powershell
godot --headless --editor --quit --path .
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected: `[TEST-WORKSPACE-SCENE] ALL PASS`.

- [ ] **Step 6: Commit**

```powershell
git add scripts/ui/bar_workspace.gd scripts/test/brewery.gd scripts/ui/kitchen_container.gd scenes/ui/Tavern.tscn scripts/test/test_workspace_scene_recovery.gd
git commit -m "feat(workspace): replace wash basin with right-click ejection"
```

---

### Task 3: Update Tutorial And Obsolete Wash Assets

**Files:**
- Modify: `data/tutorial_steps.json`
- Modify: `scripts/test/test_ryan_slice_tutorials.gd`
- Modify: `scripts/systems/audio_manager.gd`
- Modify: `scripts/test/test_audio_manager.gd`
- Modify: `scripts/test/test_ryan_slice_assets.gd`

- [ ] **Step 1: Update failing expectations first**

In `scripts/test/test_ryan_slice_tutorials.gd`, replace `"清洗盆"` in the required list with `"右键"`.

In `scripts/test/test_audio_manager.gd`:

- remove `"wash_complete"` from the event list;
- replace `["\"drop\"", "\"wash_complete\""]` with `["\"drop\""]`.

In `scripts/test/test_ryan_slice_assets.gd`, remove:

```gdscript
"res://assets/textures/vfx/wash_complete.png",
```

- [ ] **Step 2: Run tests to prove stale production code remains**

Run:

```powershell
godot --headless --path . res://scenes/test/test_ryan_slice_tutorials.tscn
godot --headless --path . res://scenes/test/test_audio_manager.tscn
```

Expected: tutorial failure because JSON still says `清洗盆`; audio test may pass before event cleanup because it now ignores the obsolete event.

- [ ] **Step 3: Update production data and event map**

In `data/tutorial_steps.json`, replace the `craft_recovery.description` with:

```text
酒桶或炖锅放错材料时，右键容器可以让最近投入的一份材料蹦回桌面。连续右键可以逐份取回。桌面太乱时，也可以从菜单点击“整理桌面”。
```

In `scripts/systems/audio_manager.gd`, remove:

```gdscript
"wash_complete": "res://assets/audio/placeholders/wash_complete.wav",
```

Do not delete the existing WAV or VFX files in this task. They are harmless unreferenced placeholders and removing tracked binary assets is unnecessary churn.

- [ ] **Step 4: Run focused tests**

```powershell
godot --headless --path . res://scenes/test/test_ryan_slice_tutorials.tscn
godot --headless --path . res://scenes/test/test_audio_manager.tscn
godot --headless --path . res://scenes/test/test_ryan_slice_assets.tscn
```

Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add data/tutorial_steps.json scripts/test/test_ryan_slice_tutorials.gd scripts/systems/audio_manager.gd scripts/test/test_audio_manager.gd scripts/test/test_ryan_slice_assets.gd
git commit -m "docs(tutorial): teach right-click container correction"
```

---

### Task 4: Promote Approved Prop Art And Attach Independent Sprites

**Files:**
- Create: `assets/source/workspace/barrel_native.png`
- Create: `assets/source/workspace/pot_native.png`
- Create: `assets/source/workspace/grill_native.png`
- Create: `assets/source/workspace/spoon_native.png`
- Create: `assets/textures/workspace/barrel.png`
- Create: `assets/textures/workspace/pot.png`
- Create: `assets/textures/workspace/grill.png`
- Create: `assets/textures/workspace/spoon.png`
- Create: `scripts/tools/export_workspace_props.py`
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scripts/test/test_ryan_slice_assets.gd`

- [ ] **Step 1: Promote the approved native `B` sources**

Run:

```powershell
New-Item -ItemType Directory -Force 'assets/source/workspace' | Out-Null
Copy-Item 'tmp/imagegen/container-approval/barrel_hand_native.png' 'assets/source/workspace/barrel_native.png'
Copy-Item 'tmp/imagegen/container-approval/pot_hand_native.png' 'assets/source/workspace/pot_native.png'
Copy-Item 'tmp/imagegen/container-approval/grill_hand_native.png' 'assets/source/workspace/grill_native.png'
Copy-Item 'tmp/imagegen/container-approval/spoon_hand_native.png' 'assets/source/workspace/spoon_native.png'
```

- [ ] **Step 2: Create the deterministic exporter**

Create `scripts/tools/export_workspace_props.py`:

```python
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "workspace"
OUTPUT = ROOT / "assets" / "textures" / "workspace"
NAMES = ["barrel", "pot", "grill", "spoon"]

OUTPUT.mkdir(parents=True, exist_ok=True)
for name in NAMES:
    source = Image.open(SOURCE / f"{name}_native.png").convert("RGBA")
    runtime = source.resize((source.width * 2, source.height * 2), Image.Resampling.NEAREST)
    runtime.save(OUTPUT / f"{name}.png")
    print(f"{name}: {source.size} -> {runtime.size}")
```

- [ ] **Step 3: Export runtime textures**

Run:

```powershell
python scripts/tools/export_workspace_props.py
```

Expected:

```text
barrel: (50, 44) -> (100, 88)
pot: (54, 40) -> (108, 80)
grill: (76, 28) -> (152, 56)
spoon: (16, 52) -> (32, 104)
```

- [ ] **Step 4: Write asset expectations before scene integration**

Append these paths to `scripts/test/test_ryan_slice_assets.gd`:

```gdscript
"res://assets/textures/workspace/barrel.png",
"res://assets/textures/workspace/pot.png",
"res://assets/textures/workspace/grill.png",
"res://assets/textures/workspace/spoon.png",
```

- [ ] **Step 5: Attach sprite nodes and hide placeholder polygons**

In `scenes/ui/Tavern.tscn`, add texture ext resources and a `Sprite2D` named `Art` below each body:

```text
Brewery/Art -> res://assets/textures/workspace/barrel.png
Grill/Art   -> res://assets/textures/workspace/grill.png
Pot/Art     -> res://assets/textures/workspace/pot.png
Spoon/Art   -> res://assets/textures/workspace/spoon.png
```

Set `texture_filter = 1` (`CanvasItem.TEXTURE_FILTER_NEAREST`) on each new `Art`. Preserve existing collision shapes, pickup areas, intake areas, `OutputAnchor`, and `Tip`. Set the old placeholder `Polygon2D` visuals to `visible = false`; do not delete collision nodes.

- [ ] **Step 6: Import and run asset tests**

Run:

```powershell
godot --headless --editor --quit --path .
godot --headless --path . res://scenes/test/test_ryan_slice_assets.tscn
godot --headless --path . res://scenes/test/test_kitchen_containers.tscn
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected: all pass.

- [ ] **Step 7: Commit explicit files**

Stage only the explicit source PNGs, runtime PNGs, exporter, scene, and test. Godot import metadata remains generated local state:

```powershell
git add assets/source/workspace/barrel_native.png assets/source/workspace/pot_native.png assets/source/workspace/grill_native.png assets/source/workspace/spoon_native.png assets/textures/workspace/barrel.png assets/textures/workspace/pot.png assets/textures/workspace/grill.png assets/textures/workspace/spoon.png scripts/tools/export_workspace_props.py scenes/ui/Tavern.tscn scripts/test/test_ryan_slice_assets.gd
git commit -m "feat(art): attach approved workspace prop sprites"
```

---

## Unified Acceptance

- [ ] Run `git diff --check`.
- [ ] Run `Get-ChildItem -Path scripts,scenes,data -Recurse -File | Select-String -Pattern 'WashBasin|wash_complete|清洗盆'`; expected: no active code, scene, tutorial, or test references.
- [ ] Run:

```powershell
godot --headless --editor --quit --path .
godot --headless --path . res://scenes/test/test_kitchen_containers.tscn
godot --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
godot --headless --path . res://scenes/test/test_ryan_slice_tutorials.tscn
godot --headless --path . res://scenes/test/test_audio_manager.tscn
godot --headless --path . res://scenes/test/test_ryan_slice_assets.tscn
```

- [ ] In Godot 4.6 standard editor, verify:

```text
TitleScreen -> DayMap -> Tavern -> LedgerScreen -> DayMap
```

- [ ] In Tavern, drop two materials into the barrel and pot separately, then right-click repeatedly. Confirm LIFO ejection, upward physical motion, no inventory duplication, no wash basin, and `0 errors/warnings`.

## Self-Review Notes

- Spec container behavior is covered by Tasks 1-3.
- Tool art freeze rules are covered by Task 4.
- Inventory ownership remains centralized: ejected items are ordinary desk entities and only return to inventory through existing recovery.
- `tmp/` is an execution input only and must not be committed.
