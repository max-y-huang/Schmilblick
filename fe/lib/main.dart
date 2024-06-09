import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const MaterialApp(home: MicPage()));
}

class MicPage extends StatefulWidget {
  const MicPage({super.key});

  @override
  State<MicPage> createState() => _MicPageState();
}

class _MicPageState extends State<MicPage> with WidgetsBindingObserver {
  // Record myRecording = AudioRecorder();
  final myRecording = AudioRecorder();
  Timer? timer;
  String? _filePath;
  File? _file;

  double volume = 0.0;
  double minVolume = -45.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopRecording();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      stopRecording();
    }
  }

  startTimer() async {
    timer ??=
        Timer.periodic(Duration(milliseconds: 50), (timer) => updateVolume());
  }

  updateVolume() async {
    Amplitude ampl = await myRecording.getAmplitude();
    // await printPCMData();
    // print("Amplitude gained: ${ampl.current}");
    if (ampl.current > minVolume) {
      setState(() {
        volume = (ampl.current - minVolume) / minVolume;
      });
      print("VOLUME: ${volume}");
    }
  }

  int volume0to(int maxVolumeToDisplay) {
    return (volume * maxVolumeToDisplay).round().abs();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<bool> startRecording() async {
    if (await myRecording.hasPermission()) {
      if (!await myRecording.isRecording()) {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String filePath = '$appDocDir/pcm_file.txt';

        _file = File(filePath);

        print("Checking the file exists....");
        if (await _file!.exists()) {
          print("File exists, we're deleting it...");
          await _file!.delete(); // Where we delete the previous recording
        }
        // setState(() {
        //   _filePath = filePath;
        // });

        await myRecording.start(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            bitRate: 128000,
          ),
          path: filePath,
        );
        // Directory appDocDir = await getApplicationDocumentsDirectory();
        // await myRecording.start(
        //     const RecordConfig(encoder: AudioEncoder.pcm16bits),
        //     path: "./test_files/pcm_file.txt");
        // final stream = await myRecording.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));
        print("Recording started at: $filePath");
      }
      startTimer();
      return true;
    } else {
      print("Recording permission not granted.");
      return false;
    }
  }

  Future<void> stopRecording() async {
    print("Stop recording is trigerred");
    if (await myRecording.isRecording()) {
      final path = await myRecording.stop();
      print('Recorded file path: $path');
    }
  }

  Future<void> printPCMData() async {
    if (_file != null) {
      final bytes = await _file!.readAsBytes();
      print("PCM Data: $bytes");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: startRecording(),
        builder: (context, AsyncSnapshot<bool> snapshot) {
          return Scaffold(
              body: Center(
            child:
                Text(snapshot.hasData ? volume0to(100).toString() : "NO DATA"),
          ));
        });
  }
}
