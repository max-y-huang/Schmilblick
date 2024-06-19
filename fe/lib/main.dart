import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:archive/archive_io.dart';

// import 'package:record_example/audio_player.dart';
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
      home: RecorderPage(),
    );
  }
}

class ScoreSheet extends StatefulWidget {
  const ScoreSheet({super.key});

  @override
  State<ScoreSheet> createState() => _ScoreSheetState();
}

// TODO: Make it look nicer with buttons to toggle scroll/page flip mode or something????
// TODO: Make the UI and code nicer.
class _ScoreSheetState extends State<ScoreSheet> {
  List<OutputStream>? _outputStreams;
  double? _width;
  double? _height;

  final uri = 'http://localhost:3000';

  void _getSvgLinks() async {
    // TODO: Might want to make two calls to the backend, one for vertical, one horizontal
    final request = http.MultipartRequest('POST', Uri.parse('$uri/musicxml-to-svg'));
    request.fields['pageWidth'] = _width.toString();
    // request.fields['pageHeight'] = _height.toString();
    
    const filename = "happy_birthday.mxl";
    final musicxmlBytes = (await rootBundle.load('assets/$filename')).buffer.asUint8List();
    request.files.add(http.MultipartFile.fromBytes('musicxml', musicxmlBytes, filename: filename));

    final streamResponse = await request.send();
    final response = await http.Response.fromStream(streamResponse);

    final inputStream = InputStream(response.bodyBytes);
    final archive = ZipDecoder().decodeBuffer(inputStream);

    List<OutputStream> outputStreams = [];
    for (final file in archive.files) {
      if (file.isFile) {
        var outputStream = OutputStream();
        file.writeContent(outputStream);
        outputStreams.add(outputStream);
      }
    }

    setState(() {
      _outputStreams = outputStreams;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder (
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_width != constraints.maxWidth || _height != constraints.maxHeight) {
          // TODO: Find a better way to get the width and height and answer the question: "Do we want
          // to call the backend every time the screen size changes?"
          _width = constraints.maxWidth;
          _height = constraints.maxHeight;
          _getSvgLinks();
        }

        return Container(
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.vertical,
            children: _outputStreams != null 
              ? _outputStreams!.map((stream) => SvgPicture.memory(stream.getBytes() as Uint8List)).toList()
              : [Placeholder()]
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
