import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:xml/xml.dart';
import 'audio_recorder.dart';
import 'dart:math';

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
      home: ContinuousScoreSheet(),
    );
  }
}

class ContinuousScoreSheet extends StatefulWidget {
  const ContinuousScoreSheet({super.key});

  @override
  State<ContinuousScoreSheet> createState() => _ContinuousScoreSheetState();
}

class _ContinuousScoreSheetState extends State<ContinuousScoreSheet> {
  final uri = 'http://localhost:3000'; // Replace this with localhost.run uri
  late int _width;
  late Future<SvgPicture> _svgs;
  late Future<XmlDocument> _svgXml;

  late final ScrollController _scrollController;

  Future<http.Response> _getSvgLinks(int imageWidth) async {
    final request = http.MultipartRequest('POST', Uri.parse('$uri/musicxml-to-svg'));
    request.fields['pageWidth'] = imageWidth.toString();

    const filename = "happy_birthday.mxl";
    final musicxmlBytes = (await rootBundle.load('assets/$filename')).buffer.asUint8List();
    request.files.add(http.MultipartFile.fromBytes('musicxml', musicxmlBytes, filename: filename));

    final streamResponse = await request.send();
    final response = await http.Response.fromStream(streamResponse);

    return response;
  }

  void _setupSvg() {
    final response = _getSvgLinks(_width);
    final svgDocument = response.then((body) => XmlDocument.parse(utf8.decode(body.bodyBytes)));
    final svgPicture = response.then((body) => SvgPicture.memory(body.bodyBytes));

    setState(() {
      _svgs = svgPicture;
    });
    _svgXml = svgDocument;
  }

  void _setWidth() {
    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    Size size = view.physicalSize / view.devicePixelRatio;
    _width = size.width.toInt();
  }

  void _getMeasureInfo() async {
    final svgXml = await _svgXml;
    for (final child in svgXml.firstChild!.childElements) {
      if (child.getAttribute("class") == "staffline") {
        for (final child2 in child.childElements) {
          if (child2.getAttribute("class") == "vf-measure") {
            print("Measure #: ${child2.getAttribute("id")}");
            for (final child3 in child2.children.sublist(0, 1)) {
              //print(child3.getAttribute("d"));
              final coordinates = child3.getAttribute("d")!;
              RegExp pattern = RegExp(r'M(?<x1>[\d\.]+) (?<y1>[\d\.]+)L(?<x2>[\d\.]+) (?<y2>[\d\.]+)');
              RegExpMatch regExpMatch = pattern.firstMatch(coordinates)!;
              final x1 = regExpMatch.namedGroup('x1');
              final x2 = regExpMatch.namedGroup('x2');
              final y1 = regExpMatch.namedGroup('y1');
              final y2 = regExpMatch.namedGroup('y2');

              print("($x1 $y1) ($x2 $y2)");
            }
            //print(child2.attributes);
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _setWidth();
    _setupSvg();
    _getMeasureInfo();
    _scrollController = ScrollController();
    _scrollController.addListener((){
      print(_scrollController.position.pixels);
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (BuildContext context, Orientation orientation) {
        return Container(
          color: Colors.white,
          child: FutureBuilder(
            future: _svgs,
            builder: (BuildContext context, AsyncSnapshot<SvgPicture> snapshot) {
              if (snapshot.hasData && orientation == Orientation.landscape) {
                return Scaffold(
                  body: ListView(
                      controller: _scrollController,
                      scrollDirection: Axis.vertical,
                      children: [snapshot.data!]
                    ),
                    floatingActionButton: FloatingActionButton(
                      onPressed: () {
                        _scrollController.jumpTo(500.0);
                      },
                      child: const Icon(Icons.arrow_upward),
                      ),
                );
              } else {
                return Placeholder();
              }
            }
          )
        );
      }
    );
  }
}

class PagedScoreSheet extends StatefulWidget {
  const PagedScoreSheet({super.key});

  @override
  State<PagedScoreSheet> createState() => _PagedScoreSheetState();
}

class _PagedScoreSheetState extends State<PagedScoreSheet> {
  Uint8List? _pdfBytes;
  late final PDFViewController _pdfViewController;
  late int? _pageCount;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    setFile();
  }

  void setFile() async {
    // TODO: Turn the file into a backend call. For now, as proof of concept
    // we'll use this file for now.
    final file = await rootBundle.load('assets/joplin-scott-the-entertainer.pdf');
    setState(() {
      _pdfBytes = file.buffer.asUint8List();
    });
  }

  Future<void> goToRandomPagePerSecond(PDFViewController pdfViewController) async {
    var rng = Random();
    _pdfViewController = pdfViewController;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // TODO: Replace this function and comment. As proof of concept, you
      // can programmatically change the page with the PDFViewController
      _pageCount = await _pdfViewController.getPageCount();
      if (_pageCount != null && _pageCount! > 0) {
        final page = rng.nextInt(_pageCount!);
        await _pdfViewController.setPage(page);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: _pdfBytes != null ? PDFView(
        pdfData: _pdfBytes!,
        swipeHorizontal: true,
        onViewCreated: goToRandomPagePerSecond,
      ) : Placeholder(),
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