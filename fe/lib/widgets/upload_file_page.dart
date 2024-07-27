import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_turner/uploaded_files_model.dart';

class UploadFilePage extends StatefulWidget {
  const UploadFilePage({super.key});

  @override
  State<UploadFilePage> createState() => _UploadFilePageState();
}

class _UploadFilePageState extends State<UploadFilePage> {
  Future<void> _uploadMxl() async {
    UploadedFiles uploadedFiles = Provider.of<UploadedFiles>(context, listen: false);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      // Process the file (e.g., upload to a server or display information)
      print('MXL File: ${file.name} ${file.extension}');
      if (file.extension == 'mxl') {
        uploadedFiles.mxlFile = file;
      } else {
        print("Not an MXL file!");
      }
    } else {
      // User canceled the picker
      print('MXL file selection canceled');
    }
  }

  Future<void> _uploadPdf() async {
    UploadedFiles uploadedFiles = Provider.of<UploadedFiles>(context, listen: false);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      // Process the file (e.g., upload to a server or display information)
      print('PDF File: ${file.name}');
      uploadedFiles.pdfFile = file;
    } else {
      // User canceled the picker
      print('PDF file selection canceled');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadedFiles>(
      builder: (context, uploadedFiles, child) {
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
                    onPressed: uploadedFiles.mxlFile == null ? _uploadMxl : null,
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(fontSize: 40), // Increase font size
                      padding: EdgeInsets.all(16), // Increase padding
                    ),
                    child: Text(uploadedFiles.mxlFile == null ? 'Upload .mxl File' : '.mxl File Uploaded'),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: 500, // Set the width of the button
                  height: 80, // Set the height of the button
                  child: ElevatedButton(
                    onPressed: uploadedFiles.pdfFile == null ? _uploadPdf : null,
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(fontSize: 40), // Increase font size
                      padding: EdgeInsets.all(16), // Increase padding
                    ),
                    child: Text(uploadedFiles.pdfFile == null ? 'Upload .pdf File' : '.pdf File Uploaded'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}