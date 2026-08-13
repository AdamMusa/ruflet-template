#!/usr/bin/env python3
"""Generate the explicit Flet Material -> Apple native icon corpus.

The Flet wire protocol identifies Material icons by integer/codepoint.  Those
identities are accepted on Apple for protocol compatibility, but their artwork
must be a bundled Cupertino glyph or an SF Symbol available at the iOS 15
and macOS 13.1 deployment floors. This tool expands every pinned wire identity
into an explicit, auditable mapping. It never emits a Material-font glyph, a
generic placeholder, or an unresolved entry.

Generation uses pinned/auditable inputs:

* material_icons.json -- the Flet 0.80.5 wire corpus;
* cupertino_glyphs.json -- the bundled Flutter Cupertino glyph corpus;
* material_semantics.json -- a checked-in snapshot of Google's official icon
  tags for the 2,235 Flet concepts;
* overrides.json -- reviewed vocabulary differences between Material and
  Apple.
* navigation_travel_overrides.json -- the reviewed navigation/transit family.
* action_overrides.json -- the reviewed platform-neutral action family.
* maps_places_overrides.json -- the reviewed maps, places, and amenities family.
* device_hardware_overrides.json -- the reviewed device and peripheral family.
* social_activities_overrides.json -- the reviewed social and activities family.
* image_media_overrides.json -- the reviewed photography and image-media family.
* text_editor_overrides.json -- the reviewed document and text-editor family.
* home_household_overrides.json -- the reviewed home and household family.
* communication_overrides.json -- the reviewed calls and messaging family.
* business_commerce_overrides.json -- the reviewed business and commerce family.
* travel_amenity_overrides.json -- the reviewed remaining travel amenity family.
* audio_video_overrides.json -- the reviewed audio and video family.
* notification_status_overrides.json -- the reviewed notification/status family.
* file_content_overrides.json -- the reviewed file and content family.
* interface_action_overrides.json -- the reviewed interface-action family.
* advanced_image_editing_overrides.json -- reviewed advanced image editing.
* local_service_transit_overrides.json -- reviewed local services and transit.

The installed public Apple symbol metadata is used only to choose and validate
native symbols available at both deployment floors. Private and restricted
symbols are excluded. The generated resource is checked in, so package builds
never depend on framework metadata.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import plistlib
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


TOOL_DIR = Path(__file__).resolve().parent
PACKAGE_DIR = TOOL_DIR.parents[1]
CATALOG_DIR = PACKAGE_DIR / "Sources" / "RufletEngine" / "Resources" / "IconCatalog"
MATERIAL_PATH = CATALOG_DIR / "material_icons.json"
CUPERTINO_PATH = CATALOG_DIR / "cupertino_glyphs.json"
OUTPUT_PATH = CATALOG_DIR / "material_to_apple.json"
SEMANTICS_PATH = TOOL_DIR / "material_semantics.json"
OVERRIDES_PATH = TOOL_DIR / "overrides.json"
NAVIGATION_TRAVEL_OVERRIDES_PATH = TOOL_DIR / "navigation_travel_overrides.json"
ACTION_OVERRIDES_PATH = TOOL_DIR / "action_overrides.json"
MAPS_PLACES_OVERRIDES_PATH = TOOL_DIR / "maps_places_overrides.json"
DEVICE_HARDWARE_OVERRIDES_PATH = TOOL_DIR / "device_hardware_overrides.json"
SOCIAL_ACTIVITIES_OVERRIDES_PATH = TOOL_DIR / "social_activities_overrides.json"
IMAGE_MEDIA_OVERRIDES_PATH = TOOL_DIR / "image_media_overrides.json"
TEXT_EDITOR_OVERRIDES_PATH = TOOL_DIR / "text_editor_overrides.json"
HOME_HOUSEHOLD_OVERRIDES_PATH = TOOL_DIR / "home_household_overrides.json"
COMMUNICATION_OVERRIDES_PATH = TOOL_DIR / "communication_overrides.json"
BUSINESS_COMMERCE_OVERRIDES_PATH = TOOL_DIR / "business_commerce_overrides.json"
TRAVEL_AMENITY_OVERRIDES_PATH = TOOL_DIR / "travel_amenity_overrides.json"
AUDIO_VIDEO_OVERRIDES_PATH = TOOL_DIR / "audio_video_overrides.json"
NOTIFICATION_STATUS_OVERRIDES_PATH = TOOL_DIR / "notification_status_overrides.json"
FILE_CONTENT_OVERRIDES_PATH = TOOL_DIR / "file_content_overrides.json"
INTERFACE_ACTION_OVERRIDES_PATH = TOOL_DIR / "interface_action_overrides.json"
ADVANCED_IMAGE_EDITING_OVERRIDES_PATH = (
    TOOL_DIR / "advanced_image_editing_overrides.json"
)
LOCAL_SERVICE_TRANSIT_OVERRIDES_PATH = (
    TOOL_DIR / "local_service_transit_overrides.json"
)
AUDIT_PATH = TOOL_DIR / "material_to_apple_audit.json"

CORE_GLYPHS = Path(
    "/System/Library/PrivateFrameworks/SFSymbols.framework/Versions/A/Resources/"
    "CoreGlyphs.bundle/Contents/Resources"
)
DEPLOYMENT_FLOORS = {"iOS": "15.0", "macOS": "13.1"}

STYLE_SUFFIXES = ("_OUTLINED", "_ROUNDED", "_SHARP")
PLACEHOLDERS = {"questionmark.square.dashed"}
LOCALE_SUFFIXES = {"ar", "he", "hi"}

# Token equivalence is platform vocabulary, not a fallback target.  It helps
# rank Apple candidates; the chosen target is still serialized explicitly and
# receives a confidence grade in the audit report.
TOKEN_EQUIVALENTS = {
    "account": "person",
    "accounts": "people",
    "add": "plus",
    "alert": "warning",
    "analytics": "chart",
    "back": "left",
    "bookmark": "bookmark",
    "calendar": "date",
    "cancel": "close",
    "chart": "graph",
    "checkmark": "check",
    "cog": "settings",
    "create": "edit",
    "date": "date",
    "delete": "trash",
    "done": "check",
    "email": "mail",
    "envelope": "mail",
    "favorite": "heart",
    "gear": "settings",
    "gearshape": "settings",
    "graph": "graph",
    "home": "house",
    "image": "photo",
    "location": "place",
    "magnifyingglass": "search",
    "mappin": "pin",
    "message": "chat",
    "minus": "remove",
    "notification": "bell",
    "notifications": "bell",
    "people": "people",
    "person": "person",
    "picture": "photo",
    "plus": "plus",
    "profile": "person",
    "remove": "remove",
    "schedule": "clock",
    "settings": "settings",
    "trash": "trash",
    "user": "person",
    "users": "people",
}

STYLE_TOKENS = {"fill", "filled", "outline", "outlined", "round", "rounded", "sharp"}
WEAK_TOKENS = {
    "action", "app", "application", "content", "display", "feature", "icon",
    "interface", "item", "material", "object", "option", "symbol", "system",
    "tool", "ui", "ux", "view", "web", "website",
}


@dataclass(frozen=True)
class Target:
    kind: str
    value: str
    source: str
    score: float
    reason: str


@dataclass(frozen=True)
class Candidate:
    kind: str
    value: str
    canonical: str
    name_tokens: frozenset[str]
    search_tokens: frozenset[str]


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def canonical(value: str) -> str:
    value = value.lower().replace("cupertinoicons.", "").replace("icons.", "")
    return re.sub(r"[^a-z0-9]+", "_", value).strip("_")


def concept_for(material_name: str) -> str:
    for suffix in STYLE_SUFFIXES:
        if material_name.endswith(suffix):
            return material_name[: -len(suffix)]
    return material_name


def raw_tokens(value: str) -> list[str]:
    normalized = canonical(value)
    parts = re.findall(r"[a-z]+|\d+", normalized)
    return [part for part in parts if part not in STYLE_TOKENS]


def normalize_token(token: str) -> str:
    token = TOKEN_EQUIVALENTS.get(token, token)
    # Conservative English morphology for catalog labels.
    if len(token) > 4 and token.endswith("ies"):
        token = token[:-3] + "y"
    elif len(token) > 4 and token.endswith("s") and not token.endswith("ss"):
        token = token[:-1]
    return TOKEN_EQUIVALENTS.get(token, token)


def tokens(value: str) -> frozenset[str]:
    return frozenset(normalize_token(token) for token in raw_tokens(value))


def phrase_tokens(values: Iterable[str]) -> frozenset[str]:
    result: set[str] = set()
    for value in values:
        result.update(tokens(value))
    return frozenset(result)


def plist(path: Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        return plistlib.load(handle)


def version_tuple(version: str) -> tuple[int, ...]:
    try:
        return tuple(int(part) for part in str(version).split("."))
    except ValueError:
        return (9999,)


def apple_metadata() -> tuple[
    dict[str, str],
    dict[str, list[str]],
    dict[str, dict[str, str]],
    dict[str, str],
    dict[str, str],
]:
    """Load Apple's public symbol metadata and usage restrictions.

    `CoreGlyphsPrivate.bundle` deliberately is not an input: its names are not
    part of the public `Image(systemName:)` contract and render as empty images
    on supported Apple releases.
    """
    availability_path = CORE_GLYPHS / "name_availability.plist"
    search_path = CORE_GLYPHS / "symbol_search.plist"
    restrictions_path = CORE_GLYPHS / "symbol_restrictions.strings"
    if not availability_path.exists() or not search_path.exists() or not restrictions_path.exists():
        raise RuntimeError("Apple public SF Symbols metadata was not found")

    availability_metadata = plist(availability_path)
    availability = availability_metadata.get("symbols", {})
    releases = availability_metadata.get("year_to_release", {})
    search = plist(search_path)
    restrictions = plist(restrictions_path)
    hashes: dict[str, str] = {}
    for path in (availability_path, search_path, restrictions_path):
        hashes[str(path)] = sha256(path)
    return availability, search, releases, restrictions, hashes


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def deployment_symbols(
    availability: dict[str, str],
    releases: dict[str, dict[str, str]],
) -> set[str]:
    result: set[str] = set()
    for name, release_key in availability.items():
        platform_releases = releases.get(str(release_key), {})
        if any(
            platform not in platform_releases
            or version_tuple(platform_releases[platform]) > version_tuple(floor)
            for platform, floor in DEPLOYMENT_FLOORS.items()
        ):
            continue
        if name.rsplit(".", 1)[-1] in LOCALE_SUFFIXES:
            continue
        result.add(name)
    return result


def candidate_catalog(
    cupertino: dict[str, int], symbols: set[str], search: dict[str, list[str]]
) -> list[Candidate]:
    result: list[Candidate] = []
    for name in sorted(cupertino):
        normalized = canonical(name)
        result.append(
            Candidate(
                kind="cupertino_glyph",
                value=name,
                canonical=normalized,
                name_tokens=tokens(normalized),
                search_tokens=frozenset(),
            )
        )
    for name in sorted(symbols):
        result.append(
            Candidate(
                kind="system_symbol",
                value=name,
                canonical=canonical(name),
                name_tokens=tokens(name),
                search_tokens=phrase_tokens(search.get(name, [])),
            )
        )
    return result


def idf_weights(candidates: list[Candidate]) -> dict[str, float]:
    frequencies: Counter[str] = Counter()
    for candidate in candidates:
        frequencies.update(candidate.name_tokens | candidate.search_tokens)
    total = len(candidates) + 1
    return {
        token: 1.0 + math.log(total / (count + 1))
        for token, count in frequencies.items()
    }


def reviewed_override(
    concept: str,
    overrides: dict[str, dict[str, str]],
    cupertino: dict[str, int],
    symbols: set[str],
) -> Target | None:
    item = overrides.get(concept)
    if item is None:
        return None
    kind = item["kind"]
    value = item["value"]
    if kind == "cupertino_glyph" and value not in cupertino:
        raise ValueError(f"Override {concept} names absent Cupertino glyph {value}")
    if kind == "system_symbol" and value not in symbols:
        # A reviewed entry may reference a newer symbol.  Do not silently make
        # the deployment floor invalid; let the scorer choose an iOS 15 target
        # and surface the concept for audit.
        return None
    if item.get("status") == "review_required":
        return Target(
            kind, value, "manual_review_required", 0.5,
            item.get("rationale", "explicit target pending semantic review"),
        )
    return Target(kind, value, "reviewed_override", 1.0, item.get("rationale", "reviewed"))


def load_reviewed_overrides() -> tuple[
    dict[str, dict[str, str]], dict[str, str], dict[str, Path]
]:
    """Merge disjoint, human-reviewed semantic families deterministically."""
    paths = {
        "general": OVERRIDES_PATH,
        "navigation_travel": NAVIGATION_TRAVEL_OVERRIDES_PATH,
        "action": ACTION_OVERRIDES_PATH,
        "maps_places": MAPS_PLACES_OVERRIDES_PATH,
        "device_hardware": DEVICE_HARDWARE_OVERRIDES_PATH,
        "social_activities": SOCIAL_ACTIVITIES_OVERRIDES_PATH,
        "image_media": IMAGE_MEDIA_OVERRIDES_PATH,
        "text_editor": TEXT_EDITOR_OVERRIDES_PATH,
        "home_household": HOME_HOUSEHOLD_OVERRIDES_PATH,
        "communication": COMMUNICATION_OVERRIDES_PATH,
        "business_commerce": BUSINESS_COMMERCE_OVERRIDES_PATH,
        "travel_amenity": TRAVEL_AMENITY_OVERRIDES_PATH,
        "audio_video": AUDIO_VIDEO_OVERRIDES_PATH,
        "notification_status": NOTIFICATION_STATUS_OVERRIDES_PATH,
        "file_content": FILE_CONTENT_OVERRIDES_PATH,
        "interface_action": INTERFACE_ACTION_OVERRIDES_PATH,
        "advanced_image_editing": ADVANCED_IMAGE_EDITING_OVERRIDES_PATH,
        "local_service_transit": LOCAL_SERVICE_TRANSIT_OVERRIDES_PATH,
    }
    merged: dict[str, dict[str, str]] = {}
    families: dict[str, str] = {}
    for family, path in paths.items():
        for concept, item in load_json(path).items():
            if concept in merged:
                raise ValueError(
                    f"Reviewed icon concept {concept} is duplicated in "
                    f"{families[concept]} and {family}"
                )
            merged[concept] = item
            families[concept] = family
    return merged, families, paths


def exact_target(
    concept: str,
    candidates_by_canonical: dict[str, list[Candidate]],
) -> Target | None:
    normalized = canonical(concept)
    exact = candidates_by_canonical.get(normalized, [])
    if not exact:
        dotted = normalized.replace("_", ".")
        exact = [candidate for candidate in candidates_by_canonical.get(canonical(dotted), []) if candidate.value == dotted]
    if not exact:
        return None
    # The bundled Cupertino family is the Apple-native vocabulary Ruflet ships
    # itself, so it wins an exact tie over an SF Symbol.
    chosen = sorted(exact, key=lambda item: (item.kind != "cupertino_glyph", item.value))[0]
    return Target(chosen.kind, chosen.value, "exact_apple_name", 0.99, "canonical name equality")


def score_candidate(
    concept_tokens: frozenset[str],
    semantic_tokens: frozenset[str],
    candidate: Candidate,
    weights: dict[str, float],
) -> tuple[float, str]:
    target_tokens = candidate.name_tokens
    vocabulary = concept_tokens | semantic_tokens
    name_overlap = concept_tokens & target_tokens
    semantic_overlap = vocabulary & (target_tokens | candidate.search_tokens)
    if not semantic_overlap:
        return -100.0, "no vocabulary overlap"

    def weight(values: Iterable[str]) -> float:
        return sum(weights.get(value, 1.0) for value in values)

    concept_recall = weight(name_overlap) / max(weight(concept_tokens), 1.0)
    semantic_recall = weight(semantic_overlap) / max(weight(concept_tokens | target_tokens), 1.0)
    name_precision = weight(name_overlap) / max(weight(target_tokens), 1.0)
    score = 5.0 * concept_recall + 2.0 * semantic_recall + 1.5 * name_precision

    # Candidate-only direction/number tokens are dangerous.  A left arrow is
    # not interchangeable with a right arrow, and 10 is not 100.
    significant_extra = {
        token for token in target_tokens - vocabulary
        if token not in STYLE_TOKENS and token not in WEAK_TOKENS
    }
    score -= 0.55 * weight(significant_extra)
    if candidate.kind == "cupertino_glyph":
        score += 0.08
    if candidate.value.endswith(".fill") and "fill" not in concept_tokens:
        score -= 0.04
    reason = (
        f"name={sorted(name_overlap)} semantic={sorted(semantic_overlap)} "
        f"extra={sorted(significant_extra)}"
    )
    return score, reason


def inferred_target(
    concept: str,
    semantic: dict[str, Any],
    candidates: list[Candidate],
    inverted: dict[str, set[int]],
    weights: dict[str, float],
) -> Target:
    concept_tokens = tokens(concept)
    tags = semantic.get("tags", [])
    categories = semantic.get("categories", [])
    semantic_tokens = phrase_tokens([*tags, *categories]) - WEAK_TOKENS
    query = concept_tokens | semantic_tokens
    candidate_indices: set[int] = set()
    for token in query:
        candidate_indices.update(inverted.get(token, set()))
    if not candidate_indices:
        raise ValueError(f"No Apple candidate shares semantic vocabulary with {concept}")

    ranked: list[tuple[float, str, Candidate]] = []
    for index in candidate_indices:
        candidate = candidates[index]
        score, reason = score_candidate(concept_tokens, semantic_tokens, candidate, weights)
        ranked.append((score, reason, candidate))
    ranked.sort(key=lambda item: (-item[0], item[2].kind != "cupertino_glyph", item[2].value))
    score, reason, candidate = ranked[0]
    if score <= -100:
        raise ValueError(f"No semantic Apple target for {concept}")
    # Logistic normalization makes the grade stable and human-readable; the
    # raw rationale remains in the concept audit for review.
    confidence = 1.0 / (1.0 + math.exp(-(score - 2.6)))
    return Target(candidate.kind, candidate.value, "semantic_rank", round(confidence, 4), reason)


def confidence_grade(target: Target) -> str:
    if target.source == "reviewed_override":
        return "reviewed"
    if target.source == "exact_apple_name":
        return "exact"
    if target.score >= 0.85:
        return "high"
    if target.score >= 0.65:
        return "medium"
    return "low"


def generate() -> tuple[dict[str, Any], dict[str, Any]]:
    material: dict[str, int] = load_json(MATERIAL_PATH)
    cupertino: dict[str, int] = load_json(CUPERTINO_PATH)
    semantics: dict[str, dict[str, Any]] = load_json(SEMANTICS_PATH)
    overrides, override_families, override_paths = load_reviewed_overrides()
    availability, search, releases, restrictions, metadata_hashes = apple_metadata()
    deployment_available_symbols = deployment_symbols(availability, releases)
    symbols = deployment_available_symbols - set(restrictions)
    candidates = candidate_catalog(cupertino, symbols, search)
    weights = idf_weights(candidates)
    candidates_by_canonical: dict[str, list[Candidate]] = defaultdict(list)
    inverted: dict[str, set[int]] = defaultdict(set)
    for index, candidate in enumerate(candidates):
        candidates_by_canonical[candidate.canonical].append(candidate)
        for token in candidate.name_tokens | candidate.search_tokens:
            inverted[token].add(index)

    concepts = sorted({concept_for(name) for name in material}, key=lambda name: material.get(name, 10**9))
    missing_semantics = [concept for concept in concepts if concept not in semantics]
    if missing_semantics:
        raise ValueError(f"Missing official semantic metadata for {len(missing_semantics)} concepts: {missing_semantics[:20]}")

    concept_targets: dict[str, Target] = {}
    unrankable: list[str] = []
    for concept in concepts:
        target = reviewed_override(concept, overrides, cupertino, symbols)
        if target is None:
            target = exact_target(concept, candidates_by_canonical)
        if target is None:
            try:
                target = inferred_target(concept, semantics[concept], candidates, inverted, weights)
            except ValueError:
                unrankable.append(concept)
                continue
        if target.kind == "system_symbol" and target.value in PLACEHOLDERS:
            raise ValueError(f"Placeholder target selected for {concept}")
        concept_targets[concept] = target

    if unrankable:
        raise ValueError(
            f"No semantic Apple candidate for {len(unrankable)} concepts: {unrankable}"
        )

    entries: dict[str, Any] = {}
    for name, _code in sorted(material.items(), key=lambda item: item[1]):
        concept = concept_for(name)
        target = concept_targets[concept]
        entries[name] = {
            "kind": target.kind,
            "value": target.value,
            "concept": concept,
            "confidence": confidence_grade(target),
            "source": target.source,
        }

    grade_counts = Counter(confidence_grade(target) for target in concept_targets.values())
    source_counts = Counter(target.source for target in concept_targets.values())
    reviewed_family_counts = Counter(
        override_families[concept]
        for concept, target in concept_targets.items()
        if target.source == "reviewed_override"
    )
    target_counts = Counter((target.kind, target.value) for target in concept_targets.values())
    low_confidence = []
    for concept, target in concept_targets.items():
        if confidence_grade(target) not in {"low", "medium"}:
            continue
        low_confidence.append(
            {
                "concept": concept,
                "target": {"kind": target.kind, "value": target.value},
                "confidence": target.score,
                "grade": confidence_grade(target),
                "reason": target.reason,
                "tags": semantics[concept].get("tags", []),
            }
        )
    low_confidence.sort(key=lambda item: (item["grade"] != "low", item["confidence"], item["concept"]))

    audit = {
        "schema": 1,
        "material_wire_identities": len(material),
        "semantic_concepts": len(concepts),
        "unresolved": 0,
        "placeholder_targets": 0,
        "deployment_floor": dict(DEPLOYMENT_FLOORS),
        "public_sf_symbols_at_floor": len(deployment_available_symbols),
        "restricted_sf_symbols_excluded": len(set(restrictions) & deployment_available_symbols),
        "input_sha256": {
            "material_icons.json": sha256(MATERIAL_PATH),
            "cupertino_glyphs.json": sha256(CUPERTINO_PATH),
            "material_semantics.json": sha256(SEMANTICS_PATH),
            **{path.name: sha256(path) for path in override_paths.values()},
            **metadata_hashes,
        },
        "sources": dict(sorted(source_counts.items())),
        "reviewed_families": dict(sorted(reviewed_family_counts.items())),
        "confidence_grades": dict(sorted(grade_counts.items())),
        "unique_apple_targets": len(target_counts),
        "most_reused_targets": [
            {"kind": kind, "value": value, "concept_count": count}
            for (kind, value), count in target_counts.most_common(50)
        ],
        "low_confidence_count": len(low_confidence),
        "low_confidence_concepts": low_confidence,
    }
    return entries, audit


def render(value: Any) -> str:
    return json.dumps(value, indent=2, sort_keys=False, ensure_ascii=False) + "\n"


def validate(entries: dict[str, Any], audit: dict[str, Any]) -> None:
    material: dict[str, int] = load_json(MATERIAL_PATH)
    cupertino: dict[str, int] = load_json(CUPERTINO_PATH)
    availability, _search, releases, restrictions, _hashes = apple_metadata()
    symbols = deployment_symbols(availability, releases) - set(restrictions)
    if set(entries) != set(material):
        raise AssertionError("Generated keys do not exactly match the 8,825-name Flet corpus")
    if len(entries) != 8_825:
        raise AssertionError(f"Expected 8,825 entries, got {len(entries)}")
    for name, entry in entries.items():
        if entry["kind"] == "cupertino_glyph":
            if entry["value"] not in cupertino:
                raise AssertionError(f"{name}: invalid Cupertino glyph {entry['value']}")
        elif entry["kind"] == "system_symbol":
            if entry["value"] not in symbols:
                raise AssertionError(
                    f"{name}: SF Symbol is private, restricted, or unavailable at "
                    f"{DEPLOYMENT_FLOORS}: {entry['value']}"
                )
            if entry["value"] in PLACEHOLDERS:
                raise AssertionError(f"{name}: placeholder artwork is forbidden")
        else:
            raise AssertionError(f"{name}: invalid target kind {entry['kind']}")
        if entry["concept"] != concept_for(name):
            raise AssertionError(f"{name}: incorrect style-collapse concept")

    critical = {
        "ROCKET_LAUNCH": ("cupertino_glyph", "ROCKET"),
        "HUB": ("cupertino_glyph", "CIRCLE_GRID_HEX_FILL"),
        "HOME": ("cupertino_glyph", "HOME"),
        "PHOTO": ("cupertino_glyph", "PHOTO"),
        "GRID_VIEW": ("cupertino_glyph", "SQUARE_GRID_2X2"),
        "SHOW_CHART": ("cupertino_glyph", "GRAPH_SQUARE"),
    }
    for name, expected in critical.items():
        actual = (entries[name]["kind"], entries[name]["value"])
        if actual != expected:
            raise AssertionError(f"{name}: expected {expected}, got {actual}")
    if audit["unresolved"] != 0 or audit["placeholder_targets"] != 0:
        raise AssertionError("Audit reports unresolved or placeholder targets")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify checked-in outputs are current")
    args = parser.parse_args()
    entries, audit = generate()
    validate(entries, audit)
    expected_entries = render(entries)
    expected_audit = render(audit)
    if args.check:
        failures: list[str] = []
        if not OUTPUT_PATH.exists() or OUTPUT_PATH.read_text(encoding="utf-8") != expected_entries:
            failures.append(str(OUTPUT_PATH))
        if not AUDIT_PATH.exists() or AUDIT_PATH.read_text(encoding="utf-8") != expected_audit:
            failures.append(str(AUDIT_PATH))
        if failures:
            print("Generated icon artifacts are stale: " + ", ".join(failures), file=sys.stderr)
            return 1
        print(f"OK: {len(entries)} explicit mappings; {audit['low_confidence_count']} concepts need audit")
        return 0
    OUTPUT_PATH.write_text(expected_entries, encoding="utf-8")
    AUDIT_PATH.write_text(expected_audit, encoding="utf-8")
    print(f"Wrote {len(entries)} explicit mappings to {OUTPUT_PATH}")
    print(f"Wrote concept audit ({audit['low_confidence_count']} low/medium) to {AUDIT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
