# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "generate_flet_control_contract"

class FletControlContractTest < Minitest::Test
  def setup
    @contract = FletControlContract.build
    @controls = @contract.fetch("controls").to_h { |control| [control.fetch("wire_type"), control] }
  end

  def test_checked_in_contract_is_deterministic_and_current
    first = FletControlContract.generate
    second = FletControlContract.generate

    assert_equal first, second
    assert_equal first, File.read(FletControlContract.output_path)

    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.join(__dir__, "generate_flet_control_contract.rb"),
      "--check"
    )
    assert status.success?, stderr
  end

  def test_core_widget_and_service_are_discovered
    assert_control "ResponsiveRow", package: "flet", classification: "widget", renderer: "ResponsiveRowControl"
    assert_control "Battery", package: "flet", classification: "service", renderer: "BatteryService"
  end

  def test_required_plugin_controls_are_discovered
    assert_control "Video", package: "flet_video", classification: "widget", renderer: "VideoControl"
    assert_control "Rive", package: "flet_rive", classification: "widget", renderer: "RiveControl"
    assert_control "CodeEditor", package: "flet_code_editor", classification: "widget", renderer: "CodeEditorControl"
    assert_control "Camera", package: "flet_camera", classification: "widget", renderer: "CameraControl"
  end

  def test_events_methods_and_defaults_are_extracted
    video = @controls.fetch("Video")
    assert_includes video.fetch("events"), "loaded"
    assert_includes video.fetch("methods"), "play"
    assert_equal false, video.dig("primitive_defaults", "autoplay", "value")

    camera = @controls.fetch("Camera")
    assert_includes camera.fetch("methods"), "get_available_cameras"

    code_editor = @controls.fetch("CodeEditor")
    assert_includes code_editor.fetch("methods"), "focus"
    assert_equal false, code_editor.dig("primitive_defaults", "read_only", "value")

    rive = @controls.fetch("Rive")
    assert_equal "double", rive.dig("primitive_defaults", "speed_multiplier", "type")
    assert_equal 1.0, rive.dig("primitive_defaults", "speed_multiplier", "value")
  end

  def test_defaults_applied_through_local_variables_are_extracted
    column = @controls.fetch("Column")

    assert_equal "start", column.dig("primitive_defaults", "alignment", "value")
    assert_equal "start", column.dig("primitive_defaults", "horizontal_alignment", "value")
  end

  def test_sibling_controls_do_not_inherit_each_others_events_and_methods
    assert_equal ["change"], @controls.fetch("Tabs").fetch("events")
    assert_equal ["move_to"], @controls.fetch("Tabs").fetch("methods")
    assert_equal ["click", "hover"], @controls.fetch("TabBar").fetch("events")
    assert_empty @controls.fetch("TabBar").fetch("methods")
    assert_empty @controls.fetch("TabBarView").fetch("events")
    assert_empty @controls.fetch("TabBarView").fetch("methods")
    assert_empty @controls.fetch("Tab").fetch("events")
    assert_empty @controls.fetch("Tab").fetch("methods")
  end

  def test_every_vendored_flet_extension_has_an_available_swift_product
    vendored = Dir.children(File.join(FletControlContract.template_root, "flet_packages"))
      .grep(/\A(?:flet_|ruflet_)/)
      .select { |name| File.directory?(File.join(FletControlContract.template_root, "flet_packages", name)) }
      .sort

    manifest_path = File.join(
      FletControlContract.template_root,
      "apple_packages/ruflet_apple/Sources/RufletEngine/RufletExtensionManifest.swift"
    )
    manifest = File.read(manifest_path)
    native = manifest.scan(
      /fletPackage:\s*"([^"]+)".*?swiftProduct:\s*"([^"]+)".*?status:\s*\.([a-z]+)/m
    ).to_h { |flet_package, swift_product, status| [flet_package, [swift_product, status]] }

    package_root = File.join(
      FletControlContract.template_root,
      "apple_packages/ruflet_apple"
    )
    package_swift = File.read(File.join(package_root, "Package.swift"))

    assert_equal vendored, native.keys.sort,
      "Every vendored Flet extension must own one native Swift product"
    assert_equal native.keys.length, native.keys.uniq.length,
      "A vendored Flet extension must map to exactly one native package"
    assert_equal native.values.map(&:first).sort, native.values.map(&:first).uniq.sort,
      "A native Swift product must not collapse multiple Flet extensions"
    native.each do |flet_package, (swift_product, status)|
      assert_equal "available", status, "#{flet_package} is not ported"
      assert_match(/\ARuflet[A-Z]/, swift_product)

      assert_match(
        /\.library\(name:\s*"#{Regexp.escape(swift_product)}"\s*,\s*targets:\s*\["#{Regexp.escape(swift_product)}"\]\)/m,
        package_swift,
        "#{flet_package} has no #{swift_product} library product"
      )
      assert_match(
        /\.target\(\s*name:\s*"#{Regexp.escape(swift_product)}"(?:\s*,|\s*\))/m,
        package_swift,
        "#{flet_package} has no #{swift_product} target"
      )

      source_root = File.join(package_root, "Sources", swift_product)
      assert_path_exists source_root, "#{flet_package} has no dedicated source directory"
      sources = Dir.glob(File.join(source_root, "**/*.swift")).map { |path| File.read(path) }.join("\n")
      assert_match(
        /\b#{Regexp.escape(swift_product)}\s*:\s*RufletExtension\b/,
        sources,
        "#{flet_package} does not expose a #{swift_product} RufletExtension entry point"
      )
    end
  end

  private

  def assert_control(type, package:, classification:, renderer:)
    control = @controls.fetch(type)
    assert_equal package, control.fetch("package")
    assert_equal classification, control.fetch("classification")
    assert_equal renderer, control.dig("renderer", "class")
    assert File.file?(File.join(FletControlContract.template_root, control.dig("renderer", "source")))
  end
end
