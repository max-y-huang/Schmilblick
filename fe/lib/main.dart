import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_turner/widgets/continuous_score_sheet.dart';
import 'package:smart_turner/widgets/paged_score_sheet.dart';
import 'package:smart_turner/widgets/score_sheet.dart';
import 'audio_recorder.dart';
import 'compiled_mxl_model.dart';

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
    CompiledMxl compiledMxl = Provider.of<CompiledMxl>(context, listen: false);
    await compiledMxl.getCompiledMxlAsMap();
  }

  @override
  Widget build(BuildContext context) {
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
