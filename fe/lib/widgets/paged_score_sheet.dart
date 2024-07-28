import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import 'package:smart_turner/uploaded_files_model.dart';
import 'package:smart_turner/backend_model.dart';
import 'package:smart_turner/uploaded_files_model.dart';

class PagedScoreSheet extends StatefulWidget {
  const PagedScoreSheet({super.key});

  @override
  State<PagedScoreSheet> createState() => _PagedScoreSheetState();
}

class _PagedScoreSheetState extends State<PagedScoreSheet> {
  // When running this app, use the url provided by localhost.run
  late final PDFViewController _pdfViewController;
  late List<int> _pageTable;

  int _randomMeasure = 0;
  final Random rand = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractCompiledMxlInformation();
    });
  }

  // This widget is wrapped in a `Consumer<CompiledMxl>(...)`
  //  so it subscribed to the CompiledMxl model. If the
  //  CompiledMxl changes, we call _extractCompiledMxlInformation()
  //  to build a new _pageTable for the new sheet music
  @override
  void didChangeDependencies() {
    print("Dependencies changed for pdf view!");
    super.didChangeDependencies();
    _extractCompiledMxlInformation();
  }

  void _extractCompiledMxlInformation() async {
    final backendResults = Provider.of<BackendResults>(context, listen: false);
    final resJson = backendResults.compiledMxlOutput;
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
    return Consumer<UploadedFiles>(builder: (context, uploadedFiles, child) {
      final pdfBytes = uploadedFiles.pdfFile?.bytes;
      return Container(
          color: Colors.white,
          child: pdfBytes == null ? Placeholder() :
            Scaffold(
              body: PDFView(
                pdfData: pdfBytes,
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
              ))
      );
    });
  }
}
