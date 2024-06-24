import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:archive/archive_io.dart';
import 'audio_recorder.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: ScoreSheet(),
    );
  }
}

class ScoreSheet extends StatefulWidget {
  const ScoreSheet({super.key});

  @override
  State<ScoreSheet> createState() => _ScoreSheetState();
}

class _ScoreSheetState extends State<ScoreSheet> {
  final uri = 'https://279df8c5ec0b57.lhr.life';
  // int? _shortLength;
  // int? _longLength;

  int? _width;

  // List<SvgPicture>? _portraitSvgs;
  // List<SvgPicture>? _landscapeSvgs;
  List<SvgPicture>? _svgs;

  Future<List<OutputStream>> _getSvgLinks(int imageWidth) async {
    final request = http.MultipartRequest('POST', Uri.parse('$uri/musicxml-to-svg'));
    request.fields['pageWidth'] = imageWidth.toString();

    const filename = "happy_birthday.mxl";
    final musicxmlBytes = (await rootBundle.load('assets/$filename')).buffer.asUint8List();
    request.files.add(http.MultipartFile.fromBytes('musicxml', musicxmlBytes, filename: filename));

    final streamResponse = await request.send();
    final response = await http.Response.fromStream(streamResponse);
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);

    List<OutputStream> outputStreams = [];
    for (final file in archive.files) {
      if (file.isFile) {
        var outputStream = OutputStream();
        file.writeContent(outputStream);
        outputStreams.add(outputStream);
      }
    }

    return outputStreams;
  }

  void _getSvg() async {
    if (_width == null) {
      return;
    }

    List<OutputStream> outputStreams = await _getSvgLinks(_width!);
    final List<SvgPicture> outputPictures = outputStreams.map((stream) => SvgPicture.memory(stream.getBytes() as Uint8List)).toList();
    setState(() {
      _svgs = outputPictures;
    });
  }

  // void _getSvgLandscape() async {
  //   if (_longLength == null) {
  //     return;
  //   }
  //
  //   final List<OutputStream> outputStreams = await _getSvgLinks(_longLength!);
  //   final List<SvgPicture> outputPictures = outputStreams.map((stream) => SvgPicture.memory(stream.getBytes() as Uint8List)).toList();
  //   print("get svg landscape");
  //   setState(() {
  //   _landscapeSvgs = outputPictures;
  //   });
  // }
  //
  // void _getSvgPortrait() async {
  //   if (_shortLength == null) {
  //     return;
  //   }
  //
  //   print("get svg portrait");
  //   List<OutputStream> outputStreams = await _getSvgLinks(_shortLength!);
  //   final List<SvgPicture> outputPictures = outputStreams.map((stream) => SvgPicture.memory(stream.getBytes() as Uint8List)).toList();
  //   setState(() {
  //     _portraitSvgs = outputPictures;
  //   });
  // }

  @override
  void initState() {
    super.initState();
    // First get the FlutterView.
    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    
    // Dimensions in physical pixels (px)
    Size size = view.physicalSize / view.devicePixelRatio;
    _width = size.width.toInt();
    print(_width);

    _getSvg();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (BuildContext context, Orientation orientation) {
        List<Widget> children = (_svgs != null && orientation == Orientation.landscape) ? _svgs as List<Widget> : [Placeholder()];

        return Container(
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.vertical,
            children: children
          )
        );
      }
    );
  }
}

class RecorderPage extends StatefulWidget {
  const RecorderPage({ super.key }); 

  @override
  State<RecorderPage> createState() => _RecorderPage();
}

class _RecorderPage extends State<RecorderPage> {
  bool showPlayer = false;
  String? audioPath;

  @override
  void initState() {
    showPlayer = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Recorder(
          onStop: (path) {
            if (kDebugMode) print('Recorded file path: $path');
            setState(() {
              audioPath = path;
              showPlayer = true;
            });
          },
        ),
      ),
    );
  }
}
