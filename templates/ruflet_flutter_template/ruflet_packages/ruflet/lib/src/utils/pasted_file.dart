import 'dart:typed_data';

/// One file pasted into a text field, as Ruby's TextField on_paste_files
/// receives it (Flet's PastedFile): a name, the MIME type the platform
/// reported (can be empty) and the contents.
class PastedFile {
  final String name;
  final String mimeType;
  final Uint8List bytes;

  const PastedFile(
      {required this.name, required this.mimeType, required this.bytes});

  /// A clipboard image, which has no file name: "image.<ext>", typed from
  /// its leading bytes (PNG when they name no other image format).
  factory PastedFile.image(Uint8List bytes) {
    final (extension, mimeType) = _imageType(bytes);
    return PastedFile(
        name: "image.$extension", mimeType: mimeType, bytes: bytes);
  }

  Map<String, dynamic> toMap() =>
      {"name": name, "mime_type": mimeType, "bytes": bytes};

  static (String, String) _imageType(Uint8List bytes) {
    bool startsWith(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return ("jpg", "image/jpeg");
    if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return ("gif", "image/gif");
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return ("webp", "image/webp");
    }
    if (startsWith(const [0x49, 0x49, 0x2A, 0x00]) ||
        startsWith(const [0x4D, 0x4D, 0x00, 0x2A])) {
      return ("tiff", "image/tiff");
    }
    if (startsWith(const [0x42, 0x4D])) return ("bmp", "image/bmp");
    return ("png", "image/png");
  }
}
