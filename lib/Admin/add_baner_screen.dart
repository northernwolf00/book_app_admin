import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class AddBannerScreen extends StatefulWidget {
  @override
  _AddBannerScreenState createState() => _AddBannerScreenState();
}

class _AddBannerScreenState extends State<AddBannerScreen> {
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _images = pickedFiles.map((file) => File(file.path)).toList();
      });
    }
  }

  Future<String?> _uploadImageToGitHub(File imageFile) async {
    const String token = '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'; 
    const String owner = 'googaMobileDev';
    const String repo = 'upload_pdf'; 
    const String branch = 'main';

    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final fileName = 'images/${path.basename(imageFile.path)}';

      final url = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/contents/$fileName');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
        body: jsonEncode({
          'message': 'Upload image $fileName',
          'content': base64Image,
          'branch': branch,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData['content']['download_url'];
      } else {
        print('Failed to upload image: ${response.statusCode}');
        print(response.body);
        return null;
      }
    } catch (e) {
      print('Error uploading image to GitHub: $e');
      return null;
    }
  }

  Future<void> _uploadBanners() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select images')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      for (var image in _images) {
        final imageUrl = await _uploadImageToGitHub(image);
        if (imageUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: ${path.basename(image.path)}')),
          );
          return;
        }

        await FirebaseFirestore.instance.collection('banners').add({
          'imageUrl': imageUrl,
          'uploadedAt': Timestamp.now(),
        });
      }
      
      setState(() => _images.clear());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Banners uploaded successfully')),
      );
    } catch (e) {
      print('Error uploading banners: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload banners: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Banners', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: Icon(Icons.image),
              label: Text('Select Images'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: _images.isEmpty
                  ? Center(child: Text('No images selected', style: TextStyle(fontSize: 16)))
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_images[index], fit: BoxFit.cover),
                        );
                      },
                    ),
            ),
            SizedBox(height: 20),
            _isUploading
                ? CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _uploadBanners,
                    icon: Icon(Icons.cloud_upload),
                    label: Text('Upload Banners'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
