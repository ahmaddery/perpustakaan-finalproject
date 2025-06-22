import 'package:sqflite/sqflite.dart';

class BookQueries {
  /// Insert a new book
  static Future<int> insertBook(
    Database db,
    Map<String, dynamic> book,
  ) async {
    book['created_at'] = DateTime.now().toIso8601String();
    book['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('books', book);
  }

  /// Get all books
  static Future<List<Map<String, dynamic>>> getAllBooks(Database db) async {
    return await db.query('books', orderBy: 'title ASC');
  }

  /// Get book by ID
  static Future<Map<String, dynamic>?> getBookById(
    Database db,
    int bookId,
  ) async {
    List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Update book information
  static Future<int> updateBook(
    Database db,
    int bookId,
    Map<String, dynamic> book,
  ) async {
    book['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'books',
      book,
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  /// Search books by title, author, or ISBN
  static Future<List<Map<String, dynamic>>> searchBooks(
    Database db,
    String query,
  ) async {
    return await db.query(
      'books',
      where: 'title LIKE ? OR author LIKE ? OR isbn LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'title ASC',
    );
  }

  /// Get book by API ID
  static Future<Map<String, dynamic>?> getBookByApiId(
    Database db,
    int apiBookId,
  ) async {
    List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'api_book_id = ?',
      whereArgs: [apiBookId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Insert API book into local database
  static Future<int> insertApiBook(
    Database db,
    Map<String, dynamic> apiBook,
  ) async {
    Map<String, dynamic> bookData = {
      'api_book_id': apiBook['id'],
      'title': apiBook['title'],
      'author': 'Stephen King', // Default author for API books
      'publisher': apiBook['publisher'],
      'year': apiBook['year'],
      'isbn': apiBook['isbn'],
      'pages': apiBook['pages'],
      'category': apiBook['category'] ?? 'Fiction',
      'stock_quantity': 1, // API books have unlimited availability
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    return await db.insert('books', bookData);
  }

  /// Get local books only (books without api_book_id)
  static Future<List<Map<String, dynamic>>> getLocalBooks(Database db) async {
    return await db.query(
      'books',
      where: 'api_book_id IS NULL',
      orderBy: 'title ASC',
    );
  }

  /// Get API books only (books with api_book_id)
  static Future<List<Map<String, dynamic>>> getApiBooks(Database db) async {
    return await db.query(
      'books',
      where: 'api_book_id IS NOT NULL',
      orderBy: 'title ASC',
    );
  }

  /// Get available local books (local books with quantity > 0)
  static Future<List<Map<String, dynamic>>> getAvailableLocalBooks(Database db) async {
    return await db.query(
      'books',
      where: 'api_book_id IS NULL AND stock_quantity > 0',
      orderBy: 'title ASC',
    );
  }

  /// Get available books (books with quantity > 0)
  static Future<List<Map<String, dynamic>>> getAvailableBooks(Database db) async {
    return await db.query(
      'books',
      where: 'stock_quantity > 0',
      orderBy: 'title ASC',
    );
  }

  /// Update book stock quantity
  static Future<void> decreaseStock(Database db, int bookId) async {
    await db.rawUpdate(
      'UPDATE books SET stock_quantity = stock_quantity - 1 WHERE book_id = ?',
      [bookId],
    );
  }

  /// Increase book stock quantity
  static Future<void> increaseStock(Database db, int bookId) async {
    await db.rawUpdate(
      'UPDATE books SET stock_quantity = stock_quantity + 1 WHERE book_id = ?',
      [bookId],
    );
  }
}