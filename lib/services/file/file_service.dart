import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'package:cloudflare_r2/cloudflare_r2.dart';

class FileService {
  // Singleton pattern
  static final FileService _instance = FileService._internal();
  
  factory FileService() {
    return _instance;
  }
  
  FileService._internal();

  // Maximum file size (3MB in bytes)
  static const int maxFileSize = 3 * 1024 * 1024; // 3MB

  // Get Cloudflare R2 configuration from .env
  String get _r2Endpoint => dotenv.env['R2_ENDPOINT'] ?? '';
  String get _r2AccessKey => dotenv.env['R2_ACCESS_KEY'] ?? '';
  String get _r2SecretKey => dotenv.env['R2_SECRET_KEY'] ?? '';
  String get _r2Bucket => dotenv.env['R2_BUCKET'] ?? '';
  String get _r2PublicUrl => dotenv.env['R2_PUBLIC_URL'] ?? '';
  String get _r2AccountID => dotenv.env['R2_ACCOUNT_ID'] ?? '';

  
  // Create R2 client instance
  CloudFlareR2 _getR2Client() {
    if (_r2Endpoint.isEmpty || _r2AccessKey.isEmpty || _r2SecretKey.isEmpty || _r2Bucket.isEmpty) {
      return CloudFlareR2();
    }
    
    return CloudFlareR2.init(
    accoundId: _r2AccountID,
    accessKeyId: _r2AccessKey, 
    secretAccessKey: _r2SecretKey, 
    );
  }

  // Pick a file from device
  Future<File?> pickFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        // Check file size
        if (await file.length() > maxFileSize) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File size exceeds 3MB limit')),
            );
          }
          return null;
        }
        
        // Verify file type is allowed
        final fileExtension = path.extension(file.path).toLowerCase();
        if (!isAllowedFileType(fileExtension)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Only images, videos, and PDF files are allowed')),
            );
          }
          return null;
        }
        
        return file;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
    return null;
  }

  // Upload file to Cloudflare R2
  Future<String?> uploadFile(File file, BuildContext context) async {
    try {
      // Get file information
      final String fileExtension = path.extension(file.path);
      final String fileName = '${const Uuid().v4()}$fileExtension';
      
      // Check if R2 configuration is available
      if (_r2Endpoint.isEmpty || _r2AccessKey.isEmpty || _r2SecretKey.isEmpty || _r2Bucket.isEmpty || _r2PublicUrl.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('R2 configuration is missing or invalid')),
          );
        }
        return null;
      }
      
      // Read file content
      final Uint8List fileBytes = await file.readAsBytes();
      
      // Initialize CloudFlare R2
      CloudFlareR2.init(
        accoundId: _r2AccountID.isNotEmpty 
          ? _r2AccountID 
          : _r2Endpoint.split('.')[0].replaceAll('https://', ''),
        accessKeyId: _r2AccessKey,
        secretAccessKey: _r2SecretKey,
      );
      
      // Upload file to R2
      await CloudFlareR2.putObject(
        bucket: _r2Bucket,
        objectName: fileName,
        objectBytes: fileBytes,
        contentType: _getContentType(fileExtension),
      );
      
      // Return public URL to the file
      final fileUrl = '$_r2PublicUrl/$fileName';
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully!')),
        );
      }
      
      return fileUrl;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
      return null;
    }
  }

  // Helper method to determine content type based on file extension
  String _getContentType(String fileExtension) {
    switch (fileExtension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream'; // Default binary file type
    }
  }
  
  // Check if file type is allowed (only images, videos, and PDFs)
  bool isAllowedFileType(String fileExtension) {
    final allowed = ['.jpg', '.jpeg', '.png', '.gif', '.mp4', '.mov', '.pdf'];
    return allowed.contains(fileExtension.toLowerCase());
  }
  
  // Determine if file is an image
  bool isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif'].contains(ext);
  }
  
  // Determine if file is a video
  bool isVideoFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.mp4', '.mov'].contains(ext);
  }
  
  // Determine if file is a PDF
  bool isPdfFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.pdf';
  }
}