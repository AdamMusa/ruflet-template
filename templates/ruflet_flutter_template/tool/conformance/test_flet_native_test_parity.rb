# frozen_string_literal: true

require "json"
require "minitest/autorun"

class FletNativeTestParityTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  MANIFEST_PATH = File.join(__dir__, "flet_native_test_parity.json")
  SWIFT_TEST_ROOT = File.join(ROOT, "apple_packages", "ruflet_apple", "Tests")

  def test_every_vendored_flet_test_case_has_a_concrete_swift_counterpart
    manifest = JSON.parse(File.read(MANIFEST_PATH)).fetch("mappings")
    discovered = discover_dart_tests

    assert_equal discovered.keys.sort, manifest.keys.sort,
      "Every vendored Dart test file must be mapped; stale mappings are forbidden too"

    discovered.each do |dart_file, dart_cases|
      native_cases = manifest.fetch(dart_file)
      assert_equal dart_cases.sort, native_cases.keys.sort,
        "Every Dart test case in #{dart_file} must be mapped exactly once"

      native_cases.each do |dart_case, native_reference|
        target_and_class, method = native_reference.split(".", 2)
        target, class_name = target_and_class.split("/", 2)
        refute_nil target, "#{dart_file}: #{dart_case} has an invalid native target"
        refute_nil class_name, "#{dart_file}: #{dart_case} has an invalid native class"
        refute_nil method, "#{dart_file}: #{dart_case} has an invalid native method"

        path = File.join(SWIFT_TEST_ROOT, target, "#{class_name}.swift")
        assert_path_exists path, "#{dart_file}: #{dart_case} maps to missing #{path}"
        source = File.read(path)
        assert_match(/\bfunc\s+#{Regexp.escape(method)}\s*\(/, source,
          "#{dart_file}: #{dart_case} maps to missing #{native_reference}")
      end
    end

    assert_equal 7, discovered.length
    assert_equal 24, discovered.values.sum(&:length)
  end

  private

  def discover_dart_tests
    root = File.join(ROOT, "flet_packages")
    Dir.glob(File.join(root, "**", "test", "**", "*.dart")).sort.to_h do |path|
      source = File.read(path)
      tests = source.scan(/\btest\s*\(\s*["']([^"']+)["']/).flatten
      relative = path.delete_prefix(root + "/")
      [relative, tests]
    end
  end
end
