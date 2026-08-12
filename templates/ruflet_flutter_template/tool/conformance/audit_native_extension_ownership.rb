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
  MANIFEST_PATH = File.join(
    APPLE_ROOT, "Sources", "RufletEngine", "RufletExtensionManifest.swift"
  )
  REGISTRY_PATH = File.join(APPLE_ROOT, "Sources", "RufletUI", "ControlRegistry.swift")
  DEFAULTS_PATH = File.join(
    APPLE_ROOT, "Sources", "RufletEngine", "RufletControlDefaults.generated.swift"
  )

  ALLOWED_CORE_FILES = [
    MANIFEST_PATH,
    REGISTRY_PATH,
    DEFAULTS_PATH,
    File.join(APPLE_ROOT, "Sources", "RufletEngine", "Services", "DefaultServices.swift"),
  ].freeze

  def contract
    @contract ||= JSON.parse(File.read(CONTRACT_PATH))
  end

  def extension_controls
    contract.fetch("controls").reject { |control| control.fetch("package") == "flet" }
  end

  def manifest
    @manifest ||= File.read(MANIFEST_PATH).scan(
      /fletPackage:\s*"([^"]+)".*?swiftProduct:\s*"([^"]+)".*?status:\s*\.([a-z]+)/m
    ).to_h do |flet_package, swift_product, status|
      [flet_package, { "swift_product" => swift_product, "status" => status }]
    end
  end

  def product_source(product)
    Dir.glob(File.join(APPLE_ROOT, "Sources", product, "**", "*.swift"))
      .sort.map { |path| File.read(path) }.join("\n")
  end

  def core_implementation_hits(control)
    renderer = control.dig("renderer", "class")
    return [] unless renderer

    core_paths = %w[RufletEngine RufletUI].flat_map do |target|
      Dir.glob(File.join(APPLE_ROOT, "Sources", target, "**", "*.swift"))
    end
    core_paths.reject { |path| ALLOWED_CORE_FILES.include?(path) }.select do |path|
      File.read(path).match?(/\b(?:struct|class|enum|actor)\s+#{Regexp.escape(renderer)}\b/)
    end
  end

  def audit
    errors = []
    products = manifest.transform_values { |entry| entry.fetch("swift_product") }
    product_sources = products.values.uniq.to_h { |product| [product, product_source(product)] }
    grouped = extension_controls.group_by { |control| control.fetch("package") }

    missing_packages = grouped.keys - products.keys
    errors.concat(missing_packages.map { |package| "#{package}: no native manifest entry" })

    grouped.each do |package, controls|
      product = products[package]
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
