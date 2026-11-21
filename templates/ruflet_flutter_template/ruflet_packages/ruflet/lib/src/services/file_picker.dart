import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../ruflet_service.dart';
import '../utils/file_picker.dart';
import '../utils/invoke.dart';
import '../utils/numbers.dart';
import '../utils/platform.dart';

class FilePickerService extends RufletService {
  FilePickerService({required super.control});

  List<PlatformFile>? _files;

  @override
  void init() {
    super.init();
    debugPrint("FilePickerService(${control.id}).init: ${control.properties}");
    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    debugPrint("FilePickerService(${control.id}).dispose()");
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("FilePicker.$name($args)");
    var dialogTitle = args["dialog_title"];
    var fileType = parseFileType(args["file_type"], FileType.any)!;
    var initialDirectory = args["initial_directory"];
    var allowedExtensions = (args["allowed_extensions"] as List?)
        ?.map((e) => e.toString())
        .toList();
    var withData = parseBool(args["with_data"], false)!;
    var srcBytes = args["src_bytes"];

    if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
      fileType = FileType.custom;
    }
    switch (name) {
      case "upload":
        var files = args["files"];
        if (files != null && _files != null) {
          uploadFiles(files, control.backend.pageUri);
        }
      case "pick_files":
        _files = await pickPlatformFiles(args);
        return pickedFilesResult(_files, withData);
      case "save_file":
        if ((kIsWeb || isAndroidMobile() || isIOSMobile()) &&
            srcBytes == null) {
          // Web, Android and iOS write the bytes themselves.
          requireInvokeArg(args, "src_bytes", "FilePicker.save_file");
        }
        if (kIsWeb) requireInvokeArg(args, "file_name", "FilePicker.save_file");
        return await FilePicker.platform.saveFile(
            dialogTitle: dialogTitle,
            fileName: args["file_name"] != null || !isIOSMobile()
                ? args["file_name"]
                : "new-file",
            initialDirectory: initialDirectory,
            lockParentWindow: true,
            type: fileType,
            allowedExtensions: allowedExtensions,
            bytes: srcBytes);
      case "get_directory_path":
        if (kIsWeb) {
          throw Exception("Get Directory Path dialog is not supported on web.");
        }
        return await FilePicker.platform.getDirectoryPath(
          dialogTitle: dialogTitle,
          initialDirectory: initialDirectory,
          lockParentWindow: true,
        );
      default:
        throw Exception("Unknown FilePicker method: $name");
    }
  }

  Future uploadFiles(List<dynamic> files, Uri pageUri) async {
    var uploadFiles = files.map((u) => FilePickerUploadFile(
        id: u["id"],
        name: u["name"],
        uploadUrl: u["upload_url"],
        method: u["method"]));

    for (var uf in uploadFiles) {
      var file = ((uf.id != null && uf.id! >= 0 && uf.id! < _files!.length)
              ? _files![uf.id!]
              : null) // by id
          ??
          _files!.firstWhereOrNull((f) => f.name == uf.name); // by name

      if (file != null) {
        try {
          await uploadFile(
              file, getFullUploadUrl(pageUri, uf.uploadUrl), uf.method);
          _files!.remove(file); // Remove the uploaded file
        } catch (e) {
          sendProgress(file.name, null, e.toString());
        }
      } else {
        debugPrint(
            "FilePicker Error: File '${uf.name}' (id: ${uf.id}) not found.");
      }
    }
  }

  Future uploadFile(PlatformFile file, String uploadUrl, String method) async {
    final fileReadStream = file.readStream;
    if (fileReadStream == null) {
      throw Exception('Cannot read file from null stream');
    }
    debugPrint("Uploading ${file.name}");
    final streamedRequest = http.StreamedRequest(method, Uri.parse(uploadUrl))
      ..headers.addAll({
        //'Cache-Control': 'no-cache',
      });
    streamedRequest.contentLength = file.size;

    // send 0%
    sendProgress(file.name, 0, null);

    double lastSent = 0; // send every 10%
    double progress = 0;
    int bytesSent = 0;
    fileReadStream.listen((chunk) async {
      //debugPrint(chunk.length);
      streamedRequest.sink.add(chunk);
      bytesSent += chunk.length;
      progress = bytesSent / file.size;
      if (progress >= lastSent) {
        lastSent += 0.1;
        if (progress != 1.0) {
          sendProgress(file.name, progress, null);
        }
      }
    }, onDone: () {
      streamedRequest.sink.close();
    });

    var streamedResponse = await streamedRequest.send();
    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode > 204) {
      sendProgress(file.name, null,
          "Upload endpoint returned code ${response.statusCode}: ${response.body}");
    } else {
      // send 100%
      sendProgress(file.name, progress, null);
    }
  }

  void sendProgress(String name, double? progress, String? error) {
    control.triggerEvent(
        "upload",
        FilePickerUploadProgressEvent(
                name: name, progress: progress, error: error)
            .toMap());
  }

  String getFullUploadUrl(Uri pageUri, String uploadUrl) {
    Uri uploadUri = Uri.parse(uploadUrl);
    if (!uploadUri.hasAuthority) {
      return Uri(
              scheme: pageUri.scheme,
              host: pageUri.host,
              port: pageUri.port,
              path: uploadUri.path,
              query: uploadUri.query)
          .toString();
    } else {
      return uploadUrl;
    }
  }
}

/// Opens the platform file picker for FilePicker.pick_files [args]. The
/// dialog opens synchronously (before the first await), so a `FilePicker`
/// client action opens it inside the user's tap, where browsers allow it.
Future<List<PlatformFile>?> pickPlatformFiles(dynamic args) async {
  var fileType = parseFileType(args["file_type"], FileType.any)!;
  var allowedExtensions = (args["allowed_extensions"] as List?)
      ?.map((e) => e.toString())
      .toList();
  if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
    fileType = FileType.custom;
  }
  var withData = parseBool(args["with_data"], false)!;
  return (await FilePicker.platform.pickFiles(
          dialogTitle: args["dialog_title"],
          initialDirectory: args["initial_directory"],
          lockParentWindow: true,
          type: fileType,
          allowedExtensions: allowedExtensions,
          allowMultiple: parseBool(args["allow_multiple"], false)!,
          withData: withData,
          withReadStream: !withData))
      ?.files;
}

/// What FilePicker.pick_files returns to Ruby for the picked [files]: each
/// file's index (the id `upload` takes), name, path (not on the web), size and,
/// [withData], its bytes. Empty when the user cancelled.
List<Map<String, dynamic>> pickedFilesResult(
        List<PlatformFile>? files, bool withData) =>
    files == null
        ? []
        : files.asMap().entries.map((file) {
            return FilePickerFile(
                    id: file.key, // use entry's index as id
                    name: file.value.name,
                    path: kIsWeb ? null : file.value.path,
                    size: file.value.size,
                    bytes: withData ? file.value.bytes : null)
                .toMap();
          }).toList();

/// FilePicker.pick_files without a FilePicker service on the page: a
/// `FilePicker` client action uses it when Ruby has not mounted one. The
/// picked files are returned but not kept, so they cannot be uploaded.
Future<dynamic> pickFilesWithoutService(String name, dynamic args) async {
  if (name != "pick_files") {
    throw Exception("Unknown FilePicker client action: $name");
  }
  return pickedFilesResult(
      await pickPlatformFiles(args), parseBool(args["with_data"], false)!);
}
