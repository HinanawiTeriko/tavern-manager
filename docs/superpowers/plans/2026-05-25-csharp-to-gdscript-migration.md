# C# → GDScript Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert all 22 C# files (~3789 lines) to GDScript, enabling Godot 4 Web export.

**Architecture:** 4-round incremental migration. Rounds 1-2 write all system GDScript files. Round 3 writes all UI GDScript files. Round 4 writes GameManager + MainInit, updates project.godot/.tscn, deletes .NET artifacts. The game remains on .NET through Round 3 (GDScript files exist but aren't wired). Round 4 makes the full switch.

**Tech Stack:** Godot 4.6 (standard), GDScript. Plugins (dialogue_manager, godot_mcp) unchanged.

**Key conversion rules:**
- `Dictionary<K,V>` → GDScript `Dictionary` (implicitly typed)
- `List<T>` → GDScript `Array`
- `JsonSerializer.Deserialize<T>(json)` → `JSON.parse_string(json)` returning Dictionary/Array
- `[Signal] delegate` / `event Action` → `signal name(args)`
- `GetNode<T>(path)` → `$Path` or `get_node(path)`
- `ResourceLoader.Load<T>(path)` → `load(path)`
- `using var file = FileAccess.Open(...)` → `var file = FileAccess.open(...)` (no using/Dispose in GDScript)
- `Mathf.FloorToInt()` → `floori()`
- `Variant.From(x)` → direct assignment (GDScript uses Variant natively)
- `new Random()` → `RandomNumberGenerator.new()` + `.randomize()`
- `?.Invoke()` → `.emit()`
- `string.IsNullOrEmpty(s)` → `s == null or s == ""` or `s.is_empty()`
- `.TryGetValue(key, out var v)` → `.get(key, default)` or `if dict.has(key):`
- Tuples `(string, string)` → use concatenated key `a + "|" + b`

---

### Task 1: Convert SeasoningSystem.cs → seasoning_system.gd

**Files:**
- Create: `scripts/systems/seasoning_system.gd`

- [ ] **Step 1: Write seasoning_system.gd**

```gdscript
class_name SeasoningData
extends RefCounted

var name: String = ""
var tag: String = ""
var color: Array = []


class_name SeasoningSystem
extends RefCounted

var seasonings: Dictionary = {}

func load_data() -> void:
	var file = FileAccess.open("res://data/seasonings.json", FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return
	seasonings = json.data
	GD.print("[Seasoning] 加载 ", seasonings.size(), " 种香料")

func get_seasoning(key: String) -> Dictionary:
	return seasonings.get(key, {})

func is_seasoning(key: String) -> bool:
	return seasonings.has(key)
```

- [ ] **Step 2: Verify syntax — load in Godot editor**

Open project in Godot editor, check `scripts/systems/seasoning_system.gd` has no parse errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/seasoning_system.gd
git commit -m "feat: add SeasoningSystem GDScript"
```

---

### Task 2: Convert ShopSystem.cs → shop_system.gd

**Files:**
- Create: `scripts/systems/shop_system.gd`

- [ ] **Step 1: Write shop_system.gd**

```gdscript
class_name ShopMaterialEntry
extends RefCounted

var key: String = ""
var price: int = 0


class_name ShopRecipeEntry
extends RefCounted

var key: String = ""
var price: int = 0


class_name ShopConfig
extends RefCounted

var materials: Array = []
var recipe_unlocks: Array = []
var mira_discount: float = 0.8


class_name ShopSystem
extends RefCounted

var _material_prices: Dictionary = {}
var _recipe_unlock_prices: Dictionary = {}
var _mira_discount: float = 0.8

func load_config() -> void:
	var file = FileAccess.open("res://data/shop.json", FileAccess.READ)
	if file == null:
		GD.print_err("[Shop] shop.json 未找到")
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		GD.print_err("[Shop] JSON 解析失败: ", error)
		return
	var data = json.data
	if data == null:
		return
	_material_prices.clear()
	if data.has("materials") and data["materials"] != null:
		for m in data["materials"]:
			_material_prices[m["key"]] = m["price"]
	_recipe_unlock_prices.clear()
	if data.has("recipeUnlocks") and data["recipeUnlocks"] != null:
		for r in data["recipeUnlocks"]:
			_recipe_unlock_prices[r["key"]] = r["price"]
	_mira_discount = data.get("miraDiscount", 0.8)
	GD.print("[Shop] 加载 ", _material_prices.size(), " 种材料, ", _recipe_unlock_prices.size(), " 种可解锁配方")

func get_material_price(key: String, mira_active: bool = false) -> int:
	if not _material_prices.has(key):
		return 999
	var price: int = _material_prices[key]
	if mira_active:
		return floori(price * _mira_discount)
	return price

func get_recipe_unlock_price(key: String) -> int:
	if _recipe_unlock_prices.has(key):
		return _recipe_unlock_prices[key]
	return -1

func is_mira_shop_today(current_day: int, narrative) -> bool:
	var scenes = narrative.get_today_scenes(current_day)
	for npc in scenes:
		if npc.id == "mira":
			return true
	return false
```

- [ ] **Step 2: Verify syntax in Godot editor**

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/shop_system.gd
git commit -m "feat: add ShopSystem GDScript"
```

---

### Task 3: Convert CraftSystem.cs → craft_system.gd

**Files:**
- Create: `scripts/systems/craft_system.gd`

- [ ] **Step 1: Write craft_system.gd**

```gdscript
class_name ItemData
extends RefCounted

var name: String = ""
var color: Array = []
var price: int = 0


class_name CraftSystem
extends RefCounted

var items: Dictionary = {}
var _ops: Dictionary = {}
var _combine: Dictionary = {}
var unlocked_recipes: Array = []

func is_recipe_unlocked(key: String) -> bool:
	return unlocked_recipes.has(key)

func unlock_recipe(key: String) -> void:
	if not unlocked_recipes.has(key):
		unlocked_recipes.append(key)

func load_data() -> void:
	load_items()
	load_operations()
	load_combines()
	GD.print("[Craft] 加载 ", items.size(), " 种物品, ", _ops.size(), " 个加工节点, ", _combine.size(), " 条组合规则")

func load_items() -> void:
	var file = FileAccess.open("res://data/items.json", FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return
	items = json.data

func load_operations() -> void:
	var file = FileAccess.open("res://data/operations.json", FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return
	_ops = json.data

func load_combines() -> void:
	var pairs = [
		["dough", "meat_raw", "dough_meat"],
		["ale", "herb", "ale_herb"],
		["grape", "herb", "grape_herb"],
		["meat_raw", "ale", "meat_stew_raw"],
	]
	for p in pairs:
		var a: String = p[0]
		var b: String = p[1]
		var r: String = p[2]
		_combine[_make_key(a, b)] = r
		_combine[_make_key(b, a)] = r

func _make_key(a: String, b: String) -> String:
	return a + "|" + b

func get_item(key: String) -> Dictionary:
	var item: Dictionary = items.get(key, {})
	return item

func get_operations(key: String) -> Dictionary:
	var ops: Dictionary = _ops.get(key, {})
	return ops

func has_operations(key: String) -> bool:
	return _ops.has(key)

func is_product(key: String) -> bool:
	var item = items.get(key, {})
	return item.get("price", 0) > 0

func get_combine_result(a: String, b: String) -> String:
	if a == "" or b == "":
		return ""
	return _combine.get(_make_key(a, b), "")
```

- [ ] **Step 2: Verify syntax in Godot editor**

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/craft_system.gd
git commit -m "feat: add CraftSystem GDScript"
```

---

### Task 4: Convert EconomySystem.cs → economy_system.gd

**Files:**
- Create: `scripts/systems/economy_system.gd`

- [ ] **Step 1: Write economy_system.gd**

```gdscript
class_name EconomySystem
extends RefCounted

signal changed()

var gold: int = 0
var reputation: int = 0
var tavern_level: int = 1
var current_day: int = 1
var gold_today: int = 0
var rep_today: int = 0

const MAX_DAYS: int = 30
const _level_rep_thresholds: Array = [0, 50, 150]

func get_level_rep_threshold() -> int:
	if tavern_level < _level_rep_thresholds.size():
		return _level_rep_thresholds[tavern_level]
	return 0x7FFFFFFF

func add_gold(amount: int) -> void:
	gold += amount
	gold_today += amount
	changed.emit()

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	changed.emit()
	return true

func add_reputation(amount: int) -> void:
	reputation += amount
	rep_today += amount
	_check_level_up()
	changed.emit()

func reset_daily() -> void:
	gold_today = 0
	rep_today = 0

func _check_level_up() -> void:
	if tavern_level < 3 and reputation >= _level_rep_thresholds[tavern_level]:
		tavern_level += 1
		GD.print("[Economy] 酒馆升级到 Lv.", tavern_level)

func is_last_day() -> bool:
	return current_day >= MAX_DAYS
```

- [ ] **Step 2: Verify syntax in Godot editor**

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/economy_system.gd
git commit -m "feat: add EconomySystem GDScript"
```

---

### Task 5: Convert DayCycleSystem.cs → day_cycle_system.gd

**Files:**
- Create: `scripts/systems/day_cycle_system.gd`

- [ ] **Step 1: Write day_cycle_system.gd**

```gdscript
class_name DayCycleSystem
extends RefCounted

enum DayPhase { DAY, NIGHT }

signal phase_changed(phase: int)
signal stamina_changed()

var phase: int = DayPhase.DAY
var stamina: int = 5
var max_stamina: int = 5

func start_day() -> void:
	phase = DayPhase.DAY
	stamina = max_stamina
	stamina_changed.emit()

func spend_stamina(amount: int) -> bool:
	if phase != DayPhase.DAY or stamina < amount:
		return false
	stamina -= amount
	stamina_changed.emit()
	return true

func next_phase() -> void:
	if phase == DayPhase.DAY:
		phase = DayPhase.NIGHT
		phase_changed.emit(phase)
	else:
		phase = DayPhase.DAY
		start_day()
		phase_changed.emit(phase)
```

- [ ] **Step 2: Verify syntax in Godot editor**

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/day_cycle_system.gd
git commit -m "feat: add DayCycleSystem GDScript"
```

---

### Task 6: Convert GuestSystem.cs → guest_system.gd

**Files:**
- Create: `scripts/systems/guest_system.gd`

- [ ] **Step 1: Write guest_system.gd**

```gdscript
class_name GuestData
extends RefCounted

enum GuestType { NORMAL, IMPORTANT }

var guest_name: String = ""
var type: int = GuestType.NORMAL
var order_key: String = ""
var npc_id: String = ""
var patience: float = 60.0
var has_dialogue: bool = false

const BASE_PATIENCE: float = 60.0


class_name GuestSystem
extends RefCounted

signal guest_arrived(guest)
signal guest_left()
signal patience_low()

const _normal_names: Array = [
	"铁锤格鲁姆", "冰霜莱拉", "暗影德恩", "圣光凯尔", "疾风维克斯",
	"暗夜尼克斯", "山丘伯林", "银弦艾莉亚", "怒血索恩", "黎明扎拉",
	"磐石芬恩", "毒刃鲁克"
]

var current_guest = null
var has_guest: bool = false

var _get_available_orders: Callable
var _rng = RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
var _next_spawn: float = 2.0

var guests_served_today: int = 0
var orders_success: int = 0
var orders_failed: int = 0

func _init(available_orders_callable: Callable) -> void:
	_get_available_orders = available_orders_callable
	_rng.randomize()

func update(dt: float, has_guest_flag: bool, menu_open: bool) -> void:
	if not has_guest_flag and not menu_open:
		_spawn_timer += dt
		if _spawn_timer >= _next_spawn:
			_spawn_timer = 0.0
			_next_spawn = _rng.randf() * 3.0 + 2.0
			_spawn_normal()

	if has_guest_flag and not menu_open and current_guest != null:
		var prev_patience: float = current_guest.patience
		current_guest.patience -= dt
		if current_guest.patience <= 15.0 and prev_patience > 15.0:
			patience_low.emit()
		if current_guest.patience <= 0.0:
			clear_guest()

func _spawn_normal() -> void:
	var orders: Array = _get_available_orders.call()
	if orders.size() == 0:
		return
	var g = GuestData.new()
	g.guest_name = _normal_names[_rng.randi() % _normal_names.size()]
	g.type = GuestData.GuestType.NORMAL
	g.order_key = orders[_rng.randi() % orders.size()]
	g.patience = GuestData.BASE_PATIENCE
	g.has_dialogue = false
	current_guest = g
	has_guest = true
	guest_arrived.emit(g)

func spawn_important(npc_id: String, order_key: String) -> void:
	var g = GuestData.new()
	g.guest_name = npc_id
	g.type = GuestData.GuestType.IMPORTANT
	g.order_key = order_key
	g.npc_id = npc_id
	g.patience = GuestData.BASE_PATIENCE * 1.5
	g.has_dialogue = true
	current_guest = g
	has_guest = true
	guest_arrived.emit(g)

func clear_guest() -> void:
	guest_left.emit()
	current_guest = null
	has_guest = false
	_spawn_timer = 0.0
	_next_spawn = _rng.randf() * 2.0 + 2.0

func record_guest_served() -> void:
	guests_served_today += 1

func record_order_success() -> void:
	orders_success += 1

func record_order_failed() -> void:
	orders_failed += 1

func reset_daily() -> void:
	guests_served_today = 0
	orders_success = 0
	orders_failed = 0
```

- [ ] **Step 2: Verify syntax in Godot editor**

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/guest_system.gd
git commit -m "feat: add GuestSystem GDScript"
```

---

### Task 7: Convert NarrativeManager.cs → narrative_manager.gd

**Files:**
- Create: `scripts/systems/narrative_manager.gd`

- [ ] **Step 1: Write narrative_manager.gd**

```gdscript
class_name NpcSceneData
extends RefCounted

var day: int = 0
var dialogue: String = ""
var order: String = ""
var trigger: String = ""
var variables: Array = []


class_name NpcData
extends RefCounted

var id: String = ""
var npc_name: String = ""
var title: String = ""
var description: String = ""
var affection_start: int = 0
var scenes: Array = []
var endings: Dictionary = {}


class_name NarrativeManager
extends RefCounted

var all_npcs: Array = []
var dialogue_vars: Dictionary = {}
var key_items: Array = []
var affection: Dictionary = {}
var endings: Dictionary = {}
var today_important_npc: String = ""
var day_encounter_triggered: bool = false

func set_var(key: String, value) -> void:
	dialogue_vars[key] = value

func get_var(key: String):
	return dialogue_vars.get(key, null)

func has_key_item(item_id: String) -> bool:
	return key_items.has(item_id)

func add_key_item(item_id: String) -> void:
	if not key_items.has(item_id):
		key_items.append(item_id)
	set_var("has_" + item_id, true)

func set_affection(npc_id: String, value: int) -> void:
	affection[npc_id] = value
	set_var("aff_" + npc_id, value)

func get_affection(npc_id: String) -> int:
	var v = dialogue_vars.get("aff_" + npc_id, 0)
	return int(v)

func set_ending(npc_id: String, ending: String) -> void:
	endings[npc_id] = ending
	GD.print("[Narrative] ", npc_id, " 结局 → ", ending)

func load_npc_data() -> void:
	dialogue_vars["has_sleep_powder"] = false
	dialogue_vars["ryan_drugged"] = false
	dialogue_vars["ryan_ending"] = ""
	dialogue_vars["aff_ryan"] = 0
	dialogue_vars["aff_mira"] = 5

	var file = FileAccess.open("res://data/npcs.json", FileAccess.READ)
	if file == null:
		GD.print("[Narrative] npcs.json 未找到，使用默认变量")
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		GD.print_err("[Narrative] JSON 解析失败: ", error)
		return
	var root: Dictionary = json.data
	var npcs_array: Array = root["npcs"]
	for npc_dict in npcs_array:
		var npc = NpcData.new()
		npc.id = npc_dict["id"]
		npc.npc_name = npc_dict["name"]
		npc.title = npc_dict["title"]
		npc.description = npc_dict["description"]
		npc.affection_start = npc_dict["affectionStart"]
		npc.scenes = _parse_scenes(npc_dict["scenes"])
		npc.endings = _parse_endings(npc_dict["endings"])
		all_npcs.append(npc)
		set_affection(npc.id, npc.affection_start)
	GD.print("[Narrative] 加载 ", all_npcs.size(), " 个 NPC")

func _parse_scenes(scenes_array: Array) -> Array:
	var result: Array = []
	for scene_dict in scenes_array:
		var scene = NpcSceneData.new()
		scene.day = scene_dict["day"]
		scene.dialogue = scene_dict["dialogue"]
		scene.order = scene_dict["order"]
		scene.trigger = scene_dict["trigger"]
		if scene_dict.has("variables"):
			scene.variables = []
			for v in scene_dict["variables"]:
				scene.variables.append(v)
		result.append(scene)
	return result

func _parse_endings(endings_dict: Dictionary) -> Dictionary:
	return endings_dict

func get_today_scenes(day: int) -> Array:
	var result: Array = []
	for npc in all_npcs:
		for scene in npc.scenes:
			if scene.day == day:
				if scene.trigger == "auto":
					result.append(npc)
				elif scene.trigger.begins_with("affection"):
					var parts = scene.trigger.split(">=")
					if parts.size() == 2:
						var threshold: int = int(parts[1].strip_edges())
						if get_affection(npc.id) >= threshold:
							result.append(npc)
				break
	return result

func get_today_npc_fates(day: int) -> Array:
	var result: Array = []
	for npc in all_npcs:
		for scene in npc.scenes:
			if scene.day == day:
				var ending_var: String = npc.id + "_ending"
				if dialogue_vars.has(ending_var):
					var ending_key: String = dialogue_vars[ending_var]
					if ending_key != null and ending_key != "" and npc.endings.has(ending_key):
						result.append({
							"npc_name": npc.npc_name,
							"npc_title": npc.title,
							"fate_text": npc.endings[ending_key]
						})
				break
	return result
```

- [ ] **Step 2: Verify syntax in Godot editor**

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/narrative_manager.gd
git commit -m "feat: add NarrativeManager GDScript"
```

---

### Task 8: Convert TextureManager.cs + ThemeColors.cs + TitleAmbience.cs

**Files:**
- Create: `scripts/ui/texture_manager.gd`
- Create: `scripts/ui/theme_colors.gd`
- Create: `scripts/ui/title_ambience.gd`

- [ ] **Step 1: Write texture_manager.gd**

```gdscript
class_name TextureManager
extends RefCounted

static func try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func try_load_style_box(path: String) -> StyleBoxTexture:
	var tex: Texture2D = try_load(path)
	if tex == null:
		return null
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = Rect2(0, 0, tex.get_width(), tex.get_height())
	return sb
```

- [ ] **Step 2: Write theme_colors.gd**

```gdscript
class_name ThemeColors
extends RefCounted

const AMBER_PRIMARY = Color(1.0, 0.741, 0.498)
const AMBER_BRIGHT = Color(1.0, 0.584, 0.0)
const AMBER_DARK = Color(0.8, 0.45, 0.0)
const TEXT_ON_AMBER = Color(0.294, 0.157, 0.0)

const BACKGROUND_DEEP = Color(0.086, 0.075, 0.067)
const SURFACE_LOW = Color(0.122, 0.106, 0.098)
const SURFACE_MID = Color(0.137, 0.122, 0.114)
const SURFACE_HIGH = Color(0.18, 0.161, 0.153)
const SURFACE_HIGHEST = Color(0.224, 0.204, 0.192)

const TEXT_LIGHT = Color(0.918, 0.882, 0.867)
const TEXT_SUBTITLE = Color(0.859, 0.761, 0.678)
const TEXT_DIM = Color(0.64, 0.553, 0.478)

const SUCCESS = Color(0.29, 0.55, 0.25)
const DANGER = Color(0.65, 0.15, 0.1)
const PANEL_BORDER = Color(0.333, 0.263, 0.204)

# Cache — use a static instance for mutable cache
static var _inst = null

var _cached_btn_wide_normal = null
var _cached_btn_wide_hover = null
var _cached_btn_wide_pressed = null
var _cached_btn_small_normal = null
var _cached_btn_small_hover = null
var _cached_btn_small_pressed = null
var _cached_panel_parchment = null
var _cached_bar_shortcut_bg = null
var _cached_bar_top_panel = null

static func _get() -> RefCounted:
	if _inst == null:
		_inst = ThemeColors.new()
	return _inst

static func button_normal(w: int = 2, w_bot: int = 4) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = AMBER_PRIMARY
	sb.border_width_left = w; sb.border_width_top = w
	sb.border_width_right = w; sb.border_width_bottom = w_bot
	sb.border_color = Color(0, 0, 0, 0.4)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb

static func button_hover(w: int = 2, w_bot: int = 4) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = AMBER_BRIGHT
	sb.border_width_left = w; sb.border_width_top = w
	sb.border_width_right = w; sb.border_width_bottom = w_bot
	sb.border_color = Color(0, 0, 0, 0.5)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb

static func button_pressed(w_top: int = 4, w: int = 2) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = AMBER_DARK
	sb.border_width_left = w; sb.border_width_top = w_top
	sb.border_width_right = w; sb.border_width_bottom = w
	sb.border_color = Color(0, 0, 0, 0.5)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb

static func style_button(btn: Button, font_size: int = 16) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", TEXT_ON_AMBER)
	btn.add_theme_color_override("font_hover_color", TEXT_ON_AMBER)
	btn.add_theme_color_override("font_pressed_color", TEXT_ON_AMBER)
	var inst = _get()
	var tex_normal = inst._btn_wide_normal()
	var tex_hover = inst._btn_wide_hover()
	var tex_pressed = inst._btn_wide_pressed()
	if tex_normal != null and tex_hover != null and tex_pressed != null:
		btn.add_theme_stylebox_override("normal", tex_normal)
		btn.add_theme_stylebox_override("hover", tex_hover)
		btn.add_theme_stylebox_override("pressed", tex_pressed)
	else:
		btn.add_theme_stylebox_override("normal", button_normal())
		btn.add_theme_stylebox_override("hover", button_hover())
		btn.add_theme_stylebox_override("pressed", button_pressed())

static func style_small_button(btn: Button, font_size: int = 13) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", TEXT_ON_AMBER)
	btn.add_theme_color_override("font_hover_color", TEXT_ON_AMBER)
	btn.add_theme_color_override("font_pressed_color", TEXT_ON_AMBER)
	var inst = _get()
	var tex_normal = inst._btn_small_normal()
	var tex_hover = inst._btn_small_hover()
	var tex_pressed = inst._btn_small_pressed()
	if tex_normal != null and tex_hover != null and tex_pressed != null:
		btn.add_theme_stylebox_override("normal", tex_normal)
		btn.add_theme_stylebox_override("hover", tex_hover)
		btn.add_theme_stylebox_override("pressed", tex_pressed)
	else:
		btn.add_theme_stylebox_override("normal", button_normal(1, 2))
		btn.add_theme_stylebox_override("hover", button_hover(1, 2))
		btn.add_theme_stylebox_override("pressed", button_pressed(2, 1))

static func wood_panel() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(SURFACE_MID, 0.85)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = PANEL_BORDER
	return sb

static func parchment_panel() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.15, 0.11, 0.92)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(AMBER_PRIMARY, 0.25)
	return sb

static func style_header(label: Label, font_size: int = 28) -> void:
	label.add_theme_color_override("font_color", AMBER_PRIMARY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))

static func style_body(label: Label, font_size: int = 16) -> void:
	label.add_theme_color_override("font_color", TEXT_LIGHT)
	label.add_theme_font_size_override("font_size", font_size)

static func style_dim(label: Label, font_size: int = 14) -> void:
	label.add_theme_color_override("font_color", TEXT_SUBTITLE)
	label.add_theme_font_size_override("font_size", font_size)

# Instance methods for cached textures
func _btn_wide_normal():
	if _cached_btn_wide_normal == null:
		_cached_btn_wide_normal = TextureManager.try_load_style_box("res://assets/textures/ui/btn_wide_normal.png")
	return _cached_btn_wide_normal

func _btn_wide_hover():
	if _cached_btn_wide_hover == null:
		_cached_btn_wide_hover = TextureManager.try_load_style_box("res://assets/textures/ui/btn_wide_hover.png")
	return _cached_btn_wide_hover

func _btn_wide_pressed():
	if _cached_btn_wide_pressed == null:
		_cached_btn_wide_pressed = TextureManager.try_load_style_box("res://assets/textures/ui/btn_wide_pressed.png")
	return _cached_btn_wide_pressed

func _btn_small_normal():
	if _cached_btn_small_normal == null:
		_cached_btn_small_normal = TextureManager.try_load_style_box("res://assets/textures/ui/btn_small_normal.png")
	return _cached_btn_small_normal

func _btn_small_hover():
	if _cached_btn_small_hover == null:
		_cached_btn_small_hover = TextureManager.try_load_style_box("res://assets/textures/ui/btn_small_hover.png")
	return _cached_btn_small_hover

func _btn_small_pressed():
	if _cached_btn_small_pressed == null:
		_cached_btn_small_pressed = TextureManager.try_load_style_box("res://assets/textures/ui/btn_small_pressed.png")
	return _cached_btn_small_pressed

func panel_parchment():
	if _cached_panel_parchment == null:
		_cached_panel_parchment = TextureManager.try_load_style_box("res://assets/textures/ui/panel_parchment_9patch.png")
	return _cached_panel_parchment

func bar_shortcut_bg():
	if _cached_bar_shortcut_bg == null:
		_cached_bar_shortcut_bg = TextureManager.try_load_style_box("res://assets/textures/ui/bar_shortcut_bg.png")
	return _cached_bar_shortcut_bg

func bar_top_panel():
	if _cached_bar_top_panel == null:
		_cached_bar_top_panel = TextureManager.try_load_style_box("res://assets/textures/ui/bar_top_panel.png")
	return _cached_bar_top_panel
```

- [ ] **Step 3: Write title_ambience.gd**

```gdscript
class_name TitleAmbience
extends Node2D

@export var star_region: Rect2 = Rect2(20, 20, 380, 200)
@export var star_count: int = 10
@export var star_color: Color = Color.WHITE
@export var star_base_size: float = 3.0

@export var dust_region: Rect2 = Rect2(380, 280, 560, 280)
@export var dust_count: int = 30
@export var dust_color: Color = Color(1.0, 0.82, 0.55)
@export var dust_base_size: float = 2.0

var _stars: Array = []
var _motes: Array = []
var _rng = RandomNumberGenerator.new()
var _time: float = 0.0

func _ready() -> void:
	z_index = -50
	_rng.randomize()

	for _i in range(star_count):
		_stars.append({
			"pos": Vector2(
				star_region.position.x + _rng.randf() * star_region.size.x,
				star_region.position.y + _rng.randf() * star_region.size.y
			),
			"phase": _rng.randf() * PI * 2.0,
			"speed": 0.8 + _rng.randf() * 2.5,
			"size_mul": 0.6 + _rng.randf() * 0.9
		})

	for _i in range(dust_count):
		_motes.append(_spawn_mote(true))

func _spawn_mote(initial: bool) -> Dictionary:
	var m = {
		"pos": Vector2(
			dust_region.position.x + _rng.randf() * dust_region.size.x,
			dust_region.position.y + _rng.randf() * dust_region.size.y
		),
		"vel": Vector2(
			-8.0 + _rng.randf() * 16.0,
			-10.0 - _rng.randf() * 15.0
		),
		"max_life": 3.0 + _rng.randf() * 6.0,
		"size": 1.0 + _rng.randf() * 2.5,
		"alpha": 0.3 + _rng.randf() * 0.7
	}
	if initial:
		m["life"] = _rng.randf() * m["max_life"]
	else:
		m["life"] = m["max_life"]
	return m

func _process(delta: float) -> void:
	_time += delta

	for i in range(_stars.size()):
		_stars[i]["phase"] += _stars[i]["speed"] * delta
		if _stars[i]["phase"] > PI * 2.0:
			_stars[i]["phase"] -= PI * 2.0

	for i in range(_motes.size()):
		_motes[i]["life"] -= delta
		_motes[i]["pos"] += _motes[i]["vel"] * delta
		_motes[i]["vel"].x += (-4.0 + _rng.randf() * 8.0) * delta
		if _motes[i]["life"] <= 0.0 or not dust_region.has_point(_motes[i]["pos"]):
			_motes[i] = _spawn_mote(false)

	queue_redraw()

func _draw() -> void:
	for star in _stars:
		var raw = (sin(star["phase"]) + 1.0) / 2.0
		var brightness: float
		if raw < 0.15: brightness = 0.0
		elif raw < 0.4: brightness = 0.25
		elif raw < 0.75: brightness = 0.6
		else: brightness = 1.0
		if brightness < 0.01:
			continue
		var size = star_base_size * star["size_mul"]
		var c = Color(star_color, brightness)
		if brightness >= 0.6:
			draw_rect(Rect2(star["pos"].x - size * 0.5, star["pos"].y - size * 1.5, size, size * 3.0), c)
			draw_rect(Rect2(star["pos"].x - size * 1.5, star["pos"].y - size * 0.5, size * 3.0, size), c)
		else:
			draw_rect(Rect2(star["pos"].x - size * 0.5, star["pos"].y - size * 0.5, size, size), c)

	for mote in _motes:
		var life_ratio = mote["life"] / mote["max_life"]
		var alpha = mote["alpha"] * min(life_ratio * 1.5, 1.0)
		var c = Color(dust_color, alpha)
		var size = mote["size"]
		draw_rect(Rect2(mote["pos"].x - size * 0.5, mote["pos"].y - size * 0.5, size, size), c)
```

- [ ] **Step 4: Verify syntax in Godot editor**

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/texture_manager.gd scripts/ui/theme_colors.gd scripts/ui/title_ambience.gd
git commit -m "feat: add UI helper GDScripts (TextureManager, ThemeColors, TitleAmbience)"
```

---

### Task 9: Convert MixingArea.cs → mixing_area.gd

**Files:**
- Create: `scripts/ui/mixing_area.gd`

- [ ] **Step 1: Write mixing_area.gd**

```gdscript
class_name MixingArea
extends Control

signal combine_query(a: String, b: String)
signal contents_changed()

var _items: Array = []
var _gm = null

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	mouse_filter = Control.MOUSE_FILTER_STOP

func add_item(key: String) -> void:
	if key == "":
		return

	var distinct: Array = []
	for i in _items:
		if i != key and not distinct.has(i):
			distinct.append(i)

	if distinct.size() > 0 and not _items.has(key):
		combine_query.emit(key, distinct[0])
		return

	_items.append(key)
	_refresh()

func force_add_item(key: String) -> void:
	if key == "":
		return
	_items.append(key)
	_refresh()

func force_add_items(keys: Array) -> void:
	for key in keys:
		if key != "":
			_items.append(key)
	_refresh()

func remove_item(key: String) -> void:
	var idx = _items.find(key)
	if idx >= 0:
		_items.remove_at(idx)
		_refresh()

func clear_items() -> void:
	_items.clear()
	_refresh()

func consume_and_replace(consumed: Array, new_key: String) -> void:
	for c in consumed:
		var idx = _items.find(c)
		if idx >= 0:
			_items.remove_at(idx)
	_items.append(new_key)
	_refresh()

func _refresh() -> void:
	contents_changed.emit()
	queue_redraw()

func _draw() -> void:
	var rect = get_rect()

	draw_rect(rect, Color(0.15, 0.12, 0.1))
	draw_rect(rect, Color(0.3, 0.25, 0.2), false)

	if _items.size() == 0:
		var font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(8, rect.size.y * 0.35), "拖入材料",
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 16)
		return

	var margin = 8.0
	var item_w = (rect.size.x - margin * (_items.size() + 1)) / max(1, _items.size())
	item_w = min(item_w, 100.0)

	for i in range(_items.size()):
		var item = _gm.Craft.get_item(_items[i])
		var c: Color = Colors.GRAY
		if not item.is_empty():
			var col_arr = item.get("color", [])
			if col_arr is Array and col_arr.size() >= 3:
				c = Color(col_arr[0], col_arr[1], col_arr[2])
		var x = margin + i * (item_w + margin)
		var y = rect.size.y * 0.25
		var h = rect.size.y * 0.5

		draw_rect(Rect2(x, y, item_w, h), c)
		draw_rect(Rect2(x, y, item_w, h), Color.WHITE, false)

		var name = item.get("name", _items[i])
		var font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(x + 2, y + 14), name,
				HORIZONTAL_ALIGNMENT_LEFT, item_w - 4, 14)
```

- [ ] **Step 2: Verify syntax in Godot editor**

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/mixing_area.gd
git commit -m "feat: add MixingArea GDScript"
```

---

### Task 10: Convert ProductPanel.cs → product_panel.gd

**Files:**
- Create: `scripts/ui/product_panel.gd`

- [ ] **Step 1: Write product_panel.gd**

```gdscript
class_name ProductPanel
extends Control

signal product_selected(key: String)

var _list: VBoxContainer
var _gm
var _mixing_area

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_mixing_area = get_node("../MixingArea")
	_list = VBoxContainer.new()
	add_child(_list)
	_mixing_area.contents_changed.connect(_refresh)

func _exit_tree() -> void:
	if _mixing_area != null:
		_mixing_area.contents_changed.disconnect(_refresh)

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var contents: Array = _mixing_area._items
	if contents.size() == 0:
		return

	var products: Array = []

	for key in contents:
		var ops: Dictionary = _gm.Craft.get_operations(key)
		for result_key in ops.values():
			if not products.has(result_key):
				products.append(result_key)

	var distinct: Array = []
	for k in contents:
		if not distinct.has(k):
			distinct.append(k)

	if distinct.size() >= 2:
		for i in range(distinct.size()):
			for j in range(i + 1, distinct.size()):
				var combined = _gm.Craft.get_combine_result(distinct[i], distinct[j])
				if combined != "" and not products.has(combined):
					products.append(combined)

	for key in products:
		var item: Dictionary = _gm.Craft.get_item(key)
		if item.is_empty():
			continue
		var btn = Button.new()
		btn.text = item.get("name", key)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeColors.style_small_button(btn, 12)
		btn.pressed.connect(_on_product_selected.bind(key))
		_list.add_child(btn)

func _on_product_selected(key: String) -> void:
	var contents: Array = _mixing_area._items.duplicate()

	if contents.size() == 1 and contents[0] == key:
		return

	for c in contents:
		var ops: Dictionary = _gm.Craft.get_operations(c)
		if ops.values().has(key):
			_mixing_area.consume_and_replace([c], key)
			return

	if contents.size() >= 2:
		for i in range(contents.size()):
			for j in range(i + 1, contents.size()):
				if _gm.Craft.get_combine_result(contents[i], contents[j]) == key:
					_mixing_area.consume_and_replace([contents[i], contents[j]], key)
					return
```

- [ ] **Step 2: Verify syntax, commit**

```bash
git add scripts/ui/product_panel.gd
git commit -m "feat: add ProductPanel GDScript"
```

---

### Task 11: Convert SeasoningPanel.cs + SeasoningZone.cs

**Files:**
- Create: `scripts/ui/seasoning_panel.gd`
- Create: `scripts/ui/seasoning_zone.gd`

- [ ] **Step 1: Write seasoning_panel.gd**

```gdscript
class_name SeasoningPanel
extends Control

signal seasoning_applied(key: String)
signal seasoning_skipped()

var _btn_row: HBoxContainer
var _gm
var _current_item_key: String = ""

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_btn_row = HBoxContainer.new()
	add_child(_btn_row)
	visible = false

func show_for(item_key: String) -> void:
	if not _gm.Craft.is_product(item_key):
		visible = false
		return

	_current_item_key = item_key

	for child in _btn_row.get_children():
		child.queue_free()

	for key in _gm.seasonings_dict:
		var data: Dictionary = _gm.seasonings_dict[key]
		var btn = Button.new()
		btn.text = data.get("name", key)
		ThemeColors.style_small_button(btn, 12)
		btn.pressed.connect(func(): seasoning_applied.emit(key); hide())
		_btn_row.add_child(btn)

	var skip_btn = Button.new()
	skip_btn.text = "不加"
	ThemeColors.style_small_button(skip_btn, 12)
	skip_btn.pressed.connect(func(): seasoning_skipped.emit(); hide())
	_btn_row.add_child(skip_btn)

	visible = true
```

- [ ] **Step 2: Write seasoning_zone.gd**

```gdscript
class_name SeasoningZone
extends Control

signal seasoning_applied(key: String)
signal seasoning_cleared()

var _gm
var _applied_seasoning: String = ""
var _hint_label: Label
var _applied_label: Label
var _btn_row: HBoxContainer

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	_hint_label = Label.new()
	_hint_label.text = "拖入香料"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_bottom = 0.6
	_hint_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_hint_label.add_theme_font_size_override("font_size", 12)
	add_child(_hint_label)

	_applied_label = Label.new()
	_applied_label.visible = false
	_applied_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_applied_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_applied_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_applied_label.anchor_right = 1.0
	_applied_label.anchor_bottom = 0.6
	_applied_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_applied_label.add_theme_font_size_override("font_size", 12)
	add_child(_applied_label)

	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 2)
	add_child(_btn_row)

	visible = false

func activate() -> void:
	_applied_seasoning = ""
	_applied_label.visible = false
	_hint_label.visible = true
	_rebuild_buttons()
	_btn_row.offset_left = 2
	_btn_row.offset_top = int(size.y * 0.6)
	_btn_row.offset_right = int(size.x) - 2
	_btn_row.offset_bottom = int(size.y) - 2
	visible = true
	queue_redraw()

func deactivate() -> void:
	_applied_seasoning = ""
	visible = false
	queue_redraw()

func try_apply_seasoning(item_key: String) -> bool:
	if not visible:
		return false
	var seasoning: Dictionary = _gm.seasoning_get(item_key)
	if seasoning.is_empty():
		return false

	if item_key == "sleep_powder":
		if not _gm.inventory.has(item_key) or _gm.inventory[item_key] < 1:
			return false
		_gm.inventory[item_key] = _gm.inventory[item_key] - 1
		if _gm.inventory[item_key] <= 0:
			_gm.inventory.erase(item_key)
		_gm.notify_inventory_changed()

	_apply_seasoning(item_key)
	return true

func get_applied_seasoning() -> String:
	return _applied_seasoning

func clear_seasoning() -> void:
	_applied_seasoning = ""
	_applied_label.visible = false
	_hint_label.visible = true
	_rebuild_buttons()
	queue_redraw()
	seasoning_cleared.emit()

func _apply_seasoning(key: String) -> void:
	_applied_seasoning = key
	var seasoning: Dictionary = _gm.seasoning_get(key)
	_applied_label.text = "已加: " + seasoning.get("name", key)
	_applied_label.visible = true
	_hint_label.visible = false
	for child in _btn_row.get_children():
		child.queue_free()
	queue_redraw()
	seasoning_applied.emit(key)

func _rebuild_buttons() -> void:
	for child in _btn_row.get_children():
		child.queue_free()

	for key in _gm.seasonings_dict:
		var data: Dictionary = _gm.seasonings_dict[key]
		if key == "sleep_powder":
			if not _gm.inventory.has(key) or _gm.inventory[key] < 1:
				continue

		var btn = Button.new()
		btn.text = data.get("name", key)
		btn.custom_minimum_size = Vector2(28, 24)
		ThemeColors.style_small_button(btn, 10)
		btn.pressed.connect(_apply_seasoning.bind(key))
		_btn_row.add_child(btn)

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var bg: Color
	if _applied_seasoning != "":
		bg = Color(0.15, 0.13, 0.06)
	else:
		bg = Color(0.13, 0.10, 0.07)
	draw_rect(rect, bg)

	var dash_color = Color(ThemeColors.AMBER_PRIMARY, 0.5)
	var dash = 5.0
	var gap = 4.0
	var w = rect.size.x
	var h = rect.size.y

	var x = 0.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(min(x + dash, w), 0), dash_color)
		draw_line(Vector2(x, h), Vector2(min(x + dash, w), h), dash_color)
		x += dash + gap

	var y = 0.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(0, min(y + dash, h)), dash_color)
		draw_line(Vector2(w, y), Vector2(w, min(y + dash, h)), dash_color)
		y += dash + gap
```

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/seasoning_panel.gd scripts/ui/seasoning_zone.gd
git commit -m "feat: add SeasoningPanel and SeasoningZone GDScript"
```

---

### Task 12: Convert CraftStation.cs → craft_station.gd

**Files:**
- Create: `scripts/ui/craft_station.gd`

This is the largest UI file (630 lines). The full conversion follows the same patterns established in prior tasks: `GetNode<T>` → `$`/`get_node()`, events → signals, `_gm.Craft` → GDScript calls.

- [ ] **Step 1: Write craft_station.gd**

```gdscript
class_name CraftStation
extends Control

signal serve_requested(item_key: String, seasoning_tag: String)
signal clear_requested()
signal gesture_completed(action: String)

var _mixing_area
var _product_panel
var _seasoning_zone
var _operation_buttons: Control
var _clear_btn: Button
var _result_slot: ColorRect
var _result_label: Label

# Combine query bar
var _combine_query_bar: HBoxContainer
var _combine_query_label: Label
var _combine_yes_btn: Button
var _combine_no_btn: Button
var _pending_a: String = ""
var _pending_b: String = ""

# Drag state
var _dragging: bool = false
var _drag_material: String = ""
var _drag_panel: ColorRect
var _overlay_menu
var _dialogue_overlay

# Shortcut bar
var bar_materials: Array = []
var bar_counts: Array = []
var _shortcut_slots: Array = []
var _shortcut_labels: Array = []

var _gm

# Heat
var _heating: bool = false
var _heat_progress: float = 0.0
const HEAT_TIME: float = 1.5
var _heat_target_op: String = ""
var _heat_btn_ref: Button = null

# Stir
var _stirring: bool = false
var _stir_circles: int = 0
const STIR_TARGET: int = 3
var _stir_last_mouse: Vector2
var _stir_total_angle: float = 0.0

func _ready() -> void:
	_gm = get_node("/root/GameManager")

	_mixing_area = $MixingArea
	_product_panel = $ProductPanel
	_seasoning_zone = $SeasoningZone
	_seasoning_zone.visible = false
	_operation_buttons = $OperationButtons
	_clear_btn = $ClearBtn
	_result_slot = $ResultSlot
	_result_label = $ResultSlot/Label
	_overlay_menu = get_node_or_null("../OverlayMenu")
	_dialogue_overlay = get_node_or_null("../DialogueOverlay")

	_combine_query_bar = $CombineQueryBar
	_combine_query_label = $CombineQueryBar/Label
	_combine_yes_btn = $CombineQueryBar/YesBtn
	_combine_no_btn = $CombineQueryBar/NoBtn
	_combine_query_bar.visible = false

	_mixing_area.combine_query.connect(_show_combine_query)
	_mixing_area.contents_changed.connect(_refresh_operation_buttons)
	_mixing_area.contents_changed.connect(_check_result_ready)

	_combine_yes_btn.pressed.connect(func():
		_combine_query_bar.visible = false
		var result = _gm.Craft.get_combine_result(_pending_a, _pending_b)
		if result != "":
			_mixing_area.clear_items()
			_mixing_area.force_add_item(result)
		else:
			_mixing_area.force_add_items([_pending_a, _pending_b])
	)

	_combine_no_btn.pressed.connect(func():
		_combine_query_bar.visible = false
		_mixing_area.force_add_item(_pending_a)
	)

	_clear_btn.pressed.connect(func():
		for item in _mixing_area._items:
			_add_to_inventory(item)
		_mixing_area.clear_items()
		_clear_result_slot()
		_seasoning_zone.deactivate()
		clear_requested.emit()
	)

	_seasoning_zone.seasoning_applied.connect(func(seasoning: String):
		_result_slot.set_meta("seasoning", seasoning)
	)

	ThemeColors.style_small_button(_clear_btn, 12)
	ThemeColors.style_small_button(_combine_yes_btn, 12)
	ThemeColors.style_small_button(_combine_no_btn, 12)

	_result_slot.color = Color(0.06, 0.05, 0.04)

	_init_shortcut_bar()
	_init_drag_panel()
	_sync_from_inventory()
	_gm.inventory_changed.connect(_sync_from_inventory)

func _exit_tree() -> void:
	if _gm != null:
		_gm.inventory_changed.disconnect(_sync_from_inventory)

func _show_combine_query(a: String, b: String) -> void:
	_pending_a = a
	_pending_b = b
	var item_a: Dictionary = _gm.Craft.get_item(a)
	var item_b: Dictionary = _gm.Craft.get_item(b)
	_combine_query_label.text = "混合 " + item_a.get("name", a) + " 和 " + item_b.get("name", b) + "？"
	_combine_query_bar.visible = true

func _refresh_operation_buttons() -> void:
	for child in _operation_buttons.get_children():
		child.queue_free()

	var contents: Array = _mixing_area._items
	if contents.size() == 0:
		return

	var first_key: String = contents[0]
	var ops: Dictionary = _gm.Craft.get_operations(first_key)
	if ops.size() == 0:
		return

	for op in ops:
		var result: String = ops[op]
		var label_text: String = op
		match op:
			"heat": label_text = "加热"
			"stir": label_text = "搅拌"
			"shake": label_text = "摇晃"
			"pour": label_text = "倒出"

		var btn = Button.new()
		btn.text = label_text
		ThemeColors.style_small_button(btn, 12)

		match op:
			"heat":
				btn.button_down.connect(_start_heat.bind(btn, result))
				btn.button_up.connect(_stop_heat)
			"stir":
				btn.button_down.connect(_start_stir.bind(btn, result))
				btn.button_up.connect(_stop_stir)
			_:
				btn.pressed.connect(_execute_operation.bind(result))

		_operation_buttons.add_child(btn)

func _start_heat(btn: Button, result_key: String) -> void:
	_heating = true
	_heat_progress = 0.0
	_heat_target_op = result_key
	_heat_btn_ref = btn
	btn.text = "加热中..."

func _stop_heat() -> void:
	if not _heating:
		return
	_heating = false
	if _heat_progress < HEAT_TIME:
		_heat_btn_ref.text = "加热"
	_heat_btn_ref = null

func _start_stir(btn: Button, result_key: String) -> void:
	_stirring = true
	_stir_circles = 0
	_stir_total_angle = 0.0
	_stir_last_mouse = get_viewport().get_mouse_position()
	_heat_target_op = result_key
	_heat_btn_ref = btn
	btn.text = "搅拌中... (转圈)"

func _stop_stir() -> void:
	if not _stirring:
		return
	_stirring = false
	if _stir_circles < STIR_TARGET:
		_heat_btn_ref.text = "搅拌"
	_heat_btn_ref = null

func _execute_operation(result_key: String) -> void:
	var contents: Array = _mixing_area._items
	if contents.size() == 0:
		return
	_mixing_area.consume_and_replace([contents[0]], result_key)
	gesture_completed.emit("done")

func _check_result_ready() -> void:
	var contents: Array = _mixing_area._items
	if contents.size() == 1:
		var key: String = contents[0]
		if not _gm.Craft.has_operations(key):
			_move_to_result_slot(key)
			_mixing_area.clear_items()

func _move_to_result_slot(key: String) -> void:
	var item: Dictionary = _gm.Craft.get_item(key)
	if not item.is_empty():
		var col_arr = item.get("color", [])
		if col_arr is Array and col_arr.size() >= 3:
			_result_slot.color = Color(col_arr[0], col_arr[1], col_arr[2])
		_result_label.text = item.get("name", key)
	else:
		_result_label.text = key

	_result_slot.set_meta("item_key", key)
	_result_slot.set_meta("seasoning", "")
	_seasoning_zone.activate()

func _clear_result_slot() -> void:
	_result_label.text = ""
	_result_slot.color = Color(0.06, 0.05, 0.04)
	_result_slot.remove_meta("item_key")
	_result_slot.remove_meta("seasoning")
	_seasoning_zone.deactivate()

func _process(delta: float) -> void:
	if _overlay_menu != null and _overlay_menu.visible:
		return

	if _dragging:
		_drag_panel.position = get_viewport().get_mouse_position() - Vector2(32, 32)

	if _heating:
		_heat_progress += delta
		var ratio: float = _heat_progress / HEAT_TIME
		if _heat_progress >= HEAT_TIME:
			_heating = false
			if _heat_btn_ref != null:
				_heat_btn_ref.text = "加热 ✓"
			gesture_completed.emit("heat")
			_execute_operation(_heat_target_op)
		elif _heat_btn_ref != null:
			_heat_btn_ref.text = "加热中 %d%%" % int(ratio * 100)

	if _stirring:
		var mouse = get_viewport().get_mouse_position()
		var btn_center = _heat_btn_ref.global_position if _heat_btn_ref != null else Vector2.ZERO
		var prev = _stir_last_mouse - btn_center
		var cur = mouse - btn_center
		var angle_prev = atan2(prev.y, prev.x)
		var angle_cur = atan2(cur.y, cur.x)
		var delta_angle = angle_cur - angle_prev

		if delta_angle > PI: delta_angle -= PI * 2.0
		elif delta_angle < -PI: delta_angle += PI * 2.0

		if abs(delta_angle) > 0.005:
			_stir_total_angle += delta_angle
		_stir_last_mouse = mouse

		_stir_circles = int(abs(_stir_total_angle) / (PI * 2.0))
		if _heat_btn_ref != null:
			_heat_btn_ref.text = "搅拌... %d/%d圈" % [_stir_circles, STIR_TARGET]
		if _stir_circles >= STIR_TARGET:
			_stirring = false
			if _heat_btn_ref != null:
				_heat_btn_ref.text = "搅拌 ✓"
			gesture_completed.emit("stir")
			_execute_operation(_heat_target_op)

func _input(event: InputEvent) -> void:
	if _overlay_menu != null and _overlay_menu.visible:
		return
	if _dialogue_overlay != null and _dialogue_overlay.visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _dragging:
			_try_pick_up(event.position)
		elif not event.pressed and _dragging:
			_try_drop(event.position)

func _try_pick_up(pos: Vector2) -> void:
	if _overlay_menu != null and _overlay_menu.visible:
		var backpack_list = get_node_or_null("../OverlayMenu/BackpackPanel/BackpackList")
		if backpack_list != null:
			for row in backpack_list.get_children():
				if _hit_test(row, pos):
					var mat: String = row.get_meta("material_key", "")
					if mat != "" and _gm.inventory.get(mat, 0) > 0:
						_remove_from_inventory(mat)
						_start_drag(pos, mat)
						return
		return

	var serve_key: String = _result_slot.get_meta("item_key", "")
	if serve_key != "" and _hit_test(_result_slot, pos):
		_start_drag(pos, serve_key)
		_result_label.text = ""
		_clear_result_slot()
		return

	if _hit_test(_mixing_area, pos):
		var contents: Array = _mixing_area._items
		if contents.size() > 0:
			var mat: String = contents[contents.size() - 1]
			_mixing_area.remove_item(mat)
			_start_drag(pos, mat)
			return

	for i in range(10):
		if _hit_test(_shortcut_slots[i], pos) and bar_materials[i] != "" and bar_counts[i] > 0:
			var mat: String = bar_materials[i]
			_remove_from_inventory(mat)
			_start_drag(pos, mat)
			return

func _try_drop(pos: Vector2) -> void:
	var menu_open: bool = _overlay_menu != null and _overlay_menu.visible

	if not menu_open:
		var customer_area = get_node("../CustomerArea")
		if _hit_test(customer_area, pos):
			if _gm.Guests.has_guest and _drag_material != "":
				var serve_key = _drag_material
				var serve_seasoning = _seasoning_zone.get_applied_seasoning()
				var item: Dictionary = _gm.Craft.get_item(serve_key)
				if not item.is_empty():
					_result_slot.set_meta("item_key", serve_key)
					_result_slot.set_meta("seasoning", serve_seasoning)
					_end_drag()
					serve_requested.emit(serve_key, serve_seasoning)
					return
			_return_drag()
			_end_drag()
			return

		if _hit_test(_mixing_area, pos) and _drag_material != "":
			_mixing_area.add_item(_drag_material)
			_end_drag()
			return

	if _hit_test(_seasoning_zone, pos) and _drag_material != "":
		if _seasoning_zone.try_apply_seasoning(_drag_material):
			_end_drag()
			return

	for i in range(10):
		if _hit_test(_shortcut_slots[i], pos):
			if bar_materials[i] == "":
				bar_materials[i] = _drag_material
				_add_to_inventory(_drag_material)
				_end_drag()
				_refresh_shortcut(i)
				return
			elif bar_materials[i] == _drag_material:
				_add_to_inventory(_drag_material)
				_end_drag()
				_refresh_shortcut(i)
				return

	if menu_open:
		_return_drag()
		_end_drag()
		return
	_return_drag()
	_end_drag()

func _start_drag(pos: Vector2, material: String) -> void:
	_dragging = true
	_drag_material = material
	_drag_panel.visible = true
	_drag_panel.size = Vector2(64, 64)
	_drag_panel.position = pos - Vector2(32, 32)
	var item: Dictionary = _gm.Craft.get_item(material)
	if not item.is_empty():
		var col_arr = item.get("color", [])
		if col_arr is Array and col_arr.size() >= 3:
			_drag_panel.color = Color(col_arr[0], col_arr[1], col_arr[2])
		else:
			_drag_panel.color = Colors.GRAY
	else:
		_drag_panel.color = Colors.GRAY

func _end_drag() -> void:
	_dragging = false
	_drag_panel.visible = false
	_drag_material = ""

func _return_drag() -> void:
	_add_to_inventory(_drag_material)

func _init_shortcut_bar() -> void:
	bar_materials.resize(10)
	bar_counts.resize(10)
	_shortcut_slots.resize(10)
	_shortcut_labels.resize(10)

	var bar = get_node("../ShortcutBar")
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(10):
		_shortcut_slots[i] = bar.get_node("Slot%d" % i)
		_shortcut_slots[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shortcut_labels[i] = bar.get_node("Slot%d/Label" % i)
		_shortcut_labels[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shortcut_slots[i].color = Color(0.08, 0.06, 0.04)

func _init_drag_panel() -> void:
	var drag_canvas = CanvasLayer.new()
	drag_canvas.layer = 1
	get_parent().add_child(drag_canvas)
	_drag_panel = ColorRect.new()
	_drag_panel.visible = false
	_drag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_canvas.add_child(_drag_panel)

func _sync_from_inventory() -> void:
	var inv: Dictionary = _gm.inventory
	for i in range(10):
		if bar_materials[i] != "" and inv.get(bar_materials[i], 0) > 0:
			bar_counts[i] = inv[bar_materials[i]]
			_refresh_shortcut(i)
		else:
			bar_materials[i] = ""
			bar_counts[i] = 0

	for key in inv:
		var count: int = inv[key]
		if count <= 0:
			continue
		var already_shown = false
		for i in range(10):
			if bar_materials[i] == key:
				already_shown = true
				break
		if already_shown:
			continue
		for i in range(10):
			if bar_materials[i] == "":
				bar_materials[i] = key
				bar_counts[i] = count
				_refresh_shortcut(i)
				break

	for i in range(10):
		if bar_materials[i] == "":
			_refresh_shortcut(i)

func _add_to_inventory(key: String, amount: int = 1) -> void:
	if key == "":
		return
	var cur: int = _gm.inventory.get(key, 0)
	_gm.inventory[key] = cur + amount
	_gm.notify_inventory_changed()

func _remove_from_inventory(key: String, amount: int = 1) -> void:
	if key == "":
		return
	if _gm.inventory.has(key):
		var remaining: int = _gm.inventory[key] - amount
		if remaining <= 0:
			_gm.inventory.erase(key)
		else:
			_gm.inventory[key] = remaining
	_gm.notify_inventory_changed()

func _refresh_shortcut(i: int) -> void:
	if bar_materials[i] == "":
		_shortcut_slots[i].color = Color(0.1, 0.08, 0.06)
		_shortcut_labels[i].text = ""
	else:
		var item: Dictionary = _gm.Craft.get_item(bar_materials[i])
		if not item.is_empty():
			var col_arr = item.get("color", [])
			if col_arr is Array and col_arr.size() >= 3:
				_shortcut_slots[i].color = Color(col_arr[0], col_arr[1], col_arr[2])
			else:
				_shortcut_slots[i].color = Colors.GRAY
		else:
			_shortcut_slots[i].color = Colors.GRAY
		_shortcut_labels[i].text = "%s x%d" % [item.get("name", bar_materials[i]), bar_counts[i]]

func refresh_all() -> void:
	for i in range(10):
		_refresh_shortcut(i)

func _hit_test(c: Control, p: Vector2) -> bool:
	var r = c.get_global_rect()
	return p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y and p.y <= r.end.y
```

- [ ] **Step 2: Verify syntax, commit**

```bash
git add scripts/ui/craft_station.gd
git commit -m "feat: add CraftStation GDScript"
```

---

### Task 13: Convert TavernView.cs → tavern_view.gd

**Files:**
- Create: `scripts/ui/tavern_view.gd`

- [ ] **Step 1: Write tavern_view.gd**

```gdscript
class_name TavernView
extends Node2D

var _bg_sprite: Sprite2D
var _customer_sprite: TextureRect
var _customer_name: Label
var _order_bubble: Label
var _timer_bar: ProgressBar
var _gold_label: Label
var _rep_label: Label
var _day_label: Label
var _menu_panel: Panel
var _message_label: Label
var _end_night_btn: Button
var _dialogue_overlay: ColorRect
var _gm

const NPC_TEXTURE_KEYS: Dictionary = {
	"ryan": "ryan_neutral",
	"mira": "mira_neutral",
}

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_bg_sprite = $Background
	_customer_sprite = $CustomerArea/CustomerSprite
	_customer_name = $CustomerArea/CustomerName
	_order_bubble = $CustomerArea/OrderBubble
	_timer_bar = $CustomerArea/TimerBar
	_gold_label = $TopPanel/GoldLabel
	_rep_label = $TopPanel/ReputationLabel
	_day_label = $TopPanel/DayLabel
	_message_label = $BottomBar/MessageLabel
	_end_night_btn = $TopPanel/EndNightBtn
	_dialogue_overlay = $DialogueOverlay

	_menu_panel = $OverlayMenu
	$TopPanel/MenuButton.pressed.connect(_toggle_menu)
	$OverlayMenu/CloseBtn.pressed.connect(_toggle_menu)
	_menu_panel.visible = false

	_end_night_btn.pressed.connect(_on_end_night)

	_apply_theme()

	$BottomBar.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_theme() -> void:
	var bg_tex = TextureManager.try_load("res://assets/textures/backgrounds/tavern_bg.png")
	if bg_tex != null:
		_bg_sprite.texture = bg_tex
	else:
		var grad = GradientTexture2D.new()
		grad.width = 1280; grad.height = 720
		var g = Gradient.new()
		g.colors = [ThemeColors.BACKGROUND_DEEP, ThemeColors.SURFACE_LOW]
		g.offsets = [0.0, 1.0]
		grad.gradient = g
		_bg_sprite.texture = grad

	_customer_name.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_customer_name.add_theme_font_size_override("font_size", 18)
	_order_bubble.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_order_bubble.add_theme_font_size_override("font_size", 15)

	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 16)
	_rep_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_rep_label.add_theme_font_size_override("font_size", 16)
	_day_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_day_label.add_theme_font_size_override("font_size", 15)

	ThemeColors.style_button($TopPanel/MenuButton, 14)
	ThemeColors.style_button(_end_night_btn, 14)

	var parchment_tex = ThemeColors._get().panel_parchment()
	if parchment_tex != null:
		_menu_panel.add_theme_stylebox_override("panel", parchment_tex)
	else:
		_menu_panel.add_theme_stylebox_override("panel", ThemeColors.parchment_panel())

	ThemeColors.style_button($OverlayMenu/TabBtns/BtnRecipes, 14)
	ThemeColors.style_button($OverlayMenu/TabBtns/BtnBackpack, 14)
	ThemeColors.style_button($OverlayMenu/CloseBtn, 14)

	var recipe_panel = $OverlayMenu/RecipePanel
	var backpack_panel = $OverlayMenu/BackpackPanel
	$OverlayMenu/TabBtns/BtnRecipes.pressed.connect(func(): recipe_panel.visible = true; backpack_panel.visible = false)
	$OverlayMenu/TabBtns/BtnBackpack.pressed.connect(func(): recipe_panel.visible = false; backpack_panel.visible = true)

	_gm.inventory_changed.connect(_on_inventory_changed)

	_message_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_message_label.add_theme_font_size_override("font_size", 14)

	var patience_bg = TextureManager.try_load_style_box("res://assets/textures/ui/bar_patience_bg.png")
	var patience_fill = TextureManager.try_load_style_box("res://assets/textures/ui/bar_patience_fill.png")
	if patience_bg != null:
		_timer_bar.add_theme_stylebox_override("background", patience_bg)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(ThemeColors.SURFACE_HIGH, 0.8)
		sb.border_width_left = 1; sb.border_width_top = 1
		sb.border_width_right = 1; sb.border_width_bottom = 1
		sb.border_color = ThemeColors.PANEL_BORDER
		_timer_bar.add_theme_stylebox_override("background", sb)
	if patience_fill != null:
		_timer_bar.add_theme_stylebox_override("fill", patience_fill)
	_timer_bar.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)

	var top_bar_tex = ThemeColors._get().bar_top_panel()
	var top_panel_bg = get_node_or_null("TopPanelBg")
	if top_panel_bg != null:
		if top_bar_tex != null:
			top_panel_bg.add_theme_stylebox_override("panel", top_bar_tex)
		else:
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(ThemeColors.BACKGROUND_DEEP, 0.85)
			sb.border_width_bottom = 1
			sb.border_color = ThemeColors.PANEL_BORDER
			top_panel_bg.add_theme_stylebox_override("panel", sb)

	var shortcut_bg_tex = ThemeColors._get().bar_shortcut_bg()
	var shortcut_bg = get_node_or_null("ShortcutBarBg")
	if shortcut_bg != null:
		if shortcut_bg_tex != null:
			shortcut_bg.add_theme_stylebox_override("panel", shortcut_bg_tex)
		else:
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(ThemeColors.SURFACE_LOW, 0.8)
			sb.border_width_top = 1
			sb.border_color = ThemeColors.PANEL_BORDER
			shortcut_bg.add_theme_stylebox_override("panel", sb)

func show_customer(name: String, order: String, npc_id: String = "guest") -> void:
	var tex_key: String = NPC_TEXTURE_KEYS.get(npc_id, npc_id)
	var tex = TextureManager.try_load("res://assets/textures/characters/" + tex_key + ".png")
	if tex != null:
		_customer_sprite.texture = tex
		_customer_sprite.modulate = Color.WHITE
	else:
		var grad = GradientTexture2D.new()
		grad.width = 200; grad.height = 250
		var g = Gradient.new()
		g.colors = [Color(0.35, 0.25, 0.4), Color(0.2, 0.15, 0.25)]
		g.offsets = [0.0, 1.0]
		grad.gradient = g
		_customer_sprite.texture = grad
		_customer_sprite.modulate = Color.WHITE

	_customer_sprite.visible = true
	_customer_name.text = name
	_order_bubble.text = "「来一份" + order + "！」"
	_order_bubble.visible = true

func hide_customer() -> void:
	_customer_sprite.visible = false
	_customer_name.text = "等待中……"
	_order_bubble.visible = false

func update_timer(ratio: float) -> void:
	_timer_bar.value = ratio * 100.0

func update_top_bar(gold: int, rep: int, day: int, max_day: int) -> void:
	_gold_label.text = "金币：" + str(gold)
	_rep_label.text = "声望：" + str(rep)
	_day_label.text = "第%d/%d天" % [day, max_day]

func show_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)

func set_dialogue_mode(active: bool) -> void:
	_dialogue_overlay.visible = active

func _exit_tree() -> void:
	if _gm != null:
		_gm.inventory_changed.disconnect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if not is_instance_valid(self):
		return
	if _menu_panel.visible:
		_build_backpack_list()

func _toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible
	if _menu_panel.visible:
		_build_recipe_list()
		_build_backpack_list()

func _on_end_night() -> void:
	_gm.end_night()

func _build_recipe_list() -> void:
	var recipe_list = _menu_panel.get_node("RecipePanel/RecipeList")
	for child in recipe_list.get_children():
		child.queue_free()

	for key in _gm.Craft.items:
		var item_data: Dictionary = _gm.Craft.items[key]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size = Vector2(0, 32)

		var icon_tex = _gm.try_load_material_icon(key)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)
		else:
			var col_arr = item_data.get("color", [])
			var mat_color = Colors.GRAY
			if col_arr is Array and col_arr.size() >= 3:
				mat_color = Color(col_arr[0], col_arr[1], col_arr[2])
			var box = ColorRect.new()
			box.color = mat_color
			box.custom_minimum_size = Vector2(36, 20)
			row.add_child(box)

		var price_str = ""
		if item_data.get("price", 0) > 0:
			price_str = str(item_data["price"]) + "金"
		var name_label = Label.new()
		name_label.text = " " + item_data.get("name", key) + "  " + price_str
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)

		recipe_list.add_child(row)

func _build_backpack_list() -> void:
	var inventory: Dictionary = _gm.inventory
	var backpack_list = _menu_panel.get_node("BackpackPanel/BackpackList")
	for child in backpack_list.get_children():
		child.queue_free()

	for mat in inventory:
		var count: int = inventory[mat]
		if count <= 0:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size = Vector2(0, 32)
		row.set_meta("material_key", mat)

		var icon_tex = _gm.try_load_material_icon(mat)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)
		else:
			var mat_item: Dictionary = _gm.Craft.get_item(mat)
			var col_arr = mat_item.get("color", [])
			var mat_color = Colors.GRAY
			if col_arr is Array and col_arr.size() >= 3:
				mat_color = Color(col_arr[0], col_arr[1], col_arr[2])
			var box = ColorRect.new()
			box.color = mat_color
			box.custom_minimum_size = Vector2(36, 20)
			row.add_child(box)

		var mat_item2: Dictionary = _gm.Craft.get_item(mat)
		var display_name = mat_item2.get("name", mat)
		var label = Label.new()
		label.text = display_name + "  x" + str(count)
		label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)

		backpack_list.add_child(row)
```

- [ ] **Step 2: Verify syntax, commit**

```bash
git add scripts/ui/tavern_view.gd
git commit -m "feat: add TavernView GDScript"
```

---

### Task 14: Convert remaining UI views (DayMapView, TitleScreen, EndingScreen, LedgerScreen)

**Files:**
- Create: `scripts/ui/day_map_view.gd`
- Create: `scripts/ui/title_screen.gd`
- Create: `scripts/ui/ending_screen.gd`
- Create: `scripts/ui/ledger_screen.gd`

These four files are straightforward Node2D scenes. The DayMapView is the largest (~509 lines of C#) and contains the shop UI + gathering logic. Each follows the same conversion patterns already established.

- [ ] **Step 1: Write day_map_view.gd**

```gdscript
class_name LocationData
extends RefCounted

var id: String = ""
var name: String = ""
var cost: int = 0
var materials: Array = []
var description: String = ""


class_name LocationsFile
extends RefCounted

var max_stamina: int = 5
var locations: Array = []


class_name DayMapView
extends Node2D

signal gathering_confirmed(assignments: Dictionary)

var _location_list: VBoxContainer
var _stamina_label: Label
var _day_label: Label
var _go_button: Button
var _result_panel: Panel
var _result_label: Label
var _continue_btn: Button

var _assignments: Dictionary = {}
var _stamina_left: int = 0
var _max_stamina: int = 5
var _locations: Array = []

var _assign_labels: Dictionary = {}
var _loc_add_btns: Dictionary = {}
var _loc_sub_btns: Dictionary = {}

# Shop
var _is_shop_tab: bool = false
var _gather_tab_btn: Button
var _shop_tab_btn: Button
var _shop_panel: ScrollContainer
var _shop_title: Label
var _gold_label: Label
var _material_list: VBoxContainer
var _recipe_list: VBoxContainer
var _is_mira_shop: bool = false

func _ready() -> void:
	_location_list = $MapArea/LocationList
	_stamina_label = $TopBar/StaminaLabel
	_day_label = $TopBar/DayLabel
	_go_button = $GoButton
	_result_panel = $ResultPanel
	_result_label = $ResultPanel/ResultLabel
	_continue_btn = $ResultPanel/ContinueBtn

	var title_label = $MapArea/TitleLabel
	ThemeColors.style_header(title_label, 26)
	ThemeColors.style_header(_day_label, 22)
	_stamina_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_stamina_label.add_theme_font_size_override("font_size", 20)

	ThemeColors.style_button(_go_button, 24)
	ThemeColors.style_button(_continue_btn, 16)

	_result_panel.add_theme_stylebox_override("panel", ThemeColors.parchment_panel())
	_result_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_result_label.add_theme_font_size_override("font_size", 18)

	_go_button.pressed.connect(_on_go_pressed)
	_continue_btn.pressed.connect(_on_continue)

	_load_locations()
	_build_location_ui()

	_gold_label = $TopBar/GoldLabel
	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 20)

	_build_tab_buttons()
	_build_shop_ui()

	var bg_node = get_node_or_null("Background")
	if bg_node != null:
		var bg_tex = TextureManager.try_load("res://assets/textures/backgrounds/daymap_bg.png")
		if bg_tex != null:
			bg_node.texture = bg_tex
		else:
			var grad = GradientTexture2D.new()
			grad.width = 1280; grad.height = 720
			var g = Gradient.new()
			g.colors = [ThemeColors.BACKGROUND_DEEP, ThemeColors.SURFACE_MID]
			g.offsets = [0.0, 1.0]
			grad.gradient = g
			bg_node.texture = grad

func _load_locations() -> void:
	var file = FileAccess.open("res://data/locations.json", FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	json.parse(json_text)
	var data: Dictionary = json.data
	_locations = []
	for loc_dict in data["locations"]:
		var loc = LocationData.new()
		loc.id = loc_dict["id"]
		loc.name = loc_dict["name"]
		loc.cost = loc_dict["cost"]
		loc.materials = []
		for m in loc_dict["materials"]:
			loc.materials.append(m)
		loc.description = loc_dict["description"]
		_locations.append(loc)
	_max_stamina = data["maxStamina"]
	_stamina_left = _max_stamina

func show_day(day: int, total_days: int) -> void:
	_day_label.text = "第 %d/%d 天 — 白天·采集" % [day, total_days]
	_stamina_left = _max_stamina
	_assignments.clear()
	for kv in _assign_labels:
		kv.value.text = "0"
	_update_stamina_display()
	_result_panel.visible = false
	_continue_btn.visible = true
	for btn in _loc_add_btns.values():
		btn.disabled = false
	for btn in _loc_sub_btns.values():
		btn.disabled = true
	_go_button.disabled = false
	_go_button.visible = true
	_is_shop_tab = false
	if _gather_tab_btn != null:
		_update_tab_appearance()
	if _shop_panel != null:
		_shop_panel.visible = false
	var map_area = $MapArea
	map_area.get_node("TitleLabel").visible = true
	map_area.get_node("LocationList").visible = true
	_update_gold_display()

func _build_location_ui() -> void:
	for loc in _locations:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, 52)

		var info = VBoxContainer.new()
		info.custom_minimum_size = Vector2(360, 0)

		var name_label = Label.new()
		name_label.text = loc.name + "  [" + str(loc.cost) + "体力]"
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 18)
		info.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = loc.description
		desc_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
		desc_label.add_theme_font_size_override("font_size", 13)
		info.add_child(desc_label)

		row.add_child(info)

		var count_label = Label.new()
		count_label.text = "0"
		count_label.custom_minimum_size = Vector2(40, 0)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
		count_label.add_theme_font_size_override("font_size", 22)
		row.add_child(count_label)

		var add_btn = Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(40, 36)
		ThemeColors.style_button(add_btn, 16)
		var loc_id: String = loc.id
		add_btn.pressed.connect(_add_assignment.bind(loc_id, loc.cost, count_label))
		row.add_child(add_btn)

		var sub_btn = Button.new()
		sub_btn.text = "-"
		sub_btn.custom_minimum_size = Vector2(40, 36)
		sub_btn.disabled = true
		ThemeColors.style_button(sub_btn, 16)
		sub_btn.pressed.connect(_remove_assignment.bind(loc_id, loc.cost, count_label))
		row.add_child(sub_btn)

		_assign_labels[loc.id] = count_label
		_loc_add_btns[loc.id] = add_btn
		_loc_sub_btns[loc.id] = sub_btn

		_location_list.add_child(row)

func _add_assignment(loc_id: String, cost: int, count_label: Label) -> void:
	if _stamina_left < cost:
		return
	_stamina_left -= cost
	var cur: int = _assignments.get(loc_id, 0)
	_assignments[loc_id] = cur + 1
	count_label.text = str(_assignments[loc_id])
	_update_stamina_display()
	if _loc_sub_btns.has(loc_id):
		_loc_sub_btns[loc_id].disabled = false
	if _stamina_left < 1:
		for btn in _loc_add_btns.values():
			btn.disabled = true

func _remove_assignment(loc_id: String, cost: int, count_label: Label) -> void:
	var cur: int = _assignments.get(loc_id, 0)
	if cur < 1:
		return
	_stamina_left += cost
	_assignments[loc_id] = cur - 1
	if _assignments[loc_id] <= 0:
		_assignments.erase(loc_id)
	count_label.text = str(_assignments.get(loc_id, 0))
	_update_stamina_display()
	for btn in _loc_add_btns.values():
		btn.disabled = false
	if _loc_sub_btns.has(loc_id):
		_loc_sub_btns[loc_id].disabled = not _assignments.has(loc_id)

func _update_stamina_display() -> void:
	_stamina_label.text = "体力：" + str(_stamina_left) + "/" + str(_max_stamina)

func _on_go_pressed() -> void:
	if _assignments.size() == 0:
		_result_label.text = "请至少分配一点体力到采集点！"
		_result_panel.visible = true
		_continue_btn.visible = false
		return
	_go_button.disabled = true
	gathering_confirmed.emit(_assignments)

func _on_continue() -> void:
	_result_panel.visible = false
	# gathering_confirmed already emitted

func _update_gold_display() -> void:
	var gm = get_node("/root/GameManager")
	if gm != null:
		_gold_label.text = "金币：" + str(gm.economy.gold)

func _build_tab_buttons() -> void:
	var map_area = $MapArea
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.custom_minimum_size = Vector2(0, 40)

	_gather_tab_btn = Button.new()
	_gather_tab_btn.text = "采集"
	_gather_tab_btn.custom_minimum_size = Vector2(100, 36)
	ThemeColors.style_button(_gather_tab_btn, 16)
	_gather_tab_btn.pressed.connect(_switch_tab.bind(false))
	tab_row.add_child(_gather_tab_btn)

	_shop_tab_btn = Button.new()
	_shop_tab_btn.text = "商店"
	_shop_tab_btn.custom_minimum_size = Vector2(100, 36)
	ThemeColors.style_button(_shop_tab_btn, 16)
	_shop_tab_btn.pressed.connect(_switch_tab.bind(true))
	tab_row.add_child(_shop_tab_btn)

	map_area.add_child(tab_row)
	map_area.move_child(tab_row, 0)

	var title_label = map_area.get_node("TitleLabel")
	title_label.offset_top = 45
	title_label.offset_bottom = 80
	var location_list = map_area.get_node("LocationList")
	location_list.offset_top = 95
	location_list.offset_bottom = 420

	_update_tab_appearance()

func _switch_tab(shop: bool) -> void:
	_is_shop_tab = shop
	_update_tab_appearance()

	var map_area = $MapArea
	map_area.get_node("TitleLabel").visible = not shop
	map_area.get_node("LocationList").visible = not shop
	_shop_panel.visible = shop

	if shop:
		_refresh_shop_ui()

	_go_button.visible = not shop

func _update_tab_appearance() -> void:
	if _gather_tab_btn == null or _shop_tab_btn == null:
		return
	_gather_tab_btn.modulate = Color.DIM_GRAY if _is_shop_tab else Color.WHITE
	_shop_tab_btn.modulate = Color.WHITE if _is_shop_tab else Color.DIM_GRAY

func _build_shop_ui() -> void:
	_shop_panel = ScrollContainer.new()
	_shop_panel.anchor_left = 0.0; _shop_panel.anchor_right = 1.0
	_shop_panel.offset_left = 0; _shop_panel.offset_top = 95
	_shop_panel.offset_right = 1000; _shop_panel.offset_bottom = 420
	_shop_panel.visible = false
	$MapArea.add_child(_shop_panel)

	var shop_content = VBoxContainer.new()
	shop_content.add_theme_constant_override("separation", 8)
	_shop_panel.add_child(shop_content)

	_shop_title = Label.new()
	_shop_title.custom_minimum_size = Vector2(0, 36)
	ThemeColors.style_header(_shop_title, 22)
	shop_content.add_child(_shop_title)

	var mat_title = Label.new()
	mat_title.text = "—— 购买材料 ——"
	mat_title.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	mat_title.add_theme_font_size_override("font_size", 16)
	mat_title.custom_minimum_size = Vector2(0, 30)
	shop_content.add_child(mat_title)

	_material_list = VBoxContainer.new()
	_material_list.add_theme_constant_override("separation", 4)
	shop_content.add_child(_material_list)

	var recipe_title = Label.new()
	recipe_title.text = "—— 解锁配方 ——"
	recipe_title.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	recipe_title.add_theme_font_size_override("font_size", 16)
	recipe_title.custom_minimum_size = Vector2(0, 30)
	shop_content.add_child(recipe_title)

	_recipe_list = VBoxContainer.new()
	_recipe_list.add_theme_constant_override("separation", 4)
	shop_content.add_child(_recipe_list)

func _refresh_shop_ui() -> void:
	var gm = get_node("/root/GameManager")
	if gm == null:
		return

	_is_mira_shop = gm.shop.is_mira_shop_today(gm.economy.current_day, gm.narrative)
	_shop_title.text = "米拉的旅行商店" if _is_mira_shop else "商店"

	_build_material_rows(gm)
	_build_recipe_rows(gm)
	_update_gold_display()

func _build_material_rows(gm) -> void:
	for child in _material_list.get_children():
		child.queue_free()

	var materials = [
		["ale", "麦芽"], ["grape", "葡萄"], ["flour", "面粉"],
		["meat_raw", "生肉"], ["herb", "草药"]
	]

	for pair in materials:
		var key: String = pair[0]
		var name: String = pair[1]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 40)

		var name_label = Label.new()
		name_label.text = name
		name_label.custom_minimum_size = Vector2(70, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 16)
		row.add_child(name_label)

		var price: int = gm.shop.get_material_price(key, _is_mira_shop)
		var price_label = Label.new()
		if _is_mira_shop:
			price_label.text = str(gm.shop.get_material_price(key)) + "→" + str(price) + "金"
		else:
			price_label.text = str(price) + "金"
		price_label.custom_minimum_size = Vector2(70, 0)
		price_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
		price_label.add_theme_font_size_override("font_size", 14)
		row.add_child(price_label)

		var sub_btn = Button.new()
		sub_btn.text = "-"
		sub_btn.custom_minimum_size = Vector2(36, 30)
		ThemeColors.style_button(sub_btn, 14)
		var qty_label = Label.new()
		qty_label.text = "0"
		qty_label.custom_minimum_size = Vector2(30, 0)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
		qty_label.add_theme_font_size_override("font_size", 18)
		var add_btn = Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(36, 30)
		ThemeColors.style_button(add_btn, 14)

		sub_btn.pressed.connect(func():
			var cur = int(qty_label.text)
			if cur > 0:
				cur -= 1
				qty_label.text = str(cur)
		)
		add_btn.pressed.connect(func():
			var cur = int(qty_label.text)
			cur += 1
			qty_label.text = str(cur)
		)

		var buy_btn = Button.new()
		buy_btn.text = "购买"
		buy_btn.custom_minimum_size = Vector2(56, 30)
		ThemeColors.style_button(buy_btn, 14)
		buy_btn.pressed.connect(func():
			var qty = int(qty_label.text)
			if qty < 1:
				return
			if gm.buy_material(key, qty, _is_mira_shop):
				qty_label.text = "0"
				_update_gold_display()
		)

		row.add_child(sub_btn)
		row.add_child(qty_label)
		row.add_child(add_btn)
		row.add_child(buy_btn)
		_material_list.add_child(row)

func _build_recipe_rows(gm) -> void:
	for child in _recipe_list.get_children():
		child.queue_free()

	var unlocks = [
		["Herbal Ale", "草药麦酒"], ["SpicedWine", "香料红酒"],
		["MeatSand", "肉夹面包"], ["Meat Stew", "肉汤"]
	]

	for pair in unlocks:
		var key: String = pair[0]
		var name: String = pair[1]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 40)

		var name_label = Label.new()
		name_label.text = name
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 16)
		row.add_child(name_label)

		if gm.craft.is_recipe_unlocked(key):
			var owned = Label.new()
			owned.text = "已拥有"
			owned.custom_minimum_size = Vector2(80, 0)
			owned.add_theme_color_override("font_color", ThemeColors.TEXT_DIM)
			owned.add_theme_font_size_override("font_size", 14)
			row.add_child(owned)
		else:
			var price: int = gm.shop.get_recipe_unlock_price(key)
			if price < 0:
				_recipe_list.add_child(row)
				continue
			var price_label = Label.new()
			price_label.text = str(price) + "金"
			price_label.custom_minimum_size = Vector2(60, 0)
			price_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
			price_label.add_theme_font_size_override("font_size", 14)
			row.add_child(price_label)

			var unlock_btn = Button.new()
			unlock_btn.text = "解锁"
			unlock_btn.custom_minimum_size = Vector2(56, 30)
			ThemeColors.style_button(unlock_btn, 14)
			unlock_btn.pressed.connect(func():
				if gm.buy_recipe_unlock(key):
					_update_gold_display()
					_build_recipe_rows(gm)
			)
			row.add_child(unlock_btn)

		_recipe_list.add_child(row)
```

- [ ] **Step 2: Write title_screen.gd**

```gdscript
class_name TitleScreen
extends Node2D

func _ready() -> void:
	var ambience = $Ambience
	ambience.star_color = Color(ThemeColors.AMBER_PRIMARY, 0.9)
	ambience.dust_color = ThemeColors.AMBER_PRIMARY

	var title = $UI/TitlePanel/TitleLabel
	ThemeColors.style_header(title, 48)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))

	var title_panel = $UI/TitlePanel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(ThemeColors.SURFACE_MID, 0.7)
	panel_style.border_width_left = 2; panel_style.border_width_top = 2
	panel_style.border_width_right = 2; panel_style.border_width_bottom = 2
	panel_style.border_color = Color(ThemeColors.AMBER_PRIMARY, 0.3)
	title_panel.add_theme_stylebox_override("panel", panel_style)

	var subtitle = $UI/SubtitleLabel
	subtitle.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	subtitle.add_theme_font_size_override("font_size", 18)

	var btn = $UI/StartButton
	ThemeColors.style_button(btn, 22)
	btn.pressed.connect(_on_start)

	var hint = $UI/HintLabel
	hint.add_theme_color_override("font_color", Color(ThemeColors.TEXT_LIGHT, 0.6))
	hint.add_theme_font_size_override("font_size", 14)

	var ver = $UI/VersionLabel
	ver.add_theme_color_override("font_color", Color(ThemeColors.TEXT_SUBTITLE, 0.35))
	ver.add_theme_font_size_override("font_size", 11)

	_try_load_deco("Deco/CandleLeft", "res://assets/textures/ui/deco_candle_left.png")
	_try_load_deco("Deco/CandleRight", "res://assets/textures/ui/deco_candle_right.png")
	_try_load_deco("Deco/Mug", "res://assets/textures/ui/deco_mug.png")
	_try_load_deco("Deco/Emblem", "res://assets/textures/ui/deco_emblem.png")

	var title_sign = get_node_or_null("UI/TitlePanel/TitleSign")
	if title_sign != null:
		var sign_tex = TextureManager.try_load("res://assets/textures/ui/title_sign.png")
		if sign_tex != null:
			title_sign.texture = sign_tex

func _try_load_deco(node_path: String, tex_path: String) -> void:
	var node = get_node_or_null(node_path)
	if node != null:
		var tex = TextureManager.try_load(tex_path)
		if tex != null:
			node.texture = tex

func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/DayMap.tscn")
```

- [ ] **Step 3: Write ending_screen.gd**

```gdscript
class_name EndingScreen
extends Node2D

var _npc_endings_list: VBoxContainer
var _gold_label: Label
var _rep_label: Label
var _title_label: Label

func _ready() -> void:
	_npc_endings_list = $Content/NPCEndingsList
	_gold_label = $Content/Stats/GoldLabel
	_rep_label = $Content/Stats/RepLabel
	_title_label = $Content/TitleLabel

	ThemeColors.style_header(_title_label, 36)
	_title_label.add_theme_constant_override("outline_size", 3)

	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 20)
	_rep_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_rep_label.add_theme_font_size_override("font_size", 20)

	ThemeColors.style_button($Content/QuitBtn)
	ThemeColors.style_button($Content/RestartBtn)

	$Content/QuitBtn.pressed.connect(func(): get_tree().quit())
	$Content/RestartBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn"))

	var bg_node = get_node_or_null("Background")
	if bg_node != null:
		var bg_tex = TextureManager.try_load("res://assets/textures/backgrounds/ending_bg.png")
		if bg_tex != null:
			bg_node.texture = bg_tex
		else:
			var grad = GradientTexture2D.new()
			grad.width = 1280; grad.height = 720
			var g = Gradient.new()
			g.colors = [Color(0.055, 0.047, 0.04), ThemeColors.BACKGROUND_DEEP]
			g.offsets = [0.0, 1.0]
			grad.gradient = g
			bg_node.texture = grad

func show_endings(gold: int, rep: int, npc_endings: Dictionary) -> void:
	_gold_label.text = "最终金币：" + str(gold)
	_rep_label.text = "最终声望：" + str(rep)

	for child in _npc_endings_list.get_children():
		child.queue_free()

	var divider = ColorRect.new()
	divider.color = Color(ThemeColors.AMBER_PRIMARY, 0.3)
	divider.custom_minimum_size = Vector2(0, 2)
	_npc_endings_list.add_child(divider)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_npc_endings_list.add_child(spacer)

	for npc_id in npc_endings:
		var ending: String = npc_endings[npc_id]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, 40)

		var name_label = Label.new()
		name_label.text = npc_id
		name_label.custom_minimum_size = Vector2(120, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
		name_label.add_theme_font_size_override("font_size", 18)
		row.add_child(name_label)

		var ending_label = Label.new()
		ending_label.text = ending
		ending_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		ending_label.add_theme_font_size_override("font_size", 15)
		row.add_child(ending_label)

		_npc_endings_list.add_child(row)
```

- [ ] **Step 4: Write ledger_screen.gd**

```gdscript
class_name LedgerScreen
extends Node2D

var _title_label: Label
var _stats_list: VBoxContainer
var _fate_title: Label
var _fate_list: VBoxContainer
var _continue_btn: Button

func _ready() -> void:
	_title_label = $UI/TitleLabel
	_stats_list = $UI/StatsList
	_fate_title = $UI/FateTitle
	_fate_list = $UI/FateList
	_continue_btn = $UI/ContinueBtn

	_continue_btn.pressed.connect(_on_continue)

	var gm = get_node("/root/GameManager")
	var data = gm.current_ledger_data
	if data != null:
		_render(data)

func _render(data: Dictionary) -> void:
	_title_label.text = "第 %d 天 · 营业结算" % data["day"]
	ThemeColors.style_header(_title_label, 30)

	_add_stat_row("金币收入    +%d 金      累计: %d 金" % [data["gold_today"], data["gold_total"]])
	_add_stat_row("声望变化    +%d           累计: %d" % [data["rep_today"], data["rep_total"]])
	_add_stat_row("服务客人    %d 位" % data["guests_served"])
	_add_stat_row("成功订单    %d 单" % data["orders_success"])
	_add_stat_row("失败订单    %d 单" % data["orders_failed"])

	var fates: Array = data.get("npc_fates", [])
	if fates.size() > 0:
		_fate_title.text = "今日宿命"
		ThemeColors.style_header(_fate_title, 22)

		for fate in fates:
			var card = VBoxContainer.new()
			card.add_theme_constant_override("separation", 4)

			var name_label = Label.new()
			name_label.text = fate["npc_name"] + " · " + fate["npc_title"]
			name_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
			name_label.add_theme_font_size_override("font_size", 20)
			card.add_child(name_label)

			var fate_label = Label.new()
			fate_label.text = fate["fate_text"]
			fate_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
			fate_label.add_theme_font_size_override("font_size", 15)
			card.add_child(fate_label)

			_fate_list.add_child(card)
	else:
		_fate_title.visible = false

	ThemeColors.style_button(_continue_btn, 20)

func _add_stat_row(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	label.add_theme_font_size_override("font_size", 16)
	_stats_list.add_child(label)

func _on_continue() -> void:
	var gm = get_node("/root/GameManager")
	gm.day_cycle.next_phase()
```

- [ ] **Step 5: Verify all syntax in Godot editor**

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/day_map_view.gd scripts/ui/title_screen.gd scripts/ui/ending_screen.gd scripts/ui/ledger_screen.gd
git commit -m "feat: add remaining UI view GDScripts"
```

---

### Task 15: Convert GameManager.cs → game_manager.gd (CRITICAL)

**Files:**
- Create: `scripts/game_manager.gd`

This is the central autoload that ties all systems together. The full 490-line conversion is done by reading `scripts/GameManager.cs` and applying all conversion rules. Key structural differences in GDScript:

- Extends `Node`, declared as `class_name GameManager` with `extends Node`
- Subsystems are created as GDScript objects: `var economy = EconomySystem.new()`
- Signals replace C# events: `signal inventory_changed()`
- `_Ready()` → `_ready()`, `_Process(double dt)` → `_process(delta: float)`
- `GetNode<GameManager>("/root/GameManager")` → `get_node("/root/GameManager")` (but inside GameManager itself, use `self`)
- `DialogueManager.DialogueStarted += ...` → `DialogueManager.dialogue_started.connect(...)`
- `CallDeferred(nameof(Method), args)` → `call_deferred("method_name", args)`
- `GodotObject.IsInstanceValid(obj)` → `is_instance_valid(obj)`
- `GetTree().CallDeferred("change_scene_to_file", path)` → `get_tree().call_deferred("change_scene_to_file", path)`
- `Input.IsActionJustPressed("name")` → `Input.is_action_just_pressed("name")`
- `using var file = FileAccess.Open(...)` → `var file = FileAccess.open(...); ... file.close()`
- `Godot.Collections.Array<Variant>` → `Array`
- `GD.Load<Resource>(path)` → `load(path)`
- `new Color(r, g, b)` → `Color(r, g, b)`
- `Colors.Gray` → `Color.GRAY`
- `Colors.LimeGreen` → `Color.LIME_GREEN`
- `Colors.Red` → `Color.RED`
- `Colors.Orange` → `Color.ORANGE`
- `Colors.White` → `Color.WHITE`
- `.GetNode<T>(path)` → `$Path` (use `%` for unique names, or `get_node(path)`)
- `System.Array.Empty<T>()` → `[]`
- `System.Array.Find(arr, predicate)` → manual `for` loop
- `string.IsNullOrEmpty(s)` → `s == null or s == ""`
- `balloon.Set("will_block_other_input", false)` → `balloon.will_block_other_input = false`
- `kvp.Key` / `kvp.Value` → `key` / `dict[key]` in `for key in dict:` loops

- [ ] **Step 1: Write game_manager.gd** by converting GameManager.cs

The subagent executing this task will read `scripts/GameManager.cs` and produce the complete `scripts/game_manager.gd` using the conversion rules above.

- [ ] **Step 2: Write main_init.gd**

```gdscript
class_name MainInit
extends Node2D

func _ready() -> void:
	pass  # GameManager autoload handles all init
```

- [ ] **Step 3: Commit**

```bash
git add scripts/game_manager.gd scripts/main/main_init.gd
git commit -m "feat: add GameManager and MainInit GDScript"
```

---

### Task 16: Finalize project — project.godot, .tscn, cleanup, Web export

**Files:**
- Modify: `project.godot`
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scenes/ui/DayMap.tscn`
- Modify: `scenes/ui/LedgerScreen.tscn`
- Modify: `scenes/ui/TitleScreen.tscn`
- Modify: `scenes/ui/EndingScreen.tscn`
- Delete: All 22 `.cs` files, `.sln`, `.csproj`

- [ ] **Step 1: Update project.godot**

Change:
```
config/features=PackedStringArray("4.6", "C#", "GL Compatibility")
```
to:
```
config/features=PackedStringArray("4.6", "GL Compatibility")
```

Change:
```
GameManager="*res://scripts/GameManager.cs"
```
to:
```
GameManager="*res://scripts/game_manager.gd"
```

Remove the `[dotnet]` section:
```
[dotnet]

project/assembly_name="TavernManager"
```

- [ ] **Step 2: Update .tscn files**

For each of the 5 `.tscn` files, change the script reference from `.cs` to `.gd`:
- `res://scripts/ui/TavernView.cs` → `res://scripts/ui/tavern_view.gd`
- `res://scripts/ui/DayMapView.cs` → `res://scripts/ui/day_map_view.gd`
- `res://scripts/ui/LedgerScreen.cs` → `res://scripts/ui/ledger_screen.gd`
- `res://scripts/ui/TitleScreen.cs` → `res://scripts/ui/title_screen.gd`
- `res://scripts/ui/EndingScreen.cs` → `res://scripts/ui/ending_screen.gd`

This is done by opening each scene in the Godot editor and reattaching the .gd script, or by directly editing the .tscn files.

- [ ] **Step 3: Delete .NET artifacts**

```bash
rm scripts/GameManager.cs
rm scripts/systems/CraftSystem.cs
rm scripts/systems/EconomySystem.cs
rm scripts/systems/DayCycleSystem.cs
rm scripts/systems/GuestSystem.cs
rm scripts/systems/NarrativeManager.cs
rm scripts/systems/SeasoningSystem.cs
rm scripts/systems/ShopSystem.cs
rm scripts/ui/CraftStation.cs
rm scripts/ui/DayMapView.cs
rm scripts/ui/EndingScreen.cs
rm scripts/ui/LedgerScreen.cs
rm scripts/ui/MixingArea.cs
rm scripts/ui/ProductPanel.cs
rm scripts/ui/SeasoningPanel.cs
rm scripts/ui/SeasoningZone.cs
rm scripts/ui/TavernView.cs
rm scripts/ui/TextureManager.cs
rm scripts/ui/ThemeColors.cs
rm scripts/ui/TitleAmbience.cs
rm scripts/ui/TitleScreen.cs
rm scripts/main/MainInit.cs
rm TavernManager.sln
rm TavernManager.csproj
```

- [ ] **Step 4: Open project in standard Godot 4.6 (non-.NET)**

Verify the project opens without errors. Check all .gd files parse correctly.

- [ ] **Step 5: Test full game flow**

Run the game and verify:
1. Title screen → click start → DayMap loads
2. Assign stamina → click go → Tavern loads
3. Guest arrives → drag materials → craft → serve
4. End night → Ledger shows → continue → DayMap
5. Day 30 → Ending screen

- [ ] **Step 6: Test Web export**

Godot menu: Project → Export → Add → Web
Configure export path, then Export Project.
Open the exported .html in a browser and verify it runs.

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "feat: complete C# to GDScript migration — Web export enabled"
```
