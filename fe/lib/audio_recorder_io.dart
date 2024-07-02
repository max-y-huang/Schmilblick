import 'dart:io';
import 'dart:core';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:record/record.dart';

// scidart package used for preprocessing functions...

import 'package:scidart/src/numdart/numdart.dart';
import 'package:scidart/src/scidart/signal/signal.dart';
import 'package:scidart/src/scidart/fftpack/fft/fft.dart';
import 'package:scidart/src/scidart/fftpack/rfft/rfft.dart';

mixin AudioRecorderMixin {
  Future<void> recordFile(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath();

    await recorder.start(config, path: path);
  }

  Future<void> recordStream(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath();
    final file = File(path);

    const numberOfSamples = 2048;
    const thresholdFFT =
        150000; // set the threshold as a base, then test the different harmonics

    // band pass filter settings (in Hz)
    const lowerFilter = 50;
    const higherFilter = 4100;
    const fftResolution = 10;
    const errorBoundForInterpol = 2;

    final hannWindow = hann(numberOfSamples);

    final stream = await recorder.startStream(config);

    final stopWatch = Stopwatch();

    stream.listen(
      (data) {
        stopWatch.start();
        // Convert the bytes into a 16 bit integer PCM array as convention
        final rawListIntPCM =
            recorder.convertBytesToInt16(Uint8List.fromList(data));

        // TODO: first of all, convert to a larger array; we want a larger buffer to get a higher resolution
        // Then afterwards, perform a harmonic product spectrum in the actual streaming
        // convert the list to a double
        final rawListDoublePCM =
            rawListIntPCM.map((i) => i.toDouble()).toList();

        // windowing operation
        var sciListDoublePCM = Array(rawListDoublePCM);
        var windowedPCM = sciListDoublePCM * hannWindow;

        // Perform FFT on the complex field
        var fftResult = rfft(windowedPCM, n: numberOfSamples);

        // Obtain the FFT result, plot on Octave
        var absFFTResult = arrayComplexAbs(fftResult);

        for (var i = 0; i < absFFTResult.length; i++) {
          if (i < lowerFilter / fftResolution ||
              i > higherFilter / fftResolution) {
            absFFTResult[i] = 0;
          }
        }

        var [bins, mags] = findPeaks(absFFTResult);

        // Check the length of the FFT peaks, if it's over a certain length, it's presumed that percusiveness
        // is happening (the spectrum is effectively a mess)

        print("Bins printed: $bins");
        print("Magnitudes printed: $mags");

        // if the bins are somewhat evenly spaced (give some error for x-1 <= x <= x+1), then we don't want to report the peaks yet
        // if (bins.length >= 8) {
        //   print("Bins surpassed the length, will return later...");
        //   stopWatch.stop();
        //   print("Elapsed time: ${stopWatch.elapsedMilliseconds}");
        //   stopWatch.reset();
        //   return;
        // }

        // if (bins.length == 0) {
        //   return;
        // }

        // if (bins.length == 1) {
        //   print("Bins selected: ${bins[0]}");
        //   print("Amplitude detected: ${mags[0]}");
        //   return;
        // }

        // var differenceMach = 0;

        // // get the difference between the bins, and assess if they would be the same
        // // for (int i = 1; i < bins.length - 1; i++) {
        // //   if (differenceMach == ) differenceMach = mags[i] - mags[i - 1];
        // // }

        // print("Difference between bins: $differenceMach");

        // for (int i = 0; i < bins.length - 1; i++) {
        //   // find if it's within some error of the frequency bin
        //   if (-1 * errorBoundForInterpol < differenceMach - bins[i] &&
        //       differenceMach - bins[i] < errorBoundForInterpol) {
        //     print("Bin selected: ${bins[i]}\n Amplitude detected: ${mags[i]}");
        //   }
        // }

        stopWatch.stop();
        print("Elapsed time: ${stopWatch.elapsedMilliseconds}");
        stopWatch.reset();
        // windowed PCM
        // file.writeAsStringSync(absFFTResult.toString(), mode: FileMode.append);
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
