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

    def test_home_household_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.HOME_HOUSEHOLD_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["home_household"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_home_household_distinct_semantics_do_not_regress(self):
        expected = {
            "BEDROOM_PARENT": ("system_symbol", "bed.double.fill"),
            "BROADCAST_ON_PERSONAL": (
                "system_symbol",
                "antenna.radiowaves.left.and.right.circle.fill",
            ),
            "COFFEE": ("system_symbol", "cup.and.saucer.fill"),
            "DESK": ("system_symbol", "studentdesk"),
            "GAS_METER": ("system_symbol", "gauge"),
            "HVAC": ("system_symbol", "fanblades.fill"),
            "OUTLET": ("system_symbol", "powerplug.fill"),
            "SNOWING": ("system_symbol", "cloud.snow.fill"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_communication_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.COMMUNICATION_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["communication"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_communication_distinct_semantics_do_not_regress(self):
        expected = {
            "CALL_MADE": ("system_symbol", "phone.arrow.up.right"),
            "CALL_RECEIVED": ("system_symbol", "phone.arrow.down.left"),
            "CANCEL_PRESENTATION": (
                "system_symbol",
                "rectangle.on.rectangle.slash",
            ),
            "CONTACT_EMERGENCY": (
                "cupertino_glyph",
                "PERSON_CROP_CIRCLE_BADGE_EXCLAM",
            ),
            "DIALPAD": ("system_symbol", "circle.grid.3x3.fill"),
            "MARK_UNREAD_CHAT_ALT": (
                "cupertino_glyph",
                "EXCLAMATIONMARK_BUBBLE_FILL",
            ),
            "QR_CODE_2": ("system_symbol", "qrcode"),
            "VOICEMAIL": ("system_symbol", "recordingtape"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_business_commerce_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.BUSINESS_COMMERCE_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["business_commerce"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_business_commerce_distinct_semantics_do_not_regress(self):
        expected = {
            "CALCULATE": ("system_symbol", "plus.forwardslash.minus"),
            "CONTACTLESS": ("system_symbol", "wave.3.right.circle.fill"),
            "CURRENCY_EXCHANGE": (
                "system_symbol",
                "arrow.left.arrow.right.circle.fill",
            ),
            "CURRENCY_FRANC": ("system_symbol", "francsign.circle"),
            "CURRENCY_RUPEE": ("system_symbol", "indianrupeesign.circle"),
            "DATA_EXPLORATION": ("system_symbol", "chart.xyaxis.line"),
            "INSERT_CHART_OUTLINED": ("system_symbol", "chart.bar.fill"),
            "REDEEM": ("system_symbol", "gift.fill"),
            "SAVINGS": ("system_symbol", "banknote.fill"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_travel_amenity_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.TRAVEL_AMENITY_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["travel_amenity"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_travel_amenity_distinct_semantics_do_not_regress(self):
        expected = {
            "BENTO": ("system_symbol", "takeoutbag.and.cup.and.straw.fill"),
            "DEPARTURE_BOARD": ("system_symbol", "airplane.departure"),
            "DO_NOT_TOUCH": ("system_symbol", "hand.raised.slash.fill"),
            "ELEVATOR": ("system_symbol", "arrow.up.arrow.down.square.fill"),
            "FORK_LEFT": ("system_symbol", "arrow.turn.up.left"),
            "FORK_RIGHT": ("system_symbol", "arrow.turn.up.right"),
            "MOPED": ("system_symbol", "scooter"),
            "TIRE_REPAIR": ("system_symbol", "wrench.fill"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_audio_video_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.AUDIO_VIDEO_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["audio_video"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_audio_video_distinct_semantics_do_not_regress(self):
        expected = {
            "AIRPLAY": ("system_symbol", "airplayvideo"),
            "ART_TRACK": ("cupertino_glyph", "MUSIC_ALBUMS_FILL"),
            "CLOSED_CAPTION": ("system_symbol", "captions.bubble.fill"),
            "HEARING_DISABLED": (
                "system_symbol",
                "ear.trianglebadge.exclamationmark",
            ),
            "LYRICS": ("system_symbol", "music.note.list"),
            "REPEAT_ONE_ON": ("system_symbol", "repeat.1.circle.fill"),
            "SUBSCRIPTIONS": (
                "system_symbol",
                "rectangle.stack.badge.play.fill",
            ),
            "SURROUND_SOUND": ("system_symbol", "hifispeaker.2.fill"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_notification_status_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.NOTIFICATION_STATUS_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["notification_status"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_notification_status_distinct_semantics_do_not_regress(self):
        expected = {
            "DO_DISTURB_ON": ("system_symbol", "minus.circle.fill"),
            "EVENT_BUSY": (
                "system_symbol",
                "calendar.badge.exclamationmark",
            ),
            "NO_ENCRYPTION_GMAILERRORRED": (
                "system_symbol",
                "lock.slash.fill",
            ),
            "ONDEMAND_VIDEO": ("system_symbol", "play.rectangle.fill"),
            "RUNNING_WITH_ERRORS": (
                "system_symbol",
                "exclamationmark.triangle.fill",
            ),
            "SMS_FAILED": (
                "cupertino_glyph",
                "EXCLAMATIONMARK_BUBBLE_FILL",
            ),
            "SYNC_PROBLEM": (
                "system_symbol",
                "exclamationmark.arrow.triangle.2.circlepath",
            ),
            "SYSTEM_UPDATE": ("system_symbol", "arrow.down.circle.fill"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_file_content_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.FILE_CONTENT_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(self.audit["reviewed_families"]["file_content"], len(family))
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_file_content_distinct_semantics_do_not_regress(self):
        expected = {
            "BLOCK_FLIPPED": ("system_symbol", "circle.slash"),
            "CONTENT_PASTE_GO": (
                "system_symbol",
                "arrow.right.doc.on.clipboard",
            ),
            "DIFFERENCE": ("system_symbol", "square.on.square.dashed"),
            "DRIVE_FILE_RENAME_OUTLINE": (
                "system_symbol",
                "square.and.pencil",
            ),
            "DYNAMIC_FEED": ("system_symbol", "rectangle.stack.fill"),
            "MARKUNREAD": ("system_symbol", "envelope.badge.fill"),
            "POLICY": ("system_symbol", "checkmark.shield.fill"),
            "WORKSPACES_OUTLINE": ("system_symbol", "rectangle.grid.2x2"),
        }
        for concept, (kind, value) in expected.items():
            self.assertEqual(self.entries[concept]["kind"], kind)
            self.assertEqual(self.entries[concept]["value"], value)

    def test_interface_action_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.INTERFACE_ACTION_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        entries_by_concept = {}
        for entry in self.entries.values():
            entries_by_concept.setdefault(entry["concept"], entry)
        self.assertEqual(
            self.audit["reviewed_families"]["interface_action"], len(family)
        )
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = entries_by_concept[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_interface_action_distinct_semantics_do_not_regress(self):
        expected = {
            "API": (
                "cupertino_glyph",
                "CHEVRON_LEFT_SLASH_CHEVRON_RIGHT",
            ),
            "ASSESSMENT": ("system_symbol", "chart.bar.fill"),
            "CLASS_": ("cupertino_glyph", "BOOK_FILL"),
            "CLASS_OUTLINED": ("cupertino_glyph", "BOOK_FILL"),
            "COMPRESS": (
                "system_symbol",
                "arrow.down.right.and.arrow.up.left",
            ),
            "EXPAND": (
                "system_symbol",
                "arrow.up.left.and.arrow.down.right",
            ),
            "FILTER_LIST_ALT": (
                "system_symbol",
                "line.3.horizontal.decrease",
            ),
            "FIT_SCREEN": (
                "system_symbol",
                "rectangle.and.arrow.up.right.and.arrow.down.left",
            ),
            "INPUT": (
                "system_symbol",
                "rectangle.portrait.and.arrow.right",
            ),
            "NOISE_AWARE": ("system_symbol", "ear.and.waveform"),
            "PRIVACY_TIP": ("system_symbol", "hand.raised.fill"),
            "RULE": ("system_symbol", "checklist"),
            "SMART_BUTTON": ("system_symbol", "wand.and.stars"),
            "SOURCE": ("system_symbol", "doc.text.fill"),
            "VIEW_KANBAN": (
                "system_symbol",
                "rectangle.split.3x1.fill",
            ),
            "WYSIWYG": ("system_symbol", "textformat"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_advanced_image_editing_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.ADVANCED_IMAGE_EDITING_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(
            self.audit["reviewed_families"]["advanced_image_editing"],
            len(family),
        )
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_advanced_image_editing_distinct_semantics_do_not_regress(self):
        expected = {
            "AUTO_AWESOME_MOTION": (
                "system_symbol",
                "sparkles.rectangle.stack.fill",
            ),
            "BLUR_CIRCULAR": ("system_symbol", "circle.dotted"),
            "CONTROL_POINT_DUPLICATE": (
                "cupertino_glyph",
                "SMALLCIRCLE_FILL_CIRCLE",
            ),
            "DEBLUR": ("system_symbol", "viewfinder"),
            "FILTER_TILT_SHIFT": ("system_symbol", "scope"),
            "INVERT_COLORS_ON": (
                "system_symbol",
                "circle.lefthalf.filled",
            ),
            "LOOKS_ONE": ("system_symbol", "1.square.fill"),
            "LOOKS_TWO": ("system_symbol", "2.square.fill"),
            "LOOKS_3": ("system_symbol", "3.square.fill"),
            "PANORAMA_FISHEYE": ("system_symbol", "circle"),
            "TRANSFORM": (
                "system_symbol",
                "rectangle.and.arrow.up.right.and.arrow.down.left",
            ),
            "WB_IRIDESCENT": ("system_symbol", "lightbulb.fill"),
            "WB_TWIGHLIGHT": ("system_symbol", "sunset.fill"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_local_service_transit_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.LOCAL_SERVICE_TRANSIT_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(
            self.audit["reviewed_families"]["local_service_transit"],
            len(family),
        )
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_local_service_transit_distinct_semantics_do_not_regress(self):
        expected = {
            "CONFIRMATION_NUM": ("system_symbol", "ticket"),
            "DIRECTIONS_FERRY": ("system_symbol", "ferry"),
            "DIRECTIONS_TRAIN": ("system_symbol", "tram"),
            "FASTFOOD": (
                "system_symbol",
                "takeoutbag.and.cup.and.straw.fill",
            ),
            "LOCAL_ATTRACTION": ("system_symbol", "ticket"),
            "LOCAL_PRINT_SHOP": ("system_symbol", "printer.fill"),
            "LOCAL_RESTAURANT": ("system_symbol", "fork.knife"),
            "MISCELLANEOUS_SERVICES": (
                "system_symbol",
                "wrench.and.screwdriver",
            ),
            "TRANSIT_ENTEREXIT": (
                "system_symbol",
                "arrow.left.arrow.right",
            ),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_device_status_family_is_explicit_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.DEVICE_STATUS_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(
            self.audit["reviewed_families"]["device_status"], len(family)
        )
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_device_status_distinct_semantics_do_not_regress(self):
        expected = {
            "AIRPLANEMODE_ACTIVE": ("system_symbol", "airplane"),
            "AIRPLANEMODE_ON": ("system_symbol", "airplane"),
            "MOBILEDATA_OFF": (
                "system_symbol",
                "antenna.radiowaves.left.and.right.slash",
            ),
            "NEARBY_OFF": (
                "system_symbol",
                "antenna.radiowaves.left.and.right.slash",
            ),
            "SECURITY_UPDATE_GOOD": (
                "system_symbol",
                "checkmark.shield.fill",
            ),
            "SECURITY_UPDATE_WARNING": (
                "system_symbol",
                "exclamationmark.shield.fill",
            ),
            "SIGNAL_CELLULAR_NODATA": (
                "system_symbol",
                "antenna.radiowaves.left.and.right.slash",
            ),
            "SIGNAL_WIFI_CONNECTED_NO_INTERNET_4": (
                "system_symbol",
                "wifi.exclamationmark",
            ),
            "SYSTEM_SECURITY_UPDATE_GOOD": (
                "system_symbol",
                "checkmark.shield.fill",
            ),
            "SYSTEM_SECURITY_UPDATE_WARNING": (
                "system_symbol",
                "exclamationmark.shield.fill",
            ),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_communication_access_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.COMMUNICATION_ACCESS_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(
            self.audit["reviewed_families"]["communication_access"],
            len(family),
        )
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_communication_access_distinct_semantics_do_not_regress(self):
        expected = {
            "CO_PRESENT": (
                "system_symbol",
                "person.crop.rectangle.stack.fill",
            ),
            "DIALER_SIP": ("system_symbol", "phone.connection"),
            "DOMAIN_VERIFICATION": (
                "system_symbol",
                "network.badge.shield.half.filled",
            ),
            "MESSENGER": (
                "system_symbol",
                "bubble.left.and.bubble.right.fill",
            ),
            "MESSENGER_OUTLINE": (
                "system_symbol",
                "bubble.left.and.bubble.right",
            ),
            "PERM_CONTACT_CALENDAR": (
                "system_symbol",
                "person.text.rectangle.fill",
            ),
            "PHONELINK_ERASE": (
                "system_symbol",
                "iphone.homebutton.slash",
            ),
            "PHONELINK_RING": (
                "system_symbol",
                "iphone.homebutton.radiowaves.left.and.right",
            ),
            "PRESENT_TO_ALL": ("system_symbol", "airplayvideo"),
            "SIP": ("system_symbol", "phone.connection"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_health_accessibility_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.HEALTH_ACCESSIBILITY_OVERRIDES_PATH)
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertEqual(
            self.audit["reviewed_families"]["health_accessibility"],
            len(family),
        )
        self.assertTrue(set(family).isdisjoint(low_confidence))
        for concept, target in family.items():
            entry = self.entries[concept]
            self.assertEqual(entry["kind"], target["kind"])
            self.assertEqual(entry["value"], target["value"])
            self.assertEqual(entry["confidence"], "reviewed")
            self.assertEqual(entry["source"], "reviewed_override")

    def test_health_accessibility_distinct_semantics_do_not_regress(self):
        expected = {
            "ACCESSIBILITY_NEW": ("system_symbol", "figure.stand"),
            "EMOJI_FOOD_BEVERAGE": (
                "system_symbol",
                "cup.and.saucer.fill",
            ),
            "ENGINEERING": (
                "system_symbol",
                "wrench.and.screwdriver.fill",
            ),
            "MEDICATION": ("system_symbol", "pills.fill"),
            "PERSONAL_INJURY": ("system_symbol", "bandage.fill"),
            "SCIENCE": ("cupertino_glyph", "LAB_FLASK_SOLID"),
            "SIX_FT_APART": (
                "system_symbol",
                "figure.stand.line.dotted.figure.stand",
            ),
            "SOCIAL_DISTANCE": (
                "system_symbol",
                "figure.stand.line.dotted.figure.stand",
            ),
            "VACCINES": ("system_symbol", "cross.vial.fill"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_interface_state_manipulation_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(
            MODULE.INTERFACE_STATE_MANIPULATION_OVERRIDES_PATH
        )
        expected_concepts = {
            "CUT",
            "DESELECT",
            "DND_FORWARDSLASH",
            "FLIP_TO_BACK",
            "FLIP_TO_FRONT",
            "PINCH",
            "RADIO_BUTTON_OFF",
            "RADIO_BUTTON_ON",
            "TRENDING_NEUTRAL",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["interface_state_manipulation"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 36)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_interface_state_manipulation_distinct_semantics_do_not_regress(self):
        expected = {
            "CUT": ("system_symbol", "scissors"),
            "DESELECT": ("system_symbol", "square.slash"),
            "DND_FORWARDSLASH": ("system_symbol", "circle.slash"),
            "FLIP_TO_BACK": (
                "system_symbol",
                "square.3.stack.3d.bottom.fill",
            ),
            "FLIP_TO_FRONT": (
                "system_symbol",
                "square.3.stack.3d.top.fill",
            ),
            "PINCH": (
                "system_symbol",
                "arrow.up.left.and.down.right.magnifyingglass",
            ),
            "RADIO_BUTTON_OFF": ("system_symbol", "circle"),
            "RADIO_BUTTON_ON": ("system_symbol", "circle.inset.filled"),
            "TRENDING_NEUTRAL": ("system_symbol", "arrow.right"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_apple_platform_device_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.APPLE_PLATFORM_DEVICE_OVERRIDES_PATH)
        expected_concepts = {
            "ANDROID",
            "APPLE",
            "FITBIT",
            "MOBILE_FRIENDLY",
            "PHONELINK_OFF",
            "SECURITY_UPDATE",
            "SYSTEM_SECURITY_UPDATE",
            "TABLET",
            "WATCH",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["apple_platform_device"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 36)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_apple_platform_device_distinct_semantics_do_not_regress(self):
        expected = {
            "ANDROID": ("system_symbol", "applelogo"),
            "APPLE": ("system_symbol", "applelogo"),
            "FITBIT": (
                "system_symbol",
                "applewatch.case.inset.filled",
            ),
            "MOBILE_FRIENDLY": (
                "system_symbol",
                "checkmark.rectangle.portrait",
            ),
            "PHONELINK_OFF": (
                "system_symbol",
                "iphone.homebutton.slash",
            ),
            "SECURITY_UPDATE": ("system_symbol", "arrow.down.app.fill"),
            "SYSTEM_SECURITY_UPDATE": (
                "system_symbol",
                "arrow.down.app.fill",
            ),
            "TABLET": ("system_symbol", "ipad.homebutton"),
            "WATCH": (
                "system_symbol",
                "applewatch.case.inset.filled",
            ),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_privacy_access_state_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.PRIVACY_ACCESS_STATE_OVERRIDES_PATH)
        expected_concepts = {
            "GPP_BAD",
            "GPP_GOOD",
            "GPP_MAYBE",
            "NO_ACCOUNTS",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["privacy_access_state"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 16)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_privacy_access_state_distinct_semantics_do_not_regress(self):
        expected = {
            "GPP_BAD": ("system_symbol", "xmark.shield.fill"),
            "GPP_GOOD": ("system_symbol", "checkmark.shield.fill"),
            "GPP_MAYBE": (
                "system_symbol",
                "exclamationmark.shield.fill",
            ),
            "NO_ACCOUNTS": ("system_symbol", "person.fill.xmark"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_legacy_interface_alias_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.LEGACY_INTERFACE_ALIAS_OVERRIDES_PATH)
        expected_concepts = {
            "COPY",
            "LABEL_OUTLINE",
            "NOW_WIDGETS",
            "ONETWOTHREE",
            "OUTBOND",
            "PASTE",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["legacy_interface_alias"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        # LABEL_OUTLINE has no redundant OUTLINED wire alias; the other five
        # concepts carry all four Material style identities.
        self.assertEqual(len(family_wire_identities), 23)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_legacy_interface_alias_distinct_semantics_do_not_regress(self):
        expected = {
            "COPY": ("system_symbol", "doc.on.doc"),
            "LABEL_OUTLINE": ("system_symbol", "tag"),
            "NOW_WIDGETS": ("system_symbol", "square.grid.2x2"),
            "ONETWOTHREE": ("cupertino_glyph", "TEXTFORMAT_123"),
            "OUTBOND": ("system_symbol", "arrow.up.right.square"),
            "PASTE": ("system_symbol", "doc.on.clipboard"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_media_library_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.MEDIA_LIBRARY_OVERRIDES_PATH)
        expected_concepts = {
            "MY_LIBRARY_ADD",
            "MY_LIBRARY_MUSIC",
            "RECENT_ACTORS",
            "VIDEO_LIBRARY",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["media_library"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 16)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_media_library_distinct_semantics_do_not_regress(self):
        expected = {
            "MY_LIBRARY_ADD": (
                "system_symbol",
                "rectangle.stack.badge.plus",
            ),
            "MY_LIBRARY_MUSIC": ("system_symbol", "music.note.list"),
            "RECENT_ACTORS": (
                "system_symbol",
                "person.crop.circle.badge.clock.fill",
            ),
            "VIDEO_LIBRARY": (
                "system_symbol",
                "rectangle.stack.badge.play",
            ),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_financial_wallet_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.FINANCIAL_WALLET_OVERRIDES_PATH)
        expected_concepts = {
            "ACCOUNT_BALANCE",
            "ACCOUNT_BALANCE_WALLET",
            "CARD_TRAVEL",
            "WALLET_MEMBERSHIP",
            "WALLET_TRAVEL",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["financial_wallet"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 20)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_financial_wallet_distinct_semantics_do_not_regress(self):
        expected = {
            "ACCOUNT_BALANCE": ("system_symbol", "building.columns.fill"),
            "ACCOUNT_BALANCE_WALLET": ("system_symbol", "wallet.pass.fill"),
            "CARD_TRAVEL": ("system_symbol", "suitcase.fill"),
            "WALLET_MEMBERSHIP": ("system_symbol", "creditcard.fill"),
            "WALLET_TRAVEL": ("system_symbol", "suitcase.fill"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_disabled_interface_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.DISABLED_INTERFACE_OVERRIDES_PATH)
        expected_concepts = {
            "CODE_OFF",
            "GRID_OFF",
            "LABEL_OFF",
            "SENSORS",
            "SENSORS_OFF",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["disabled_interface"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 20)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_disabled_interface_distinct_semantics_do_not_regress(self):
        expected = {
            "CODE_OFF": (
                "system_symbol",
                "chevron.left.slash.chevron.right",
            ),
            "GRID_OFF": ("system_symbol", "rectangle.3.offgrid.fill"),
            "LABEL_OFF": ("system_symbol", "tag.slash.fill"),
            "SENSORS": (
                "system_symbol",
                "antenna.radiowaves.left.and.right",
            ),
            "SENSORS_OFF": (
                "system_symbol",
                "antenna.radiowaves.left.and.right.slash",
            ),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

    def test_legacy_named_symbol_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.LEGACY_NAMED_SYMBOL_OVERRIDES_PATH)
        expected_concepts = {
            "FOUR_K",
            "NIGHTLIGHT",
            "QUERY_BUILDER",
            "THREED_ROTATION",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["legacy_named_symbol"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 16)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_legacy_named_symbols_do_not_conflate_nearby_concepts(self):
        expected = {
            "FOUR_K": ("system_symbol", "4k.tv.fill"),
            "NIGHTLIGHT": ("system_symbol", "moon.fill"),
            "QUERY_BUILDER": ("system_symbol", "clock.fill"),
            "THREED_ROTATION": ("system_symbol", "rotate.3d"),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

        # Apple has no floor-safe 4K+ distinction; never silently collapse it
        # into the reviewed 4K identity.
        self.assertNotEqual(
            self.entries["FOUR_K_PLUS"]["value"],
            self.entries["FOUR_K"]["value"],
        )
        self.assertNotEqual(self.entries["FOUR_K_PLUS"]["confidence"], "reviewed")

    def test_layout_manipulation_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.LAYOUT_MANIPULATION_OVERRIDES_PATH)
        expected_concepts = {
            "BORDER_HORIZONTAL",
            "BORDER_INNER",
            "BORDER_OUTER",
            "SWAP_VERT_CIRCLE",
            "UNFOLD_MORE_DOUBLE",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["layout_manipulation"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 20)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_layout_manipulation_geometry_does_not_regress(self):
        expected = {
            "BORDER_HORIZONTAL": ("system_symbol", "rectangle.split.1x2"),
            "BORDER_INNER": ("system_symbol", "rectangle.split.2x2"),
            "BORDER_OUTER": ("system_symbol", "rectangle"),
            "SWAP_VERT_CIRCLE": (
                "system_symbol",
                "arrow.up.arrow.down.circle.fill",
            ),
            "UNFOLD_MORE_DOUBLE": (
                "system_symbol",
                "chevron.up.chevron.down",
            ),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

        # Half-filled rectangles are not border-line artwork. Keep directional
        # border variants out of this family until Apple exposes exact glyphs.
        for material_name in ("BORDER_TOP", "BORDER_BOTTOM", "BORDER_RIGHT"):
            self.assertNotEqual(self.entries[material_name]["confidence"], "reviewed")

    def test_device_interaction_state_family_is_reviewed_native_artwork(self):
        family = MODULE.load_json(MODULE.DEVICE_INTERACTION_STATE_OVERRIDES_PATH)
        expected_concepts = {
            "MODE_STANDBY",
            "SENSOR_OCCUPIED",
            "VIBRATION",
        }
        self.assertEqual(set(family), expected_concepts)
        self.assertEqual(
            self.audit["reviewed_families"]["device_interaction_state"],
            len(expected_concepts),
        )
        low_confidence = {
            item["concept"] for item in self.audit["low_confidence_concepts"]
        }
        self.assertTrue(expected_concepts.isdisjoint(low_confidence))
        material = MODULE.load_json(MODULE.MATERIAL_PATH)
        family_wire_identities = {
            name
            for name in material
            if MODULE.concept_for(name) in expected_concepts
        }
        self.assertEqual(len(family_wire_identities), 12)
        for name in family_wire_identities:
            self.assertEqual(self.entries[name]["confidence"], "reviewed")
            self.assertEqual(self.entries[name]["source"], "reviewed_override")

    def test_device_interaction_state_semantics_do_not_regress(self):
        expected = {
            "MODE_STANDBY": ("system_symbol", "power"),
            "SENSOR_OCCUPIED": ("system_symbol", "person.wave.2.fill"),
            "VIBRATION": (
                "system_symbol",
                "iphone.homebutton.radiowaves.left.and.right",
            ),
        }
        for material_name, (kind, value) in expected.items():
            self.assertEqual(self.entries[material_name]["kind"], kind)
            self.assertEqual(self.entries[material_name]["value"], value)

        # Radiowaves alone do not retain prediction or playback semantics.
        for material_name in ("ONLINE_PREDICTION", "TAP_AND_PLAY"):
            self.assertNotEqual(self.entries[material_name]["confidence"], "reviewed")

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
