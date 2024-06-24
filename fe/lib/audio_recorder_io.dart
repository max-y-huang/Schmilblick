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

    const numberOfSamples = 2048;
    final hannWindow = hann(numberOfSamples);

    final stream = await recorder.startStream(config);

    stream.listen(
      (data) {
        // Convert the bytes into a 16 bit integer PCM array as convention
        final rawListIntPCM =
            recorder.convertBytesToInt16(Uint8List.fromList(data));

        // convert the list to a double
        final rawListDoublePCM =
            rawListIntPCM.map((i) => i.toDouble()).toList();


        // windowing operation
        var sciListDoublePCM = Array(rawListDoublePCM);
        var windowedPCM = sciListDoublePCM * hannWindow;

        // Perform FFT on the complex field
        var complexArray = arrayToComplexArray(windowedPCM);
        var fftResult = fft(complexArray, n: numberOfSamples);

        // Obtain the FFT result, plot on Octave
        var absFFTResult = arrayComplexAbs(fftResult);

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
