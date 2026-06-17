from __future__ import annotations

import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MENU_BRUSH_SOURCE = ROOT / "assets" / "source" / "ui" / "menu_brush_components_approved.png"
MENU_BRUSH_BAND = ROOT / "assets" / "textures" / "ui" / "menu_brush_band.png"
TAVERN_VIEW = ROOT / "scripts" / "ui" / "tavern_view.gd"


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    raw = image.tobytes()
    return [tuple(raw[index:index + 4]) for index in range(0, len(raw), 4) if raw[index + 3] > 0]


class RecipeDiscoveryBrushNoticeTest(unittest.TestCase):
    def test_notice_uses_existing_menu_brush_asset_family(self) -> None:
        self.assertTrue(MENU_BRUSH_SOURCE.exists(), f"{MENU_BRUSH_SOURCE}: missing approved menu brush source sheet")
        self.assertTrue(MENU_BRUSH_BAND.exists(), f"{MENU_BRUSH_BAND}: missing runtime menu brush band")
        source = load_rgba(MENU_BRUSH_SOURCE)
        band = load_rgba(MENU_BRUSH_BAND)
        self.assertEqual(source.size, (1536, 1024))
        self.assertEqual(band.size, (320, 56))
        visible = visible_pixels(band)
        self.assertGreater(len(visible), 6_000, "menu brush band cannot be visually sparse")
        dark_teal = sum(1 for r, g, b, a in visible if a > 0 and r <= 40 and 25 <= g <= 95 and 35 <= b <= 110)
        self.assertGreaterEqual(dark_teal, 3_500, "notice backing should read as the existing dark teal brush UI")

    def test_tavern_notice_references_brush_band_not_generated_paper(self) -> None:
        source = TAVERN_VIEW.read_text(encoding="utf-8")
        self.assertIn('RECIPE_DISCOVERY_BRUSH_ART := "res://assets/textures/ui/menu_brush_band.png"', source)
        self.assertNotIn("res://assets/textures/ui/recipe_discovery/recipe_note.png", source)
        self.assertIn('notice.name = "RecipeDiscoveryNotice"', source)
        self.assertIn('brush.name = "BrushBand"', source)
        self.assertIn("RECIPE_DISCOVERY_NOTICE_SIZE := Vector2(480.0, 104.0)", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
