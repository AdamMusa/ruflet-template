import 'pasted_file.dart';

/// Native apps have no browser paste event: PasteFilesScope reads the
/// clipboard on the keyboard paste shortcut instead.
Object? listenForPastedFiles(
        bool Function() isFocused, void Function(List<PastedFile>) onFiles) =>
    null;

void stopListeningForPastedFiles(Object? handle) {}
