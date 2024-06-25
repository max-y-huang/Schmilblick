import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  @override
  void initState() {
    super.initState();
    setFile();
  }

  void setFile() async {
    // TODO: Turn the file into a backend call. For now, as proof of concept
    // we'll use this file for now.
    final file = await rootBundle.load('assets/happy_birthday.pdf');
    setState(() {
      _pdfBytes = file.buffer.asUint8List();
    });
  }

  void goToLastPage() async {
    // TODO: Remove this comment. As proof of concept, you
    // can programmatically change the page with the PDFViewController
    final pageCount = await _pdfViewController.getPageCount();
    if (pageCount != null) {
      await _pdfViewController.setPage(pageCount - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: _pdfBytes != null ? PDFView(
        pdfData: _pdfBytes!,
        swipeHorizontal: true,
        onViewCreated: (PDFViewController pdfViewController) {
          _pdfViewController = pdfViewController;
          goToLastPage();
        },
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