from __future__ import annotations

import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
CHARACTER_NATIVE_DIRS = [
    ROOT / "assets" / "source" / "tavern" / "characters",
    ROOT / "assets" / "source" / "tavern" / "characters" / "vera",
    ROOT / "assets" / "source" / "tavern" / "regular_customers",
]


def native_paths() -> list[Path]:
    paths: list[Path] = []
    for directory in CHARACTER_NATIVE_DIRS:
        paths.extend(sorted(directory.glob("*_native.png")))
    return paths


def is_alpha_boundary_pixel(image: Image.Image, x: int, y: int) -> bool:
    if image.getpixel((x, y))[3] == 0:
        return False
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            xx = x + dx
            yy = y + dy
            if 0 <= xx < image.width and 0 <= yy < image.height and image.getpixel((xx, yy))[3] == 0:
                return True
    return False


def is_dark_green_screen_fringe(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and green >= 24 and green > red + 6 and green > blue + 4


def is_bright_green_screen_pixel(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and green >= 170 and red <= 96 and blue <= 96 and green > max(red, blue) + 80


def flattened_pixels(image: Image.Image):
    if hasattr(image, "get_flattened_data"):
        return image.get_flattened_data()
    return image.getdata()


class CharacterGreenSpillPipelineTest(unittest.TestCase):
    def test_character_native_alpha_edges_have_no_dark_green_screen_fringe(self) -> None:
        paths = native_paths()
        self.assertGreater(paths, [], "expected exported character native images")
        offenders: dict[str, int] = {}
        for path in paths:
            with Image.open(path) as source:
                image = source.convert("RGBA")
            count = 0
            for y in range(image.height):
                for x in range(image.width):
                    if is_alpha_boundary_pixel(image, x, y) and is_dark_green_screen_fringe(image.getpixel((x, y))):
                        count += 1
            if count:
                offenders[path.relative_to(ROOT).as_posix()] = count

        self.assertEqual(offenders, {}, "character alpha edges still contain dark green-screen spill")

    def test_character_native_images_have_no_visible_bright_green_screen_pixels(self) -> None:
        paths = native_paths()
        self.assertGreater(paths, [], "expected exported character native images")
        offenders: dict[str, int] = {}
        for path in paths:
            with Image.open(path) as source:
                image = source.convert("RGBA")
            count = 0
            for pixel in flattened_pixels(image):
                if is_bright_green_screen_pixel(pixel):
                    count += 1
            if count:
                offenders[path.relative_to(ROOT).as_posix()] = count

        self.assertEqual(offenders, {}, "character native images still contain visible bright green-screen pixels")


if __name__ == "__main__":
    unittest.main(verbosity=2)
