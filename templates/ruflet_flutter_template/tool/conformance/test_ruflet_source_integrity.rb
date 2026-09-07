# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "../sync_ruflet_source"

class RufletSourceIntegrityTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  MANIFEST_PATH = File.join(__dir__, "ruflet_source_integrity.json")

  def manifest
    @manifest ||= JSON.parse(File.read(MANIFEST_PATH))
  end

  def test_manifest_pins_a_source_commit_and_every_distributable_file
    assert_equal 5, manifest.fetch("manifest_version")
    assert_equal "ruflet-engine", manifest.fetch("package_name")
    assert_match(/\A[0-9a-f]{40}\z/, manifest.fetch("source_ref"))
    assert_equal "packages", manifest.fetch("source_package")
    assert_equal 20, manifest.fetch("packages").length
    %w[lib/ruflet.dart pubspec.yaml LICENSE
       vendor/flutter_markdown_plus/LICENSE vendor/flutter_math_fork/LICENSE].each do |path|
      assert manifest.fetch("files").key?("ruflet/#{path}"), "Missing distributable source/license: #{path}"
    end
    assert_match(/verified/, RufletSourceSync.new(template: ROOT).check)
  end

  def test_every_file_is_exact_committed_engine_source_including_transport
    files = manifest.fetch("files")
    assert files.key?("ruflet/lib/src/transport/ruflet_backend_channel_in_process.dart")
    files.each do |path, entry|
      assert RufletSourceSync.managed?(path), "Excluded file in manifest: #{path}"
      assert_match(/\A[0-9a-f]{64}\z/, entry.fetch("vendored_sha256"))
      assert_equal "exact_source", entry.fetch("classification")
      assert_equal path, entry.fetch("source_path")
      assert_equal entry.fetch("source_sha256"), entry.fetch("vendored_sha256"), path
      assert_match(/\A[0-9a-f]{40}\z/, entry.fetch("source_git_blob"))
    end
  end
end
