# Ryan Neutral Portrait Design

## Scope

Create one baseline portrait for Ryan: `assets/textures/characters/ryan_neutral.png`.

Do not create or replace the other Ryan expression variants in this pass.

## Style Target

Match the project's current shipped art direction rather than the older character-art notes:

- native low-resolution pixel art, not high-detail illustration pixelated afterward
- dark teal and brown shadow language matching the title/background art
- warm amber tavern light on one side of the character
- thick dark brown/near-black readable silhouette
- simple block shapes and restrained detail density
- transparent background for direct use in the Tavern customer area

Ryan should feel like he belongs in the current tavern and title-screen art.

## Character Direction

Ryan is a young male apprentice adventurer, about 18-20. He is earnest and slightly overconfident, but not a polished heroic knight.

Required visual anchors:

- messy short brown hair
- light armor over dark blue cloth
- lean build
- sword present as a readable prop, either shouldered or held casually
- neutral confident expression, not exaggerated grin
- youthful face and posture

Avoid:

- anime rendering
- smooth digital painting
- glossy 3D armor
- high-density facial detail
- pure silver/blue palette that ignores the tavern's warm lighting
- background, text, watermark, or cast shadow

## Asset Handling

Generate a candidate asset first and save it in the project without overwriting the existing placeholder until it is inspected.

After inspection, replace only:

```text
assets/textures/characters/ryan_neutral.png
```

Keep the current expression variants unchanged:

```text
assets/textures/characters/ryan_excited.png
assets/textures/characters/ryan_hesitant.png
assets/textures/characters/ryan_dejected.png
```

## Validation

The finished portrait must be checked for:

- transparent background
- readable silhouette at Tavern display scale
- style fit against current title/background/workspace assets
- no unintended text or watermark
- no changes to gameplay logic

