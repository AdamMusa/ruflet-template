# frozen_string_literal: true

require "minitest/autorun"
require_relative "ruflet_namespace"

class RufletNamespaceTest < Minitest::Test
  def test_package_paths_symbols_and_environment_names
    original = "package:flet/flet.dart FletApp getFletPath fletJS FLET_WEB_PATH flet_audio/flet_audio.dart"
    expected = "package:ruflet/ruflet.dart RufletApp getRufletPath rufletJS RUFLET_WEB_PATH ruflet_audio/ruflet_audio.dart"
    assert_equal expected, RufletNamespace.rename(original)
  end

  def test_is_idempotent_and_does_not_corrupt_existing_ruflet_or_leaflet
    original = "RufletApp ruflet RUFLET_DATA ruflet_qrcode_scanner Leaflet leaflet"
    assert_equal original, RufletNamespace.rename(original)
    renamed = RufletNamespace.rename("FletStyleTheme package:flet/flet.dart")
    assert_equal renamed, RufletNamespace.rename(renamed)
    assert_equal '\nruflet_ads: any', RufletNamespace.rename('\nflet_ads: any')
  end

  def test_preserves_real_urls_and_copyright_attribution
    original = "// Copyright 2026 Flet contributors\n// Flet comes from https://github.com/flet-dev/flet\n"
    assert_equal "// Copyright 2026 Flet contributors\n// Ruflet comes from https://github.com/flet-dev/flet\n",
      RufletNamespace.rewrite("lib/flet.dart", original)
    assert_equal original, RufletNamespace.rewrite("LICENSE", original)
    assert_equal original, RufletNamespace.rewrite("utils/FLUTTER_LICENSE", original)
  end

  def test_preserves_binary_and_non_utf8_assets
    ["\x00flet".b, "\xffflet".b].each do |bytes|
      assert_equal bytes, RufletNamespace.rewrite("font.ttf", bytes)
    end
  end

  def test_core_manifest_identifies_our_package_and_repository
    result = RufletNamespace.rewrite("pubspec.yaml",
      "name: flet\ndescription: Flet engine\nhomepage: https://flet.dev\nrepository: https://github.com/flet-dev/flet\n")
    assert_includes result, "name: ruflet\n"
    assert_includes result, "Ruby applications"
    assert_includes result, "repository: https://github.com/AdamMusa/ruflet-template"
  end
end
