import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smart_turner/backend_helpers.dart';
import 'process_notes.dart';

class UploadedFiles with ChangeNotifier {
  PlatformFile? _mxlFile;
  PlatformFile? _pdfFile;
  List<int> _intervals = [];
  List<int> _measureNumbers = [];

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

  late Map<String, dynamic> _compiledMxlOutput;

  // Set the _compiledMxlOutput, _intervals, and _measureNumbers fields
  //   based on the current MXL score (represented by _mxlFile)
  Future<void> setMxlData() async {
    final fileBytes = _mxlFile?.bytes;
    final fileName = _mxlFile?.name;

    if (fileBytes == null || fileName == null) return;

    final response = await compileMxl(fileBytes, fileName);
    _compiledMxlOutput = jsonDecode(response.body) as Map<String, dynamic>;
    List<dynamic> processedMxl = processMxl(_compiledMxlOutput);
    _intervals = processedMxl[0];
    _measureNumbers = processedMxl[1];
    notifyListeners();
  }

  List<int> get intervals => _intervals;
  List<int> get measureNumbers => _measureNumbers;
  Map<String, dynamic> get compiledMxlOutput => _compiledMxlOutput;
}
