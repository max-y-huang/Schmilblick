import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_turner/backend_helpers.dart';

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
  
  late Map<String, dynamic> compiledMxlOutput;

  Future<void> getCompiledMxlAsMap() async {
    final fileBytes = _mxlFile?.bytes;
    final fileName = _mxlFile?.name;

    if (fileBytes == null || fileName == null) return;

    final response = await compileMxl(fileBytes, fileName);
    compiledMxlOutput = jsonDecode(response.body) as Map<String, dynamic>;
    notifyListeners();
  }
}