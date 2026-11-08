# frozen_string_literal: true

require "minitest/autorun"

# The entrypoints run two ordered startup hook lists: one just before runApp
# and one after the first frame. They declare both lists empty themselves, so
# they compile with every ruflet gem, including the released ones that copy
# lib/main*.dart into an existing client dir file by file and know nothing
# about hooks. Only while a build feature adds hooks does `ruflet build`
# (Ruflet::CLI::ClientBootstrap in AdamMusa/ruflet) write
# lib/ruflet_bootstrap.g.dart, import it and empty the marked block.
class BootstrapHooksContractTest < Minitest::Test
  TEMPLATE_ROOT = File.expand_path("../..", __dir__)
  ENTRYPOINTS = %w[lib/main.self.dart lib/main.server.dart].freeze

  # The CLI finds the block by these exact marker lines
  # (packages/ruflet/lib/ruflet/cli/client_bootstrap.rb). Change both together.
  HOOKS_START = "// --RUFLET_BOOTSTRAP_HOOKS_START--\n"
  HOOKS_END = "// --RUFLET_BOOTSTRAP_HOOKS_END--\n"
  HOOK_LISTS = <<~DART
    const rufletPreRunAppHooks = <RufletBootstrapHook>[];
    const rufletPostFirstFrameHooks = <RufletBootstrapHook>[];
  DART
  GENERATED_BOOTSTRAP = "lib/ruflet_bootstrap.g.dart"

  PRE_RUN_APP_HOOKS = <<~DART.gsub(/^/, "  ")
    if (rufletPreRunAppHooks.isNotEmpty) {
      await runRufletBootstrapHooks(rufletPreRunAppHooks, 'pre-runApp');
    }
  DART
  POST_FIRST_FRAME_HOOKS = "  scheduleRufletBootstrapHooksAfterFirstFrame(rufletPostFirstFrameHooks);\n"

  # An import, export or part directive up to its semicolon, which may be
  # several lines on: a conditional import names its alternatives after `if`.
  # `part of` is not a directive that names a file to load.
  DIRECTIVE = /^[ \t]*(import|export|part)(?![A-Za-z0-9_$])(?![ \t]+of\b)([^;]*);/
  # A URI in either quote style.
  URI_LITERAL = /(['"])([^'"\n]*)\1/

  # A file the CLI writes must never ship here: the default build/client copy
  # would carry it, but a client dir an older gem refreshes would not, and the
  # two would start to differ.
  def test_template_does_not_ship_the_generated_bootstrap
    refute File.exist?(File.join(TEMPLATE_ROOT, GENERATED_BOOTSTRAP)),
           "#{GENERATED_BOOTSTRAP} is written by `ruflet build` only while a feature adds hooks"
  end

  # Released gems refresh lib/main*.dart without the rest of lib/, so an
  # entrypoint may only import, export or include as a part what the template
  # itself ships, whichever quotes the directive uses.
  def test_entrypoints_import_only_files_the_template_ships
    (ENTRYPOINTS + ["lib/main.dart"]).each do |relative_path|
      uris = directive_uris(relative_path)
      refute_empty uris, "#{relative_path}: no directive found"

      uris.each do |keyword, uri|
        next if uri.start_with?("dart:", "package:")

        assert File.file?(File.join(TEMPLATE_ROOT, "lib", uri)),
               "#{relative_path}: #{keyword} '#{uri}' names a file the template does not ship"
      end
    end
  end

  # No released gem writes the generated file, so any reference to it, in any
  # directive form or quote style, stops the client compiling with them.
  def test_entrypoints_never_refer_to_the_generated_bootstrap
    generated = File.basename(GENERATED_BOOTSTRAP)

    (ENTRYPOINTS + ["lib/main.dart"]).each do |relative_path|
      directive_uris(relative_path).each do |keyword, uri|
        refute_equal generated, File.basename(uri), "#{relative_path}: #{keyword} '#{uri}'"
      end
      assert_empty code_lines(read(relative_path)).grep(/#{Regexp.escape(generated)}/),
                   "#{relative_path}: only comments may name the generated file"
    end
  end

  # `ruflet build` renames this package to the app's package name
  # (apply_pubspec_metadata in AdamMusa/ruflet) and build/client keeps lib/ and
  # test/ as they are, so a Dart file that reaches this package by its
  # template name stops resolving there. test/ reaches lib/ relatively.
  def test_dart_files_never_import_the_client_package_by_its_template_name
    package = read("pubspec.yaml")[/^name:[ \t]*([A-Za-z0-9_]+)/, 1]
    refute_nil package, "pubspec.yaml has no name"
    files = Dir.glob("{lib,test}/**/*.dart", base: TEMPLATE_ROOT).sort
    assert_includes files, "test/ruflet_bootstrap_test.dart"

    files.each do |relative_path|
      directive_uris(relative_path).each do |keyword, uri|
        refute uri.start_with?("package:#{package}/"),
               "#{relative_path}: #{keyword} '#{uri}' stops resolving once `ruflet build` renames the package"
      end
    end
  end

  def test_entrypoints_declare_both_hook_lists_empty_in_one_marked_block
    ENTRYPOINTS.each do |relative_path|
      source = read(relative_path)

      assert_equal 1, source.scan(HOOKS_START).size, relative_path
      assert_equal 1, source.scan(HOOKS_END).size, relative_path
      assert_match(/^#{Regexp.escape(HOOKS_START)}/, source, "#{relative_path}: the start marker begins a line")
      block = source[(source.index(HOOKS_START) + HOOKS_START.size)...source.index(HOOKS_END)]
      assert_equal HOOK_LISTS, block, relative_path
      assert_includes source, "\ntypedef RufletBootstrapHook = FutureOr<void> Function();\n", relative_path
      refute_includes main_body(relative_path), HOOKS_START, "#{relative_path}: the block is top level"
    end
  end

  def test_pre_run_app_hooks_run_only_when_present_and_just_before_run_app
    ENTRYPOINTS.each do |relative_path|
      body = main_body(relative_path)
      run_app = body.index("\n  runApp(")

      refute_nil run_app, relative_path
      assert_equal 1, body.scan("runApp(").size, relative_path
      hooks = body.index(PRE_RUN_APP_HOOKS)
      refute_nil hooks, "#{relative_path} must guard its pre-runApp hooks with isNotEmpty"
      between = body[(hooks + PRE_RUN_APP_HOOKS.size)...run_app]
      assert_empty code_lines(between), "#{relative_path}: nothing may run between the hooks and runApp"
    end
  end

  def test_post_first_frame_hooks_are_scheduled_right_after_run_app
    ENTRYPOINTS.each do |relative_path|
      body = main_body(relative_path)
      run_app = body.index("\n  runApp(")
      run_app_end = body.index(");\n", run_app) + 3

      assert_equal POST_FIRST_FRAME_HOOKS, body[run_app_end..], relative_path
    end
  end

  def test_entrypoints_share_one_hook_block_and_runner
    runners = ENTRYPOINTS.map do |relative_path|
      source = read(relative_path)
      start = source.index("// Startup hooks for build features.")
      refute_nil start, relative_path
      finish = source.index("\n}\n", source.index("void scheduleRufletBootstrapHooksAfterFirstFrame", start))
      source[start..finish + 2]
    end

    assert_equal runners.first, runners.last
    assert_includes runners.first, "if (hooks.isEmpty) return;"
    assert_includes runners.first, "FlutterError.reportError("
    assert_includes runners.first, "WidgetsBinding.instance.addPostFrameCallback("
  end

  private

  def read(relative_path)
    File.read(File.join(TEMPLATE_ROOT, relative_path), encoding: Encoding::UTF_8)
  end

  # The body of `main` up to its closing brace.
  def main_body(relative_path)
    source = read(relative_path)
    start = source.index(/^Future<void> main\(/)
    refute_nil start, relative_path
    source[start...source.index("\n}\n", start) + 1]
  end

  # [keyword, uri] for every import, export and part directive, a conditional
  # import's alternatives included.
  def directive_uris(relative_path)
    read(relative_path).scan(DIRECTIVE).flat_map do |keyword, rest|
      rest.scan(URI_LITERAL).map { |_quote, uri| [keyword, uri] }
    end
  end

  def code_lines(text)
    text.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("//") }
  end
end
