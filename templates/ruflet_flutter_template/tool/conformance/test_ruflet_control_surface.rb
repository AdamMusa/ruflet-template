# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "generate_ruflet_control_surface"

class RufletControlSurfaceTest < Minitest::Test
  def setup
    @contract = RufletControlSurface.build
    @entries = @contract.fetch("entries")
  end

  def test_every_advertised_entry_is_preserved_and_contract_is_current
    assert_equal 449, @contract.dig("summary", "advertised_entries")
    assert_equal 409, @contract.dig("summary", "visual_entries")
    assert_equal 40, @contract.dig("summary", "service_entries")
    assert_equal 238, @contract.dig("summary", "wire_types")
    assert_equal RufletControlSurface.generate, File.read(RufletControlSurface.output_path)

    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.join(__dir__, "generate_ruflet_control_surface.rb"),
      "--check"
    )
    assert status.success?, stderr
  end

  def test_aliases_remain_independent_audit_entries
    alert_dialog = entry("visual", "alert_dialog")
    alertdialog = entry("visual", "alertdialog")

    refute_equal alert_dialog.fetch("dsl_name"), alertdialog.fetch("dsl_name")
    assert_equal "AlertDialog", alert_dialog.fetch("wire_type")
    assert_equal alert_dialog.fetch("wire_type"), alertdialog.fetch("wire_type")
    assert_equal alert_dialog.fetch("keywords"), alertdialog.fetch("keywords")
  end

  def test_plugins_and_services_are_in_the_public_surface
    assert_equal "Video", entry("visual", "video").fetch("wire_type")
    assert_equal "Map", entry("visual", "map").fetch("wire_type")
    assert_equal "Camera", entry("service", "camera").fetch("wire_type")
    assert_equal "AudioRecorder", entry("service", "audio_recorder").fetch("wire_type")
  end

  # The committed surface, not only the live Ruby registries, must list the
  # controls that render as "Unknown control" on an engine older than abd906b9.
  def test_committed_surface_lists_controls_added_since_the_previous_engine_sync
    committed = JSON.parse(File.read(RufletControlSurface.output_path)).fetch("entries")
    {
      %w[visual form] => "Form",
      %w[visual nested_scroll_view] => "NestedScrollView",
      %w[visual fade_transition] => "FadeTransition",
      %w[service local_authentication] => "LocalAuthentication"
    }.each do |(family, name), wire_type|
      found = committed.find { |candidate| candidate.fetch("family") == family && candidate.fetch("dsl_name") == name }
      assert found, "Committed surface is missing #{family} control #{name}"
      assert_equal wire_type, found.fetch("wire_type")
    end
  end

  private

  def entry(family, name)
    @entries.find { |candidate| candidate.fetch("family") == family && candidate.fetch("dsl_name") == name } ||
      flunk("Missing #{family} control #{name}")
  end
end
