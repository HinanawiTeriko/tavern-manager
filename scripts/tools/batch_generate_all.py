# -*- coding: utf-8 -*-
"""
批量生成项目所需所有美术资源 (P0+P1+P2)
调用本地 Stable Diffusion WebUI (SDXL Base + pixel-art-xl LoRA)
基于 docs/07_美术需求文档.md 和 docs/08_AI生图提示词.md
"""
import json, os, requests, time, base64
from pathlib import Path

# ========== 配置 ==========
API_BASE = "http://127.0.0.1:7860"
ASSETS_DIR = Path(r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures")
MODEL_NAME = "sd_xl_base_1.0.safetensors"  # base checkpoint
LORA_TAG = "<lora:pixel-art-xl:1.0>"        # pixel art LoRA

# SDXL 通用负面提示词
NEGATIVE_PROMPT = """3D render, realistic photo, photorealism, smooth gradients, anti-aliasing, blur,
anime style, manga style, cartoon, modern architecture, neon lights,
bright daylight, white background, text, watermark, signature,
low quality, jpeg artifacts, distorted, deformed, blurry, out of focus,
photographic, hyperrealistic, 8k, high detail, soft lighting"""

# SDXL 风格后缀
STYLE_SUFFIX = "pixel art, 16-bit pixel game art, dark fantasy pixel tavern, limited color palette, flat colors, crisp pixel edges, sharp outlines, no anti-aliasing, no gradient, retro game pixel art"

# ========== 生成参数（SDXL优化） ==========
DEFAULT_STEPS = 25
DEFAULT_CFG = 7.0
HIRES_UPSCALER = "Latent"
HIRES_STEPS = 15
HIRES_DENOISING = 0.5

# 小图标用 hi-res fix 先生成大图再缩小
SMALL_ICON_SIZE = 512  # 小图标先生成 512x512 再 downscale


def get_params(width, height, steps=25):
    """根据尺寸决定是否启用 hi-res fix"""
    payload = {
        "steps": steps,
        "cfg_scale": 7.0,
        "sampler_name": "DPM++ 2M Karras",
        "batch_size": 1,
        "n_iter": 1,
        "seed": -1,
        "restore_faces": False,
        "tiling": False,
        "width": width,
        "height": height,
        "enable_hr": False,
    }
    return payload


# ========== 所有生成任务 ==========
TASKS = []

# ==================== P0 角色 (400x500) ====================
P0_CHARACTERS = [
    {
        "id": "C2", "name": "ryan_determined",
        "output": "characters/ryan_determined.png", "width": 768, "height": 960,
        "prompt": f"""{LORA_TAG} Pixel art character sprite. Full body standing portrait, front-facing.
Young male knight age 18-20, lean build. Short messy brown hair.
Bright blue-grey eyes, intense determined gaze.
Expression: confident smile, eyebrows furrowed with determination.
Right hand gripping sword hilt. Silver light armor with metal pauldrons.
Dark blue cloth underneath. Long sword on shoulder.
Light skin. Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait style. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "C3", "name": "ryan_worried",
        "output": "characters/ryan_worried.png", "width": 768, "height": 960,
        "prompt": f"""{LORA_TAG} Pixel art character sprite. Full body standing portrait.
Young male knight. Short messy brown hair. Silver light armor, dark blue cloth, sword on shoulder.
Expression: eyebrows tightly knit with worry, lips pressed thin.
Eyes looking downward, avoiding contact. Shoulders hunched inward. Dimmer eyes.
Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "C4", "name": "ryan_broken",
        "output": "characters/ryan_broken.png", "width": 768, "height": 960,
        "prompt": f"""{LORA_TAG} Pixel art character sprite. Full body standing portrait.
Young male knight. Messy brown hair. Silver light armor, dark blue cloth, sword.
Expression: eyes hollow and unfocused, half-lowered eyelids, vacant stare.
Mouth drooping. Head slightly lowered. Shadow under one eye.
Darker and gloomier. Top-down dim lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "C5", "name": "mira_neutral",
        "output": "characters/mira_neutral.png", "width": 768, "height": 960,
        "prompt": f"""{LORA_TAG} Pixel art character sprite. Full body standing portrait, front-facing.
Female traveling merchant age 25-28, capable lean build.
Dark brown hair tied in high ponytail, loose strands near ears.
Sharp amber eyes, narrow and keen, looking directly at viewer.
Professional slight smile, polite but reserved, one hand on hip.
Dark brown leather vest over cream linen shirt.
Multi-pocket utility belt diagonally, pouches and scrolls.
Large leather travel bag over right shoulder. Light wheat-tone skin.
Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "C6", "name": "mira_smile",
        "output": "characters/mira_smile.png", "width": 768, "height": 960,
        "prompt": f"""{LORA_TAG} Pixel art character sprite. Full body standing portrait.
Female merchant, dark brown high ponytail, amber eyes, leather vest, cream shirt, utility belt, travel bag.
Expression: genuine warm smile, eye corners crinkled, mouth naturally upturned.
Warmer feeling. Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "C7", "name": "mira_surprised",
        "output": "characters/mira_surprised.png", "width": 768, "height": 960,
        "prompt": f"""{LORA_TAG} Pixel art character sprite. Full body standing portrait.
Female merchant, dark brown ponytail, amber eyes, leather vest, utility belt, travel bag.
Expression: eyebrows raised, eyes widened, mouth slightly open in surprise.
Head tilted back slightly. Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "C8", "name": "mira_serious",
        "output": "characters/mira_serious.png", "width": 768, "height": 960,
        "prompt": f"""{LORA_TAG} Pixel art character sprite. Full body standing portrait.
Female merchant, dark brown ponytail, amber eyes, leather vest, utility belt, travel bag.
Expression: no smile, eyebrows furrowed, direct intense stare.
Mouth closed in firm line. Serious business demeanor.
Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait. Pixel art, flat colors, crisp edges."""
    },
]
TASKS.extend(P0_CHARACTERS)

# ==================== P0 材料图标 (先生成512x512) ====================
P0_MATERIALS = [
    {
        "id": "I1", "name": "materials_ale",
        "output": "icons/materials/ale.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. A bundle of golden wheat stalks, 3-4 stalks tied with twine.
Ripe grain heads drooping downward. Warm amber-gold color.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I2", "name": "materials_wine",
        "output": "icons/materials/wine.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Small cluster of deep purple grapes, 3-5 berries, vine tendril and green leaf.
Deep purple-red grapes, muted green leaf.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I3", "name": "materials_bread",
        "output": "icons/materials/bread.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Small burlap sack tied at top with rope, white powder particles leaking.
Warm brown sack, white powder. Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I4", "name": "materials_meat",
        "output": "icons/materials/meat.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. T-bone cut of raw meat, pinkish-red meat with white bone center.
Meat has visible marbling. Classic T-bone shape.
Top lighting, slight gloss. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I5", "name": "materials_herb",
        "output": "icons/materials/herb.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Bundle of fresh green leaves, 3-4 leaves tied, visible veins.
Fresh vibrant green. Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
]
TASKS.extend(P0_MATERIALS)

# ==================== P0 成品图标 (512x512) ====================
P0_PRODUCTS = [
    {
        "id": "I6", "name": "products_ale",
        "output": "icons/products/ale.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Thick wooden beer mug overflowing with frothy foam.
Amber liquid visible through foam. Dark brown wooden mug.
Top lighting, highlight on foam. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I7", "name": "products_wine",
        "output": "icons/products/wine.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Elegant stemmed wine glass half-filled with deep red wine.
Visible wine legs on glass. White reflection highlights.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I8", "name": "products_bread",
        "output": "icons/products/bread.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Round rustic European country loaf, golden-brown crust.
Cross-shaped scoring on top, lighter inner crumb visible.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I9", "name": "products_meat",
        "output": "icons/products/meat.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Meat chunks on iron skewer, oily golden-brown with charred edges.
Steam wisp rising. Iron skewer grey.
Top lighting, oil gloss. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I10", "name": "products_herb_tea",
        "output": "icons/products/herb_tea.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Rustic clay cup filled with green-tinted tea.
Mint leaf on rim as garnish. Steam wisp rising. Warm earthy brown cup.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I11", "name": "products_herbal_ale",
        "output": "icons/products/herbal_ale.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Wooden beer mug with herb leaf at rim.
Amber-green liquid. Dark brown mug.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I12", "name": "products_meat_stew",
        "output": "icons/products/meat_stew.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Small clay pot with rich brown meat stew.
Meat chunks and carrot pieces visible. Steam wisps rising. Warm brown clay pot.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I13", "name": "products_meat_sand",
        "output": "icons/products/meat_sand.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Bread roll sliced horizontally, thick roasted meat slices inside.
Lettuce leaf peeking out. Golden brown bread, red-brown meat, green lettuce.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
    {
        "id": "I14", "name": "products_spiced_wine",
        "output": "icons/products/spiced_wine.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Wine glass with deep red wine, cinnamon stick and star anise inside.
White reflection highlights on glass.
Top lighting. 1px dark outline. Transparent background.
RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
]
TASKS.extend(P0_PRODUCTS)

# ==================== P0 UI组件 ====================
P0_UI = [
    {
        "id": "UI_WIDE_N", "name": "btn_wide_normal",
        "output": "ui/btn_wide_normal.png", "width": 512, "height": 128,
        "prompt": f"""{LORA_TAG} Pixel art UI button. Rectangle with rounded corners. Amber base (#ffbd7f).
Bottom edge solid dark shadow creating raised 3D effect.
Wood grain texture on surface. Clean pixel edges. Transparent background.
Pixel art game UI element, flat colors."""
    },
    {
        "id": "UI_WIDE_H", "name": "btn_wide_hover",
        "output": "ui/btn_wide_hover.png", "width": 512, "height": 128,
        "prompt": f"""{LORA_TAG} Pixel art UI button. Rectangle with rounded corners. Bright amber base (#ff9500).
Bottom edge solid dark shadow creating raised 3D effect. ~15% brighter than normal.
Wood grain texture. Clean pixel edges. Transparent background.
Pixel art game UI element, flat colors."""
    },
    {
        "id": "UI_WIDE_P", "name": "btn_wide_pressed",
        "output": "ui/btn_wide_pressed.png", "width": 512, "height": 128,
        "prompt": f"""{LORA_TAG} Pixel art UI button. Rectangle with rounded corners. Dark amber base (#cc7300).
Shadow on TOP edge creating pressed-in effect. Wood grain texture.
Clean pixel edges. Transparent background. Pixel art game UI element, flat colors."""
    },
    {
        "id": "UI_SMALL_N", "name": "btn_small_normal",
        "output": "ui/btn_small_normal.png", "width": 360, "height": 160,
        "prompt": f"""{LORA_TAG} Pixel art small UI button. Amber base (#ffbd7f). Dark bottom shadow creating raised effect.
Wood grain noise. Clean pixel edges. Transparent background.
Pixel art game UI element, flat colors, simple."""
    },
    {
        "id": "UI_SMALL_H", "name": "btn_small_hover",
        "output": "ui/btn_small_hover.png", "width": 360, "height": 160,
        "prompt": f"""{LORA_TAG} Pixel art small UI button. Bright amber (#ff9500). Same shadow.
Clean pixel edges. Transparent background. Pixel art game UI element, flat colors."""
    },
    {
        "id": "UI_SMALL_P", "name": "btn_small_pressed",
        "output": "ui/btn_small_pressed.png", "width": 360, "height": 160,
        "prompt": f"""{LORA_TAG} Pixel art small UI button. Dark amber (#cc7300), shadow on top.
Clean pixel edges. Transparent background. Pixel art game UI element, flat colors."""
    },
    {
        "id": "UI_SLOT_MAT", "name": "slot_material",
        "output": "ui/slot_material.png", "width": 480, "height": 480,
        "prompt": f"""{LORA_TAG} Pixel art UI slot, square. Recessed slot — dark inner area inside wooden frame border.
Metallic rivets at four corners. Inner area empty dark.
Wood texture on frame. Transparent background outside frame.
Pixel art game UI element, flat colors, crisp edges."""
    },
    {
        "id": "UI_SLOT_RESULT", "name": "slot_result",
        "output": "ui/slot_result.png", "width": 580, "height": 130,
        "prompt": f"""{LORA_TAG} Pixel art UI slot, wide rectangular. Same style as square slot but wider.
Wooden frame border with corner rivets. Dark inner area. Empty.
Transparent background. Pixel art game UI element, flat colors, crisp edges."""
    },
    {
        "id": "UI_SLOT_SHORT", "name": "slot_shortcut",
        "output": "ui/slot_shortcut.png", "width": 360, "height": 144,
        "prompt": f"""{LORA_TAG} Pixel art UI slot, small rectangle. Wooden frame border, dark inner area, small rivets.
Transparent background. Pixel art game UI element, flat colors, crisp edges."""
    },
    {
        "id": "UI_BAR_SHORT", "name": "bar_shortcut_bg",
        "output": "ui/bar_shortcut_bg.png", "width": 1000, "height": 40,
        "prompt": f"""{LORA_TAG} Pixel art UI bar background, horizontal. Dark wooden plank strip, vertical wood grain lines.
Clean pixel edges. Pixel art game UI element, flat colors."""
    },
    {
        "id": "UI_BAR_TOP", "name": "bar_top_panel",
        "output": "ui/bar_top_panel.png", "width": 1280, "height": 40,
        "prompt": f"""{LORA_TAG} Pixel art UI bar background, horizontal. Dark semi-transparent strip.
Subtle inner shadow on bottom edge. Clean pixel edges.
Pixel art game UI element, flat colors."""
    },
    {
        "id": "UI_PATIENCE", "name": "bar_patience_fill",
        "output": "ui/bar_patience_fill.png", "width": 64, "height": 80,
        "prompt": f"""{LORA_TAG} Pixel art UI fill bar, vertical. Gradient fill: green at top → amber middle → red at bottom.
Used for ProgressBar. Dark border. Clean pixel edges. Transparent background.
Pixel art game UI element, flat colors."""
    },
]
TASKS.extend(P0_UI)

# ==================== P1 背景 ====================
P1_BG = [
    {
        "id": "D1", "name": "daymap_bg",
        "output": "backgrounds/daymap_bg.png", "width": 1280, "height": 720,
        "prompt": f"""{LORA_TAG} Pixel art dungeon map on parchment paper, 1280x720.
Flat parchment base, pixelated jagged torn edges.
Five locations connected by dotted pixel paths:
- mushroom grotto top left with simple mushroom shapes
- abandoned mine tunnel top center with minecart
- underground river right with wavy lines
- grape vine terrace bottom left with vine patterns
- underground farm mill bottom right with windmill
Dark ink lines on parchment, pixel compass rose in corner.
Limited color palette, flat colors, 1px black outlines.
No UI, no gradient, no soft blur. Simple pixel shapes."""
    },
    {
        "id": "E1", "name": "ending_bg",
        "output": "backgrounds/ending_bg.png", "width": 1280, "height": 720,
        "prompt": f"""{LORA_TAG} Pixel art tavern interior after hours, 1280x720.
Stone and wood tavern with deeper dark colors.
Heavy closed ledger book on bartop center-bottom, flat amber pattern on cover.
Wall sconces as dark flat extinguished blocks.
Light from above as subtle brighter pixel tones.
Quiet contemplative end-of-journey mood.
Limited color palette, flat colors, 1px black outlines.
No gradient, no soft glow, no characters. Simple pixel shapes."""
    },
]
TASKS.extend(P1_BG)

# ==================== P1 普通客人头像 ====================
P1_GUESTS = [
    {
        "id": "C11a", "name": "guest_warrior",
        "output": "characters/guest_warrior.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art bust portrait. Male warrior head. Iron helmet visor, thick beard, rugged face.
Limited color palette, flat colors, 1px black outlines.
Transparent background, neutral expression, chunky pixels, 8-bit style, simple forms."""
    },
    {
        "id": "C11b", "name": "guest_mage",
        "output": "characters/guest_mage.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art bust portrait. Male mage head. Pointed wizard hat, long white beard, mysterious look.
Limited color palette, flat colors, 1px black outlines.
Transparent background, neutral expression, chunky pixels, simple forms."""
    },
    {
        "id": "C11c", "name": "guest_rogue",
        "output": "characters/guest_rogue.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art bust portrait. Rogue character head. Hood pulled low, cloth mask covering lower face.
Cunning eyes visible, stealthy look. Limited color palette, flat colors, 1px black outlines.
Transparent background, neutral expression, chunky pixels, simple forms."""
    },
    {
        "id": "C11d", "name": "guest_archer",
        "output": "characters/guest_archer.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art bust portrait. Archer character head. Feathered cap, pointed elf-like ears.
Sharp keen gaze. Limited color palette, flat colors, 1px black outlines.
Transparent background, neutral expression, chunky pixels, simple forms."""
    },
    {
        "id": "C11e", "name": "guest_cleric",
        "output": "characters/guest_cleric.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art bust portrait. Cleric character head. Bald or short hair, holy symbol pendant.
Kind gentle face. Limited color palette, flat colors, 1px black outlines.
Transparent background, neutral expression, chunky pixels, simple forms."""
    },
    {
        "id": "C11f", "name": "guest_barbarian",
        "output": "characters/guest_barbarian.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art bust portrait. Barbarian character head. Wild unkempt hair, war paint stripes on face.
Animal fur cloak on shoulders, fierce look, battle-scarred.
Limited color palette, flat colors, 1px black outlines.
Transparent background, neutral expression, chunky pixels, simple forms."""
    },
]
TASKS.extend(P1_GUESTS)

# ==================== P1 采集点图标 ====================
P1_MAP_ICONS = [
    {
        "id": "D2a", "name": "icon_mushroom",
        "output": "icons/map/icon_mushroom.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art icon. Cluster of glowing mushrooms, caps emitting blue-white light.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms, 8-bit style."""
    },
    {
        "id": "D2b", "name": "icon_mine",
        "output": "icons/map/icon_mine.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art icon. Two crossed pickaxes with chunk of dark ore between them.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms, 8-bit style."""
    },
    {
        "id": "D2c", "name": "icon_river",
        "output": "icons/map/icon_river.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art icon. Water droplet with ripple rings beneath, suggesting underground river.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms, 8-bit style."""
    },
    {
        "id": "D2d", "name": "icon_vine",
        "output": "icons/map/icon_vine.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art icon. Bunch of grapes with curling vine tendrils.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms, 8-bit style."""
    },
    {
        "id": "D2e", "name": "icon_mill",
        "output": "icons/map/icon_mill.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art icon. Small windmill building silhouette.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms, 8-bit style."""
    },
]
TASKS.extend(P1_MAP_ICONS)

# ==================== P1 通用小图标 ====================
P1_UI_ICONS = [
    {
        "id": "U1", "name": "icon_gold",
        "output": "ui/icon_gold.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art tiny icon. Round gold coin with serrated edge, star mark in center.
Golden highlight. 1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms."""
    },
    {
        "id": "U2", "name": "icon_star",
        "output": "ui/icon_star.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art tiny icon. Five-pointed star, amber-gold fill.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms."""
    },
    {
        "id": "U3", "name": "icon_stamina",
        "output": "ui/icon_stamina.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art tiny icon. Small heart shape or lightning bolt, bright green fill.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms."""
    },
    {
        "id": "U4", "name": "icon_close",
        "output": "ui/icon_close.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art tiny icon. X cross mark, 2px line width, muted brown.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms."""
    },
    {
        "id": "U5", "name": "icon_check",
        "output": "ui/icon_check.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art tiny icon. Checkmark tick, 2px line width, success green.
1px black outlines. Limited color palette, flat colors.
Transparent background, simple forms."""
    },
]
TASKS.extend(P1_UI_ICONS)

# ==================== P1 UI组件 ====================
P1_UI = [
    {
        "id": "UI1", "name": "panel_parchment_9patch",
        "output": "ui/panel_parchment_9patch.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art 9-patch panel. Parchment texture, warm pale brown base.
Subtle fiber grain texture. Edges slightly darkened.
2px dark brown border, corners darker. Center plain parchment.
Limited color palette, flat colors, 1px black outlines. Transparent background."""
    },
    {
        "id": "UI2", "name": "bubble_order_9patch",
        "output": "ui/bubble_order_9patch.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art 9-patch speech bubble. Light parchment interior.
2px border, pointed tail on left side.
Limited color palette, flat colors, 1px black outlines. Transparent background."""
    },
    {
        "id": "UI3", "name": "title_sign",
        "output": "ui/title_sign.png", "width": 1024, "height": 256,
        "prompt": f"""{LORA_TAG} Pixel art decorative banner sign, 1024x256. Amber-gold fill.
2px black outline, drop shadow offset downward. Transparent background.
Clean pixel edges. Limited color palette, flat colors. No text, decorative only."""
    },
    {
        "id": "UI4a", "name": "deco_candle_left",
        "output": "ui/deco_candle_left.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art decoration. Metal candle holder base, half-melted candle, small flame (#ff9500).
Dark outline, transparent background. Limited color palette, flat colors, 1px black outlines."""
    },
    {
        "id": "UI4b", "name": "deco_candle_right",
        "output": "ui/deco_candle_right.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art decoration. Candle holder similar to left but mirrored. Metal holder, half-melted candle, flame.
Dark outline, transparent background. Limited color palette, flat colors, 1px black outlines."""
    },
    {
        "id": "UI4c", "name": "deco_mug",
        "output": "ui/deco_mug.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art decoration. Wooden beer mug on bartop, foam overflowing, warm tones.
Dark outline, transparent background. Limited color palette, flat colors, 1px black outlines."""
    },
    {
        "id": "UI4d", "name": "deco_emblem",
        "output": "ui/deco_emblem.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art emblem. Tavern crest: shield shape with wheat stalks and drinking mug.
Amber on dark shield. Transparent background. Limited color palette, flat colors, 1px black outlines."""
    },
    {
        "id": "UI5", "name": "bar_stamina_segment",
        "output": "ui/bar_stamina_segment.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art UI element. Heart or lightning bolt shape, amber-colored fill.
Dark outline, transparent background. Limited color palette, flat colors."""
    },
    {
        "id": "UI6", "name": "divider_rope",
        "output": "ui/divider_rope.png", "width": 1000, "height": 32,
        "prompt": f"""{LORA_TAG} Pixel art UI divider, horizontal thin line. Rope texture, brown color (#554334).
Small spiral decorations at both ends. Transparent background.
Limited color palette, flat colors, 1px black outlines. Simple pixel pattern."""
    },
]
TASKS.extend(P1_UI)

# ==================== P2 VFX ====================
P2_VFX = [
    {"id": "B21_1", "name": "steam_01", "output": "vfx/steam/steam_01.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. White steam beginning to rise from bottom center. Limited palette, flat colors, transparent bg."""},
    {"id": "B21_2", "name": "steam_02", "output": "vfx/steam/steam_02.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. White steam rising higher, expanding slightly, wispy cloud shape. Limited palette, flat colors, transparent bg."""},
    {"id": "B21_3", "name": "steam_03", "output": "vfx/steam/steam_03.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. White steam fully risen, spreading horizontally, wider cloud. Limited palette, flat colors, transparent bg."""},
    {"id": "B21_4", "name": "steam_04", "output": "vfx/steam/steam_04.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. White steam dispersing and fading, thin wisps, almost gone. Limited palette, flat colors, transparent bg."""},
    {"id": "B22_1", "name": "splash_01", "output": "vfx/splash/splash_01.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Small white droplets appearing at center, transparent bg. Limited palette, flat colors."""},
    {"id": "B22_2", "name": "splash_02", "output": "vfx/splash/splash_02.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. White droplets spreading outward left and right from center, transparent bg. Limited palette, flat colors."""},
    {"id": "B22_3", "name": "splash_03", "output": "vfx/splash/splash_03.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. White droplets fading and disappearing, barely visible dots at edges, transparent bg. Limited palette, flat colors."""},
    {"id": "B23_1", "name": "swirl_01", "output": "vfx/swirl/swirl_01.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Liquid vortex starting, spiral pattern with 2-3 arms beginning, white semi-transparent, transparent bg, flat colors."""},
    {"id": "B23_2", "name": "swirl_02", "output": "vfx/swirl/swirl_02.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Liquid vortex rotating about 60 degrees, spiral pattern, white semi-transparent, transparent bg, flat colors."""},
    {"id": "B23_3", "name": "swirl_03", "output": "vfx/swirl/swirl_03.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Liquid vortex rotating about 120 degrees, spiral pattern, white semi-transparent, transparent bg, flat colors."""},
    {"id": "B23_4", "name": "swirl_04", "output": "vfx/swirl/swirl_04.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Liquid vortex rotating about 180 degrees, spiral pattern, white semi-transparent, transparent bg, flat colors."""},
    {"id": "B23_5", "name": "swirl_05", "output": "vfx/swirl/swirl_05.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Liquid vortex rotating about 240 degrees, spiral pattern, white semi-transparent, transparent bg, flat colors."""},
    {"id": "B23_6", "name": "swirl_06", "output": "vfx/swirl/swirl_06.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Liquid vortex rotating about 300 degrees, spiral pattern, white semi-transparent, transparent bg, flat colors."""},
    {"id": "B24_1", "name": "sparkle_01", "output": "vfx/sparkle/sparkle_01.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Star sparkle beginning, bright center dot, pure white core, transparent bg, limited palette, flat colors."""},
    {"id": "B24_2", "name": "sparkle_02", "output": "vfx/sparkle/sparkle_02.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Star sparkle expanding, bright white center with amber edges starting, transparent bg, flat colors."""},
    {"id": "B24_3", "name": "sparkle_03", "output": "vfx/sparkle/sparkle_03.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Star sparkle full starburst, white center with amber-gold rays outward, transparent bg, flat colors."""},
    {"id": "B24_4", "name": "sparkle_04", "output": "vfx/sparkle/sparkle_04.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Star sparkle peak brightness, amber-gold full starburst, particles at edges, transparent bg, flat colors."""},
    {"id": "B24_5", "name": "sparkle_05", "output": "vfx/sparkle/sparkle_05.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Star sparkle fading, amber rays shrinking, particles dissipating, transparent bg, flat colors."""},
    {"id": "B24_6", "name": "sparkle_06", "output": "vfx/sparkle/sparkle_06.png", "width": 512, "height": 512,
     "prompt": f"""{LORA_TAG} Pixel art VFX. Star sparkle almost gone, faint amber dots remaining, mostly transparent, flat colors."""},
]
TASKS.extend(P2_VFX)

# ==================== P2 剧情道具 ====================
P2_ITEMS = [
    {
        "id": "I15", "name": "sleep_powder",
        "output": "icons/items/sleep_powder.png", "width": 512, "height": 512,
        "prompt": f"""{LORA_TAG} Pixel art item icon. Small round-bottom glass flask with cork stopper, containing fine purple powder (#7b3fa3).
Faint purple glow from within. Glass has white reflections. 1px dark outline.
Transparent background. RPG inventory icon. Pixel art, flat colors, crisp edges."""
    },
]
TASKS.extend(P2_ITEMS)


# ========== 核心函数 ==========
def check_webui():
    try:
        r = requests.get(f"{API_BASE}/sdapi/v1/sd-models", timeout=5)
        if r.status_code == 200:
            models = r.json()
            print(f"[OK] WebUI running, {len(models)} model(s)")
            return True
        return False
    except Exception as e:
        print(f"[ERR] Cannot connect: {e}")
        return False


def generate_image(task, steps=25):
    """调用 WebUI API 生成图片"""
    prompt = task["prompt"] + "\n" + STYLE_SUFFIX
    payload = {
        "prompt": prompt,
        "negative_prompt": NEGATIVE_PROMPT,
        "width": task["width"],
        "height": task["height"],
        "steps": steps,
        "cfg_scale": 7.0,
        "sampler_name": "DPM++ 2M Karras",
        "batch_size": 1,
        "n_iter": 1,
        "seed": -1,
        "restore_faces": False,
        "tiling": False,
        "enable_hr": False,
    }

    # 对于非标准尺寸，启用 hi-res fix
    if task["width"] != task["height"] and task["width"] < 1024:
        pass  # 保持原始尺寸

    output_path = ASSETS_DIR / task["output"]

    try:
        w, h = task["width"], task["height"]
        print(f"  Generating {w}x{h}...", end=" ", flush=True)
        r = requests.post(f"{API_BASE}/sdapi/v1/txt2img", json=payload, timeout=600)

        if r.status_code == 200:
            data = r.json()
            if "images" in data and len(data["images"]) > 0:
                image_data = base64.b64decode(data["images"][0])
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with open(output_path, 'wb') as f:
                    f.write(image_data)
                kb = len(image_data) / 1024
                print(f"OK ({kb:.0f} KB)")
                return True
            else:
                print("ERR: no image in response")
                return False
        else:
            print(f"ERR: HTTP {r.status_code}")
            try:
                err = r.json()
                print(f"  {json.dumps(err)[:200]}")
            except:
                print(f"  {r.text[:200]}")
            return False
    except Exception as e:
        print(f"ERR: {e}")
        return False


def main():
    print("=" * 70)
    print("  ALL Art Assets Batch Generator (SDXL + pixel-art-xl LoRA)")
    print("=" * 70)
    print(f"  Assets dir: {ASSETS_DIR}")
    print(f"  Total tasks: {len(TASKS)}")
    print()

    if not check_webui():
        print("[ABORT] WebUI not running!")
        return

    total = success = failed = skipped = 0

    for i, task in enumerate(TASKS):
        total += 1
        output_path = ASSETS_DIR / task["output"]
        print(f"[{i+1}/{len(TASKS)}] {task['id']} {task['name']}")

        if output_path.exists():
            print(f"  SKIP: already exists")
            skipped += 1
            continue

        if generate_image(task):
            success += 1
        else:
            failed += 1

        time.sleep(1)

    print(f"\n{'='*70}")
    print(f"  DONE! Total: {total} | OK: {success} | Failed: {failed} | Skipped: {skipped}")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
