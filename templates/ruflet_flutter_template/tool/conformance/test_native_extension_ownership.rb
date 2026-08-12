# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "audit_native_extension_ownership"

class NativeExtensionOwnershipTest < Minitest::Test
  def test_every_executable_extension_wire_is_owned_by_its_native_product
    errors, = NativeExtensionOwnership.audit
    assert_empty errors, errors.join("\n")
  end

  def test_commented_flet_todos_are_not_native_requirements
    controls = NativeExtensionOwnership.extension_controls

    refute controls.any? { |control| control.fetch("wire_type") == "NativeAd" },
      "flet_ads comments NativeAd out of its executable extension registry"
  end

  def test_ruflet_qr_extension_is_part_of_the_source_contract
    controls = NativeExtensionOwnership.extension_controls
    qrcode = controls.select { |control| control.fetch("package") == "ruflet_qrcode_scanner" }

    assert_equal %w[QrcodeScanner qrcode_scanner], qrcode.map { |control| control.fetch("wire_type") }.sort
    qrcode.each do |control|
      assert_equal %w[detect error], control.fetch("events")
      assert_equal %w[reset_zoom_scale set_zoom_scale start stop switch_camera toggle_torch],
        control.fetch("methods")
    end
  end

  def test_primitive_defaults_are_generated_directly_from_the_same_contract
    generator = File.join(NativeExtensionOwnership::TEMPLATE_ROOT, "tool", "generate_flet_defaults.rb")
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, generator, "--check")

    assert status.success?, stderr
  end
end
