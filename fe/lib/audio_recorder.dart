import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';

import 'package:flutter_sound/flutter_sound.dart';

// temporary fix for getting the RecorderState because we need access to it.
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fftea/fftea.dart';

// import 'audio_recorder_io.dart';

const int tSampleRate = 44100;
typedef _Fn = void Function();

int fixedListSize = 2048;
// two buffers to allow for possible switching
List<double> primaryBuffer = List<double>.filled(fixedListSize, 0);
List<double> secondaryBuffer = List<double>.filled(fixedListSize, 0);

int flag = 0;

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
    // _mPlayer!.openPlayer().then((value) {
    //   setState(() {
    //     _mPlayerIsInited = true;
    //   });
    // });

    // _openRecorder();
    init().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });

    // _recordSubscription = _mRecorder!.recorderState.listen()
  }

  Future<void> init() async {
    await _openRecorder();
    _mRecorderSubscription = _mRecorder!.onProgress!.listen((e) {
      print("E is printed out: $e");
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

  Future<void> record() async {
    assert(_mRecorderIsInited && _mPlayer!.isStopped);
    var sink = await createFile();
    var recordingDataController = StreamController<Food>();
    _mRecordingDataSubscription =
        recordingDataController.stream.listen((buffer) {
      if (buffer is FoodData) {
        // this is where we will process the PCM data

        // print("Buffer information: ${buffer.data}!");
        // print("Buffer length: ${buffer.data.length}");
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
            // _updateRecordState(_mRecorder!.recorderState);
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
            // _updateRecordState(_mRecorder!.recorderState);
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
            // if (_amplitude != null) ...[
            //   const SizedBox(height: 40),
            //   Text('Current: ${_amplitude?.current ?? 0.0}'),
            //   Text('Max: ${_amplitude?.max ?? 0.0}'),
            // ],
          ],
        ),
      ),
    );
  }
}

// class _RecorderState extends State<Recorder> with AudioRecorderMixin {
//   late final AudioRecorder _audioRecorder;
//   Timer? _timer;
//   int _recordDuration = 0;
//   RecordState _recordState = RecordState.stop;
//   StreamSubscription<RecordState>? _recordSub;
//   StreamSubscription<Amplitude>? _amplitudeSub;
//   Amplitude? _amplitude;

//   @override
//   void initState() {
//     // establish the audio recorder
//     _audioRecorder = AudioRecorder();

//     _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
//       _updateRecordState(recordState);
//     });

//     _amplitudeSub = _audioRecorder
//         .onAmplitudeChanged(const Duration(milliseconds: 800))
//         .listen((amp) {
//       setState(() => _amplitude = amp);
//     });

//     super.initState();
//   }

//   Future<void> _start() async {
//     try {
//       if (await _audioRecorder.hasPermission()) {
//         const encoder = AudioEncoder.pcm16bits;

//         if (!await _isEncoderSupported(encoder)) {
//           return;
//         }

//         // get all the necessary devices
//         final devs = await _audioRecorder.listInputDevices();
//         print("All input devices: ${devs.toString()}");

//         const config =
//             RecordConfig(encoder: encoder, sampleRate: 10000, numChannels: 1);

//         await recordStream(_audioRecorder, config);

//         _recordDuration = 0;

//         _startTimer();
//       }
//     } catch (e) {
//       print("Error caught: $e");
//     }
//   }

//   Future<void> _stop() async {
//     final path = await _audioRecorder.stop();

//     if (path != null) {
//       widget.onStop(path);

//       downloadWebData(path);
//     }
//   }

//   Future<void> _pause() => _audioRecorder.pause();

//   Future<void> _resume() => _audioRecorder.resume();

//   void _updateRecordState(RecordState recordState) {
//     setState(() => _recordState = recordState);

//     switch (recordState) {
//       case RecordState.pause:
//         _timer?.cancel();
//         break;
//       case RecordState.record:
//         _startTimer();
//         break;
//       case RecordState.stop:
//         _timer?.cancel();
//         _recordDuration = 0;
//         break;
//     }
//   }

//   Future<bool> _isEncoderSupported(AudioEncoder encoder) async {
//     final isSupported = await _audioRecorder.isEncoderSupported(
//       encoder,
//     );

//     if (!isSupported) {
//       print("${encoder.name} is not supported on this platform.");
//       print("Supported encoders are the following: ");

//       for (final e in AudioEncoder.values) {
//         if (await _audioRecorder.isEncoderSupported(e)) {
//           print("- ${encoder.name}");
//         }
//       }
//     }

//     return isSupported;
//   }

//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         body: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: <Widget>[
//                 _buildRecordStopControl(),
//                 const SizedBox(width: 20),
//                 _buildPauseResumeControl(),
//                 const SizedBox(width: 20),
//                 _buildText(),
//               ],
//             ),
//             if (_amplitude != null) ...[
//               const SizedBox(height: 40),
//               Text('Current: ${_amplitude?.current ?? 0.0}'),
//               Text('Max: ${_amplitude?.max ?? 0.0}'),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   // @override
//   // Widget build(BuildContext context) {
//   //   return MaterialApp(home: Scaffold( body: Column ( mainAxisAlignment: MainAxisAlignment.center, children: [
//   //     Row( mainAxisAlignment: MainAxisAlignment.center, children: [
//   //       Row( mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
//   //         _buildRecordStopControl(),
//   //         constSizedBox(width: 20),
//   //         _buildPauseResumeControl(),
//   //         constSizedBox(width: 20),
//   //         _buildText(),
//   //       ],
//   //       ),
//   //       if (_amplitude != null) ...[
//   //         const SizedBox(height: 40),
//   //         Text('Current: ${_amplitude?.current ?? 0.0}'),
//   //         Text('Max: ${_amplitude?.max ?? 0.0}'),
//   //       ],
//   //     ],
//   //     ),
//   //   ),
//   //   ),
//   //   );
//   // }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _recordSub?.cancel();
//     _amplitudeSub?.cancel();
//     _audioRecorder.dispose();
//     super.dispose();
//   }

  // Widget _buildRecordStopControl() {
  //   late Icon icon;
  //   late Color color;

  //   if (_recordState != RecordState.stop) {
  //     icon = const Icon(Icons.stop, color: Colors.red, size: 30);
  //     color = Colors.red.withOpacity(0.1);
  //   } else {
  //     final theme = Theme.of(context);
  //     icon = Icon(Icons.mic, color: theme.primaryColor, size: 30);
  //     color = theme.primaryColor.withOpacity(0.1);
  //   }

  //   return ClipOval(
  //     child: Material(
  //       color: color,
  //       child: InkWell(
  //         child: SizedBox(width: 56, height: 56, child: icon),
  //         onTap: () {
  //           (_recordState != RecordState.stop) ? _stop() : _start();
  //         },
  //       ),
  //     ),
  //   );
  // }

//   Widget _buildPauseResumeControl() {
//     if (_recordState == RecordState.stop) {
//       return const SizedBox.shrink();
//     }

//     late Icon icon;
//     late Color color;

//     if (_recordState == RecordState.record) {
//       icon = const Icon(Icons.pause, color: Colors.red, size: 30);
//       color = Colors.red.withOpacity(0.1);
//     } else {
//       final theme = Theme.of(context);
//       icon = const Icon(Icons.play_arrow, color: Colors.red, size: 30);
//       color = theme.primaryColor.withOpacity(0.1);
//     }

//     return ClipOval(
//       child: Material(
//         color: color,
//         child: InkWell(
//           child: SizedBox(width: 56, height: 56, child: icon),
//           onTap: () {
//             (_recordState == RecordState.pause) ? _resume() : _pause();
//           },
//         ),
//       ),
//     );
//   }

//   Widget _buildText() {
//     if (_recordState != RecordState.stop) {
//       return _buildTimer();
//     }

//     return const Text("Waiting to record");
//   }

//   Widget _buildTimer() {
//     final String minutes = _formatNumber(_recordDuration ~/ 60);
//     final String seconds = _formatNumber(_recordDuration % 60);

//     return Text(
//       '$minutes : $seconds',
//       style: const TextStyle(color: Colors.red),
//     );
//   }

//   String _formatNumber(int number) {
//     String numberStr = number.toString();
//     if (number < 10) {
//       numberStr = '0$numberStr';
//     }

//     return numberStr;
//   }

//   void _startTimer() {
//     _timer?.cancel();

//     _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
//       setState(() => _recordDuration++);
//     });
//   }
// }
