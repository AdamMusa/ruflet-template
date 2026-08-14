# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "audit_native_layout_defaults"

class NativeLayoutDefaultAuditTest < Minitest::Test
  def test_every_pinned_layout_getter_has_native_default_evidence
    report = NativeLayoutDefaultAudit.build

    assert_operator report.dig("summary", "call_sites"), :>=, 50
    assert_equal report.dig("summary", "call_sites"), report.dig("summary", "verified")
    assert_empty report.fetch("missing")
  end

  def test_checked_in_report_is_deterministic_and_current
    first = NativeLayoutDefaultAudit.generate
    second = NativeLayoutDefaultAudit.generate

    assert_equal first, second
    assert_equal first, File.read(NativeLayoutDefaultAudit.report_path)

    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.join(__dir__, "audit_native_layout_defaults.rb"),
      "--check"
    )
    assert status.success?, stderr
  end
end
