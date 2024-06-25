import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
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
  Uint8List? _pdfBytes;
  late final PDFViewController _pdfViewController;
  late int? _pageCount;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    setFile();
  }

  void setFile() async {
    // TODO: Turn the file into a backend call. For now, as proof of concept
    // we'll use this file for now.
    final file = await rootBundle.load('assets/joplin-scott-the-entertainer.pdf');
    setState(() {
      _pdfBytes = file.buffer.asUint8List();
    });
  }

  Future<void> goToRandomPagePerSecond(PDFViewController pdfViewController) async {
    var rng = Random();
    _pdfViewController = pdfViewController;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // TODO: Replace this function and comment. As proof of concept, you
      // can programmatically change the page with the PDFViewController
      _pageCount = await _pdfViewController.getPageCount();
      if (_pageCount != null && _pageCount! > 0) {
        final page = rng.nextInt(_pageCount!);
        await _pdfViewController.setPage(page);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: _pdfBytes != null ? PDFView(
        pdfData: _pdfBytes!,
        swipeHorizontal: true,
        onViewCreated: goToRandomPagePerSecond,
      ) : Placeholder(),
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