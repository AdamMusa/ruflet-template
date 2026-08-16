# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "audit_protocol_by_protocol_parity"

class ProtocolByProtocolParityTest < Minitest::Test
  def setup
    @contract = FletProtocolContract.build
    @report = ProtocolByProtocolParityAudit.build
  end

  def test_checked_in_contract_and_report_are_current
    assert_equal FletProtocolContract.generate,
      File.read(FletProtocolContract.output_path)
    assert_equal ProtocolByProtocolParityAudit.generate,
      File.read(ProtocolByProtocolParityAudit.output_path)
  end

  def test_all_six_actions_and_four_patch_operations_are_matched
    assert_equal 6, @contract.dig("message", "actions").length
    assert_equal 4, @contract.dig("patch", "operations").length
    assert_equal 6, @report.dig("summary", "message_actions")
    assert_equal 4, @report.dig("summary", "patch_operations")
  end

  def test_every_protocol_row_has_native_evidence
    assert_equal 0, @report.dig("summary", "unmatched_rows"),
      JSON.pretty_generate(@report.fetch("unmatched"))
    assert_equal @report.dig("summary", "rows"),
      @report.dig("summary", "matched_rows")
  end

  def test_command_line_gate_rejects_any_unmatched_row
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.join(__dir__, "audit_protocol_by_protocol_parity.rb"),
      "--check")
    assert status.success?, stderr
  end
end
