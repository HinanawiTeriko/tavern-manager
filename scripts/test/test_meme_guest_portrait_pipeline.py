import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from scripts.tools.export_meme_guest_portraits import export_manifest


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "art_sources/generated_raw/characters/meme_guests/meme_guest_portraits_manifest.json"


class MemeGuestPortraitPipelineTest(unittest.TestCase):
    def test_manifest_shape(self):
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        ids = [asset["id"] for asset in data["assets"]]
        expected_ids = {
            "meme_doge_neutral",
            "meme_doge_satisfied",
            "meme_doge_dissatisfied",
            "meme_snack_cat_neutral",
            "meme_snack_cat_satisfied",
            "meme_snack_cat_dissatisfied",
            "meme_cheems_neutral",
            "meme_cheems_satisfied",
            "meme_cheems_dissatisfied",
            "meme_popcat_neutral",
            "meme_popcat_satisfied",
            "meme_popcat_dissatisfied",
            "meme_tomori_penguin_neutral",
            "meme_tomori_penguin_satisfied",
            "meme_tomori_penguin_dissatisfied",
            "meme_doro_neutral",
            "meme_doro_satisfied",
            "meme_doro_dissatisfied",
            "meme_anon_face_neutral",
            "meme_anon_face_satisfied",
            "meme_anon_face_dissatisfied",
            "meme_yellow_laugh_neutral",
            "meme_yellow_laugh_satisfied",
            "meme_yellow_laugh_dissatisfied",
        }
        self.assertEqual(set(ids), expected_ids)
        self.assertEqual(len(ids), len(set(ids)))
        for asset in data["assets"]:
            self.assertEqual(asset["native_size"], [96, 96])
            self.assertEqual(asset["runtime_scale"], 4)
            self.assertTrue(asset["runtime_output"].startswith("assets/textures/characters/"))
            self.assertFalse(asset["source"].startswith("assets/textures/"))

    def test_runtime_is_exact_nearest_neighbor_scale(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            export_manifest(MANIFEST, ROOT, output_root=Path(temp_dir))
            data = json.loads(MANIFEST.read_text(encoding="utf-8"))
            for asset in data["assets"]:
                native = Image.open(Path(temp_dir) / asset["native_output"]).convert("RGBA")
                runtime = Image.open(Path(temp_dir) / asset["runtime_output"]).convert("RGBA")
                scale = int(asset["runtime_scale"])
                expected = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
                self.assertEqual(runtime.size, expected.size)
                self.assertEqual(runtime.tobytes(), expected.tobytes())

    def test_new_meme_guests_have_distinct_reaction_portraits(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            export_manifest(MANIFEST, ROOT, output_root=Path(temp_dir))
            data = json.loads(MANIFEST.read_text(encoding="utf-8"))
            assets_by_id = {asset["id"]: asset for asset in data["assets"]}
            for guest_id in [
                "meme_tomori_penguin",
                "meme_doro",
                "meme_anon_face",
                "meme_yellow_laugh",
            ]:
                frames = []
                for state in ["neutral", "satisfied", "dissatisfied"]:
                    asset = assets_by_id[f"{guest_id}_{state}"]
                    native = Image.open(Path(temp_dir) / asset["native_output"]).convert("RGBA")
                    frames.append(native.tobytes())
                self.assertEqual(
                    len(set(frames)),
                    3,
                    f"{guest_id} should have distinct neutral/satisfied/dissatisfied portraits",
                )


if __name__ == "__main__":
    unittest.main()
