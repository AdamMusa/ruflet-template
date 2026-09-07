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
    assert_equal 386, @contract.dig("summary", "advertised_entries")
    assert_equal 348, @contract.dig("summary", "visual_entries")
    assert_equal 38, @contract.dig("summary", "service_entries")
    assert_equal 205, @contract.dig("summary", "wire_types")
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

  private

  def entry(family, name)
    @entries.find { |candidate| candidate.fetch("family") == family && candidate.fetch("dsl_name") == name } ||
      flunk("Missing #{family} control #{name}")
  end
end
