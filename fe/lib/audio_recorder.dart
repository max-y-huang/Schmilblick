import 'dart:async';
import 'package:flutter/material.dart';

import 'package:record/record.dart';

import 'audio_recorder_io.dart';

class Recorder extends StatefulWidget {
  const Recorder({super.key});

  @override
  State<Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<Recorder> with AudioRecorderMixin {
  late final AudioRecorder _audioRecorder;
  Timer? _timer;
  int _recordDuration = 0;
  RecordState _recordState = RecordState.stop;
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Amplitude? _amplitude;

  @override
  void initState() {
    // establish the audio recorder
    _audioRecorder = AudioRecorder();

    // print('Record state: $_recordState');
    _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
      _updateRecordState(recordState);
    });

    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 350))
        .listen((amp) {
      setState(() => _amplitude = amp);
    });

    _start();

    super.initState();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        const encoder = AudioEncoder.pcm16bits;

        const sampleRateSet = 20000;

        if (!await _isEncoderSupported(encoder)) {
          return;
        }

        // get all the necessary devices
        final devs = await _audioRecorder.listInputDevices();
        print("All input devices: ${devs.toString()}");

        const config = RecordConfig(
            encoder: encoder, numChannels: 1, sampleRate: sampleRateSet);

        await recordStream(_audioRecorder, config);

        _recordDuration = 0;

        _startTimer();
      }
    } catch (e) {
      print("Error caught: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
  
  Future<void> _stop() async {
    final path = await _audioRecorder.stop();

    // if (path != null) {
    //   widget.onStop(path);
    // }
  }

  Future<void> _pause() => _audioRecorder.pause();

  Future<void> _resume() => _audioRecorder.resume();

  void _updateRecordState(RecordState recordState) {
    setState(() => _recordState = recordState);

    switch (recordState) {
      case RecordState.pause:
        _timer?.cancel();
        break;
      case RecordState.record:
        _startTimer();
        break;
      case RecordState.stop:
        _timer?.cancel();
        _recordDuration = 0;
        break;
    }
  }

  Future<bool> _isEncoderSupported(AudioEncoder encoder) async {
    final isSupported = await _audioRecorder.isEncoderSupported(
      encoder,
    );

    if (!isSupported) {
      print("${encoder.name} is not supported on this platform.");
      print("Supported encoders are the following: ");

      for (final e in AudioEncoder.values) {
        if (await _audioRecorder.isEncoderSupported(e)) {
          print("- ${encoder.name}");
        }
      }
    }

    return isSupported;
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(child: Container());
  }
}


// class _RecorderState extends State with AudioRecorderMixin {
// // class _RecorderState with AudioRecorderMixin {
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

//     // print('Record state: $_recordState');
//     _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
//       _updateRecordState(recordState);
//     });

//     _amplitudeSub = _audioRecorder
//         .onAmplitudeChanged(const Duration(milliseconds: 350))
//         .listen((amp) {
//       setState(() => _amplitude = amp);
//     });

//     super.initState();
//   }

//   Future<void> _start() async {
//     try {
//       if (await _audioRecorder.hasPermission()) {
//         const encoder = AudioEncoder.pcm16bits;

//         const sampleRateSet = 20000;

//         if (!await _isEncoderSupported(encoder)) {
//           return;
//         }

//         // get all the necessary devices
//         final devs = await _audioRecorder.listInputDevices();
//         print("All input devices: ${devs.toString()}");

//         const config = RecordConfig(
//             encoder: encoder, numChannels: 1, sampleRate: sampleRateSet);

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

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _recordSub?.cancel();
//     _amplitudeSub?.cancel();
//     _audioRecorder.dispose();
//     super.dispose();
//   }

//   Widget _buildRecordStopControl() {
//     late Icon icon;
//     late Color color;

//     if (_recordState != RecordState.stop) {
//       icon = const Icon(Icons.stop, color: Colors.red, size: 30);
//       color = Colors.red.withOpacity(0.1);
//     } else {
//       final theme = Theme.of(context);
//       icon = Icon(Icons.mic, color: theme.primaryColor, size: 30);
//       color = theme.primaryColor.withOpacity(0.1);
//     }

//     return ClipOval(
//       child: Material(
//         color: color,
//         child: InkWell(
//           child: SizedBox(width: 56, height: 56, child: icon),
//           onTap: () {
//             (_recordState != RecordState.stop) ? _stop() : _start();
//           },
//         ),
//       ),
//     );
//   }

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
