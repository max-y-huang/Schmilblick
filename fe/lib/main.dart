import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: const ScoreSheet(),
    );
  }
}

class ScoreSheet extends StatefulWidget {
  const ScoreSheet({super.key});

  @override
  State<ScoreSheet> createState() => _ScoreSheetState();
}

class _ScoreSheetState extends State<ScoreSheet> {
  // late Future<List<String>> svgLinks;

  @override
  void initState() {
    super.initState();
    // svgLinks = getSvgLinks();
  }

  // Future<List<String>> getSvgLinks() async {
  //   FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
  //   Size size = view.physicalSize;
  //   double width = size.width;
  //
  //   try {
  //   var request = http.MultipartRequest(
  //     'POST',
  //     Uri.parse('https://9c8b61b21ebaad.lhr.life/musicxml-to-svg')
  //   )
  //   ..fields['pageWidth'] = width.toString()
  //   ..files.add(await http.MultipartFile.fromPath("musicxml", "assets/music.xml"));
  //   } catch (e) { print(e); }
  //
  //   return [];
  //
  //   final response = await request.send();
  //   final responseBodyString = await response.stream.bytesToString();
  //
  //   final responseBody = jsonDecode(responseBodyString) as Map<String, dynamic>;
  //   final List<String> files = responseBody["files"];
  //
  //   return files;
  // }
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.vertical,
      children: [
        SvgPicture.network("http://localhost:3000/music_0.svg"),
        SvgPicture.network("http://localhost:3000/music_1.svg"),
      ]
    );
  }
}
