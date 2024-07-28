import 'package:flutter/foundation.dart';
import 'package:smart_turner/backend_helpers.dart';
import 'dart:convert';
import 'process_notes.dart';

class CompiledMxl with ChangeNotifier {
  late Map<String, dynamic> compiledMxlOutput;
  late List<Slice> dstSlices;

  Future<void> getCompiledMxlAsMap() async {
    final response = await compileMxl();
    compiledMxlOutput = jsonDecode(response.body) as Map<String, dynamic>;
    notifyListeners();
  }

  void setDstSlices(List<Slice> slices) {
    dstSlices = slices;
    notifyListeners();
  }
}
