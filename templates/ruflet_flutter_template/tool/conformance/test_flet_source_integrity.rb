# frozen_string_literal: true

require "digest"
require "json"
require "minitest/autorun"

class FletSourceIntegrityTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  VENDORED_ROOT = File.join(ROOT, "flet_packages")
  MANIFEST_PATH = File.join(__dir__, "flet_source_integrity.json")
  EXPECTED_REF = "67a9763da3bd2611bbb7626c3a1ec5e9d30fc965"

  def manifest
    @manifest ||= JSON.parse(File.read(MANIFEST_PATH))
  end

  def test_manifest_pins_the_exact_flet_release
    assert_equal 1, manifest.fetch("manifest_version")
    assert_equal "0.80.5", manifest.fetch("flet_version")
    assert_equal EXPECTED_REF, manifest.fetch("flet_ref")
    assert_equal 262, manifest.dig("summary", "source_files")
    assert_equal 4, manifest.dig("summary", "test_files")
    assert_equal 264, manifest.dig("summary", "exact_upstream")
    assert_equal 2, manifest.dig("summary", "reviewed_ruflet_patches")
  end

  def test_vendored_file_set_and_hashes_match_the_reviewed_inventory
    files = manifest.fetch("files")
    discovered = Dir.glob(File.join(VENDORED_ROOT, "flet", "{lib/src,test}", "**", "*.dart"))
      .sort
      .to_h { |path| [path.delete_prefix(VENDORED_ROOT + "/"), path] }

    assert_equal files.keys, discovered.keys,
      "Pinned Flet source/test additions and removals must be reviewed and regenerated"

    files.each do |relative, entry|
      actual = Digest::SHA256.file(discovered.fetch(relative)).hexdigest
      assert_equal entry.fetch("vendored_sha256"), actual, "Vendored content drifted: #{relative}"
      if entry.fetch("classification") == "exact_upstream"
        assert_equal entry.fetch("upstream_sha256"), actual, "Exact upstream file diverged: #{relative}"
      end
    end
  end

  def test_every_divergence_is_an_explicit_non_wildcard_patch
    files = manifest.fetch("files")
    divergent = files.filter_map do |relative, entry|
      relative if entry.fetch("upstream_sha256") != entry.fetch("vendored_sha256")
    end
    patches = manifest.fetch("patches")

    assert_equal patches.keys.sort, divergent.sort
    assert_equal [
      "flet/lib/src/controls/banner.dart",
      "flet/lib/src/controls/snack_bar.dart"
    ], patches.keys.sort
    patches.each do |relative, detail|
      refute_equal "*", relative
      refute_empty detail.fetch("reason").strip
      refute_empty detail.fetch("ruflet_commit").strip
      assert_equal "reviewed_ruflet_patch", files.dig(relative, "classification")
    end
  end
end
