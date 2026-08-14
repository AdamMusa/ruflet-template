#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require_relative "generate_flet_control_contract"

module NativeLayoutDefaultAudit
  module_function

  GETTER = /(?:[a-zA-Z_]\w*|widget\.control)\.(get(?:Padding|Margin|EdgeInsets|EdgeInsetsDirectional|WidgetStatePadding))\s*\(/
  BRIDGES = {
    "cupertino_app_bar" => "app_bar",
    "cupertino_bottom_sheet" => "bottom_sheet",
    "cupertino_textfield" => "textfield"
  }.freeze
  SHARED_SOURCES = {
    "utils.badge" => ["RufletEngine/Controls/base_controls.swift"],
    "utils.form_field" => [
      "RufletEngine/Controls/dropdownm2.swift",
      "RufletEngine/Controls/textfield.swift"
    ],
    "utils.popup_menu" => ["RufletEngine/Controls/popup_menu_button.swift"],
    "flet_code_editor.code_editor" => [
      "RufletExtensions/RufletCodeEditor/Sources/Utils/CodeEditorUtils.swift"
    ]
  }.freeze

  # Values Flutter supplies when Flet deliberately passes null. This table is
  # exhaustive: generation fails when a new inherited layout call appears.
  INHERITED = {
    "alert_dialog.action_button_padding" => ["horizontal 8", "alertDialogActionButton"],
    "alert_dialog.actions_padding" => ["Material 3: left/right/bottom 24", "alertDialogActions"],
    "alert_dialog.icon_padding" => ["conditional icon/title/content insets", "alertDialogIcon"],
    "alert_dialog.title_padding" => ["conditional icon/title/content insets", "alertDialogTitle"],
    "app_bar.actions_padding" => ["zero", "appBarActions"],
    "banner.content_padding" => ["single row: start 16/top 2; stacked: start/end 16/top 24/bottom 4", "bannerContent"],
    "banner.leading_padding" => ["end 16", "bannerLeading"],
    "banner.margin" => ["bottom 10 only when elevated", "bannerMargin"],
    "base_controls.margin" => ["none", '"margin"'],
    "bottom_app_bar.padding" => ["Material 3: horizontal 16/vertical 12", "bottomAppBar"],
    "card.margin" => ["all 4", "cardMargin"],
    "chip.label_padding" => ["horizontal 8", "chipLabel"],
    "chip.padding" => ["all 8", "RufletLayoutDefaults.chip"],
    "container.margin" => ["none", '"margin"'],
    "container.padding" => ["none", '"padding"'],
    "cupertino_app_bar.padding" => ["horizontal 16", "cupertinoNavigationBar"],
    "cupertino_bottom_sheet.padding" => ["zero", '"padding"'],
    "cupertino_button.padding" => ["small 12x6; medium 15x10; large 20x16", "size.padding"],
    "cupertino_list_tile.content_padding" => ["base/notched/leading conditional Cupertino insets", "cupertinoListTile"],
    "cupertino_segmented_button.padding" => ["horizontal 16", "cupertinoSegmentedButton"],
    "dropdown.content_padding" => ["Material 3 InputDecoration outline/filled/dense/collapsed defaults", "formField"],
    "dropdownm2.padding" => ["none", '"padding"'],
    "expansion_tile.controls_padding" => ["zero", '"controls_padding"'],
    "expansion_tile.tile_padding" => ["Material 3 ListTile start 16/end 24", "RufletLayoutDefaults.listTile"],
    "grid_view.padding" => ["none", '"padding"'],
    "icon_button.padding" => ["all 8", "EdgeInsets(top: 8, leading: 8"],
    "list_tile.content_padding" => ["Material 3 start 16/end 24", "RufletLayoutDefaults.listTile"],
    "list_view.padding" => ["none", '"padding"'],
    "navigation_bar.label_padding" => ["top 4", "navigationBarLabel"],
    "navigation_rail.padding" => ["zero", "navigationRailDestination"],
    "popup_menu_button.menu_padding" => ["vertical 8", "RufletLayoutDefaults.popupMenu"],
    "progress_ring.padding" => ["zero", '"padding"'],
    "reorderable_list_view.padding" => ["none", '"padding"'],
    "search_bar.bar_padding" => ["horizontal 8", "RufletLayoutDefaults.searchBar"],
    "search_bar.view_bar_padding" => ["horizontal 8", "searchViewBar"],
    "search_bar.view_padding" => ["none", '"view_padding"'],
    "segmented_button.padding" => ["null (no expanded insets)", '"padding"'],
    "slider.padding" => ["zero", '"padding"'],
    "snack_bar.margin" => ["floating: left/right 15, top 5, bottom 10", "floatingSnackBarMargin"],
    "snack_bar.padding" => ["behavior/action/close conditional content insets", "snackBarContent"],
    "switch.padding" => ["Material 3 horizontal 4", "materialSwitch"],
    "tabs.icon_margin" => ["primary tab icon bottom 10", "primaryTabIcon"],
    "tabs.label_padding" => ["horizontal 16", "RufletLayoutDefaults.tabLabel"],
    "tabs.padding" => ["none", '"padding"'],
    "utils.badge.padding" => ["horizontal 4", "RufletLayoutDefaults.badge"],
    "utils.form_field.content_padding" => ["Material 3 InputDecoration outline/filled/dense/collapsed defaults", "formField"],
    "utils.popup_menu.padding" => ["horizontal 12", "popupMenuItem"]
  }.freeze

  def template_root
    FletControlContract.template_root
  end

  def report_path
    File.join(__dir__, "native_layout_default_report.json")
  end

  def source_key(dart_path)
    relative = dart_path.delete_prefix(File.join(template_root, "flet_packages/") )
    package, remainder = relative.split("/", 2)
    base = File.basename(dart_path, ".dart")
    return base if package == "flet" && remainder.start_with?("lib/src/controls/")
    return "utils.#{base}" if package == "flet" && remainder.start_with?("lib/src/utils/")

    "#{package}.#{base}"
  end

  def swift_paths(key, base)
    if (relative_paths = SHARED_SOURCES[key])
      return relative_paths.map do |relative|
        File.join(template_root, "apple_packages/ruflet_apple/Sources", relative)
      end
    end

    effective = BRIDGES.fetch(base, base)
    matches = Dir.glob(File.join(
      template_root, "apple_packages/ruflet_apple/Sources/RufletEngine/**/#{effective}.swift"
    )).sort
    matches.one? ? matches : []
  end

  def build
    calls = []
    missing = []
    inherited_seen = []
    root = File.join(template_root, "flet_packages")
    Dir.glob(File.join(root, "**/lib/**/*.dart")).sort.each do |dart_path|
      source = File.read(dart_path)
      base = File.basename(dart_path, ".dart")
      source_prefix = source_key(dart_path)
      source.to_enum(:scan, GETTER).each do
        match = Regexp.last_match
        arguments = FletControlContract.invocation_arguments(source, match.end(0) - 1)
        property = arguments.fetch(0, "")[/\A["']([^"']+)["']\z/, 1]
        next unless property

        key = "#{source_prefix}.#{property}"
        source_line = source[0...match.begin(0)].count("\n") + 1
        companions = swift_paths(source_prefix, base)
        swift_sources = companions.map { |path| File.read(path) }
        swift_source = swift_sources.join("\n")
        parsed = arguments[1] && FletControlContract.compound_default(arguments[1])
        inherited = parsed.nil? && arguments[1].nil?
        inherited_contract = INHERITED[key]
        inherited_seen << key if inherited
        evidence = inherited_contract&.last || %Q{"#{property}"}
        reads_property = companions.any? && swift_sources.all? { |text| text.include?(%Q{"#{property}"}) }
        proves_default = !inherited || (inherited_contract &&
          (swift_source.include?(evidence) || File.read(File.join(
            template_root,
            "apple_packages/ruflet_apple/Sources/RufletEngine/Utils/layout_defaults.swift"
          )).include?(evidence)))

        status = reads_property && proves_default ? "verified" : "missing"
        missing << key unless status == "verified"
        calls << {
          "control_source" => dart_path.delete_prefix("#{template_root}/"),
          "line" => source_line,
          "getter" => match[1],
          "property" => property,
          "default_origin" => inherited ? "flutter_widget" : "flet_literal",
          "expected_default" => parsed || inherited_contract&.first || arguments[1],
          "native_sources" => companions.map { |path| path.delete_prefix("#{template_root}/") },
          "native_evidence" => evidence,
          "status" => status
        }
      end
    end

    stale = INHERITED.keys - inherited_seen.uniq
    missing.concat(stale.map { |key| "stale:#{key}" })
    {
      "report_version" => 1,
      "source" => "Pinned Flet layout getter calls and Flutter widget defaults",
      "summary" => {
        "call_sites" => calls.length,
        "distinct_control_properties" => calls.map { |call| [call["control_source"], call["property"]] }.uniq.length,
        "flet_literal_defaults" => calls.count { |call| call["default_origin"] == "flet_literal" },
        "flutter_inherited_defaults" => calls.count { |call| call["default_origin"] == "flutter_widget" },
        "verified" => calls.count { |call| call["status"] == "verified" },
        "missing" => missing.length
      },
      "missing" => missing.sort,
      "calls" => calls
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = NativeLayoutDefaultAudit.generate
  if ARGV.include?("--check")
    abort "Native layout default report is stale" unless File.file?(NativeLayoutDefaultAudit.report_path) &&
      File.read(NativeLayoutDefaultAudit.report_path) == generated
    abort "Native layout default audit has missing evidence" unless NativeLayoutDefaultAudit.build.fetch("missing").empty?
    puts "Native layout default report is current and complete"
  else
    File.write(NativeLayoutDefaultAudit.report_path, generated)
    summary = NativeLayoutDefaultAudit.build.fetch("summary")
    puts "Generated #{NativeLayoutDefaultAudit.report_path}: #{summary.fetch("verified")}/#{summary.fetch("call_sites")} verified"
  end
end
