import 'dart:io';
import 'dart:core';
import 'dart:typed_data';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:record/record.dart';

import 'package:fftea/fftea.dart';
import 'package:fftea/impl.dart';

class Tuple<T, U> {
  T x;
  U y;
  Tuple(this.x, this.y);
}

double twelfthRootOf2 = pow(2, 1.0 / 12).toDouble();

double freqForNote(String? baseNote, int noteIndex) {
  double A4 = 440.0;

  Map<String, double> baseNotesFreq = {
    "A2": A4 / 4,
    "A3": A4 / 2,
    "A4": A4,
    "A5": A4 * 2,
    "A6": A4 * 4
  };

  Map<String, double> scaleNotes = {
    "C": -9.0,
    "C#": -8.0,
    "D": -7.0,
    "D#": -6.0,
    "E": -5.0,
    "F": -4.0,
    "F#": -3.0,
    "G": -2.0,
    "G#": -1.0,
    "A": 1.0,
    "A#": 2.0,
    "B": 3.0,
    "Cn": 4.0
  };

  List<int> scaleNotesIndex = List<int>.filled(14, 0);

  for (int i = -9; i < 5; i++) {
    scaleNotesIndex[i + 9] = i;
  }

  int noteIndexValue = scaleNotesIndex[noteIndex];

  double? freq0 = baseNotesFreq[baseNote];

  double freq = freq0! * pow(twelfthRootOf2, noteIndexValue).toDouble();

  return freq;
}

List<Tuple<String, double>> getAllNotesFreq() {
  List<Tuple<String, double>> orderedNoteFreq =
      List<Tuple<String, double>>.empty(growable: true);
  List<String> orderedNotes = [
    "C",
    "C#",
    "D",
    "D#",
    "E",
    "F",
    "F#",
    "G",
    "G#",
    "A",
    "A#",
    "B"
  ];

  for (int octaveIndex = 2; octaveIndex < 7; octaveIndex++) {
    String baseNote = "A${octaveIndex}";
    for (int noteIndex = 0; noteIndex < 12; noteIndex++) {
      double noteFrequency = freqForNote(baseNote, noteIndex);
      String noteName = "${orderedNotes[noteIndex]}$octaveIndex";
      orderedNoteFreq.add(Tuple(noteName, noteFrequency));
    }
  }

  return orderedNoteFreq;
}

List<Tuple<String, double>> orderedNoteFreq = getAllNotesFreq();

mixin AudioRecorderMixin {
  final numberOfFFTBins = 8192;
  final sampleRate = 10000;

  Future<void> recordFile(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath();

    await recorder.start(config, path: path);
  }

  List<double> findPeaks(List<double> arr, int threshold) {
    var N = arr.length - 2;
    var ix = List<double>.empty(growable: true);
    var ax = List<double>.empty(growable: true);

    for (int i = 1; i < N; i++) {
      if (arr[i - 1] <= arr[i] && arr[i] >= arr[i + 1] && arr[i] > threshold) {
        ix.add(i.toDouble());
        ax.add(arr[i].toDouble());
      }
    }

    return ix;
  }

  List<double> implementBandPassFilter(List<double> FFTData, int sampleRate,
      int numberOfBins, int lowerFreq, int higherFreq) {
    List<double> filteredFFTData = FFTData;
    double fftResolution = sampleRate / numberOfBins;
    print("FFT resolution: ${fftResolution}");
    int lowerBin = lowerFreq ~/ fftResolution;
    int higherBin = higherFreq ~/ fftResolution;

    print("Lower bin: ${lowerBin}");
    print("Higher bin: ${higherBin}");
    for (int i = 0; i < FFTData.length; i++) {
      if (i < lowerBin || i > higherBin) {
        filteredFFTData[i] = 0;
      }
    }

    return filteredFFTData;
  }

  List<double> hanningFunction(int size) {
    List<double> result = List<double>.filled(size, 0);
    for (int i = 0; i < result.length; i++) {
      result[i] = 0.5 - 0.5 * cos((2 * pi * i) / (size - 1));
    }
    return result;
  }

  double rmsSignalThreshold(List<double> chunk) {
    double sum = 0;
    for (int i = 0; i < chunk.length; i++) {
      sum += pow(chunk[i], 2).toDouble();
    }
    double mean = sum / chunk.length;
    print("Mean: $mean");
    return sqrt(mean);
  }

  List<double> downSampleFunc(List<double> X, int decimation, int lengthOfRet) {
    // when you downsample, you simply take the ith sample in the original array
    List<double> retX = List<double>.filled(lengthOfRet, 0);
    for (int i = 0; i < lengthOfRet; i++) {
      retX[i] = X[i * decimation];
    }

    return retX;
  }

  double noteThresholdScaledByHPS(double buffer_rms) {
    double noteThreshold = 500 * (4 / 0.090) * buffer_rms;
    return noteThreshold;
  }

  List<int> argWhere(List<double> X, double threshold) {
    List<int> retArgs = List<int>.filled(X.length, 0);

    int numArgsAdded = 0;
    for (int i = 0; i < X.length; i++) {
      if (X[i] > threshold) {
        retArgs[numArgsAdded] = i;
        numArgsAdded += 1;
      }
    }
    return retArgs.sublist(0, numArgsAdded);
  }

  List<double> normalizedData(List<double> X) {
    List<double> retData = List<double>.filled(X.length, 0);
    for (int i = 0; i < retData.length; i++) {
      retData[i] = X[i] / 32768;
    }
    return retData;
  }

  String findNearestNote(
      List<Tuple<String, double>> orderedNoteFreq, int freq) {
    String finalNoteName = "note_not_found";
    double lastDistance = 1000000.0;
    for (int i = 0; i < orderedNoteFreq.length; i++) {
      double currentDistance = (orderedNoteFreq[i].y - freq).abs();
      if (currentDistance < lastDistance) {
        lastDistance = currentDistance;
        finalNoteName = orderedNoteFreq[i].x;
      } else if (currentDistance > lastDistance) {
        break;
      }
    }
    return finalNoteName;
  }

  List<Tuple<int, double>> pitchSpectralHPS(List<double> X, double rms) {
    int iOrder = 4;
    print("Length of X: ${X.length}");
    int finalSizeOfAFHPS = ((numberOfFFTBins / 2) - 1) ~/ iOrder;
    print("Final size of AFHPS: $finalSizeOfAFHPS");
    double fMin = 65.41;

    int kMin = (fMin / sampleRate * 2 * (X.length - 1)).round();
    print("kMin given: $kMin");

    List<double> afHps = X.sublist(0, finalSizeOfAFHPS);

    for (int i = 1; i < iOrder; i++) {
      List<double> X_d = downSampleFunc(X, i + 1, finalSizeOfAFHPS);

      for (int j = 0; j < finalSizeOfAFHPS; j++) {
        afHps[j] = afHps[j] * X_d[j];
      }
    }

    // print("afHPS after: $afHps");
    double noteThreshold = noteThresholdScaledByHPS(rms);

    // print("AFHPS: ${afHps}");
    List<double> rawFreqValues = afHps.sublist(kMin);
    List<int> allFreqs = argWhere(rawFreqValues, noteThreshold);

    List<int> freqsOut = List<int>.filled(allFreqs.length, 0);

    for (int i = 0; i < freqsOut.length; i++) {
      freqsOut[i] =
          ((allFreqs[i] + kMin) / (X.length - 1) * sampleRate / 2).toInt();
    }

    print("All frequencies: $allFreqs");
    print("Frequency out: $freqsOut");

    List<Tuple<int, double>> freqsOutTmp =
        List<Tuple<int, double>>.empty(growable: true);

    for (int i = 0; i < allFreqs.length; i++) {
      Tuple<int, double> indexValue = Tuple(freqsOut[i], rawFreqValues[i]);
      freqsOutTmp.add(indexValue);
    }

    return freqsOutTmp;
    // List<int> allFreqs = argWhere(afHps.sublist(kMin), noteThreshold);
  }

  Future<void> recordStream(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath();
    final file = File(path);

    final stream = await recorder.startStream(config);

    final stopWatch = Stopwatch();

    List<int>? primaryDataBuffer;
    List<int>? secondaryDataBuffer;
    int numBuffers = 2;

    Radix2FFT fftObj = Radix2FFT(numberOfFFTBins);

    int flag = 1;

    stream.listen(
      (data) {
        stopWatch.start();
        // Convert the bytes into a 16 bit integer PCM array as convention
        var rawListIntPCM;

        if (flag == 1) {
          primaryDataBuffer =
              recorder.convertBytesToInt16(Uint8List.fromList(data));
          rawListIntPCM = primaryDataBuffer;
        } else {
          secondaryDataBuffer =
              recorder.convertBytesToInt16(Uint8List.fromList(data));
          rawListIntPCM = secondaryDataBuffer;
        }

        flag = (flag + 1) % numBuffers;

        var windowedResult = List<double>.filled(rawListIntPCM.length, 0);

        var hann = hanningFunction(rawListIntPCM.length);

        for (int i = 0; i < rawListIntPCM.length; i++) {
          windowedResult[i] = rawListIntPCM[i].toDouble() / 32768 * hann[i];
        }

        var fftList = List<double>.filled(numberOfFFTBins, 0);

        for (int i = 0; i < windowedResult.length; i++) {
          fftList[i] = windowedResult[i].toDouble();
        }

        file.writeAsStringSync(fftList.toString(), mode: FileMode.append);

        Float64List FFTResult =
            fftObj.realFft(fftList).discardConjugates().magnitudes();

        List<double> FFTFiltered = implementBandPassFilter(
            FFTResult, sampleRate, numberOfFFTBins, 50, 4500);

        double rmsThreshold = rmsSignalThreshold(windowedResult);

        print("RMS Threshold: $rmsThreshold");
        // print("Peaks: $peaks");

        List<Tuple> pHPS = pitchSpectralHPS(FFTFiltered, rmsThreshold);

        for (int i = 0; i < pHPS.length; i++) {
          String noteName = findNearestNote(orderedNoteFreq, pHPS[i].x);
          print(
              "=> Freq: ${pHPS[i].x}  Hz value: ${pHPS[i].y}  Note name: $noteName");
        }
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
