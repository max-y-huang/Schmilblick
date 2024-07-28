import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_turner/uploaded_files_model.dart';
import 'package:smart_turner/widgets/upload_file_page.dart';
import 'package:smart_turner/widgets/score_sheet.dart';
import 'audio_recorder.dart';

void main() => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UploadedFiles()),
        ],
        child: MyApp(),
      ),
    );

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPage();
}

class _RecorderPage extends State<RecorderPage> {
  String? audioPath;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Recorder(),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: Consumer<UploadedFiles>(
        builder: (context, uploadedFiles, child) {
          if (uploadedFiles.bothFilesReady) {
            return Column(
              children: [
                SizedBox(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    child: ScoreSheetDisplay()),
                Recorder(),
              ],
            );
          } else {
            return const UploadFilePage();
          }
        },
      ),
    );
  }
}
