import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class UploadFilePage extends StatefulWidget {
  const UploadFilePage({super.key});

  @override
  State<UploadFilePage> createState() => _UploadFilePageState();
}

class _UploadFilePageState extends State<UploadFilePage> {
  Uint8List? _mxlFile;
  Uint8List? _pdfFile;

  Future<void> _uploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      // Process the file (e.g., upload to a server or display information)
      print('PDF File: ${file.name}');
      setState(() {
        _pdfFile = file.bytes;
      });
    } else {
      // User canceled the picker
      print('PDF file selection canceled');
    }
  }
  
  Future<void> _uploadMxl() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      // Process the file (e.g., upload to a server or display information)
      print('MXL File: ${file.name} ${file.extension}');
      setState(() {
        _mxlFile = file.bytes;
      });
    } else {
      // User canceled the picker
      print('MXL file selection canceled');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 500, // Set the width of the button
              height: 80, // Set the height of the button
              child: ElevatedButton(
                onPressed: _mxlFile == null ? _uploadMxl : null,
                style: ElevatedButton.styleFrom(
                  textStyle: TextStyle(fontSize: 40), // Increase font size
                  padding: EdgeInsets.all(16), // Increase padding
                ),
                child: Text(_mxlFile == null ? 'Upload .mxl File' : '.mxl File Uploaded'),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 500, // Set the width of the button
              height: 80, // Set the height of the button
              child: ElevatedButton(
                onPressed: _pdfFile == null ? _uploadPdf : null,
                style: ElevatedButton.styleFrom(
                  textStyle: TextStyle(fontSize: 40), // Increase font size
                  padding: EdgeInsets.all(16), // Increase padding
                ),
                child: Text(_pdfFile == null ? 'Upload .pdf File' : '.pdf File Uploaded'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}