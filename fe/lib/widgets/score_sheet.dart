import 'package:flutter/material.dart';
import 'package:smart_turner/widgets/continuous_score_sheet.dart';
import 'package:smart_turner/widgets/paged_score_sheet.dart';
import 'package:smart_turner/process_notes.dart';
import 'dart:async';
import 'package:smart_turner/audio_recorder_io.dart';
import 'package:smart_turner/compiled_mxl_model.dart';
import 'package:provider/provider.dart';

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
  Timer? _timer;
  final int TIMER_PERIOD = 1;

  @override
  void initState() {
    super.initState();
    CompiledMxl compiledMxl = Provider.of<CompiledMxl>(context, listen: false);
    _timer = Timer.periodic(Duration(seconds: TIMER_PERIOD), (Timer timer) {
      List<List<int>> stream = getAudioStream();
      print(stream);
      List<int> src = processInput(stream);
      if (src.isEmpty == false) {
        int curMeasure = getCurrentMeasure(compiledMxl.dstSlices, src);
        print(curMeasure);
      }
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: mode.index,
        children: [
          PagedScoreSheet(),
          Placeholder(),
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
