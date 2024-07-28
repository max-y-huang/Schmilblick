import 'package:flutter/foundation.dart';
import 'package:smart_turner/backend_helpers.dart';
import 'dart:convert';
import 'process_notes.dart';

class CompiledMxl with ChangeNotifier {
  late Map<String, dynamic> compiledMxlOutput;
  late List<int> intervals;
  late List<int> measureNumbers;

  Future<void> getCompiledMxlAsMap() async {
    final response = await compileMxl();
    compiledMxlOutput = jsonDecode(response.body) as Map<String, dynamic>;
    notifyListeners();
  }

  void setIntervalsAndMeasureNumbers(
      List<int> pitchIntervals, List<int> measures) {
    intervals = pitchIntervals;
    measureNumbers = measures;
    notifyListeners();
  }
}
