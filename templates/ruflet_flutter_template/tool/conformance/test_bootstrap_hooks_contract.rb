# frozen_string_literal: true

require "minitest/autorun"

# The entrypoints run the ordered hook lists `ruflet build` writes into
# lib/ruflet_bootstrap.g.dart: one list just before runApp and one after the
# first frame. The template ships the file the CLI writes when no build feature
# adds a hook, so an unmodified template starts exactly as it did without them.
class BootstrapHooksContractTest < Minitest::Test
  TEMPLATE_ROOT = File.expand_path("../..", __dir__)
  ENTRYPOINTS = %w[lib/main.self.dart lib/main.server.dart].freeze

  # Byte-identical to what Ruflet::CLI::ClientBootstrap (AdamMusa/ruflet,
  # packages/ruflet/lib/ruflet/cli/client_bootstrap.rb) writes with no hooks;
  # packages/ruflet/test/client_bootstrap_test.rb pins the same text. Change
  # both together.
  DEFAULT_BOOTSTRAP = <<~DART
    // GENERATED FILE. DO NOT EDIT.
    //
    // `ruflet build` writes this file into the Flutter client on every build.
    // lib/main.self.dart and lib/main.server.dart run its hooks in list order:
    //
    // * rufletPreRunAppHooks are awaited one at a time just before runApp, once
    //   the Flutter binding and every extension are initialized.
    // * rufletPostFirstFrameHooks run one at a time after the first frame.
    //
    // A hook that throws is reported through FlutterError.reportError and does
    // not stop the hooks after it or the app. With both lists empty the
    // entrypoints skip the hooks entirely. Build features add hooks through
    // Ruflet::CLI::ClientBootstrap in the ruflet gem.

    import 'dart:async';

    /// A bootstrap hook: a top-level or static function that takes no
    /// arguments.
    typedef RufletBootstrapHook = FutureOr<void> Function();

    const rufletPreRunAppHooks = <RufletBootstrapHook>[];

    const rufletPostFirstFrameHooks = <RufletBootstrapHook>[];
  DART

  PRE_RUN_APP_HOOKS = <<~DART.gsub(/^/, "  ")
    if (rufletPreRunAppHooks.isNotEmpty) {
      await runRufletBootstrapHooks(rufletPreRunAppHooks, 'pre-runApp');
    }
  DART
  POST_FIRST_FRAME_HOOKS = "  scheduleRufletBootstrapHooksAfterFirstFrame(rufletPostFirstFrameHooks);\n"

  def test_template_ships_the_bootstrap_the_cli_writes_without_hooks
    path = File.join(TEMPLATE_ROOT, "lib/ruflet_bootstrap.g.dart")

    assert_equal DEFAULT_BOOTSTRAP, File.binread(path)
  end

  def test_entrypoints_import_the_bootstrap
    ENTRYPOINTS.each do |relative_path|
      assert_includes read(relative_path), "\nimport 'ruflet_bootstrap.g.dart';\n", relative_path
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

  def test_entrypoints_share_one_hook_runner
    runners = ENTRYPOINTS.map do |relative_path|
      source = read(relative_path)
      start = source.index("/// Runs build-written bootstrap hooks")
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

  def code_lines(text)
    text.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("//") }
  end
end
