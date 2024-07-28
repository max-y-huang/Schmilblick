import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

Future<http.Response> compileMxl(Uint8List musicXmlBytes, String fileName) async {
  const uri = "http://localhost:4000";
  final request = http.MultipartRequest('POST', Uri.parse('$uri/compile-mxl'));

  request.files.add(http.MultipartFile.fromBytes(
    'file', musicXmlBytes,
    filename: fileName
  ));

  final streamResponse = await request.send();
  final response = await http.Response.fromStream(streamResponse);

  return response;
}

Future<http.Response> mxlToSvg(Uint8List musicXmlBytes, String fileName, int imageWidth) async {
  const uri = "http://localhost:3000";
  final request =
      http.MultipartRequest('POST', Uri.parse('$uri/musicxml-to-svg'));
  request.fields['pageWidth'] = imageWidth.toString();
  
  request.files.add(http.MultipartFile.fromBytes(
    'musicxml', musicXmlBytes,
    filename: fileName
  ));

  final streamResponse = await request.send();
  final response = await http.Response.fromStream(streamResponse);

  return response;
}
