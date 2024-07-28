import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BackendResults with ChangeNotifier {
  late Map<String, dynamic> _compiledMxlOutput;
  
  Map<String, dynamic> get compiledMxlOutput => _compiledMxlOutput;

  set compiledMxlOutput(Map<String, dynamic> val) {
    _compiledMxlOutput = val;
    notifyListeners();
  }

  Map<Orientation, Uint8List> _sheetMusicSvgBytes = {};

  UnmodifiableMapView<Orientation, Uint8List> get sheetMusicSvgBytes => UnmodifiableMapView(_sheetMusicSvgBytes);

  void addMusicSvgFile(Orientation orientation, Uint8List bytes) {
    _sheetMusicSvgBytes[orientation] = bytes;
    notifyListeners();
  }
}
