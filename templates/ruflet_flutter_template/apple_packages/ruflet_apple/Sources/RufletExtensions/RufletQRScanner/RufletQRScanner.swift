/// Public namespace for the native port of the vendored
/// `ruflet_qrcode_scanner` Flet extension.
public enum RufletQRScanner {
  public static let packageName = "ruflet_qrcode_scanner"
  public static let controlTypes: Set<String> = ["QrcodeScanner", "qrcode_scanner"]
  public static let events: Set<String> = ["detect", "error"]
  public static let methods: Set<String> = [
    "reset_zoom_scale", "set_zoom_scale", "start", "stop", "switch_camera", "toggle_torch",
  ]
}
