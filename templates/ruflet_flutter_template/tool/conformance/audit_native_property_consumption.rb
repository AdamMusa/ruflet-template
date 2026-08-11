#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "set"

module NativePropertyConsumptionAudit
  ROOT = File.expand_path("../..", __dir__)
  SWIFT_ROOT = File.join(ROOT, "apple_packages", "ruflet_apple", "Sources")
  SURFACE_PATH = File.join(__dir__, "ruflet_control_surface.json")
  CLASSIFICATIONS_PATH = File.join(__dir__, "native_property_classifications.json")
  REPORT_PATH = File.join(__dir__, "native_property_consumption_report.json")
  REPORT_VERSION = 1

  # These modifiers are applied by ControlView to every visual control. Their
  # reads are therefore real parent-owned consumption, unlike a property name
  # merely appearing in a descriptor or generated defaults table.
  SHARED_IMPLEMENTATIONS = [
    "apple_packages/ruflet_apple/Sources/RufletUI/Support/CommonModifiers.swift"
  ].freeze

  # Ruflet owns these constructor attributes above the renderer boundary. They
  # are deliberately exact names, not a wildcard escape hatch.
  DSL_OWNED_PROPERTIES = {
    "data" => "Ruflet application metadata; it is preserved on the Ruby control and has no visual native behavior",
    "key" => "Ruflet control identity used while constructing and reconciling the wire tree"
  }.freeze

  # Flet resolves these on the child from constraints supplied by its parent.
  # The Swift readers live in Stack/ResponsiveRow rather than in every child.
  LAYOUT_PARENT_PROPERTIES = %w[animate_position bottom col left right top].freeze

  # Metadata controls intentionally render EmptyView. Their properties are
  # read by these concrete parents; the parent source remains the evidence.
  PARENT_IMPLEMENTATIONS = {
    "ExpansionPanel" => %w[ExpansionPanelListControlView],
    "Tab" => %w[TabsControlView TabBarControlView],
    "DataColumn" => %w[DataTableControlView],
    "DataRow" => %w[DataTableControlView],
    "DataCell" => %w[DataTableControlView],
    "NavigationBarDestination" => %w[NavigationBarControlView],
    "NavigationRailDestination" => %w[NavigationRailControlView],
    "NavigationDrawerDestination" => %w[NavigationDrawerControlView],
    "ReorderableDragHandle" => %w[ReorderableListControlView],
    "Segment" => %w[SegmentedButtonControlView],
    "Option" => %w[DropdownControlView DropdownM2ControlView],
    "DropdownOption" => %w[DropdownControlView DropdownM2ControlView],
    "AutoCompleteSuggestion" => %w[AutoCompleteControlView],
    "Page" => %w[ClientCapabilities],
    "AlertDialog" => %w[DialogPresenter],
    "CupertinoAlertDialog" => %w[DialogPresenter],
    "BottomSheet" => %w[DialogPresenter],
    "CupertinoBottomSheet" => %w[DialogPresenter],
    "SnackBar" => %w[DialogPresenter],
    "Banner" => %w[DialogPresenter],
    "TileLayer" => %w[MapControlView],
    "MarkerLayer" => %w[MapControlView],
    "Marker" => %w[MapControlView],
    "CircleLayer" => %w[MapControlView],
    "CircleMarker" => %w[MapControlView],
    "PolylineLayer" => %w[MapControlView],
    "PolylineMarker" => %w[MapControlView],
    "PolygonLayer" => %w[MapControlView],
    "PolygonMarker" => %w[MapControlView],
    "SimpleAttribution" => %w[MapControlView],
    # Text doubles as a Canvas shape, the way Arc and Circle do.
    "Text" => %w[CanvasControlView],
    "Arc" => %w[CanvasControlView],
    "Circle" => %w[CanvasControlView],
    "Color" => %w[CanvasControlView],
    "Fill" => %w[CanvasControlView],
    "Line" => %w[CanvasControlView],
    "Oval" => %w[CanvasControlView],
    "Path" => %w[CanvasControlView],
    "Points" => %w[CanvasControlView],
    "Rect" => %w[CanvasControlView],
    "Shadow" => %w[CanvasControlView],
    "RadarChartTitle" => %w[ChartControlView],
    "RadarDataSet" => %w[ChartControlView],
    "RadarDataSetEntry" => %w[ChartControlView],
    "CandlestickChartSpot" => %w[ChartControlView],
    "ScatterChartSpot" => %w[ChartControlView],
    "group" => %w[ChartControlView],
    "rod" => %w[ChartControlView],
    "stack_item" => %w[ChartControlView],
    "axis" => %w[ChartControlView],
    "l" => %w[ChartControlView],
    "data" => %w[ChartControlView],
    "p" => %w[ChartControlView],
    "section" => %w[ChartControlView]
  }.freeze

  ACCESSORS = %w[
    array bool controlID controlIDs double enumValue rufletBool rufletDouble rufletString int
    map skipsRufletProperty string
  ].freeze

  module_function

  def relative(path)
    path.delete_prefix("#{ROOT}/")
  end

  def swift_files
    @swift_files ||= Dir.glob(File.join(SWIFT_ROOT, "**", "*.swift")).sort.to_h do |path|
      [path, File.readlines(path, chomp: true)]
    end
  end

  def code_lines(lines)
    in_block = false
    lines.map do |line|
      output = +""
      index = 0
      while index < line.length
        if in_block
          ending = line.index("*/", index)
          if ending
            in_block = false
            index = ending + 2
          else
            index = line.length
          end
        else
          block = line.index("/*", index)
          single = line.index("//", index)
          boundary = [block, single].compact.min
          if boundary.nil?
            output << line[index..]
            index = line.length
          elsif boundary == single
            output << line[index...single]
            index = line.length
          else
            output << line[index...block]
            in_block = true
            index = block + 2
          end
        end
      end
      output
    end
  end

  # The concrete types this package declares. An extension is only followed
  # when it extends one of these, so `extension View` — a protocol the whole
  # renderer conforms to — does not become evidence for every control.
  def declared_types
    @declared_types ||= swift_files.values.flat_map { |raw_lines|
      code_lines(raw_lines).flat_map do |line|
        line.scan(/\b(?:struct|class|actor|enum)\s+([A-Za-z_][A-Za-z0-9_]*)\b/).flatten
      end
    }.to_set
  end

  def type_scopes
    @type_scopes ||= begin
      scopes = Hash.new { |hash, key| hash[key] = [] }
      swift_files.each do |path, raw_lines|
        lines = code_lines(raw_lines)
        lines.each_with_index do |line, index|
          name = line[/\b(?:struct|class|actor|enum)\s+([A-Za-z_][A-Za-z0-9_]*)\b/, 1]
          # An extension's body belongs to the type it extends — a delegate
          # conformance is where a capture pipeline reports from — but only
          # when that type is one this package declares. Following
          # `extension View` would make every control's evidence universal.
          if name.nil?
            extended = line[/\bextension\s+([A-Za-z_][A-Za-z0-9_]*)\b/, 1]
            name = extended if extended && declared_types.include?(extended)
          end
          next if name.nil?

          depth = 0
          opened = false
          finish = index
          lines[index..].each_with_index do |body_line, offset|
            depth += body_line.count("{")
            opened ||= body_line.include?("{")
            depth -= body_line.count("}")
            finish = index + offset
            break if opened && depth <= 0
          end
          scopes[name] << { path: path, start: index, finish: finish }
        end
      end
      scopes
    end
  end

  def implementation_map
    @implementation_map ||= begin
      result = Hash.new { |hash, key| hash[key] = [] }
      swift_files.each do |_path, raw_lines|
        pending = []
        code_lines(raw_lines).each do |line|
          if line.match?(/^\s*case\s+/)
            pending = line.scan(/"([A-Za-z0-9_]+)"/).flatten
          elsif !pending.empty? && line.match?(/^\s*"/)
            pending.concat(line.scan(/"([A-Za-z0-9_]+)"/).flatten)
          end

          if !pending.empty? && (match = line.match(/return\s+AnyView\(([A-Za-z_][A-Za-z0-9_]*)\s*\(/))
            pending.each { |wire| result[wire].push(match[1]) }
            pending = []
          end

          line.scan(/ControlRegistry\.register\("([A-Za-z0-9_]+)"\).*?([A-Za-z_][A-Za-z0-9_]*ControlView)\s*\(/) do |wire, type|
            result[wire].push(type)
          end
        end
        code_lines(raw_lines).join("\n").scan(
          /ControlRegistry\.register\("([A-Za-z0-9_]+)"\).*?AnyView\(([A-Za-z_][A-Za-z0-9_]*ControlView)\s*\(/m
        ) do |wire, type|
          result[wire].push(type)
        end
      end
      result.transform_values { |types| types.uniq.sort }
    end
  end

  def service_implementation_map
    @service_implementation_map ||= begin
      result = Hash.new { |hash, key| hash[key] = [] }
      swift_files.each do |_path, raw_lines|
        text = code_lines(raw_lines).join("\n")
        text.scan(/registerNamed\("([A-Za-z0-9_]+)"\)\s*\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(/m) do |wire, type|
          result[wire] << type
        end
        text.scan(/register\(([A-Za-z_][A-Za-z0-9_]*)\.self\)/) do |(type)|
          type_scopes.fetch(type, []).each do |scope|
            body = code_lines(swift_files.fetch(scope[:path]))[scope[:start]..scope[:finish]].join("\n")
            wire = body[/static\s+(?:let|var)\s+wireType\s*=\s*"([A-Za-z0-9_]+)"/, 1]
            result[wire] << type if wire
          end
        end
      end
      result.transform_values { |types| types.uniq.sort }
    end
  end

  # An `events.fire(` whose event name sits on a following line is the same
  # read as the single-line form. Swift formatting wraps these constantly, so
  # scanning one line at a time reported implemented events as unconsumed.
  EVENT_CALL_LOOKAHEAD = 3

  def property_reads(lines, path:, start_line: 0)
    reads = Hash.new { |hash, key| hash[key] = [] }
    scanned = code_lines(lines)
    scanned.each_with_index do |line, index|
      keys = []
      accessor_pattern = ACCESSORS.join("|")
      # A presenter reads the control it is showing through a local of its
      # own, so the receiver is not always `node`.
      line.scan(/\b[a-z][A-Za-z0-9_]*\??\.(?:#{accessor_pattern})\(\s*(?:forKey:\s*)?"([^"]+)"/) { |match| keys << match[0] }
      line.scan(/\bnode\.props\[\s*"([^"]+)"\s*\]/) { |match| keys << match[0] }
      line.scan(/\b(?:child|control|item|option|suggestion|value)?\.?(?:props)\[\s*"([^"]+)"\s*\]/) { |match| keys << match[0] }
      # The register payload builds the page map by key, which is how the
      # engine reports its environment rather than reading it.
      line.scan(/\bpage\[\s*"([^"]+)"\s*\]\s*=/) { |match| keys << match[0] }
      line.scan(/\bcall\.argument\(\s*"([^"]+)"\s*\)/) { |match| keys << match[0] }
      line.scan(/\bnode\.(?:handlesEvent|sendEvent)\(\s*"([^"]+)"/) { |match| keys << "on_#{match[0]}" }
      line.scan(/\b(?:context\.)?emitEvent\([^\n]*?"([^"]+)"/) { |match| keys << "on_#{match[0]}" }
      # `events.fire` is the event sink; `onEvent` is the callback a platform
      # view reports through instead, and `emit` is the one a service uses.
      # Each takes the event name first —
      # that is how the AppKit pointer monitor raises the secondary and
      # tertiary buttons. Both wrap, so both are read over a window.
      window = scanned[index, EVENT_CALL_LOOKAHEAD].join(" ")
      if (event_call = window[/\b(?:events\.fire|events\.send|onEvent|emit)\((.*)$/, 1])
        # Stop at the closing paren so a following statement's literals on the
        # same window cannot be attributed to this call.
        event_call[/\A[^)]*/].scan(/"([^"]+)"/) { |match| keys << "on_#{match[0]}" }
      end
      line.scan(/\bproperty:\s*"([^"]+)"/) { |match| keys << match[0] }
      # A reusable slot reads whichever property it was handed, so the literal
      # sits at the construction site rather than inside the accessor:
      # RufletFormFieldSlot(key: "helper", styleKey: "helper_style") and
      # events.commit(key: "selected_index") all name a real property.
      line.scan(/\b[A-Za-z]*[kK]ey:\s*"([^"]+)"/) { |match| keys << match[0] }
      # A reusable reporter takes the event it fires as an argument, so the
      # only literal is at the call site: NamedSemanticsAction(event: "copy")
      # and events.commit(..., event: "change") both name a real event.
      line.scan(/\bevent:\s*"([^"]+)"/) { |match| keys << "on_#{match[0]}" }
      # RufletEventSink#commit defaults to writing `value` and reporting
      # `change`, so the commonest read of either has no literal to find.
      if (commit = window[/\bevents\.commit\((.*)$/, 1])
        call = commit[/\A[^)]*/]
        keys << "on_change" unless call.include?("event:")
        keys << "value" unless call.include?("key:")
      end
      keys.uniq.each do |key|
        reads[key] << { "path" => relative(path), "line" => start_line + index + 1 }
      end
    end
    reads
  end

  def reads_for_types(types)
    reads = Hash.new { |hash, key| hash[key] = [] }
    implementation_closure(types).each do |type|
      type_scopes.fetch(type, []).each do |scope|
        lines = swift_files.fetch(scope[:path])[scope[:start]..scope[:finish]]
        property_reads(lines, path: scope[:path], start_line: scope[:start]).each do |key, evidence|
          reads[key].concat(evidence)
        end
        code_lines(lines).each_with_index do |line, index|
          next unless line.match?(/\bnode\.childIDs\b/)
          evidence = { "path" => relative(scope[:path]), "line" => scope[:start] + index + 1 }
          reads["controls"] << evidence
          reads["content"] << evidence
        end
      end
    end
    reads
  end

  def implementation_closure(types)
    seen = {}
    queue = types.dup
    until queue.empty?
      type = queue.shift
      next if seen[type]
      seen[type] = true
      type_scopes.fetch(type, []).each do |scope|
        body = code_lines(swift_files.fetch(scope[:path]))[scope[:start]..scope[:finish]].join("\n")
        # Concrete controls commonly delegate constructor/default parsing to a
        # pure helper (for example CollectionDefaults). Following only View
        # and Modifier constructors made those real reads look unimplemented.
        # Keep this deliberately suffix-scoped so arbitrary framework types do
        # not become evidence for a control.
        body.scan(/\b([A-Z][A-Za-z0-9_]*)\s*(?:\(|\.|\{)/) do |(dependency)|
          queue << dependency if type_scopes.key?(dependency)
        end
      end
    end
    seen.keys
  end

  def shared_reads
    @shared_reads ||= SHARED_IMPLEMENTATIONS.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |relative_path, reads|
      path = File.join(ROOT, relative_path)
      property_reads(swift_files.fetch(path), path: path).each { |key, evidence| reads[key].concat(evidence) }
    end
  end

  def layout_parent_reads
    @layout_parent_reads ||= begin
      reads = Hash.new { |hash, key| hash[key] = [] }
      %w[
        apple_packages/ruflet_apple/Sources/RufletUI/Controls/StackControls.swift
      ].each do |relative_path|
        path = File.join(ROOT, relative_path)
        property_reads(swift_files.fetch(path), path: path).each do |key, evidence|
          reads[key].concat(evidence) if LAYOUT_PARENT_PROPERTIES.include?(key)
        end
      end
      reads
    end
  end

  def classifications
    @classifications ||= JSON.parse(File.read(CLASSIFICATIONS_PATH))
  end

  def declared(category, wire, keyword)
    value = classifications.fetch(category, {}).dig(wire, keyword)
    return unless value

    abort "#{category} #{wire}.#{keyword} must provide a non-empty reason" unless value.is_a?(Hash) && !value.fetch("reason", "").strip.empty?
    value
  end

  def merged_surface_entries
    entries = JSON.parse(File.read(SURFACE_PATH)).fetch("entries")
    entries.group_by { |entry| [entry.fetch("family"), entry.fetch("wire_type")] }.map do |(family, wire), aliases|
      {
        "family" => family,
        "wire_type" => wire,
        "dsl_names" => aliases.map { |entry| entry.fetch("dsl_name") }.uniq.sort,
        "keywords" => aliases.flat_map { |entry| entry.fetch("keywords") }.uniq.sort
      }
    end.sort_by { |entry| [entry.fetch("family"), entry.fetch("wire_type")] }
  end

  def classify(entry, keyword, local_reads, parent_reads, service_reads)
    wire = entry.fetch("wire_type")
    family = entry.fetch("family")
    probes = [keyword]
    probes << keyword.delete_prefix("on_") if keyword.start_with?("on_")

    if (probe = probes.find { |candidate| service_reads.key?(candidate) })
      return ["service", service_reads.fetch(probe)]
    end
    if (probe = probes.find { |candidate| local_reads.key?(candidate) })
      return ["consumed", local_reads.fetch(probe)]
    end
    if (probe = probes.find { |candidate| parent_reads.key?(candidate) })
      return ["parent_consumed", parent_reads.fetch(probe)]
    end
    if (family == "visual" || !implementation_map.fetch(wire, []).empty?) &&
        (probe = probes.find { |candidate| shared_reads.key?(candidate) })
      return ["parent_consumed", shared_reads.fetch(probe)]
    end
    if (family == "visual" || !implementation_map.fetch(wire, []).empty?) && (reason = DSL_OWNED_PROPERTIES[keyword])
      return ["parent_consumed", [{ "consumer" => "Ruflet::Control wire construction", "reason" => reason }]]
    end
    if family == "service" && (reason = DSL_OWNED_PROPERTIES[keyword])
      return ["service", [{ "consumer" => "Ruflet::Control wire construction", "reason" => reason }]]
    end
    if (family == "visual" || !implementation_map.fetch(wire, []).empty?) &&
        LAYOUT_PARENT_PROPERTIES.include?(keyword) && layout_parent_reads.key?(keyword)
      return ["parent_consumed", layout_parent_reads.fetch(keyword)]
    end
    if (detail = declared("parent_consumed", wire, keyword))
      return ["parent_consumed", [detail]]
    end
    if (detail = declared("service", wire, keyword))
      return ["service", [detail]]
    end
    if (detail = declared("unsupported", wire, keyword))
      return ["unsupported", [detail]]
    end
    ["unclassified", []]
  end

  def build
    controls = merged_surface_entries.map do |entry|
      wire = entry.fetch("wire_type")
      implementations = implementation_map.fetch(wire, [])
      service_implementations = service_implementation_map.fetch(wire, [])
      local_reads = reads_for_types(implementations)
      parent_implementations = PARENT_IMPLEMENTATIONS.fetch(wire, [])
      parent_reads = reads_for_types(parent_implementations)
      service_reads = reads_for_types(service_implementations)
      properties = entry.fetch("keywords").to_h do |keyword|
        category, evidence = classify(entry, keyword, local_reads, parent_reads, service_reads)
        [keyword, { "classification" => category, "evidence" => evidence.uniq }]
      end
      entry.merge(
        "implementations" => implementations,
        "parent_implementations" => parent_implementations,
        "service_implementations" => service_implementations,
        "properties" => properties
      ).reject { |key, _| key == "keywords" }
    end

    counts = Hash.new(0)
    controls.each do |control|
      control.fetch("properties").each_value { |property| counts[property.fetch("classification")] += 1 }
    end
    unclassified = controls.flat_map do |control|
      control.fetch("properties").filter_map do |keyword, property|
        next unless property.fetch("classification") == "unclassified"
        { "family" => control.fetch("family"), "wire_type" => control.fetch("wire_type"), "property" => keyword }
      end
    end

    {
      "report_version" => REPORT_VERSION,
      "source" => "ruflet_control_surface.json KEYWORDS verified against native Swift property reads",
      "classification_contract" => {
        "consumed" => "read by the concrete native control implementation",
        "parent_consumed" => "read by the shared visual pipeline or an explicitly named structural parent",
        "service" => "read by the native service implementation",
        "unsupported" => "explicitly reviewed as platformUnsupported with a reason",
        "unclassified" => "no executable consumption or reviewed unsupported contract was found"
      },
      "summary" => {
        "controls" => controls.length,
        "properties" => counts.values.sum,
        "classifications" => counts.sort.to_h,
        "unclassified" => unclassified.length
      },
      "unclassified" => unclassified,
      "controls" => controls
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = NativePropertyConsumptionAudit.generate
  if ARGV.delete("--check")
    current = File.file?(NativePropertyConsumptionAudit::REPORT_PATH) ? File.read(NativePropertyConsumptionAudit::REPORT_PATH) : nil
    abort "Native property consumption report is stale. Run #{__FILE__}." unless current == generated
    report = JSON.parse(generated)
    missing = report.dig("summary", "unclassified")
    abort "Native renderer has #{missing} unclassified public DSL properties; inspect #{NativePropertyConsumptionAudit::REPORT_PATH}." unless missing.zero?
    puts "Native property consumption report is current and complete."
  else
    File.write(NativePropertyConsumptionAudit::REPORT_PATH, generated)
    puts "Generated #{NativePropertyConsumptionAudit::REPORT_PATH}"
    puts JSON.pretty_generate(JSON.parse(generated).fetch("summary"))
  end
end
