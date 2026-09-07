# frozen_string_literal: true

require "minitest/autorun"
require_relative "sync_ruflet_source"

class SyncRufletSourceTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir("ruflet-sync-fixture-")
    @source = File.join(@tmp, "source")
    @template = File.join(@tmp, "template")
    FileUtils.mkdir_p(@source)
    git("init", "-q")
    git("config", "user.email", "fixture@example.invalid")
    git("config", "user.name", "Sync fixture")
    source("pubspec.yaml", "name: ruflet\nversion: 0.81.0\n")
    source("lib/ruflet.dart", "export 'original.dart';\nexport 'embedded.dart';\n")
    source("lib/src/ruflet_widget.dart", "class RufletWidget {}\n")
    source("lib/embedded.dart", "reviewed engine transport\n")
    source("test/upstream_test.dart", "test source\n")
    source("vendor/math/lib/math.dart", "math source\n")
    source("vendor/math/assets/font.ttf", "\x00\xfffont".b)
    source("vendor/math/LICENSE", "MIT\n")
    source("vendor/math/.dart_tool/package_config.json", "never copied\n")
    source("vendor/math/build/test.dill", "never copied\n")
    source("vendor/math/pubspec.lock", "never copied\n")
    source("third_party/LICENSE", "third-party license\n")
    commit
    target("lib/embedded.dart", "reviewed local transport\n")
    write(File.join(@template, "pubspec.yaml"), "name: client\n  # #{'0' * 40}. No git/Python dependency.\nruflet_ads: user-owned\n")
    @sync = RufletSourceSync.new(template: @template, source: @source)
    @backups = []
  end

  def teardown
    @backups.each { |path| FileUtils.remove_entry(path) if File.directory?(path) }
    FileUtils.remove_entry(@tmp)
  end

  def write(path, bytes)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, bytes)
  end

  def source(path, bytes)
    write(File.join(@source, "packages/ruflet", path), bytes)
  end

  def target(path, bytes)
    write(File.join(@template, "ruflet_packages/ruflet", path), bytes)
  end

  def git(*args)
    output, error, status = Open3.capture3("git", "-C", @source, *args)
    raise error unless status.success?
    output
  end

  def commit
    git("add", ".")
    git("commit", "-qm", "fixture")
  end

  def sync(initial: true)
    result = @sync.sync(initialize_inventory: initial)
    @backups << result[/Recoverable originals: (.+)$/, 1] if result.include?("Recoverable originals:")
    result
  end

  def test_tracks_exact_engine_blobs_including_transport_assets_and_no_caches
    sync
    assert_match(/verified/, @sync.check)
    assert_match(/verified/, RufletSourceSync.new(template: @template).check)
    files = @sync.manifest.fetch("files")
    assert_equal "exact_source", files.dig("ruflet/lib/ruflet.dart", "classification")
    assert_equal "exact_source", files.dig("ruflet/lib/embedded.dart", "classification")
    assert_equal "exact_source", files.dig("ruflet/lib/src/ruflet_widget.dart", "classification")
    assert_equal "ruflet/lib/src/ruflet_widget.dart", files.dig("ruflet/lib/src/ruflet_widget.dart", "source_path")
    assert_equal "class RufletWidget {}\n", File.read(File.join(@template, "ruflet_packages/ruflet/lib/src/ruflet_widget.dart"))
    assert_equal "\x00\xfffont".b, File.binread(File.join(@template, "ruflet_packages/ruflet/vendor/math/assets/font.ttf"))
    refute files.keys.any? { |path| path.include?(".dart_tool") || path.include?("build/") || path.end_with?("pubspec.lock") }
    assert_includes File.read(File.join(@template, "pubspec.yaml")), "ruflet_ads: user-owned"
    assert_includes File.read(File.join(@template, "pubspec.yaml")), git("rev-parse", "HEAD").strip
  end

  def test_initial_adoption_is_explicit_and_old_files_are_recoverable
    target("lib/obsolete.dart", "old bytes")
    assert_raises(RufletSourceSync::Error) { sync(initial: false) }
    sync
    assert_equal "old bytes", File.read(File.join(@backups.fetch(0), "ruflet/lib/obsolete.dart"))
    refute File.exist?(File.join(@template, "ruflet_packages/ruflet/lib/obsolete.dart"))
  end

  def test_dirty_source_fails_before_writing
    source("lib/ruflet.dart", "uncommitted")
    error = assert_raises(RufletSourceSync::Error) { sync }
    assert_match(/uncommitted/, error.message)
    refute File.exist?(File.join(@template, "ruflet_packages/ruflet/pubspec.yaml"))
  end

  def test_committed_exports_are_copied_without_transforms
    source("lib/ruflet.dart", "export 'different.dart';\n")
    commit
    sync
    assert_equal "export 'different.dart';\n", File.read(File.join(@template, "ruflet_packages/ruflet/lib/ruflet.dart"))
  end

  def test_local_drift_blocks_check_and_later_sync_without_overwrite
    sync
    target("lib/ruflet.dart", "user work")
    assert_raises(RufletSourceSync::Error) { @sync.check }
    assert_raises(RufletSourceSync::Error) { sync }
    assert_equal "user work", File.read(File.join(@template, "ruflet_packages/ruflet/lib/ruflet.dart"))
  end

  def test_source_update_syncs_new_files_removes_old_files_and_refreshes_provenance
    sync
    git("rm", "packages/ruflet/test/upstream_test.dart")
    source("test/new_test.dart", "replacement")
    commit
    assert_raises(RufletSourceSync::Error) { @sync.check }
    sync(initial: false)
    assert_match(/verified/, @sync.check)
    assert_equal "test source\n", File.read(File.join(@backups.last, "ruflet/test/upstream_test.dart"))
  end

  def test_unreviewed_transport_addition_cannot_be_silently_preserved
    sync
    target("lib/embedded.dart", "changed transport")
    error = assert_raises(RufletSourceSync::Error) { sync }
    assert_match(/content drift/, error.message)
  end

  def test_caches_are_ignored_but_unexpected_source_files_are_drift
    sync
    target("vendor/math/.dart_tool/temp", "local cache")
    assert_match(/verified/, @sync.check)
    target("lib/unreviewed.dart", "not in source")
    error = assert_raises(RufletSourceSync::Error) { @sync.check }
    assert_match(/unexpected file/, error.message)
  end

  def test_symlink_in_target_is_not_followed
    outside = File.join(@tmp, "outside")
    write(outside, "user bytes")
    File.symlink(outside, File.join(@template, "ruflet_packages/ruflet/lib/unsafe.dart"))
    assert_raises(RufletSourceSync::Error) { sync }
    assert_equal "user bytes", File.read(outside)
  end

  def test_source_ref_comment_is_checked_without_changing_user_settings
    sync
    path = File.join(@template, "pubspec.yaml")
    write(path, File.read(path).sub(@sync.manifest.fetch("source_ref"), "0" * 40))
    error = assert_raises(RufletSourceSync::Error) { @sync.check }
    assert_match(/source-ref comment drifted/, error.message)
  end

  def test_transport_updates_use_committed_engine_bytes
    sync
    source("lib/embedded.dart", "new engine transport")
    commit
    sync(initial: false)
    assert_equal "new engine transport", File.read(File.join(@template, "ruflet_packages/ruflet/lib/embedded.dart"))
  end

  def test_old_inventory_migration_still_rejects_local_edits
    sync
    path = File.join(@template, "tool/conformance/ruflet_source_integrity.json")
    record = JSON.parse(File.read(path)).merge("manifest_version" => 4)
    record["files"] = record["files"].transform_keys { |key| key.delete_prefix("ruflet/") }
    write(path, JSON.generate(record))
    target("lib/embedded.dart", "user's transport edits")
    error = assert_raises(RufletSourceSync::Error) { sync }
    assert_match(/content drift/, error.message)
  end

  def test_tracked_source_symlink_is_rejected
    File.symlink("ruflet.dart", File.join(@source, "packages/ruflet/lib/link.dart"))
    commit
    error = assert_raises(RufletSourceSync::Error) { sync }
    assert_match(/regular files/, error.message)
  end

  def test_template_parent_symlink_is_rejected
    parent = File.join(@tmp, "linked-packages")
    FileUtils.mkdir_p(parent)
    linked_template = File.join(@tmp, "linked-template")
    FileUtils.mkdir_p(linked_template)
    File.symlink(parent, File.join(linked_template, "ruflet_packages"))
    assert_raises(RufletSourceSync::Error) { RufletSourceSync.new(template: linked_template) }
  end

  def test_extension_packages_native_sources_and_executable_modes_are_pinned
    write(File.join(@source, "packages/ruflet_spinkit/pubspec.yaml"), "name: ruflet_spinkit\n")
    script = File.join(@source, "packages/ruflet_spinkit/ios/setup.sh")
    write(script, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, script)
    commit
    sync
    assert_equal %w[ruflet ruflet_spinkit], @sync.manifest.fetch("packages")
    copy = File.join(@template, "ruflet_packages/ruflet_spinkit/ios/setup.sh")
    assert_equal File.binread(script), File.binread(copy)
    assert_equal 0o755, File.stat(copy).mode & 0o777
    File.chmod(0o644, copy)
    error = assert_raises(RufletSourceSync::Error) { @sync.check }
    assert_match(/file mode drift/, error.message)
  end

  def test_generated_plugin_metadata_and_vendor_download_cache_are_excluded
    sync
    target(".flutter-plugins-dependencies", "generated locally")
    target("vendor/math/.cache/archive.tar.gz", "generated locally")
    assert_match(/verified/, @sync.check)
  end
end
