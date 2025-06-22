import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class BooksManagementScreen extends StatefulWidget {
  const BooksManagementScreen({Key? key}) : super(key: key);

  @override
  State<BooksManagementScreen> createState() => _BooksManagementScreenState();
}

class _BooksManagementScreenState extends State<BooksManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final localBooks = await _dbHelper.getLocalBooks();
      setState(() {
        _books = localBooks;
        _filteredBooks = localBooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading books: $e')),
      );
    }
  }

  void _filterBooks(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBooks = _books;
      } else {
        _filteredBooks = _books
            .where((book) =>
                book['title'].toLowerCase().contains(query.toLowerCase()) ||
                (book['author'] ?? '').toLowerCase().contains(query.toLowerCase()) ||
                (book['isbn'] ?? '').toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showAddBookDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEditBookDialog(
        onSave: (book) async {
          try {
            await _dbHelper.insertBook(book);
            _loadBooks();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book added successfully')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error adding book: $e')),
            );
          }
        },
      ),
    );
  }

  void _showEditBookDialog(Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (context) => AddEditBookDialog(
        book: book,
        onSave: (updatedBook) async {
          try {
            await _dbHelper.updateBook(book['book_id'], updatedBook);
            _loadBooks();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book updated successfully')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating book: $e')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Books Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search books',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterBooks,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBooks.isEmpty
                    ? const Center(
                        child: Text(
                          'No books found',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = _filteredBooks[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  book['title'][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(book['title']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (book['author'] != null)
                                    Text('Author: ${book['author']}'),
                                  if (book['isbn'] != null)
                                    Text('ISBN: ${book['isbn']}'),
                                  Text('Stock: ${book['stock_quantity']}'),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditBookDialog(book);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBookDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class AddEditBookDialog extends StatefulWidget {
  final Map<String, dynamic>? book;
  final Function(Map<String, dynamic>) onSave;

  const AddEditBookDialog({
    Key? key,
    this.book,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AddEditBookDialog> createState() => _AddEditBookDialogState();
}

class _AddEditBookDialogState extends State<AddEditBookDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _isbnController;
  late TextEditingController _publisherController;
  late TextEditingController _yearController;
  late TextEditingController _pagesController;
  late TextEditingController _categoryController;
  late TextEditingController _stockController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book?['title'] ?? '');
    _authorController = TextEditingController(text: widget.book?['author'] ?? '');
    _isbnController = TextEditingController(text: widget.book?['isbn'] ?? '');
    _publisherController = TextEditingController(text: widget.book?['publisher'] ?? '');
    _yearController = TextEditingController(text: widget.book?['year']?.toString() ?? '');
    _pagesController = TextEditingController(text: widget.book?['pages']?.toString() ?? '');
    _categoryController = TextEditingController(text: widget.book?['category'] ?? '');
    _stockController = TextEditingController(text: widget.book?['stock_quantity']?.toString() ?? '1');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _pagesController.dispose();
    _categoryController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.book == null ? 'Add Book' : 'Edit Book'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter title';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(labelText: 'Author'),
              ),
              TextFormField(
                controller: _isbnController,
                decoration: const InputDecoration(labelText: 'ISBN'),
              ),
              TextFormField(
                controller: _publisherController,
                decoration: const InputDecoration(labelText: 'Publisher'),
              ),
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _pagesController,
                decoration: const InputDecoration(labelText: 'Pages'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock Quantity'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter stock quantity';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 1) {
                    return 'Please enter a valid stock quantity';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final stockQuantity = int.parse(_stockController.text);
              final book = {
                'title': _titleController.text,
                'author': _authorController.text.isEmpty ? null : _authorController.text,
                'isbn': _isbnController.text.isEmpty ? null : _isbnController.text,
                'publisher': _publisherController.text.isEmpty ? null : _publisherController.text,
                'year': _yearController.text.isEmpty ? null : int.tryParse(_yearController.text),
                'pages': _pagesController.text.isEmpty ? null : int.tryParse(_pagesController.text),
                'category': _categoryController.text.isEmpty ? null : _categoryController.text,
                'stock_quantity': stockQuantity,
              };
              widget.onSave(book);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}