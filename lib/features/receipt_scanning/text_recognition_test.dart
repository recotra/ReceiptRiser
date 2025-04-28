import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';

class TextRecognitionTest extends StatefulWidget {
  const TextRecognitionTest({super.key});

  @override
  State<TextRecognitionTest> createState() => _TextRecognitionTestState();
}

class _TextRecognitionTestState extends State<TextRecognitionTest> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String _recognizedText = '';
  bool _isProcessing = false;

  Future<void> _getImageAndRecognizeText(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isProcessing = true;
        _recognizedText = '';
      });
      
      // Process the image
      final inputImage = InputImage.fromFile(_image!);
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      
      try {
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        String text = '';
        
        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            text += '${line.text}\n';
          }
        }
        
        setState(() {
          _recognizedText = text;
          _isProcessing = false;
        });
      } catch (e) {
        setState(() {
          _recognizedText = 'Error recognizing text: $e';
          _isProcessing = false;
        });
      } finally {
        textRecognizer.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Recognition Test'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            if (_image != null)
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.file(_image!, fit: BoxFit.contain),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _getImageAndRecognizeText(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () => _getImageAndRecognizeText(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isProcessing)
              const CircularProgressIndicator()
            else if (_recognizedText.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _recognizedText,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
