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

    def test_navigation_travel_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.NAVIGATION_TRAVEL_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["navigation_travel"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_navigation_travel_known_wrong_generic_targets_do_not_regress(self):
        expected = {
            "EXPLORE": ("cupertino_glyph", "COMPASS"),
            "FLIGHT_TAKEOFF": ("system_symbol", "airplane.departure"),
            "MENU_OPEN": ("system_symbol", "sidebar.leading"),
            "ROUTE": (
                "system_symbol",
                "point.topleft.down.curvedto.point.bottomright.up",
            ),
            "U_TURN_RIGHT": ("system_symbol", "arrow.uturn.right"),
            "LOCAL_SHIPPING": ("system_symbol", "shippingbox.fill"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_action_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.ACTION_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["action"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_action_family_known_wrong_generic_targets_do_not_regress(self):
        expected = {
            "BACKSPACE": ("cupertino_glyph", "DELETE_LEFT"),
            "BUG_REPORT": ("system_symbol", "ladybug.fill"),
            "CHANGE_HISTORY": ("cupertino_glyph", "TRIANGLE"),
            "OPEN_IN_BROWSER": ("cupertino_glyph", "GLOBE"),
            "PICTURE_IN_PICTURE_ALT": ("system_symbol", "pip.enter"),
            "TURNED_IN": ("cupertino_glyph", "BOOKMARK_FILL"),
            "WEB_ASSET": ("system_symbol", "macwindow"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_maps_places_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.MAPS_PLACES_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["maps_places"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_maps_places_known_wrong_generic_targets_do_not_regress(self):
        expected = {
            "ATM": ("system_symbol", "banknote.fill"),
            "CASINO": ("system_symbol", "dice.fill"),
            "EMERGENCY": ("system_symbol", "cross.case.fill"),
            "LOCAL_GAS_STATION": ("system_symbol", "fuelpump.fill"),
            "LOCAL_PHARMACY": ("system_symbol", "pills.fill"),
            "MUSEUM": ("system_symbol", "building.columns.fill"),
            "THEATER_COMEDY": ("system_symbol", "theatermasks.fill"),
            "WHEELCHAIR_PICKUP": ("system_symbol", "figure.roll"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_device_hardware_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.DEVICE_HARDWARE_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["device_hardware"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_device_hardware_known_wrong_generic_targets_do_not_regress(self):
        expected = {
            "ADD_TO_HOME_SCREEN": ("system_symbol", "plus.app"),
            "DEVELOPER_BOARD": ("system_symbol", "cpu.fill"),
            "DISC_FULL": ("system_symbol", "opticaldisc"),
            "GAMEPAD": ("system_symbol", "gamecontroller.fill"),
            "MOBILE_OFF": ("system_symbol", "iphone.homebutton.slash"),
            "PHONELINK": ("system_symbol", "laptopcomputer.and.iphone"),
            "SD_CARD": ("system_symbol", "sdcard"),
            "USB": ("system_symbol", "cable.connector"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_social_activities_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.SOCIAL_ACTIVITIES_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["social_activities"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_social_activities_known_wrong_generic_targets_do_not_regress(self):
        expected = {
            "ARCHITECTURE": ("system_symbol", "ruler"),
            "BLIND": ("system_symbol", "eye.slash"),
            "CAMPAIGN": ("system_symbol", "megaphone.fill"),
            "COMPOST": ("system_symbol", "leaf.arrow.circlepath"),
            "CRUELTY_FREE": ("system_symbol", "hare.fill"),
            "MASKS": ("system_symbol", "facemask.fill"),
            "RECYCLING": ("system_symbol", "arrow.3.trianglepath"),
            "THUNDERSTORM": ("system_symbol", "cloud.bolt.rain.fill"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_image_media_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.IMAGE_MEDIA_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["image_media"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_image_media_distinct_semantics_do_not_regress(self):
        expected = {
            "ADJUST": ("system_symbol", "slider.horizontal.3"),
            "CAMERA_ROLL": ("cupertino_glyph", "PHOTO_FILL_ON_RECTANGLE_FILL"),
            "COMPARE": ("system_symbol", "square.split.2x1"),
            "FILTER_4": ("system_symbol", "4.circle"),
            "LENS": ("system_symbol", "camera.aperture"),
            "MOVIE_CREATION": ("cupertino_glyph", "FILM_FILL"),
            "PANORAMA_PHOTOSPHERE": ("system_symbol", "view.3d"),
            "ROTATE_90_DEGREES_CW": ("system_symbol", "rotate.right"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_text_editor_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.TEXT_EDITOR_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["text_editor"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_text_editor_distinct_semantics_do_not_regress(self):
        expected = {
            "ARCHIVE": ("system_symbol", "archivebox.fill"),
            "ASSIGNMENT_IND": ("system_symbol", "person.text.rectangle.fill"),
            "BORDER_ALL": ("system_symbol", "square.grid.2x2"),
            "DATA_ARRAY": ("system_symbol", "list.bullet"),
            "DATA_OBJECT": ("system_symbol", "curlybraces"),
            "HIGHLIGHT": ("system_symbol", "highlighter"),
            "INTEGRATION_INSTRUCTIONS": (
                "cupertino_glyph",
                "CHEVRON_LEFT_SLASH_CHEVRON_RIGHT",
            ),
            "SPELLCHECK": ("system_symbol", "textformat.abc.dottedunderline"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

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
