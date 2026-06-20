# DayMap Today Intel UI Contract

## Scope

This contract covers the first player-experience clarity pass for DayMap and the adjacent Tavern preparation flow:

- DayMap gets a brush-style Today Intel panel for in-day rumor review.
- Tavern menu-preparation food tags become compact colored markers.
- Backpack item extraction in Tavern should feel like shortcut-bar extraction.

Legacy DayMap detail panels, pinned notes, result panels, and Tavern menu-preparation contracts remain available.

## DayMap Today Intel

### Stable Nodes

`DayMapView` must expose these runtime nodes after `_ready()`:

- `UILayer/TodayIntelBtn`
- `UILayer/TodayIntelPanel`
- `UILayer/TodayIntelPanel/Title`
- `UILayer/TodayIntelPanel/CloseBtn`
- `UILayer/TodayIntelPanel/IntelScroll`
- `UILayer/TodayIntelPanel/IntelScroll/IntelList`
- `UILayer/TodayIntelPanel/Footer`

### Layout

- `TodayIntelPanel` uses `ThemeColors.style_brush_panel()`.
- Panel size is fixed at `560x520`.
- Panel is screen-space UI under `UILayer`, not map-world UI.
- `TodayIntelBtn` remains as a hidden, disabled compatibility node only. It is not a player-facing button.
- `TodayIntelBtn` must be `visible == false`, `disabled == true`, `mouse_filter == MOUSE_FILTER_IGNORE`, `text == ""`, and size `0x0`.
- `TodayIntelBtn` must not use generated button textures, badges, sparks, unread overlays, or visible icon/text states.
- `TodayIntelBtn` must not be embedded in the topbar, and pressing the hidden compatibility node must not open `TodayIntelPanel`.
- `show_wind_notice()` must not make `TodayIntelBtn` visible or interactive.
- Panel defaults to hidden.
- The scroll area clips contents and owns all long text.
- The scroll area keeps its vertical scrollbar hidden, but mouse wheel/programmatic vertical scrolling must still work when the list is taller than the viewport.
- While `TodayIntelPanel` is visible, DayMap camera mouse input is suspended so wheel input cannot zoom the map behind the panel.
- Closing `TodayIntelPanel` restores the camera input state it had before the panel was opened.
- No child may resize the panel.
- The close button must not overlap title text.

### Text Safety

- Titles and buttons are single-line controls.
- Rumor summaries may wrap, but only inside fixed-height entries or the scroll area.
- Long tags are shown as compact colored text labels; tag rows may wrap only inside the scroll area.
- Rumor entries must keep title, summary, tags, and context inside a fixed text-safe inset. Long context lines must trim or wrap within that inset, never spill over the brush-panel edge.
- Empty state text is visible when no rumors were heard.
- Text must fit at `1280x720`.

### Data

The panel reads current data from existing public surfaces:

- `GameManager.get_today_rumors()`
- current DayMap stamina display state
- rumor `menuHints.summary`
- rumor `menuHints.recommendedTags`
- enriched rumor `affectedCustomers`

Location identifiers such as `dark_river` are data keys only. Player-facing rumor titles must resolve them to the localized DayMap location name, falling back to a generic localized title rather than showing a raw id.

Today Intel entries should prefer concrete affected customer names over generic guest-group labels. `menuHints.customerGroups` may still influence systems and menu preparation, but this panel must not append a separate `客群` phrase after the customer line.

This pass does not introduce a new persistent action log.

## Colored Food Tags

Menu-preparation food tags and Today Intel rumor tags must use one shared color mapping. They are colored text labels, not boxed swatches:

- `酒水`: amber
- `热食`: muted red-orange
- `顶饿`: warm tan
- `力量`: muted red
- `清香`: desaturated green
- `秘香`: muted purple
- `轻快`: cool green-blue
- `体面`: gold
- `精致`: pale gold
- unknown tags: `ThemeColors.TEXT_SUBTITLE`

List buttons only show compact colored text labels. Full reasons stay in the fixed detail area.

Selected menu products must be visually obvious without changing row height:

- The product name/price label changes to amber highlight when selected.
- The product name/price label returns to normal body text color when deselected.
- Tag labels remain their semantic colors.
- Selection feedback must not add extra text or resize the product row.

Menu-preparation must close the loop from DayMap wind notices to dish choice:

- Selecting or focusing a product updates the fixed `MenuPrepReasonLabel` detail area.
- The detail area must show the selected dish's matching tags when it hits wind/customer recommendation tags.
- If a current wind notice is part of the recommendation, the detail area must name it as `风声命中`.
- The detail area must stay within its fixed `688x34` safe area, using clipping/wrapping rather than resizing the panel.
- Product rows may keep compact recommendation text, but full matching reasons belong in `MenuPrepReasonLabel`.
- Products with no current match keep the existing fallback text and do not create noisy warnings.

## DayMap Wind Notice Art

- `UILayer/WindNotice` uses `res://assets/textures/ui/wind_notice/wind_notice_panel.png` and `res://assets/textures/ui/wind_notice/wind_notice_icon.png`.
- The DayMap panel and note icon must not retain saturated red source artifacts along paper or frame edges.
- Red wax is allowed only in the separate `wind_notice_stamp` asset, which is not part of the DayMap notice panel backing.
- Runtime wind notice textures remain exact 4x nearest-neighbor exports from native pixel sources.

## Backpack Drag Handoff

Tavern backpack extraction should reuse the same feel as shortcut extraction:

- Dragging an inventory item out to the table creates a real `DeskItem`.
- `InventoryOverlay.item_dropped` is a release-time event; the spawned table item must not remain owned by `DragController`.
- The item uses the same tabletop clamp as shortcut-bar extraction before falling freely.
- Inventory item detail tooltips must not overlap the hovered slot, so the first press-and-drag target stays visible.
- Inventory item detail tooltips must ignore mouse input and must not steal drag start events.
- Inventory item detail tooltips must have stable first-frame width and height; first hover/click must not stretch the panel vertically before settling.
- Dropping on a shortcut slot still binds the shortcut and does not consume inventory.
- Dropping back onto the open backpack still recovers backpack-backed items.

DayMap inventory overlay remains non-spawning; accidental DayMap drag-out must not duplicate inventory.

## Today Intel Entry Art

- No player-facing Today Intel entry button art is used in this pass.
- Rejected generated icon-button source should not be referenced by runtime UI scenes.

## DayMap Wind Toast Art

- Wind notices use `UILayer/GatheringToast` and `res://assets/textures/daymap/ui/gathering_toast_panel.png`.
- The toast panel may use muted parchment, dark outline, and sparse amber pin/highlight pixels.
- The toast panel must not retain saturated red/orange source artifacts that read as stray warning pixels.
- Toast text, warning emphasis, and wind-state feedback must be rendered by Godot controls, not baked into panel art.

## Verification

Focused tests must cover:

- DayMap intel button and panel node contract.
- Panel brush style, size, scroll clipping, and empty state.
- Long rumor text stays inside the fixed scroll area.
- Colored tag markers exist and are not plain white.
- Menu product buttons keep stable size with compact colored tags.
- Selecting a recommended menu product updates the fixed detail area with matching tags and a wind-notice reason.
- Backpack release-to-table creates a real free `DeskItem` in Tavern and leaves `DragController` idle.
- DayMap accidental inventory drop does not increase item count.
- Today Intel has no visible entry-button texture contract in this pass.
- DayMap wind notice panel/icon runtime textures are exact nearest-neighbor exports and contain no saturated red/orange artifact pixels.
- DayMap wind notices leave the hidden Today Intel compatibility node hidden and non-interactive.

Relevant scenes:

- `res://scenes/test/test_day_map_scrollbars.tscn`
- `res://scenes/test/test_tavern_patience_ui.tscn`
- `res://scenes/test/test_workspace_scene_recovery.tscn`
