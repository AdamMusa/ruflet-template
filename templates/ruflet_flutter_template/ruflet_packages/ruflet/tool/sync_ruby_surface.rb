#!/usr/bin/env ruby
# frozen_string_literal: true

# Refreshes test/contract/ruflet_control_surface.json, the Ruby control
# surface the control-core contract test (rule C3) compares every shared core
# spec with. The ruflet repo owns the generator (tools/control_surface.rb);
# CI only reads the checked-in copy, so a Ruby change that adds or renames
# keywords is paired with an engine PR that runs this script.
#
#   ruby tool/sync_ruby_surface.rb --ruby <ruflet checkout>          # write
#   ruby tool/sync_ruby_surface.rb --ruby <ruflet checkout> --check  # verify

require "open3"
require "rbconfig"

package = File.expand_path("..", __dir__)
target = File.join(package, "test", "contract", "ruflet_control_surface.json")

ruby_index = ARGV.index("--ruby")
abort "usage: #{$PROGRAM_NAME} --ruby <ruflet checkout> [--check]" unless ruby_index && ARGV[ruby_index + 1]
generator = File.join(File.expand_path(ARGV[ruby_index + 1]), "tools", "control_surface.rb")
abort "#{generator} not found: the ruflet checkout predates the surface export" unless File.file?(generator)

mode = ARGV.include?("--check") ? ["--check", target] : ["--out", target]
stdout, stderr, status = Open3.capture3({ "RUBYOPT" => "-W0" }, RbConfig.ruby, generator, *mode)
$stdout.write(stdout)
$stderr.write(stderr)
exit(status.success? ? 0 : 1)
