
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class FileUploader extends StatefulWidget {
  @override
  _FileUploaderState createState() => _FileUploaderState();
}

class _FileUploaderState extends State<FileUploader> {

  Future<void> uploadFile() async {
    bool result = await InternetConnection().hasInternetAccess;
    print("Does have internet?: $result ");
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: uploadFile,
          child: Text('Checked Status'),
        ),
      ],
    );
  }
}
