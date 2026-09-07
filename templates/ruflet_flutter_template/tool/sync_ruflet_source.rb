#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "optparse"
require "tmpdir"
require_relative "ruflet_namespace"

# Sync only the core Ruflet package. Extension packages and host code are separate
# sources of truth and are deliberately outside this utility's write boundary.
class RufletSourceSync
  class Error < StandardError; end
  # This is upstream provenance, not a consumer dependency. The distributed
  # package and every owned Dart import are transformed into the Ruflet namespace.
  SOURCE_PACKAGE = "packages/flet"
  PACKAGE = "#{SOURCE_PACKAGE}/"
  MANIFEST_VERSION = 3
  DIRECTORIES = %w[lib test vendor third_party assets fonts licenses].freeze
  METADATA = %w[pubspec.yaml analysis_options.yaml LICENSE LICENSE.md LICENSE.txt
                NOTICE CHANGELOG.md README.md .gitignore .metadata].freeze
  CACHES = %w[.git .dart_tool build .pub-cache .idea .vscode coverage].freeze

  def initialize(template:, source: nil, ref: "HEAD", overlay: nil)
    @template = File.expand_path(template)
    @target = File.join(@template, "ruflet_packages/ruflet")
    [@template, File.dirname(@target), @target].each do |path|
      raise Error, "Refusing symbolic link: #{path}" if File.symlink?(path)
    end
    @source = source && File.expand_path(source)
    @ref = ref
    @manifest_path = File.join(@template, "tool/conformance/ruflet_source_integrity.json")
    @overlay_path = overlay || File.join(@template, "tool/ruflet_transport_overlay.json")
    @overlay_bytes = File.binread(@overlay_path)
    @overlay = JSON.parse(@overlay_bytes)
  end

  def self.managed?(path)
    parts = path.split("/")
    return false if (parts & CACHES).any? || parts.include?("..") || path.start_with?("/")
    return false if %w[pubspec.lock .DS_Store].include?(parts.last)
    DIRECTORIES.include?(parts.first) || METADATA.include?(path)
  end

  def safe_path(root, relative)
    raise Error, "Unsafe managed path: #{relative}" unless self.class.managed?(relative)
    path = root
    relative.split("/").each do |part|
      path = File.join(path, part)
      raise Error, "Refusing symbolic link: #{path}" if File.symlink?(path)
    end
    path
  end

  def inventory
    raise Error, "Ruflet destination is missing: #{@target}" unless File.directory?(@target)
    raise Error, "Refusing symbolic link: #{@target}" if File.symlink?(@target)
    paths = []
    Find.find(@target) do |path|
      next if path == @target
      relative = path.delete_prefix(@target + "/")
      if CACHES.include?(File.basename(path))
        Find.prune if File.directory?(path)
        next
      end
      next unless self.class.managed?(relative)
      safe_path(@target, relative)
      paths << relative if File.file?(path)
    end
    paths.sort
  end

  def sha(bytes)
    Digest::SHA256.hexdigest(bytes)
  end

  def git(*args)
    output, error, status = Open3.capture3("git", "-C", @source, *args)
    raise Error, "git #{args.first} failed: #{error.strip}" unless status.success?
    output
  end

  def source_files
    raise Error, "--source (or RUFLET_UPSTREAM_ROOT) is required for synchronization" unless @source
    dirty = git("status", "--porcelain", "--untracked-files=all", "--", SOURCE_PACKAGE)
    raise Error, "Source #{SOURCE_PACKAGE} has uncommitted changes; commit before syncing" unless dirty.empty?
    ref = git("rev-parse", "--verify", "--end-of-options", "#{@ref}^{commit}").strip
    tree = git("ls-tree", "-rz", "--full-tree", ref, "--", SOURCE_PACKAGE)
    entries = tree.split("\0").filter_map do |line|
      mode, type, object, path = line.match(/\A(\d+) (\w+) ([0-9a-f]+)\t(.+)\z/m)&.captures
      next unless path&.start_with?(PACKAGE)
      relative = path.delete_prefix(PACKAGE)
      next unless self.class.managed?(relative)
      raise Error, "Source must contain regular files: #{path}" unless type == "blob" && %w[100644 100755].include?(mode)
      [relative, object]
    end.sort
    raise Error, "Source ref has no Ruflet package" unless entries.any? { |path, _| path == "pubspec.yaml" }

    files = {}
    Open3.popen3("git", "-C", @source, "cat-file", "--batch") do |input, output, error, wait|
      input.binmode
      output.binmode
      entries.each do |path, object|
        input.puts(object)
        input.flush
        header = output.gets&.split
        raise Error, "Cannot read source blob #{object}" unless header&.[](1) == "blob"
        bytes = output.read(Integer(header.fetch(2)))
        output.read(1)
        files[path] = { bytes: bytes, object: object }
      end
      input.close
      raise Error, "Cannot read source blobs: #{error.read}" unless wait.value.success?
    end
    [ref, files]
  end

  def desired
    ref, upstream = source_files
    originals = {}
    files = upstream.to_h do |path, entry|
      destination = RufletNamespace.rename(path)
      raise Error, "Namespace collision at #{destination}" if originals.key?(destination)
      originals[destination] = entry.merge(source_path: path)
      [destination, RufletNamespace.rewrite(path, entry.fetch(:bytes))]
    end
    @overlay.fetch("patches").each do |path, patches|
      bytes = files.fetch(path) { raise Error, "Overlay source file disappeared: #{path}" }
      patches.each do |patch|
        before, after = patch.values_at("before", "after")
        count = bytes.scan(Regexp.new(Regexp.escape(before))).length
        raise Error, "Transport overlay needs review: #{path} (expected one anchor, found #{count})" unless count == 1 && !bytes.include?(after)
        bytes = bytes.sub(before, after)
      end
      files[path] = bytes
    end
    @overlay.fetch("preserved_files").each do |path, expected_sha|
      raise Error, "Upstream now owns a template-only transport file: #{path}" if files.key?(path)
      full = safe_path(@target, path)
      raise Error, "Restore the reviewed template transport file: #{path}" unless File.file?(full)
      bytes = File.binread(full)
      raise Error, "Template transport changed; review overlay hash: #{path}" unless sha(bytes) == expected_sha
      files[path] = bytes
    end
    entries = files.sort.to_h do |path, bytes|
      original = originals[path]
      classification = if !original
        "reviewed_template_addition"
      elsif @overlay.fetch("patches").key?(path)
        "reviewed_transport_overlay"
      elsif original.fetch(:source_path) != path || original.fetch(:bytes) != bytes
        "namespaced_source"
      else
        "exact_source"
      end
      [path, { "classification" => classification, "source_path" => original&.fetch(:source_path),
               "source_git_blob" => original&.fetch(:object),
               "source_sha256" => original && sha(original.fetch(:bytes)), "vendored_sha256" => sha(bytes) }]
    end
    manifest = {
      "manifest_version" => MANIFEST_VERSION,
      "package_name" => "ruflet",
      "engine_version" => files.fetch("pubspec.yaml")[/^version:\s*(\S+)/, 1],
      "source_ref" => ref,
      "source_package" => SOURCE_PACKAGE,
      "namespace_version" => RufletNamespace::VERSION,
      "namespace_sha256" => namespace_sha,
      "transport_overlay_sha256" => sha(@overlay_bytes),
      "transport_overlay_ref" => @overlay.fetch("reviewed_template_ref"),
      "summary" => entries.values.group_by { |entry| entry.fetch("classification") }.transform_values(&:length),
      "files" => entries
    }
    [files, manifest]
  end

  def manifest
    JSON.parse(File.read(@manifest_path)) if File.file?(@manifest_path)
  end

  def namespace_sha
    sha(File.binread(File.join(__dir__, "ruflet_namespace.rb")))
  end

  def source_ref_comment(ref)
    path = File.join(@template, "pubspec.yaml")
    raise Error, "Refusing symbolic link: #{path}" if File.symlink?(path)
    bytes = File.binread(path)
    anchor = /^  # [a-f0-9]{40}\. No git\/Python dependency\.$/
    raise Error, "Template source-ref comment needs review" unless bytes.scan(anchor).length == 1
    bytes.sub(anchor, "  # #{ref}. No git/Python dependency.")
  end

  def drift(record)
    raise Error, "Source inventory needs initialization with --source ... --initialize" unless record && record["manifest_version"] == MANIFEST_VERSION
    files = record.fetch("files")
    errors = []
    errors << "Ruflet namespace transform changed" unless record.fetch("namespace_sha256") == namespace_sha && record.fetch("namespace_version") == RufletNamespace::VERSION
    errors << "transport overlay contract changed" unless record.fetch("transport_overlay_sha256") == sha(@overlay_bytes)
    errors << "template source-ref comment drifted" unless source_ref_comment(record.fetch("source_ref")) == File.binread(File.join(@template, "pubspec.yaml"))
    actual = inventory
    (actual - files.keys).each { |path| errors << "unexpected file: #{path}" }
    (files.keys - actual).each { |path| errors << "missing file: #{path}" }
    (files.keys & actual).each do |path|
      errors << "content drift: #{path}" unless sha(File.binread(safe_path(@target, path))) == files.fetch(path).fetch("vendored_sha256")
    end
    errors
  end

  def check
    current = manifest
    errors = drift(current)
    if @source
      _files, expected = desired
      errors << "manifest differs from source ref #{@ref}" unless expected == current
    end
    raise Error, errors.join("\n") unless errors.empty?
    "Ruflet source integrity verified: #{current.fetch('files').length} files at #{current.fetch('source_ref')}"
  end

  def sync(initialize_inventory: false)
    current = manifest
    if current && current["manifest_version"] == MANIFEST_VERSION
      errors = drift(current)
      raise Error, "Local changes must be reviewed/restored before sync:\n#{errors.join("\n")}" unless errors.empty?
    elsif !initialize_inventory
      raise Error, "Initial adoption requires --initialize; existing managed files are backed up"
    end
    files, record = desired
    updated_pubspec = source_ref_comment(record.fetch("source_ref"))
    old_paths = inventory
    removed = old_paths - files.keys
    changed = files.keys.select do |path|
      full = safe_path(@target, path)
      !File.file?(full) || File.binread(full) != files.fetch(path)
    end
    backup = nil
    affected_existing = (changed + removed).select { |path| File.file?(safe_path(@target, path)) }
    unless affected_existing.empty?
      backup = Dir.mktmpdir("ruflet-source-sync-")
      affected_existing.each do |path|
        destination = File.join(backup, path)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(safe_path(@target, path), destination)
      end
      FileUtils.cp(@manifest_path, File.join(backup, "source_integrity_before.json")) if File.file?(@manifest_path)
      FileUtils.cp(File.join(@template, "pubspec.yaml"), File.join(backup, "template_pubspec_before.yaml"))
    end
    changed.each do |path|
      destination = safe_path(@target, path)
      FileUtils.mkdir_p(File.dirname(destination))
      File.binwrite(destination, files.fetch(path))
    end
    removed.each { |path| File.delete(safe_path(@target, path)) }
    # Only this comment changes; preserve user dependency/host configuration edits.
    File.binwrite(File.join(@template, "pubspec.yaml"), updated_pubspec)
    FileUtils.mkdir_p(File.dirname(@manifest_path))
    File.write(@manifest_path, JSON.pretty_generate(record) + "\n")
    "Synced #{changed.length} files, removed #{removed.length} superseded managed files; source #{record.fetch('source_ref')}." +
      (backup ? " Recoverable originals: #{backup}" : "")
  end

  def self.run(argv)
    options = { template: File.expand_path("..", __dir__), source: ENV["RUFLET_UPSTREAM_ROOT"] }
    check = initialize_inventory = false
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: ruby tool/sync_ruflet_source.rb [--source RUFLET_REPO] [--ref COMMIT] [--check] [--initialize]"
      opts.on("--source PATH", "Clean source Ruflet repository (or RUFLET_UPSTREAM_ROOT)") { |value| options[:source] = value }
      opts.on("--ref REF", "Source commit, defaults to HEAD") { |value| options[:ref] = value }
      opts.on("--template PATH", "Template root; primarily useful for fixtures") { |value| options[:template] = value }
      opts.on("--check", "Read-only local integrity check; also verify source when supplied") { check = true }
      opts.on("--initialize", "Explicit first adoption of source inventory (backs up replaced files)") { initialize_inventory = true }
    end
    parser.parse!(argv)
    raise Error, "Unexpected arguments: #{argv.join(' ')}" unless argv.empty?
    raise Error, "--check cannot initialize an inventory" if check && initialize_inventory
    sync = new(**options)
    puts(check ? sync.check : sync.sync(initialize_inventory: initialize_inventory))
  rescue Error, OptionParser::ParseError, Errno::ENOENT, KeyError => error
    warn "Ruflet source sync: #{error.message}"
    return 1
  end
end

exit(RufletSourceSync.run(ARGV) || 0) if $PROGRAM_NAME == __FILE__
