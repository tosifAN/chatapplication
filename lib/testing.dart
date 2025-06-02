import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudflare_r2/cloudflare_r2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class FileUploader extends StatefulWidget {
  @override
  _FileUploaderState createState() => _FileUploaderState();
}

class _FileUploaderState extends State<FileUploader> {
  String? uploadedFileUrl;

  Future<void> uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      int fileSize = await file.length();

      if (fileSize > 3 * 1024 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File size exceeds 3 GB. Please select a smaller file.')),
        );
        return;
      }

      Uint8List objectBytes = await file.readAsBytes();

      CloudFlareR2.init(
        accoundId: dotenv.env['R2_ENDPOINT']!.split('.')[0].replaceAll('https://', ''),
        accessKeyId: dotenv.env['R2_ACCESS_KEY']!,
        secretAccessKey: dotenv.env['R2_SECRET_KEY']!,
      );

      String objectName = result.files.single.name;
      String? extension = result.files.single.extension?.toLowerCase();

      // Set proper Content-Type
      String contentType = 'application/octet-stream'; // fallback
      if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'gif') {
        contentType = 'image/gif';
      } else if (extension == 'webp') {
        contentType = 'image/webp';
      }

      await CloudFlareR2.putObject(
        bucket: dotenv.env['R2_BUCKET']!,
        objectName: objectName,
        objectBytes: objectBytes,
        contentType: contentType,
      );

      setState(() {
        uploadedFileUrl = '${dotenv.env['R2_PUBLIC_URL']}/$objectName';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File uploaded successfully!')),
      );
    }
  }

  Future<void> _launchInBrowser(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: uploadFile,
          child: Text('Upload File'),
        ),
        if (uploadedFileUrl != null) ...[
          Text('File URL: $uploadedFileUrl'),
          ElevatedButton(
            onPressed: () => _launchInBrowser(uploadedFileUrl!),
            child: Text('View in Browser'),
          ),
        ],
      ],
    );
  }
}
