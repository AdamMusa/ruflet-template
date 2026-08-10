#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"

module FletControlContract
  CONTRACT_VERSION = 1
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

  def registry_mappings(registry_path)
    source = File.read(registry_path)
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
    defaults.sort.to_h
  end

  def events(source)
    triggered = source.scan(/\.triggerEvent\(\s*["']([^"']+)["']/).flatten
    enabled = source.scan(/\.getBool\(\s*["']on_([^"']+)["']/).flatten
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
        "primitive_defaults" => primitive_defaults(source),
        "events" => events(source),
        "methods" => methods(source)
      }
    end
  end

  def registries
    core = File.join(packages_root, "flet", "lib", "src", "flet_core_extension.dart")
    extensions = Dir.glob(File.join(packages_root, "flet_*", "lib", "src", "extension.dart")).sort
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
