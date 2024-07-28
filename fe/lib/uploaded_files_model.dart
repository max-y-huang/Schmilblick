import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class UploadedFiles with ChangeNotifier {
  PlatformFile? _mxlFile;
  PlatformFile? _pdfFile;

  PlatformFile? get mxlFile => _mxlFile;

  set mxlFile(PlatformFile? file) {
    _mxlFile = file;
    notifyListeners();
  }

  PlatformFile? get pdfFile => _pdfFile;

  set pdfFile(PlatformFile? file) {
    _pdfFile = file;
    notifyListeners();
  }

  bool get bothFilesReady => _mxlFile != null && _pdfFile != null;
}
