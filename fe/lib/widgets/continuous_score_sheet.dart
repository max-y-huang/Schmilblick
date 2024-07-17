import 'dart:ui';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';

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

class ContinuousScoreSheet extends StatefulWidget {
  const ContinuousScoreSheet({super.key});

  @override
  State<ContinuousScoreSheet> createState() => _ContinuousScoreSheetState();
}

class _ContinuousScoreSheetState extends State<ContinuousScoreSheet> {
  final uri = 'http://localhost:3000'; // Replace this with localhost.run uri
  late int _width;
  late int _height;
  final double _offsetRatio = 1 / 8;
  late Future<SvgPicture> _svgs;
  late Future<XmlDocument> _svgXml;
  var groups = <GroupInfo>[];

  // lineCoordinatesRegex captures the coordinates from
  //  a string like "M171.66015625 189L472.4196980046949 189".
  //  So for the above example, we capture the following:
  //    x1 = 171.66015625, y1 = 189, x2 = 472.4196980046949, y2 = 189
  //  Format: ?<x1> is an example of a named capture group
  final RegExp lineCoordinatesRegex =
      RegExp(r'M(?<x1>[\d\.]+) (?<y1>[\d\.]+)L(?<x2>[\d\.]+) (?<y2>[\d\.]+)$');

  late final ScrollController _scrollController;

  Future<http.Response> _getSvgLinks(int imageWidth) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$uri/musicxml-to-svg'));
    request.fields['pageWidth'] = imageWidth.toString();

    // TODO: Properly get the file instead of hardcoding a filename
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
    final classAttribute = elem.getAttribute('class');
    return classAttribute != null &&
        classAttribute.contains('vf-measure') &&
        elem.getAttribute('id') != '-1';
  }

  // Determine if elem is a 'line' element e.g.
  //  <path stroke-width="1" fill="none" stroke="#000000" stroke-dasharray="none" d="M171.66015625 625.5999999999999L472.4196980046949 625.5999999999999"></path>
  bool _isLine(XmlElement elem) {
    final String? dAttribute = elem.getAttribute("d");
    return elem.name.local == "path" &&
        dAttribute != null &&
        elem.getAttribute("class") == null &&
        lineCoordinatesRegex.hasMatch(dAttribute);
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

    var minY = double.maxFinite;
    var maxY = -double.maxFinite;
    for (final measureElement in measureElements) {
      List<XmlElement> measureStaffLines =
          _getAllChildElements(measureElement, _isLine);
      for (final line in measureStaffLines) {
        final double y = _getYCoord(line.getAttribute("d")!);
        if (y < minY) minY = y;
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
    int minId = -100;
    for (final XmlElement measureElement in measureElements) {
      final idStr = measureElement.getAttribute("id");
      if (idStr == null) throw "Null measure id!";
      final id = int.parse(idStr);
      if (id < minId || minId == -100) minId = id;
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
      double maxY = -double.maxFinite;
      double minY = double.maxFinite;
      for (var j = 0; j < linesPerGroup; ++j) {
        final minMaxY = _getStafflineMinMaxY(stafflineElements[i + j]);
        if (minMaxY.maximumY > maxY) maxY = minMaxY.maximumY;
        if (minMaxY.minimumY < minY) minY = minMaxY.minimumY;
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
    final double offset = _height * _offsetRatio;
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
                    // TODO: Remove this button (it is for testing purposes only)
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
