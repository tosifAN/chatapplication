import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

class ImageUploader extends StatefulWidget {
  @override
  _ImageUploaderState createState() => _ImageUploaderState();
}

class _ImageUploaderState extends State<ImageUploader> {
  // Image fields
  File? _image;
  File? _compressedImage;
  int? _originalSize;
  int? _compressedSize;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        setState(() {
          _isLoading = true;
          _image = File(pickedFile.path);
          _originalSize = _image!.lengthSync();
        });

        // Compress the image
        await _compressImage(File(pickedFile.path));
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _compressImage(File file) async {
    try {
      // Get the application documents directory
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 50, // Quality ranges from 0-100
        minWidth: 1024, // Max width
        minHeight: 1024, // Max height
      );

      if (result != null) {
        setState(() {
          _compressedImage = File(result.path);
          _compressedSize = _compressedImage!.lengthSync();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error compressing image: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error compressing image')),
      );
    }
  }

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(
        title: Text('Image & Video Compression Demo'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 20),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_image != null && _compressedImage != null)
              Column(
                children: [
                  _buildImageSection('Original Image', _image!, _originalSize!),
                  SizedBox(height: 20),
                  _buildImageSection('Compressed Image', _compressedImage!, _compressedSize!),
                  SizedBox(height: 20),
                  _buildComparisonStats(),
                ],
              ),
            Divider(height: 40, thickness: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(String title, File image, int size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${_formatBytes(size)})',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.file(
            image,
            fit: BoxFit.contain,
            height: 200,
            width: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonStats() {
    if (_originalSize == null || _compressedSize == null) return SizedBox();
    final originalSizeKB = _originalSize! / 1024;
    final compressedSizeKB = _compressedSize! / 1024;
    final reduction = ((1 - (compressedSizeKB / originalSizeKB)) * 100).toStringAsFixed(2);
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Image Compression Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Original: ${_formatBytes(_originalSize!)}'),
            Text('Compressed: ${_formatBytes(_compressedSize!)}'),
            Text('Reduction: $reduction%'),
          ],
        ),
      ),
    );
  }
}


// Helper function to calculate log for web compatibility
double log(num x) => x <= 0 ? 0 : math.log(x);

// Helper function to calculate power for web compatibility
double pow(num x, num exponent) => math.pow(x, exponent).toDouble();
