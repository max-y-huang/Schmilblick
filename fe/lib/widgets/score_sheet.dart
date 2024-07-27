import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
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
