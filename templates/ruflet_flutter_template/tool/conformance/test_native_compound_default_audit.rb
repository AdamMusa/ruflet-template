# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "audit_native_compound_defaults"

class NativeCompoundDefaultAuditTest < Minitest::Test
  def test_every_pinned_compound_default_has_native_evidence
    report = NativeCompoundDefaultAudit.build

    assert_equal 25, report.dig("summary", "contract_defaults")
    assert_equal 25, report.dig("summary", "verified")
    assert_empty report.fetch("missing")
  end

  def test_checked_in_report_is_deterministic_and_current
    first = NativeCompoundDefaultAudit.generate
    second = NativeCompoundDefaultAudit.generate

    assert_equal first, second
    assert_equal first, File.read(NativeCompoundDefaultAudit.report_path)

    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.join(__dir__, "audit_native_compound_defaults.rb"),
      "--check"
    )
    assert status.success?, stderr
  end
end
