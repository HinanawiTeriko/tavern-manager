# Shop Scene V2 Reference Prompt

Generated with the built-in `image_gen` tool on 2026-06-11.

## Project References

- Highest style benchmark: `assets/source/title/reference/title_pixel_composite_reference.png`
- Existing shop layout and brush reference: `assets/source/daymap/shop_brush/reference/shop_ui_chroma_reference_v3.png`
- Existing approved brush component reference: `assets/source/ui/menu_brush_components_approved.png`

These references informed palette, texture density, and UI carrier expectations. They were not copied into the final runtime assets.

## Accepted Prompt

```text
Use case: stylized-concept.
Asset type: project-bound Godot 1280x720 shop UI reference, later normalized to a 320x180 native pixel grid and nearest-neighbor scaled 4x.
Reference target: match the existing title-screen visual language: dark teal dungeon tavern palette, broad blocky silhouettes, rough ink-like pixel clusters, sparse amber candle and coin accents, low-density chunky pixel composition.
Primary request: Create a full-screen in-world shop UI scene for a dungeon tavern management game. The composition must be readable after downscaling to 320x180.
Fixed native layout to respect after 320x180 normalization: left item board at x14 y28 w190 h99, right detail board at x216 y28 w90 h99, bottom checkout board at x30 y142 w260 h32, three top cloth tabs at x35/y14, x88/y14, x141/y14 each about 48x16.
Visual carriers: five clean blank horizontal item rows inside the left board, one clean blank detail writing surface inside the right board, bottom coin/status plaque, simple minus-count-plus quantity plaque, wax or brass purchase button, small hanging close tag.
Merchant presence: weak background presence only. Show a withdrawn hooded shopkeeper silhouette or partial hands behind the counter, low contrast, mostly in shadow, not centered, not bright, not overlapping text boards.
Scene details: quiet underground tavern market stall, dark stone arch blocks, old wood counter, shelves in shadow, rope, coins, one small lantern, dusty air, warm amber pin lights.
Style: chunky native-pixel concept art with hard nearest-neighbor-feeling edges, simple flat masses, restrained detail, no smooth glossy rendering, no anime, no cute character, no modern dashboard UI.
Text rule: no readable text, no numbers, no letters, no logo, no watermark. Plus and minus marks may appear only as simple block symbols.
Strict avoid: abacus, beads, rollers, counting rods, tilted readable panels, open-book perspective, bright yellow parchment, dense tiny inventory clutter, large portrait, floating cards, modern app panels, watermark, signature.
Correction: the previous candidate failed because the detail surface read as bright parchment and gold or wax emphasis was too dominant, so keep all text-safe surfaces dark teal or near-black teal with only sparse amber accents.
```

## Review Notes

- The first generated candidate was rejected because the detail surface read as bright parchment and the gold/wax emphasis was too dominant for the title-screen palette.
- The second generated candidate improved the palette, but it used a broader rewritten prompt than the implementation plan requested.
- The accepted candidate was generated from the original plan prompt plus the single correction sentence above.
- The accepted candidate keeps the main text-safe surfaces dark teal, uses amber mostly as small edge and candle accents, places the close tag near the checkout area, and keeps the merchant as a low-contrast background presence.
- No readable UI text from the generated image will be used at runtime. Dynamic text remains Godot-rendered.
