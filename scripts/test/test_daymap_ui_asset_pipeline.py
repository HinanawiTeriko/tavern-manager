from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "assets" / "source" / "daymap" / "reference"
SOURCE = ROOT / "assets" / "source" / "daymap" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "ui"
GENERATED_RAW = ROOT / "art_sources" / "generated_raw" / "daymap"
NATIVE_SIZE = (70, 18)
RUNTIME_SIZE = (280, 72)
LEDGER_NATIVE_SIZE = (66, 22)
LEDGER_RUNTIME_SIZE = (132, 44)
DETAIL_PANEL_NATIVE_SIZE = (80, 120)
DETAIL_PANEL_RUNTIME_SIZE = (320, 480)
DETAIL_GO_BUTTON_NATIVE_SIZE = (56, 14)
DETAIL_GO_BUTTON_RUNTIME_SIZE = (224, 56)
RESULT_PANEL_NATIVE_SIZE = (175, 100)
RESULT_PANEL_RUNTIME_SIZE = (700, 400)
TAB_NATIVE_SIZE = (36, 12)
TAB_RUNTIME_SIZE = (144, 48)
SHOP_SQUARE_NATIVE_SIZE = (9, 9)
SHOP_SQUARE_RUNTIME_SIZE = (36, 36)
SHOP_STEPPER_ICON_NATIVE_SIZE = (9, 9)
SHOP_STEPPER_ICON_RUNTIME_SIZE = (36, 36)
SHOP_WIDE_NATIVE_SIZE = (18, 9)
SHOP_WIDE_RUNTIME_SIZE = (72, 36)
SHOP_PANEL_NATIVE_SIZE = (250, 84)
SHOP_PANEL_RUNTIME_SIZE = (1000, 336)
SHOP_BACKDROP_NATIVE_SIZE = (320, 180)
SHOP_BACKDROP_RUNTIME_SIZE = (1280, 720)
DOCUMENT_PANEL_NATIVE_SIZE = (155, 135)
DOCUMENT_PANEL_RUNTIME_SIZE = (620, 540)
SCROLL_TRACK_NATIVE_SIZE = (4, 80)
SCROLL_TRACK_RUNTIME_SIZE = (16, 320)
SCROLL_GRABBER_NATIVE_SIZE = (4, 16)
SCROLL_GRABBER_RUNTIME_SIZE = (16, 64)
TOPBAR_NATIVE_SIZE = (320, 15)
TOPBAR_RUNTIME_SIZE = (1280, 60)
PINNED_NOTE_PANEL_NATIVE_SIZE = (92, 96)
PINNED_NOTE_PANEL_RUNTIME_SIZE = (368, 384)
PINNED_NOTE_KNIFE_NATIVE_SIZE = (28, 28)
PINNED_NOTE_KNIFE_RUNTIME_SIZE = (112, 112)
PINNED_DETAIL_PANEL_NATIVE_SIZE = (92, 96)
PINNED_DETAIL_PANEL_RUNTIME_SIZE = (368, 384)
GATHERING_TOAST_PANEL_NATIVE_SIZE = (105, 14)
GATHERING_TOAST_PANEL_RUNTIME_SIZE = (420, 56)
PINNED_NOTE_CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "daymap_pinned_note_contact_sheet.png"
NOTE_ACTION_CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "daymap_note_action_button_contact_sheet.png"
DETAIL_PANEL_CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "daymap_detail_panel_contact_sheet.png"
GATHERING_TOAST_CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "daymap_gathering_toast_contact_sheet.png"
RESULT_PANEL_CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "daymap_result_panel_contact_sheet.png"
LEDGER_BUTTON_CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "daymap_ledger_button_states_contact_sheet.png"
DAYMAP_UI_MANIFEST = SOURCE / "daymap_ui_manifest.json"
TOPBAR_DESKTOP_SOURCE = GENERATED_RAW / "topbar_desktop_source.png"
TOPBAR_SOURCE_CROP = [14, 557, 1240, 698]
PINNED_NOTE_PIERCED_SOURCE = GENERATED_RAW / "pinned_note_pierced_source.png"
PINNED_NOTE_PANEL_CROP = [80, 60, 1120, 1148]
PINNED_NOTE_KNIFE_CROP = [80, 60, 520, 540]
NOTE_ACTION_PAPER_STAMP_SOURCE = GENERATED_RAW / "note_action_paper_stamp_source.png"
DETAIL_PANEL_PINNED_SOURCE = GENERATED_RAW / "detail_panel_pinned_notice_source_v1.png"
DETAIL_PANEL_PINNED_PROMPT = GENERATED_RAW / "detail_panel_pinned_notice_prompt_v1.txt"
DETAIL_PANEL_SOURCE_CROP = [72, 44, 966, 1492]
PINNED_DETAIL_PANEL_SOURCE = GENERATED_RAW / "pinned_note_detail_panel_source_v2.png"
PINNED_DETAIL_PANEL_PROMPT = GENERATED_RAW / "pinned_note_detail_panel_prompt_v2.txt"
PINNED_DETAIL_PANEL_CROP = [100, 52, 1188, 1136]
DETAIL_GO_BUTTON_STATES_SOURCE = GENERATED_RAW / "detail_go_button_states_source_v3.png"
DETAIL_GO_BUTTON_STATES_PROMPT = GENERATED_RAW / "detail_go_button_states_prompt_v3.txt"
GATHERING_TOAST_PANEL_SOURCE = GENERATED_RAW / "gathering_toast_panel_source_v2.png"
GATHERING_TOAST_PANEL_PROMPT = GENERATED_RAW / "gathering_toast_panel_prompt_v2.txt"
SPECIAL_RESULT_PANEL_SOURCE = GENERATED_RAW / "special_result_panel_source_v1.png"
SPECIAL_RESULT_PANEL_PROMPT = GENERATED_RAW / "special_result_panel_prompt_v1.txt"
LEDGER_BUTTON_STATES_SOURCE = GENERATED_RAW / "daymap_ledger_button_states_source_v1.png"
LEDGER_BUTTON_STATES_PROMPT = GENERATED_RAW / "daymap_ledger_button_states_prompt_v1.txt"
LEDGER_UNREAD_BUTTON_STATES_SOURCE = GENERATED_RAW / "daymap_ledger_unread_button_states_source_v1.png"
LEDGER_UNREAD_BUTTON_STATES_PROMPT = GENERATED_RAW / "daymap_ledger_unread_button_states_prompt_v1.txt"
NOTE_ACTION_NATIVE_SIZE = (56, 14)
NOTE_ACTION_RUNTIME_SIZE = (224, 56)
NOTE_ACTION_CROPS = {
    "normal": [165, 111, 1089, 358],
    "hover": [165, 501, 1089, 748],
    "pressed": [165, 892, 1089, 1141],
}
LEDGER_BUTTON_CROPS = {
    "normal": [190, 100, 1064, 360],
    "hover": [190, 500, 1064, 760],
    "pressed": [190, 895, 1064, 1155],
}
DETAIL_GO_BUTTON_CROPS = {
    "normal": [60, 195, 975, 429],
    "hover": [60, 630, 975, 864],
    "pressed": [60, 1064, 975, 1298],
}
GATHERING_TOAST_PANEL_CROP = [50, 552, 1200, 705]
SPECIAL_RESULT_PANEL_CROP = [0, 0, 1659, 930]
STATES = ["normal", "hover", "pressed"]
TAB_STATES = ["normal", "selected"]
SHOP_ATLAS_REFERENCE = REFERENCE / "daymap_ui_shop_atlas_reference_v3_generated.png"
SHOP_BUTTONS_REFERENCE = REFERENCE / "daymap_ui_shop_buttons_reference_v2_generated.png"
SHOP_STEPPER_ICONS_REFERENCE = REFERENCE / "daymap_ui_shop_stepper_icons_reference_v1_generated.png"
PANELS_REFERENCE = REFERENCE / "daymap_ui_panels_reference_v2_generated.png"
SHOP_REDESIGN_SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_redesign"
SHOP_REDESIGN_RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_redesign"
SHOP_MASTER_REFERENCE = SHOP_REDESIGN_SOURCE / "reference" / "shop_master_composition_generated.png"
SHOP_CLEAN_REFERENCE = SHOP_REDESIGN_SOURCE / "reference" / "shop_clean_background_reference.png"
SHOP_SCENE_NATIVE_SIZE = (320, 180)
SHOP_SCENE_RUNTIME_SIZE = (1280, 720)
SHOP_BOOK_NATIVE_SIZE = (248, 104)
SHOP_BOOK_RUNTIME_SIZE = (992, 416)
SHOP_BOOKMARK_NATIVE_SIZE = (36, 16)
SHOP_BOOKMARK_RUNTIME_SIZE = (144, 64)
SHOP_ITEM_ROW_NATIVE_SIZE = (116, 18)
SHOP_ITEM_ROW_RUNTIME_SIZE = (464, 72)
SHOP_SEAL_NATIVE_SIZE = (64, 18)
SHOP_SEAL_RUNTIME_SIZE = (256, 72)
SHOP_TAG_NATIVE_SIZE = (44, 18)
SHOP_TAG_RUNTIME_SIZE = (176, 72)
SHOP_QUANTITY_NATIVE_SIZE = (72, 18)
SHOP_QUANTITY_RUNTIME_SIZE = (288, 72)
SHOP_STATUS_NATIVE_SIZE = (40, 14)
SHOP_STATUS_RUNTIME_SIZE = (160, 56)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def writable_parchment_pixel_count(image: Image.Image) -> int:
    return sum(
        1 for red, green, blue, alpha in image.get_flattened_data()
        if alpha >= 200 and 110 <= red <= 220 and 70 <= green <= 170 and 35 <= blue <= 125
    )


def overheated_orange_pixel_count(image: Image.Image) -> int:
    return sum(
        1 for red, green, blue, alpha in image.get_flattened_data()
        if alpha >= 180 and red >= 150 and 55 <= green <= 150 and blue <= 90 and red > green * 1.25
    )


def muted_map_parchment_pixel_count(image: Image.Image) -> int:
    return sum(
        1 for red, green, blue, alpha in image.get_flattened_data()
        if (
            alpha >= 180
            and 85 <= red <= 180
            and 60 <= green <= 140
            and 35 <= blue <= 105
            and red >= green
            and red - green <= 55
            and green - blue <= 55
        )
    )


def unsupported_alpha_pixel_count(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    unsupported = 0
    for y in range(alpha.height):
        for x in range(alpha.width):
            if pixels[x, y] == 0:
                continue
            support = 0
            for neighbor_y in range(max(0, y - 1), min(alpha.height, y + 2)):
                for neighbor_x in range(max(0, x - 1), min(alpha.width, x + 2)):
                    if neighbor_x == x and neighbor_y == y:
                        continue
                    if pixels[neighbor_x, neighbor_y] > 0:
                        support += 1
            if support <= 1:
                unsupported += 1
    return unsupported


def alpha_bbox_fill_ratio(image: Image.Image) -> tuple[float, float]:
    box = image.getchannel("A").getbbox()
    if box is None:
        return (0.0, 0.0)
    left, top, right, bottom = box
    return ((right - left) / image.width, (bottom - top) / image.height)


def alpha_edge_visible_counts(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    width, height = alpha.size
    left = sum(1 for y in range(height) if pixels[0, y] > 0)
    right = sum(1 for y in range(height) if pixels[width - 1, y] > 0)
    top = sum(1 for x in range(width) if pixels[x, 0] > 0)
    bottom = sum(1 for x in range(width) if pixels[x, height - 1] > 0)
    return (left, right, top, bottom)


def long_horizontal_line_pixels(image: Image.Image) -> int:
    pixels = image.load()
    width, height = image.size
    total = 0
    for y in range(height):
        run = 0
        for x in range(width):
            r, g, b, a = pixels[x, y]
            is_guide_pixel = 45 <= a <= 140 and 130 <= r <= 185 and 80 <= g <= 140 and 45 <= b <= 100
            if is_guide_pixel:
                run += 1
            else:
                if run >= 18:
                    total += run
                run = 0
        if run >= 18:
            total += run
    return total


def internal_horizontal_mark_count(image: Image.Image) -> int:
    pixels = image.load()
    width, height = image.size
    total = 0
    for y in range(14, height - 14):
        run = 0
        for x in range(12, width - 12):
            r, g, b, a = pixels[x, y]
            is_faint_body_mark = 45 <= a <= 180 and 80 <= r <= 190 and 45 <= g <= 140 and 25 <= b <= 105
            if is_faint_body_mark:
                run += 1
            else:
                if run >= 3:
                    total += 1
                run = 0
        if run >= 3:
            total += 1
    return total


def semi_transparent_body_pixel_count(image: Image.Image) -> int:
    pixels = image.load()
    width, height = image.size
    count = 0
    for y in range(14, height - 14):
        for x in range(12, width - 12):
            alpha = pixels[x, y][3]
            if 0 < alpha < 255:
                count += 1
    return count


def compact_amber_light_clusters(image: Image.Image) -> int:
    pixels = image.load()
    width, height = image.size
    visited = bytearray(width * height)
    clusters = 0

    for start_y in range(height):
        for start_x in range(width):
            offset = start_y * width + start_x
            if visited[offset]:
                continue
            visited[offset] = 1
            red, green, blue, alpha = pixels[start_x, start_y]
            if not (alpha >= 170 and red >= 185 and 70 <= green <= 175 and blue <= 90):
                continue

            stack = [(start_x, start_y)]
            count = 0
            min_x = max_x = start_x
            min_y = max_y = start_y
            while stack:
                x, y = stack.pop()
                count += 1
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or nx >= width or ny < 0 or ny >= height:
                        continue
                    next_offset = ny * width + nx
                    if visited[next_offset]:
                        continue
                    red, green, blue, alpha = pixels[nx, ny]
                    if alpha >= 170 and red >= 185 and 70 <= green <= 175 and blue <= 90:
                        visited[next_offset] = 1
                        stack.append((nx, ny))

            cluster_width = max_x - min_x + 1
            cluster_height = max_y - min_y + 1
            if 3 <= cluster_width <= 20 and cluster_height >= 3 and count >= 8:
                clusters += 1

    return clusters


def assert_exact_native_export(
    test_case: unittest.TestCase,
    native_path: Path,
    runtime_path: Path,
    native_size: tuple[int, int],
    runtime_size: tuple[int, int],
) -> Image.Image:
    test_case.assertTrue(native_path.exists(), f"{native_path}: missing native source")
    test_case.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
    native = load_rgba(native_path)
    runtime = load_rgba(runtime_path)
    test_case.assertEqual(native.size, native_size, f"{native_path.name}: wrong native size")
    test_case.assertEqual(runtime.size, runtime_size, f"{runtime_path.name}: wrong runtime size")
    test_case.assertGreater(visible_pixel_count(native), 0, f"{native_path.name}: has no visible pixels")
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_path.name}: not exact nearest export")
    return native


class DayMapUiAssetPipelineTest(unittest.TestCase):
    def test_daymap_ui_exporter_uses_references_and_native_constructors(self) -> None:
        source = (ROOT / "scripts" / "tools" / "export_daymap_ui_assets.py").read_text(encoding="utf-8")
        self.assertNotIn("ImageDraw", source, "DayMap UI assets must come from generated or artist source sheets")
        self.assertNotIn("draw_button", source, "DayMap UI buttons must not be procedurally drawn")
        self.assertNotIn("draw_panel", source, "DayMap UI panels must not be procedurally drawn")
        self.assertNotIn("make_shop_backdrop_native", source, "shop backdrop must be normalized from retained reference art")
        self.assertNotIn("make_shop_panel_native", source, "shop panel must be normalized from retained reference art")
        self.assertNotIn("make_shop_square_button_native", source, "shop square buttons must be normalized from retained reference art")
        self.assertNotIn("make_shop_wide_button_native", source, "shop wide buttons must be normalized from retained reference art")
        self.assertNotIn("make_shop_stepper_icon_native", source, "shop stepper icons must be normalized from retained reference art")
        self.assertNotIn("make_scroll_track_native", source, "shop scrollbar track must be normalized from retained reference art")
        self.assertNotIn("make_scroll_grabber_native", source, "shop scrollbar grabber must be normalized from retained reference art")
        self.assertIn("REFERENCE", source, "DayMap UI exporter must consume retained reference art")
        self.assertIn("SHOP_ATLAS_REFERENCE", source, "shop backdrop must keep its generated reference art")
        self.assertIn("SHOP_BUTTONS_REFERENCE", source, "shop buttons must consume retained reference art")
        self.assertIn("SHOP_STEPPER_ICONS_REFERENCE", source, "shop stepper icons must keep generated reference art")
        self.assertIn("PANELS_REFERENCE", source, "shop panel and scrollbar must consume retained panel reference art")
        self.assertIn("TOPBAR_DESKTOP_SOURCE", source, "topbar must consume retained AI source art")
        self.assertIn("PINNED_NOTE_PIERCED_SOURCE", source, "pinned note must consume retained AI source art")
        self.assertIn("PINNED_DETAIL_PANEL_SOURCE", source, "active pinned detail panel must consume retained AI source art")
        self.assertIn("NOTE_ACTION_PAPER_STAMP_SOURCE", source, "note action button must consume retained AI source art")
        self.assertIn("DETAIL_GO_BUTTON_STATES_SOURCE", source, "detail go button must consume retained AI state art")
        self.assertIn("LEDGER_BUTTON_STATES_SOURCE", source, "ledger button must consume retained AI state art")
        self.assertIn("LEDGER_UNREAD_BUTTON_STATES_SOURCE", source, "ledger unread button must consume retained AI state art")
        self.assertIn("LEDGER_UNREAD_BUTTON_STATES_PROMPT", source, "ledger unread button must keep its prompt record")
        self.assertIn("SPECIAL_RESULT_PANEL_SOURCE", source, "special result panel must consume retained AI source art")
        self.assertNotIn("def make_ledger_button_native", source, "ledger button must not be procedurally drawn")
        self.assertNotIn("make_pinned_note_panel_native", source, "pinned note must be normalized from retained AI source art")
        self.assertNotIn("make_pinned_note_knife_native", source, "knife pin must be normalized from retained AI source art")
        self.assertIn("make_primary_button_native", source, "primary button must use a deterministic native-pixel constructor")

    def test_shop_reference_sources_are_retained(self) -> None:
        for path in [SHOP_ATLAS_REFERENCE, SHOP_BUTTONS_REFERENCE, SHOP_STEPPER_ICONS_REFERENCE, PANELS_REFERENCE]:
            with self.subTest(path=path.name):
                self.assertTrue(path.exists(), f"{path}: missing retained generated reference art")
                self.assertGreater(path.stat().st_size, 0, f"{path}: retained reference art is empty")

    def test_pinned_note_ai_source_is_retained(self) -> None:
        self.assertTrue(
            PINNED_NOTE_PIERCED_SOURCE.exists(),
            f"{PINNED_NOTE_PIERCED_SOURCE}: missing retained AI source art",
        )
        self.assertGreater(
            PINNED_NOTE_PIERCED_SOURCE.stat().st_size,
            0,
            f"{PINNED_NOTE_PIERCED_SOURCE}: retained AI source art is empty",
        )

    def test_pinned_detail_panel_ai_source_is_retained(self) -> None:
        for path in [PINNED_DETAIL_PANEL_SOURCE, PINNED_DETAIL_PANEL_PROMPT]:
            with self.subTest(path=path.name):
                self.assertTrue(path.exists(), f"{path}: missing retained AI pinned detail source")
                self.assertGreater(path.stat().st_size, 0, f"{path}: retained pinned detail source is empty")

    def test_topbar_desktop_ai_source_is_retained(self) -> None:
        self.assertTrue(
            TOPBAR_DESKTOP_SOURCE.exists(),
            f"{TOPBAR_DESKTOP_SOURCE}: missing retained AI source art",
        )
        self.assertGreater(
            TOPBAR_DESKTOP_SOURCE.stat().st_size,
            0,
            f"{TOPBAR_DESKTOP_SOURCE}: retained AI source art is empty",
        )

    def test_note_action_paper_stamp_ai_source_is_retained(self) -> None:
        self.assertTrue(
            NOTE_ACTION_PAPER_STAMP_SOURCE.exists(),
            f"{NOTE_ACTION_PAPER_STAMP_SOURCE}: missing retained AI source art",
        )
        self.assertGreater(
            NOTE_ACTION_PAPER_STAMP_SOURCE.stat().st_size,
            0,
            f"{NOTE_ACTION_PAPER_STAMP_SOURCE}: retained AI source art is empty",
        )

    def test_ledger_button_ai_state_source_is_retained(self) -> None:
        for path in [
            LEDGER_BUTTON_STATES_SOURCE,
            LEDGER_BUTTON_STATES_PROMPT,
            LEDGER_UNREAD_BUTTON_STATES_SOURCE,
            LEDGER_UNREAD_BUTTON_STATES_PROMPT,
        ]:
            with self.subTest(path=path.name):
                self.assertTrue(path.exists(), f"{path}: missing retained AI ledger button source")
                self.assertGreater(path.stat().st_size, 0, f"{path}: retained ledger button source is empty")

    def test_special_result_panel_ai_source_is_retained(self) -> None:
        for path in [SPECIAL_RESULT_PANEL_SOURCE, SPECIAL_RESULT_PANEL_PROMPT]:
            with self.subTest(path=path.name):
                self.assertTrue(path.exists(), f"{path}: missing retained AI special result panel source")
                self.assertGreater(path.stat().st_size, 0, f"{path}: retained special result panel source is empty")

    def test_shop_redesign_reference_source_is_retained(self) -> None:
        self.assertTrue(
            SHOP_MASTER_REFERENCE.exists(),
            f"{SHOP_MASTER_REFERENCE}: missing retained generated master composition art",
        )
        self.assertGreater(
            SHOP_MASTER_REFERENCE.stat().st_size,
            0,
            f"{SHOP_MASTER_REFERENCE}: master composition art is empty",
        )
        self.assertTrue(
            SHOP_CLEAN_REFERENCE.exists(),
            f"{SHOP_CLEAN_REFERENCE}: missing retained clean background reference art",
        )
        self.assertGreater(
            SHOP_CLEAN_REFERENCE.stat().st_size,
            0,
            f"{SHOP_CLEAN_REFERENCE}: clean background art is empty",
        )

    def test_shop_redesign_exporter_uses_reference_art(self) -> None:
        source = (ROOT / "scripts" / "tools" / "export_daymap_shop_redesign_assets.py").read_text(encoding="utf-8")
        self.assertIn("SHOP_MASTER_REFERENCE", source, "shop redesign exporter must retain and consume the master composition")
        self.assertIn("SHOP_CLEAN_REFERENCE", source, "shop redesign exporter must retain and consume the clean background reference")
        self.assertIn("CLEAN_LAYER_SPECS", source, "shop redesign assets must be derived as clean scene/UI layers")
        self.assertIn("crop_reference", source, "shop redesign exporter must crop from the generated master composition")
        self.assertIn("paint_layer", source, "shop redesign row/bookmark states must be deterministic paint layers")
        self.assertIn("button_layer", source, "shop redesign bottom controls must be deterministic button layers")
        self.assertNotIn("\"diff\"", source, "shop redesign interaction UI must not rely on clean-plate diff modes")
        self.assertNotIn("clean_pixels", source, "shop redesign interaction UI must not rely on clean-plate pixel differencing")
        self.assertNotIn("ensure_clean_reference", source, "shop redesign exporter must not rewrite the retained clean plate")
        self.assertNotIn("make_clean_native", source, "shop clean plate must be authored/retained, not synthesized from the master")
        self.assertNotIn("patch_from_neighbor", source, "shop clean plate must not be generated by neighbor patching")
        self.assertNotIn(".save(SHOP_CLEAN_REFERENCE", source, "shop exporter must not overwrite the clean reference")
        self.assertNotIn("SHOP_PIECES_REFERENCE", source, "shop redesign exporter must not depend on a separately generated UI pieces sheet")
        self.assertNotIn("ImageDraw", source, "shop redesign core UI must not be procedurally rectangle-drawn")
        self.assertNotIn("rectangle(", source, "shop redesign core UI must not be built from drawn rectangles")

    def test_shop_redesign_quantity_control_is_not_abacus(self) -> None:
        source = (ROOT / "scripts" / "tools" / "export_daymap_shop_redesign_assets.py").read_text(encoding="utf-8")
        self.assertNotIn("quantity_abacus", source, "shop quantity control must no longer use abacus naming or extraction")
        self.assertIn("quantity_control", source, "shop quantity control should use generic plus/count/minus naming")

    def test_shop_redesign_keeps_front_facing_text_zones(self) -> None:
        scene = load_rgba(SHOP_REDESIGN_RUNTIME / "shop_scene.png")
        native = scene.resize((320, 180), Image.Resampling.NEAREST)
        row_zone = native.crop((68, 70, 162, 139)).convert("RGBA")
        detail_zone = native.crop((166, 66, 282, 139)).convert("RGBA")
        self.assertGreaterEqual(
            writable_parchment_pixel_count(row_zone),
            3500,
            "front-facing item row zone lost too much writable parchment area",
        )
        self.assertGreaterEqual(
            writable_parchment_pixel_count(detail_zone),
            5000,
            "front-facing detail zone lost too much writable parchment area",
        )

    def test_shop_redesign_assets_are_exact_native_exports(self) -> None:
        cases = [
            ("shop_scene", SHOP_SCENE_NATIVE_SIZE, SHOP_SCENE_RUNTIME_SIZE),
            ("shop_book", SHOP_BOOK_NATIVE_SIZE, SHOP_BOOK_RUNTIME_SIZE),
            ("bookmark_materials_normal", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
            ("bookmark_materials_selected", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
            ("bookmark_recipes_normal", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
            ("bookmark_recipes_selected", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
            ("bookmark_abilities_normal", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
            ("bookmark_abilities_selected", SHOP_BOOKMARK_NATIVE_SIZE, SHOP_BOOKMARK_RUNTIME_SIZE),
            ("item_row_normal", SHOP_ITEM_ROW_NATIVE_SIZE, SHOP_ITEM_ROW_RUNTIME_SIZE),
            ("item_row_selected", SHOP_ITEM_ROW_NATIVE_SIZE, SHOP_ITEM_ROW_RUNTIME_SIZE),
            ("item_row_disabled", SHOP_ITEM_ROW_NATIVE_SIZE, SHOP_ITEM_ROW_RUNTIME_SIZE),
            ("purchase_seal_normal", SHOP_SEAL_NATIVE_SIZE, SHOP_SEAL_RUNTIME_SIZE),
            ("purchase_seal_pressed", SHOP_SEAL_NATIVE_SIZE, SHOP_SEAL_RUNTIME_SIZE),
            ("purchase_seal_disabled", SHOP_SEAL_NATIVE_SIZE, SHOP_SEAL_RUNTIME_SIZE),
            ("close_tag_normal", SHOP_TAG_NATIVE_SIZE, SHOP_TAG_RUNTIME_SIZE),
            ("close_tag_selected", SHOP_TAG_NATIVE_SIZE, SHOP_TAG_RUNTIME_SIZE),
            ("quantity_control", SHOP_QUANTITY_NATIVE_SIZE, SHOP_QUANTITY_RUNTIME_SIZE),
            ("status_owned", SHOP_STATUS_NATIVE_SIZE, SHOP_STATUS_RUNTIME_SIZE),
            ("status_discount", SHOP_STATUS_NATIVE_SIZE, SHOP_STATUS_RUNTIME_SIZE),
        ]
        for name, native_size, runtime_size in cases:
            with self.subTest(name=name):
                assert_exact_native_export(
                    self,
                    SHOP_REDESIGN_SOURCE / f"{name}_native.png",
                    SHOP_REDESIGN_RUNTIME / f"{name}.png",
                    native_size,
                    runtime_size,
                )

    def test_shop_redesign_assets_have_integrated_scene_materials(self) -> None:
        scene = load_rgba(SHOP_REDESIGN_SOURCE / "shop_scene_native.png")
        pixels = list(scene.get_flattened_data())
        teal_shadow = sum(
            1 for r, g, b, a in pixels
            if a >= 220 and 5 <= r <= 50 and 18 <= g <= 78 and 18 <= b <= 85
        )
        amber_light = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and r >= 145 and 60 <= g <= 175 and b <= 95
        )
        wood_counter = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and 45 <= r <= 145 and 25 <= g <= 95 and 12 <= b <= 65
        )
        parchment = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and 110 <= r <= 220 and 70 <= g <= 170 and 35 <= b <= 120
        )
        visible_colors = {
            (r, g, b)
            for r, g, b, a in pixels
            if a >= 200
        }
        self.assertGreaterEqual(teal_shadow, 2600, "shop scene needs dark teal underground shadow mass")
        self.assertGreaterEqual(amber_light, 180, "shop scene needs sparse amber stall light")
        self.assertGreaterEqual(wood_counter, 1700, "shop scene needs wooden counter/stall pixels")
        self.assertGreaterEqual(parchment, 5200, "shop scene needs readable ledger parchment area")
        self.assertGreaterEqual(len(visible_colors), 24, "shop scene needs enough tonal variation to sit with title art")

    def test_shop_redesign_interaction_assets_are_not_flat_rectangles(self) -> None:
        cases = [
            "bookmark_materials_normal",
            "item_row_normal",
            "item_row_selected",
            "purchase_seal_normal",
            "close_tag_normal",
            "quantity_control",
            "status_owned",
            "status_discount",
        ]
        for name in cases:
            with self.subTest(name=name):
                native = load_rgba(SHOP_REDESIGN_SOURCE / f"{name}_native.png")
                pixels = list(native.get_flattened_data())
                visible_colors = {
                    (r, g, b)
                    for r, g, b, a in pixels
                    if a >= 120
                }
                amber = sum(
                    1 for r, g, b, a in pixels
                    if a >= 160 and r >= 145 and 55 <= g <= 175 and b <= 100
                )
                dark = sum(
                    1 for r, g, b, a in pixels
                    if a >= 160 and r <= 70 and 18 <= g <= 90 and 15 <= b <= 90
                )
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, f"{name}: needs transparent edge pixels, not a full opaque scene crop")
                self.assertGreater(alpha_max, 0, f"{name}: has no visible pixels")
                self.assertGreaterEqual(len(visible_colors), 8, f"{name}: too few colors; looks like a flat rectangle")
                self.assertGreaterEqual(amber + dark, 8, f"{name}: needs scene-material accent/shadow pixels")

    def test_shop_redesign_interaction_layers_have_supported_alpha_shapes(self) -> None:
        cases = [
            "bookmark_materials_normal",
            "bookmark_materials_selected",
            "bookmark_recipes_normal",
            "bookmark_recipes_selected",
            "bookmark_abilities_normal",
            "bookmark_abilities_selected",
            "purchase_seal_normal",
            "purchase_seal_pressed",
            "purchase_seal_disabled",
            "close_tag_normal",
            "close_tag_selected",
            "quantity_control",
            "status_owned",
            "status_discount",
        ]
        for name in cases:
            with self.subTest(name=name):
                native = load_rgba(SHOP_REDESIGN_SOURCE / f"{name}_native.png")
                visible = visible_pixel_count(native)
                self.assertGreaterEqual(visible, native.width * native.height // 14, f"{name}: extraction is too sparse")
                self.assertEqual(
                    unsupported_alpha_pixel_count(native),
                    0,
                    f"{name}: contains isolated or dangling alpha pixels from dirty clean-plate diff extraction",
                )

    def test_shop_redesign_book_layer_is_clean_transparent_overlay(self) -> None:
        native = load_rgba(SHOP_REDESIGN_SOURCE / "shop_book_native.png")
        alpha = native.getchannel("A")
        alpha_min, alpha_max = alpha.getextrema()
        visible_pixels = visible_pixel_count(native)
        self.assertEqual(alpha_min, 0, "shop_book must be a clean transparent UI layer, not a duplicated scene crop")
        self.assertGreater(alpha_max, 0, "shop_book transparent layer is empty")
        self.assertLessEqual(
            visible_pixels,
            native.width * native.height * 3 // 5,
            "shop_book overlay covers too much of the scene; keep the ledger body in the clean background",
        )

    def test_primary_button_states_are_exact_native_exports(self) -> None:
        previous_bytes: bytes | None = None
        for state in STATES:
            with self.subTest(state=state):
                native_path = SOURCE / f"button_primary_{state}_native.png"
                runtime_path = RUNTIME / f"button_primary_{state}.png"
                self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
                self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")

                native = load_rgba(native_path)
                runtime = load_rgba(runtime_path)
                self.assertEqual(native.size, NATIVE_SIZE, f"{state}: wrong native size")
                self.assertEqual(runtime.size, RUNTIME_SIZE, f"{state}: wrong runtime size")
                self.assertGreaterEqual(visible_pixel_count(native), 420, f"{state}: too sparse")
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, f"{state}: needs transparent edge pixels")
                self.assertGreater(alpha_max, 0, f"{state}: has no visible pixels")

                expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{state}: not exact nearest export")

                current_bytes = native.tobytes()
                if previous_bytes is not None:
                    self.assertNotEqual(current_bytes, previous_bytes, f"{state}: state art matches previous state")
                previous_bytes = current_bytes

    def test_primary_button_reads_as_dark_tavern_action_plaque(self) -> None:
        native = load_rgba(SOURCE / "button_primary_normal_native.png")
        pixels = list(native.get_flattened_data())
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 220 and r <= 38 and 18 <= g <= 75 and 18 <= b <= 80
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 170 and r >= 185 and 75 <= g <= 175 and b <= 75
        )
        self.assertGreaterEqual(dark_pixels, 620, "primary button needs a readable dark wood/body")
        self.assertGreaterEqual(amber_pixels, 50, "primary button needs clear amber trim/accent pixels")

    def test_primary_button_reads_as_dark_map_plaque_not_noise_strip(self) -> None:
        native = load_rgba(SOURCE / "button_primary_normal_native.png")
        pixels = list(native.get_flattened_data())
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and r <= 45 and 18 <= g <= 85 and 18 <= b <= 90
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 160 and r >= 150 and 60 <= g <= 170 and b <= 90
        )
        parchment_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 95 <= r <= 190 and 60 <= g <= 150 and 35 <= b <= 110
        )
        self.assertGreaterEqual(dark_pixels, 620, "primary action should read as a dark map plaque")
        self.assertLessEqual(parchment_pixels, 360, "primary action should not be a noisy parchment strip")
        self.assertGreaterEqual(amber_pixels, 50, "primary action needs readable amber trim")
        self.assertLessEqual(amber_pixels, 260, "primary action hover/normal states should not flood amber")

    def test_note_action_button_states_are_exact_native_exports(self) -> None:
        previous_bytes: bytes | None = None
        for state in STATES:
            with self.subTest(state=state):
                native = assert_exact_native_export(
                    self,
                    SOURCE / f"button_note_action_{state}_native.png",
                    RUNTIME / f"button_note_action_{state}.png",
                    NOTE_ACTION_NATIVE_SIZE,
                    NOTE_ACTION_RUNTIME_SIZE,
                )
                self.assertGreaterEqual(visible_pixel_count(native), 340, f"{state}: note action tag too sparse")
                current_bytes = native.tobytes()
                if previous_bytes is not None:
                    self.assertNotEqual(current_bytes, previous_bytes, f"{state}: state art matches previous state")
                previous_bytes = current_bytes

    def test_note_action_button_reads_as_old_paper_stamp(self) -> None:
        native = load_rgba(SOURCE / "button_note_action_normal_native.png")
        pixels = list(native.get_flattened_data())
        muted_stamp_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 58 <= r <= 150 and 20 <= g <= 90 and 18 <= b <= 70 and r > g * 1.25
        )
        dark_ink_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and r <= 60 and 15 <= g <= 95 and 15 <= b <= 95
        )
        warm_highlight_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 160 and 135 <= r <= 205 and 80 <= g <= 155 and 35 <= b <= 95 and r - g <= 70
        )
        overheated_pixels = overheated_orange_pixel_count(native)
        muted_paper_pixels = muted_map_parchment_pixel_count(native)
        label_zone = native.crop((14, 3, 53, 11)).convert("RGBA")
        label_zone_paper_pixels = muted_map_parchment_pixel_count(label_zone)
        left_stamp_zone = native.crop((0, 0, 18, 14)).convert("RGBA")
        left_stamp_pixels = sum(
            1 for r, g, b, a in left_stamp_zone.get_flattened_data()
            if a >= 180 and 58 <= r <= 150 and 20 <= g <= 90 and 18 <= b <= 70 and r > g * 1.25
        )
        self.assertGreaterEqual(muted_stamp_pixels, 24, "note action needs a small muted red-brown stamped accent")
        self.assertLessEqual(muted_stamp_pixels, 110, "note action stamped accent must stay small, not become a wax-seal body")
        self.assertGreaterEqual(dark_ink_pixels, 70, "note action needs rough dark ink edging")
        self.assertGreaterEqual(warm_highlight_pixels, 18, "note action needs restrained warm paper highlights")
        self.assertLessEqual(overheated_pixels, 90, "note action should not be dominated by saturated orange/red")
        self.assertGreaterEqual(muted_paper_pixels, 260, "note action paper must be the main material")
        self.assertGreaterEqual(label_zone_paper_pixels, 150, "note action label area must stay readable paper")
        self.assertLessEqual(left_stamp_pixels, 96, "left accent must not read as an oversized wax seal")
        self.assertGreaterEqual(len(set(pixels)), 9, "note action button needs native-pixel tonal variation")

    def test_detail_go_button_states_are_exact_native_exports(self) -> None:
        previous_bytes: bytes | None = None
        for state in STATES:
            with self.subTest(state=state):
                native = assert_exact_native_export(
                    self,
                    SOURCE / f"button_detail_go_{state}_native.png",
                    RUNTIME / f"button_detail_go_{state}.png",
                    DETAIL_GO_BUTTON_NATIVE_SIZE,
                    DETAIL_GO_BUTTON_RUNTIME_SIZE,
                )
                self.assertGreaterEqual(visible_pixel_count(native), 340, f"{state}: detail go tag too sparse")
                current_bytes = native.tobytes()
                if previous_bytes is not None:
                    self.assertNotEqual(current_bytes, previous_bytes, f"{state}: state art matches previous state")
                previous_bytes = current_bytes

    def test_detail_go_button_reads_as_travel_tag(self) -> None:
        native = load_rgba(SOURCE / "button_detail_go_normal_native.png")
        pixels = list(native.get_flattened_data())
        parchment_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 95 <= r <= 190 and 60 <= g <= 150 and 35 <= b <= 112
        )
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and r <= 62 and 18 <= g <= 95 and 18 <= b <= 95
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 150 and r >= 145 and 55 <= g <= 165 and b <= 90
        )
        self.assertGreaterEqual(parchment_pixels, 360, "detail go button needs a readable travel-tag body")
        self.assertGreaterEqual(dark_pixels, 44, "detail go button needs a dark pressed shadow/outline")
        self.assertGreaterEqual(amber_pixels, 12, "detail go button needs small warm pin or seal accents")
        self.assertLessEqual(overheated_orange_pixel_count(native), 140, "detail go button should not become a hot orange strip")

    def test_detail_go_button_edges_are_not_hard_cropped(self) -> None:
        for state in STATES:
            with self.subTest(state=state):
                native = load_rgba(SOURCE / f"button_detail_go_{state}_native.png")
                left, right, top, bottom = alpha_edge_visible_counts(native)
                self.assertEqual(left, 0, f"{state}: detail go button left side is clipped")
                self.assertEqual(right, 0, f"{state}: detail go button right side is clipped")
                self.assertLessEqual(top, 50, f"{state}: detail go button top edge is a hard line")
                self.assertLessEqual(bottom, 50, f"{state}: detail go button bottom edge is a hard line")
                width_ratio, height_ratio = alpha_bbox_fill_ratio(native)
                self.assertGreaterEqual(width_ratio, 0.90, f"{state}: detail go button became too narrow")
                self.assertGreaterEqual(height_ratio, 0.90, f"{state}: detail go button became too short")

    def test_note_action_contact_sheet_exists(self) -> None:
        self.assertTrue(NOTE_ACTION_CONTACT_SHEET.exists(), f"{NOTE_ACTION_CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(NOTE_ACTION_CONTACT_SHEET.stat().st_size, 0, "note action contact sheet is empty")

    def test_button_silhouettes_fill_their_native_shapes(self) -> None:
        cases = [
            ("button_primary_normal", 0.86, 0.90),
            ("button_note_action_normal", 0.86, 0.90),
            ("button_detail_go_normal", 0.86, 0.84),
            ("button_ledger_normal", 0.82, 0.90),
            ("button_ledger_unread_normal", 0.82, 0.90),
            ("button_tab_normal", 0.82, 0.90),
            ("button_shop_wide_normal", 0.82, 0.90),
            ("button_shop_square_normal", 0.92, 0.90),
        ]
        for name, min_width_ratio, min_height_ratio in cases:
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                width_ratio, height_ratio = alpha_bbox_fill_ratio(native)
                self.assertGreaterEqual(width_ratio, min_width_ratio, f"{name}: visible silhouette is too narrow")
                self.assertGreaterEqual(height_ratio, min_height_ratio, f"{name}: visible silhouette is too short")

    def test_ledger_button_states_are_exact_native_exports(self) -> None:
        natives: dict[str, dict[str, Image.Image]] = {}
        for prefix in ["button_ledger", "button_ledger_unread"]:
            natives[prefix] = {}
            for state in STATES:
                with self.subTest(prefix=prefix, state=state):
                    native_path = SOURCE / f"{prefix}_{state}_native.png"
                    runtime_path = RUNTIME / f"{prefix}_{state}.png"
                    self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
                    self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
                    native = load_rgba(native_path)
                    runtime = load_rgba(runtime_path)
                    self.assertEqual(native.size, LEDGER_NATIVE_SIZE, f"{prefix} {state}: wrong native size")
                    self.assertEqual(runtime.size, LEDGER_RUNTIME_SIZE, f"{prefix} {state}: wrong runtime size")
                    self.assertGreaterEqual(visible_pixel_count(native), 160, f"{prefix} {state}: ledger button too sparse")
                    expected = native.resize(LEDGER_RUNTIME_SIZE, Image.Resampling.NEAREST)
                    self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{prefix} {state}: ledger not exact nearest export")
                    natives[prefix][state] = native
        normal_pressed_diff = sum(
            1
            for normal_px, pressed_px in zip(
                natives["button_ledger"]["normal"].get_flattened_data(),
                natives["button_ledger"]["pressed"].get_flattened_data(),
            )
            if normal_px != pressed_px
        )
        normal_hover_diff = sum(
            1
            for normal_px, hover_px in zip(
                natives["button_ledger"]["normal"].get_flattened_data(),
                natives["button_ledger"]["hover"].get_flattened_data(),
            )
            if normal_px != hover_px
        )
        unread_normal_diff = sum(
            1
            for normal_px, unread_px in zip(
                natives["button_ledger"]["normal"].get_flattened_data(),
                natives["button_ledger_unread"]["normal"].get_flattened_data(),
            )
            if normal_px != unread_px
        )
        self.assertGreaterEqual(normal_pressed_diff, 110, "pressed ledger state needs a clear authored state change")
        self.assertGreaterEqual(normal_hover_diff, 140, "hover ledger state needs a clear authored highlight change")
        self.assertGreaterEqual(unread_normal_diff, 18, "unread ledger button needs a visible authored prompt-state change")

    def test_ledger_unread_button_has_badge_region(self) -> None:
        normal = load_rgba(SOURCE / "button_ledger_normal_native.png")
        unread = load_rgba(SOURCE / "button_ledger_unread_normal_native.png")
        normal_badge_zone = normal.crop((46, 0, 66, 16)).convert("RGBA")
        unread_badge_zone = unread.crop((46, 0, 66, 16)).convert("RGBA")
        changed_pixels = sum(
            1
            for normal_px, unread_px in zip(normal_badge_zone.get_flattened_data(), unread_badge_zone.get_flattened_data())
            if normal_px != unread_px
        )
        warm_prompt_pixels = sum(
            1 for r, g, b, a in unread_badge_zone.get_flattened_data()
            if a >= 170 and r >= 120 and 25 <= g <= 130 and b <= 90 and r > b * 1.8
        )
        self.assertGreaterEqual(changed_pixels, 14, "unread ledger button needs a changed prompt region")
        self.assertGreaterEqual(warm_prompt_pixels, 6, "unread ledger button needs warm wax/amber prompt pixels")

    def test_ledger_button_contact_sheet_exists(self) -> None:
        self.assertTrue(LEDGER_BUTTON_CONTACT_SHEET.exists(), f"{LEDGER_BUTTON_CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(LEDGER_BUTTON_CONTACT_SHEET.stat().st_size, 0, "ledger button contact sheet is empty")

    def test_ledger_button_reads_as_small_book_tab(self) -> None:
        native_path = SOURCE / "button_ledger_normal_native.png"
        self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
        native = load_rgba(native_path)
        pixels = list(native.get_flattened_data())
        dark_cover_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 220 and r <= 45 and 20 <= g <= 85 and 20 <= b <= 90
        )
        page_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and 110 <= r <= 190 and 80 <= g <= 150 and 45 <= b <= 110
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 170 and r >= 185 and 75 <= g <= 175 and b <= 75
        )
        self.assertGreaterEqual(dark_cover_pixels, 90, "ledger button needs a dark book cover")
        self.assertGreaterEqual(page_pixels, 35, "ledger button needs visible page/parchment pixels")
        self.assertGreaterEqual(amber_pixels, 5, "ledger button needs a small amber clasp/accent")

    def test_ledger_button_has_readable_book_icon_geometry(self) -> None:
        native = load_rgba(SOURCE / "button_ledger_normal_native.png")
        pixels = list(native.get_flattened_data())
        page_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and 110 <= r <= 190 and 80 <= g <= 150 and 45 <= b <= 110
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 170 and r >= 185 and 75 <= g <= 175 and b <= 75
        )
        self.assertGreaterEqual(page_pixels, 96, "ledger button needs a readable page block")
        self.assertGreaterEqual(amber_pixels, 18, "ledger button needs a visible clasp or corner tabs")

    def test_ledger_button_has_title_style_pixel_detail_density(self) -> None:
        native = load_rgba(SOURCE / "button_ledger_normal_native.png")
        pixels = list(native.get_flattened_data())
        visible_colors = {
            (r, g, b)
            for r, g, b, a in pixels
            if a > 0
        }
        page_detail_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and 70 <= r <= 130 and 45 <= g <= 95 and 25 <= b <= 70
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 170 and r >= 185 and 75 <= g <= 175 and b <= 75
        )
        self.assertGreaterEqual(
            len(visible_colors),
            10,
            "ledger button needs enough native-pixel tonal steps to sit with the rest of the DayMap UI",
        )
        self.assertGreaterEqual(
            page_detail_pixels,
            22,
            "ledger button needs readable page/spine line details, not a flat book rectangle",
        )
        self.assertGreaterEqual(
            amber_pixels,
            30,
            "ledger button needs stronger amber clasp/corner accents to match the topbar material",
        )

    def test_panel_textures_are_exact_native_exports(self) -> None:
        cases = [
            ("panel_detail", DETAIL_PANEL_NATIVE_SIZE, DETAIL_PANEL_RUNTIME_SIZE),
            ("panel_result", RESULT_PANEL_NATIVE_SIZE, RESULT_PANEL_RUNTIME_SIZE),
        ]
        for name, native_size, runtime_size in cases:
            with self.subTest(name=name):
                native = assert_exact_native_export(
                    self,
                    SOURCE / f"{name}_native.png",
                    RUNTIME / f"{name}.png",
                    native_size,
                    runtime_size,
                )
                pixels = list(native.get_flattened_data())
                parchment_pixels = sum(
                    1 for r, g, b, a in pixels
                    if a >= 200 and 95 <= r <= 185 and 60 <= g <= 145 and 35 <= b <= 110
                )
                dark_pixels = sum(
                    1 for r, g, b, a in pixels
                    if a >= 200 and r <= 45 and 20 <= g <= 85 and 20 <= b <= 90
                )
                self.assertGreaterEqual(parchment_pixels, native_size[0] * native_size[1] // 3, f"{name}: needs parchment body")
                self.assertGreaterEqual(dark_pixels, native_size[0] * native_size[1] // 12, f"{name}: needs dark frame")
                self.assertGreaterEqual(
                    len(set(pixels)),
                    7,
                    f"{name}: too few tonal steps; panel reads as abstract flat color blocks",
                )

    def test_result_panel_keeps_a_complete_dark_frame(self) -> None:
        native = load_rgba(SOURCE / "panel_result_native.png")
        width, height = native.size
        pixels = native.load()

        def dark_pixels_in(box: tuple[int, int, int, int]) -> int:
            count = 0
            x1, y1, x2, y2 = box
            for y in range(y1, y2):
                for x in range(x1, x2):
                    red, green, blue, alpha = pixels[x, y]
                    if alpha >= 180 and red <= 45 and 15 <= green <= 90 and 15 <= blue <= 95:
                        count += 1
            return count

        edge_width = max(1, width // 8)
        self.assertGreaterEqual(
            dark_pixels_in((0, 0, edge_width, height)),
            900,
            "result panel lost the left dark frame; panel reference extraction is probably cutting the sheet",
        )
        self.assertGreaterEqual(
            dark_pixels_in((width - edge_width, 0, width, height)),
            900,
            "result panel lost the right dark frame; panel reference extraction is probably cutting the sheet",
        )

    def test_result_panel_reads_as_special_location_notice(self) -> None:
        native = load_rgba(SOURCE / "panel_result_native.png")
        pixels = list(native.get_flattened_data())
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and r <= 62 and 18 <= g <= 95 and 18 <= b <= 95
        )
        parchment_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 95 <= r <= 190 and 60 <= g <= 150 and 35 <= b <= 112
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 150 and r >= 145 and 55 <= g <= 165 and b <= 90
        )
        button_seat = native.crop((55, 77, 120, 99)).convert("RGBA")
        seat_pixels = list(button_seat.get_flattened_data())
        seat_dark_pixels = sum(
            1 for r, g, b, a in seat_pixels
            if a >= 180 and r <= 70 and 18 <= g <= 100 and 18 <= b <= 100
        )
        body_area = native.crop((24, 24, 151, 72)).convert("RGBA")
        body_pixels = list(body_area.get_flattened_data())
        body_parchment_pixels = sum(
            1 for r, g, b, a in body_pixels
            if a >= 180 and 95 <= r <= 190 and 60 <= g <= 150 and 35 <= b <= 112
        )
        self.assertGreaterEqual(dark_pixels, 1350, "result panel needs a strong dark teal special-location frame")
        self.assertGreaterEqual(parchment_pixels, 9800, "result panel needs a broad readable parchment body")
        self.assertGreaterEqual(amber_pixels, 80, "result panel needs wax, nail, or candle amber accents")
        self.assertGreaterEqual(seat_dark_pixels, 700, "result panel needs a visible bottom button seat")
        self.assertGreaterEqual(body_parchment_pixels, 4300, "result panel body safe area must stay readable")
        self.assertGreaterEqual(len(set(pixels)), 7, "result panel needs native-pixel tonal variation")

    def test_result_panel_contact_sheet_exists(self) -> None:
        self.assertTrue(RESULT_PANEL_CONTACT_SHEET.exists(), f"{RESULT_PANEL_CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(RESULT_PANEL_CONTACT_SHEET.stat().st_size, 0, "result panel contact sheet is empty")

    def test_topbar_strip_is_exact_native_export(self) -> None:
        native = assert_exact_native_export(
            self,
            SOURCE / "topbar_strip_native.png",
            RUNTIME / "topbar_strip.png",
            TOPBAR_NATIVE_SIZE,
            TOPBAR_RUNTIME_SIZE,
        )
        pixels = list(native.get_flattened_data())
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and r <= 45 and 18 <= g <= 80 and 18 <= b <= 85
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 150 and r >= 150 and 65 <= g <= 155 and b <= 80
        )
        wood_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 56 <= r <= 145 and 30 <= g <= 100 and 18 <= b <= 78 and r > g and g >= b
        )
        parchment_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 84 <= r <= 185 and 58 <= g <= 145 and 34 <= b <= 112 and r >= g and r - g <= 62
        )
        self.assertGreaterEqual(dark_pixels, 900, "topbar strip needs dark map-edge shadows")
        self.assertGreaterEqual(wood_pixels, 1600, "topbar strip should read as a muted wooden tavern-table ledge")
        self.assertGreaterEqual(parchment_pixels, 160, "topbar strip needs restrained paper/material patches behind status text")
        self.assertGreaterEqual(amber_pixels, 24, "topbar strip needs sparse amber binding accents")
        self.assertLessEqual(amber_pixels, 220, "topbar strip should not flood the bar with saturated orange")
        self.assertLessEqual(overheated_orange_pixel_count(native), 260, "topbar strip should stay muted, not hot orange")
        self.assertGreaterEqual(len(set(pixels)), 10, "topbar strip needs more material variation than a flat dark strip")

    def test_topbar_covers_the_screen_top_edge(self) -> None:
        native = load_rgba(SOURCE / "topbar_strip_native.png")
        top_alpha = [native.getpixel((x, 0))[3] for x in range(native.width)]
        visible_top_pixels = sum(1 for alpha in top_alpha if alpha > 0)
        self.assertEqual(
            visible_top_pixels,
            native.width,
            "topbar native top row must be opaque so the screen does not leak above it",
        )

    def test_detail_panel_does_not_read_as_ruled_ledger_paper(self) -> None:
        native = load_rgba(SOURCE / "panel_detail_native.png")
        self.assertLessEqual(
            long_horizontal_line_pixels(native),
            96,
            "detail panel should not rely on repeated long horizontal guide lines",
        )
        self.assertEqual(
            internal_horizontal_mark_count(native),
            0,
            "detail panel body should use speckles, not cut-out horizontal marks",
        )
        self.assertEqual(
            semi_transparent_body_pixel_count(native),
            0,
            "detail panel body should be opaque; do not use alpha as carved wear",
        )

    def test_detail_panel_reads_as_knife_pinned_location_notice(self) -> None:
        native = load_rgba(SOURCE / "panel_detail_native.png")
        pixels = list(native.get_flattened_data())
        blade_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 105 <= r <= 225 and 110 <= g <= 230 and 100 <= b <= 220
        )
        top_left = native.crop((0, 0, 34, 36)).convert("RGBA")
        top_left_blade_pixels = sum(
            1 for r, g, b, a in top_left.get_flattened_data()
            if a >= 180 and 105 <= r <= 225 and 110 <= g <= 230 and 100 <= b <= 220
        )
        title_safe = native.crop((18, 8, 70, 28)).convert("RGBA")
        title_dark_pixels = sum(
            1 for r, g, b, a in title_safe.get_flattened_data()
            if a >= 180 and r <= 62 and 18 <= g <= 95 and 18 <= b <= 95
        )
        body_safe = native.crop((14, 28, 66, 92)).convert("RGBA")
        body_parchment_pixels = sum(
            1 for r, g, b, a in body_safe.get_flattened_data()
            if a >= 200 and 95 <= r <= 190 and 60 <= g <= 150 and 35 <= b <= 112
        )
        self.assertGreaterEqual(blade_pixels, 12, "detail panel needs visible knife blade pixels")
        self.assertGreaterEqual(top_left_blade_pixels, 8, "detail panel knife should visibly pin the upper-left paper corner")
        self.assertLessEqual(title_dark_pixels, 520, "detail title safe area should not be buried under the knife or dark ornament")
        self.assertGreaterEqual(body_parchment_pixels, 1900, "detail body safe area needs enough clear parchment for readable labels")

    def test_detail_panel_contact_sheet_exists(self) -> None:
        self.assertTrue(DETAIL_PANEL_CONTACT_SHEET.exists(), f"{DETAIL_PANEL_CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(DETAIL_PANEL_CONTACT_SHEET.stat().st_size, 0, "detail panel contact sheet is empty")

    def test_pinned_note_assets_are_exact_native_exports(self) -> None:
        cases = [
            (
                "pinned_note_panel",
                PINNED_NOTE_PANEL_NATIVE_SIZE,
                PINNED_NOTE_PANEL_RUNTIME_SIZE,
            ),
            (
                "pinned_note_knife",
                PINNED_NOTE_KNIFE_NATIVE_SIZE,
                PINNED_NOTE_KNIFE_RUNTIME_SIZE,
            ),
            (
                "pinned_note_detail_panel",
                PINNED_DETAIL_PANEL_NATIVE_SIZE,
                PINNED_DETAIL_PANEL_RUNTIME_SIZE,
            ),
        ]
        for name, native_size, runtime_size in cases:
            with self.subTest(name=name):
                assert_exact_native_export(
                    self,
                    SOURCE / f"{name}_native.png",
                    RUNTIME / f"{name}.png",
                    native_size,
                    runtime_size,
                )

    def test_gathering_toast_panel_is_exact_native_export(self) -> None:
        assert_exact_native_export(
            self,
            SOURCE / "gathering_toast_panel_native.png",
            RUNTIME / "gathering_toast_panel.png",
            GATHERING_TOAST_PANEL_NATIVE_SIZE,
            GATHERING_TOAST_PANEL_RUNTIME_SIZE,
        )

    def test_gathering_toast_panel_reads_as_top_bubble(self) -> None:
        native = load_rgba(SOURCE / "gathering_toast_panel_native.png")
        pixels = list(native.get_flattened_data())
        visible_pixels = visible_pixel_count(native)
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and r <= 62 and 18 <= g <= 95 and 18 <= b <= 95
        )
        parchment_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 95 <= r <= 190 and 60 <= g <= 150 and 35 <= b <= 112
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 150 and r >= 145 and 55 <= g <= 165 and b <= 90
        )
        self.assertGreaterEqual(visible_pixels, 1000, "gathering toast panel needs a readable banner body")
        self.assertGreaterEqual(dark_pixels, 80, "gathering toast panel needs dark DayMap outline/shadow pixels")
        self.assertGreaterEqual(parchment_pixels, 680, "gathering toast panel should read as muted parchment")
        self.assertGreaterEqual(amber_pixels, 10, "gathering toast panel needs sparse warm pin/highlight pixels")
        self.assertLessEqual(overheated_orange_pixel_count(native), 160, "gathering toast panel should not become a hot orange strip")

    def test_gathering_toast_contact_sheet_exists(self) -> None:
        self.assertTrue(GATHERING_TOAST_CONTACT_SHEET.exists(), f"{GATHERING_TOAST_CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(GATHERING_TOAST_CONTACT_SHEET.stat().st_size, 0, "gathering toast contact sheet is empty")

    def test_pinned_note_panel_reads_as_map_parchment(self) -> None:
        native = load_rgba(SOURCE / "pinned_note_panel_native.png")
        pixels = list(native.get_flattened_data())
        parchment_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and 100 <= r <= 220 and 65 <= g <= 170 and 35 <= b <= 120
        )
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and r <= 55 and 15 <= g <= 90 and 15 <= b <= 95
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 160 and r >= 150 and 55 <= g <= 170 and b <= 90
        )
        blade_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 115 <= r <= 220 and 120 <= g <= 225 and 110 <= b <= 215
        )
        puncture_zone = native.crop((0, 0, 42, 42)).convert("RGBA")
        zone_pixels = list(puncture_zone.get_flattened_data())
        zone_blade_pixels = sum(
            1 for r, g, b, a in zone_pixels
            if a >= 180 and 86 <= r <= 220 and 90 <= g <= 225 and 85 <= b <= 215 and abs(r - g) <= 80
        )
        zone_dark_pixels = sum(
            1 for r, g, b, a in zone_pixels
            if a >= 180 and r <= 70 and 15 <= g <= 100 and 15 <= b <= 100
        )
        self.assertGreaterEqual(parchment_pixels, 4200, "pinned note needs a writable parchment body")
        self.assertGreaterEqual(dark_pixels, 430, "pinned note needs a dark DayMap edge/shadow")
        self.assertGreaterEqual(amber_pixels, 24, "pinned note needs sparse amber wax or pin accents")
        self.assertLessEqual(overheated_orange_pixel_count(native), 1200, "pinned note should not read as saturated orange UI")
        self.assertGreaterEqual(muted_map_parchment_pixel_count(native), 3600, "pinned note should match the map parchment palette")
        self.assertGreaterEqual(blade_pixels, 12, "pinned note composite needs visible dagger blade pixels")
        self.assertGreaterEqual(zone_blade_pixels, 32, "pinned note upper-left area needs visible piercing metal")
        self.assertGreaterEqual(zone_dark_pixels, 120, "pinned note upper-left area needs puncture shadow and folds")
        self.assertGreaterEqual(len(set(pixels)), 10, "pinned note needs native-pixel tonal variation")

    def test_pinned_detail_panel_matches_daymap_marker_palette(self) -> None:
        native = load_rgba(SOURCE / "pinned_note_detail_panel_native.png")
        pixels = list(native.get_flattened_data())
        parchment_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and 95 <= r <= 190 and 60 <= g <= 150 and 35 <= b <= 112
        )
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and r <= 62 and 18 <= g <= 95 and 18 <= b <= 95
        )
        blade_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 105 <= r <= 225 and 110 <= g <= 230 and 100 <= b <= 220
        )
        overheated_pixels = overheated_orange_pixel_count(native)
        self.assertGreaterEqual(parchment_pixels, 5200, "pinned detail panel needs a broad readable parchment body")
        self.assertGreaterEqual(dark_pixels, 600, "pinned detail panel needs DayMap dark teal map-shadow pixels")
        self.assertGreaterEqual(blade_pixels, 12, "pinned detail panel needs a visible dagger pin")
        self.assertLessEqual(overheated_pixels, 80, "pinned detail panel should stay muted, not hot orange")
        self.assertGreaterEqual(len(set(pixels)), 10, "pinned detail panel needs native-pixel tonal variation")

    def test_pinned_note_knife_reads_as_small_dagger_pin(self) -> None:
        native = load_rgba(SOURCE / "pinned_note_knife_native.png")
        pixels = list(native.get_flattened_data())
        blade_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 115 <= r <= 220 and 120 <= g <= 225 and 110 <= b <= 215
        )
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and r <= 60 and 15 <= g <= 85 and 15 <= b <= 90
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 160 and r >= 145 and 55 <= g <= 165 and b <= 90
        )
        visible_pixels = visible_pixel_count(native)
        self.assertGreaterEqual(visible_pixels, 95, "knife pin must have a readable silhouette")
        self.assertGreaterEqual(blade_pixels, 6, "knife pin needs blade pixels")
        self.assertGreaterEqual(dark_pixels, 28, "knife pin needs dark handle or outline pixels")
        self.assertGreaterEqual(amber_pixels, 4, "knife pin needs small warm hilt or rivet pixels")

    def test_pinned_note_contact_sheet_exists(self) -> None:
        self.assertTrue(PINNED_NOTE_CONTACT_SHEET.exists(), f"{PINNED_NOTE_CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(PINNED_NOTE_CONTACT_SHEET.stat().st_size, 0, "pinned note contact sheet is empty")

    def test_pinned_note_assets_have_manifest_entries(self) -> None:
        self.assertTrue(DAYMAP_UI_MANIFEST.exists(), f"{DAYMAP_UI_MANIFEST}: missing manifest")
        manifest = json.loads(DAYMAP_UI_MANIFEST.read_text(encoding="utf-8"))
        assets = manifest.get("assets", {})
        expected = {
            "topbar_strip": {
                "source_file": "art_sources/generated_raw/daymap/topbar_desktop_source.png",
                "native_file": "assets/source/daymap/ui/topbar_strip_native.png",
                "output_file": "assets/textures/daymap/ui/topbar_strip.png",
                "size": [1280, 60],
                "source_crop": TOPBAR_SOURCE_CROP,
                "safe_area": [72, 8, 1120, 44],
                "intended_godot_use": "DayMap UILayer/TopBar/TopStrip",
            },
            "gathering_toast_panel": {
                "source_file": "art_sources/generated_raw/daymap/gathering_toast_panel_source_v2.png",
                "native_file": "assets/source/daymap/ui/gathering_toast_panel_native.png",
                "output_file": "assets/textures/daymap/ui/gathering_toast_panel.png",
                "size": [420, 56],
                "source_crop": GATHERING_TOAST_PANEL_CROP,
                "safe_area": [44, 10, 332, 36],
                "intended_godot_use": "DayMap UILayer/GatheringToast panel",
            },
            "panel_result": {
                "source_file": "art_sources/generated_raw/daymap/special_result_panel_source_v1.png",
                "native_file": "assets/source/daymap/ui/panel_result_native.png",
                "output_file": "assets/textures/daymap/ui/panel_result.png",
                "size": [700, 400],
                "source_crop": SPECIAL_RESULT_PANEL_CROP,
                "safe_area": [96, 88, 508, 228],
                "intended_godot_use": "DayMap UILayer/ResultPanel special-location result notice",
            },
            "pinned_note_panel": {
                "source_file": "art_sources/generated_raw/daymap/pinned_note_pierced_source.png",
                "native_file": "assets/source/daymap/ui/pinned_note_panel_native.png",
                "output_file": "assets/textures/daymap/ui/pinned_note_panel.png",
                "size": [368, 384],
                "source_crop": PINNED_NOTE_PANEL_CROP,
                "safe_area": [84, 88, 248, 228],
                "intended_godot_use": "DayMap PinnedNotePanel/NoteArt",
            },
            "pinned_note_knife": {
                "source_file": "art_sources/generated_raw/daymap/pinned_note_pierced_source.png",
                "native_file": "assets/source/daymap/ui/pinned_note_knife_native.png",
                "output_file": "assets/textures/daymap/ui/pinned_note_knife.png",
                "size": [112, 112],
                "source_crop": PINNED_NOTE_KNIFE_CROP,
                "safe_area": [18, 0, 74, 112],
                "intended_godot_use": "DayMap PinnedNotePanel optional KnifeArt compatibility layer",
            },
            "pinned_note_detail_panel": {
                "source_file": "art_sources/generated_raw/daymap/pinned_note_detail_panel_source_v2.png",
                "native_file": "assets/source/daymap/ui/pinned_note_detail_panel_native.png",
                "output_file": "assets/textures/daymap/ui/pinned_note_detail_panel.png",
                "size": [368, 384],
                "source_crop": PINNED_DETAIL_PANEL_CROP,
                "safe_area": [88, 88, 224, 192],
                "intended_godot_use": "DayMap MapWorld/PinnedNotePanel/NoteArt active location notice",
            },
            "panel_detail": {
                "source_file": "art_sources/generated_raw/daymap/detail_panel_pinned_notice_source_v1.png",
                "native_file": "assets/source/daymap/ui/panel_detail_native.png",
                "output_file": "assets/textures/daymap/ui/panel_detail.png",
                "size": [320, 480],
                "source_crop": DETAIL_PANEL_SOURCE_CROP,
                "safe_area": [56, 112, 208, 256],
                "intended_godot_use": "DayMap UILayer/DetailPanel pinned location notice",
            },
        }
        for state in STATES:
            expected[f"button_ledger_{state}"] = {
                "source_file": "art_sources/generated_raw/daymap/daymap_ledger_button_states_source_v1.png",
                "native_file": f"assets/source/daymap/ui/button_ledger_{state}_native.png",
                "output_file": f"assets/textures/daymap/ui/button_ledger_{state}.png",
                "size": [132, 44],
                "source_crop": LEDGER_BUTTON_CROPS[state],
                "safe_area": [42, 8, 60, 28],
                "intended_godot_use": "DayMap UILayer/TopBar/DocumentsBtn",
            }
            expected[f"button_ledger_unread_{state}"] = {
                "source_file": "art_sources/generated_raw/daymap/daymap_ledger_unread_button_states_source_v1.png",
                "prompt": "art_sources/generated_raw/daymap/daymap_ledger_unread_button_states_prompt_v1.txt",
                "native_file": f"assets/source/daymap/ui/button_ledger_unread_{state}_native.png",
                "output_file": f"assets/textures/daymap/ui/button_ledger_unread_{state}.png",
                "size": [132, 44],
                "source_crop": LEDGER_BUTTON_CROPS[state],
                "safe_area": [42, 8, 60, 28],
                "intended_godot_use": "DayMap UILayer/TopBar/DocumentsBtn unread prompt state",
            }
            expected[f"button_note_action_{state}"] = {
                "source_file": "art_sources/generated_raw/daymap/note_action_paper_stamp_source.png",
                "native_file": f"assets/source/daymap/ui/button_note_action_{state}_native.png",
                "output_file": f"assets/textures/daymap/ui/button_note_action_{state}.png",
                "size": [224, 56],
                "source_crop": NOTE_ACTION_CROPS[state],
                "safe_area": [56, 12, 148, 32],
                "intended_godot_use": "DayMap PinnedNotePanel/GoHereBtn",
            }
            expected[f"button_detail_go_{state}"] = {
                "source_file": "art_sources/generated_raw/daymap/detail_go_button_states_source_v3.png",
                "native_file": f"assets/source/daymap/ui/button_detail_go_{state}_native.png",
                "output_file": f"assets/textures/daymap/ui/button_detail_go_{state}.png",
                "size": [224, 56],
                "source_crop": DETAIL_GO_BUTTON_CROPS[state],
                "safe_area": [44, 10, 136, 36],
                "intended_godot_use": "DayMap UILayer/DetailPanel/GoHereBtn",
            }
        for asset_id, expected_entry in expected.items():
            with self.subTest(asset_id=asset_id):
                self.assertIn(asset_id, assets, f"{asset_id}: missing manifest entry")
                for key, value in expected_entry.items():
                    self.assertEqual(assets[asset_id].get(key), value, f"{asset_id}: wrong manifest {key}")

    def test_tab_button_states_are_exact_native_exports(self) -> None:
        for state in TAB_STATES:
            with self.subTest(state=state):
                assert_exact_native_export(
                    self,
                    SOURCE / f"button_tab_{state}_native.png",
                    RUNTIME / f"button_tab_{state}.png",
                    TAB_NATIVE_SIZE,
                    TAB_RUNTIME_SIZE,
                )

    def test_shop_button_states_are_exact_native_exports(self) -> None:
        cases = [
            ("button_shop_square", SHOP_SQUARE_NATIVE_SIZE, SHOP_SQUARE_RUNTIME_SIZE),
            ("button_shop_wide", SHOP_WIDE_NATIVE_SIZE, SHOP_WIDE_RUNTIME_SIZE),
        ]
        for base, native_size, runtime_size in cases:
            for state in STATES:
                with self.subTest(base=base, state=state):
                    assert_exact_native_export(
                        self,
                        SOURCE / f"{base}_{state}_native.png",
                        RUNTIME / f"{base}_{state}.png",
                        native_size,
                        runtime_size,
                    )

    def test_shop_buttons_read_as_daymap_material_controls(self) -> None:
        cases = [
            ("button_shop_square_normal", 6, 34, 20),
            ("button_shop_wide_normal", 6, 70, 30),
        ]
        for name, min_colors, min_dark, min_amber in cases:
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                pixels = list(native.get_flattened_data())
                visible_colors = {
                    (r, g, b)
                    for r, g, b, a in pixels
                    if a > 0
                }
                dark_pixels = sum(
                    1 for r, g, b, a in pixels
                    if a >= 200 and r <= 45 and 18 <= g <= 85 and 18 <= b <= 90
                )
                amber_pixels = sum(
                    1 for r, g, b, a in pixels
                    if a >= 160 and r >= 150 and 60 <= g <= 170 and b <= 90
                )
                self.assertGreaterEqual(
                    len(visible_colors),
                    min_colors,
                    f"{name}: shop control is too low-detail for the DayMap UI",
                )
                self.assertGreaterEqual(dark_pixels, min_dark, f"{name}: needs a stronger dark tavern-control body")
                self.assertGreaterEqual(amber_pixels, min_amber, f"{name}: needs readable amber trim/accent pixels")

    def test_shop_stepper_icons_are_exact_native_exports(self) -> None:
        for name in ["icon_shop_stepper_decrement", "icon_shop_stepper_increment"]:
            with self.subTest(name=name):
                native = assert_exact_native_export(
                    self,
                    SOURCE / f"{name}_native.png",
                    RUNTIME / f"{name}.png",
                    SHOP_STEPPER_ICON_NATIVE_SIZE,
                    SHOP_STEPPER_ICON_RUNTIME_SIZE,
                )
                pixels = list(native.get_flattened_data())
                amber_pixels = sum(
                    1 for r, g, b, a in pixels
                    if a >= 180 and r >= 185 and 75 <= g <= 175 and b <= 90
                )
                dark_shadow_pixels = sum(
                    1 for r, g, b, a in pixels
                    if a >= 180 and r <= 55 and 18 <= g <= 90 and 18 <= b <= 95
                )
                self.assertGreaterEqual(amber_pixels, 5, f"{name}: icon needs readable amber symbol pixels")
                self.assertGreaterEqual(dark_shadow_pixels, 2, f"{name}: icon needs dark shadow pixels")

    def test_shop_background_and_scrollbar_assets_are_exact_native_exports(self) -> None:
        cases = [
            ("panel_shop", SHOP_PANEL_NATIVE_SIZE, SHOP_PANEL_RUNTIME_SIZE),
            ("shop_backdrop", SHOP_BACKDROP_NATIVE_SIZE, SHOP_BACKDROP_RUNTIME_SIZE),
            ("scroll_track", SCROLL_TRACK_NATIVE_SIZE, SCROLL_TRACK_RUNTIME_SIZE),
            ("scroll_grabber", SCROLL_GRABBER_NATIVE_SIZE, SCROLL_GRABBER_RUNTIME_SIZE),
        ]
        for name, native_size, runtime_size in cases:
            with self.subTest(name=name):
                native = assert_exact_native_export(
                    self,
                    SOURCE / f"{name}_native.png",
                    RUNTIME / f"{name}.png",
                    native_size,
                    runtime_size,
                )
                pixels = list(native.get_flattened_data())
                dark_pixels = sum(
                    1 for r, g, b, a in pixels
                    if a >= 200 and r <= 45 and 18 <= g <= 85 and 18 <= b <= 90
                )
                amber_pixels = sum(
                    1 for r, g, b, a in pixels
                    if a >= 160 and r >= 150 and 60 <= g <= 170 and b <= 90
                )
                self.assertGreaterEqual(dark_pixels, native_size[0] * native_size[1] // 6, f"{name}: needs dark UI material")
                self.assertGreaterEqual(amber_pixels, 4, f"{name}: needs amber binding/accent pixels")

    def test_shop_backdrop_reads_as_underground_general_store(self) -> None:
        native = load_rgba(SOURCE / "shop_backdrop_native.png")
        pixels = list(native.get_flattened_data())
        visible_colors = {
            (r, g, b)
            for r, g, b, a in pixels
            if a >= 200
        }
        store_prop_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and 70 <= r <= 150 and 35 <= g <= 120 and 20 <= b <= 95
        )
        warm_light_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and r >= 150 and 60 <= g <= 170 and b <= 90
        )
        shelf_and_counter_rows = 0
        for y in range(native.height):
            row_prop_pixels = 0
            for x in range(native.width):
                r, g, b, a = native.getpixel((x, y))
                if a >= 200 and 70 <= r <= 150 and 35 <= g <= 120 and 20 <= b <= 95:
                    row_prop_pixels += 1
            if row_prop_pixels >= 35:
                shelf_and_counter_rows += 1

        self.assertGreaterEqual(len(visible_colors), 12, "shop backdrop needs more palette variation than stripe placeholder art")
        self.assertGreaterEqual(store_prop_pixels, 450, "shop backdrop needs visible wooden shelves, crates, or jars")
        self.assertGreaterEqual(warm_light_pixels, 800, "shop backdrop needs candle, lantern, or counter warm-light accents")
        self.assertGreaterEqual(shelf_and_counter_rows, 4, "shop backdrop needs multiple shelf/counter bands")

    def test_document_overlay_panel_is_exact_native_export(self) -> None:
        native = assert_exact_native_export(
            self,
            SOURCE / "panel_document_native.png",
            RUNTIME / "panel_document.png",
            DOCUMENT_PANEL_NATIVE_SIZE,
            DOCUMENT_PANEL_RUNTIME_SIZE,
        )
        pixels = list(native.get_flattened_data())
        dark_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 200 and r <= 45 and 18 <= g <= 85 and 18 <= b <= 90
        )
        parchment_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 180 and 95 <= r <= 190 and 60 <= g <= 150 and 35 <= b <= 110
        )
        amber_pixels = sum(
            1 for r, g, b, a in pixels
            if a >= 160 and r >= 150 and 60 <= g <= 170 and b <= 90
        )
        self.assertGreaterEqual(dark_pixels, 1600, "document panel needs a dark DayMap frame")
        self.assertGreaterEqual(parchment_pixels, 7000, "document panel needs readable paper pages")
        self.assertGreaterEqual(amber_pixels, 40, "document panel needs sparse amber binding accents")


if __name__ == "__main__":
    unittest.main(verbosity=2)
