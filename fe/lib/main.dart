import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audio_recorder.dart';
import 'package:smart_turner/widgets/continuous_score_sheet.dart';
import 'package:smart_turner/widgets/paged_score_sheet.dart';
import 'compiled_mxl_model.dart';
import 'audio_matching.dart';
import 'process_notes.dart';

void main() => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CompiledMxl()),
        ],
        child: MyApp(),
      ),
    );

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _compileFuture;

  @override
  void initState() {
    super.initState();
    _compileFuture = _initialize();
  }

  Future<void> _initialize() async {
    final int BUFFER = 5;
    CompiledMxl compiledMxl = Provider.of<CompiledMxl>(context, listen: false);
    await compiledMxl.getCompiledMxlAsMap();
    List<int> src = processInput();
    List<dynamic> processedMxl = processMxl(compiledMxl.compiledMxlOutput);
    List<int> mxlIntervals = processedMxl[0];
    List<int> measureNumbers = processedMxl[1];
    final int sliceSize = src.length;
    List<Slice> dstSlices = [];
    for (int i = sliceSize - BUFFER; i <= sliceSize + BUFFER; i++) {
      dstSlices.addAll(getNoteIntervalSlices(mxlIntervals, measureNumbers, i));
    }

    final int numSlices = dstSlices.length;
    int closestSliceMeasure = -1;
    int minDist = -1;
    for (int i = 0; i < numSlices; ++i) {
      final int dist = contourMatching(src, dstSlices[i].intervals);
      if (dist <= 5) {
        print('-----------');
        print(dist);
        print(src);
        print(dstSlices[i]);
      }
      if (dist < minDist || minDist == -1) {
        minDist = dist;
        closestSliceMeasure = dstSlices[i].measureNumber;
      }
    }
    print('closestSliceMeasure: $closestSliceMeasure');
    //contourMatching
  }

  @override
  Widget build(BuildContext context) {
    //contourMatching(src, dst);
    return FutureBuilder(
        future: _compileFuture,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return MaterialApp(
              title: 'Flutter Demo',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
                useMaterial3: true,
              ),
              home: const PagedScoreSheet(),
            );
          }
        });
  }
}

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

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
