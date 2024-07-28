import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_turner/uploaded_files_model.dart';
import 'package:provider/provider.dart';
import 'package:smart_turner/backend_helpers.dart';
import 'package:smart_turner/backend_model.dart';
import 'package:smart_turner/uploaded_files_model.dart';
import 'package:smart_turner/widgets/continuous_score_sheet.dart';
import 'package:smart_turner/widgets/paged_score_sheet.dart';

enum ScoreSheetMode {
  paged,
  continuous,
}

class ScoreSheetDisplay extends StatefulWidget {
  const ScoreSheetDisplay({super.key});

  @override
  State<ScoreSheetDisplay> createState() => _ScoreSheetDisplayState();
}

class _ScoreSheetDisplayState extends State<ScoreSheetDisplay> {
  ScoreSheetMode mode = ScoreSheetMode.paged;
  late Future<void> _backendFuture;
  
  Future<void> getCompiledMxlAsMap() async {
    final uploadedFiles = Provider.of<UploadedFiles>(context, listen: false);
    final backendResults = Provider.of<BackendResults>(context, listen: false);

    final mxlFile = uploadedFiles.mxlFile;
    final fileBytes = mxlFile!.bytes!;
    final fileName = mxlFile.name;

    final response = await compileMxl(fileBytes, fileName);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    
    backendResults.compiledMxlOutput = jsonBody;
  }

  Future<void> getSvgBytesPerOrientation() async {
    final uploadedFiles = Provider.of<UploadedFiles>(context, listen: false);
    final backendResults = Provider.of<BackendResults>(context, listen: false);

    final mxlFile = uploadedFiles.mxlFile;
    final fileBytes = mxlFile!.bytes!;
    final fileName = mxlFile.name;

    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    Size size = view.physicalSize / view.devicePixelRatio;

    final width = size.width.toInt();
    final height = size.height.toInt();

    final minDimension = min(width, height);
    final maxDimension = max(width, height);

    Map<Orientation, int> orientationWidth = {
      Orientation.portrait: minDimension,
      Orientation.landscape: maxDimension,
    };

    for (final orientation in Orientation.values) {
      final width = orientationWidth[orientation]!;
      final response = await mxlToSvg(fileBytes, fileName, width);
      final svgBody = response.bodyBytes;
      backendResults.addMusicSvgFile(orientation, svgBody);
    }
  }

  Future<void> _callBackends() async {
    await Future.wait([getCompiledMxlAsMap(), getSvgBytesPerOrientation()]);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    setState(() {
      _backendFuture =  _callBackends();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _backendFuture,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return Scaffold(
            body: IndexedStack(
              index: mode.index,
              children: [
                PagedScoreSheet(),
                ContinuousScoreSheet(),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              child: FilledButton(
                child: mode == ScoreSheetMode.paged
                    ? Text('Paged', style: TextStyle(fontSize: 30))
                    : Text('Continuous', style: TextStyle(fontSize: 30)),
                onPressed: () {
                  if (mode == ScoreSheetMode.paged) {
                    setState(() {
                      mode = ScoreSheetMode.continuous;
                    });
                  } else {
                    setState(() {
                      mode = ScoreSheetMode.paged;
                    });
                  }
                },
              ),
            ),
          );
        }
      }
    );
  }
}
