#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "optparse"
require "tmpdir"

# Sync all owned engine packages. Application and platform host code are outside
# this utility's write boundary.
class RufletSourceSync
  class Error < StandardError; end
  # The Ruflet engine owns both its renderers and embedded transport.
  SOURCE_PACKAGE = "packages"
  PACKAGE = "#{SOURCE_PACKAGE}/"
  MANIFEST_VERSION = 5
  CACHES = %w[.git .dart_tool .cache build .pub-cache .idea .vscode coverage].freeze

  def initialize(template:, source: nil, ref: "HEAD")
    @template = File.expand_path(template)
    @target = File.join(@template, "ruflet_packages")
    [@template, File.dirname(@target), @target].each do |path|
      raise Error, "Refusing symbolic link: #{path}" if File.symlink?(path)
    end
    @source = source && File.expand_path(source)
    @ref = ref
    @manifest_path = File.join(@template, "tool/conformance/ruflet_source_integrity.json")
  end

  def self.managed?(path)
    parts = path.split("/")
    return false if (parts & CACHES).any? || parts.include?("..") || path.start_with?("/")
    return false if %w[pubspec.lock .DS_Store .flutter-plugins .flutter-plugins-dependencies].include?(parts.last)
    parts.length > 1 && parts.first.match?(/\Aruflet(?:_[a-z0-9_]+)?\z/)
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
    raise Error, "--source (or RUFLET_ENGINE_ROOT) is required for synchronization" unless @source
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
      [relative, object, mode]
    end.sort
    raise Error, "Source ref has no Ruflet package" unless entries.any? { |path, _| path == "ruflet/pubspec.yaml" }

    files = {}
    Open3.popen3("git", "-C", @source, "cat-file", "--batch") do |input, output, error, wait|
      input.binmode
      output.binmode
      entries.each do |path, object, mode|
        input.puts(object)
        input.flush
        header = output.gets&.split
        raise Error, "Cannot read source blob #{object}" unless header&.[](1) == "blob"
        bytes = output.read(Integer(header.fetch(2)))
        output.read(1)
        files[path] = { bytes: bytes, object: object, mode: mode }
      end
      input.close
      raise Error, "Cannot read source blobs: #{error.read}" unless wait.value.success?
    end
    [ref, files]
  end

  def desired
    ref, source = source_files
    files = source.transform_values { |entry| entry.fetch(:bytes) }
    entries = files.sort.to_h do |path, bytes|
      [path, { "classification" => "exact_source", "source_path" => path,
               "source_git_blob" => source.fetch(path).fetch(:object),
               "source_mode" => source.fetch(path).fetch(:mode),
               "source_sha256" => sha(bytes), "vendored_sha256" => sha(bytes) }]
    end
    manifest = {
      "manifest_version" => MANIFEST_VERSION,
      "package_name" => "ruflet-engine",
      "packages" => files.keys.filter_map { |path| path.split('/').first if path.match?(%r{\Aruflet[^/]*/pubspec.yaml\z}) }.sort,
      "engine_version" => files.fetch("ruflet/pubspec.yaml")[/^version:\s*(\S+)/, 1],
      "source_ref" => ref,
      "source_package" => SOURCE_PACKAGE,
      "summary" => entries.values.group_by { |entry| entry.fetch("classification") }.transform_values(&:length),
      "files" => entries
    }
    [files, manifest]
  end

  def manifest
    JSON.parse(File.read(@manifest_path)) if File.file?(@manifest_path)
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
    raise Error, "Source inventory needs initialization with --source ... --initialize" unless record && [3, 4, MANIFEST_VERSION].include?(record["manifest_version"])
    legacy_core = record["manifest_version"] < MANIFEST_VERSION
    files = record.fetch("files")
    files = files.transform_keys { |path| "ruflet/#{path}" } if legacy_core
    errors = []
    errors << "template source-ref comment drifted" unless source_ref_comment(record.fetch("source_ref")) == File.binread(File.join(@template, "pubspec.yaml"))
    actual = inventory
    actual = actual.select { |path| path.start_with?("ruflet/") } if legacy_core
    (actual - files.keys).each { |path| errors << "unexpected file: #{path}" }
    (files.keys - actual).each { |path| errors << "missing file: #{path}" }
    (files.keys & actual).each do |path|
      errors << "content drift: #{path}" unless sha(File.binread(safe_path(@target, path))) == files.fetch(path).fetch("vendored_sha256")
      mode = files.fetch(path)["source_mode"]
      if mode && (File.stat(safe_path(@target, path)).mode & 0o777) != (mode.to_i(8) & 0o777)
        errors << "file mode drift: #{path}"
      end
    end
    errors
  end

  def check
    current = manifest
    errors = drift(current)
    errors << "Migrate to the Ruflet engine with --source ... --initialize" unless current["manifest_version"] == MANIFEST_VERSION
    if @source
      _files, expected = desired
      errors << "manifest differs from source ref #{@ref}" unless expected == current
    end
    raise Error, errors.join("\n") unless errors.empty?
    "Ruflet source integrity verified: #{current.fetch('files').length} files at #{current.fetch('source_ref')}"
  end

  def sync(initialize_inventory: false)
    current = manifest
    if current && [3, 4, MANIFEST_VERSION].include?(current["manifest_version"])
      errors = drift(current)
      raise Error, "Local changes must be reviewed/restored before sync:\n#{errors.join("\n")}" unless errors.empty?
      if current["manifest_version"] != MANIFEST_VERSION && !initialize_inventory
        raise Error, "Engine adoption requires --initialize; existing managed files are backed up"
      end
      validate_extension_migration if current["manifest_version"] < MANIFEST_VERSION
    elsif !initialize_inventory
      raise Error, "Initial adoption requires --initialize; existing managed files are backed up"
    end
    files, record = desired
    updated_pubspec = source_ref_comment(record.fetch("source_ref"))
    old_paths = inventory
    removed = old_paths - files.keys
    changed = files.keys.select do |path|
      full = safe_path(@target, path)
      !File.file?(full) || File.binread(full) != files.fetch(path) ||
        (File.stat(full).mode & 0o777) != (record.fetch("files").fetch(path).fetch("source_mode").to_i(8) & 0o777)
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
      File.chmod(record.fetch("files").fetch(path).fetch("source_mode").to_i(8) & 0o777, destination)
    end
    removed.each { |path| File.delete(safe_path(@target, path)) }
    # Only this comment changes; preserve user dependency/host configuration edits.
    File.binwrite(File.join(@template, "pubspec.yaml"), updated_pubspec)
    FileUtils.mkdir_p(File.dirname(@manifest_path))
    File.write(@manifest_path, JSON.pretty_generate(record) + "\n")
    "Synced #{changed.length} files, removed #{removed.length} superseded managed files; source #{record.fetch('source_ref')}." +
      (backup ? " Recoverable originals: #{backup}" : "")
  end

  def validate_extension_migration
    output, _error, status = Open3.capture3("git", "-C", @template,
      "status", "--porcelain", "-z", "--untracked-files=all", "--", @target)
    return unless status.success? # Explicit initialization also supports non-Git fixtures.

    changed = output.split("\0").filter_map do |entry|
      relative = entry[3..].to_s.split("ruflet_packages/", 2).last
      relative if relative && self.class.managed?(relative) && !relative.start_with?("ruflet/")
    end
    raise Error, "Commit/review local extension changes before engine adoption: #{changed.join(', ')}" unless changed.empty?
  end

  def self.run(argv)
    options = { template: File.expand_path("..", __dir__), source: ENV["RUFLET_ENGINE_ROOT"] }
    check = initialize_inventory = false
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: ruby tool/sync_ruflet_source.rb [--source RUFLET_REPO] [--ref COMMIT] [--check] [--initialize]"
      opts.on("--source PATH", "Clean ruflet-engine repository (or RUFLET_ENGINE_ROOT)") { |value| options[:source] = value }
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
