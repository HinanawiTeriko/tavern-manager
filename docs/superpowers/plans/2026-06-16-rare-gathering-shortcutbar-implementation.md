# Rare Gathering and Shortcut Binding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first rare-gathering loop with upgrade recipes and player-controlled shortcut bar bindings, without changing current container limits or story-critical route logic.

**Architecture:** Extend `locations.json` with stable and rare reward metadata, and let `DayMapSystem.visit()` resolve repeatable gathering rewards with pity state saved in its existing `capture_state()`/`restore_state()` path. Store shortcut bindings in `GameManager` as item-key references only; `BarWorkspace` renders and spawns from those bindings while `InventorySystem` remains the single inventory source.

**Tech Stack:** Godot 4.6.3, GDScript, JSON data files, existing headless test scenes, existing pixel icon export conventions.

---

## Files And Responsibilities

- Modify `data/locations.json`: add first-batch rare gathering metadata and revised natural descriptions.
- Modify `data/items.json`: add 4 rare materials and 4 upgrade products.
- Modify `data/recipes.json`: add upgrade recipes within existing container limits.
- Modify `scripts/systems/day_map_system.gd`: resolve stable x2 rewards, rare chance, pity counter, and saved pity state.
- Modify `scripts/game_manager.gd`: expose shortcut binding API, save/load bindings, add icon path mappings, keep inventory as single source.
- Modify `scripts/ui/bar_workspace.gd`: render shortcut slots from bindings, bind inventory item drops to slot positions, keep click-to-spawn behavior.
- Modify `scripts/ui/tavern_view.gd`: route inventory drag drops onto shortcut slots before spawning world items.
- Modify `scripts/test/test_day_map_system.gd`: cover rare gathering rewards, pity, Day2 sleep powder special case.
- Modify `scripts/test/test_inventory_system.gd`: cover shortcut binding validation and duplicate handling.
- Modify `scripts/test/test_save_roundtrip.gd`: cover saved shortcut bindings and rare pity counters.
- Modify `scripts/test/test_workspace_scene_recovery.gd`: cover binding a backpack item to a live shortcut slot and spawning from it.
- Create `scripts/test/test_rare_gathering_data.gd`: focused data contract for new item/recipe/location keys.
- Create `scenes/test/test_rare_gathering_data.tscn`: headless scene for the data contract.
- Later asset task creates `scripts/tools/export_rare_gathering_assets.py`, `scripts/test/test_rare_gathering_asset_pipeline.py`, and runtime/source PNGs.

---

### Task 1: Rare Gathering Data Contract

**Files:**
- Create: `scripts/test/test_rare_gathering_data.gd`
- Create: `scenes/test/test_rare_gathering_data.tscn`
- Modify later in Task 2: `data/items.json`, `data/recipes.json`, `data/locations.json`

- [ ] **Step 1: Write the failing data contract test**

Create `scripts/test/test_rare_gathering_data.gd`:

```gdscript
extends Node

var _checks := 0
var _failures := 0

const RARE_MATERIALS := {
	"cave_mushroom": "洞窟菌",
	"rock_lizard_meat": "岩蜥肉",
	"north_sour_grape": "北路酸葡萄",
	"black_malt": "黑麦芽",
}

const UPGRADE_RECIPES := {
	"cave_mushroom_stew": {"name": "菌菇肉汤", "container": "pot", "ingredients": ["meat_raw", "cave_mushroom"]},
	"rock_lizard_steak": {"name": "岩蜥烤排", "container": "grill", "ingredients": ["rock_lizard_meat"]},
	"old_road_wine": {"name": "旧路酸葡萄酒", "container": "barrel", "ingredients": ["north_sour_grape"]},
	"miner_dark_ale": {"name": "矿工黑啤", "container": "barrel", "ingredients": ["black_malt"]},
}

const RARE_LOCATIONS := {
	"mushroom_forest": {"stable": "herb", "rare": "cave_mushroom"},
	"dark_river": {"stable": "meat_raw", "rare": "rock_lizard_meat"},
	"grape_trellis": {"stable": "grape", "rare": "north_sour_grape"},
	"mill_farm": {"stable": "ale", "rare": "black_malt"},
}

func _ready() -> void:
	_test_items_define_rare_materials_and_products()
	_test_recipes_keep_container_limits()
	_test_locations_advertise_stable_and_rare_rewards()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RARE-GATHERING-DATA] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-RARE-GATHERING-DATA] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RARE-GATHERING-DATA] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_ok(file != null, path + " opens")
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(parsed is Dictionary, path + " parses as Dictionary")
	return parsed if parsed is Dictionary else {}

func _test_items_define_rare_materials_and_products() -> void:
	var items := _load_json("res://data/items.json")
	for key in RARE_MATERIALS.keys():
		_ok(items.has(key), "items has rare material " + key)
		var item: Dictionary = items.get(key, {})
		_ok(String(item.get("name", "")) == String(RARE_MATERIALS[key]), key + " has expected Chinese name")
		_ok(String(item.get("type", "")) == "material", key + " is a material")
	for key in UPGRADE_RECIPES.keys():
		_ok(items.has(key), "items has upgrade product " + key)
		var product: Dictionary = items.get(key, {})
		_ok(String(product.get("name", "")) == String(UPGRADE_RECIPES[key]["name"]), key + " has expected Chinese name")
		_ok(String(product.get("type", "")) == "product", key + " is a product")

func _test_recipes_keep_container_limits() -> void:
	var recipes := _load_json("res://data/recipes.json")
	for key in UPGRADE_RECIPES.keys():
		_ok(recipes.has(key), "recipes has upgrade recipe " + key)
		var recipe: Dictionary = recipes.get(key, {})
		var expected: Dictionary = UPGRADE_RECIPES[key]
		var ingredients: Array = recipe.get("ingredients", [])
		_ok(String(recipe.get("container", "")) == String(expected["container"]), key + " uses expected container")
		_ok(ingredients == expected["ingredients"], key + " uses expected ingredients")
		if String(recipe.get("container", "")) == "grill":
			_ok(ingredients.size() == 1, key + " keeps grill single-material rule")
		else:
			_ok(ingredients.size() <= 2, key + " keeps existing two-material cap")

func _test_locations_advertise_stable_and_rare_rewards() -> void:
	var data := _load_json("res://data/locations.json")
	var locations: Array = data.get("locations", [])
	for location_id in RARE_LOCATIONS.keys():
		var loc := _find_location(locations, location_id)
		_ok(not loc.is_empty(), "location exists: " + location_id)
		var expected: Dictionary = RARE_LOCATIONS[location_id]
		_ok(String(loc.get("stableReward", "")) == String(expected["stable"]), location_id + " declares stableReward")
		_ok(int(loc.get("stableRewardCount", 0)) == 2, location_id + " declares stableRewardCount 2")
		var rare: Dictionary = loc.get("rareReward", {})
		_ok(String(rare.get("key", "")) == String(expected["rare"]), location_id + " declares rare reward key")
		_ok(float(rare.get("chance", -1.0)) == 0.35, location_id + " declares 35 percent rare chance")
		_ok(int(rare.get("pityAfterMisses", 0)) == 2, location_id + " declares pity after two misses")
		_ok(String(loc.get("description", "")).contains(String(expected["rare"])) or String(loc.get("description", "")).length() > 8,
			location_id + " has a natural revised description")

func _find_location(locations: Array, location_id: String) -> Dictionary:
	for loc in locations:
		if String((loc as Dictionary).get("id", "")) == location_id:
			return loc
	return {}
```

Create `scenes/test/test_rare_gathering_data.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_rare_gathering_data.gd" id="1"]

[node name="TestRareGatheringData" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_rare_gathering_data.tscn"
```

Expected: FAIL because the rare item, recipe, and location metadata keys do not exist yet.

- [ ] **Step 3: Commit the red test**

```powershell
git add scripts/test/test_rare_gathering_data.gd scenes/test/test_rare_gathering_data.tscn
git commit -m "test: add rare gathering data contract"
```

---

### Task 2: Add Rare Items, Recipes, And Location Metadata

**Files:**
- Modify: `data/items.json`
- Modify: `data/recipes.json`
- Modify: `data/locations.json`
- Modify: `scripts/game_manager.gd`

- [ ] **Step 1: Add rare materials and upgrade products to `data/items.json`**

Add these keys near related materials/products:

```json
"cave_mushroom": { "name": "洞窟菌", "color": [0.38, 0.45, 0.32], "price": 0, "type": "material", "physics_profile": "soft_stable", "collision_profile": "default_box", "feedback_profile": "default" },
"rock_lizard_meat": { "name": "岩蜥肉", "color": [0.45, 0.25, 0.18], "price": 0, "type": "material", "physics_profile": "heavy_dull", "collision_profile": "default_box", "feedback_profile": "thud" },
"north_sour_grape": { "name": "北路酸葡萄", "color": [0.48, 0.08, 0.24], "price": 0, "type": "material", "physics_profile": "round_light", "collision_profile": "circle_small", "feedback_profile": "bouncy" },
"black_malt": { "name": "黑麦芽", "color": [0.35, 0.22, 0.08], "price": 0, "type": "material", "physics_profile": "default", "collision_profile": "default_box", "feedback_profile": "default" },
"cave_mushroom_stew": { "name": "菌菇肉汤", "color": [0.38, 0.30, 0.18], "price": 14, "type": "product" },
"rock_lizard_steak": { "name": "岩蜥烤排", "color": [0.42, 0.18, 0.10], "price": 10, "type": "product" },
"old_road_wine": { "name": "旧路酸葡萄酒", "color": [0.32, 0.04, 0.18], "price": 8, "type": "product" },
"miner_dark_ale": { "name": "矿工黑啤", "color": [0.26, 0.16, 0.06], "price": 8, "type": "product" },
```

- [ ] **Step 2: Add upgrade recipes to `data/recipes.json`**

Add:

```json
"old_road_wine": {
  "name": "旧路酸葡萄酒",
  "ingredients": ["north_sour_grape"],
  "container": "barrel",
  "memory_for": { "mira": "day4_road_story" }
},
"miner_dark_ale": {
  "name": "矿工黑啤",
  "ingredients": ["black_malt"],
  "container": "barrel"
},
"rock_lizard_steak": {
  "name": "岩蜥烤排",
  "ingredients": ["rock_lizard_meat"],
  "container": "grill"
},
"cave_mushroom_stew": {
  "name": "菌菇肉汤",
  "ingredients": ["meat_raw", "cave_mushroom"],
  "container": "pot"
}
```

- [ ] **Step 3: Add stable/rare metadata and revised descriptions to `data/locations.json`**

For `mushroom_forest`, add or replace:

```json
"stableReward": "herb",
"stableRewardCount": 2,
"rareReward": { "key": "cave_mushroom", "chance": 0.35, "pityAfterMisses": 2 },
"description": "潮湿的洞穴林地里长着常用草药，腐木背面偶尔能找到肥厚的洞窟菌。",
"result": "你从林地带回了可用的植物。"
```

For `dark_river`:

```json
"stableReward": "meat_raw",
"stableRewardCount": 2,
"rareReward": { "key": "rock_lizard_meat", "chance": 0.35, "pityAfterMisses": 2 },
"description": "地下暗河旁有小型野兽和鱼类，温热石缝里偶尔能撞见岩蜥。",
"result": "你从暗河沿岸带回了肉食。"
```

For `grape_trellis`:

```json
"stableReward": "grape",
"stableRewardCount": 2,
"rareReward": { "key": "north_sour_grape", "chance": 0.35, "pityAfterMisses": 2 },
"description": "地牢里罕见的葡萄藤架，深处偶尔结着酸涩的北路野葡萄。",
"result": "你采到了一篮葡萄。"
```

For `mill_farm`:

```json
"stableReward": "ale",
"stableRewardCount": 2,
"rareReward": { "key": "black_malt", "chance": 0.35, "pityAfterMisses": 2 },
"description": "地牢入口附近的农庄磨坊能换到麦芽，旧仓里偶尔翻出颜色更深的黑麦芽。",
"result": "你从农庄带回了麦芽。"
```

Keep existing `materials` and `rewards` arrays for backward compatibility until all callers use the new metadata.

- [ ] **Step 4: Map temporary icon paths in `scripts/game_manager.gd`**

Add to `MATERIAL_ICON_PATHS`. These files will be created by the asset task; until then, missing icon fallback remains acceptable for data tests:

```gdscript
"cave_mushroom": "res://assets/textures/tavern/icons/cave_mushroom.png",
"rock_lizard_meat": "res://assets/textures/tavern/icons/rock_lizard_meat.png",
"north_sour_grape": "res://assets/textures/tavern/icons/north_sour_grape.png",
"black_malt": "res://assets/textures/tavern/icons/black_malt.png",
"cave_mushroom_stew": "res://assets/textures/tavern/items/cave_mushroom_stew.png",
"rock_lizard_steak": "res://assets/textures/tavern/items/rock_lizard_steak.png",
"old_road_wine": "res://assets/textures/tavern/items/old_road_wine.png",
"miner_dark_ale": "res://assets/textures/tavern/items/miner_dark_ale.png",
```

- [ ] **Step 5: Run data test**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_rare_gathering_data.tscn"
```

Expected: PASS.

- [ ] **Step 6: Commit data changes**

```powershell
git add data/items.json data/recipes.json data/locations.json scripts/game_manager.gd
git commit -m "feat: add first rare gathering ingredients"
```

---

### Task 3: Rare Gathering Rewards And Pity State

**Files:**
- Modify: `scripts/test/test_day_map_system.gd`
- Modify: `scripts/systems/day_map_system.gd`

- [ ] **Step 1: Add failing DayMap reward tests**

In `scripts/test/test_day_map_system.gd`, add `_test_rare_gathering_rewards_and_pity()` to `_ready()` before `_finish()`:

```gdscript
	_test_rare_gathering_rewards_and_pity()
```

Add this function:

```gdscript
func _test_rare_gathering_rewards_and_pity() -> void:
	var map := DayMapSystem.new()
	_ok(map.load_data(), "rare gathering locations data loads")
	map.start_day(3)
	map.stamina = 10
	var grape_loc: Dictionary = map._locations.get("grape_trellis", {})
	grape_loc["rareReward"]["chance"] = 0.0
	map._locations["grape_trellis"] = grape_loc

	var first := map.visit("grape_trellis")
	_ok(first.get("success", false), "first grape gathering succeeds")
	_ok(_count_reward(first, "grape") == 2, "stable grape reward gives two")
	_ok(_count_reward(first, "north_sour_grape") == 0, "first forced miss gives no rare")

	var second := map.visit("grape_trellis")
	_ok(_count_reward(second, "grape") == 2, "second grape gathering still gives stable reward")
	_ok(_count_reward(second, "north_sour_grape") == 0, "second forced miss gives no rare")

	var third := map.visit("grape_trellis")
	_ok(_count_reward(third, "grape") == 2, "third grape gathering still gives stable reward")
	_ok(_count_reward(third, "north_sour_grape") == 1, "third gathering triggers rare pity")
	_ok(int(map.capture_state().get("rare_gather_misses", {}).get("grape_trellis", -1)) == 0,
		"rare pity resets after award")

	var snap := map.capture_state()
	map.start_day(3)
	var restored := DayMapSystem.new()
	restored.load_data()
	restored.restore_state(snap)
	_ok(int(restored.capture_state().get("rare_gather_misses", {}).get("grape_trellis", -1)) == 0,
		"rare pity state roundtrips through capture/restore")

	var day2 := DayMapSystem.new()
	day2.load_data()
	day2.start_day(2)
	var forest := day2.visit("mushroom_forest")
	_ok(_count_reward(forest, "sleep_powder") == 1, "day2 forest still grants sleep powder")
	_ok(_count_reward(forest, "cave_mushroom") == 0, "day2 sleep powder special does not also roll cave mushroom")
	_ok(not day2.capture_state().get("rare_gather_misses", {}).has("mushroom_forest"),
		"day2 sleep powder special does not consume rare pity state")

func _count_reward(result: Dictionary, item_key: String) -> int:
	var count := 0
	for key in result.get("rewards", []):
		if String(key) == item_key:
			count += 1
	return count
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_day_map_system.tscn"
```

Expected: FAIL because `stableReward`, x2 stable rewards, rare pity, and `rare_gather_misses` state are not implemented.

- [ ] **Step 3: Implement reward resolution in `DayMapSystem`**

Add state near existing private dictionaries:

```gdscript
var _rare_gather_misses: Dictionary = {}
var _rare_rng := RandomNumberGenerator.new()
```

Initialize RNG in `load_data()` after parse succeeds:

```gdscript
_rare_rng.randomize()
```

Add capture/restore fields:

```gdscript
"rare_gather_misses": _rare_gather_misses.duplicate(),
```

In `restore_state(state)`, restore:

```gdscript
_rare_gather_misses.clear()
var misses: Dictionary = state.get("rare_gather_misses", {})
for id in misses.keys():
	_rare_gather_misses[String(id)] = int(misses[id])
```

Replace reward resolution inside `visit()`:

```gdscript
	var rewards: Array = _resolve_rewards(location_id, location)
	var day_rewards: Dictionary = location.get("dayRewards", {})
	if day_rewards.has(str(current_day)):
		rewards = day_rewards[str(current_day)].duplicate()
```

with:

```gdscript
	var rewards: Array = _resolve_rewards(location_id, location)
```

Add helper functions:

```gdscript
func _resolve_rewards(location_id: String, location: Dictionary) -> Array:
	var day_rewards: Dictionary = location.get("dayRewards", {})
	if day_rewards.has(str(current_day)):
		return day_rewards[str(current_day)].duplicate()
	var rewards: Array = []
	var stable_key := String(location.get("stableReward", ""))
	if stable_key != "":
		var stable_count := maxi(1, int(location.get("stableRewardCount", 1)))
		for _i in range(stable_count):
			rewards.append(stable_key)
	else:
		rewards = location.get("rewards", []).duplicate()
	var rare: Dictionary = location.get("rareReward", {})
	var rare_key := String(rare.get("key", ""))
	if rare_key != "":
		if _should_award_rare(location_id, rare):
			rewards.append(rare_key)
			_rare_gather_misses[location_id] = 0
		else:
			_rare_gather_misses[location_id] = int(_rare_gather_misses.get(location_id, 0)) + 1
	return rewards

func _should_award_rare(location_id: String, rare: Dictionary) -> bool:
	var pity_after := int(rare.get("pityAfterMisses", 0))
	var misses := int(_rare_gather_misses.get(location_id, 0))
	if pity_after > 0 and misses >= pity_after:
		return true
	var chance := clampf(float(rare.get("chance", 0.0)), 0.0, 1.0)
	return _rare_rng.randf() < chance
```

- [ ] **Step 4: Run DayMap tests**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_day_map_system.tscn"
```

Expected: PASS.

- [ ] **Step 5: Commit DayMap reward logic**

```powershell
git add scripts/test/test_day_map_system.gd scripts/systems/day_map_system.gd
git commit -m "feat: add rare gathering reward pity"
```

---

### Task 4: Shortcut Binding State And Save Roundtrip

**Files:**
- Modify: `scripts/test/test_inventory_system.gd`
- Modify: `scripts/test/test_save_roundtrip.gd`
- Modify: `scripts/game_manager.gd`

- [ ] **Step 1: Add failing shortcut binding tests**

In `scripts/test/test_inventory_system.gd`, call `_test_shortcut_bindings_are_item_key_references()` before `_finish()`:

```gdscript
	_test_shortcut_bindings_are_item_key_references()
```

Add:

```gdscript
func _test_shortcut_bindings_are_item_key_references() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	_ok(gm.has_method("get_shortcut_bindings"), "GameManager exposes shortcut binding snapshot")
	_ok(gm.has_method("bind_shortcut_item"), "GameManager exposes shortcut bind API")
	_ok(gm.has_method("can_bind_shortcut_item"), "GameManager exposes shortcut bind validation")
	var defaults: Array = gm.get_shortcut_bindings()
	_ok(defaults.size() == 10, "shortcut binding array has ten slots")
	_ok(defaults[0] == "ale", "default slot0 is ale")
	_ok(defaults[1] == "grape", "default slot1 is grape")
	_ok(gm.can_bind_shortcut_item("north_sour_grape"), "rare material can bind to shortcut")
	_ok(not gm.can_bind_shortcut_item("toby_contract"), "story item cannot bind to shortcut")
	_ok(not gm.can_bind_shortcut_item("wine"), "product cannot bind to shortcut")
	_ok(gm.bind_shortcut_item(0, "north_sour_grape"), "binding rare material succeeds")
	_ok(gm.get_shortcut_bindings()[0] == "north_sour_grape", "slot0 stores rare material key")
	_ok(gm.bind_shortcut_item(1, "north_sour_grape"), "rebinding same key to another slot succeeds")
	var moved: Array = gm.get_shortcut_bindings()
	_ok(moved[0] == "", "old duplicate binding is cleared")
	_ok(moved[1] == "north_sour_grape", "new duplicate binding is kept")
	_ok(not gm.bind_shortcut_item(2, "wine"), "binding product fails")
```

In `scripts/test/test_save_roundtrip.gd`, add `_test_shortcut_bindings_roundtrip()` before `_test_new_game_resets()`:

```gdscript
	_test_shortcut_bindings_roundtrip()
```

Add:

```gdscript
func _test_shortcut_bindings_roundtrip() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	_ok(gm.bind_shortcut_item(0, "north_sour_grape"), "test setup binds rare grape")
	_ok(gm.bind_shortcut_item(5, "black_malt"), "test setup binds black malt")
	var snap := gm._capture_save_state()
	_ok(snap.has("shortcut_bindings"), "save snapshot includes shortcut bindings")
	gm.bind_shortcut_item(0, "ale")
	gm.bind_shortcut_item(5, "grape")
	gm._apply_save_state(snap)
	var restored: Array = gm.get_shortcut_bindings()
	_ok(restored[0] == "north_sour_grape", "slot0 binding restored")
	_ok(restored[5] == "black_malt", "slot5 binding restored")
	gm._apply_save_state(gm._default_new_game_state())
	var defaults: Array = gm.get_shortcut_bindings()
	_ok(defaults[0] == "ale" and defaults[1] == "grape", "new game restores default shortcut bindings")
	gm.save_sys.clear()
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_inventory_system.tscn"
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_save_roundtrip.tscn"
```

Expected: FAIL because shortcut binding APIs and save field do not exist.

- [ ] **Step 3: Implement shortcut binding state in `GameManager`**

Add near inventory vars:

```gdscript
const DEFAULT_SHORTCUT_BINDINGS: Array[String] = [
	"ale", "grape", "flour", "meat_raw", "herb", "", "", "", "", ""
]

var shortcut_bindings: Array[String] = []
```

In `_ready()`, after `inventory = inventory_sys.materials`:

```gdscript
shortcut_bindings = _default_shortcut_bindings()
```

Add methods:

```gdscript
func _default_shortcut_bindings() -> Array[String]:
	var result: Array[String] = []
	for key in DEFAULT_SHORTCUT_BINDINGS:
		result.append(String(key))
	return result

func get_shortcut_bindings() -> Array[String]:
	if shortcut_bindings.size() != 10:
		shortcut_bindings = _normalized_shortcut_bindings(shortcut_bindings)
	return shortcut_bindings.duplicate()

func can_bind_shortcut_item(item_key: String) -> bool:
	if item_key == "":
		return false
	if inventory_sys == null:
		return false
	return inventory_sys.is_material(item_key) or seasoning.is_seasoning(item_key)

func bind_shortcut_item(slot_index: int, item_key: String) -> bool:
	if slot_index < 0 or slot_index >= 10:
		return false
	if not can_bind_shortcut_item(item_key):
		return false
	shortcut_bindings = _normalized_shortcut_bindings(shortcut_bindings)
	for i in range(shortcut_bindings.size()):
		if i != slot_index and shortcut_bindings[i] == item_key:
			shortcut_bindings[i] = ""
	shortcut_bindings[slot_index] = item_key
	notify_inventory_changed()
	return true

func clear_shortcut_binding(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 10:
		return false
	shortcut_bindings = _normalized_shortcut_bindings(shortcut_bindings)
	shortcut_bindings[slot_index] = ""
	notify_inventory_changed()
	return true

func _normalized_shortcut_bindings(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for i in range(10):
		var key := String(raw[i]) if i < raw.size() else ""
		if key != "" and can_bind_shortcut_item(key):
			result.append(key)
		else:
			result.append("")
	return result
```

Add to `_capture_save_state()` root dictionary:

```gdscript
"shortcut_bindings": get_shortcut_bindings(),
```

In `_apply_save_state(data)`, after `inventory_sys.set_initial(...)`:

```gdscript
shortcut_bindings = _normalized_shortcut_bindings(data.get("shortcut_bindings", _default_shortcut_bindings()))
```

In `_default_new_game_state()`, include:

```gdscript
"shortcut_bindings": _default_shortcut_bindings(),
```

- [ ] **Step 4: Run inventory and save tests**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_inventory_system.tscn"
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_save_roundtrip.tscn"
```

Expected: PASS.

- [ ] **Step 5: Commit shortcut state**

```powershell
git add scripts/test/test_inventory_system.gd scripts/test/test_save_roundtrip.gd scripts/game_manager.gd
git commit -m "feat: save shortcut bar bindings"
```

---

### Task 5: Shortcut UI Binding And Backpack Drop Routing

**Files:**
- Modify: `scripts/test/test_workspace_scene_recovery.gd`
- Modify: `scripts/ui/bar_workspace.gd`
- Modify: `scripts/ui/tavern_view.gd`

- [ ] **Step 1: Add failing live UI contract test**

In `scripts/test/test_workspace_scene_recovery.gd`, add a test after existing inventory/shortcut tests:

```gdscript
func _test_inventory_drop_binds_shortcut_slot() -> void:
	var tavern = load("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.add_to_inventory("north_sour_grape", 1)
	var bar = tavern.get_node("BarWorkspace")
	var slot7 := tavern.get_node("ShortcutBar/Slot7") as Control
	var slot_center := slot7.global_position + slot7.size * 0.5
	_ok(bar.has_method("bind_shortcut_at_position"), "BarWorkspace exposes shortcut drop binding")
	_ok(bar.bind_shortcut_at_position("north_sour_grape", slot_center), "dropping inventory item on slot binds it")
	await get_tree().process_frame
	_ok(bar._slot_item_keys[7] == "north_sour_grape", "slot7 renders bound rare material")
	_ok(gm.inventory_sys.get_count("north_sour_grape") == 1, "binding does not consume inventory")
	var spawned = bar.spawn_inventory_item_at("north_sour_grape", slot_center + Vector2(0, -120))
	_ok(spawned != null, "bound rare material can still spawn as desk item")
	_ok(gm.inventory_sys.get_count("north_sour_grape") == 0, "spawning consumes inventory, not binding")
	tavern.queue_free()
	await get_tree().process_frame
```

Call it from `_ready()` with `await _test_inventory_drop_binds_shortcut_slot()`.

- [ ] **Step 2: Run workspace test to verify failure**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_workspace_scene_recovery.tscn"
```

Expected: FAIL because `bind_shortcut_at_position` does not exist and `_init_material_slots()` still auto-sorts inventory.

- [ ] **Step 3: Update `BarWorkspace._init_material_slots()` to use bindings**

Replace the current key collection:

```gdscript
	var keys: Array = []
	for k in _gm.inventory.keys():
		if _gm.inventory_sys.is_material(k):
			keys.append(k)
	keys.sort()
```

with:

```gdscript
	var keys: Array[String] = _gm.get_shortcut_bindings() if _gm != null and _gm.has_method("get_shortcut_bindings") else []
```

Keep the existing rendering loop, but for a bound key with count 0, render the icon/name and count `0` while still allowing `spawn_inventory_item_at()` to fail safely through inventory removal.

Add method:

```gdscript
func bind_shortcut_at_position(item_key: String, global_position: Vector2) -> bool:
	if _gm == null or not _gm.has_method("bind_shortcut_item"):
		return false
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(global_position):
			var bound: bool = _gm.bind_shortcut_item(i, item_key)
			if bound:
				_init_material_slots()
				_gm.play_audio_event("drop")
			return bound
	return false
```

- [ ] **Step 4: Route inventory drops in `TavernView`**

Update `_on_inventory_item_dropped(item_key, global_position)`:

```gdscript
func _on_inventory_item_dropped(item_key: String, global_position: Vector2) -> void:
	var bar = get_node_or_null("BarWorkspace")
	if bar != null and bar.has_method("bind_shortcut_at_position"):
		if bar.bind_shortcut_at_position(item_key, global_position):
			return
	if bar != null and bar.has_method("spawn_inventory_item_at"):
		bar.spawn_inventory_item_at(item_key, global_position)
```

- [ ] **Step 5: Run workspace test**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_workspace_scene_recovery.tscn"
```

Expected: PASS.

- [ ] **Step 6: Commit UI binding**

```powershell
git add scripts/test/test_workspace_scene_recovery.gd scripts/ui/bar_workspace.gd scripts/ui/tavern_view.gd
git commit -m "feat: bind backpack items to shortcut bar"
```

---

### Task 6: Asset Pipeline And First Runtime Icons

**Files:**
- Create: `art_sources/generated_raw/rare_gathering/`
- Create: `assets/source/rare_gathering/`
- Create/modify runtime PNGs under `assets/textures/tavern/icons/` and `assets/textures/tavern/items/`
- Create: `scripts/tools/export_rare_gathering_assets.py`
- Create: `scripts/test/test_rare_gathering_asset_pipeline.py`
- Create: `docs/art/rare_gathering_contact_sheet.png`

- [ ] **Step 1: Generate source art**

Use the image generation workflow to create a single transparent icon sheet source containing:

```text
cave mushroom, rock lizard meat, north sour grape, black malt,
cave mushroom stew, rock lizard steak, old road wine, miner dark ale
```

Prompt constraints:

```text
Pixel game item icon sheet, eight separate icons on transparent background, no text, no numbers, no UI frames, dark teal dungeon tavern palette with amber highlights, crisp silhouettes, rough ink-like outlines, limited palette, readable at small size. Icons: fat cave mushroom, rugged lizard meat cut, dark sour grape cluster, black malt grain bundle, mushroom meat stew bowl, grilled lizard steak, dark red sour grape wine bottle, black miner ale mug.
```

Save raw sources under `art_sources/generated_raw/rare_gathering/`.

- [ ] **Step 2: Write deterministic exporter**

Create `scripts/tools/export_rare_gathering_assets.py` with explicit crop manifest and nearest-neighbor export. It must:

- Read native cleaned PNGs from `assets/source/rare_gathering/`.
- Export 24x24 native icons scaled to 96x96 runtime PNGs.
- Write runtime files to the paths in `MATERIAL_ICON_PATHS`.
- Write `docs/art/rare_gathering_contact_sheet.png`.

- [ ] **Step 3: Write pipeline test**

Create `scripts/test/test_rare_gathering_asset_pipeline.py` that:

```python
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

ITEMS = [
    ("assets/source/rare_gathering/cave_mushroom.png", "assets/textures/tavern/icons/cave_mushroom.png"),
    ("assets/source/rare_gathering/rock_lizard_meat.png", "assets/textures/tavern/icons/rock_lizard_meat.png"),
    ("assets/source/rare_gathering/north_sour_grape.png", "assets/textures/tavern/icons/north_sour_grape.png"),
    ("assets/source/rare_gathering/black_malt.png", "assets/textures/tavern/icons/black_malt.png"),
    ("assets/source/rare_gathering/cave_mushroom_stew.png", "assets/textures/tavern/items/cave_mushroom_stew.png"),
    ("assets/source/rare_gathering/rock_lizard_steak.png", "assets/textures/tavern/items/rock_lizard_steak.png"),
    ("assets/source/rare_gathering/old_road_wine.png", "assets/textures/tavern/items/old_road_wine.png"),
    ("assets/source/rare_gathering/miner_dark_ale.png", "assets/textures/tavern/items/miner_dark_ale.png"),
]

def test_runtime_icons_are_exact_nearest_exports():
    for native_rel, runtime_rel in ITEMS:
        native = Image.open(ROOT / native_rel).convert("RGBA")
        runtime = Image.open(ROOT / runtime_rel).convert("RGBA")
        assert native.size == (24, 24)
        assert runtime.size == (96, 96)
        expected = native.resize((96, 96), Image.Resampling.NEAREST)
        assert list(runtime.getdata()) == list(expected.getdata())
```

- [ ] **Step 4: Run exporter and test**

Run:

```powershell
python scripts/tools/export_rare_gathering_assets.py
python -m pytest scripts/test/test_rare_gathering_asset_pipeline.py
```

Expected: PASS.

- [ ] **Step 5: Run material icon smoke**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_baseline_systems.tscn"
```

Expected: PASS once `test_baseline_systems.gd` is extended to include the four rare material icons.

- [ ] **Step 6: Commit assets**

```powershell
git add art_sources/generated_raw/rare_gathering assets/source/rare_gathering assets/textures/tavern/icons assets/textures/tavern/items scripts/tools/export_rare_gathering_assets.py scripts/test/test_rare_gathering_asset_pipeline.py docs/art/rare_gathering_contact_sheet.png
git commit -m "art: add rare gathering item icons"
```

---

### Task 7: Final Regression

**Files:**
- No new edits unless regressions are found.

- [ ] **Step 1: Run headless regression set**

Run:

```powershell
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_rare_gathering_data.tscn"
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_day_map_system.tscn"
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_inventory_system.tscn"
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_save_roundtrip.tscn"
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_workspace_scene_recovery.tscn"
& "C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "D:/game/tavern-manager" "res://scenes/test/test_day12_smoke.tscn"
python -m pytest scripts/test/test_rare_gathering_asset_pipeline.py
```

Expected: all pass. `test_day12_smoke.tscn` may still print existing Godot resource leak warnings at exit while returning exit code 0.

- [ ] **Step 2: Run diff checks**

Run:

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors. Status contains only intentional files for this feature plus pre-existing unrelated user changes.

---

## Self-Review

- Spec coverage: rare material data, stable x2 rewards, 35% chance, pity, Day2 sleep powder exception, shortcut binding, save/load, and asset pipeline are all mapped to tasks.
- Scope check: first implementation uses 4 existing repeatable locations and does not add new map regions or change container capacity.
- Type consistency: rare metadata uses `stableReward`, `stableRewardCount`, and `rareReward`; saved pity uses `rare_gather_misses`; shortcut state uses `shortcut_bindings`.
- UI contract: `ShortcutBar/Slot0..9`, `InventoryOverlay.item_dropped`, and click-to-spawn path remain intact.
- No story break: Ryan/Mira route conditions are not changed; `old_road_wine` only reuses Mira memory flavor metadata.
