import 'dart:io';
import 'dart:core';
import 'dart:typed_data';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:record/record.dart';

// scidart package used for preprocessing functions...

import 'package:scidart/src/numdart/numdart.dart';
import 'package:scidart/src/scidart/signal/signal.dart';
import 'package:scidart/src/scidart/fftpack/fft/fft.dart';
import 'package:scidart/src/scidart/fftpack/rfft/rfft.dart';
import 'package:scidart/src/scidart/fftpack/rfft/rifft.dart';

mixin AudioRecorderMixin {
  Future<void> recordFile(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath();

    await recorder.start(config, path: path);
  }

  List<double> normalizeAudio(List<int> samples) {
    List<double> normalized = [];
    for (int sample in samples) {
      double normalizedSample = sample / 32768.0;
      normalized.add(normalizedSample);
    }

    return normalized;
  }

  double computeYinPitch(List<double> audioBuffer, int sampleRate) {
    int tauEstimate = 0;
    double minThreshold = 0.1; // Adjust threshold as needed
    int bufferSize = audioBuffer.length;

    // Compute difference function
    List<double> difference = List.filled(bufferSize, 0);
    for (int tau = 1; tau < bufferSize; tau++) {
      for (int i = 0; i < bufferSize - tau; i++) {
        difference[tau] += (audioBuffer[i] - audioBuffer[i + tau]).abs();
      }
    }

    // Compute cumulative mean normalized difference function (CMND)
    List<double> cumulativeMean = List.filled(bufferSize, 0);
    cumulativeMean[1] = 1.0; // Avoid division by zero
    double runningSum = 0;
    for (int tau = 1; tau < bufferSize; tau++) {
      runningSum += difference[tau];
      cumulativeMean[tau] = difference[tau] / (runningSum / tau);
    }

    // Find minimum tau for which CMND is below threshold
    for (int tau = 2; tau < bufferSize; tau++) {
      if (cumulativeMean[tau] < minThreshold) {
        tauEstimate = tau;
        break;
      }
    }

    // Calculate pitch (in Hz)
    double pitchInHz = sampleRate / tauEstimate.toDouble();
    return pitchInHz;
  }

  String pitchToNote(double pitchInHz) {
    // Implement logic to map pitch frequencies to musical notes
    // Example implementation
    print("Pitch in hz: $pitchInHz");
    List<String> notes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];
    int noteIndex = (12 * (log(pitchInHz / 440) / log(2))).round() % 12;
    print("Note index given: $noteIndex\r");
    return notes[noteIndex];
  }

  void processAudioFrame(List<double> audioFrame, int sampleRate) {
    double pitch = computeYinPitch(audioFrame, sampleRate);
    String detectedNote = pitchToNote(pitch);
    print('Detected note: $detectedNote\r');
  }

  Future<void> recordStream(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath();
    final file = File(path);

    const numberOfFFTBins = 2048;
    const thresholdFFT =
        200000; // set the threshold as a base, then test the different harmonics

    // band pass filter settings (in Hz)
    const fftResolution = 10000 / numberOfFFTBins;

    const lowBoundFilter = 50;
    const highBoundFilter = 4100;

    final hannWindow = hann(numberOfFFTBins);

    final stream = await recorder.startStream(config);

    final stopWatch = Stopwatch();

    stream.listen(
      (data) {
        stopWatch.start();
        // Convert the bytes into a 16 bit integer PCM array as convention
        final rawListIntPCM =
            recorder.convertBytesToInt16(Uint8List.fromList(data));

        // print("Size of list: ${rawListIntPCM.length}");

        var fftList = List<double>.filled(numberOfFFTBins, 0);

        for (int i = 0; i < rawListIntPCM.length; i++) {
          fftList[i] = rawListIntPCM[i].toDouble();
        }

        // var normalizedAudioList = normalizeAudio(rawListIntPCM);

        // processAudioFrame(normalizedAudioList, 20000);
        // YIN ALGORITHM

        // windowing operation
        var sciListDoublePCM = Array(fftList);
        var windowedPCM = sciListDoublePCM * hannWindow;

        // Perform FFT on the complex field
        // var complexArray = arrayToComplexArray(windowedPCM);
        // var fftResult = fft(complexArray, n: numberOfFFTBins);

        var absFFTResult =
            arrayComplexAbs(rfft(windowedPCM, n: numberOfFFTBins));

        // Obtain the FFT result, plot on Octave
        // var absFFTResult = arrayComplexAbs(fftResult);

        for (var i = 0; i < absFFTResult.length; i++) {
          if (i * fftResolution < lowBoundFilter ||
              i * fftResolution > highBoundFilter) {
            // print("I index: $i");
            // absFFTResult[i] = Complex(real: 0, imaginary: 0);
            absFFTResult[i] = 0;
          }
        }

        // var ifftResult = rifft(absFFTResult);

        // print("Result of ifft result: $ifftResult");

        // List<int> preprocessing = [];

        // for (int i = 0; i < ifftResult.length; i++) {
        //   preprocessing.add(ifftResult[i].toInt());
        // }

        // print("Preprocessing array: $preprocessing");
        // var normalizedAudioList = normalizeAudio(preprocessing);

        // processAudioFrame(normalizedAudioList, 10000);
        //---------------------------------------------------------
        //
        // FFT IMPLEMENTATION
        //
        // ---------------------------------------------------------
        // var [bins, mags] = findPeaks(absFFTResult);

        var [bins, mags] =
            findPeaks(absFFTResult, threshold: thresholdFFT.toDouble());

        if (bins.length == 0) {
          print("No new notes detected.");
          return;
        }

        if (bins.length > 6) {
          print("Multiple overtones heard, delaying input signal...");
          return;
        }

        // Choose the lowest peak and determine the fundamental frequency
        var firstPeakBin = bins[0].toInt();
        var firstPeakMag = mags[0].toInt();

        var lowerFirstPeakBin = firstPeakBin - 1;
        var higherFirstPeakBin = firstPeakBin + 1;

        var lowerMagFirstPeakBin = absFFTResult[lowerFirstPeakBin].toDouble();
        var higherMagFirstPeakBin = absFFTResult[higherFirstPeakBin].toDouble();

        print("Lower first peak bin: $lowerFirstPeakBin");
        print("Higher first peak bin: $higherFirstPeakBin");

        print("Bins printed: $bins");
        print("Magnitudes printed: $mags");

        print("Bin below peak: ${absFFTResult[lowerFirstPeakBin.toInt()]}");
        print("Bin above peak: ${absFFTResult[higherFirstPeakBin.toInt()]}");

        // Interpolation time!

        var H = sqrt(firstPeakMag);
        var L = lowerMagFirstPeakBin < higherMagFirstPeakBin
            ? sqrt(lowerMagFirstPeakBin)
            : sqrt(higherMagFirstPeakBin);
        var D = H / (L + H);

        print("First peak bin: $firstPeakBin");
        print("FFT Resolution: $fftResolution");
        var freq = (firstPeakBin + D) * fftResolution;

        print("H index: $H");
        print("L index: $L");
        print("D index: $D");
        print("Estimated frequency: $freq");

        // stopWatch.stop();
        // print("Elapsed time: ${stopWatch.elapsedMilliseconds}");
        // stopWatch.reset();
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
