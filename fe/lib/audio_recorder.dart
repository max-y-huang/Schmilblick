import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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

int fixedListSize = 2048;
int lowerFrequency = 50;
int higherFrequency = 4500;
// two buffers to allow for possible switching
List<double> primaryBuffer = List<double>.filled(fixedListSize, 0);
List<double> secondaryBuffer = List<double>.filled(fixedListSize, 0);

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

  List<double> performFFT(Uint8List? streamData) {
    // use Cooley-Turkey algorithm
    // FFT separates into two groups: the reals and the conjugates.
    // Discard the conjugates to get rid of the phase and get the magnitudes.
    // 1. convert the Uint8List into bytes
    List<double> streamDataDouble = streamData!.buffer.asFloat32List();
    // 2. perform the FFT
    return fftObj.realFft(streamDataDouble).discardConjugates().magnitudes();
  }

  

  Future<void> record() async {
    assert(_mRecorderIsInited && _mPlayer!.isStopped);
    var sink = await createFile();
    var recordingDataController = StreamController<Food>();
    _mRecordingDataSubscription =
        recordingDataController.stream.listen((buffer) {
      if (buffer is FoodData) {
        // this is where we will process the PCM data

        List<double> fftResult = performFFT(buffer.data);
        List<double> fftFiltered = implementBandPassFilter(
            fftResult, tSampleRate, lowerFrequency, higherFrequency);
        // print("Buffer information: ${buffer.data}!");
        print("Buffer filtered: $fftFiltered");
        sink.add(buffer.data!);
      }
    });
    await _mRecorder!.startRecorder(
      toStream: recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: tSampleRate,
      enableVoiceProcessing: _mEnableVoiceProcessing,
      bufferSize: 2048,
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
