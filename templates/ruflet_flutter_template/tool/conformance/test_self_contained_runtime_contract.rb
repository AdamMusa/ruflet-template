# frozen_string_literal: true

require "minitest/autorun"

class SelfContainedRuntimeContractTest < Minitest::Test
  TEMPLATE_ROOT = File.expand_path("../..", __dir__)

  def test_apple_plists_do_not_hardcode_a_project_name
    %w[ios/Runner/Info.plist macos/Runner/Info.plist].each do |relative_path|
      plist = File.read(File.join(TEMPLATE_ROOT, relative_path))

      refute_includes plist, "RufletEmbeddedProject", relative_path
      refute_includes plist, "<string>ruflet</string>", relative_path
    end
  end

  def test_platform_manifests_delegate_self_contained_startup_to_ruby_runtime
    %w[ios/Runner/Info.plist macos/Runner/Info.plist].each do |relative_path|
      plist = File.read(File.join(TEMPLATE_ROOT, relative_path))

      assert_match(/<key>RufletRuntimeAutostart<\/key>\s*<true\/>/, plist, relative_path)
    end

    manifest = File.read(File.join(TEMPLATE_ROOT, "android/app/src/main/AndroidManifest.xml"))
    assert_match(
      /android:name="ruflet\.runtime\.autostart"\s+android:value="true"/,
      manifest
    )
  end

  def test_self_entrypoint_resolves_the_platform_started_runtime
    source = File.read(File.join(TEMPLATE_ROOT, "lib/main.self.dart"))

    assert_includes source, "RufletRuntime.serverUrl()"
    # A packaged app talks to its runtime over the in-process bridge rather
    # than a loopback port.
    assert_includes source, "inprocess://"
  end
end
