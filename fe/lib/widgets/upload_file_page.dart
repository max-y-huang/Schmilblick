import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class UploadFilePage extends StatefulWidget {
  const UploadFilePage({super.key});

  @override
  State<UploadFilePage> createState() => _UploadFilePageState();
}

class _UploadFilePageState extends State<UploadFilePage> {
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;
      // Process the file (e.g., upload to a server or display information)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File: ${file.name}')),
      );
    } else {
      // User canceled the picker
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File selection canceled')),
      );
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
                onPressed: _pickFile,
                style: ElevatedButton.styleFrom(
                  textStyle: TextStyle(fontSize: 40), // Increase font size
                  padding: EdgeInsets.all(16), // Increase padding
                ),
                child: Text('Upload .mxl File'),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 500, // Set the width of the button
              height: 80, // Set the height of the button
              child: ElevatedButton(
                onPressed: _pickFile,
                style: ElevatedButton.styleFrom(
                  textStyle: TextStyle(fontSize: 40), // Increase font size
                  padding: EdgeInsets.all(16), // Increase padding
                ),
                child: Text('Upload .pdf File'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}