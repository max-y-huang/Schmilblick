// Convert output from /compile-mxl endpoint to a list
//  where each entry represents the pitch difference
//  between a note and its previous note.
Future<List<int>> getNoteIntervals(
    Map<String, dynamic> compiledMxlOutput) async {
  final parts = compiledMxlOutput["parts"] as Map<String, dynamic>;
  final firstPart = parts.keys.first;
  final notes = parts[firstPart]["notes"] as List<dynamic>;
  final pitches = notes.map((note) => note["pitch"]).toList();
  final intervals = List<int>.generate(
      pitches.length - 1, (i) => pitches[i + 1] - pitches[i]);
  return intervals;
}
