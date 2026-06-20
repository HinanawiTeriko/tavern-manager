from __future__ import annotations

import json
from pathlib import Path

import export_tavern_recipe_item_art as base


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "grill_expansion" / "grill_expansion_item_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_grill_expansion_contact_sheet.png"


def main() -> None:
    base.CONTACT_SHEET = CONTACT_SHEET
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    exports = [base.export_item(item_id, spec) for item_id, spec in manifest["items"].items()]
    base.make_contact_sheet(exports)
    print("exported tavern grill expansion item art: " + ", ".join(exported["id"] for exported in exports))


if __name__ == "__main__":
    main()
