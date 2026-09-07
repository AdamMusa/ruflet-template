# frozen_string_literal: true

# The reviewed, deterministic downstream namespace transform. Upstream Git
# paths/hashes remain provenance, while consumers compile only Ruflet packages.
module RufletNamespace
  VERSION = 1
  TOKEN = /(?<![A-Za-z0-9])flet|(?<=\\[nrt])flet|(?<!Ru)Flet|(?<![A-Za-z0-9])FLET/
  URL = %r{(?:https?|git|ssh)://[^\s<>"'`]+}
  ATTRIBUTION = /(?:\A|[_-])(?:LICENSE|COPYING|COPYRIGHT|NOTICE|AUTHORS|CREDITS|UPSTREAM|CHANGELOG)(?:[._-]|\z)/i

  def self.rename(value)
    value.gsub(TOKEN) do |token|
      { "flet" => "ruflet", "Flet" => "Ruflet", "FLET" => "RUFLET" }.fetch(token)
    end
  end

  def self.rewrite(path, bytes)
    return bytes if File.basename(path).match?(ATTRIBUTION) || bytes.include?("\x00")

    text = bytes.dup.force_encoding(Encoding::UTF_8)
    return bytes unless text.valid_encoding?

    text = text.lines.map do |line|
      next line if line.match?(/copyright|SPDX-License-Identifier/i)

      # Existing external URLs are real upstream resources, not new Ruflet
      # domains or repositories. Do not invent their renamed equivalents.
      urls = []
      protected = line.gsub(URL) { |url| urls << url; "\u0001#{urls.length - 1}\u0002" }
      rename(protected).gsub(/\u0001(\d+)\u0002/) { urls.fetch(Regexp.last_match(1).to_i) }
    end.join

    if path == "pubspec.yaml"
      text = text.sub(/^description:.*$/, "description: Ruflet Flutter rendering engine for Ruby applications.")
      text = text.sub(/^homepage:.*$/, "homepage: https://github.com/AdamMusa/ruflet")
      text = text.sub(/^repository:.*$/, "repository: https://github.com/AdamMusa/ruflet-template")
    end
    text
  end
end
