import 'package:smart_turner/backend_helpers.dart';

Future<List<int>> getNoteIntervals() async {
  final resJson = await getCompiledMxlAsMap();
  final parts = resJson["parts"] as Map<String, dynamic>;
  final firstPart = parts.keys.first;
  final notes = parts[firstPart]["notes"] as List<dynamic>;
  final pitches = notes.map((note) => note["pitch"]).toList();
  final intervals = List<int>.generate(
      pitches.length - 1, (i) => pitches[i + 1] - pitches[i]);
  return intervals;
}
