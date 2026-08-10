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

  private

  def assert_control(type, package:, classification:, renderer:)
    control = @controls.fetch(type)
    assert_equal package, control.fetch("package")
    assert_equal classification, control.fetch("classification")
    assert_equal renderer, control.dig("renderer", "class")
    assert File.file?(File.join(FletControlContract.template_root, control.dig("renderer", "source")))
  end
end
