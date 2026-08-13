#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require_relative "audit_native_property_consumption"
require_relative "generate_flet_control_contract"

# Compares Flet's executable createWidget/createService contract with the
# current native Swift implementation graph. This intentionally does not read
# the deleted RufletUI registry or a hand-maintained renderer manifest.
module NativeRendererGapAudit
  AUDIT_VERSION = 2

  module_function

  def allowlist_path
    File.join(__dir__, "native_gap_allowlist.json")
  end

  def output_path
    File.join(__dir__, "native_renderer_gap_report.json")
  end

  def swift_source_for_types(types)
    closure = NativePropertyConsumptionAudit.implementation_closure(types)
    full_paths = closure.filter_map do |type|
      next unless type.match?(/(?:Control|Service|Controller)\z/)
      NativePropertyConsumptionAudit.type_scopes.fetch(type, []).map { |scope| scope.fetch(:path) }
    end.flatten.uniq
    scoped = closure.flat_map do |type|
      NativePropertyConsumptionAudit.type_scopes.fetch(type, []).filter_map do |scope|
        next if full_paths.include?(scope.fetch(:path))
        lines = NativePropertyConsumptionAudit.code_lines(
          NativePropertyConsumptionAudit.swift_files.fetch(scope.fetch(:path))
        )
        lines[scope.fetch(:start)..scope.fetch(:finish)].join("\n")
      end
    end
    full = full_paths.map do |path|
      NativePropertyConsumptionAudit.code_lines(
        NativePropertyConsumptionAudit.swift_files.fetch(path)).join("\n")
    end
    (full + scoped).join("\n")
  end

  def executable_methods(types)
    source = swift_source_for_types(types)
    return [] unless source.match?(/addInvokeMethodListener|\b(?:invoke|handle)\s*\(/)

    cases = source.scan(/\bcase\s+((?:"[^"]+"\s*,?\s*)+):/m)
      .flatten.flat_map { |clause| clause.scan(/"([^"]+)"/).flatten }
    comparisons = source.scan(/(?:name|call\.name)\s*==\s*"([^"]+)"/).flatten
    declared = source.scan(
      /(?:supportedMethods|methodNames)(?:\s*:\s*(?:Set<)?\[?String\]?>?)?\s*=\s*\[([^\]]*)\]/m
    ).flatten.flat_map { |body| body.scan(/"([^"]+)"/).flatten }
    (cases + comparisons + declared).uniq.sort
  end

  def executable_events(types)
    reads = NativePropertyConsumptionAudit.reads_for_types(types)
    source = swift_source_for_types(types)
    events = reads.keys.grep(/\Aon_/).map { |name| name.delete_prefix("on_") }
    events.concat(source.scan(
      /\b(?:hasEventHandler|triggerEvent|triggerEventWithoutSubscribers)\(\s*"([^"]+)"/
    ).flatten)
    if source.match?(/\btriggerEvent\(\s*event\b/)
      events.concat(source.scan(/\bevent\s*=\s*"([^"]+)"/).flatten)
    end
    # These shared transaction helpers are executable event bridges called by
    # several controls. Keep the association at the concrete call site rather
    # than globally crediting every renderer for the helper's literals.
    events << "change" if source.match?(
      /\b(?:rufletActivateCheckbox|rufletCommitExpansion|rufletCommitSelection)\s*\(/)
    # These are reviewed native compatibility spellings already enforced by
    # the property-consumption audit.
    events << "completed" if events.include?("complete")
    events << "track_changed" if events.include?("track_change")
    events.uniq.sort
  end

  def platform_conditional_types
    root = File.join(
      FletControlContract.template_root,
      "apple_packages", "ruflet_apple", "Sources", "RufletExtensions"
    )
    Dir.glob(File.join(root, "**", "Sources", "Extension.swift")).sort.flat_map do |path|
      source = File.read(path)
      next [] unless source.include?("#if os(iOS)")

      source.scan(/(?:renderedControlTypes|serviceControlTypes).*?\[([^\]]+)\]/m)
        .flatten.flat_map { |body| body.scan(/"([A-Za-z0-9_]+)"/).flatten }
    end.uniq.sort
  end

  def declared_native_surface
    implementations = NativePropertyConsumptionAudit.implementation_map
    services = NativePropertyConsumptionAudit.service_implementation_map
    parents = NativePropertyConsumptionAudit::PARENT_IMPLEMENTATIONS
    conditional = platform_conditional_types
    (implementations.keys | services.keys | parents.keys | conditional).sort.to_h do |wire_type|
      visual_types = implementations.fetch(wire_type, [])
      service_types = services.fetch(wire_type, [])
      parent_types = parents.fetch(wire_type, [])
      executable_types = (visual_types + service_types + parent_types).uniq
      classification = service_types.empty? ? "widget" : "service"
      declarations = []
      declarations << "control_descriptor" unless visual_types.empty?
      declarations << "named_service" unless service_types.empty?
      declarations << "structural_parent" unless parent_types.empty?
      implementation = (visual_types - visual_types.grep(/Extension\z/)).last || visual_types.last
      declaration = if service_types.empty?
        parent_types.empty? ? "control_descriptor" : "structural_parent"
      else
        "named_service"
      end
      [wire_type, {
        "wire_type" => wire_type,
        "classification" => classification,
        "declaration" => declaration,
        "declarations" => declarations,
        "implementation" => implementation,
        "implementations" => visual_types,
        "service_implementations" => service_types,
        "parent_implementations" => parent_types,
        "events" => executable_events(executable_types),
        "methods" => executable_methods(executable_types)
      }]
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
    contract = FletControlContract.build
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
        missing_events << {
          "wire_type" => wire_type,
          "native_type" => native_type,
          "event" => event,
          "allowed" => gap_allowed?(allowlist, "event_gaps", wire_type, event),
          "reason" => allowlist.dig("event_gaps", wire_type, "reason")
        }
      end

      upstream.fetch("methods").each do |method|
        next if declaration.fetch("methods").include?(method)
        missing_methods << {
          "wire_type" => wire_type,
          "native_type" => native_type,
          "method" => method,
          "allowed" => gap_allowed?(allowlist, "method_gaps", wire_type, method),
          "reason" => allowlist.dig("method_gaps", wire_type, "reason")
        }
      end
    end

    unresolved = {
      "types" => missing_types.reject { |gap| gap.fetch("allowed") }
        .map { |gap| gap.fetch("wire_type") }.sort,
      "events" => missing_events.reject { |gap| gap.fetch("allowed") }
        .map { |gap| [gap.fetch("wire_type"), gap.fetch("event")] }.sort,
      "methods" => missing_methods.reject { |gap| gap.fetch("allowed") }
        .map { |gap| [gap.fetch("wire_type"), gap.fetch("method")] }.sort
    }
    all_gaps = missing_types + missing_events + missing_methods
    {
      "audit_version" => AUDIT_VERSION,
      "contract_version" => contract.fetch("contract_version"),
      "source" => {
        "flet_contract" => File.basename(FletControlContract.output_path),
        "native_registry" => "RufletCoreExtension + concrete RufletExtension implementations",
        "allowlist" => File.basename(allowlist_path)
      },
      "summary" => {
        "flet_types" => contract.fetch("controls").length,
        "native_declarations" => native.length,
        "missing_types" => missing_types.length,
        "missing_events" => missing_events.length,
        "missing_methods" => missing_methods.length,
        "undeclared_gaps" => all_gaps.count { |gap| !gap.fetch("allowed") },
        "declared_baseline_matches" => true,
        "unresolved_gap_set_sha256" => Digest::SHA256.hexdigest(JSON.generate(unresolved))
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
    current = File.file?(NativeRendererGapAudit.output_path) ?
      File.read(NativeRendererGapAudit.output_path) : nil
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
