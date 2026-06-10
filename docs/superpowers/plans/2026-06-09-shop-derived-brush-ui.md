# Shop Derived Brush UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current large-ledger shop overlay with a shop-specific UI kit derived from the existing main-menu brush language.

**Architecture:** Add a deterministic Pillow exporter that creates new `shop_brush` native/runtime assets from the approved menu brush source without reusing the menu runtime PNGs as-is. Rebuild `ShopOverlay` around the new brush assets while preserving shop behavior. Use asset tests and Godot structure tests to prevent a return to the old ledger/collage direction.

**Tech Stack:** Godot 4.6.3, GDScript, Python 3, Pillow, `unittest`, native 4x nearest-neighbor PNG export.

---

## File Map

- Create `scripts/tools/export_daymap_shop_brush_assets.py`: deterministic exporter for shop-specific brush assets.
- Create `scripts/test/test_daymap_shop_brush_asset_pipeline.py`: Python tests for native/runtime export correctness, derived-not-reused constraints, color balance, and state variance.
- Create `assets/source/daymap/shop_brush/reference/`: retained reference/copy of the approved brush source for audit.
- Create `assets/source/daymap/shop_brush/*.png`: native shop brush assets.
- Create `assets/textures/daymap/shop_brush/*.png`: runtime 4x shop brush assets.
- Modify `scripts/ui/shop_overlay.gd`: replace old `shop_redesign` ledger visual structure with derived `shop_brush` layout.
- Modify `scripts/test/test_shop_overlay.gd`: assert new brush nodes and paths, old `BookLayer` removal, and existing shop behavior.

## Task 1: Establish Baseline

**Files:**
- Read: `scripts/test/test_brush_theme.gd`
- Read: `scripts/test/test_shop_overlay.gd`

- [ ] **Step 1: Run brush theme baseline**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_brush_theme.tscn
```

Expected: output contains `[TEST-BRUSH-THEME] ALL PASS`.

- [ ] **Step 2: Run current shop overlay baseline**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_shop_overlay.tscn
```

Expected: pass or record existing failure before changing tests. If it fails before edits, keep the failure separate from the new work.

## Task 2: Add Failing Asset Pipeline Tests

**Files:**
- Create: `scripts/test/test_daymap_shop_brush_asset_pipeline.py`
- Test: `scripts/test/test_daymap_shop_brush_asset_pipeline.py`

- [ ] **Step 1: Add the Python asset test file**

Create `scripts/test/test_daymap_shop_brush_asset_pipeline.py` with tests for these exact runtime names:

```python
EXPECTED_ASSETS = {
    "shop_brush_backdrop": ((320, 180), (1280, 720)),
    "shop_brush_panel_list": ((154, 126), (616, 504)),
    "shop_brush_panel_detail": ((112, 126), (448, 504)),
    "shop_brush_row_normal": ((132, 19), (528, 76)),
    "shop_brush_row_hover": ((132, 19), (528, 76)),
    "shop_brush_row_selected": ((132, 19), (528, 76)),
    "shop_brush_row_disabled": ((132, 19), (528, 76)),
    "shop_brush_category_normal": ((48, 16), (192, 64)),
    "shop_brush_category_selected": ((48, 16), (192, 64)),
    "shop_brush_button_normal": ((58, 18), (232, 72)),
    "shop_brush_button_hover": ((58, 18), (232, 72)),
    "shop_brush_button_pressed": ((58, 18), (232, 72)),
    "shop_brush_button_disabled": ((58, 18), (232, 72)),
    "shop_brush_quantity": ((70, 18), (280, 72)),
    "shop_brush_status_owned": ((42, 13), (168, 52)),
    "shop_brush_status_discount": ((42, 13), (168, 52)),
    "shop_brush_divider": ((180, 4), (720, 16)),
    "shop_brush_hover_marker": ((42, 6), (168, 24)),
}
```

Required assertions:

- every native/runtime file exists;
- runtime bytes equal native resized with `Image.Resampling.NEAREST`;
- assets are not byte-identical to `assets/textures/ui/menu_brush_panel.png`, `menu_brush_band.png`, or `menu_brush_tab.png`;
- main panels have at least 45% low-noise dark readable center pixels;
- selected/hover/pressed states differ from normal;
- amber pixels remain below 18% for non-selected assets.

- [ ] **Step 2: Run the new test and verify RED**

Run:

```powershell
python -m unittest scripts.test.test_daymap_shop_brush_asset_pipeline -v
```

Expected: FAIL because `assets/source/daymap/shop_brush/*.png` and `scripts/tools/export_daymap_shop_brush_assets.py` do not exist yet.

## Task 3: Implement Exporter And Generate Assets

**Files:**
- Create: `scripts/tools/export_daymap_shop_brush_assets.py`
- Create: `assets/source/daymap/shop_brush/reference/menu_brush_components_approved.png`
- Create: `assets/source/daymap/shop_brush/*.png`
- Create: `assets/textures/daymap/shop_brush/*.png`
- Test: `scripts/test/test_daymap_shop_brush_asset_pipeline.py`

- [ ] **Step 1: Add exporter constants**

Implement constants:

```python
ROOT = Path(__file__).resolve().parents[2]
MENU_SOURCE = ROOT / "assets" / "source" / "ui" / "menu_brush_components_approved.png"
REFERENCE = ROOT / "assets" / "source" / "daymap" / "shop_brush" / "reference"
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_brush"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_brush"
SCALE = 4
```

Use these menu source crop boxes:

```python
MENU_PANEL_BOX = (47, 49, 898, 447)
MENU_BAND_BOX = (942, 71, 1471, 163)
MENU_TAB_BOX = (47, 678, 332, 768)
MENU_DIVIDER_BOX = (52, 835, 995, 855)
```

- [ ] **Step 2: Add image helpers**

Implement helpers:

```python
def load_menu_source() -> Image.Image
def crop_fit(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image
def tint(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image
def add_amber_edge(image: Image.Image, mode: str) -> Image.Image
def mute_alpha_edges(image: Image.Image) -> Image.Image
def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None
```

`save_pair` must save `SOURCE / f"{name}_native.png"` and `RUNTIME / f"{name}.png"` where runtime is exact nearest-neighbor resize.

- [ ] **Step 3: Build derived assets**

Use the source brush sheet to construct these native assets:

```python
build_backdrop(source) -> Image.Image
build_panel(source, native_size, variant) -> Image.Image
build_row(source, state) -> Image.Image
build_category(source, selected) -> Image.Image
build_button(source, state) -> Image.Image
build_quantity(source) -> Image.Image
build_status(source, kind) -> Image.Image
build_divider(source) -> Image.Image
build_hover_marker(source) -> Image.Image
```

The generated shapes must use new dimensions from Task 2. They may crop from the approved brush source, retint, mask, and add small amber accents. They must not copy the existing runtime brush PNG files.

- [ ] **Step 4: Run exporter**

Run:

```powershell
python scripts\tools\export_daymap_shop_brush_assets.py
```

Expected: native files appear under `assets/source/daymap/shop_brush/`; runtime files appear under `assets/textures/daymap/shop_brush/`.

- [ ] **Step 5: Run asset tests and verify GREEN**

Run:

```powershell
python -m unittest scripts.test.test_daymap_shop_brush_asset_pipeline -v
```

Expected: PASS.

## Task 4: Add Failing ShopOverlay Structure Tests

**Files:**
- Modify: `scripts/test/test_shop_overlay.gd`
- Test: `scenes/test/test_shop_overlay.tscn`

- [ ] **Step 1: Update core layout assertions**

Change `_test_core_layout` so it expects:

```gdscript
_ok(overlay.get_node_or_null("ShopBackdrop") is TextureRect, "overlay has derived brush shop backdrop")
_ok(overlay.get_node_or_null("MainBrushPanel") is Control, "overlay has main brush panel root")
_ok(overlay.get_node_or_null("CategoryTabs/MaterialsZone") is Button, "materials brush category zone exists")
_ok(overlay.get_node_or_null("ItemList") is Control, "brush item list exists")
_ok(overlay.get_node_or_null("DetailPanel/Title") is Label, "brush detail title exists")
_ok(overlay.get_node_or_null("CheckoutBar/GoldLabel") is Label, "checkout gold label exists")
_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusZone") is Button, "quantity minus zone exists")
_ok(overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") is Button, "purchase zone exists")
_ok(overlay.get_node_or_null("CheckoutBar/CloseButton/CloseZone") is Button, "close zone exists")
_ok(overlay.get_node_or_null("BookLayer") == null, "old large ledger layer is removed")
```

- [ ] **Step 2: Add texture path assertion helper**

Add:

```gdscript
func _test_shop_brush_texture_paths(overlay) -> void:
    for path in ["ShopBackdrop", "MainBrushPanel/ListPanel", "MainBrushPanel/DetailPanelArt"]:
        var rect := overlay.get_node(path) as TextureRect
        _ok(rect.texture != null, path + " has texture")
        _ok(rect.texture.resource_path.contains("/shop_brush/"), path + " uses shop_brush texture")
        _ok(rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, path + " uses nearest filtering")
```

Call this after `_test_core_layout`.

- [ ] **Step 3: Run the updated Godot test and verify RED**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_shop_overlay.tscn
```

Expected: FAIL because `ShopOverlay` still builds old `SceneBackdrop` / `BookLayer` nodes.

## Task 5: Rebuild ShopOverlay Visual Structure

**Files:**
- Modify: `scripts/ui/shop_overlay.gd`
- Test: `scenes/test/test_shop_overlay.tscn`

- [ ] **Step 1: Replace texture constants**

Remove old `shop_redesign` constants from the visual build path and add:

```gdscript
const SHOP_BRUSH_BACKDROP := "res://assets/textures/daymap/shop_brush/shop_brush_backdrop.png"
const SHOP_BRUSH_PANEL_LIST := "res://assets/textures/daymap/shop_brush/shop_brush_panel_list.png"
const SHOP_BRUSH_PANEL_DETAIL := "res://assets/textures/daymap/shop_brush/shop_brush_panel_detail.png"
const SHOP_BRUSH_ROW_NORMAL := "res://assets/textures/daymap/shop_brush/shop_brush_row_normal.png"
const SHOP_BRUSH_ROW_HOVER := "res://assets/textures/daymap/shop_brush/shop_brush_row_hover.png"
const SHOP_BRUSH_ROW_SELECTED := "res://assets/textures/daymap/shop_brush/shop_brush_row_selected.png"
const SHOP_BRUSH_ROW_DISABLED := "res://assets/textures/daymap/shop_brush/shop_brush_row_disabled.png"
const SHOP_BRUSH_CATEGORY_NORMAL := "res://assets/textures/daymap/shop_brush/shop_brush_category_normal.png"
const SHOP_BRUSH_CATEGORY_SELECTED := "res://assets/textures/daymap/shop_brush/shop_brush_category_selected.png"
const SHOP_BRUSH_BUTTON_NORMAL := "res://assets/textures/daymap/shop_brush/shop_brush_button_normal.png"
const SHOP_BRUSH_BUTTON_HOVER := "res://assets/textures/daymap/shop_brush/shop_brush_button_hover.png"
const SHOP_BRUSH_BUTTON_PRESSED := "res://assets/textures/daymap/shop_brush/shop_brush_button_pressed.png"
const SHOP_BRUSH_BUTTON_DISABLED := "res://assets/textures/daymap/shop_brush/shop_brush_button_disabled.png"
const SHOP_BRUSH_QUANTITY := "res://assets/textures/daymap/shop_brush/shop_brush_quantity.png"
const SHOP_BRUSH_STATUS_OWNED := "res://assets/textures/daymap/shop_brush/shop_brush_status_owned.png"
const SHOP_BRUSH_STATUS_DISCOUNT := "res://assets/textures/daymap/shop_brush/shop_brush_status_discount.png"
const SHOP_BRUSH_DIVIDER := "res://assets/textures/daymap/shop_brush/shop_brush_divider.png"
const SHOP_BRUSH_HOVER_MARKER := "res://assets/textures/daymap/shop_brush/shop_brush_hover_marker.png"
```

- [ ] **Step 2: Replace `_build` visual tree**

Build this node tree:

```text
ShopOverlay
  ShopBackdrop
  MainBrushPanel
    ListPanel
    DetailPanelArt
  CategoryTabs
  ItemList
  DetailPanel
  CheckoutBar
    GoldLabel
    TotalLabel
    QuantityControl
    PurchaseButton
    CloseButton
```

Use these runtime positions:

```gdscript
ShopBackdrop: Vector2(0, 0), size Vector2(1280, 720)
ListPanel: Vector2(92, 116), size Vector2(616, 504)
DetailPanelArt: Vector2(744, 116), size Vector2(448, 504)
CategoryTabs: positions 142/334/526 x, y 72
ItemList: position Vector2(136, 176), size Vector2(528, 404)
DetailPanel: position Vector2(790, 172), size Vector2(352, 360)
CheckoutBar: position Vector2(110, 622), size Vector2(1080, 76)
```

- [ ] **Step 3: Update item rows**

Rows use `SHOP_BRUSH_ROW_SELECTED` when selected, `SHOP_BRUSH_ROW_HOVER` on hover, `SHOP_BRUSH_ROW_DISABLED` for owned recipes/abilities, and `SHOP_BRUSH_ROW_NORMAL` otherwise. Row text remains dynamic:

```gdscript
var name_label := _add_label(row, "Name", Vector2(28, 8), Vector2(300, 30), 14, ThemeColors.TEXT_LIGHT)
var price_label := _add_label(row, "Price", Vector2(342, 8), Vector2(120, 30), 14, ThemeColors.AMBER_PRIMARY)
```

- [ ] **Step 4: Update checkout controls**

Gold and total labels sit directly under `CheckoutBar`. `QuantityControl`, `PurchaseButton`, and `CloseButton` contain TextureRects from the new brush assets plus transparent buttons for input.

- [ ] **Step 5: Run Godot test and verify GREEN**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_shop_overlay.tscn
```

Expected: output contains `[TEST-SHOP-OVERLAY] ALL PASS`.

## Task 6: Final Verification And Visual Check

**Files:**
- Verify: `assets/textures/daymap/shop_brush/*.png`
- Verify: `scripts/ui/shop_overlay.gd`
- Verify: `scripts/test/test_daymap_shop_brush_asset_pipeline.py`
- Verify: `scripts/test/test_shop_overlay.gd`

- [ ] **Step 1: Run focused Python verification**

Run:

```powershell
python -m unittest scripts.test.test_daymap_shop_brush_asset_pipeline -v
```

Expected: PASS.

- [ ] **Step 2: Run focused Godot verification**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_shop_overlay.tscn
```

Expected: PASS.

- [ ] **Step 3: Inspect runtime assets**

Open:

```text
assets/textures/daymap/shop_brush/shop_brush_backdrop.png
assets/textures/daymap/shop_brush/shop_brush_panel_list.png
assets/textures/daymap/shop_brush/shop_brush_row_selected.png
```

Expected visual result: derived brush style, dark teal dominance, sparse amber emphasis, clean text fields, no large parchment book.

- [ ] **Step 4: Report dirty scope**

Run:

```powershell
git status --short
```

Expected: report new/modified files related to `shop_brush`, `ShopOverlay`, and tests separately from pre-existing DayMap/shop redesign dirty files.

