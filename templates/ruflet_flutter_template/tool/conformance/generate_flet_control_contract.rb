#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"

module FletControlContract
  CONTRACT_VERSION = 2
  GLOBAL_DEFAULTS = {
    "disabled" => { "type" => "bool", "value" => false },
    "expand_loose" => { "type" => "bool", "value" => false },
    "opacity" => { "type" => "double", "value" => 1.0 },
    "rtl" => { "type" => "bool", "value" => false },
    "visible" => { "type" => "bool", "value" => true }
  }.freeze

  module_function

  def template_root
    @template_root ||= File.expand_path("../..", __dir__)
  end

  def packages_root
    File.join(template_root, "flet_packages")
  end

  def output_path
    File.join(__dir__, "flet_control_contract.json")
  end

  def balanced_body(source, signature)
    match = source.match(signature)
    return unless match

    opening = source.index("{", match.end(0))
    return unless opening

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

      if character == '"' || character == "'"
        quote = character
      elsif character == "{"
        depth += 1
      elsif character == "}"
        depth -= 1
        return source[(opening + 1)...index] if depth.zero?
      end
    end
    nil
  end

  def source_classes(package_root)
    classes = {}
    Dir.glob(File.join(package_root, "lib", "**", "*.dart")).sort.each do |path|
      text = File.read(path)
      text.to_enum(:scan, /^class\s+(\w+)\b/).each do
        name = Regexp.last_match(1)
        line = text[0...Regexp.last_match.begin(0)].count("\n") + 1
        classes[name] ||= { path: path, line: line }
      end
    end
    classes
  end

  # A Dart source file commonly contains several independent Flet controls.
  # Attribute defaults/events/methods only to the registered renderer and its
  # private State implementation; scanning the entire file falsely assigns a
  # sibling control's behavior to every wire type in that file (Tabs/TabBar is
  # the canonical example).
  def renderer_scope(source, renderer_class)
    names = [renderer_class]
    bodies = []
    index = 0
    while index < names.length
      name = names[index]
      signature = /\b(?:class|extension)\s+#{Regexp.escape(name)}\b/
      offset = 0
      while (match = source.match(signature, offset))
        body = balanced_body(source[match.begin(0)..], signature)
        break unless body

        bodies << body
        body.scan(/\bcreateState\s*\(\s*\)\s*=>\s*(\w+)\s*\(/).flatten.each do |state_name|
          names << state_name unless names.include?(state_name)
        end
        offset = match.end(0) + body.length
      end
      index += 1
    end
    bodies.empty? ? source : bodies.join("\n")
  end

  def registry_mappings(registry_path)
    # A commented switch case is documentation/TODO, not a wire type the Flet
    # engine can construct. In particular flet_ads keeps NativeAdControl's
    # unfinished case in a block comment. Strip comments before walking the
    # registry so the generated contract represents executable Flet code.
    source = strip_dart_comments(File.read(registry_path))
    mappings = []
    {
      "widget" => /\bcreateWidget\s*\([^)]*\)\s*/m,
      "service" => /\bcreateService\s*\([^)]*\)\s*/m
    }.each do |classification, signature|
      body = balanced_body(source, signature)
      next unless body

      pending = []
      body.each_line do |line|
        if (match = line.match(/case\s+["']([^"']+)["']\s*:/))
          pending << match[1]
        elsif (match = line.match(/return\s+(\w+)\s*\(/))
          pending.each do |wire_type|
            mappings << {
              wire_type: wire_type,
              renderer_class: match[1],
              classification: classification
            }
          end
          pending.clear
        elsif line.match?(/\bdefault\s*:/)
          pending.clear
        end
      end
    end
    mappings
  end

  def strip_dart_comments(source)
    result = +""
    index = 0
    quote = nil
    escaped = false
    line_comment = false
    block_comment_depth = 0

    while index < source.length
      character = source[index]
      following = source[index + 1]

      if line_comment
        if character == "\n"
          line_comment = false
          result << character
        end
      elsif block_comment_depth.positive?
        if character == "/" && following == "*"
          block_comment_depth += 1
          result << "  "
          index += 1
        elsif character == "*" && following == "/"
          block_comment_depth -= 1
          result << "  "
          index += 1
        else
          # Preserve newlines so renderer source locations remain useful.
          result << (character == "\n" ? "\n" : " ")
        end
      elsif quote
        result << character
        if escaped
          escaped = false
        elsif character == "\\"
          escaped = true
        elsif character == quote
          quote = nil
        end
      elsif character == '"' || character == "'"
        quote = character
        result << character
      elsif character == "/" && following == "/"
        line_comment = true
        result << "  "
        index += 1
      elsif character == "/" && following == "*"
        block_comment_depth = 1
        result << "  "
        index += 1
      else
        result << character
      end

      index += 1
    end

    result
  end

  def primitive(expression, getter: nil)
    value = expression.strip
    return { "type" => "bool", "value" => value == "true" } if %w[true false].include?(value)
    if value.match?(/\A-?\d+(?:\.\d+)?\z/)
      return { "type" => "double", "value" => value.to_f } if getter == "getDouble" || value.include?(".")
      return { "type" => "int", "value" => value.to_i }
    end
    if (match = value.match(/\A["']([^"']*)["']\z/))
      return { "type" => "string", "value" => match[1] }
    end
    if (match = value.match(/\A[A-Z]\w*(?:<[^>]+>)?\.(\w+)\z/))
      return { "type" => "enum", "value" => match[1] }
    end
    nil
  end

  def primitive_defaults(source)
    defaults = {}
    source.scan(
      /(?:control|widget\.control)\.(get(?:Bool|Double|Int|String|MainAxisAlignment|CrossAxisAlignment|WrapAlignment|WrapCrossAlignment|ClipBehavior|Alignment))\(\s*["']([^"']+)["']\s*,\s*([^,\)\n]+)/m
    ).each do |getter, property, expression|
      parsed = primitive(expression, getter: getter)
      defaults[property] = parsed if parsed
    end
    source.scan(
      /parse\w+\(\s*(?:control|widget\.control)\.getString\(\s*["']([^"']+)["']\s*\)\s*,\s*([A-Z]\w*(?:<[^>]+>)?\.\w+)/m
    ).each do |property, expression|
      parsed = primitive(expression)
      defaults[property] = parsed if parsed
    end

    # Flet sometimes stores a nullable wire value in a local before applying
    # the Flutter parser default (Column is the canonical example). Preserve
    # that data flow in the contract instead of forcing native renderers to
    # rediscover the default independently.
    string_locals = source.scan(
      /(?:var|final)\s+(\w+)\s*=\s*(?:control|widget\.control)\.getString\(\s*["']([^"']+)["']\s*\)\s*;/m
    ).to_h
    source.scan(
      /parse\w+\(\s*(\w+)\s*,\s*([A-Z]\w*(?:<[^>]+>)?\.\w+)\s*\)/m
    ).each do |local, expression|
      property = string_locals[local]
      next unless property

      parsed = primitive(expression)
      defaults[property] = parsed if parsed
    end
    defaults.sort.to_h
  end

  def invocation_arguments(source, opening)
    arguments = []
    depth = 0
    quote = nil
    escaped = false
    start = opening + 1
    index = start
    while index < source.length
      character = source[index]
      if quote
        if escaped
          escaped = false
        elsif character == "\\"
          escaped = true
        elsif character == quote
          quote = nil
        end
      elsif character == '"' || character == "'"
        quote = character
      elsif "([{".include?(character)
        depth += 1
      elsif ")]}".include?(character)
        if character == ")" && depth.zero?
          arguments << source[start...index].strip
          return arguments
        end
        depth -= 1
      elsif character == "," && depth.zero?
        arguments << source[start...index].strip
        start = index + 1
      end
      index += 1
    end
    []
  end

  def numeric_literal(value)
    text = value.strip
    return unless text.match?(/\A-?\d+(?:\.\d+)?\z/)

    text.to_f
  end

  def named_numeric_arguments(expression)
    expression.scan(/(\w+)\s*:\s*(-?\d+(?:\.\d+)?)/).to_h.transform_values(&:to_f)
  end

  def compound_default(expression)
    value = expression.strip.sub(/\Aconst\s+/, "")
    if value.match?(/\AEdgeInsets(?:Directional)?\.zero\z/)
      return { "type" => "edge_insets", "top" => 0.0, "left" => 0.0,
               "bottom" => 0.0, "right" => 0.0 }
    end
    if (match = value.match(/\AEdgeInsets(?:Directional)?\.all\(\s*([^\)]+)\s*\)\z/))
      amount = numeric_literal(match[1])
      return unless amount

      return { "type" => "edge_insets", "top" => amount, "left" => amount,
               "bottom" => amount, "right" => amount }
    end
    if value.match?(/\AEdgeInsets(?:Directional)?\.symmetric\(/)
      named = named_numeric_arguments(value)
      horizontal = named.fetch("horizontal", 0.0)
      vertical = named.fetch("vertical", 0.0)
      return { "type" => "edge_insets", "top" => vertical, "left" => horizontal,
               "bottom" => vertical, "right" => horizontal }
    end
    if value.match?(/\AEdgeInsets(?:Directional)?\.only\(/)
      named = named_numeric_arguments(value)
      return {
        "type" => "edge_insets",
        "top" => named.fetch("top", 0.0),
        "left" => named.fetch("left", named.fetch("start", 0.0)),
        "bottom" => named.fetch("bottom", 0.0),
        "right" => named.fetch("right", named.fetch("end", 0.0))
      }
    end
    if (match = value.match(/\AEdgeInsets(?:Directional)?\.from(?:LTRB|STEB)\(\s*([^\)]+)\s*\)\z/))
      values = match[1].split(",").map { |item| numeric_literal(item) }
      return unless values.length == 4 && values.all?

      return { "type" => "edge_insets", "left" => values[0], "top" => values[1],
               "right" => values[2], "bottom" => values[3] }
    end
    if (match = value.match(/\ADuration\(\s*(milliseconds|microseconds|seconds)\s*:\s*([^\)]+)\s*\)\z/))
      amount = numeric_literal(match[2])
      return unless amount

      seconds = amount * { "microseconds" => 0.000001, "milliseconds" => 0.001,
                           "seconds" => 1.0 }.fetch(match[1])
      return { "type" => "duration", "seconds" => seconds }
    end
    if (match = value.match(/\ADateTime\(\s*([^\)]+)\s*\)\z/))
      values = match[1].split(",").map { |item| numeric_literal(item) }
      return unless values.length.between?(1, 3) && values.all?

      return { "type" => "date_time", "year" => values[0].to_i,
               "month" => (values[1] || 1).to_i, "day" => (values[2] || 1).to_i }
    end
    if (match = value.match(/\ABorderRadius\.all\(\s*Radius\.circular\(\s*([^\)]+)\s*\)\s*\)\z/))
      radius = numeric_literal(match[1])
      return { "type" => "border_radius", "radius" => radius } if radius
    end
    if (match = value.match(/\AAlignment\(\s*([^,]+),\s*([^\)]+)\s*\)\z/))
      x = numeric_literal(match[1])
      y = numeric_literal(match[2])
      return { "type" => "alignment", "x" => x, "y" => y } if x && y
    end
    if (match = value.match(/\ASize\(\s*([^,]+),\s*([^\)]+)\s*\)\z/))
      width = numeric_literal(match[1])
      height = numeric_literal(match[2])
      return { "type" => "size", "width" => width, "height" => height } if width && height
    end
    nil
  end

  def compound_defaults(source)
    defaults = {}
    pattern = /(?:control|widget\.control)\.(get[A-Z]\w*)\s*\(/
    source.to_enum(:scan, pattern).each do
      match = Regexp.last_match
      arguments = invocation_arguments(source, match.end(0) - 1)
      next if arguments.length < 2

      property = arguments[0][/\A["']([^"']+)["']\z/, 1]
      next unless property

      parsed = compound_default(arguments[1])
      defaults[property] = parsed if parsed
    end
    defaults.sort.to_h
  end

  def events(source)
    # Only events emitted by the registered renderer's own control belong to
    # its contract. Files such as SnackBar and DataTable also fire events on
    # nested action/row/cell controls; attributing those to the parent creates
    # a false gap and can hide a real child-control omission.
    triggered = source.scan(
      /(?:\bcontrol|\bwidget\.control)\s*\.\s*triggerEvent\(\s*["']([^"']+)["']/
    ).flatten
    triggered.concat(source.scan(
      /\.triggerControlEvent\(\s*(?:control|widget\.control)\s*,\s*["']([^"']+)["']/
    ).flatten)
    # `on_*` flags read from a child/sibling control describe that child's
    # event contract, not the renderer currently being inventoried. Page, for
    # example, inspects its top View's `on_confirm_pop`. Only the registered
    # renderer's own control can contribute an enabled event here.
    enabled = source.scan(
      /(?:\bcontrol|\bwidget\.control)\.getBool\(\s*["']on_([^"']+)["']/
    ).flatten
    (triggered + enabled).uniq.sort
  end

  def methods(source)
    bodies = []
    offset = 0
    pattern = /\b(?:_invokeMethod|invokeMethod)\s*\(\s*String\s+\w+/
    while (match = source.match(pattern, offset))
      body = balanced_body(source[match.begin(0)..], pattern)
      break unless body

      bodies << body
      offset = match.end(0) + body.length
    end
    bodies.flat_map { |body| body.scan(/case\s+["']([^"']+)["']\s*:/).flatten }.uniq.sort
  end

  def design_family(wire_type, renderer_class)
    return "cupertino" if wire_type.start_with?("Cupertino")
    return "adaptive" if wire_type.start_with?("Adaptive") || renderer_class.start_with?("Adaptive")
    nil
  end

  def package_contract(package_name, registry_path)
    package_root = File.join(packages_root, package_name)
    classes = source_classes(package_root)
    family = package_name == "flet" ? "core" : "extension"

    registry_mappings(registry_path).filter_map do |mapping|
      renderer = classes[mapping[:renderer_class]]
      next unless renderer

      source = File.read(renderer[:path])
      scope = renderer_scope(strip_dart_comments(source), mapping[:renderer_class])
      relative_source = renderer[:path].delete_prefix(template_root + "/")
      {
        "wire_type" => mapping[:wire_type],
        "renderer" => {
          "class" => mapping[:renderer_class],
          "source" => relative_source,
          "line" => renderer[:line],
          "sha256" => Digest::SHA256.hexdigest(source)
        },
        "package" => package_name,
        "family" => family,
        "classification" => mapping[:classification],
        "design_family" => design_family(mapping[:wire_type], mapping[:renderer_class]),
        "primitive_defaults" => primitive_defaults(scope),
        "compound_defaults" => compound_defaults(scope),
        "events" => events(scope),
        "methods" => methods(scope)
      }
    end
  end

  def registries
    core = File.join(packages_root, "flet", "lib", "src", "flet_core_extension.dart")
    extensions = %w[flet_* ruflet_*].flat_map do |pattern|
      Dir.glob(File.join(packages_root, pattern, "lib", "src", "extension.dart"))
    end.sort
    [["flet", core]] + extensions.map do |path|
      [path.split(File::SEPARATOR)[-4], path]
    end
  end

  def build
    pubspec = File.read(File.join(packages_root, "flet", "pubspec.yaml"))
    template_pubspec = File.read(File.join(template_root, "pubspec.yaml"))
    version = pubspec[/^version:\s*([^\s]+)/, 1]
    source_ref = template_pubspec[/vendored locally \(Dart only\) from flet ref\s*\n\s*#\s*([0-9a-f]{40})/m, 1]
    controls = registries.flat_map { |package, registry| package_contract(package, registry) }
    duplicates = controls.group_by { |control| control["wire_type"] }.select { |_type, entries| entries.length > 1 }
    abort "Duplicate Flet wire types: #{duplicates.keys.sort.join(', ')}" unless duplicates.empty?

    {
      "contract_version" => CONTRACT_VERSION,
      "source" => {
        "flet_version" => version,
        "flet_ref" => source_ref,
        "registry" => "flet_packages/flet/lib/src/flet_core_extension.dart"
      },
      "global_primitive_defaults" => GLOBAL_DEFAULTS,
      "controls" => controls.sort_by { |control| [control["wire_type"], control["package"]] }
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = FletControlContract.generate
  if ARGV.delete("--check")
    current = File.file?(FletControlContract.output_path) ? File.read(FletControlContract.output_path) : nil
    abort "Flet control contract is stale. Run #{__FILE__}." unless current == generated
    puts "Flet control contract is current."
  else
    File.write(FletControlContract.output_path, generated)
    puts "Generated #{FletControlContract.output_path}"
  end
end
