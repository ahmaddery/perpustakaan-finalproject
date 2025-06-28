import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading books: $e')));
    }
  }

  void _filterBooks(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBooks = _books;
      } else {
        _filteredBooks =
            _books
                .where(
                  (book) =>
                      book['title'].toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      (book['author'] ?? '').toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      (book['isbn'] ?? '').toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
      }
    });
  }

  void _showAddBookDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AddEditBookDialog(
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
      builder:
          (context) => AddEditBookDialog(
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Books Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search books, authors, or ISBN...',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    onChanged: _filterBooks,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Books: ${_filteredBooks.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.library_books,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Library',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF667eea),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading books...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _filteredBooks.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_books_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No books found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or add new books',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredBooks.length,
                      itemBuilder: (context, index) {
                        final book = _filteredBooks[index];
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          curve: Curves.easeOutBack,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.white, Colors.grey[50]!],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF667eea),
                                            Color(0xFF764ba2),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(
                                              0xFF667eea,
                                            ).withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          book['title'][0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            book['title'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D3748),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          if (book['author'] != null)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person_outline,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    book['author'],
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (book['isbn'] != null)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.qr_code,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  book['isbn'],
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  book['stock_quantity'] > 0
                                                      ? Colors.green
                                                          .withOpacity(0.1)
                                                      : Colors.red.withOpacity(
                                                        0.1,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color:
                                                    book['stock_quantity'] > 0
                                                        ? Colors.green
                                                        : Colors.red,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  book['stock_quantity'] > 0
                                                      ? Icons
                                                          .check_circle_outline
                                                      : Icons.warning_outlined,
                                                  size: 16,
                                                  color:
                                                      book['stock_quantity'] > 0
                                                          ? Colors.green
                                                          : Colors.red,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Stock: ${book['stock_quantity']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        book['stock_quantity'] >
                                                                0
                                                            ? Colors.green
                                                            : Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: PopupMenuButton(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.grey[600],
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        itemBuilder:
                                            (context) => [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit_outlined,
                                                      size: 18,
                                                      color: Color(0xFF667eea),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Edit Book',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF667eea,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEditBookDialog(book);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF667eea).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddBookDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class AddEditBookDialog extends StatefulWidget {
  final Map<String, dynamic>? book;
  final Function(Map<String, dynamic>) onSave;

  const AddEditBookDialog({Key? key, this.book, required this.onSave})
    : super(key: key);

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
    _authorController = TextEditingController(
      text: widget.book?['author'] ?? '',
    );
    _isbnController = TextEditingController(text: widget.book?['isbn'] ?? '');
    _publisherController = TextEditingController(
      text: widget.book?['publisher'] ?? '',
    );
    _yearController = TextEditingController(
      text: widget.book?['year']?.toString() ?? '',
    );
    _pagesController = TextEditingController(
      text: widget.book?['pages']?.toString() ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.book?['category'] ?? '',
    );
    _stockController = TextEditingController(
      text: widget.book?['stock_quantity']?.toString() ?? '1',
    );
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey[50]!],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.book == null ? Icons.add : Icons.edit,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book == null ? 'Add New Book' : 'Edit Book',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.book == null
                              ? 'Fill in the book details below'
                              : 'Update the book information',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _titleController,
                        label: 'Book Title',
                        icon: Icons.book,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter book title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _authorController,
                        label: 'Author',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _isbnController,
                        label: 'ISBN',
                        icon: Icons.qr_code,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _publisherController,
                        label: 'Publisher',
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _yearController,
                              label: 'Year',
                              icon: Icons.calendar_today,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _pagesController,
                              label: 'Pages',
                              icon: Icons.description,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _categoryController,
                        label: 'Category',
                        icon: Icons.category,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _stockController,
                        label: 'Stock Quantity',
                        icon: Icons.inventory,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter stock quantity';
                          }
                          if (int.tryParse(value) == null ||
                              int.parse(value) < 1) {
                            return 'Please enter a valid stock quantity';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF667eea).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final stockQuantity = int.parse(
                              _stockController.text,
                            );
                            final book = {
                              'title': _titleController.text,
                              'author':
                                  _authorController.text.isEmpty
                                      ? null
                                      : _authorController.text,
                              'isbn':
                                  _isbnController.text.isEmpty
                                      ? null
                                      : _isbnController.text,
                              'publisher':
                                  _publisherController.text.isEmpty
                                      ? null
                                      : _publisherController.text,
                              'year':
                                  _yearController.text.isEmpty
                                      ? null
                                      : int.tryParse(_yearController.text),
                              'pages':
                                  _pagesController.text.isEmpty
                                      ? null
                                      : int.tryParse(_pagesController.text),
                              'category':
                                  _categoryController.text.isEmpty
                                      ? null
                                      : _categoryController.text,
                              'stock_quantity': stockQuantity,
                            };
                            widget.onSave(book);
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Book',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }
}
