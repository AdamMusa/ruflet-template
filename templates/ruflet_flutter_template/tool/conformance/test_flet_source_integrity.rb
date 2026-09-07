# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "../sync_flet_source"

class FletSourceIntegrityTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  MANIFEST_PATH = File.join(__dir__, "flet_source_integrity.json")

  def manifest
    @manifest ||= JSON.parse(File.read(MANIFEST_PATH))
  end

  def test_manifest_pins_a_source_commit_and_every_distributable_file
    assert_equal 2, manifest.fetch("manifest_version")
    assert_match(/\A[0-9a-f]{40}\z/, manifest.fetch("flet_ref"))
    assert_equal "packages/flet", manifest.fetch("source_package")
    %w[lib/flet.dart pubspec.yaml LICENSE
       vendor/flutter_markdown_plus/LICENSE vendor/flutter_math_fork/LICENSE].each do |path|
      assert manifest.fetch("files").key?(path), "Missing distributable source/license: #{path}"
    end
    assert_match(/verified/, FletSourceSync.new(template: ROOT).check)
  end

  def test_every_divergence_is_the_explicit_transport_overlay
    files = manifest.fetch("files")
    overlay = JSON.parse(File.read(File.join(ROOT, "tool/flet_transport_overlay.json")))
    patched = files.select { |_, entry| entry.fetch("classification") == "reviewed_transport_overlay" }
    added = files.select { |_, entry| entry.fetch("classification") == "reviewed_template_addition" }
    assert_equal overlay.fetch("patches").keys.sort, patched.keys.sort
    assert_equal overlay.fetch("preserved_files").keys.sort, added.keys.sort
    files.each do |path, entry|
      assert FletSourceSync.managed?(path), "Excluded file in manifest: #{path}"
      assert_match(/\A[0-9a-f]{64}\z/, entry.fetch("vendored_sha256"))
      next unless entry.fetch("classification") == "exact_source"
      assert_equal entry.fetch("source_sha256"), entry.fetch("vendored_sha256"), path
      assert_match(/\A[0-9a-f]{40}\z/, entry.fetch("source_git_blob"))
    end
  end
end
