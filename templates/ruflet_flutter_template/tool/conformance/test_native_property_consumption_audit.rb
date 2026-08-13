#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "audit_native_property_consumption"

class NativePropertyConsumptionAuditTest < Minitest::Test
  def report
    @report ||= NativePropertyConsumptionAudit.build
  end

  def test_checked_in_report_is_deterministic
    assert_equal NativePropertyConsumptionAudit.generate,
      File.read(NativePropertyConsumptionAudit::REPORT_PATH),
      "run tool/conformance/audit_native_property_consumption.rb"
  end

  def test_unclassified_inventory_is_exact_sorted_and_counted
    missing = report.fetch("controls").flat_map do |control|
      control.fetch("properties").filter_map do |property, detail|
        next unless detail.fetch("classification") == "unclassified"
        {
          "family" => control.fetch("family"),
          "wire_type" => control.fetch("wire_type"),
          "property" => property
        }
      end
    end.sort_by { |gap| [gap.fetch("family"), gap.fetch("wire_type"), gap.fetch("property")] }

    assert_equal missing, report.fetch("unclassified")
    assert_equal missing.length, report.dig("summary", "unclassified")
  end

  def test_evidence_categories_cannot_be_satisfied_by_extension_dispatch_metadata
    evidence = report.fetch("controls").flat_map do |control|
      control.fetch("properties").values.flat_map { |property| property.fetch("evidence") }
    end
    refute evidence.any? { |item| item["path"]&.end_with?("/RufletCoreExtension.swift") },
      "extension dispatch declarations are not property-consumption evidence"

    dispatch_patterns = [/\bcase\s+"/, /control\.type/, /\bAnyView\(/, /renderedControlTypes/]
    extension_evidence = evidence.select do |item|
      item["path"]&.match?(%r{/Sources/RufletExtensions/[^/]+/Sources/Extension\.swift\z})
    end
    refute extension_evidence.any? { |item|
      source_line = File.readlines(File.join(NativePropertyConsumptionAudit::ROOT, item.fetch("path")))
        .fetch(item.fetch("line") - 1)
      dispatch_patterns.any? { |pattern| source_line.match?(pattern) }
    },
      "extension registry/type-dispatch lines are not property-consumption evidence"
  end

  def test_clean_extension_dispatch_resolves_concrete_views
    implementations = NativePropertyConsumptionAudit.implementation_map

    assert_includes implementations.fetch("Video"), "VideoControl"
    assert_includes implementations.fetch("BarChart"), "BarChartControl"
    assert_includes implementations.fetch("CandlestickChart"), "CandlestickChartControl"
    assert_includes implementations.fetch("SpinKitWaveSpinner"), "SpinKitControl"
    assert_equal ["AdaptiveTextFieldControl"], implementations.fetch("TextField")
  end

  def test_optional_package_properties_are_proven_by_their_concrete_sources
    implementations = NativePropertyConsumptionAudit.implementation_map
    entries = NativePropertyConsumptionAudit.merged_surface_entries.to_h do |entry|
      [entry.fetch("wire_type"), entry]
    end
    assertions = {
      "Video" => %w[playlist on_completed on_track_changed],
      "BarChart" => %w[groups],
      "SpinKitWaveSpinner" => %w[color size]
    }

    assertions.each do |wire, properties|
      reads = NativePropertyConsumptionAudit.reads_for_types(implementations.fetch(wire))
      entry = entries.fetch(wire, { "family" => "visual", "wire_type" => wire })
      properties.each do |property|
        classification, = NativePropertyConsumptionAudit.classify(
          entry, property, reads, {}, {})
        assert_equal "consumed", classification, "#{wire}.#{property}"
      end
    end
  end

  def test_manual_classifications_are_specific_and_reviewed
    declarations = JSON.parse(File.read(NativePropertyConsumptionAudit::CLASSIFICATIONS_PATH))
    assert_equal %w[parent_consumed service unsupported], declarations.keys.sort
    declarations.each do |category, controls|
      controls.each do |wire, properties|
        refute properties.key?("*"), "#{category} #{wire} uses a forbidden wildcard"
        properties.each do |property, detail|
          assert_kind_of Hash, detail, "#{category} #{wire}.#{property} must be an object"
          refute_empty detail.fetch("reason", "").strip, "#{category} #{wire}.#{property} needs a reason"
        end
      end
    end
  end
end
