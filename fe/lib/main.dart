import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'audio_recorder.dart';
import 'package:smart_turner/widgets/continuous_score_sheet.dart';
import 'package:smart_turner/widgets/paged_score_sheet.dart';

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
