import 'audio_matching.dart';

// Convert output from /compile-mxl endpoint to two different arrays:
// `intervals` and `measureNumbers`. The former contains the pitch differences
// between each note and the note that comes after it. The latter contains the
// measure number corresponding to each note/index.
List<dynamic> processMxl(Map<String, dynamic> compiledMxlOutput) {
  final parts = compiledMxlOutput["parts"] as Map<String, dynamic>;
  final firstPart = parts.keys.first;
  final notes = parts[firstPart]["notes"] as List<dynamic>;
  final List<int> pitches = notes.map((note) => note["pitch"] as int).toList();
  final List<int> intervals = convertPitchesToIntervals(pitches);
  final List<int> measureNumbers =
      notes.map((note) => note["measure"] as int).toList();
  return [intervals, measureNumbers];
}

// Convert an array of pitches to an array of pitch differences between each
// note and the note that comes after it.
List<int> convertPitchesToIntervals(List<int> pitches) {
  return List<int>.generate(
      pitches.length - 1, (i) => pitches[i + 1] - pitches[i]);
}

// Return the array of pitch differences for the audio input
List<int> processInput(List<dynamic> audioStream) {
  // "Collapse" consecutive identical notes into a single note
  final List<int> inputCollapsed = audioStream.fold([], (acc, cur) {
    if (cur.length == 0) {
      acc.add(-1);
      return acc;
    }

    if (acc.isEmpty) {
      return [cur[0]];
    }

    if (acc.last == cur[0]) {
      return acc;
    }

    acc.add(cur[0]);
    return acc;
  });

  // Remove the '-1' elements from inputCollapsed
  final List<int> inputPitches = inputCollapsed.fold([], (acc, cur) {
    if (cur == -1) {
      return acc;
    } else {
      acc.add(cur);
      return acc;
    }
  });

  if (inputPitches.isEmpty) return [];
  var intervals = convertPitchesToIntervals(inputPitches);
  return intervals;
}

class Slice {
  final List<int> intervals;
  // measureNumber for the last note of the last interval in `this.intervals`
  final int measureNumber;
  Slice(this.intervals, this.measureNumber);
}

List<Slice> getNoteIntervalSlices(
    List<int> noteIntervals, List<int> measureNumbers, int sliceSize) {
  final int len = noteIntervals.length;
  List<Slice> slices = List<Slice>.generate(
      (len - sliceSize),
      (sliceStartIndex) => Slice(
          noteIntervals.sublist(sliceStartIndex, sliceStartIndex + sliceSize),
          measureNumbers[sliceStartIndex + sliceSize]));

  return slices;
}

List<Slice> getAllSlices(List<int> mxlIntervals, List<int> measureNumbers,
    int sliceSize, int buffer) {
  List<Slice> dstSlices = [];
  for (int i = sliceSize - buffer; i <= sliceSize + buffer; i++) {
    if (i <= 0) continue;
    dstSlices.addAll(getNoteIntervalSlices(mxlIntervals, measureNumbers, i));
  }
  return dstSlices;
}

int getCurrentMeasure(List<Slice> dstSlices, List<int> srcInterval) {
  int closestSliceMeasure = -1;
  int minDist = -1;
  for (final slice in dstSlices) {
    final int dist = contourMatching(srcInterval, slice.intervals);
    if (dist < minDist || minDist == -1) {
      minDist = dist;
      closestSliceMeasure = slice.measureNumber;
    }
    // if (dist < 50) {
    //   print('----------');
    //   print(srcInterval);
    //   print(slice.intervals);
    //   print('$dist');
    // }
  }
  return closestSliceMeasure;
}
