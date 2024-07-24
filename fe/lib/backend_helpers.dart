import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

// TODO: add argument for the MXL file to be parsed
Future<http.Response> compileMxl() async {
  const uri = "https://cf2957d893188a.lhr.life";
  const score = "emerald_moonlight";
  final request = http.MultipartRequest('POST', Uri.parse('$uri/compile-mxl'));

  final musicxmlBytes =
      (await rootBundle.load('assets/$score.mxl')).buffer.asUint8List();
  request.files.add(
      http.MultipartFile.fromBytes('file', musicxmlBytes, filename: score));

  final streamResponse = await request.send();
  final response = await http.Response.fromStream(streamResponse);

  return response;
}

Future<Map<String, dynamic>> getCompiledMxlAsMap() async {
  final response = await compileMxl();
  return jsonDecode(response.body) as Map<String, dynamic>;
}
