#!/usr/bin/env ruby
# frozen_string_literal: true

# Backward-compatible entrypoint. The manifest is now generated from a clean
# source commit by the same guarded operation that syncs its tracked files.
require_relative "../sync_flet_source"
exit(FletSourceSync.run(ARGV) || 0)
