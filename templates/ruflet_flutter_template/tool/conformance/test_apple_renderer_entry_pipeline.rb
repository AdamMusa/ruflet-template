# frozen_string_literal: true

require "minitest/autorun"

class AppleRendererEntryPipelineTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def source(relative)
    File.read(File.join(ROOT, relative))
  end

  def assert_ordered(text, *fragments)
    positions = fragments.map do |fragment|
      position = text.index(fragment)
      refute_nil position, "missing #{fragment.inspect}"
      position
    end
    assert_equal positions.sort, positions, "expected source fragments in pipeline order"
  end

  def test_native_bridge_is_apple_only_and_passes_the_page_url_unchanged
    bridge = source("lib/native_renderer.dart")

    assert_includes bridge, "defaultTargetPlatform == TargetPlatform.iOS"
    assert_includes bridge, "defaultTargetPlatform == TargetPlatform.macOS"
    assert_ordered(
      bridge,
      "if (!usesNativeAppleRenderer) return false;",
      "_nativeRendererChannel.invokeMethod<bool>('show'",
      "'pageUrl': pageUrl"
    )
  end

  def test_server_mode_switches_apple_immediately_after_url_resolution
    entrypoint = source("lib/main.server.dart")

    assert_ordered(
      entrypoint,
      "final pageUrl = resolveBackendUrl(args);",
      "if (usesNativeAppleRenderer)",
      "requireNativeAppleRenderer(pageUrl)",
      "waitForBackend(pageUrl)",
      "runApp(TemplateApp(pageUrl: pageUrl, extensions: extensions))"
    )
    assert_includes entrypoint, "'RUFLET_BACKEND_URL'"
    refute_includes entrypoint, "RufletRuntime.serverUrl()"
  end

  def test_self_mode_resolves_embedded_url_before_the_apple_switch
    entrypoint = source("lib/main.self.dart")

    assert_ordered(
      entrypoint,
      "pageUrl = (await RufletRuntime.serverUrl()).toString();",
      "requireNativeAppleRenderer(pageUrl)",
      "runApp(TemplateApp(pageUrl: pageUrl, extensions: extensions))"
    )
  end

  def test_apple_has_no_flutter_renderer_opt_out_or_silent_handoff_fallback
    bridge = source("lib/native_renderer.dart")
    self_entry = source("lib/main.self.dart")
    server_entry = source("lib/main.server.dart")
    ios_choice = source("ios/Runner/RufletEngineChoice.swift")
    macos_choice = source("macos/Runner/RufletEngineChoice.swift")

    assert_includes bridge, "Future<void> requireNativeAppleRenderer"
    assert_includes bridge, "if (!await showNativeAppleRenderer(pageUrl))"
    assert_includes self_entry, "await requireNativeAppleRenderer(pageUrl);"
    assert_includes server_entry, "await requireNativeAppleRenderer(pageUrl);"
    [ios_choice, macos_choice].each do |choice|
      assert_includes choice, "static let usesNativeRenderer = true"
      refute_includes choice, "RufletUseFlutterEngine"
    end
  end

  def test_self_mode_delegates_apple_runtime_startup_without_a_hardcoded_project
    %w[ios/Runner/Info.plist macos/Runner/Info.plist].each do |relative|
      plist = source(relative)

      assert_match(/<key>RufletRuntimeAutostart<\/key>\s*<true\/>/, plist, relative)
      refute_includes plist, "RufletEmbeddedProject", relative
      refute_includes plist, "<string>ruflet</string>", relative
    end
  end

  def test_runner_hosts_share_the_same_original_page_url_contract
    ios = source("ios/Runner/AppDelegate.swift")
    macos = source("macos/Runner/MainFlutterWindow.swift")
    ios_choice = source("ios/Runner/RufletEngineChoice.swift")
    macos_choice = source("macos/Runner/RufletEngineChoice.swift")

    [ios, macos].each do |runner|
      assert_includes runner, 'name: "ruflet/native_renderer"'
      assert_ordered(
        runner,
        'arguments?["pageUrl"] as? String',
        "RufletEngineChoice.pageURL(from: rawURL)",
        "RufletAppView("
      )
      assert_includes runner, "pageURL: pageURL"
      assert_includes runner, "extensions: RufletEngineChoice.extensions"
      refute_includes runner, "websocketURL"
      refute_includes runner, "WebSocketTransport"
    end

    assert_equal ios_choice, macos_choice
    assert_includes ios_choice, "RufletPageAddress.parse(raw)"
    refute_includes ios_choice, "websocketURL"
  end

  def test_ios_deployment_target_matches_the_native_layout_protocol_floor
    engine_package = source("apple_packages/ruflet_apple/Package.swift")
    extension_package = source("apple_extensions/Package.swift")
    podfile = source("ios/Podfile")
    project = source("ios/Runner.xcodeproj/project.pbxproj")

    assert_includes engine_package, ".iOS(.v16)"
    assert_includes extension_package, ".iOS(.v16)"
    assert_includes podfile, "platform :ios, '16.0'"
    assert_equal 3, project.scan("IPHONEOS_DEPLOYMENT_TARGET = 16.0;").length
    refute_includes project, "IPHONEOS_DEPLOYMENT_TARGET = 15.0;"
  end

  def test_every_native_optional_extension_is_linked_and_registered_by_both_runners
    choice = source("macos/Runner/RufletEngineChoice.swift")
    macos_project = source("macos/Runner.xcodeproj/project.pbxproj")
    ios_project = source("ios/Runner.xcodeproj/project.pbxproj")
    extensions = {
      "RufletAds" => "RufletAds.Extension()",
      "RufletAudio" => "RufletAudioExtension()",
      "RufletAudioRecorder" => "RufletAudioRecorderExtension()",
      "RufletCamera" => "RufletCameraExtension()",
      "RufletCharts" => "RufletChartsExtension()",
      "RufletCodeEditor" => "RufletCodeEditorExtension()",
      "RufletColorPickers" => "RufletColorPickersExtension()",
      "RufletDataTable2" => "RufletDataTable2Extension()",
      "RufletFlashlight" => "RufletFlashlightExtension()",
      "RufletGeolocator" => "RufletGeolocatorExtension()",
      "RufletLottie" => "RufletLottieExtension()",
      "RufletMap" => "RufletMap.Extension()",
      "RufletPermissionHandler" => "RufletPermissionHandlerExtension()",
      "RufletQRScanner" => "RufletQRScannerExtension()",
      "RufletRive" => "RufletRiveExtension()",
      "RufletSecureStorage" => "RufletSecureStorageExtension()",
      "RufletSpinKit" => "RufletSpinKitExtension()",
      "RufletVideo" => "RufletVideoExtension()",
      "RufletWebView" => "RufletWebViewExtension()"
    }

    extensions.each do |product, registration|
      assert_includes choice, "canImport(#{product})", "#{product} is not imported conditionally"
      assert_includes choice, registration, "#{product} is not registered"
      assert_includes macos_project, "productName = #{product};", "#{product} is not linked on macOS"
      assert_includes ios_project, "productName = #{product};", "#{product} is not linked on iOS"
    end
  end
end
