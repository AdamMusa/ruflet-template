#!/usr/bin/env ruby
# frozen_string_literal: true

# Audits the native package boundary against the executable extension
# registries in the vendored Flet source. This is deliberately source-driven:
# it does not keep another hand-maintained list of wire controls.

require "json"

module NativeExtensionOwnership
  module_function

  TEMPLATE_ROOT = File.expand_path("../..", __dir__)
  APPLE_ROOT = File.join(TEMPLATE_ROOT, "apple_packages", "ruflet_apple")
  CONTRACT_PATH = File.join(__dir__, "flet_control_contract.json")
  PACKAGE_PATH = File.join(APPLE_ROOT, "Package.swift")

  def contract
    @contract ||= JSON.parse(File.read(CONTRACT_PATH))
  end

  def extension_controls
    contract.fetch("controls").reject { |control| control.fetch("package") == "flet" }
  end

  def products
    @products ||= File.read(PACKAGE_PATH)
      .scan(/\.library\(name:\s*"(Ruflet[A-Za-z0-9]+)"/).flatten
      .reject { |name| %w[RufletProtocol RufletEngine RufletApple].include?(name) }
  end

  def product_source(product)
    Dir.glob(File.join(APPLE_ROOT, "Sources", "RufletExtensions", product, "**", "*.swift"))
      .sort.map { |path| File.read(path) }.join("\n")
  end

  def package_products
    @package_products ||= begin
      sources = products.to_h { |product| [product, product_source(product)] }
      extension_controls.group_by { |control| control.fetch("package") }.to_h do |package, controls|
        wires = controls.map { |control| control.fetch("wire_type") }
        candidates = sources.filter_map do |product, source|
          product if wires.all? { |wire| source.include?(%Q{"#{wire}"}) }
        end
        [package, candidates]
      end
    end
  end

  def core_implementation_hits(control)
    renderer = control.dig("renderer", "class")
    return [] unless renderer

    core_paths = Dir.glob(File.join(APPLE_ROOT, "Sources", "RufletEngine", "**", "*.swift"))
    core_paths.reject { |path| path.end_with?("/RufletCoreExtension.swift") }.select do |path|
      File.read(path).match?(/\b(?:struct|class|enum|actor)\s+#{Regexp.escape(renderer)}\b/)
    end
  end

  def audit
    errors = []
    resolved = package_products
    product_sources = products.to_h { |product| [product, product_source(product)] }
    grouped = extension_controls.group_by { |control| control.fetch("package") }

    resolved.each do |package, candidates|
      errors << "#{package}: expected exactly one native product, found #{candidates.inspect}" unless candidates.length == 1
    end
    claimed = resolved.values.flatten
    errors << "Unowned native products: #{(products - claimed).inspect}" unless (products - claimed).empty?
    errors << "Native products claimed more than once: #{claimed.tally.select { |_key, count| count != 1 }.inspect}" unless claimed.uniq.length == claimed.length

    grouped.each do |package, controls|
      product = resolved.fetch(package, []).first
      next unless product

      source = product_sources.fetch(product)
      controls.each do |control|
        wire_type = control.fetch("wire_type")
        owners = product_sources.select { |_candidate, text| text.include?(%Q{"#{wire_type}"}) }.keys
        errors << "#{package}/#{wire_type}: owned by #{owners.inspect}, expected only #{product}" unless owners == [product]

        control.fetch("events").each do |event|
          errors << "#{package}/#{wire_type}: missing event #{event}" unless source.include?(%Q{"#{event}"})
        end
        control.fetch("methods").each do |method|
          errors << "#{package}/#{wire_type}: missing method #{method}" unless source.include?(%Q{"#{method}"})
        end

        core_implementation_hits(control).each do |path|
          relative = path.delete_prefix(TEMPLATE_ROOT + "/")
          errors << "#{package}/#{wire_type}: renderer class remains in core at #{relative}"
        end
      end
    end

    [errors, grouped]
  end

  def run
    errors, grouped = audit
    abort(errors.join("\n") + "\n") unless errors.empty?

    wire_count = grouped.values.sum(&:length)
    puts "Native extension ownership is current: #{grouped.length} packages, #{wire_count} wire types."
  end
end

NativeExtensionOwnership.run if $PROGRAM_NAME == __FILE__
