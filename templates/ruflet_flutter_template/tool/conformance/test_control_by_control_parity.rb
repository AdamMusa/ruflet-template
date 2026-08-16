# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "audit_control_by_control_parity"

class ControlByControlParityTest < Minitest::Test
  def setup
    @report = ControlByControlParityAudit.build
  end

  def test_checked_in_report_is_current
    assert_equal ControlByControlParityAudit.generate,
      File.read(ControlByControlParityAudit.output_path)
  end

  def test_every_executable_flet_control_has_an_individual_match
    assert_equal 213, @report.dig("summary", "controls")
    assert_equal 213, @report.dig("summary", "matched_controls")
    assert_equal 0, @report.dig("summary", "unmatched_controls")
    assert_equal 0, @report.dig("summary", "unmatched_rows"),
      JSON.pretty_generate(@report.fetch("unmatched"))
  end

  def test_command_line_gate_rejects_any_unmatched_row
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.join(__dir__, "audit_control_by_control_parity.rb"),
      "--check")
    assert status.success?, stderr
  end
end
