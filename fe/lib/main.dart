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

class GroupInfo {
  int startingMeasure;
  double minY;

  GroupInfo(this.startingMeasure, this.minY);
}

class MinMaxYCoords {
  double minimumY;
  double maximumY;

  MinMaxYCoords(this.minimumY, this.maximumY);
}

class _ContinuousScoreSheetState extends State<ContinuousScoreSheet> {
  final uri = 'http://localhost:3000'; // Replace this with localhost.run uri
  late int _width;
  late int _height;
  late Future<SvgPicture> _svgs;
  late Future<XmlDocument> _svgXml;
  var groups = <GroupInfo>[];
  final RegExp lineCoordinatesRegex =
      RegExp(r'M(?<x1>[\d\.]+) (?<y1>[\d\.]+)L(?<x2>[\d\.]+) (?<y2>[\d\.]+)$');

  late final ScrollController _scrollController;

  Future<http.Response> _getSvgLinks(int imageWidth) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$uri/musicxml-to-svg'));
    request.fields['pageWidth'] = imageWidth.toString();

    const filename = "viva_la_vida.mxl";
    final musicxmlBytes =
        (await rootBundle.load('assets/$filename')).buffer.asUint8List();
    request.files.add(http.MultipartFile.fromBytes('musicxml', musicxmlBytes,
        filename: filename));

    final streamResponse = await request.send();
    final response = await http.Response.fromStream(streamResponse);

    return response;
  }

  void _setupSvg() {
    final response = _getSvgLinks(_width);
    final svgDocument =
        response.then((body) => XmlDocument.parse(utf8.decode(body.bodyBytes)));
    final svgPicture =
        response.then((body) => SvgPicture.memory(body.bodyBytes));

    setState(() {
      _svgs = svgPicture;
    });
    _svgXml = svgDocument;
  }

  void _setWidth() {
    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    Size size = view.physicalSize / view.devicePixelRatio;
    _width = size.width.toInt();
    _height = size.height.toInt();
  }

  // Determine if elem is a 'measure' element e.g.
  //  <g class="vf-measure" id="1">
  bool _isMeasure(XmlElement elem) {
    if (elem.getAttribute('class') == null) {
      return false;
    } else if (elem.getAttribute('class')!.contains('vf-measure') &&
        elem.getAttribute('id') != '-1') {
      return true;
    } else {
      return false;
    }
  }

  // Determine if elem is a 'line' element e.g.
  //  <path stroke-width="1" fill="none" stroke="#000000" stroke-dasharray="none" d="M171.66015625 625.5999999999999L472.4196980046949 625.5999999999999"></path>
  bool _isLine(XmlElement elem) {
    final String? dAttribute = elem.getAttribute("d");
    if (elem.name.local == "path" &&
        dAttribute != null &&
        elem.getAttribute("class") == null &&
        lineCoordinatesRegex.hasMatch(dAttribute)) {
      return true;
    } else {
      return false;
    }
  }

  // Return all child elements of elem for which the predicate returns true
  List<XmlElement> _getAllChildElements(
      XmlElement elem, bool Function(XmlElement) predicate) {
    List<XmlElement> children = [];
    for (final XmlElement child in elem.childElements) {
      if (predicate(child)) {
        children.add(child);
      }
    }
    return children;
  }

  // Extract the y coordinate from a "d" attribute - this is the attribute denoting the coordinates
  //   of a line element on the staff.
  // e.g. d="M171.66015625 625.5999999999999L472.4196980046949 625.5999999999999" -- the y coordinate is 625.5999 here
  double _getYCoord(String dAttribute) {
    RegExpMatch regExpMatch = lineCoordinatesRegex.firstMatch(dAttribute)!;
    final y1 = regExpMatch.namedGroup('y1');
    if (y1 == null) throw "Null y coordinate in d attribute!";
    return double.parse(y1);
  }

  // Get the minimum and maximum y-coordinates of a 'staffline' element. This means getting the
  //  minimum and maximum y-coordinates of all staff lines and ledger lines of every measure.
  // e.g. stafflineElement:
  //  <g class="staffline" id="Violin0-1">
  //     <g class="vf-measure" id="5">...</g>
  //     <g class="vf-measure" id="6">...</g>
  //    ...
  //  </g>
  MinMaxYCoords _getStafflineMinMaxY(XmlElement stafflineElement) {
    List<XmlElement> measureElements =
        _getAllChildElements(stafflineElement, _isMeasure);
    if (measureElements.isEmpty) throw "No measures found?!";

    var minY = -1.0;
    var maxY = -1.0;
    for (final measureElement in measureElements) {
      List<XmlElement> measureStaffLines =
          _getAllChildElements(measureElement, _isLine);
      for (final line in measureStaffLines) {
        final double y = _getYCoord(line.getAttribute("d")!);
        if (y < minY || minY == -1.0) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    return MinMaxYCoords(minY, maxY);
  }

  // Get the Id of the first measure in the 'staffline' element. See _getStafflineMinMaxY documentation for
  //  example of 'staffline' element. "First" measure means the measure with the lowest Id.
  int _getFirstMeasureId(XmlElement stafflineElement) {
    List<XmlElement> measureElements =
        _getAllChildElements(stafflineElement, _isMeasure);
    int minId = -1;
    for (final XmlElement measureElement in measureElements) {
      final idStr = measureElement.getAttribute("id");
      if (idStr == null) throw "Null measure id!";
      final id = int.parse(idStr);
      if (id < minId || minId == -1) minId = id;
    }

    return minId;
  }

  // Given a measureId, return the Group the measure would belong to
  int _getGroupForMeasure(int measureId) {
    var left = 0;
    var right = groups.length;
    var groupCount = groups.length;

    var mid = 0;

    while (true) {
      mid = (left + right) ~/ 2;
      if (measureId == groups[mid].startingMeasure ||
          (measureId > groups[mid].startingMeasure && mid == groupCount - 1) ||
          (measureId > groups[mid].startingMeasure &&
              measureId < groups[mid + 1].startingMeasure)) {
        return mid;
      } else if (measureId < groups[mid].startingMeasure) {
        right = mid;
      } else {
        left = mid;
      }
    }
  }

  void _setupContinuousMode() async {
    final svgXml = await _svgXml;
    var stafflineElements = svgXml
        .findAllElements("g")
        .where((line) => line.getAttribute('class') == 'staffline')
        .toList();
    final stafflineElementsCount = stafflineElements.length;
    final linesPerGroup = svgXml
        .findAllElements("g")
        .where((line) => (line.getAttribute('class')!.contains('vf-measure') &&
            line.getAttribute('id') == '1'))
        .length;

    for (var i = 0; i < stafflineElementsCount; i += linesPerGroup) {
      double maxY = -1;
      double minY = -1;
      for (var j = 0; j < linesPerGroup; ++j) {
        final minMaxY = _getStafflineMinMaxY(stafflineElements[i + j]);
        if (minMaxY.maximumY > maxY) maxY = minMaxY.maximumY;
        if (minMaxY.minimumY < minY || minY == -1) minY = minMaxY.minimumY;
      }

      final int firstMeasureId = _getFirstMeasureId(stafflineElements[i]);
      groups.add(GroupInfo(firstMeasureId, minY));
    }

    groups.sort((group1Info, group2Info) =>
        group1Info.startingMeasure.compareTo(group2Info.startingMeasure));
    final int veryFirstMeasureId = groups[0].startingMeasure;
    for (var groupInfo in groups) {
      groupInfo.startingMeasure -= veryFirstMeasureId;
    }
  }

  void jumpToMeasure(int measureNumber) {
    int groupNumber = _getGroupForMeasure(measureNumber);
    final double offset = _height * 1 / 8;
    double yCoord = groups[groupNumber].minY - offset;
    double maxScroll = _scrollController.position.maxScrollExtent;
    double minScroll = _scrollController.position.minScrollExtent;

    if (yCoord > maxScroll) {
      _scrollController.jumpTo(maxScroll);
    } else if (yCoord < minScroll) {
      _scrollController.jumpTo(minScroll);
    } else {
      _scrollController.jumpTo(yCoord);
    }
  }

  @override
  void initState() {
    super.initState();
    _setWidth();
    _setupSvg();
    _setupContinuousMode();
    _scrollController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
      return Container(
          color: Colors.white,
          child: FutureBuilder(
              future: _svgs,
              builder:
                  (BuildContext context, AsyncSnapshot<SvgPicture> snapshot) {
                if (snapshot.hasData && orientation == Orientation.landscape) {
                  return Scaffold(
                    body: ListView(
                        controller: _scrollController,
                        scrollDirection: Axis.vertical,
                        children: [snapshot.data!]),
                    floatingActionButton: FloatingActionButton(
                      onPressed: () {
                        jumpToMeasure(75 - 1);
                      },
                      child: const Icon(Icons.arrow_upward),
                    ),
                  );
                } else {
                  return Placeholder();
                }
              }));
    });
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
    final file =
        await rootBundle.load('assets/joplin-scott-the-entertainer.pdf');
    setState(() {
      _pdfBytes = file.buffer.asUint8List();
    });
  }

  Future<void> goToRandomPagePerSecond(
      PDFViewController pdfViewController) async {
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
      child: _pdfBytes != null
          ? PDFView(
              pdfData: _pdfBytes!,
              swipeHorizontal: true,
              onViewCreated: goToRandomPagePerSecond,
            )
          : Placeholder(),
    );
  }
}

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

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
