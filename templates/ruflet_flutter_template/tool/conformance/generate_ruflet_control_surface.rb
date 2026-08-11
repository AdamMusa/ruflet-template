#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"

module RufletControlSurface
  CONTRACT_VERSION = 1

  module_function

  def default_ruflet_root
    File.expand_path("../ruflet", File.expand_path("../../../..", __dir__))
  end

  def ruflet_root
    File.expand_path(ENV.fetch("RUFLET_SOURCE_ROOT", default_ruflet_root))
  end

  def output_path
    File.join(__dir__, "ruflet_control_surface.json")
  end

  def source_script
    <<~'RUBY'
      require "json"
      require "ruflet_core"

      surfaces = {
        "visual" => Ruflet::UI::Controls::RufletControls::CLASS_MAP,
        "service" => Ruflet::UI::Services::RufletServices::CLASS_MAP
      }
      entries = surfaces.flat_map do |family, controls|
        controls.map do |dsl_name, klass|
          {
            "dsl_name" => dsl_name,
            "family" => family,
            "ruby_class" => klass.name,
            "wire_type" => (klass.const_get(:WIRE) rescue klass.const_get(:TYPE)),
            "keywords" => (klass.const_get(:KEYWORDS) rescue []).map(&:to_s).sort
          }
        end
      end
      puts JSON.generate(entries)
    RUBY
  end

  def entries
    lib = File.join(ruflet_root, "packages", "ruflet_core", "lib")
    abort "Ruflet source was not found at #{ruflet_root}" unless File.file?(File.join(lib, "ruflet_core.rb"))

    stdout, stderr, status = Open3.capture3(
      { "RUBYOPT" => "-W0" },
      RbConfig.ruby,
      "-I#{lib}",
      "-e",
      source_script
    )
    abort "Unable to inspect Ruflet controls:\n#{stderr}" unless status.success?

    JSON.parse(stdout).sort_by { |entry| [entry.fetch("family"), entry.fetch("dsl_name")] }
  end

  def build
    advertised = entries
    {
      "contract_version" => CONTRACT_VERSION,
      "source" => "Ruflet::UI control and service registries",
      "summary" => {
        "advertised_entries" => advertised.length,
        "visual_entries" => advertised.count { |entry| entry.fetch("family") == "visual" },
        "service_entries" => advertised.count { |entry| entry.fetch("family") == "service" },
        "wire_types" => advertised.map { |entry| entry.fetch("wire_type") }.uniq.length
      },
      "entries" => advertised
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = RufletControlSurface.generate
  if ARGV.delete("--check")
    current = File.file?(RufletControlSurface.output_path) ? File.read(RufletControlSurface.output_path) : nil
    abort "Ruflet control surface is stale. Run #{__FILE__}." unless current == generated
    puts "Ruflet control surface is current."
  else
    File.write(RufletControlSurface.output_path, generated)
    puts "Generated #{RufletControlSurface.output_path}"
    puts JSON.pretty_generate(JSON.parse(generated).fetch("summary"))
  end
end
