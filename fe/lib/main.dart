import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'audio_recorder.dart';

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
      home: const PagedScoreSheet(),
    );
  }
}

class PagedScoreSheet extends StatefulWidget {
  const PagedScoreSheet({super.key});

  @override
  State<PagedScoreSheet> createState() => _PagedScoreSheetState();
}

class _PagedScoreSheetState extends State<PagedScoreSheet> {
  // When running this app, use the url provided by localhost.run
  final uri = "http://localhost:4000"; // TODO: We will need to remove this at some point
  final score = "emerald_moonlight";
  late final Future<Uint8List> _pdfBytes;
  late final PDFViewController _pdfViewController;
  late final List<int> _pageTable;

  int _randomMeasure = 0;
  final Random rand = Random();

  @override
  void initState() {
    super.initState();
    _extractCompiledMxlInformation();
    _getFile(); 
  }

  void _getFile() async {
    // TODO: Turn the file into a backend call.
    final pdfBytes = rootBundle.load('assets/$score.pdf').then((file) => file.buffer.asUint8List());
    setState(() {
      _pdfBytes = pdfBytes;
    });
  }

  Future<http.Response> _compileMxl() async {
    final request = http.MultipartRequest('POST', Uri.parse('$uri/compile-mxl'));

    final musicxmlBytes = (await rootBundle.load('assets/$score.mxl')).buffer.asUint8List();
    request.files.add(http.MultipartFile.fromBytes('file', musicxmlBytes, filename: score));

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
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                jumpToMeasure(_randomMeasure);
                setState(() {
                  _randomMeasure = rand.nextInt(_pageTable.length);
                });
              },
              label: Text(
                '${_randomMeasure + 1}',
                style: const TextStyle(
                  fontSize: 60.0,
                )
              ),
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