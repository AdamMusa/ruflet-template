#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require_relative "audit_native_compound_defaults"
require_relative "audit_native_property_consumption"
require_relative "audit_native_renderer_gaps"
require_relative "generate_flet_control_contract"

# Produces one strict parity verdict for every executable Flet registry entry.
# Aggregate totals are intentionally insufficient: a control is matched only
# when its own declaration, properties, child-slot cardinality, defaults,
# events, and methods are all accounted for by executable Swift code.
module ControlByControlParityAudit
  REPORT_VERSION = 1

  module_function

  def output_path
    File.join(__dir__, "control_by_control_parity_report.json")
  end

  def property_probes(property)
    probes = [property]
    if property.start_with?("on_")
      event = property.delete_prefix("on_")
      probes << event
      if (canonical = NativePropertyConsumptionAudit.event_aliases_to_canonical[event])
        probes.concat([canonical, "on_#{canonical}"])
      end
    end
    probes.uniq
  end

  def native_slots(types)
    source = NativeRendererGapAudit.swift_source_for_types(types)
    slots = {}
    source.scan(
      /\b(child|children|buildWidget|buildWidgets|buildIconOrWidget|buildTextOrWidget)\(\s*"([^"]+)"/m
    ).each do |accessor, property|
      cardinality = %w[children buildWidgets].include?(accessor) ? "many" : "one"
      slots[property] = "many" if slots[property] == "many" || cardinality == "many"
      slots[property] ||= cardinality
    end
    source.scan(/\b(?:property|propertyName):\s*"([^"]+)"/).flatten.each do |property|
      slots[property] ||= "many"
    end
    slots.sort.to_h
  end

  def platform_inapplicable(wire, property)
    NativePropertyConsumptionAudit.classifications
      .fetch("platform_inapplicable", {}).dig(wire, property)
  end

  def build
    contract = FletControlContract.build
    native = NativeRendererGapAudit.declared_native_surface
    compound = NativeCompoundDefaultAudit.build.fetch("entries").to_h do |entry|
      [entry.fetch("control_property"), entry]
    end
    unmatched = []

    controls = contract.fetch("controls").map do |upstream|
      wire = upstream.fetch("wire_type")
      declaration = native[wire]
      unless declaration
        unmatched << { "wire_type" => wire, "category" => "declaration", "name" => wire }
        next upstream.merge(
          "native" => nil,
          "property_matches" => [],
          "child_slot_matches" => [],
          "status" => "missing")
      end

      types = (
        declaration.fetch("implementations") +
        declaration.fetch("service_implementations") +
        declaration.fetch("parent_implementations")
      ).uniq
      reads = NativePropertyConsumptionAudit.reads_for_types(types)
        .transform_values(&:dup)
      if upstream.fetch("classification") == "widget"
        NativePropertyConsumptionAudit.shared_reads.each do |property, evidence|
          (reads[property] ||= []).concat(evidence)
        end
      end

      property_matches = upstream.fetch("properties").map do |property|
        probe = property_probes(property).find { |candidate| reads.key?(candidate) }
        inapplicable = platform_inapplicable(wire, property)
        status = probe ? "matched" : inapplicable ? "platform_inapplicable" : "missing"
        if status == "missing"
          unmatched << { "wire_type" => wire, "category" => "property", "name" => property }
        end
        {
          "property" => property,
          "status" => status,
          "native_probe" => probe,
          "evidence" => probe ? reads.fetch(probe).uniq : inapplicable ? [inapplicable] : []
        }
      end

      slots = native_slots(types)
      child_slot_matches = upstream.fetch("child_slots").map do |property, cardinality|
        actual = slots[property]
        status = actual == cardinality ? "matched" : actual.nil? ? "missing" : "cardinality_mismatch"
        unless status == "matched"
          unmatched << {
            "wire_type" => wire,
            "category" => "child_slot",
            "name" => property,
            "expected" => cardinality,
            "actual" => actual
          }
        end
        {
          "property" => property,
          "expected" => cardinality,
          "actual" => actual,
          "status" => status
        }
      end

      expected_events = upstream.fetch("events")
      actual_events = declaration.fetch("events")
      (expected_events - actual_events).each do |event|
        unmatched << { "wire_type" => wire, "category" => "event", "name" => event }
      end

      expected_methods = upstream.fetch("methods")
      actual_methods = declaration.fetch("methods")
      (expected_methods - actual_methods).each do |method|
        unmatched << { "wire_type" => wire, "category" => "method", "name" => method }
      end

      compound_defaults = upstream.fetch("compound_defaults").map do |property, expected|
        evidence = compound["#{wire}.#{property}"]
        status = evidence&.fetch("status") == "verified" ? "matched" : "missing"
        if status == "missing"
          unmatched << { "wire_type" => wire, "category" => "compound_default", "name" => property }
        end
        { "property" => property, "expected" => expected, "status" => status }
      end

      control_unmatched = unmatched.select { |gap| gap.fetch("wire_type") == wire }
      upstream.merge(
        "native" => declaration,
        "property_matches" => property_matches,
        "child_slot_matches" => child_slot_matches,
        "primitive_defaults_status" => "generated_from_flet_contract",
        "compound_default_matches" => compound_defaults,
        "events_status" => (expected_events - actual_events).empty? ? "matched" : "missing",
        "methods_status" => (expected_methods - actual_methods).empty? ? "matched" : "missing",
        "status" => control_unmatched.empty? ? "matched" : "missing")
    end

    {
      "report_version" => REPORT_VERSION,
      "contract_version" => contract.fetch("contract_version"),
      "source" => contract.fetch("source"),
      "summary" => {
        "controls" => controls.length,
        "matched_controls" => controls.count { |control| control.fetch("status") == "matched" },
        "unmatched_controls" => controls.count { |control| control.fetch("status") != "matched" },
        "properties" => controls.sum { |control| control.fetch("property_matches").length },
        "child_slots" => controls.sum { |control| control.fetch("child_slot_matches").length },
        "events" => controls.sum { |control| control.fetch("events").length },
        "methods" => controls.sum { |control| control.fetch("methods").length },
        "unmatched_rows" => unmatched.length
      },
      "unmatched" => unmatched.sort_by { |gap| [gap.fetch("wire_type"), gap.fetch("category"), gap.fetch("name")] },
      "controls" => controls.sort_by { |control| control.fetch("wire_type") }
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = ControlByControlParityAudit.generate
  if ARGV.delete("--check")
    abort "Control-by-control parity report is stale" unless
      File.file?(ControlByControlParityAudit.output_path) &&
        File.read(ControlByControlParityAudit.output_path) == generated
    gaps = ControlByControlParityAudit.build.dig("summary", "unmatched_rows")
    abort "Control-by-control parity has #{gaps} unmatched rows" unless gaps.zero?
    puts "Control-by-control parity report is current; every row matches."
  else
    File.write(ControlByControlParityAudit.output_path, generated)
    puts JSON.pretty_generate(ControlByControlParityAudit.build.fetch("summary"))
  end
end
