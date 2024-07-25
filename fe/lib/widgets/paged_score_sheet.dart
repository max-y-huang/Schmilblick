import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import 'package:smart_turner/compiled_mxl_model.dart';

class PagedScoreSheet extends StatefulWidget {
  const PagedScoreSheet({super.key});

  @override
  State<PagedScoreSheet> createState() => _PagedScoreSheetState();
}

class _PagedScoreSheetState extends State<PagedScoreSheet> {
  // When running this app, use the url provided by localhost.run
  final uri =
      "http://localhost:4000"; // TODO: We will need to remove this at some point
  final score = "emerald_moonlight";
  late final Future<Uint8List> _pdfBytes;

  late final PDFViewController _pdfViewController;
  late final List<int> _pageTable;

  int _randomMeasure = 0;
  final Random rand = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractCompiledMxlInformation();
    });

    _getFile();
  }

  void _getFile() async {
    // TODO: Turn the file into a backend call.
    final pdfBytes = rootBundle
        .load('assets/$score.pdf')
        .then((file) => file.buffer.asUint8List());

    setState(() {
      _pdfBytes = pdfBytes;
    });
  }

  void _extractCompiledMxlInformation() async {
    CompiledMxl compiledMxl = Provider.of<CompiledMxl>(context, listen: false);
    final resJson = compiledMxl.compiledMxlOutput;
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
        child: FutureBuilder(
            future: _pdfBytes,
            builder: (buildContext, snapshot) {
              if (snapshot.hasData) {
                return Scaffold(
                    body: PDFView(
                      pdfData: snapshot.data,
                      swipeHorizontal: true,
                      onViewCreated: _initializeController,
                    ),
                    // TODO: Remove this button (testing purposes only)
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () {
                        jumpToMeasure(_randomMeasure);
                        setState(() {
                          _randomMeasure = rand.nextInt(_pageTable.length);
                        });
                      },
                      label: Text('${_randomMeasure + 1}',
                          style: const TextStyle(
                            fontSize: 60.0,
                          )),
                    ));
              } else {
                return Placeholder();
              }
            }));
  }
}
