# Title Screen Native Pixel Rebuild Design

> Date: 2026-06-02
>
> Scope: Rebuild only the `TitleScreen` art pipeline and title-screen display settings. Do not restyle other scenes.

## 1. Problem

The current title screen has the right composition but the wrong production pipeline. Its runtime layers exist only as final-size exports:

- `assets/textures/title/title_pixel_bg_clean.png`
- `assets/textures/title/title_pixel_glow_mask.png`
- `assets/textures/title/title_pixel_logo.png`
- `assets/textures/title/title_pixel_menu_bands.png`
- `assets/textures/title/title_pixel_menu_marker.png`

The repository does not preserve native `320x180` or `640x360` title sources and does not have a title-specific deterministic exporter. The current assets therefore mix different apparent pixel scales and contain cleanup artifacts from later slicing.

The approved replacement direction is authentic low-density pixel art authored on one `320x180` grid. Preserve the current composition:

- warm tavern entrance, crooked lantern, oversized barrel, and uneven crates in the lower-left;
- cool underground passage through the center;
- large two-line `LAST CALL / BELOW` logo across the upper-left and center;
- calm right-side wall with four empty menu bands;
- runtime-rendered menu labels.

## 2. Approaches Considered

### A. Keep the current assets and apply another pixel filter

This is the smallest code change but does not solve the root problem. A filter cannot recover a coherent source grid after generated details and cutout edges already use mixed scales.

### B. Rebuild the title art as native `640x360`

This preserves more detail and is easier for text generation, but it risks returning to noisy, fragmented pixel detail. It also weakens the deliberately chunky visual language approved in the preview.

### C. Rebuild the title art as native `320x180` and export deterministically

Selected. This gives every layer one grid, keeps the visual density under control, and supports clean integer scaling across common 16:9 displays.

## 3. Source And Runtime Assets

Preserve editable native assets under:

```text
assets/source/title/
```

Create these native layers:

| Native source | Purpose |
| --- | --- |
| `title_pixel_bg_clean_native.png` | Text-free, UI-free environment plate |
| `title_pixel_glow_mask_native.png` | Transparent warm doorway and lantern light overlay |
| `title_pixel_logo_native.png` | Transparent `LAST CALL / BELOW` logo |
| `title_pixel_menu_bands_native.png` | Transparent four-band right-side menu decoration |
| `title_pixel_menu_marker_native.png` | Transparent amber hover underline |

Use the same `320x180` coordinate space for the background, glow, logo, and menu-band sources. This avoids manual crop offsets and prevents later alignment drift. The hover marker may use a tightly cropped native canvas because it is positioned relative to the hovered button.

Generate or edit the native artwork against the approved preview direction. Use local cleanup only for deterministic tasks such as alpha cleanup, palette inspection, and nearest-neighbor export. Do not use a generic pixelation filter as the source of the art style.

Export runtime textures under:

```text
assets/textures/title/
```

The exporter scales native sources by exactly `4x` with nearest-neighbor resampling. The background, glow, logo, and bands become aligned `1280x720` runtime layers. The marker becomes a `4x` cropped runtime texture.

## 4. Exporter

Add:

```text
scripts/tools/export_title_screen_assets.py
```

The script must:

1. Load every required native source.
2. Validate the expected native canvas sizes.
3. Validate alpha-channel requirements for transparent layers.
4. Export each runtime PNG using Pillow `Image.Resampling.NEAREST`.
5. Print source and runtime dimensions.
6. Fail clearly if a required source is missing or malformed.

The exporter is the only supported path for producing runtime title textures from native sources.

## 5. Scene Integration

Keep `scenes/ui/TitleScreen.tscn` and `scripts/ui/title_screen.gd` behavior focused on composition and interaction:

- Preserve separate background, glow, logo, menu-band, and marker layers.
- Keep menu labels rendered by Godot so localization and settings behavior remain runtime-controlled.
- Preserve the current subtle glow breathing and logo motion.
- Preserve the existing settings panel entry and menu hover behavior.
- Adjust layer node layout only where required by the new full-canvas aligned exports.

Do not modify Tavern, DayMap, LedgerScreen, EndingScreen, gameplay state, or dialogue behavior in this pass.

## 6. Resolution Strategy

Keep the project logical viewport at:

```text
1280x720
```

The title art remains native `320x180` internally and exports to `1280x720` for runtime composition. Add nearest-neighbor texture filtering for pixel-art presentation and keep aspect-ratio preservation enabled.

Support these 16:9 window sizes in settings:

| Display size | Scale relative to `320x180` |
| --- | ---: |
| `1280x720` | `4x` |
| `1600x900` | `5x` |
| `1920x1080` | `6x` |
| `2560x1440` | `8x` |
| `3840x2160` | `12x` |

These common sizes preserve integer scaling relative to the native title grid. Fullscreen continues to use the active display size. Unsupported aspect ratios must preserve the 16:9 composition with letterboxing rather than stretching or cropping.

The runtime UI coordinate system stays `1280x720`; this pass does not introduce separate layouts per display size.

## 7. Validation

Add or extend automated checks for:

- every native title source exists;
- native full-canvas layers are exactly `320x180`;
- transparent layers contain alpha;
- runtime full-canvas layers are exactly `1280x720`;
- runtime outputs are exact `4x` nearest-neighbor exports of their native sources;
- the settings list includes `2560x1440` and `3840x2160`;
- the TitleScreen scene still loads all required visual layers;
- menu buttons remain in the right-side readability area;
- logo and runtime menu areas do not overlap;
- no conflict markers are present.

Manual verification in the Godot 4.6.x standard editor:

1. Open `TitleScreen`.
2. Check the logo, tavern entrance, passage, four menu bands, hover marker, and glow animation.
3. Check windowed `1280x720`, `1600x900`, `1920x1080`, `2560x1440`, and `3840x2160` where the monitor supports them.
4. Check fullscreen on at least one `1920x1080`, `2560x1440`, or `3840x2160` display.
5. Confirm the title art is crisp, the aspect ratio is preserved, and no layer has slicing or alpha-edge artifacts.

## 8. Non-Goals

- Do not rebuild runtime art outside `TitleScreen`.
- Do not change gameplay or save behavior.
- Do not redesign the title composition.
- Do not create multiple authored title-art sets for different resolutions.
- Do not introduce high-density pixel detail to make large monitors look sharper.
- Do not stage unrelated existing workspace changes in the title-screen commits.
