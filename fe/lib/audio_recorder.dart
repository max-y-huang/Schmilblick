import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:fftea/impl.dart';
import 'package:flutter/material.dart';

import 'package:flutter_sound/flutter_sound.dart';

// temporary fix for getting the RecorderState because we need access to it.
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fftea/fftea.dart';

// import 'audio_recorder_io.dart';

const int tSampleRate = 10000;
typedef _Fn = void Function();

int flag = 0;

int fixedListSize = 8192;
int lowerFrequency = 50;
int higherFrequency = 4500;

double twelfthRootOf2 = pow(2, 1.0 / 12).toDouble();

// two buffers to allow for possible switching
List<double> primaryBuffer = List<double>.filled(fixedListSize, 0);
List<double> secondaryBuffer = List<double>.filled(fixedListSize, 0);

class Tuple<T, U> {
  T x;
  U y;
  Tuple(this.x, this.y);
}

class Recorder extends StatefulWidget {
  final void Function(String path) onStop;

  const Recorder({super.key, required this.onStop});

  @override
  State<Recorder> createState() => _RecorderStateRedo();
}

class _RecorderStateRedo extends State<Recorder> {
  Timer? _timer;
  int _recordDuration = 0;
  FlutterSoundPlayer? _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  RecorderState _mRecorderState = RecorderState.isStopped;
  StreamSubscription? _mRecordingDataSubscription;
  StreamSubscription? _mRecorderSubscription;
  Radix2FFT fftObj = Radix2FFT(fixedListSize);

  final stopWatch = Stopwatch();

  int pos = 0;
  double dbLevel = 0;

  // Recorder State
  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;
  bool _mEnableVoiceProcessing = false;

  bool _mplaybackReady = false;
  String? _mPath;

  Future<void> _openRecorder() async {
    var status = await Permission.microphone.request();
    // if (!status.isGranted) {
    //   print("Microphone permission is not granted!");
    //   throw RecordingPermissionException('Microphone permission not granted');
    // }
    await _mRecorder!.openRecorder();

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    setState(() {
      _mRecorderIsInited = true;
    });
  }

  @override
  void initState() {
    super.initState();
    // Be careful : openAudioSession return a Future.
    // Do not access your FlutterSoundPlayer or FlutterSoundRecorder before the completion of the Future
    init().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });
  }

  Future<void> init() async {
    await _openRecorder();
    _mRecorderSubscription = _mRecorder!.onProgress!.listen((e) {
      setState(() {
        pos = e.duration.inMilliseconds;
        if (e.decibels != null) {
          dbLevel = e.decibels as double;
        }
      });
    });
  }

  void _updateRecordState(RecorderState recordState) {
    setState(() => _mRecorderState = recordState);

    switch (recordState) {
      case RecorderState.isPaused:
        _timer?.cancel();
        break;
      case RecorderState.isRecording:
        _startTimer();
        break;
      case RecorderState.isStopped:
        _timer?.cancel();
        _recordDuration = 0;
        break;
    }
  }

  @override
  void dispose() {
    stopPlayer();
    _mPlayer!.closePlayer();
    _mPlayer = null;

    stopRecorder();
    _mRecorder!.closeRecorder();
    _mRecorder = null;
    super.dispose();
  }

  Future<IOSink> createFile() async {
    var tempDir = await getTemporaryDirectory();
    _mPath = '${tempDir.path}/flutter_sound_example.pcm';
    var outputFile = File(_mPath!);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
    return outputFile.openWrite();
  }

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

    for (int i = 0; i <= 13; i++) {
      scaleNotesIndex[i] = i - 9;
    }

    int noteIndexValue = scaleNotesIndex[noteIndex];

    double? freq0 = baseNotesFreq[baseNote];

    double freq = freq0! * pow(twelfthRootOf2, noteIndex).toDouble();

    return freq;
  }

  List<Tuple> getAllNotesFreq() {
    List<Tuple> orderedNoteFreq = List<Tuple>.empty(growable: true);
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
        String noteName = "${orderedNotes[noteIndex]}_$octaveIndex";
        orderedNoteFreq.add(Tuple(noteName, noteFrequency));
      }
    }

    return orderedNoteFreq;
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

  double rmsSignalThreshold(List<double> fftChunk) {
    double sum = 0;
    for (int i = 0; i < fftChunk.length; i++) {
      sum += pow(fftChunk[i], 2).toDouble();
    }
    double mean = sum / fftChunk.length;

    return sqrt(mean);
  }

  double noteThresholdScaledByHPS(double buffer_rms) {
    double noteThreshold = 1000 * (4 / 0.090) * buffer_rms;
    return noteThreshold;
  }

  // band pass filter necessary to remove extraneous noise
  List<double> implementBandPassFilter(
      List<double> FFTData, int sampleRate, int lowerFreq, int higherFreq) {
    List<double> filteredFFTData = FFTData;
    double fftResolution = sampleRate / (FFTData.length * 2);
    int lowerBin = lowerFreq ~/ fftResolution;
    int higherBin = higherFreq ~/ fftResolution;

    for (int i = 0; i < FFTData.length; i++) {
      if (i < lowerBin || i > higherBin) {
        filteredFFTData[i] = 0;
      }
    }

    return filteredFFTData;
  }

  List<double> performFFT(List<double> streamData) {
    // use Cooley-Turkey algorithm
    // FFT separates into two groups: the reals and the conjugates.
    // Discard the conjugates to get rid of the phase and get the magnitudes.
    // 1. convert the Uint8List into Double

    // print("Stream data length: ${streamData!.length}");
    List<double> streamDataDouble = List<double>.filled(fixedListSize, 0);
    for (int i = 0; i < min(streamData.length, fixedListSize); i++) {
      streamDataDouble[i] = streamData[i];
    }

    // print("Stream data double: ${streamDataDouble.length}");
    // 2. perform the FFT
    return fftObj.realFft(streamDataDouble).discardConjugates().magnitudes();
  }

  List<double> downSampleFunc(List<double> X, int decimation) {
    // when you downsample, you simply take the ith sample in the original array
    int lengthOfRet = X.length ~/ decimation;
    List<double> retX = List<double>.filled(lengthOfRet, 0);
    for (int i = 0; i < retX.length; i++) {
      retX[i] = X[i * decimation];
    }

    return retX;
  }

  List<int> argWhere(List<double> X, double threshold) {
    // TODO: implement function
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

  List<double> where(List<double> X, double threshold) {
    List<double> retArgs = List<double>.filled(X.length, 0);

    int numArgsAdded = 0;
    for (int i = 0; i < X.length; i++) {
      if (X[i] > threshold) {
        retArgs[numArgsAdded] = X[i];
        numArgsAdded += 1;
      }
    }
    return retArgs.sublist(0, numArgsAdded);
  }

  List<Tuple> pitchSpectralHPS(List<double> X, double rms) {
    // get every fourth sample (basically akin to downsampling)
    int iOrder = 4;
    int finalSizeOfAFHPS = fixedListSize ~/ iOrder;
    // print("Final size of AFHPS: $finalSizeOfAFHPS");
    double fMin = 65.41; // frequency for C2 (the lowest we are willing to go)

    int kMin = (fMin / tSampleRate * 2 * (X.length - 1)).round();
    print("kMin given: $kMin");
    List<double> afHps = X.sublist(0, finalSizeOfAFHPS);

    // print("afHPS initially: $afHps");
    // downsample the incoming FFT samples placed within a spectrogram
    for (int i = 1; i < iOrder; i++) {
      // List<double>
      List<double> X_d = downSampleFunc(X, i + 1);
      // print("X_d length: ${X_d.length}");

      for (int i = 0; i < min(afHps.length, X_d.length); i++) {
        afHps[i] = afHps[i] * X_d[i];
      }
    }

    // print("afHPS after: $afHps");

    // // determine the note threshold for the incoming stream
    double noteThreshold = noteThresholdScaledByHPS(rms);

    // print("Note threshold: $noteThreshold");
    List<int> allFreqs = argWhere(afHps.sublist(kMin), noteThreshold);

    // Convert to Hz
    List<int> freqsOut = List<int>.filled(allFreqs.length, 0);

    for (int i = 0; i < freqsOut.length; i++) {
      freqsOut[i] =
          ((allFreqs[i] + kMin) / (X.length - 1) * tSampleRate / 2).toInt();
    }
    // print("allFreqs: $allFreqs");
    // print("Frequency out: $freqsOut");

    List<double> rawFreqValues = afHps.sublist(kMin);

    // print("rawFreqValues: $rawFreqValues");

    List<int> freqIndexesOut = argWhere(rawFreqValues, noteThreshold);
    // print("Freq indexes out: $freqIndexesOut");

    List<Tuple> freqsOutTmp = List<Tuple>.empty(growable: true);

    for (int i = 0; i < freqIndexesOut.length; i++) {
      Tuple indexValue = Tuple(freqIndexesOut[i], rawFreqValues[i]);
      freqsOutTmp.add(indexValue);
    }
    // sample return implementation
    return freqsOutTmp;
  }

  // List<double

  List<double> normalizedList(List<int> pcmData, int maxThreshold) {
    List<double> pcmDataNorm = List<double>.filled(pcmData.length, 0);
    for (int i = 0; i < pcmData.length; i++) {
      pcmDataNorm[i] = pcmData[i] / maxThreshold;
    }
    return pcmDataNorm;
  }

  Future<void> record() async {
    assert(_mRecorderIsInited && _mPlayer!.isStopped);
    var sink = await createFile();
    var recordingDataController = StreamController<Food>();
    _mRecordingDataSubscription =
        recordingDataController.stream.listen((buffer) {
      if (buffer is FoodData) {
        // this is where we will process the PCM data

        // PCM is unsigned, need to convert to signed
        // print("Buffer data: ${buffer.data}");
        stopWatch.start();
        final pcm16 = normalizedList(buffer.data!.buffer.asInt16List(), 32768);

        print("PCM 16: $pcm16");
        print("Min: ${pcm16.reduce(min)}");
        print("Max: ${pcm16.reduce(max)}");

        List<double> windowedHamming = Window.hanning(pcm16.length);
        List<double> windowedResult = List<double>.filled(pcm16.length, 0);

        // // // print("Buffer data: ${buffer.data!.length}");
        for (int i = 0; i < pcm16.length; i++) {
          windowedResult[i] = windowedHamming[i] * pcm16[i];
        }

        // print("Windowed result: $windowedResult");
        // print("--------////---------");

        List<double> fftResult = performFFT(windowedResult);
        // print("FFT Result: $fftResult");
        // print("--------////---------");
        // List<double> fftFiltered = implementBandPassFilter(
        //     fftResult, tSampleRate, lowerFrequency, higherFrequency);
        // print("FFT Filtered: $fftFiltered");
        // print("--------////---------");
        // double rmsThreshold = rmsSignalThreshold(fftFiltered);
        double rmsThreshold = rmsSignalThreshold(fftResult);
        // print("rmsThreshold: $rmsThreshold");
        // print("--------////---------");

        // List<Tuple> pHPS = pitchSpectralHPS(fftFiltered, rmsThreshold);
        List<Tuple> pHPS = pitchSpectralHPS(fftResult, rmsThreshold);

        // List<double> fftFiltered = implementBandPassFilter(
        //     fftResult, tSampleRate, lowerFrequency, higherFrequency);
        // sink.add(buffer.data!);

        // print("Stopwatch elapsed: ${stopWatch.elapsedMilliseconds}");
        stopWatch.reset();
      }
    });
    await _mRecorder!.startRecorder(
      toStream: recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: tSampleRate,
      enableVoiceProcessing: _mEnableVoiceProcessing,
      bufferSize: 10000,
    );
    setState(() {});
    _updateRecordState(_mRecorder!.recorderState);
  }

  Future<void> stopRecorder() async {
    await _mRecorder!.stopRecorder();
    if (_mRecordingDataSubscription != null) {
      await _mRecordingDataSubscription!.cancel();
      _mRecordingDataSubscription = null;
    }
    _mplaybackReady = true;
    _updateRecordState(_mRecorder!.recorderState);
  }

  _Fn? getRecorderFn() {
    if (!_mRecorderIsInited || !_mPlayer!.isStopped) {
      return null;
    }
    return _mRecorder!.isStopped
        ? record
        : () {
            stopRecorder().then((value) => setState(() {}));
          };
  }

  // void _updateRecordState(RecorderState recordState) {}
  void play() async {
    assert(_mPlayerIsInited &&
        _mplaybackReady &&
        _mRecorder!.isStopped &&
        _mPlayer!.isStopped);
    await _mPlayer!.startPlayer(
        fromURI: _mPath,
        sampleRate: tSampleRate,
        codec: Codec.pcm16,
        numChannels: 1,
        whenFinished: () {
          setState(() {});
        }); // The readability of Dart is very special :-(
    setState(() {});
  }

  Future<void> stopPlayer() async {
    await _mPlayer!.stopPlayer();
  }

  Future<void> pauseRecorder() async {
    await _mRecorder!.pauseRecorder();
    _updateRecordState(_mRecorder!.recorderState);
  }

  Future<void> resumeRecorder() async {
    await _mRecorder!.resumeRecorder();
    _updateRecordState(_mRecorder!.recorderState);
  }

  Widget _buildRecordStopControl() {
    late Icon icon;
    late Color color;

    // print(
    //     "Within build record stop control, What is the recorder state: ${_mRecorder!.recorderState}");

    if (!(_mRecorder!.isStopped)) {
      icon = const Icon(Icons.stop, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = Icon(Icons.mic, color: theme.primaryColor, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            (!(_mRecorder!.isStopped)) ? stopRecorder() : record();
          },
        ),
      ),
    );
  }

  Widget _buildPauseResumeControl() {
    if (_mRecorder!.isStopped) {
      return const SizedBox.shrink();
    }

    late Icon icon;
    late Color color;

    if (_mRecorder!.isRecording) {
      icon = const Icon(Icons.pause, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = const Icon(Icons.play_arrow, color: Colors.red, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            (_mRecorder!.isPaused) ? resumeRecorder() : pauseRecorder();
          },
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0$numberStr';
    }

    return numberStr;
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  Widget _buildTimer() {
    final String minutes = _formatNumber(_recordDuration ~/ 60);
    final String seconds = _formatNumber(_recordDuration % 60);

    return Text(
      '$minutes : $seconds',
      style: const TextStyle(color: Colors.red),
    );
  }

  Widget _buildText() {
    if (_mRecorder!.isRecording || _mRecorder!.isPaused) {
      return _buildTimer();
    }

    return const Text("Waiting to record");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildRecordStopControl(),
                const SizedBox(width: 20),
                _buildPauseResumeControl(),
                const SizedBox(width: 20),
                _buildText(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
