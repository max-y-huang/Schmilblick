import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:archive/archive_io.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
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
      home: PagedScoreSheet(),
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
  int? _width;
  List<SvgPicture>? _svgs;

  late final ScrollController _scrollController;
  late final Timer _timer;

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

  void handleAttach(ScrollPosition scrollposition) {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      final offset = _scrollController.offset;
      _scrollController.jumpTo(offset + 10);
    });
  }

  void handleDetach(ScrollPosition scrollposition) {
    _timer.cancel();
  }

  @override
  void initState() {
    super.initState();
    // First get the FlutterView.
    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    
    // Dimensions in physical pixels (px)
    Size size = view.physicalSize / view.devicePixelRatio;
    _width = size.width.toInt();

    _getSvg();

    _scrollController = ScrollController(
      onAttach: handleAttach,
      onDetach: handleDetach
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (BuildContext context, Orientation orientation) {
        return Container(
          color: Colors.white,
          child: (_svgs != null && orientation == Orientation.landscape) ? ListView(
            controller: _scrollController,
            scrollDirection: Axis.vertical,
            children: _svgs!
          ) : Placeholder()
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