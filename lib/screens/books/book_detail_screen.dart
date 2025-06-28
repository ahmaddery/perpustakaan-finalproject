import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/book_model.dart';

class BookDetailScreen extends StatelessWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin ke clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          book.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667eea),
                    Color(0xFF764ba2),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
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
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF667eea).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                book.title[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            book.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF667eea),
                                  Color(0xFF764ba2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF667eea).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Tahun ${book.year}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Information Card
                  Card(
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: const Color(0xFF667eea)),
                              const SizedBox(width: 8),
                              const Text(
                                'Informasi Buku',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          _buildInfoRow('Penerbit', book.publisher),
                          _buildInfoRow('ISBN', book.isbn, copyable: true),
                          _buildInfoRow('Jumlah Halaman', '${book.pages} halaman'),
                          _buildInfoRow('Handle', book.handle),
                          _buildInfoRow('Dibuat', _formatDate(book.createdAt)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notes Card
                  if (book.notes.isNotEmpty) ...[
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.note_outlined, color: Colors.orange[600]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Catatan & Penghargaan',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            ...book.notes.map((note) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(top: 6, right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[600],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Villains Card
                  if (book.villains.isNotEmpty) ...[
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline, color: Colors.red[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'Karakter Penjahat (${book.villains.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            ...book.villains.map((villain) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red[200]!, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: Colors.red[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      villain.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.red[800],
                                      ),
                                    ),
                                  ),
                                  if (villain.url.isNotEmpty)
                                    IconButton(
                                      icon: Icon(
                                        Icons.link,
                                        color: Colors.red[600],
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _copyToClipboard(context, villain.url, 'URL ${villain.name}');
                                      },
                                      tooltip: 'Salin URL',
                                    ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: copyable ? () => _copyToClipboard(context, value, label) : null,
                child: Text(
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    color: copyable ? const Color(0xFF667eea) : Colors.grey[800],
                    decoration: copyable ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ),
          ),
          if (copyable)
            Builder(
              builder: (context) => IconButton(
                icon: Icon(
                  Icons.copy,
                  size: 16,
                  color: Colors.grey[600],
                ),
                onPressed: () => _copyToClipboard(context, value, label),
                tooltip: 'Salin',
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}