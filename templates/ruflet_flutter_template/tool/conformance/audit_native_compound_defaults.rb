#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require_relative "generate_flet_control_contract"

module NativeCompoundDefaultAudit
  module_function

  SOURCES = "apple_packages/ruflet_apple/Sources"

  # Exact native evidence for every non-primitive default extracted from the
  # pinned Flet renderer. This is deliberately exhaustive: a newly introduced
  # compound default makes the audit fail until its native behavior is proven.
  EVIDENCE = {
    "AnimatedSwitcher.duration" => [
      "RufletEngine/Controls/animated_switcher.swift",
      ['dynamicValue("duration")', ", 1)!"]
    ],
    "AnimatedSwitcher.reverse_duration" => [
      "RufletEngine/Controls/animated_switcher.swift",
      ['dynamicValue("reverse_duration")', ", 1)!"]
    ],
    "CodeEditor.padding" => [
      "RufletExtensions/RufletCodeEditor/Sources/Utils/CodeEditorUtils.swift",
      ['value("padding")', 'map["top"]?.number ?? 0', 'map["right"]?.number ?? 0']
    ],
    "CupertinoButton.border_radius" => [
      "RufletEngine/Controls/cupertino_button.swift",
      ['dynamicValue("border_radius")', "topLeft: 8", "bottomRight: 8"]
    ],
    "CupertinoFilledButton.border_radius" => [
      "RufletEngine/Controls/cupertino_button.swift",
      ['dynamicValue("border_radius")', "topLeft: 8", "bottomRight: 8"]
    ],
    "CupertinoSlidingSegmentedButton.padding" => [
      "RufletEngine/Controls/cupertino_sliding_segmented_button.swift",
      ['dynamicValue("padding")', "top: 2, leading: 3, bottom: 2, trailing: 3"]
    ],
    "CupertinoTextField.padding" => [
      "RufletEngine/Controls/textfield.swift",
      ['dynamicValue("padding")', "top: 7, leading: 7, bottom: 7, trailing: 7"]
    ],
    "CupertinoTintedButton.border_radius" => [
      "RufletEngine/Controls/cupertino_button.swift",
      ['dynamicValue("border_radius")', "topLeft: 8", "bottomRight: 8"]
    ],
    "DataTable2.sort_arrow_animation_duration" => [
      "RufletExtensions/RufletDataTable2/Sources/DataTable2.swift",
      ['value("sort_arrow_animation_duration")', "0.000_150"]
    ],
    "DatePicker.first_date" => [
      "RufletEngine/Controls/date_picker.swift",
      ['value("first_date")', "DateComponents(year: 1900, month: 1, day: 1)"]
    ],
    "DatePicker.inset_padding" => [
      "RufletEngine/Controls/date_picker.swift",
      ['dynamicValue("inset_padding")', "top: 24, leading: 16, bottom: 24, trailing: 16"]
    ],
    "DatePicker.last_date" => [
      "RufletEngine/Controls/date_picker.swift",
      ['value("last_date")', "DateComponents(year: 2050, month: 1, day: 1)"]
    ],
    "DateRangePicker.first_date" => [
      "RufletEngine/Controls/date_range_picker.swift",
      ['value("first_date")', "DateComponents(year: 1900, month: 1, day: 1)"]
    ],
    "DateRangePicker.last_date" => [
      "RufletEngine/Controls/date_range_picker.swift",
      ['value("last_date")', "DateComponents(year: 2050, month: 1, day: 1)"]
    ],
    "ExpansionPanelList.expanded_header_padding" => [
      "RufletEngine/Controls/expansion_panel.swift",
      ['dynamicValue("expanded_header_padding")', "top: 16, leading: 0, bottom: 16, trailing: 0"]
    ],
    "InteractiveViewer.boundary_margin" => [
      "RufletEngine/Controls/interactive_viewer.swift",
      ['dynamicValue("boundary_margin")', "?? EdgeInsets()"]
    ],
    "PopupMenuButton.padding" => [
      "RufletEngine/Controls/popup_menu_button.swift",
      ['dynamicValue("padding")', "RufletLayoutDefaults.popupMenuButton"]
    ],
    "SafeArea.minimum_padding" => [
      "RufletEngine/Controls/safe_area.swift",
      ['dynamicValue("minimum_padding")', "?? EdgeInsets()"]
    ],
    "Shimmer.period" => [
      "RufletEngine/Controls/shimmer.swift",
      ['dynamicValue("period")', ", 1.5) ?? 1.5"]
    ],
    "SlidePicker.indicator_alignment_begin" => [
      "RufletExtensions/RufletColorPickers/Sources/SlidePicker.swift",
      ['value("indicator_alignment_begin"), defaultX: -1, defaultY: -3']
    ],
    "SlidePicker.indicator_size" => [
      "RufletExtensions/RufletColorPickers/Sources/SlidePicker.swift",
      ['value("indicator_size")', "CGSize(width: 280, height: 50)"]
    ],
    "SlidePicker.slider_size" => [
      "RufletExtensions/RufletColorPickers/Sources/SlidePicker.swift",
      ['value("slider_size")', "CGSize(width: 260, height: 40)"]
    ],
    "SnackBar.duration" => [
      "RufletEngine/Controls/snack_bar.swift",
      ['dynamicValue("duration")', ", 4) ?? 4"]
    ],
    "TabBar.indicator_padding" => [
      "RufletEngine/Controls/tabs.swift",
      ['dynamicValue("indicator_padding")', "?? EdgeInsets()"]
    ],
    "View.padding" => [
      "RufletEngine/Controls/view.swift",
      ['dynamicValue("padding")', "top: 10, leading: 10, bottom: 10, trailing: 10"]
    ]
  }.freeze

  def template_root
    FletControlContract.template_root
  end

  def report_path
    File.join(__dir__, "native_compound_default_report.json")
  end

  def contract_defaults
    contract = JSON.parse(File.read(FletControlContract.output_path))
    contract.fetch("controls").flat_map do |control|
      control.fetch("compound_defaults").map do |property, value|
        ["#{control.fetch("wire_type")}.#{property}", value]
      end
    end.to_h
  end

  def build
    defaults = contract_defaults
    missing_keys = defaults.keys - EVIDENCE.keys
    stale_keys = EVIDENCE.keys - defaults.keys
    entries = defaults.sort.map do |key, expected|
      relative, tokens = EVIDENCE[key]
      path = relative && File.join(template_root, SOURCES, relative)
      source = path && File.file?(path) ? File.read(path) : ""
      missing_tokens = Array(tokens).reject { |token| source.include?(token) }
      status = relative && missing_tokens.empty? ? "verified" : "missing"
      {
        "control_property" => key,
        "expected_default" => expected,
        "native_source" => relative && File.join(SOURCES, relative),
        "native_evidence" => tokens,
        "missing_evidence" => missing_tokens,
        "status" => status
      }
    end
    missing = missing_keys + stale_keys.map { |key| "stale:#{key}" } +
      entries.filter_map { |entry| entry["control_property"] if entry["status"] == "missing" }
    {
      "report_version" => 1,
      "source" => "Pinned Flet compound defaults",
      "summary" => {
        "contract_defaults" => defaults.length,
        "verified" => entries.count { |entry| entry["status"] == "verified" },
        "missing" => missing.length
      },
      "missing" => missing.sort,
      "entries" => entries
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = NativeCompoundDefaultAudit.generate
  if ARGV.include?("--check")
    abort "Native compound default report is stale" unless
      File.file?(NativeCompoundDefaultAudit.report_path) &&
        File.read(NativeCompoundDefaultAudit.report_path) == generated
    abort "Native compound default audit has missing evidence" unless
      NativeCompoundDefaultAudit.build.fetch("missing").empty?
    puts "Native compound default report is current and complete"
  else
    File.write(NativeCompoundDefaultAudit.report_path, generated)
    summary = NativeCompoundDefaultAudit.build.fetch("summary")
    puts "Generated #{NativeCompoundDefaultAudit.report_path}: " \
      "#{summary.fetch("verified")}/#{summary.fetch("contract_defaults")} verified"
  end
end
