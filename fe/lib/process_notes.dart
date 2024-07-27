// Convert output from /compile-mxl endpoint to a list
//  where each entry represents the pitch difference
//  between a note and its previous note.
List<dynamic> processMxl(Map<String, dynamic> compiledMxlOutput) {
  final parts = compiledMxlOutput["parts"] as Map<String, dynamic>;
  final firstPart = parts.keys.first;
  final notes = parts[firstPart]["notes"] as List<dynamic>;
  final pitches = notes.map((note) => note["pitch"]).toList();
  final List<int> intervals = convertPitchesToIntervals(pitches);
  final List<int> measureNumbers =
      notes.map((note) => note["measure"] as int).toList();
  return [intervals, measureNumbers];
}

List<int> convertPitchesToIntervals(pitches) {
  return List<int>.generate(
      pitches.length - 1, (i) => pitches[i + 1] - pitches[i]);
}

List<int> processInput() {
  final List<dynamic> input001 = [
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [72],
    [72],
    [72],
    [72],
    [72],
    [74],
    [74],
    [74],
    [74],
    [74],
    [76],
    [76],
    [76],
    [76],
    [76],
    [77],
    [77],
    [77],
    [77],
    [77],
    [79],
    [79],
    [79],
    [79],
    [79],
    [81],
    [81],
    [81],
    [81],
    [81],
    [83],
    [83],
    [83],
    [83],
    [],
    [84],
    [84],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [84],
    [84],
    [84],
    [],
    [],
    [83],
    [83],
    [83],
    [83],
    [83],
    [81],
    [81],
    [81],
    [81],
    [81],
    [79],
    [79],
    [79],
    [79],
    [79],
    [77],
    [77],
    [77],
    [77],
    [77],
    [76],
    [76],
    [76],
    [76],
    [76],
    [74],
    [74],
    [74],
    [74],
    [74],
    [72],
    [72],
    [72],
    [72],
    [72],
    [72],
    [72],
    [72],
    [72],
    [72],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    []
  ];
  final List<int> inputMerged = input001.fold([], (acc, cur) {
    if (cur.length == 0) {
      acc.add(-1);
      return acc;
    }

    if (acc.last == cur[0]) {
      return acc;
    }

    acc.add(cur[0]);
    return acc;
  });

  final List<int> inputPitches = inputMerged.fold([], (acc, cur) {
    if (cur == -1) {
      return acc;
    } else {
      acc.add(cur);
      return acc;
    }
  });

  return convertPitchesToIntervals(inputPitches);
}

class Slice {
  final List<int> intervals;
  // measureNumber for the note of the first interval in intervals
  final int measureNumber;
  Slice(this.intervals, this.measureNumber);
}

List<Slice> getNoteIntervalSlices(
    List<int> noteIntervals, List<int> measureNumbers, int sliceSize) {
  final int len = noteIntervals.length;
  List<Slice> slices = List<Slice>.generate(
      (len - sliceSize),
      (i) => Slice(noteIntervals.sublist(i, i + sliceSize),
          measureNumbers[i + sliceSize + 1]));

  return slices;
}
