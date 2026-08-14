# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"

class NativeDeadCodeAuditTest < Minitest::Test
  def test_report_is_current_and_has_no_proven_unreferenced_declarations
    script = File.join(__dir__, "audit_native_dead_code.rb")
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, "--check")

    assert status.success?, "#{stdout}\n#{stderr}"
    report = JSON.parse(File.read(File.join(__dir__, "native_dead_code_report.json")))
    assert_operator report.fetch("source_files"), :>, 0
    assert_empty report.fetch("proven_unreferenced")
  end
end
