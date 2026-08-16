#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"

# Generates the non-visual Flet wire/runtime contract from the vendored,
# integrity-pinned Dart sources. The declarative body table records direction
# and nullability that Dart's dynamic JSON casts express only at runtime; every
# entry is checked against the source before it enters the generated contract.
module FletProtocolContract
  CONTRACT_VERSION = 1

  BODY_SPECS = {
    "ControlEventBody" => {
      file: "control_event_body.dart", direction: "client_to_server",
      fields: [
        ["target", "target", "int", false, nil],
        ["name", "name", "String", false, nil],
        ["data", "data", "dynamic", true, nil]
      ]
    },
    "InvokeMethodRequestBody" => {
      file: "invoke_method_request_body.dart", direction: "server_to_client",
      fields: [
        ["controlId", "control_id", "int", false, nil],
        ["callId", "call_id", "String", false, nil],
        ["name", "name", "String", false, nil],
        ["args", "args", "dynamic", true, nil],
        ["timeout", "timeout", "Duration", false, { "seconds" => 10 }]
      ]
    },
    "InvokeMethodResponseBody" => {
      file: "invoke_method_response_body.dart", direction: "client_to_server",
      fields: [
        ["controlId", "control_id", "int", false, nil],
        ["callId", "call_id", "String", false, nil],
        ["result", "result", "dynamic", true, nil],
        ["error", "error", "String?", true, nil]
      ]
    },
    "PaddingData" => {
      file: "page_media_data.dart", direction: "client_to_server_nested",
      fields: [
        ["top", "top", "double", false, nil],
        ["right", "right", "double", false, nil],
        ["bottom", "bottom", "double", false, nil],
        ["left", "left", "double", false, nil]
      ]
    },
    "PageMediaData" => {
      file: "page_media_data.dart", direction: "client_to_server_nested",
      fields: [
        ["padding", "padding", "PaddingData", false, nil],
        ["viewPadding", "view_padding", "PaddingData", false, nil],
        ["viewInsets", "view_insets", "PaddingData", false, nil],
        ["devicePixelRatio", "device_pixel_ratio", "double", false, nil],
        ["orientation", "orientation", "Orientation", false, nil],
        ["alwaysUse24HourFormat", "always_use_24_hour_format", "bool", false, nil]
      ]
    },
    "PatchControlRequestBody" => {
      file: "patch_control_request_body.dart", direction: "server_to_client",
      fields: [
        ["id", "id", "int", false, nil],
        ["patch", "patch", "List<dynamic>", false, nil]
      ]
    },
    "RegisterClientRequestBody" => {
      file: "register_client_request_body.dart", direction: "client_to_server",
      fields: [
        ["sessionId", "session_id", "String?", true, nil],
        ["pageName", "page_name", "String", false, nil],
        ["page", "page", "Map<String, dynamic>", false, nil]
      ]
    },
    "RegisterClientResponseBody" => {
      file: "register_client_response_body.dart", direction: "server_to_client",
      fields: [
        ["sessionId", "session_id", "String?", true, nil],
        ["patch", "page_patch", "Map<String, dynamic>", false, nil],
        ["error", "error", "String?", true, nil]
      ]
    },
    "SessionCrashedBody" => {
      file: "session_crashed_body.dart", direction: "server_to_client",
      fields: [["message", "message", "String", false, nil]]
    },
    "SessionPayload" => {
      file: "session_payload.dart", direction: "reserved",
      fields: [["id", nil, "String", false, nil]]
    },
    "UpdateControlBody" => {
      file: "update_control_body.dart", direction: "client_to_server",
      fields: [
        ["id", "id", "int", false, nil],
        ["props", "props", "Map<String, dynamic>", false, nil]
      ]
    }
  }.freeze

  module_function

  def template_root
    @template_root ||= File.expand_path("../..", __dir__)
  end

  def flet_root
    File.join(template_root, "flet_packages/flet/lib/src")
  end

  def output_path
    File.join(__dir__, "flet_protocol_contract.json")
  end

  def read(relative)
    File.read(File.join(flet_root, relative))
  end

  def source_files
    Dir.glob(File.join(flet_root, "protocol/*.dart")).sort + [
      File.join(flet_root, "models/control.dart"),
      *Dir.glob(File.join(flet_root, "transport/*.dart")).sort
    ]
  end

  def source_digest
    Digest::SHA256.hexdigest(source_files.map { |path|
      "#{path.delete_prefix(template_root + "/")}\0#{File.binread(path)}"
    }.join("\0"))
  end

  def class_body(source, name)
    match = source.match(/\bclass\s+#{Regexp.escape(name)}\b/)
    raise "Missing Dart class #{name}" unless match

    opening = source.index("{", match.end(0))
    depth = 0
    source.each_char.with_index do |character, index|
      next if index < opening
      depth += 1 if character == "{"
      depth -= 1 if character == "}"
      return source[(opening + 1)...index] if depth.zero?
    end
    raise "Unbalanced Dart class #{name}"
  end

  def actions
    source = read("protocol/message.dart")
    source.scan(/^\s*(\w+)\((-?\d+)\)[,;]?$/).to_h { |name, value|
      [name, value.to_i]
    }
  end

  def bodies
    BODY_SPECS.map do |name, spec|
      relative = "protocol/#{spec.fetch(:file)}"
      source = read(relative)
      body = class_body(source, name)
      fields = spec.fetch(:fields).map do |dart_name, wire_key, type, nullable, default|
        unless body.match?(/\bfinal\s+#{Regexp.escape(type)}\s+#{Regexp.escape(dart_name)}\s*;/m)
          raise "#{name}.#{dart_name} no longer has pinned type #{type}"
        end
        if wire_key && !body.include?(%Q{"#{wire_key}"}) && !body.include?(%Q{'#{wire_key}'})
          raise "#{name}.#{dart_name} no longer maps wire key #{wire_key}"
        end
        {
          "dart_name" => dart_name,
          "wire_key" => wire_key,
          "type" => type,
          "nullable" => nullable,
          "default" => default
        }
      end
      {
        "name" => name,
        "source" => relative,
        "direction" => spec.fetch(:direction),
        "fields" => fields
      }
    end.sort_by { |body| body.fetch("name") }
  end

  def patch_operations
    source = read("models/control.dart")
    enum = source[/enum\s+OperationType\s*\{(.*?)\n\}/m, 1] || raise("Missing OperationType")
    enum.scan(/\b(\w+)\((-?\d+)\)/).filter_map do |name, opcode|
      next if name == "unknown"
      { "name" => name, "opcode" => opcode.to_i }
    end
  end

  def message_pack_markers
    read("transport/streaming_msgpack_deserializer.dart")
      .scan(/case\s+(0x[0-9a-f]+)\s*:/i).flatten.map(&:downcase).uniq.sort
  end

  def build
    {
      "contract_version" => CONTRACT_VERSION,
      "source" => {
        "flet_version" => "0.80.5",
        "git_ref" => "67a9763da3bd2611bbb7626c3a1ec5e9d30fc965",
        "vendored_root" => "flet_packages/flet/lib/src",
        "sha256" => source_digest
      },
      "message" => {
        "actions" => actions,
        "minimum_list_items" => 2,
        "trailing_list_items" => "ignored"
      },
      "bodies" => bodies,
      "invoke_method" => {
        "timeout_default_seconds" => 10,
        "timeout_behavior" => "parsed_and_forwarded_but_not_enforced"
      },
      "patch" => {
        "minimum_items" => 2,
        "tree_node" => ["index", "children_map_optional"],
        "operations" => patch_operations,
        "operation_shapes" => {
          "replace" => ["opcode", "target", "key", "value"],
          "add" => ["opcode", "target", "key_or_index", "value"],
          "remove" => ["opcode", "target", "key_or_index"],
          "move" => ["opcode", "source_target", "source_key_or_index", "destination_target", "destination_key_or_index"]
        },
        "notification" => {
          "each_operation" => true,
          "replace_visible_notifies_parent" => true,
          "move_distinct_owners_notify_both" => true
        }
      },
      "message_pack" => {
        "markers" => message_pack_markers,
        "streaming" => "decode_all_complete_values_and_retain_incomplete_tail",
        "map_key_types" => ["string", "integer"],
        "extensions" => {
          "1" => "DateTime ISO-8601 UTF-8",
          "2" => "TimeOfDay hour:minute UTF-8",
          "3" => "Duration microseconds UTF-8",
          "4" => "JSAny string UTF-8 encoder-only"
        },
        "unknown_extension_decode" => "null"
      },
      "transports" => {
        "factory_order" => ["javascript", "web_socket", "mock", "socket"],
        "apple_channels" => {
          "javascript_io" => { "local" => true, "reconnect_ms" => 10, "send" => "no_op" },
          "web_socket" => { "reconnect_ms" => 500, "schemes" => ["http", "https"] },
          "mock" => { "local" => true, "reconnect_ms" => 500 },
          "socket" => { "local_reconnect_ms" => 200, "public_reconnect_ms" => 500, "modes" => ["tcp", "unix"] }
        }
      }
    }
  end

  def generate
    JSON.pretty_generate(build) + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  generated = FletProtocolContract.generate
  if ARGV.delete("--check")
    abort "Flet protocol contract is stale" unless
      File.file?(FletProtocolContract.output_path) &&
        File.read(FletProtocolContract.output_path) == generated
    puts "Flet protocol contract is current."
  else
    File.write(FletProtocolContract.output_path, generated)
    puts "Generated #{FletProtocolContract.output_path}"
  end
end
