#!/usr/bin/env python3

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("generate_material_to_apple.py")
SPEC = importlib.util.spec_from_file_location("generate_material_to_apple", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class MaterialToAppleCorpusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.entries, cls.audit = MODULE.generate()

    def test_every_pinned_wire_identity_has_a_valid_native_target(self):
        MODULE.validate(self.entries, self.audit)
        self.assertEqual(len(self.entries), 8_825)
        self.assertEqual(self.audit["unresolved"], 0)
        self.assertEqual(self.audit["placeholder_targets"], 0)

    def test_every_sf_symbol_is_public_unrestricted_and_available_at_both_floors(self):
        availability, _search, releases, restrictions, _hashes = MODULE.apple_metadata()
        allowed = MODULE.deployment_symbols(availability, releases) - set(restrictions)
        selected = {
            entry["value"]
            for entry in self.entries.values()
            if entry["kind"] == "system_symbol"
        }
        self.assertTrue(selected <= allowed)
        self.assertFalse(selected & set(restrictions))
        for symbol in selected:
            release = releases[str(availability[symbol])]
            for platform, floor in MODULE.DEPLOYMENT_FLOORS.items():
                self.assertLessEqual(
                    MODULE.version_tuple(release[platform]),
                    MODULE.version_tuple(floor),
                    f"{symbol} requires {platform} {release[platform]} above {floor}",
                )

    def test_minor_sf_symbol_releases_are_not_collapsed_to_their_year(self):
        availability, _search, releases, _restrictions, _hashes = MODULE.apple_metadata()
        allowed = MODULE.deployment_symbols(availability, releases)
        self.assertNotIn("camera.macro", allowed)  # iOS 15.4, package floor iOS 15.0

    def test_style_variants_collapse_only_to_their_named_concept(self):
        for name, entry in self.entries.items():
            self.assertEqual(entry["concept"], MODULE.concept_for(name))
            base = self.entries.get(entry["concept"])
            if base is not None:
                self.assertEqual(entry["kind"], base["kind"])
                self.assertEqual(entry["value"], base["value"])

    def test_explorer_critical_icons_are_exact_cupertino_glyphs(self):
        expected = {
            "ROCKET_LAUNCH": "ROCKET",
            "HUB": "CIRCLE_GRID_HEX_FILL",
            "HOME": "HOME",
            "PHOTO": "PHOTO",
            "GRID_VIEW": "SQUARE_GRID_2X2",
            "SHOW_CHART": "GRAPH_SQUARE",
        }
        for material_name, cupertino_name in expected.items():
            self.assertEqual(
                self.entries[material_name],
                {
                    "kind": "cupertino_glyph",
                    "value": cupertino_name,
                    "concept": material_name,
                    "confidence": "reviewed",
                    "source": "reviewed_override",
                },
            )

    def test_checked_in_artifacts_are_reproducible(self):
        self.assertEqual(
            MODULE.OUTPUT_PATH.read_text(encoding="utf-8"),
            MODULE.render(self.entries),
        )
        self.assertEqual(
            MODULE.AUDIT_PATH.read_text(encoding="utf-8"),
            MODULE.render(self.audit),
        )


if __name__ == "__main__":
    unittest.main()
