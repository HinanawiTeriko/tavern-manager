# Pixel UI Tokens

Use these as practical targets when adding or reviewing UI. Existing scene constants and textures override this document if already more specific.

## Canvas

- Runtime viewport: `1280x720`
- Native pixel sources for full-screen art usually start from `320x180`
- Runtime scaling should be integer nearest-neighbor where possible

## Colors

Use existing `ThemeColors` and texture palettes first.

| Token | Use |
|---|---|
| Dark teal/black | background, deep shadow |
| Amber/gold | primary highlight, reward, selected state |
| Warm paper | readable panels |
| Muted red | warnings, failure, danger |
| Desaturated green | herbs, recovery, positive low-priority signals |

## Type

- Primary font: `assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf`
- Keep text rendered by `Label`, `RichTextLabel`, `Button`, or other Godot controls.
- Do not use viewport-width based font scaling.
- Avoid negative letter spacing.

## Layout

- Fixed-format controls need stable `size`, `custom_minimum_size`, or explicit container constraints.
- Text must fit within controls at 1280x720.
- Feedback toasts should not block input; use `mouse_filter = IGNORE`.
