# Shop Scene V2 UI Art Design

## Goal

Build a new title-screen-style art pipeline for the DayMap shop UI while preserving existing shop behavior and runtime contracts. The new shop surface is a full visual redesign, not an in-place repaint of the current `shop_brush` assets.

The final result should feel like the title screen's dark teal dungeon tavern language: broad chunky pixel shapes, sparse amber light, rough hand-authored UI carriers, and dynamic Godot text placed on clean readable surfaces.

## Scope

In scope:

- Add a new independent `shop_scene_v2` asset pipeline.
- Keep all generated or approved references under `assets/source/daymap/shop_scene_v2/reference/`.
- Produce native pixel sources under `assets/source/daymap/shop_scene_v2/`.
- Produce runtime textures under `assets/textures/daymap/shop_scene_v2/`.
- Update `ShopOverlay` to use the new textures after pipeline and scene tests exist.
- Preserve current shop data, purchase logic, discount logic, tutorial entry, and DayMap open/close behavior.
- Keep the current `shop_brush` assets and code path available as legacy fallback until `shop_scene_v2` is verified.

Out of scope:

- Rewriting `GameManager`, `ShopSystem`, inventory, economy, save/load, tutorial, or DayMap navigation logic.
- Deleting old `shop_brush` or `shop_redesign` assets.
- Baking readable text, prices, counts, item names, or status strings into generated art.
- Reintroducing an abacus, bead counter, roller, or counting rod quantity control.

## Current Context

The active shop UI is `scenes/ui/ShopOverlay.tscn` with behavior in `scripts/ui/shop_overlay.gd`. The scene is an empty Control shell; `shop_overlay.gd` builds the runtime tree in code.

Current runtime art uses:

- `assets/source/daymap/shop_brush/`
- `assets/textures/daymap/shop_brush/`
- `scripts/tools/export_daymap_shop_brush_assets.py`
- `scripts/test/test_daymap_shop_brush_asset_pipeline.py`
- `scripts/test/test_shop_overlay.gd`

The existing `ShopOverlay` already exposes key nodes used by tests and integration:

- `ShopBackdrop`
- `CategoryTabs/MaterialsZone`
- `CategoryTabs/RecipesZone`
- `CategoryTabs/AbilitiesZone`
- `ItemList`
- `DetailPanel/Title`
- `CheckoutBar/GoldLabel`
- `CheckoutBar/TotalLabel`
- `CheckoutBar/QuantityControl/MinusZone`
- `CheckoutBar/QuantityControl/PlusZone`
- `CheckoutBar/PurchaseButton/PurchaseZone`
- `CheckoutBar/CloseButton/CloseZone`

These names should remain available or be adapted through wrapper nodes. Do not casually rename them.

## Visual Direction

The shop should be a full-screen in-world shop UI, but with the merchant as a weak background presence rather than the focus.

Approved direction:

- A front-facing merchant counter, wood board, ledger board, or mounted trade board.
- Left side: clean item row carrier area for up to five visible rows.
- Right side: clean detail carrier area.
- Top edge: category tabs or cloth bookmarks for materials, recipes, abilities.
- Bottom: checkout carrier with gold, quantity, purchase, and close controls.
- Merchant: only a weak presence in shadow, such as a hooded half figure, hands, or silhouette behind the counter. The merchant must not overlap text safe zones.
- Palette: dark teal stone and wood masses, sparse amber candlelight and coin accents.
- Text: no generated readable text, no numbers, no logos, no watermark. Godot renders all text.

## Asset Pipeline

Add:

```text
assets/source/daymap/shop_scene_v2/reference/
assets/source/daymap/shop_scene_v2/
assets/textures/daymap/shop_scene_v2/
scripts/tools/prepare_daymap_shop_scene_v2_sources.py
scripts/tools/export_daymap_shop_scene_v2_assets.py
scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py
```

The pipeline follows the title screen pattern:

1. Retain the approved high-resolution or generated reference in `reference/`.
2. `prepare_daymap_shop_scene_v2_sources.py` normalizes the approved reference to a `320x180` native grid and extracts native layers.
3. `export_daymap_shop_scene_v2_assets.py` validates native files and exports runtime PNGs only by exact `4x` nearest-neighbor scaling.
4. Python tests prove source presence, dimensions, alpha contracts, text-safe zones, and exact runtime exports.
5. Godot only references runtime textures under `assets/textures/daymap/shop_scene_v2/`.

Expected native layers:

- `shop_scene_bg_native.png`: full `320x180` scene background with counter and weak merchant presence.
- `shop_scene_list_panel_native.png`: transparent or opaque item-list carrier.
- `shop_scene_detail_panel_native.png`: detail carrier.
- `shop_scene_checkout_native.png`: bottom checkout carrier.
- `shop_scene_tab_materials_normal_native.png`
- `shop_scene_tab_materials_selected_native.png`
- `shop_scene_tab_recipes_normal_native.png`
- `shop_scene_tab_recipes_selected_native.png`
- `shop_scene_tab_abilities_normal_native.png`
- `shop_scene_tab_abilities_selected_native.png`
- `shop_scene_row_normal_native.png`
- `shop_scene_row_hover_native.png`
- `shop_scene_row_selected_native.png`
- `shop_scene_row_disabled_native.png`
- `shop_scene_button_normal_native.png`
- `shop_scene_button_hover_native.png`
- `shop_scene_button_pressed_native.png`
- `shop_scene_button_disabled_native.png`
- `shop_scene_quantity_minus_native.png`
- `shop_scene_quantity_body_native.png`
- `shop_scene_quantity_plus_native.png`
- `shop_scene_close_normal_native.png`
- `shop_scene_close_hover_native.png`
- `shop_scene_close_pressed_native.png`
- `shop_scene_status_owned_native.png`
- `shop_scene_status_discount_native.png`

The exact component sizes may be adjusted during implementation, but must be written into the pipeline test before assets are accepted.

## ShopOverlay Integration

Keep `ShopOverlay` as the behavior owner. Do not move purchase logic into scene resources.

Integration plan:

- Add `SHOP_SCENE_V2_*` constants in `scripts/ui/shop_overlay.gd`.
- Keep existing `SHOP_BRUSH_*` constants available as legacy fallback until the v2 screen is accepted.
- Build the new visual tree from runtime textures under `/shop_scene_v2/`.
- Preserve existing behavior methods:
  - `open`
  - `close`
  - `select_category`
  - `select_item`
  - `set_quantity`
  - `purchase_selected`
  - `get_selected_key`
  - `get_quantity`
- Preserve current data reads from `data/shop_ui.json`, `GameManager.shop`, `GameManager.craft`, `GameManager.inventory_sys`, and economy gold.

Required exposed nodes:

```text
ShopOverlay
  ShopBackdrop
  MainShopPanel
    ListPanel
    DetailPanelArt
  CategoryTabs
    MaterialsZone
    RecipesZone
    AbilitiesZone
  ItemList
  DetailPanel
    Title
    Description
    Uses
    State
    OwnedMark
    DiscountMark
  CheckoutBar
    GoldLabel
    TotalLabel
    QuantityControl
      MinusZone
      PlusZone
      QuantityLabel
    PurchaseButton
      PurchaseZone
    CloseButton
      CloseZone
```

If tests or tutorial code still require `MainBrushPanel`, add a compatibility wrapper or alias instead of breaking callers.

State handling remains dynamic:

- Item row hover swaps to hover art.
- Selected row swaps to selected art.
- Owned recipes and abilities swap to disabled art and show owned marker.
- Mira discount shows discount marker.
- Purchase button swaps normal, hover, pressed, disabled art.
- Quantity is three pieces: minus, body, plus. It must not read as an abacus.

## Testing

Python asset test:

- `scripts/test/test_daymap_shop_scene_v2_asset_pipeline.py`
- Required checks:
  - retained reference exists and is non-empty;
  - each native source exists and has expected dimensions;
  - each runtime texture exists and has exact `4x` dimensions;
  - runtime bytes equal native resized with `Image.Resampling.NEAREST`;
  - transparent layers have alpha, visible pixels, and clean edges;
  - text-safe zones are sufficiently low-noise and free of character/background intrusion;
  - amber is sparse on non-state assets;
  - no `abacus` or `quantity_abacus` output names exist.

Godot overlay test:

- Extend `scripts/test/test_shop_overlay.gd`.
- Required checks:
  - overlay uses `/shop_scene_v2/` runtime textures;
  - key texture nodes use nearest filtering;
  - required node paths still exist;
  - old `BookLayer`, `Tabs`, `ItemGrid`, and large-ledger structure do not return;
  - default selection, category switching, quantity total, Mira discount, material purchase, owned recipe state, and close signal still work;
  - labels stay inside declared v2 safe areas.

DayMap integration:

- Keep `scripts/test/test_day_map_scrollbars.gd` passing:
  - DayMap instantiates `ShopOverlay`;
  - opening shop hides map world;
  - closing shop restores map flow;
  - tutorial-relevant regions remain discoverable.

Recommended verification commands:

```powershell
python -m unittest scripts.test.test_daymap_shop_scene_v2_asset_pipeline -v
python -m unittest scripts.test.test_daymap_shop_brush_asset_pipeline -v
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' 'res://scenes/test/test_shop_overlay.tscn'
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --path 'D:\game\tavern-manager' 'res://scenes/test/test_day_map_scrollbars.tscn'
```

## Risks

- A full generated composition may produce tilted or noisy text areas. Mitigation: promote only a visually approved reference and test safe zones.
- A weak merchant can still steal attention if the figure is too bright or central. Mitigation: keep merchant behind counter, low contrast, and outside text carriers.
- Existing tests may expect `shop_brush` node names. Mitigation: preserve key node paths or add compatibility wrappers.
- Reference extraction can become fragile if crop boxes are implicit. Mitigation: keep fixed crop rectangles and explicit sizes in scripts/tests.

## Acceptance Criteria

- The shop has an independent `shop_scene_v2` reference/native/runtime pipeline.
- No runtime UI references high-resolution reference art.
- Runtime textures are exact nearest-neighbor exports from native sources.
- Existing shop behavior is unchanged.
- `shop_brush` remains available as legacy fallback until v2 is accepted.
- The final screen reads as one cohesive title-style dark dungeon tavern shop, with readable Godot text and no baked labels.
