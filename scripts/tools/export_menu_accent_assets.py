"""重做两个琥珀 accent 件，参照已认可的"颜料堆"质感。

设计语言：暗青刷痕为底，琥珀作 accent。旧 hover marker 是实心橙砖、旧 grabber 是
多阶 3D 宝石球，都不对。

- hover marker：复用标题"颜料堆"标记（横向），代码里 KEEP_ASPECT_CENTERED 保比例不形变。
- slider grabber：用 GPT 手绘竖向琥珀笔触（menu_accent_dabs.png 右半），抠白底 →
  量化到标题同款琥珀三阶（暗/中/亮芯）→ 小尺寸 4px 块。滑块按 PNG 原生像素 1:1 画，
  不做运行时拉伸，尺寸只由导出像素数决定。

文件名沿用原资产名直接覆盖，零改代码。流程对齐 [[ui-art-pixelization-workflow]]。
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TITLE_MARKER = ROOT / "assets" / "textures" / "title" / "title_pixel_menu_marker.png"
SRC_DABS = ROOT / "assets" / "source" / "ui" / "menu_accent_dabs.png"
OUTPUT = ROOT / "assets" / "textures" / "ui"

SCALE = 4  # 与已上线 4px 块密度一致

# 颜料堆分层琥珀（与 build_marker / 标题标记同调），5 阶让像素块有渐变质感
AMBER_RAMP = [
    (140, 66, 0), (180, 96, 4), (224, 133, 0), (245, 162, 14), (255, 190, 40),
]


def lum(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b


def key_white(im):
    """纯白底→透明，颜料→不透明（软边）。高亮度+低饱和=背景。"""
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            sat, L = mx - mn, lum(r, g, b)
            if L >= 232 and sat <= 16:
                continue
            a = 255
            if L >= 205 and sat <= 30:
                a = max(0, min(255, int(255 * (232 - L) / 27)))
            if a > 0:
                o[x, y] = (r, g, b, a)
    return out


def crop_a(im, thr=24):
    a = im.getchannel("A")
    box = a.point(lambda v: 255 if v >= thr else 0).getbbox()
    return im.crop(box) if box else im


def export_hover_marker():
    """复用标题颜料堆标记。"""
    marker = Image.open(TITLE_MARKER).convert("RGBA")
    marker.save(OUTPUT / "menu_brush_hover_marker.png")
    print(f"menu_brush_hover_marker.png: {marker.size}")


GRABBER_BLOCKS_H = 11  # native 块高；×SCALE=44 显示。4px 块密度与 marker 一致


def _pixelize_amber(keyed, gw, gh):
    """降采样到 gw×gh 块网格：RGB 量化到琥珀色板，alpha 保留渐变(飞白半透块) → ×SCALE 最近邻。"""
    small = keyed.resize((gw, gh), Image.LANCZOS)
    px = small.load()
    vals = [lum(*px[x, y][:3]) for y in range(gh) for x in range(gw) if px[x, y][3] >= 24]
    lo, hi = (min(vals), max(vals)) if vals else (0, 255)
    rng = max(hi - lo, 1)
    n = len(AMBER_RAMP)
    out = Image.new("RGBA", (gw, gh), (0, 0, 0, 0))
    o = out.load()
    for y in range(gh):
        for x in range(gw):
            r, g, b, a = px[x, y]
            if a < 90:
                continue  # 半透闷块剔除，块要么实要么无，保持像素脆不发糊
            idx = min(n - 1, max(0, int((lum(r, g, b) - lo) / rng * n)))
            o[x, y] = AMBER_RAMP[idx] + (255,)
    return out.resize((gw * SCALE, gh * SCALE), Image.NEAREST)


def export_slider_grabber():
    """GPT 手绘竖向琥珀笔触（源图右半）→ 抠白底 → 4px 块像素化（多阶琥珀+飞白边）。

    像素化但不过粗：留够列数铺渐变、保半透飞白块。与 marker 同为 4px 块"颜料"质感。
    """
    src = Image.open(SRC_DABS).convert("RGB")
    w, h = src.size
    right = src.crop((int(w * 0.65), 0, w, h))  # 右段 = 竖向笔触（避开横笔触尾巴）
    # 低阈值纳入笔触虚边 → bbox 略宽 → 4px 块下能给出 ~5 列铺渐变
    keyed = crop_a(key_white(right), thr=40)
    bw, bh = keyed.size
    gh = GRABBER_BLOCKS_H
    gw = max(4, round(gh * bw / bh))
    grabber = _pixelize_amber(keyed, gw, gh)
    grabber.save(OUTPUT / "menu_brush_slider_grabber.png")
    print(f"menu_brush_slider_grabber.png: {grabber.size}  (bbox {bw}x{bh}, grid {gw}x{gh})")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    export_hover_marker()
    export_slider_grabber()
