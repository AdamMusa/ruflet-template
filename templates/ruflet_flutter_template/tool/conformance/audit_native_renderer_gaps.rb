#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "digest"
require_relative "generate_flet_control_contract"

module NativeRendererGapAudit
  AUDIT_VERSION = 1

  module_function

  def registry_path
    File.join(
      FletControlContract.template_root,
      "apple_packages", "ruflet_apple", "Sources", "RufletUI", "ControlRegistry.swift"
    )
  end

  def sources_root
    File.join(FletControlContract.template_root, "apple_packages", "ruflet_apple", "Sources")
  end

  def allowlist_path
    File.join(__dir__, "native_gap_allowlist.json")
  end

  def output_path
    File.join(__dir__, "native_renderer_gap_report.json")
  end

  def balanced(source, opening, open_character: "(", close_character: ")")
    depth = 0
    quote = nil
    escaped = false
    source.each_char.with_index do |character, index|
      next if index < opening

      if quote
        if escaped
          escaped = false
        elsif character == "\\"
          escaped = true
        elsif character == quote
          quote = nil
        end
        next
      end

      # Swift string literals use double quotes. Apostrophes commonly occur in
      # comments ("device's state") and must not turn the remainder of a class
      # into a quoted region while locating its closing brace.
      if character == '"'
        quote = character
      elsif character == open_character
        depth += 1
      elsif character == close_character
        depth -= 1
        return source[opening..index] if depth.zero?
      end
    end
    nil
  end

  def string_array(expression, variables = {})
    token = expression&.strip
    return [] unless token
    if token.include?("+")
      return token.split("+").flat_map { |part| string_array(part, variables) }
    end
    unless token.start_with?("[")
      return variables.fetch(token, variables.fetch(token.split(".").last, []))
    end

    token.scan(/["']([^"']+)["']/).flatten
  end

  def swift_array_variables
    Dir.glob(File.join(sources_root, "**", "*.swift")).sort.each_with_object({}) do |path, result|
      source = File.read(path)
      source.scan(/(?:static\s+)?let\s+(\w+)(?:\s*:\s*(?:Set<)?\[?String\]?>?)?\s*=\s*(\[[^\]]*\])/m) do |name, expression|
        values = string_array(expression)
        result[name] = values unless values.empty?
      end
    end
  end

  def native_descriptors
    source = File.read(registry_path)
    set_variables = swift_array_variables.merge(
      source.scan(/let\s+(\w+)\s*:\s*Set<String>\s*=\s*(\[[^\]]*\])/m)
        .to_h { |name, expression| [name, string_array(expression)] }
    )
    descriptors = {}
    offset = 0
    while (match = source.match(/\badd\s*\(/, offset))
      call = balanced(source, source.index("(", match.begin(0)))
      break unless call

      types_expression = call[/\A\(\s*(.+?)\s*,\s*\.\w+/m, 1]
      classification = call[/\A\(\s*.+?\s*,\s*\.(\w+)/m, 1]
      implementation = call[/\A\(\s*.+?\s*,\s*\.\w+\s*,\s*["']([^"']+)["']/m, 1]
      rendering = call[/\A\(\s*.+?\s*,\s*\.\w+\s*,\s*["'][^"']+["']\s*,\s*\.(\w+)/m, 1]
      events_expression = call[/\bevents:\s*(\[[^\]]*\]|\w+)/m, 1]
      methods_expression = call[/\bmethods:\s*(\[[^\]]*\]|\w+)/m, 1]
      string_array(types_expression, set_variables).each do |wire_type|
        descriptors[wire_type] = {
          "wire_type" => wire_type,
          "declaration" => "control_descriptor",
          "classification" => classification,
          "implementation" => implementation,
          "rendering" => rendering,
          "events" => string_array(events_expression, set_variables).sort,
          "methods" => string_array(methods_expression, set_variables).sort
        }
      end
      offset = match.begin(0) + call.length
    end


    # Some families start from a shared descriptor and then replace selected
    # entries with a more precise event/method contract. Treat those explicit
    # assignments as first-class declarations instead of reporting false gaps.
    source.scan(/result\[\s*["']([^"']+)["']\s*\]\s*=\s*ControlDescriptor\s*\(/m) do |key|
      match = Regexp.last_match
      opening = source.index("(", match.begin(0) + match[0].index("ControlDescriptor"))
      call = balanced(source, opening)
      next unless call

      wire_type = call[/\bwireType:\s*["']([^"']+)["']/, 1] || key.first
      descriptors[wire_type] = descriptor_from_constructor(call, wire_type, set_variables)
    end

    loop_offset = 0
    loop_pattern = /for\s+type\s+in\s+(\[[^\]]*\])\s*\{/m
    while (match = source.match(loop_pattern, loop_offset))
      body = balanced(source, match.end(0) - 1, open_character: "{", close_character: "}")
      break unless body
      if body.include?("result[type.lowercased()]") && (constructor = body.index("ControlDescriptor("))
        opening = body.index("(", constructor)
        call = balanced(body, opening)
        string_array(match[1]).each do |wire_type|
          descriptors[wire_type] = descriptor_from_constructor(call, wire_type, set_variables)
        end
      end
      loop_offset = match.begin(0) + body.length
    end
    descriptors
  end

  def descriptor_from_constructor(call, wire_type, variables)
    {
      "wire_type" => wire_type,
      "declaration" => "control_descriptor",
      "classification" => call[/\bclassification:\s*\.(\w+)/, 1],
      "implementation" => call[/\bimplementation:\s*["']([^"']+)["']/, 1],
      "rendering" => call[/\brendering:\s*\.(\w+)/, 1],
      "events" => string_array(
        call[/\bsupportedEvents:\s*(\[[^\]]*\]|\w+)/m, 1], variables).sort,
      "methods" => string_array(
        call[/\bsupportedMethods:\s*(\[[^\]]*\]|\w+)/m, 1], variables).sort
    }
  end

  def service_declarations
    declarations = {}
    class_declarations = {}
    Dir.glob(File.join(sources_root, "**", "*.swift")).sort.each do |path|
      source = File.read(path)
      class_matches = []
      offset = 0
      pattern = /\bclass\s+(\w+)\s*:\s*[^\{]*\bRuflet(?:Streaming)?Service\b[^\{]*\{/
      while (match = source.match(pattern, offset))
        class_matches << [match[1], match.end(0) - 1]
        offset = match.end(0)
      end
      class_matches.each do |class_name, opening|
        body = balanced(source, opening, open_character: "{", close_character: "}")
        next unless body
        wire_type = body[/static\s+let\s+wireType\s*=\s*["']([^"']+)["']/, 1]
        next unless wire_type

        extension_bodies = []
        extension_offset = 0
        extension_pattern = /\bextension\s+#{Regexp.escape(class_name)}\b[^\{]*\{/
        while (extension_match = source.match(extension_pattern, extension_offset))
          extension_body = balanced(
            source,
            extension_match.end(0) - 1,
            open_character: "{",
            close_character: "}"
          )
          break unless extension_body

          extension_bodies << extension_body
          extension_offset = extension_match.begin(0) + extension_body.length
        end
        implementation = ([body] + extension_bodies).join("\n")

        case_methods = implementation.scan(/case\s+((?:["'][^"']+["']\s*,?\s*)+):/m)
          .flatten
          .flat_map { |clause| clause.scan(/["']([^"']+)["']/).flatten }
        compared_methods = implementation.scan(/call\.name\s*==\s*["']([^"']+)["']/).flatten

        declaration = {
          "wire_type" => wire_type,
          "declaration" => "service",
          "classification" => "service",
          "implementation" => class_name,
          "rendering" => "serviceOnly",
          "events" => implementation.scan(/\.emitEvent\([^,]+,\s*["']([^"']+)["']/m).flatten.uniq.sort,
          "methods" => (case_methods + compared_methods).uniq.sort
        }
        declarations[wire_type] = declaration
        class_declarations[class_name] = declaration
      end

      # Optional bundles register several wire types against one parameterised
      # service implementation (for example all CoreMotion sensors). Treat
      # those declarations as first-class native surface rather than aliases
      # hidden in integration glue.
      source.scan(/registerNamed\(["']([^"']+)["']\)\s*\{\s*(\w+)\s*\(/m) do |wire_type, class_name|
        declaration = class_declarations[class_name]
        next unless declaration

        declarations[wire_type] = declaration.merge(
          "wire_type" => wire_type,
          "declaration" => "named_service"
        )
      end
    end
    declarations
  end

  def declared_native_surface
    services = service_declarations
    descriptors = native_descriptors
    (services.keys | descriptors.keys).sort.to_h do |wire_type|
      service = services[wire_type]
      descriptor = descriptors[wire_type]
      declaration = (service || {}).merge(descriptor || {})
      declaration["events"] = [service, descriptor].compact.flat_map { |item| item.fetch("events") }.uniq.sort
      declaration["methods"] = [service, descriptor].compact.flat_map { |item| item.fetch("methods") }.uniq.sort
      declaration["declarations"] = [service, descriptor].compact.map { |item| item.fetch("declaration") }.uniq.sort
      [wire_type, declaration]
    end
  end

  def load_allowlist
    JSON.parse(File.read(allowlist_path))
  end

  def gap_allowed?(allowlist, category, wire_type, value = nil)
    entry = allowlist.fetch(category, {})[wire_type]
    return false unless entry
    return true unless value

    entry.fetch("names", []).include?(value) || entry.fetch("names", []).include?("*")
  end

  def build
    contract = JSON.parse(File.read(FletControlContract.output_path))
    allowlist = load_allowlist
    native = declared_native_surface
    aliases = allowlist.fetch("aliases", {})
    ignored_packages = allowlist.fetch("ignored_packages", {})
    missing_types = []
    missing_events = []
    missing_methods = []

    contract.fetch("controls").each do |upstream|
      wire_type = upstream.fetch("wire_type")
      native_type = aliases.fetch(wire_type, wire_type)
      declaration = native[native_type]
      if declaration.nil?
        package_reason = ignored_packages[upstream.fetch("package")]
        allowed = !package_reason.nil? || gap_allowed?(allowlist, "type_gaps", wire_type)
        details = allowlist.fetch("type_gaps", {})[wire_type]
        missing_types << {
          "wire_type" => wire_type,
          "package" => upstream.fetch("package"),
          "classification" => upstream.fetch("classification"),
          "allowed" => allowed,
          "gap_classification" => details&.fetch("classification", nil) ||
            (package_reason ? "ignored_package" : "undeclared"),
          "reason" => details&.fetch("reason", nil) || package_reason
        }
        next
      end

      upstream.fetch("events").each do |event|
        next if declaration.fetch("events").include?(event)
        allowed = gap_allowed?(allowlist, "event_gaps", wire_type, event)
        missing_events << {
          "wire_type" => wire_type,
          "native_type" => native_type,
          "event" => event,
          "allowed" => allowed,
          "reason" => allowlist.dig("event_gaps", wire_type, "reason")
        }
      end

      upstream.fetch("methods").each do |method|
        next if declaration.fetch("methods").include?(method)
        allowed = gap_allowed?(allowlist, "method_gaps", wire_type, method)
        missing_methods << {
          "wire_type" => wire_type,
          "native_type" => native_type,
          "method" => method,
          "allowed" => allowed,
          "reason" => allowlist.dig("method_gaps", wire_type, "reason")
        }
      end
    end

    unresolved_signature = Digest::SHA256.hexdigest(
      JSON.generate(
        {
          "types" => missing_types.reject { |gap| gap.fetch("allowed") }.map { |gap| gap.fetch("wire_type") }.sort,
          "events" => missing_events.reject { |gap| gap.fetch("allowed") }.map { |gap| [gap.fetch("wire_type"), gap.fetch("event")] }.sort,
          "methods" => missing_methods.reject { |gap| gap.fetch("allowed") }.map { |gap| [gap.fetch("wire_type"), gap.fetch("method")] }.sort
        }
      )
    )
    baseline = allowlist["declared_baseline"]
    baseline_matches = baseline && baseline.fetch("gap_set_sha256") == unresolved_signature
    if baseline_matches
      (missing_types + missing_events + missing_methods).each do |gap|
        next if gap.fetch("allowed")

        gap["allowed"] = true
        if !gap.key?("gap_classification") || gap["gap_classification"] == "undeclared"
          gap["gap_classification"] = baseline.fetch("classification")
        end
        gap["reason"] ||= baseline.fetch("reason")
      end
    end
    undeclared = (missing_types + missing_events + missing_methods).count { |gap| !gap.fetch("allowed") }
    {
      "audit_version" => AUDIT_VERSION,
      "contract_version" => contract.fetch("contract_version"),
      "source" => {
        "flet_contract" => File.basename(FletControlContract.output_path),
        "native_registry" => registry_path.delete_prefix(FletControlContract.template_root + "/"),
        "allowlist" => File.basename(allowlist_path)
      },
      "summary" => {
        "flet_types" => contract.fetch("controls").length,
        "native_declarations" => native.length,
        "missing_types" => missing_types.length,
        "missing_events" => missing_events.length,
        "missing_methods" => missing_methods.length,
        "undeclared_gaps" => undeclared,
        "declared_baseline_matches" => !!baseline_matches,
        "unresolved_gap_set_sha256" => unresolved_signature
      },
      "missing_types" => missing_types.sort_by { |gap| gap.fetch("wire_type") },
      "missing_events" => missing_events.sort_by { |gap| [gap.fetch("wire_type"), gap.fetch("event")] },
      "missing_methods" => missing_methods.sort_by { |gap| [gap.fetch("wire_type"), gap.fetch("method")] }
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = NativeRendererGapAudit.generate
  if ARGV.delete("--check")
    current = File.file?(NativeRendererGapAudit.output_path) ? File.read(NativeRendererGapAudit.output_path) : nil
    abort "Native renderer gap report is stale. Run #{__FILE__}." unless current == generated
    report = JSON.parse(generated)
    undeclared = report.dig("summary", "undeclared_gaps")
    abort "Native renderer has #{undeclared} undeclared Flet conformance gaps." unless undeclared.zero?
    puts "Native renderer gap report is current; all gaps are declared."
  else
    File.write(NativeRendererGapAudit.output_path, generated)
    report = JSON.parse(generated)
    puts "Generated #{NativeRendererGapAudit.output_path}"
    puts JSON.pretty_generate(report.fetch("summary"))
  end
end
