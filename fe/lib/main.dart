import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'audio_recorder.dart';
import 'dart:math';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: ScoreSheet(),
    );
  }
}

class ScoreSheet extends StatefulWidget {
  const ScoreSheet({super.key});

  @override
  State<ScoreSheet> createState() => _ScoreSheetState();
}

class _ScoreSheetState extends State<ScoreSheet> {
  final uri = "http://localhost:3000";
  late final Future<Uint8List> _pdfBytes;

  late final PDFViewController _pdfViewController;
  late final List<int> _pageTable;

  @override
  void initState() {
    super.initState();
    _extractCompiledMxlInformation();
    _getFile(); 
  }

  void _getFile() async {
    // TODO: Turn the file into a backend call.
    final pdfBytes = rootBundle.load('assets/happy_birthday.pdf').then((file) => file.buffer.asUint8List());
    setState(() {
      _pdfBytes = pdfBytes;
    });
  }

  Future<http.Response> _compileMxl() async {
    final request = http.MultipartRequest('POST', Uri.parse('$uri/compile-mxl'));

    const filename = "happy_birthday.mxl";
    final musicxmlBytes = (await rootBundle.load('assets/$filename')).buffer.asUint8List();
    request.files.add(http.MultipartFile.fromBytes('file', musicxmlBytes, filename: filename));

    final streamResponse = await request.send();
    final response = await http.Response.fromStream(streamResponse);

    return response;
  }

  void _extractCompiledMxlInformation() async {
    final response = await _compileMxl();
    final resJson = jsonDecode(response.body) as Map<String, dynamic>;
    final parts = resJson["parts"] as Map<String, dynamic>;
    final firstPart = parts.keys.first;
    final pageTableDyn = parts[firstPart]["page_table"] as List<dynamic>;
    final pageTable = pageTableDyn.map((e) => e as int).toList();
    _pageTable = pageTable;
  }

  void _initializeController(PDFViewController pdfViewController) {
    _pdfViewController = pdfViewController;
  }

  void jumpToMeasure(int measureId) {
    if (0 <= measureId && measureId < _pageTable.length) {
      final int pageNumber = _pageTable[measureId];
      _pdfViewController.setPage(pageNumber);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: FutureBuilder(future: _pdfBytes, builder: (buildContext, snapshot) {
        if (snapshot.hasData) {
          return Scaffold(
            body: PDFView(
              pdfData: snapshot.data,
              swipeHorizontal: true,
              onViewCreated: _initializeController,
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                jumpToMeasure(12);
              },
              child: const Icon(Icons.arrow_upward),
            )
          );
        } else {
          return Placeholder();
        }
      }) ,
    );
  }
}

class RecorderPage extends StatefulWidget {
  const RecorderPage({ super.key }); 

  @override
  State<RecorderPage> createState() => _RecorderPage();
}

class _RecorderPage extends State<RecorderPage> {
  bool showPlayer = false;
  String? audioPath;

  @override
  void initState() {
    showPlayer = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Recorder(
          onStop: (path) {
            if (kDebugMode) print('Recorded file path: $path');
            setState(() {
              audioPath = path;
              showPlayer = true;
            });
          },
        ),
      ),
    );
  }
}