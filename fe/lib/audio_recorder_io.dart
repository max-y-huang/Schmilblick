import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:record/record.dart';

// scidart package used for preprocessing functions...

import 'package:scidart/src/numdart/numdart.dart';
import 'package:scidart/src/scidart/signal/signal.dart';
import 'package:scidart/src/scidart/fftpack/fft/fft.dart';

mixin AudioRecorderMixin {
  Future<void> recordFile(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath();

    await recorder.start(config, path: path);
  }

  Future<void> recordStream(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath();
    final file = File(path);

    final hannWindow = hann(2048);

    final stream = await recorder.startStream(config);

    stream.listen(
      (data) {
        // get from list as uint8 integers first
        final rawListIntPCM =
            recorder.convertBytesToInt16(Uint8List.fromList(data));

        // print("List raw list int PCM: ${rawListIntPCM.length}");

        // convert to a list in double
        final rawListDoublePCM =
            rawListIntPCM.map((i) => i.toDouble()).toList();

        // print("List raw list double PCM: ${rawListDoublePCM.length}");

        // create a new array in scidart
        var sciListDoublePCM = Array(rawListDoublePCM);

        var length = sciListDoublePCM.length;

        print("Length of array: $length");

        var windowedPCM = sciListDoublePCM * hannWindow;

        var complexArray = arrayToComplexArray(windowedPCM);

        var fftResult = fft(complexArray, n: 2048);

        var absFFTResult = arrayComplexAbs(fftResult);

        print("FFT finished");

        // windowed PCM
        // file.writeAsStringSync(windowedPCM.toString(), mode: FileMode.append);
        // file.writeAsStringSync(hannWindow.toString(), mode: FileMode.append);
        // file.writeAsStringSync(rawListIntPCM.toString(), mode: FileMode.append);
        file.writeAsStringSync(absFFTResult.toString(), mode: FileMode.append);
      },
      onDone: () {
        print('End of stream. File written to $path.');
      },
    );
  }

  void downloadWebData(String path) {}

  Future<String> _getPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(
      dir.path,
      'audio_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
  }
}
