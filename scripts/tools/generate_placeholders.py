#!/usr/bin/env python3
"""
占位符美术资源生成脚本
使用 Pillow 库生成 P0 和 P1 优先级的所有占位符资源
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

# ============================================================
#  配置
# ============================================================

# 项目根目录
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 资源输出目录
TEXTURES_DIR = os.path.join(PROJECT_DIR, "assets", "textures")

# 颜色定义（从 Godot theme_colors.gd 转换）
COLORS = {
    "amber_primary": (255, 190, 127),
    "amber_bright": (255, 149, 0),
    "amber_dark": (204, 115, 0),
    "bg_deep": (22, 19, 17),
    "surface_low": (31, 27, 25),
    "surface_mid": (35, 31, 29),
    "surface_high": (46, 41, 39),
    "surface_highest": (57, 52, 49),
    "text_light": (234, 225, 221),
    "text_subtitle": (219, 194, 173),
    "text_dim": (163, 141, 122),
    "success": (74, 140, 63),
    "danger": (166, 38, 26),
    "panel_border": (85, 67, 52),
}

# 材料颜色
MATERIAL_COLORS = {
    "wheat": (230, 204, 128),
    "mushroom": (204, 153, 179),
    "herb": (102, 179, 77),
    "grape": (153, 51, 204),
    "milk": (242, 242, 230),
    "cream": (255, 242, 217),
    "honey": (255, 204, 51),
    "yeast": (204, 179, 153),
}

# 成品颜色
PRODUCT_COLORS = {
    "bread": (217, 166, 102),
    "ale": (230, 179, 77),
    "wine": (153, 26, 77),
    "cheese": (255, 217, 102),
    "roast": (179, 77, 51),
    "stew": (153, 102, 77),
    "pie": (204, 153, 102),
    "salad": (128, 204, 77),
}


# ============================================================
#  辅助函数
# ============================================================

def ensure_dir(path: str) -> None:
    """确保目录存在"""
    os.makedirs(path, exist_ok=True)


def save_image(img: Image.Image, path: str) -> bool:
    """保存图片"""
    try:
        ensure_dir(os.path.dirname(path))
        img.save(path, "PNG")
        print("    [OK] %s" % os.path.basename(path))
        return True
    except Exception as e:
        print("    [FAIL] %s - %s" % (os.path.basename(path), e))
        return False


def create_circle_icon(w: int, h: int, bg_color: tuple, label: str = "") -> Image.Image:
    """创建圆形图标"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center_x = w // 2
    center_y = h // 2
    radius = min(w, h) // 2 - 2

    # 绘制圆形
    draw.ellipse(
        [center_x - radius, center_y - radius, center_x + radius, center_y + radius],
        fill=bg_color,
        outline=tuple(int(c * 0.7) for c in bg_color[:3]) + (255,),
        width=2
    )

    # 添加标签（如果有）
    if label:
        try:
            font = ImageFont.truetype("arial.ttf", min(w, h) // 3)
        except:
            font = ImageFont.load_default()
        bbox = draw.textbbox((0, 0), label, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]
        text_x = (w - text_w) // 2
        text_y = (h - text_h) // 2
        draw.text((text_x, text_y), label, fill=COLORS["text_light"] + (255,), font=font)

    return img


def create_square_icon(w: int, h: int, bg_color: tuple, label: str = "") -> Image.Image:
    """创建方形图标（带圆角）"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 绘制圆角矩形
    radius = 4
    draw.rounded_rectangle(
        [2, 2, w - 3, h - 3],
        radius=radius,
        fill=bg_color,
        outline=tuple(int(c * 0.7) for c in bg_color[:3]) + (255,),
        width=1
    )

    # 添加标签
    if label:
        try:
            font = ImageFont.truetype("arial.ttf", min(w, h) // 3)
        except:
            font = ImageFont.load_default()
        bbox = draw.textbbox((0, 0), label, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]
        text_x = (w - text_w) // 2
        text_y = (h - text_h) // 2
        draw.text((text_x, text_y), label, fill=COLORS["text_light"] + (255,), font=font)

    return img


def create_bg(w: int, h: int, bg_color: tuple, label: str = "") -> Image.Image:
    """创建背景图像"""
    img = Image.new("RGBA", (w, h), bg_color)
    draw = ImageDraw.Draw(img)

    # 添加网格线（如果是地图）
    if "MAP" in label:
        line_color = tuple(min(255, int(c * 1.05)) for c in bg_color[:3]) + (128,)
        for y in range(0, h, 80):
            draw.line([(0, y), (w, y)], fill=line_color, width=1)
        for x in range(0, w, 80):
            draw.line([(x, 0), (x, h)], fill=line_color, width=1)

    # 添加标签
    if label:
        try:
            font = ImageFont.truetype("arial.ttf", 48)
        except:
            font = ImageFont.load_default()
        bbox = draw.textbbox((0, 0), label, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]
        text_x = (w - text_w) // 2
        text_y = (h - text_h) // 2
        draw.text((text_x, text_y), label, fill=COLORS["text_light"] + (255,), font=font)

    return img


def create_9patch(w: int, h: int, bg_color: tuple, border_color: tuple) -> Image.Image:
    """创建 9-patch 纹理"""
    img = Image.new("RGBA", (w, h), bg_color)
    draw = ImageDraw.Draw(img)

    # 绘制边框
    draw.rectangle([0, 0, w - 1, h - 1], outline=border_color, width=2)

    # 9-patch 标记（左上和右下角的小黑点）
    draw.point((0, 0), fill=(0, 0, 0, 255))
    draw.point((w - 1, 0), fill=(0, 0, 0, 255))
    draw.point((0, h - 1), fill=(0, 0, 0, 255))
    draw.point((w - 1, h - 1), fill=(0, 0, 0, 255))

    return img


def create_button(w: int, h: int, bg_color: tuple, shadow_color: tuple) -> Image.Image:
    """创建按钮贴图"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 绘制按钮主体（渐变效果）
    for y in range(h):
        t = y / h
        r = int(bg_color[0] * (1 - t * 0.1))
        g = int(bg_color[1] * (1 - t * 0.1))
        b = int(bg_color[2] * (1 - t * 0.1))
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # 绘制边框
    draw.rectangle([0, 0, w - 1, h - 1], outline=shadow_color, width=2)

    # 底部阴影
    draw.line([(0, h - 1), (w, h - 1)], fill=tuple(int(c * 0.7) for c in shadow_color[:3]) + (255,), width=2)

    return img


def create_slot(w: int, h: int, bg_color: tuple, border_color: tuple) -> Image.Image:
    """创建槽位贴图"""
    img = Image.new("RGBA", (w, h), bg_color)
    draw = ImageDraw.Draw(img)

    # 绘制边框
    draw.rectangle([0, 0, w - 1, h - 1], outline=border_color, width=2)

    return img


def create_bar(w: int, h: int, fill_color: tuple, border_color: tuple) -> Image.Image:
    """创建进度条/体力条"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 绘制填充
    draw.rectangle([2, 2, w - 3, h - 3], fill=fill_color)

    # 绘制边框
    draw.rectangle([0, 0, w - 1, h - 1], outline=border_color, width=1)

    return img


def create_divider(w: int, h: int, color: tuple) -> Image.Image:
    """创建分隔线"""
    img = Image.new("RGBA", (w, h), color)
    return img


def create_title_sign() -> Image.Image:
    """创建标题招牌"""
    w, h = 512, 128
    img = Image.new("RGBA", (w, h), COLORS["surface_low"])
    draw = ImageDraw.Draw(img)

    # 木制纹理（简化）
    bg_color = COLORS["panel_border"]
    for y in range(h):
        for x in range(w):
            noise = (x * 7 + y * 13) % 32
            if noise < 16:
                draw.point((x, y), fill=tuple(min(255, int(c * 1.1)) for c in bg_color[:3]) + (255,))
            else:
                draw.point((x, y), fill=bg_color)

    # 绘制边框
    draw.rectangle([0, 0, w - 1, h - 1], outline=COLORS["amber_primary"], width=4)

    # 添加文字
    try:
        font = ImageFont.truetype("arial.ttf", 64)
    except:
        font = ImageFont.load_default()
    label = "TAVERN"
    bbox = draw.textbbox((0, 0), label, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (w - text_w) // 2
    text_y = (h - text_h) // 2
    draw.text((text_x, text_y), label, fill=COLORS["amber_primary"] + (255,), font=font)

    return img


# ============================================================
#  主生成函数
# ============================================================

def generate_p1_backgrounds(output_dir: str) -> int:
    """生成 P1 背景资源"""
    print("[P1] 生成背景资源...")
    count = 0
    bg_dir = os.path.join(output_dir, "backgrounds")
    ensure_dir(bg_dir)

    # D1 - 地牢区域地图背景
    img = create_bg(1280, 720, COLORS["bg_deep"], "DAYMAP")
    if save_image(img, os.path.join(bg_dir, "daymap_bg.png")):
        count += 1

    # E1 - 结局画面背景
    img = create_bg(1280, 720, (13, 10, 20, 255), "ENDING")
    if save_image(img, os.path.join(bg_dir, "ending_bg.png")):
        count += 1

    print(f"  ✓ 背景资源生成完成 ({count} 个)")
    return count


def generate_p1_icons(output_dir: str) -> int:
    """生成 P1 图标资源"""
    print("[P1] 生成图标资源...")
    count = 0

    # D2a-e - 采集点图标
    map_dir = os.path.join(output_dir, "icons", "map")
    ensure_dir(map_dir)

    gathering_icons = [
        ("icon_mushroom_grotto", "🍄", (153, 102, 179)),
        ("icon_abandoned_mine", "⛏", (128, 128, 128)),
        ("icon_underground_river", "💧", (51, 128, 230)),
        ("icon_grape_terrace", "🍇", (153, 51, 204)),
        ("icon_underground_farm", "🌾", (230, 204, 77)),
    ]
    for name, emoji, color in gathering_icons:
        img = create_circle_icon(64, 64, color, emoji)
        if save_image(img, os.path.join(map_dir, f"{name}.png")):
            count += 1

    # C11a-f - 普通客人头像
    char_dir = os.path.join(output_dir, "characters")
    ensure_dir(char_dir)

    guest_icons = [
        ("guest_dwarf", "🧔", (153, 102, 51)),
        ("guest_knight", "⚔", (179, 179, 204)),
        ("guest_rogue", "🗡", (77, 77, 102)),
        ("guest_wizard", "🔮", (102, 51, 179)),
        ("guest_merchant", "💰", (230, 204, 77)),
        ("guest_commoner", "👤", (179, 153, 128)),
    ]
    for name, emoji, color in guest_icons:
        img = create_circle_icon(64, 64, color, emoji)
        if save_image(img, os.path.join(char_dir, f"{name}.png")):
            count += 1

    # U1-U5 - 通用小图标
    ui_dir = os.path.join(output_dir, "ui")
    ensure_dir(ui_dir)

    ui_icons = [
        ("icon_coin", "💰", (255, 217, 0)),
        ("icon_time", "⏱", (204, 204, 204)),
        ("icon_patience", "❤", (230, 51, 51)),
        ("icon_stamina", "⚡", (255, 204, 0)),
        ("icon_star", "⭐", (255, 255, 0)),
    ]
    for name, emoji, color in ui_icons:
        img = create_square_icon(24, 24, color, emoji)
        if save_image(img, os.path.join(ui_dir, f"{name}.png")):
            count += 1

    print(f"  ✓ 图标资源生成完成 ({count} 个)")
    return count


def generate_p1_ui(output_dir: str) -> int:
    """生成 P1 UI 组件"""
    print("[P1] 生成 UI 组件...")
    count = 0
    ui_dir = os.path.join(output_dir, "ui")
    ensure_dir(ui_dir)

    # 羊皮纸 9-patch 面板
    img = create_9patch(32, 32, COLORS["surface_high"], COLORS["panel_border"])
    if save_image(img, os.path.join(ui_dir, "panel_parchment_9patch.png")):
        count += 1

    # 对话气泡 9-patch
    img = create_9patch(32, 32, (51, 46, 38, 242), COLORS["amber_primary"])
    if save_image(img, os.path.join(ui_dir, "bubble_order_9patch.png")):
        count += 1

    # 标题招牌
    img = create_title_sign()
    if save_image(img, os.path.join(ui_dir, "title_sign.png")):
        count += 1

    # 注意：tavern_sign.png 已存在于 backgrounds 目录（使用 title_bg.png 即可）

    # 标题装饰元素
    decos = [
        ("deco_left", "◆", (255, 179, 51)),
        ("deco_right", "◆", (255, 179, 51)),
        ("deco_top", "─", (255, 179, 51)),
        ("deco_bottom", "─", (255, 179, 51)),
    ]
    for name, shape, color in decos:
        img = create_square_icon(64, 64, color, shape)
        if save_image(img, os.path.join(ui_dir, f"{name}.png")):
            count += 1

    # 体力分段槽
    img = create_bar(48, 32, COLORS["success"], (51, 112, 38))
    if save_image(img, os.path.join(ui_dir, "bar_stamina_segment.png")):
        count += 1

    # 分隔线
    img = create_divider(1000, 4, COLORS["panel_border"])
    if save_image(img, os.path.join(ui_dir, "divider_rope.png")):
        count += 1

    # 按钮贴图
    buttons = [
        ("btn_wide_normal", 200, 48, COLORS["amber_primary"], (204, 153, 102)),
        ("btn_wide_hover", 200, 48, COLORS["amber_bright"], (204, 128, 0)),
        ("btn_wide_pressed", 200, 48, COLORS["amber_dark"], (153, 102, 0)),
        ("btn_small_normal", 120, 36, COLORS["amber_primary"], (204, 153, 102)),
        ("btn_small_hover", 120, 36, COLORS["amber_bright"], (204, 128, 0)),
        ("btn_small_pressed", 120, 36, COLORS["amber_dark"], (153, 102, 0)),
    ]
    for name, w, h, bg, shadow in buttons:
        img = create_button(w, h, bg, shadow)
        if save_image(img, os.path.join(ui_dir, f"{name}.png")):
            count += 1

    # 槽位贴图
    slots = [
        ("slot_material", 80, 80, COLORS["surface_mid"], COLORS["panel_border"]),
        ("slot_result", 80, 80, COLORS["surface_high"], COLORS["amber_primary"]),
        ("slot_shortcut", 64, 64, COLORS["surface_low"], COLORS["panel_border"]),
    ]
    for name, w, h, bg, border in slots:
        img = create_slot(w, h, bg, border)
        if save_image(img, os.path.join(ui_dir, f"{name}.png")):
            count += 1

    # 快捷栏/顶栏背景
    bars = [
        ("bar_shortcut_bg", 1200, 64, COLORS["bg_deep"], COLORS["panel_border"]),
        ("bar_top_panel", 1280, 48, (22, 19, 17, 255), COLORS["panel_border"]),
    ]
    for name, w, h, bg, border in bars:
        img = create_bar(w, h, bg, border)
        if save_image(img, os.path.join(ui_dir, f"{name}.png")):
            count += 1

    # 耐心条填充
    img = create_bar(100, 12, COLORS["success"], (51, 112, 38))
    if save_image(img, os.path.join(ui_dir, "bar_patience_fill.png")):
        count += 1

    print(f"  ✓ UI 组件生成完成 ({count} 个)")
    return count


def generate_p0_materials(output_dir: str) -> int:
    """生成 P0 材料图标"""
    print("[P0] 生成材料图标...")
    count = 0
    mat_dir = os.path.join(output_dir, "icons", "materials")
    ensure_dir(mat_dir)

    materials = [
        ("wheat", "🌾", MATERIAL_COLORS["wheat"]),
        ("mushroom", "🍄", MATERIAL_COLORS["mushroom"]),
        ("herb", "🌿", MATERIAL_COLORS["herb"]),
        ("grape", "🍇", MATERIAL_COLORS["grape"]),
        ("milk", "🥛", MATERIAL_COLORS["milk"]),
        ("cream", "🫗", MATERIAL_COLORS["cream"]),
        ("honey", "🍯", MATERIAL_COLORS["honey"]),
        ("yeast", "🧫", MATERIAL_COLORS["yeast"]),
    ]
    for name, emoji, color in materials:
        img = create_circle_icon(48, 48, color, emoji)
        if save_image(img, os.path.join(mat_dir, f"{name}.png")):
            count += 1

    print(f"  ✓ 材料图标生成完成 ({count} 个)")
    return count


def generate_p0_products(output_dir: str) -> int:
    """生成 P0 成品图标"""
    print("[P0] 生成成品图标...")
    count = 0
    prod_dir = os.path.join(output_dir, "icons", "products")
    ensure_dir(prod_dir)

    products = [
        ("bread", "🍞", PRODUCT_COLORS["bread"]),
        ("ale", "🍺", PRODUCT_COLORS["ale"]),
        ("wine", "🍷", PRODUCT_COLORS["wine"]),
        ("cheese", "🧀", PRODUCT_COLORS["cheese"]),
        ("roast", "🥩", PRODUCT_COLORS["roast"]),
        ("stew", "🍲", PRODUCT_COLORS["stew"]),
        ("pie", "🥧", PRODUCT_COLORS["pie"]),
        ("salad", "🥗", PRODUCT_COLORS["salad"]),
        ("honey_bread", "🍯🍞", (230, 179, 77)),
        ("premium_ale", "🍺✨", (255, 204, 51)),
    ]
    for name, emoji, color in products:
        img = create_circle_icon(48, 48, color, emoji)
        if save_image(img, os.path.join(prod_dir, f"{name}.png")):
            count += 1

    print(f"  ✓ 成品图标生成完成 ({count} 个)")
    return count


def generate_p0_ui(output_dir: str) -> int:
    """生成 P0 基础 UI"""
    print("[P0] 生成基础 UI...")
    # P0 的基础 UI 已在 P1 中生成
    print("  ✓ 基础 UI 已在 P1 中生成")
    return 0


# ============================================================
#  主函数
# ============================================================

def main():
    print("=" * 50)
    print("  占位符美术资源生成器")
    print("=" * 50)
    print()

    print(f"项目目录: {PROJECT_DIR}")
    print(f"输出目录: {TEXTURES_DIR}")
    print()

    # 确保输出目录存在
    ensure_dir(TEXTURES_DIR)

    count = 0

    # 生成 P1 资源
    count += generate_p1_backgrounds(TEXTURES_DIR)
    count += generate_p1_icons(TEXTURES_DIR)
    count += generate_p1_ui(TEXTURES_DIR)
    print()

    # 生成 P0 资源
    count += generate_p0_materials(TEXTURES_DIR)
    count += generate_p0_products(TEXTURES_DIR)
    count += generate_p0_ui(TEXTURES_DIR)
    print()

    print("=" * 50)
    print(f"  生成完成！共 {count} 个文件")
    print("=" * 50)
    print()
    print("【后续步骤】")
    print("  1. 在 Godot 编辑器中，右键点击 'assets' 文件夹")
    print("  2. 选择 '重新导入' 来刷新纹理")
    print("  3. 运行游戏测试资源加载")
    print()


if __name__ == "__main__":
    main()
