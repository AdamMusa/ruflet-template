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

  def test_literal_compound_defaults_are_extracted_from_flet_renderers
    assert_equal(
      {
        "type" => "edge_insets",
        "top" => 10.0,
        "left" => 10.0,
        "bottom" => 10.0,
        "right" => 10.0
      },
      @controls.fetch("View").dig("compound_defaults", "padding")
    )
    assert_equal(
      {
        "type" => "edge_insets",
        "top" => 24.0,
        "left" => 16.0,
        "bottom" => 24.0,
        "right" => 16.0
      },
      @controls.fetch("DatePicker").dig("compound_defaults", "inset_padding")
    )
    assert_equal(
      { "type" => "duration", "seconds" => 1.0 },
      @controls.fetch("AnimatedSwitcher").dig("compound_defaults", "duration")
    )
    assert_equal(
      { "type" => "border_radius", "radius" => 8.0 },
      @controls.fetch("CupertinoButton").dig("compound_defaults", "border_radius")
    )
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
    refute_includes @controls.fetch("Page").fetch("events"), "confirm_pop"
    assert_includes @controls.fetch("View").fetch("events"), "confirm_pop"

    assert_equal %w[action dismiss visible], @controls.fetch("SnackBar").fetch("events")
    refute_includes @controls.fetch("SnackBar").fetch("events"), "click",
      "SnackBarAction.click belongs to the nested action control"
  end

  def test_every_vendored_flet_extension_has_an_available_swift_product
    vendored = Dir.children(File.join(FletControlContract.template_root, "flet_packages"))
      .grep(/\A(?:flet_|ruflet_)/)
      .select { |name| File.directory?(File.join(FletControlContract.template_root, "flet_packages", name)) }
      .sort

    package_root = File.join(
      FletControlContract.template_root,
      "apple_packages/ruflet_apple"
    )
    package_swift = File.read(File.join(package_root, "Package.swift"))
    products = package_swift.scan(/\.library\(name:\s*"(Ruflet[A-Za-z0-9]+)"/).flatten -
      %w[RufletProtocol RufletEngine RufletApple]
    product_sources = products.to_h do |product|
      source_root = File.join(package_root, "Sources", "RufletExtensions", product)
      sources = Dir.glob(File.join(source_root, "**/*.swift")).sort
        .map { |path| File.read(path) }.join("\n")
      [product, [source_root, sources]]
    end
    controls_by_package = @contract.fetch("controls")
      .reject { |control| control.fetch("package") == "flet" }
      .group_by { |control| control.fetch("package") }
    native = controls_by_package.to_h do |flet_package, controls|
      wire_types = controls.map { |control| control.fetch("wire_type") }
      candidates = product_sources.filter_map do |product, (_root, sources)|
        product if wire_types.all? { |wire_type| sources.include?(%Q{"#{wire_type}"}) }
      end
      assert_equal 1, candidates.length,
        "#{flet_package} must map by its live wire types to exactly one Swift product: #{candidates.inspect}"
      [flet_package, candidates.fetch(0)]
    end

    assert_equal vendored, native.keys.sort,
      "Every vendored Flet extension must own one native Swift product"
    assert_equal native.keys.length, native.keys.uniq.length,
      "A vendored Flet extension must map to exactly one native package"
    assert_equal native.values.sort, native.values.uniq.sort,
      "A native Swift product must not collapse multiple Flet extensions"
    assert_equal products.sort, native.values.sort,
      "Every optional Swift product must be owned by one vendored Flet extension"
    native.each do |flet_package, swift_product|
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

      source_root, sources = product_sources.fetch(swift_product)
      assert_path_exists source_root, "#{flet_package} has no dedicated source directory"
      assert_match(
        /\b(?:struct|class)\s+[A-Za-z_][A-Za-z0-9_]*\s*:\s*RufletExtension\b/,
        sources,
        "#{flet_package} does not expose a RufletExtension entry point"
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
