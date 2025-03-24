

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class EditBooksScreen extends StatefulWidget {
  final String? newsId;
  final Map<String, dynamic>? existingData;

  EditBooksScreen({this.newsId, this.existingData});
  @override
  _EditBooksScreenState createState() => _EditBooksScreenState();
}

class _EditBooksScreenState extends State<EditBooksScreen> {
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
      // _selectedDate = (widget.existingData?['date'] as Timestamp?)?.toDate();
      _existingImageUrl = widget.existingData?['imageUrl'];
      _bookUrl = widget.existingData?['book'];


       var dateData = widget.existingData?['date'];


     if (dateData is Timestamp) {
      _selectedDate = dateData.toDate();
    } else if (dateData is String) {
      try {
        _selectedDate = DateFormat("dd.MM.yyyy, HH:mm").parse(dateData);
      } catch (e) {
        print("Error parsing date: $e");
        _selectedDate = null; // Handle invalid date format
      }
    }
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







class EditNews extends StatefulWidget {
  final String? newsId;
  final Map<String, dynamic>? existingData;

  EditNews({this.newsId, this.existingData});
  @override
  _AddNewsScreenState createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<EditNews> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedFaculty;
  DateTime? _selectedDate;
  File? _image;
  String? _existingImageUrl;
   bool _isSaving = false;

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
    'Entertainment',
    'Travel',
    'Education',
    'Environment',
  ];
  final _faculties = [
    'Computer Science and Information Technology',
    'Economics of Innovations',
    'Cyber-physical systems',
    'Biotechnology and Ecology',
    'Chemistry and Nanotechnology'
  ];

  @override
void initState() {
  super.initState();
  if (widget.existingData != null) {
    // Pre-fill fields with existing data for editing
    _titleController.text = widget.existingData?['title'] ?? '';
    _descriptionController.text = widget.existingData?['description'] ?? '';
    _selectedCategory = widget.existingData?['category'];
    _selectedFaculty = widget.existingData?['faculty'];

    // Handle the date conversion properly
    var dateData = widget.existingData?['date'];
    if (dateData is Timestamp) {
      _selectedDate = dateData.toDate();
    } else if (dateData is String) {
      try {
        _selectedDate = DateFormat("dd.MM.yyyy, HH:mm").parse(dateData);
      } catch (e) {
        print("Error parsing date: $e");
        _selectedDate = null; // Handle invalid date format
      }
    }

    _existingImageUrl = widget.existingData?['imageUrl'];
  }
}

  // Function to upload the image to GitHub
  Future<String?> _uploadImageToGitHub(File imageFile) async {
   const String token = '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'; // Replace with your GitHub token
  const String owner = 'northernwolf00'; // Replace with your GitHub username
    const String repo = 'image_upload'; // Replace with your repository name
    const String branch = 'main'; // Replace with your target branch

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

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveNews() async {
    
    if (_image == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    String? imageUrl = _existingImageUrl;
    setState(() {
      _isSaving = true; // Show the progress indicator
    });

    // Upload image to GitHub if a new image is selected
    if (_image != null) {
      try {
        imageUrl = await _uploadImageToGitHub(_image!);
        if (imageUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image')),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }
      } catch (e) {
        print('Error during image upload: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }
    }

    final formattedDate = _selectedDate != null
      ? DateFormat('dd.MM.yyyy, HH:mm').format(_selectedDate!)
      : null;

    final newsData = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'category': _selectedCategory,
      'faculty': _selectedFaculty,
      'date': formattedDate.toString(),
      'imageUrl': imageUrl,
    };

    try {
      if (widget.newsId != null) {
        // Update existing news
        await FirebaseFirestore.instance
            .collection('news')
            .doc(widget.newsId)
            .update(newsData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('News updated successfully')),
        );

      } else {
        // Add new news
        await FirebaseFirestore.instance.collection('news').add(newsData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('News added successfully')),
        );
      }
      Navigator.pop(context);
    } catch (e) {
      print('Failed to save news: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save news: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false; // Hide the progress indicator
      });
    }
  }

  // Future<void> _saveNews() async {

  //   String? imageUrl;
  //   if (_image == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Please select an image')),
  //     );
  //     return;
  //   }

  //   // Upload image to GitHub
  //   try {
  //     imageUrl = await _uploadImageToGitHub(_image!);
  //     if (imageUrl == null) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to upload image')),
  //       );
  //       return;
  //     }
  //   } catch (e) {
  //     print('Error during image upload: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to upload image: $e')),
  //     );
  //     return;
  //   }

  //   // Save news data to Firestore
  //   try {
  //     await FirebaseFirestore.instance.collection('news').add({
  //       'title': _titleController.text,
  //       'description': _descriptionController.text,
  //       'category': _selectedCategory,
  //       'faculty': _selectedFaculty,
  //       'date': _selectedDate,
  //       'imageUrl': imageUrl,
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('News added successfully')),
  //     );
  //     Navigator.pop(context);
  //   } catch (e) {
  //     print('Failed to save news: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to save news: $e')),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add News')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
              maxLines: null, // Allows multiline input
              keyboardType: TextInputType
                  .multiline, // Optimized keyboard for multiline input
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              scrollPhysics:
                  BouncingScrollPhysics(), // Enables smooth scrolling
            ),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14,),
                          ),
                      
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              decoration: InputDecoration(labelText: 'Category'),
            ),
            DropdownButtonFormField<String>(
              value: _selectedFaculty,
              items: _faculties
                  .map((faculty) => DropdownMenuItem(
                        value: faculty,
                        child: Text(faculty,
                         overflow: TextOverflow.ellipsis,
                         style: TextStyle(fontSize: 14,),),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFaculty = value;
                });
              },
              decoration: InputDecoration(labelText: 'Faculty'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectDateAndTime,
              child: Text('Select Date and Time'),
            ),
            SizedBox(height: 10),
            if (_selectedDate != null)
              Text(
                'Selected Date: ${DateFormat('dd.MM.yyyy, HH:mm').format(_selectedDate!)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              )
            else
              Text(
                'No date selected',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            SizedBox(height: 20),
            _image == null
                ? Text('No image selected')
                : Image.file(
                    _image!,
                    height: 150,
                  ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 20),
           _isSaving
                ? CircularProgressIndicator() // Show the progress indicator when saving
                : ElevatedButton(
              onPressed: _saveNews,
              child: Text('Save News'),
            ),
          ],
        ),
      ),
    );
  }
}
