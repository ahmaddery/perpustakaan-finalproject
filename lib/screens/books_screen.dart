import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';
import 'book_detail_screen.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  List<Book> books = [];
  List<Book> filteredBooks = [];
  bool isLoading = true;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'year'; // 'year', 'title'
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      List<Book> loadedBooks;
      if (_sortBy == 'year') {
        loadedBooks = await BookService.getBooksSortedByYear(ascending: _ascending);
      } else {
        loadedBooks = await BookService.getBooksSortedByTitle(ascending: _ascending);
      }
      
      setState(() {
        books = loadedBooks;
        filteredBooks = loadedBooks;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _searchBooks(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredBooks = books;
      } else {
        filteredBooks = books.where((book) => 
          book.title.toLowerCase().contains(query.toLowerCase()) ||
          book.publisher.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Urutkan Berdasarkan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  _sortBy == 'year' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: Colors.blue,
                ),
                title: const Text('Tahun'),
                onTap: () {
                  setState(() {
                    _sortBy = 'year';
                  });
                  Navigator.pop(context);
                  _loadBooks();
                },
              ),
              ListTile(
                leading: Icon(
                  _sortBy == 'title' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: Colors.blue,
                ),
                title: const Text('Judul'),
                onTap: () {
                  setState(() {
                    _sortBy = 'title';
                  });
                  Navigator.pop(context);
                  _loadBooks();
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.green,
                ),
                title: Text(_ascending ? 'A-Z / Terlama-Terbaru' : 'Z-A / Terbaru-Terlama'),
                onTap: () {
                  setState(() {
                    _ascending = !_ascending;
                  });
                  Navigator.pop(context);
                  _loadBooks();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Koleksi Buku Stephen King',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Urutkan',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBooks,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[600],
            child: TextField(
              controller: _searchController,
              onChanged: _searchBooks,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari buku atau penerbit...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          _searchBooks('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Memuat data buku...'),
                      ],
                    ),
                  )
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Terjadi Kesalahan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                errorMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadBooks,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : filteredBooks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada buku ditemukan',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadBooks,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredBooks.length,
                              itemBuilder: (context, index) {
                                final book = filteredBooks[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BookDetailScreen(book: book),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Book Icon
                                          Container(
                                            width: 60,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              color: Colors.blue[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.menu_book,
                                              size: 32,
                                              color: Colors.blue[600],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          
                                          // Book Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  book.title,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Tahun: ${book.year}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  'Penerbit: ${book.publisher}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  'Halaman: ${book.pages}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                if (book.villains.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Penjahat: ${book.villains.length}',
                                                    style: TextStyle(
                                                      color: Colors.red[600],
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          
                                          // Arrow Icon
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey[400],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}