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

class Coordinates {
    double x1;
    double y1;
    double x2;
    double y2;

    Coordinates(this.x1, this.y1, this.x2, this.y2);
}

class MeasureInfo {
  Coordinates topStaffLineCoords;
  Coordinates bottomStaffLineCoords;
  int grandStaffId;

  MeasureInfo(this.topStaffLineCoords, this.bottomStaffLineCoords, this.grandStaffId);
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
  var grandStaves = []; // y-coordinate of each Grand Staff
  var measures = <MeasureInfo>[];

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

  
  /*
  args:
    staffLine: a String of the format "M<number> <number>L<number> <number>"
      e.g. "M106.123046875 1055.186219105622L326.7657137604009 1055.186219105622"
  */
  Coordinates getStaffLineCoordinates(staffLine) {
    RegExp pattern = RegExp(r'M(?<x1>[\d\.]+) (?<y1>[\d\.]+)L(?<x2>[\d\.]+) (?<y2>[\d\.]+)');
    RegExpMatch regExpMatch = pattern.firstMatch(staffLine)!;
    var x1 = regExpMatch.namedGroup('x1');
    var y1 = regExpMatch.namedGroup('y1');
    var x2 = regExpMatch.namedGroup('x2');
    var y2 = regExpMatch.namedGroup('y2');

    if (x1 == null || y1 == null || x2 == null || y2 == null) {
      throw "Null coordinates";
    }

    return Coordinates(double.parse(x1), double.parse(y1), double.parse(x2), double.parse(y2));
  }

  void _getMeasureInfo() async {
    final svgXml = await _svgXml;
    var grandStaffId = 0;
    var ignoreFirstMeasure = false;
    // ^ sometimes a measure might've begun on the previous Grand Staff, 
    //  in which case we can ignore it for the current Grand Staff.
    
    // Iterate over Grand Staves
    for (final child in svgXml.firstChild!.childElements) {
      if (child.getAttribute("class") == "staffline" && child.getAttribute("id") == "Piano0-1") {
        final firstMeasure = child.children.sublist(0, 1)[0];
        final topStaffLine = firstMeasure.children.sublist(0, 1)[0];
        final grandStaffY = getStaffLineCoordinates(topStaffLine.getAttribute("d")).y1;
        grandStaves.add(grandStaffY);

        // Iterate over measures
        var i = 0;
        if (ignoreFirstMeasure) i = 1;
        var lastMeasureIncomplete = false;
        for (final child2 in child.children.sublist(i, )) {
          if (child2.getAttribute("class") == "vf-measure") {
            if (child2.getAttribute("id") == "-1") {
              ignoreFirstMeasure = true;
              lastMeasureIncomplete = true;
            }
            //print("Measure #: ${child2.getAttribute("id")}");
            final topStaffLine = child2.children.sublist(0, 1)[0];
            final bottomStaffLine = child2.children.sublist(4, 5)[0];
            final topStaffLineCoords = getStaffLineCoordinates(topStaffLine.getAttribute("d"));
            final bottomStaffLineCoords = getStaffLineCoordinates(bottomStaffLine.getAttribute("d"));
            measures.add(MeasureInfo(topStaffLineCoords, bottomStaffLineCoords, grandStaffId));
            // print(topStaffLine.getAttribute("d"));
            // print(bottomStaffLine.getAttribute("d"));
            
          }
        }
        if (lastMeasureIncomplete == false) ignoreFirstMeasure = false;
        grandStaffId += 1;
      }
    }
    print(grandStaves);
    // for (final measure in measures) {
    //   print(measure.grandStaffId);
    //   print("${measure.topStaffLineCoords.x1} ${measure.topStaffLineCoords.x2} ${measure.topStaffLineCoords.y1}");
    //   print("${measure.bottomStaffLineCoords.x1} ${measure.bottomStaffLineCoords.x2} ${measure.bottomStaffLineCoords.y1}");
    // }
  }

  void jumpToMeasure(int measureNumber) {
    int grandStaffId = measures[measureNumber].grandStaffId;
    double yValue = grandStaves[grandStaffId];
    _scrollController.jumpTo(yValue);
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
                      jumpToMeasure(6);
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