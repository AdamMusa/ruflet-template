#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require_relative "generate_flet_protocol_contract"

module ProtocolByProtocolParityAudit
  REPORT_VERSION = 1

  BODY_FILES = {
    "ControlEventBody" => "ControlEventBody.swift",
    "InvokeMethodRequestBody" => "InvokeMethodRequestBody.swift",
    "InvokeMethodResponseBody" => "InvokeMethodResponseBody.swift",
    "PaddingData" => "PageMediaData.swift",
    "PageMediaData" => "PageMediaData.swift",
    "PatchControlRequestBody" => "PatchControlRequestBody.swift",
    "RegisterClientRequestBody" => "RegisterClientBody.swift",
    "RegisterClientResponseBody" => "RegisterClientBody.swift",
    "SessionCrashedBody" => "SessionBodies.swift",
    "SessionPayload" => "SessionBodies.swift",
    "UpdateControlBody" => "UpdateControlBody.swift"
  }.freeze

  module_function

  def template_root
    FletProtocolContract.template_root
  end

  def apple_root
    File.join(template_root, "apple_packages/ruflet_apple")
  end

  def protocol_root
    File.join(apple_root, "Sources/RufletProtocol/Protocol")
  end

  def output_path
    File.join(__dir__, "protocol_by_protocol_parity_report.json")
  end

  def normalized_action(name)
    name.sub(/\A./) { |letter| letter.downcase }
  end

  def add_match(rows, category, name, matched, evidence)
    rows << {
      "category" => category,
      "name" => name,
      "status" => matched ? "matched" : "missing",
      "evidence" => Array(evidence)
    }
  end

  def build
    contract = FletProtocolContract.build
    rows = []

    message_source = File.read(File.join(protocol_root, "Message.swift"))
    contract.dig("message", "actions").each do |name, opcode|
      swift_name = normalized_action(name)
      token = "case #{swift_name} = #{opcode}"
      add_match(rows, "message_action", name, message_source.include?(token),
        "Sources/RufletProtocol/Protocol/Message.swift: #{token}")
    end
    {
      "minimum_list_items" => "list.count >= 2",
      "action_index" => "list[0]",
      "payload_index" => "list[1]"
    }.each do |name, token|
      add_match(rows, "message_shape", name, message_source.include?(token),
        "Sources/RufletProtocol/Protocol/Message.swift: #{token}")
    end

    contract.fetch("bodies").each do |body|
      file = BODY_FILES.fetch(body.fetch("name"))
      source = File.read(File.join(protocol_root, file))
      body.fetch("fields").each do |field|
        wire_key = field.fetch("wire_key")
        token = wire_key ? %Q{"#{wire_key}"} : "public let id: String"
        add_match(rows, "body_field", "#{body.fetch("name")}.#{field.fetch("dart_name")}",
          source.include?(token), "Sources/RufletProtocol/Protocol/#{file}: #{token}")
      end
    end
    invoke_source = File.read(File.join(protocol_root, "InvokeMethodRequestBody.swift"))
    add_match(rows, "body_default", "InvokeMethodRequestBody.timeout",
      invoke_source.include?("timeoutSeconds = 10"),
      "Sources/RufletProtocol/Protocol/InvokeMethodRequestBody.swift: timeoutSeconds = 10")
    backend_source = File.read(File.join(apple_root, "Sources/RufletEngine/RufletBackend.swift"))
    timeout_is_pinned = backend_source.include?("parses and carries the request timeout") &&
      !backend_source.include?("methodTimedOut") &&
      !backend_source.include?("request.timeoutNanoseconds")
    add_match(rows, "invoke_semantics", "timeout_parsed_not_enforced",
      timeout_is_pinned,
      "Sources/RufletEngine/RufletBackend.swift: direct control.invokeMethod without timeout race")

    control_source = File.read(File.join(apple_root, "Sources/RufletEngine/Models/control.swift"))
    contract.dig("patch", "operations").each do |operation|
      token = "case #{operation.fetch("name")} = #{operation.fetch("opcode")}"
      add_match(rows, "patch_operation", operation.fetch("name"),
        control_source.include?(token), "Sources/RufletEngine/Models/control.swift: #{token}")
    end
    {
      "minimum_items" => "patch.count >= 2",
      "tree_path_index" => "buildPatchPaths(patch[0]",
      "replace_visible_parent_notification" => "operation[2].text == \"visible\"",
      "move_distinct_owner_notification" => "sourceOwner !== destinationOwner"
    }.each do |name, token|
      add_match(rows, "patch_semantics", name, control_source.include?(token),
        "Sources/RufletEngine/Models/control.swift: #{token}")
    end

    pack_source = File.read(File.join(protocol_root, "MessagePack.swift"))
    contract.dig("message_pack", "markers").each do |marker|
      add_match(rows, "message_pack_marker", marker, pack_source.include?("case #{marker}"),
        "Sources/RufletProtocol/Protocol/MessagePack.swift: case #{marker}")
    end
    {
      "streaming_tail" => "reader.offset = start",
      "integer_map_keys" => "hasIntegerKey",
      "date_extension" => "temporalDate",
      "time_extension" => "temporalTime",
      "duration_extension" => "temporalDuration",
      "unknown_extension_decode" => "guard (1...3).contains(type) else { return .null }"
    }.each do |name, token|
      add_match(rows, "message_pack_semantics", name, pack_source.include?(token),
        "Sources/RufletProtocol/Protocol/MessagePack.swift: #{token}")
    end

    channel_source = File.read(File.join(apple_root, "Sources/RufletEngine/Transport/RufletBackendChannel.swift"))
    socket_source = File.read(File.join(apple_root, "Sources/RufletEngine/Transport/RufletSocketBackendChannel.swift"))
    web_socket_source = File.read(File.join(apple_root, "Sources/RufletEngine/Transport/RufletWebSocketBackendChannel.swift"))
    transport_tokens = {
      "javascript_io" => [channel_source, "RufletJavaScriptBackendChannel"],
      "web_socket" => [web_socket_source, "RufletWebSocketBackendChannel"],
      "mock" => [channel_source, "RufletMockBackendChannel"],
      "socket_tcp" => [socket_source, "NWConnection(host:"],
      "socket_unix" => [socket_source, ".unix(path:"]
    }
    transport_tokens.each do |name, (source, token)|
      add_match(rows, "transport", name, source.include?(token), token)
    end

    missing = rows.reject { |row| row.fetch("status") == "matched" }
    {
      "report_version" => REPORT_VERSION,
      "contract_version" => contract.fetch("contract_version"),
      "source" => contract.fetch("source"),
      "summary" => {
        "message_actions" => rows.count { |row| row.fetch("category") == "message_action" },
        "body_fields" => rows.count { |row| row.fetch("category") == "body_field" },
        "patch_operations" => rows.count { |row| row.fetch("category") == "patch_operation" },
        "message_pack_markers" => rows.count { |row| row.fetch("category") == "message_pack_marker" },
        "transports" => rows.count { |row| row.fetch("category") == "transport" },
        "rows" => rows.length,
        "matched_rows" => rows.length - missing.length,
        "unmatched_rows" => missing.length
      },
      "unmatched" => missing,
      "rows" => rows
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = ProtocolByProtocolParityAudit.generate
  if ARGV.delete("--check")
    abort "Protocol-by-protocol parity report is stale" unless
      File.file?(ProtocolByProtocolParityAudit.output_path) &&
        File.read(ProtocolByProtocolParityAudit.output_path) == generated
    gaps = ProtocolByProtocolParityAudit.build.dig("summary", "unmatched_rows")
    abort "Protocol-by-protocol parity has #{gaps} unmatched rows" unless gaps.zero?
    puts "Protocol-by-protocol parity report is current; every row matches."
  else
    File.write(ProtocolByProtocolParityAudit.output_path, generated)
    puts JSON.pretty_generate(ProtocolByProtocolParityAudit.build.fetch("summary"))
  end
end
