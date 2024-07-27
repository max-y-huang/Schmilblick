import 'package:flutter/foundation.dart';
import 'package:smart_turner/backend_helpers.dart';
import 'dart:convert';

class CompiledMxl with ChangeNotifier {
  late Map<String, dynamic> compiledMxlOutput;
  Future<void> getCompiledMxlAsMap() async {
    final response = await compileMxl();
    compiledMxlOutput = jsonDecode(response.body) as Map<String, dynamic>;
    notifyListeners();
  }
}
