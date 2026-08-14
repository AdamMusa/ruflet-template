#!/usr/bin/env ruby
# frozen_string_literal: true

# Reports only declarations that can be proven unreachable without whole-
# program inference: non-public, top-level declarations whose identifier has no
# second occurrence in any package source or test. Public API and SwiftUI/
# UIKit/AppKit protocol entry points are intentionally outside this audit.

require "json"

template_root = File.expand_path("../..", __dir__)
package_root = File.join(template_root, "apple_packages", "ruflet_apple")
output_path = File.join(__dir__, "native_dead_code_report.json")
files = Dir.glob(File.join(package_root, "{Sources,Tests}", "**", "*.swift")).sort
source_files = files.grep(%r{/Sources/})
contents = files.to_h { |path| [path, File.read(path)] }
corpus = contents.values.join("\n")

declaration = /\A(?:@\w+(?:\([^\n]*\))?\s+)*(?:(?:internal)\s+)?(struct|class|enum|actor|protocol|typealias|func)\s+([A-Za-z_][A-Za-z0-9_]*)/
reserved = %w[body init deinit].freeze

candidates = source_files.flat_map do |path|
  contents.fetch(path).each_line.with_index(1).filter_map do |line, number|
    match = line.match(declaration)
    next unless match

    kind, name = match.captures
    next if reserved.include?(name)
    next unless corpus.scan(/\b#{Regexp.escape(name)}\b/).length == 1

    {
      "path" => path.delete_prefix(template_root + "/"),
      "line" => number,
      "kind" => kind,
      "name" => name
    }
  end
end.sort_by { |entry| [entry.fetch("path"), entry.fetch("line")] }

report = {
  "report_version" => 1,
  "scope" => "non-public top-level Swift declarations with exactly one corpus occurrence",
  "source_files" => source_files.length,
  "proven_unreferenced" => candidates
}
generated = JSON.pretty_generate(report) + "\n"

if ARGV.delete("--check")
  current = File.file?(output_path) ? File.read(output_path) : nil
  abort "Native dead-code report is stale. Run #{__FILE__}." unless current == generated
  abort "Proven unreachable Swift declarations remain:\n#{candidates.map { |item| item.inspect }.join("\n")}" unless candidates.empty?
  puts "Native dead-code report is current: 0 proven-unreferenced declarations."
else
  File.write(output_path, generated)
  puts "Generated #{output_path.delete_prefix(template_root + "/")}: #{candidates.length} candidates"
end
