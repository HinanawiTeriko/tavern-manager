from pathlib import Path
from collections import deque
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "characters" / "mira" / "mira_expression_sheet_source_v4.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "mira" / "mira_expression_sheet_prompt_v4.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST = SOURCE_DIR / "mira_rebalance_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "mira_rebalance_contact_sheet.png"
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
COLOR_LIMIT = 72
STYLE_PROFILE = "mira_rebalanced_tavern_bust_v4_preview"
CONTACT_SHEET_SIZE = (1600, 820)
PORTRAITS = [
    "mira_rebalance_neutral",
    "mira_rebalance_smile",
    "mira_rebalance_surprised",
    "mira_rebalance_serious",
    "mira_rebalance_guilty",
    "mira_rebalance_conflicted",
    "mira_rebalance_resolved",
    "mira_rebalance_detached",
]


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def unique_visible_colors(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    return len({(red, green, blue) for red, green, blue, alpha in data if alpha > 0})


def green_key_fringe_pixels(image: Image.Image) -> int:
    count = 0
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    for red, green, blue, alpha in data:
        if alpha == 0:
            continue
        if green >= 80 and green > red * 1.25 and green > blue * 1.25:
            count += 1
    return count


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds == None:
        return (0, 0, 0, 0)
    return bounds


def second_largest_alpha_component(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    width, height = alpha.size
    seen: set[tuple[int, int]] = set()
    sizes: list[int] = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == 0 or (x, y) in seen:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen.add((x, y))
            size = 0
            while queue:
                cx, cy = queue.popleft()
                size += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx = cx + dx
                    ny = cy + dy
                    if 0 <= nx < width and 0 <= ny < height and pixels[nx, ny] > 0 and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            sizes.append(size)
    sizes.sort(reverse=True)
    return sizes[1] if len(sizes) > 1 else 0


class MiraBustRebalancePreviewAssetPipelineTest(unittest.TestCase):
    def test_source_prompt_and_manifest_exist(self) -> None:
        self.assertTrue(RAW.exists(), "Mira rebalance source sheet is missing")
        self.assertTrue(PROMPT.exists(), "Mira rebalance prompt record is missing")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "4 columns x 2 rows",
            "mira",
            "tavern npc bust",
            "same camera distance as ryan and toby",
            "flat solid #00ff00",
            "128x160",
            "512x640",
            "fewer fine vertical lines",
            "not a polished fashion illustration",
        ):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "Mira rebalance manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "mira_rebalance_bust_portraits")
        self.assertEqual(manifest.get("style_profile"), STYLE_PROFILE)
        self.assertEqual(manifest.get("source"), RAW.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("prompt"), PROMPT.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("native_size"), list(NATIVE_SIZE))
        self.assertEqual(manifest.get("runtime_size"), list(RUNTIME_SIZE))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("grid"), {"columns": 4, "rows": 2})
        self.assertEqual(sorted(manifest.get("portraits", {}).keys()), sorted(PORTRAITS))
        with Image.open(RAW) as source:
            cell_width = source.width // 4
            cell_height = source.height // 2
        for index, portrait_id in enumerate(PORTRAITS):
            rect = manifest["portraits"][portrait_id]["source_rect"]
            row = index // 4
            column = index % 4
            strict_left = column * cell_width
            strict_right = (column + 1) * cell_width
            strict_top = row * cell_height
            strict_bottom = (row + 1) * cell_height
            self.assertLessEqual(rect[0], strict_left, f"{portrait_id} source crop should include left bleed when available")
            self.assertGreaterEqual(rect[2], strict_right, f"{portrait_id} source crop should include right bleed when available")
            self.assertEqual(rect[1], strict_top)
            self.assertEqual(rect[3], strict_bottom)
            if column > 0:
                self.assertLess(rect[0], strict_left, f"{portrait_id} should borrow left bleed from adjacent cell")
            if column < 3:
                self.assertGreater(rect[2], strict_right, f"{portrait_id} should borrow right bleed from adjacent cell")

    def test_native_and_runtime_exports(self) -> None:
        for portrait_id in PORTRAITS:
            native_path = SOURCE_DIR / f"{portrait_id}_native.png"
            runtime_path = RUNTIME_DIR / f"{portrait_id}.png"
            self.assertTrue(native_path.exists(), f"{portrait_id} native source is missing")
            self.assertTrue(runtime_path.exists(), f"{portrait_id} runtime texture is missing")
            native = load_rgba(native_path)
            runtime = load_rgba(runtime_path)
            self.assertEqual(native.size, NATIVE_SIZE)
            self.assertEqual(runtime.size, RUNTIME_SIZE)
            expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
            self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{portrait_id} runtime must be exact 4x nearest export")
            self.assertGreater(visible_pixel_count(native), 3000, f"{portrait_id} has too few visible pixels")
            self.assertLessEqual(unique_visible_colors(native), COLOR_LIMIT, f"{portrait_id} exceeds color budget")
            self.assertEqual(green_key_fringe_pixels(native), 0, f"{portrait_id} has green chroma-key fringe")
            self.assertLessEqual(
                second_largest_alpha_component(native),
                16,
                f"{portrait_id} has a detached silhouette fragment",
            )

            left, top, right, bottom = visible_bounds(native)
            self.assertGreaterEqual(bottom - top, 138, f"{portrait_id} visible figure is too short")
            self.assertLessEqual(bottom - top, 154, f"{portrait_id} visible figure is too tall")
            self.assertLessEqual(right - left, 124, f"{portrait_id} visible figure is too wide")
            bottom_padding = native.height - bottom
            self.assertGreaterEqual(bottom_padding, 2, f"{portrait_id} touches bottom edge")
            self.assertLessEqual(bottom_padding, 5, f"{portrait_id} floats too high")
            self.assertLessEqual(
                abs(left - (native.width - right)),
                16,
                f"{portrait_id} is horizontally off-center after crop normalization",
            )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "Mira rebalance contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertEqual(contact.size, CONTACT_SHEET_SIZE, "Mira rebalance sheet should use a 4x2 preview")


if __name__ == "__main__":
    unittest.main(verbosity=2)
