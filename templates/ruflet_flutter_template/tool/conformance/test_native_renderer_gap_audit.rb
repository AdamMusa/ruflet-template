# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "audit_native_renderer_gaps"

class NativeRendererGapAuditTest < Minitest::Test
  def setup
    @surface = NativeRendererGapAudit.declared_native_surface
    @report = NativeRendererGapAudit.build
  end

  def test_checked_in_report_is_deterministic_current_and_ci_clean
    first = NativeRendererGapAudit.generate
    second = NativeRendererGapAudit.generate

    assert_equal first, second
    assert_equal first, File.read(NativeRendererGapAudit.output_path)
    assert_equal true, @report.dig("summary", "declared_baseline_matches")
    assert_equal 0, @report.dig("summary", "undeclared_gaps")

    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.join(__dir__, "audit_native_renderer_gaps.rb"),
      "--check"
    )
    assert status.success?, stderr
  end

  def test_control_and_service_declarations_are_unioned
    camera = @surface.fetch("Camera")
    assert_includes camera.fetch("declarations"), "control_descriptor"
    assert_includes camera.fetch("declarations"), "named_service"
    assert_includes camera.fetch("events"), "picture_taken"
    assert_includes camera.fetch("methods"), "request_permission"
  end

  def test_default_and_optional_bundle_services_are_discovered
    assert_includes @surface.fetch("Connectivity").fetch("events"), "change"
    assert_includes @surface.fetch("FilePicker").fetch("methods"), "pick_files"
    assert_includes @surface.fetch("SecureStorage").fetch("methods"), "contains_key"
    assert_includes @surface.fetch("Barometer").fetch("events"), "change"
    assert_equal "named_service", @surface.fetch("Gyroscope").fetch("declaration")
  end

  def test_audio_declares_the_flet_push_and_method_contract
    audio = @surface.fetch("Audio")
    %w[duration_change loaded position_change seek_complete state_change].each do |event|
      assert_includes audio.fetch("events"), event
    end
    %w[get_current_position get_duration pause play release resume seek].each do |method|
      assert_includes audio.fetch("methods"), method
    end
  end

  def test_report_keeps_declared_gaps_actionable
    lottie = @report.fetch("missing_types").find { |gap| gap.fetch("wire_type") == "Lottie" }
    assert_nil lottie
    assert_includes @surface.fetch("Lottie").fetch("events"), "load"
    assert_includes @surface.fetch("Lottie").fetch("events"), "error"

    video_complete = @report.fetch("missing_events").find do |gap|
      gap.fetch("wire_type") == "Video" && gap.fetch("event") == "complete"
    end
    assert_nil video_complete
    assert_includes @surface.fetch("Video").fetch("events"), "complete"
    assert_includes @surface.fetch("Video").fetch("events"), "track_change"
  end

  def test_name_allowlist_does_not_accept_unknown_gaps
    allowlist = NativeRendererGapAudit.load_allowlist
    refute NativeRendererGapAudit.gap_allowed?(allowlist, "event_gaps", "Video", "invented_event")
    refute NativeRendererGapAudit.gap_allowed?(allowlist, "method_gaps", "Video", "invented_method")
  end
end
