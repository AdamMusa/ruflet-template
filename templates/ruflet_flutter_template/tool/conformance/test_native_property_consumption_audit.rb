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

  def test_every_public_property_has_an_executable_or_reviewed_classification
    missing = report.fetch("unclassified")
    assert missing.empty?, <<~MESSAGE
      Native controls have unclassified Ruflet public DSL properties.
      Implement the property, identify the actual structural parent/service consumer,
      or add a reviewed platformUnsupported reason to native_property_classifications.json.
      First gaps: #{missing.first(20).map { |gap| "#{gap.fetch("wire_type")}.#{gap.fetch("property")}" }.join(", ")}
    MESSAGE
  end

  def test_evidence_categories_cannot_be_satisfied_by_registry_descriptors
    forbidden = %r{RufletUI/ControlRegistry\.swift\z}
    evidence = report.fetch("controls").flat_map do |control|
      control.fetch("properties").values.flat_map { |property| property.fetch("evidence") }
    end
    refute evidence.any? { |item| item["path"]&.match?(forbidden) },
      "registry declarations are not property-consumption evidence"
  end

  def test_optional_descriptor_registrars_resolve_concrete_views
    implementations = NativePropertyConsumptionAudit.implementation_map

    assert_equal ["VideoControlView"], implementations.fetch("Video")
    assert_equal ["ChartControlView"], implementations.fetch("BarChart")
    assert_equal ["ChartControlView"], implementations.fetch("CandlestickChart")
    assert_equal ["SpinKitControlView"], implementations.fetch("RufletSpinKit")
    assert_equal ["SpinKitControlView"], implementations.fetch("SpinKitWaveSpinner")
  end

  def test_optional_package_properties_are_proven_by_their_concrete_sources
    implementations = NativePropertyConsumptionAudit.implementation_map
    entries = NativePropertyConsumptionAudit.merged_surface_entries.to_h do |entry|
      [entry.fetch("wire_type"), entry]
    end
    assertions = {
      "Video" => %w[playlist on_completed on_track_changed],
      "BarChart" => %w[groups],
      "RufletSpinKit" => %w[variant]
    }

    assertions.each do |wire, properties|
      reads = NativePropertyConsumptionAudit.reads_for_types(implementations.fetch(wire))
      properties.each do |property|
        classification, = NativePropertyConsumptionAudit.classify(
          entries.fetch(wire), property, reads, {}, {})
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
