#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"

ROOT = File.expand_path("../..", __dir__)
VENDORED_ROOT = File.join(ROOT, "flet_packages")
OUTPUT_PATH = File.join(__dir__, "flet_source_integrity.json")
UPSTREAM_ROOT = ENV.fetch("FLET_UPSTREAM_ROOT")
FLET_VERSION = "0.80.5"
FLET_REF = "67a9763da3bd2611bbb7626c3a1ec5e9d30fc965"

PATCHES = {
  "flet/lib/src/controls/banner.dart" => {
    "reason" => "Ruflet reusable-overlay lifecycle fix: discard stale close completions and reset the closing guard for the next open generation.",
    "ruflet_commit" => "767f1a2"
  },
  "flet/lib/src/controls/snack_bar.dart" => {
    "reason" => "Ruflet reusable-overlay lifecycle fix: discard stale close completions and reset the closing guard for the next open generation.",
    "ruflet_commit" => "767f1a2"
  }
}.freeze

def digest(path)
  Digest::SHA256.file(path).hexdigest
end

upstream_files = Dir.glob(File.join(UPSTREAM_ROOT, "packages", "flet", "{lib/src,test}", "**", "*.dart"))
  .sort
  .to_h do |path|
    [path.delete_prefix(File.join(UPSTREAM_ROOT, "packages") + "/"), path]
  end
vendored_files = Dir.glob(File.join(VENDORED_ROOT, "flet", "{lib/src,test}", "**", "*.dart"))
  .sort
  .to_h do |path|
    [path.delete_prefix(VENDORED_ROOT + "/"), path]
  end

abort "Vendored Flet source/test file set differs from pinned upstream" unless upstream_files.keys == vendored_files.keys

files = upstream_files.to_h do |relative, upstream_path|
  upstream_sha = digest(upstream_path)
  vendored_sha = digest(vendored_files.fetch(relative))
  patched = PATCHES.key?(relative)
  abort "Unexpected vendored modification: #{relative}" if upstream_sha != vendored_sha && !patched
  abort "Declared patch no longer differs from upstream: #{relative}" if patched && upstream_sha == vendored_sha

  [relative, {
    "classification" => patched ? "reviewed_ruflet_patch" : "exact_upstream",
    "upstream_sha256" => upstream_sha,
    "vendored_sha256" => vendored_sha
  }]
end

missing_patches = PATCHES.keys - files.keys
abort "Declared patches missing from pinned inventory: #{missing_patches.join(', ')}" unless missing_patches.empty?

manifest = {
  "manifest_version" => 1,
  "flet_version" => FLET_VERSION,
  "flet_ref" => FLET_REF,
  "contract" => "Every vendored Flet Dart engine and test file is hash-pinned to the exact upstream ref; every byte-level deviation is explicitly enumerated.",
  "summary" => {
    "source_files" => files.keys.count { |path| path.include?("/lib/src/") },
    "test_files" => files.keys.count { |path| path.include?("/test/") },
    "exact_upstream" => files.values.count { |entry| entry.fetch("classification") == "exact_upstream" },
    "reviewed_ruflet_patches" => PATCHES.length
  },
  "patches" => PATCHES,
  "files" => files
}

File.write(OUTPUT_PATH, JSON.pretty_generate(manifest) + "\n")
puts "Generated #{OUTPUT_PATH}"
puts JSON.pretty_generate(manifest.fetch("summary"))
