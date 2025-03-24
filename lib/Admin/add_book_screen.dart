import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class AddBooksScreen extends StatefulWidget {
  final String? newsId;
  final Map<String, dynamic>? existingData;

  AddBooksScreen({this.newsId, this.existingData});
  @override
  _AddBooksScreenState createState() => _AddBooksScreenState();
}

class _AddBooksScreenState extends State<AddBooksScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _authorNameController = TextEditingController();
  String? _selectedCategory;
  DateTime? _selectedDate;
  File? _image;
  File? _pdfBook;
  String? _existingImageUrl;
  String? _bookUrl;
  bool _isSaving = false;
  String? _pickedBookName;

  Future<void> _selectDateAndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  final _categories = [
    'Politics',
    'Sports',
    'Technology',
    'Health',
    'Business',
    'Science',
    'History',
    'Biography',
    'Education',
    'Environment',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _titleController.text = widget.existingData?['title'] ?? '';
       _authorNameController.text = widget.existingData?['author_name'] ?? '';
      _descriptionController.text = widget.existingData?['description'] ?? '';
      _selectedCategory = widget.existingData?['category'];
      _selectedDate = (widget.existingData?['date'] as Timestamp?)?.toDate();
      _existingImageUrl = widget.existingData?['imageUrl'];
      _bookUrl = widget.existingData?['book'];
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickBook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfBook = File(result.files.single.path!);
        _pickedBookName = path.basename(result.files.single.path!);
      });
    }
  }

  Future<String?> _uploadFileToGitHub(File file, String folder) async {
    const String token = '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';
    const String owner = 'googaMobileDev';
    const String repo = 'upload_pdf';
    const String branch = 'main';

    try {
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);
      final fileName = '$folder/${path.basename(file.path)}';

      final url = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/contents/$fileName');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
        body: jsonEncode({
          'message': 'Upload file $fileName',
          'content': base64File,
          'branch': branch,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData['content']['download_url'];
      } else {
        print('Failed to upload file: ${response.statusCode}');
        print(response.body);
        return null;
      }
    } catch (e) {
      print('Error uploading file to GitHub: $e');
      return null;
    }
  }

  Future<void> _saveBooks() async {
    if (_image == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please select an image')));
      return;
    }
    if (_pdfBook == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please select a book PDF')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String? imageUrl = _existingImageUrl;
    String? bookUrl = _bookUrl;

    if (_image != null) {
      imageUrl = await _uploadFileToGitHub(_image!, 'images');
      if (imageUrl == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to upload image')));
        setState(() {
          _isSaving = false;
        });
        return;
      }
    }

    if (_pdfBook != null) {
      bookUrl = await _uploadFileToGitHub(_pdfBook!, 'books');
      if (bookUrl == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to upload book')));
        setState(() {
          _isSaving = false;
        });
        return;
      }
    }

    final formattedDate = _selectedDate != null
        ? DateFormat('dd.MM.yyyy, HH:mm').format(_selectedDate!)
        : null;

    final booksData = {
      'title': _titleController.text,
      'author_name': _authorNameController.text,
      'description': _descriptionController.text,
      'category': _selectedCategory,
      'book': bookUrl,
      'date': formattedDate.toString(),
      'imageUrl': imageUrl,
    };

    try {
      if (widget.newsId != null) {
        await FirebaseFirestore.instance
            .collection('books')
            .doc(widget.newsId)
            .update(booksData);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Book updated successfully')));
      } else {
        await FirebaseFirestore.instance.collection('books').add(booksData);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Book added successfully')));
      }
      Navigator.pop(context);
    } catch (e) {
      print('Failed to save book: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save book: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Book')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                      labelText: 'Title', border: OutlineInputBorder()),
                ),
                SizedBox(height: 12),
                  
                TextField(
                  controller: _authorNameController,  // Author name text field
                  decoration: InputDecoration(
                      labelText: 'Author Name', border: OutlineInputBorder()),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                      labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: _categories
                      .map((category) => DropdownMenuItem(
                          value: category, child: Text(category)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                  decoration: InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _selectDateAndTime,
                  icon: Icon(Icons.calendar_today),
                  label: Text(_selectedDate == null
                      ? 'Select Date'
                      : 'Selected: ${DateFormat('dd.MM.yyyy, HH:mm').format(_selectedDate!)}'),
                ),
                ElevatedButton(
                  onPressed: _pickBook,
                  child: Text('Pick PDF Book'),
                ),
                if (_pickedBookName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Picked Book: $_pickedBookName',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                SizedBox(height: 12),
                Center(
                  child: _image == null
                      ? Text('No image selected',
                          style: TextStyle(color: Colors.grey))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_image!,
                              height: 150, width: 150, fit: BoxFit.cover),
                        ),
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.image),
                  label: Text('Pick Image'),
                ),
                SizedBox(height: 20),
                Center(
                  child: _isSaving
                      ? CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _saveBooks,
                          icon: Icon(Icons.save),
                          label: Text('Save Book'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
