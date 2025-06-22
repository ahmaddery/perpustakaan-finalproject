import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'perpustakaan.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE books (
        book_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        isbn TEXT UNIQUE,
        publisher TEXT,
        year INTEGER,
        pages INTEGER,
        category TEXT,
        stock_quantity INTEGER NOT NULL DEFAULT 1,
        api_book_id INTEGER,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        member_id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone_number TEXT,
        address TEXT,
        date_of_birth TEXT,
        membership_status TEXT NOT NULL DEFAULT 'active' CHECK (membership_status IN ('active', 'inactive', 'suspended')),
        registered_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        loan_id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        book_id INTEGER NOT NULL,
        loan_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        due_date TEXT NOT NULL,
        return_date TEXT,
        fine_amount REAL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'borrowed' CHECK (status IN ('borrowed', 'returned', 'overdue')),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (member_id) REFERENCES members(member_id),
        FOREIGN KEY (book_id) REFERENCES books(book_id)
      )
    ''');

    // Insert default admin user
    String adminPassword = _hashPassword('admin123');
    await db.insert('users', {
      'full_name': 'Administrator',
      'email': 'admin@perpustakaan.com',
      'password_hash': adminPassword,
      'role': 'admin',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE books (
          book_id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          author TEXT,
          isbn TEXT UNIQUE,
          publisher TEXT,
          year INTEGER,
          pages INTEGER,
          category TEXT,
          stock_quantity INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE members (
          member_id INTEGER PRIMARY KEY AUTOINCREMENT,
          full_name TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
          phone_number TEXT,
          address TEXT,
          date_of_birth TEXT,
          membership_status TEXT NOT NULL DEFAULT 'active' CHECK (membership_status IN ('active', 'inactive', 'suspended')),
          registered_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE loans (
          loan_id INTEGER PRIMARY KEY AUTOINCREMENT,
          member_id INTEGER NOT NULL,
          book_id INTEGER NOT NULL,
          loan_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          due_date TEXT NOT NULL,
          return_date TEXT,
          fine_amount REAL DEFAULT 0.0,
          status TEXT NOT NULL DEFAULT 'borrowed' CHECK (status IN ('borrowed', 'returned', 'overdue')),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (member_id) REFERENCES members(member_id),
          FOREIGN KEY (book_id) REFERENCES books(book_id)
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add api_book_id column to existing books table
      await db.execute('ALTER TABLE books ADD COLUMN api_book_id INTEGER');
    }

    if (oldVersion < 4) {
      // Remove available_quantity column as we only use stock_quantity now
      // SQLite doesn't support DROP COLUMN, so we need to recreate the table
      await db.execute('''
        CREATE TABLE books_new (
          book_id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          author TEXT,
          isbn TEXT UNIQUE,
          publisher TEXT,
          year INTEGER,
          pages INTEGER,
          category TEXT,
          stock_quantity INTEGER NOT NULL DEFAULT 1,
          api_book_id INTEGER,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Copy data from old table to new table
      await db.execute('''
        INSERT INTO books_new (book_id, title, author, isbn, publisher, year, pages, category, stock_quantity, api_book_id, created_at, updated_at)
        SELECT book_id, title, author, isbn, publisher, year, pages, category, stock_quantity, api_book_id, created_at, updated_at
        FROM books
      ''');

      // Drop old table and rename new table
      await db.execute('DROP TABLE books');
      await db.execute('ALTER TABLE books_new RENAME TO books');
    }
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>?> authenticateUser(
    String email,
    String password,
  ) async {
    final db = await database;
    String hashedPassword = _hashPassword(password);

    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ? AND password_hash = ? AND is_active = 1',
      whereArgs: [email, hashedPassword],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<bool> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await database;

    // Check if email already exists
    List<Map<String, dynamic>> existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (existing.isNotEmpty) {
      return false; // Email already exists
    }

    String hashedPassword = _hashPassword(password);

    try {
      await db.insert('users', {
        'full_name': fullName,
        'email': email,
        'password_hash': hashedPassword,
        'role': role,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users', where: 'is_active = 1');
  }

  // Member management methods
  Future<int> insertMember(Map<String, dynamic> member) async {
    final db = await database;
    member['registered_at'] = DateTime.now().toIso8601String();
    member['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('members', member);
  }

  Future<List<Map<String, dynamic>>> getAllMembers() async {
    final db = await database;
    return await db.query('members', orderBy: 'full_name ASC');
  }

  Future<Map<String, dynamic>?> getMemberById(int memberId) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'members',
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateMember(int memberId, Map<String, dynamic> member) async {
    final db = await database;
    member['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'members',
      member,
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
  }

  Future<int> deleteMember(int memberId) async {
    final db = await database;
    return await db.delete(
      'members',
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
  }

  Future<List<Map<String, dynamic>>> searchMembers(String query) async {
    final db = await database;
    return await db.query(
      'members',
      where: 'full_name LIKE ? OR email LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'full_name ASC',
    );
  }

  // Book management methods
  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await database;
    book['created_at'] = DateTime.now().toIso8601String();
    book['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('books', book);
  }

  Future<List<Map<String, dynamic>>> getAllBooks() async {
    final db = await database;
    return await db.query('books', orderBy: 'title ASC');
  }

  Future<Map<String, dynamic>?> getBookById(int bookId) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateBook(int bookId, Map<String, dynamic> book) async {
    final db = await database;
    book['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'books',
      book,
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    final db = await database;
    return await db.query(
      'books',
      where: 'title LIKE ? OR author LIKE ? OR isbn LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'title ASC',
    );
  }

  // Loan management methods
  Future<int> insertLoan(Map<String, dynamic> loan) async {
    final db = await database;
    loan['loan_date'] = DateTime.now().toIso8601String();
    loan['created_at'] = DateTime.now().toIso8601String();
    loan['updated_at'] = DateTime.now().toIso8601String();

    // Check if it's a local book (not API book) before updating stock
    List<Map<String, dynamic>> bookResult = await db.query(
      'books',
      where: 'book_id = ?',
      whereArgs: [loan['book_id']],
    );

    if (bookResult.isNotEmpty) {
      Map<String, dynamic> book = bookResult.first;
      // Only update stock for local books (books without api_book_id)
      // Hanya kurangi stock_quantity saja, tidak available_quantity
      if (book['api_book_id'] == null) {
        await db.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - 1 WHERE book_id = ?',
          [loan['book_id']],
        );
      }
    }

    return await db.insert('loans', loan);
  }

  Future<List<Map<String, dynamic>>> getAllLoans() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT l.*, m.full_name as member_name, b.title as book_title
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      ORDER BY l.loan_date DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getActiveLoans() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT l.*, m.full_name as member_name, b.title as book_title
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      WHERE l.status = 'borrowed'
      ORDER BY l.due_date ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getOverdueLoans() async {
    final db = await database;
    String currentDate = DateTime.now().toIso8601String();
    return await db.rawQuery(
      '''
      SELECT l.*, m.full_name as member_name, b.title as book_title
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      WHERE l.status = 'borrowed' AND l.due_date < ?
      ORDER BY l.due_date ASC
    ''',
      [currentDate],
    );
  }

  Future<List<Map<String, dynamic>>> getLoansByMember(int memberId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT l.*, b.title as book_title
      FROM loans l
      JOIN books b ON l.book_id = b.book_id
      WHERE l.member_id = ?
      ORDER BY l.loan_date DESC
    ''',
      [memberId],
    );
  }

  Future<int> returnBook(int loanId, {double? fineAmount}) async {
    final db = await database;

    // Get loan details
    List<Map<String, dynamic>> loanResult = await db.query(
      'loans',
      where: 'loan_id = ?',
      whereArgs: [loanId],
    );

    if (loanResult.isEmpty) return 0;

    Map<String, dynamic> loan = loanResult.first;

    // Calculate fine if overdue (WIB timezone)
    DateTime now = DateTime.now().add(Duration(hours: 7)); // Convert to WIB
    DateTime dueDate = DateTime.parse(loan['due_date']);
    double calculatedFine = 0.0;

    if (now.isAfter(dueDate)) {
      int overdueDays = now.difference(dueDate).inDays;
      if (overdueDays > 0) {
        calculatedFine =
            overdueDays * 5000.0; // Rp 5,000 per hari keterlambatan
      }
    }

    // Use provided fine amount or calculated fine
    double finalFine = fineAmount ?? calculatedFine;

    // Update loan record
    Map<String, dynamic> updateData = {
      'return_date': DateTime.now().toIso8601String(),
      'status': 'returned',
      'fine_amount': finalFine,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Check if it's a local book before updating stock
    List<Map<String, dynamic>> bookResult = await db.query(
      'books',
      where: 'book_id = ?',
      whereArgs: [loan['book_id']],
    );

    if (bookResult.isNotEmpty) {
      Map<String, dynamic> book = bookResult.first;
      // Only update stock for local books (books without api_book_id)
      // Hanya tambah stock_quantity saja jika buku lokal
      if (book['api_book_id'] == null) {
        await db.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + 1 WHERE book_id = ?',
          [loan['book_id']],
        );
      }
    }

    return await db.update(
      'loans',
      updateData,
      where: 'loan_id = ?',
      whereArgs: [loanId],
    );
  }

  Future<int> updateLoanStatus(int loanId, String status) async {
    final db = await database;
    return await db.update(
      'loans',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'loan_id = ?',
      whereArgs: [loanId],
    );
  }

  Future<bool> canBorrowBook(int memberId, int bookId) async {
    final db = await database;

    // Check if member has active loans for this book
    List<Map<String, dynamic>> activeLoans = await db.query(
      'loans',
      where: 'member_id = ? AND book_id = ? AND status = "borrowed"',
      whereArgs: [memberId, bookId],
    );

    if (activeLoans.isNotEmpty) return false;

    // Check book availability
    List<Map<String, dynamic>> bookResult = await db.query(
      'books',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );

    if (bookResult.isEmpty) return false;

    Map<String, dynamic> book = bookResult.first;

    // For local books, check stock quantity saja
    if (book['api_book_id'] == null) {
      return book['stock_quantity'] > 0;
    }

    // For API books, always available (unlimited stock)
    return true;
  }

  // Method to check if API book exists in local database
  Future<Map<String, dynamic>?> getBookByApiId(int apiBookId) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'api_book_id = ?',
      whereArgs: [apiBookId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Method to insert API book into local database
  Future<int> insertApiBook(Map<String, dynamic> apiBook) async {
    final db = await database;
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

  // Method to get local books only (books without api_book_id)
  Future<List<Map<String, dynamic>>> getLocalBooks() async {
    final db = await database;
    return await db.query(
      'books',
      where: 'api_book_id IS NULL',
      orderBy: 'title ASC',
    );
  }

  // Method to get API books only (books with api_book_id)
  Future<List<Map<String, dynamic>>> getApiBooks() async {
    final db = await database;
    return await db.query(
      'books',
      where: 'api_book_id IS NOT NULL',
      orderBy: 'title ASC',
    );
  }

  // Method to get available local books (local books with quantity > 0)
  Future<List<Map<String, dynamic>>> getAvailableLocalBooks() async {
    final db = await database;
    return await db.query(
      'books',
      where: 'api_book_id IS NULL AND stock_quantity > 0',
      orderBy: 'title ASC',
    );
  }

  // Method to get available books (local books with quantity > 0)
  Future<List<Map<String, dynamic>>> getAvailableBooks() async {
    final db = await database;
    return await db.query(
      'books',
      where: 'stock_quantity > 0',
      orderBy: 'title ASC',
    );
  }

  // Method to update book quantity
  // updateBookQuantity function removed - stock is now managed by insertLoan and returnBook methods

  // Method to check if member can borrow API book (no quantity limit)
  Future<bool> canBorrowApiBook(int memberId, int apiBookId) async {
    final db = await database;

    // For API books, check if member already has this book borrowed
    List<Map<String, dynamic>> activeLoans = await db.rawQuery(
      '''
      SELECT l.* FROM loans l
      JOIN books b ON l.book_id = b.book_id
      WHERE l.member_id = ? AND b.api_book_id = ? AND l.status = "borrowed"
    ''',
      [memberId, apiBookId],
    );

    return activeLoans.isEmpty;
  }

  // Helper method to format currency to Indonesian Rupiah
  String formatRupiah(double amount) {
    if (amount == 0) return 'Rp 0';

    String amountStr = amount.toStringAsFixed(0);
    String formatted = '';
    int counter = 0;

    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (counter == 3) {
        formatted = '.' + formatted;
        counter = 0;
      }
      formatted = amountStr[i] + formatted;
      counter++;
    }

    return 'Rp ' + formatted;
  }

  // Method to calculate fine for overdue loan
  double calculateFine(String dueDateStr) {
    DateTime now = DateTime.now().add(Duration(hours: 7)); // Convert to WIB
    DateTime dueDate = DateTime.parse(dueDateStr);

    if (now.isAfter(dueDate)) {
      int overdueDays = now.difference(dueDate).inDays;
      if (overdueDays > 0) {
        return overdueDays * 5000.0; // Rp 5,000 per hari keterlambatan
      }
    }

    return 0.0;
  }

  // Method to get loan with fine information
  Future<Map<String, dynamic>?> getLoanWithFine(int loanId) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT l.*, m.full_name as member_name, b.title as book_title, b.api_book_id
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      WHERE l.loan_id = ?
    ''',
      [loanId],
    );

    if (result.isEmpty) return null;

    Map<String, dynamic> loan = Map.from(result.first);

    // Calculate current fine if still borrowed
    if (loan['status'] == 'borrowed') {
      double currentFine = calculateFine(loan['due_date']);
      loan['current_fine'] = currentFine;
      loan['current_fine_formatted'] = formatRupiah(currentFine);
    }

    // Format existing fine amount
    if (loan['fine_amount'] != null) {
      loan['fine_amount_formatted'] = formatRupiah(loan['fine_amount']);
    }

    return loan;
  }

  // Note: getActiveLoans, getOverdueLoans, getMemberById, and getBookById methods already exist above

  // Method to get loans due in specific days
  Future<List<Map<String, dynamic>>> getLoansDueInDays(int days) async {
    final db = await database;
    final targetDate =
        DateTime.now()
            .add(Duration(days: days))
            .toIso8601String()
            .split('T')[0];

    return await db.query(
      'loans',
      where: 'status = ? AND due_date = ?',
      whereArgs: ['borrowed', targetDate],
      orderBy: 'due_date ASC',
    );
  }

  // Method to get loans with member and book details
  Future<List<Map<String, dynamic>>> getLoansWithDetails() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT l.*, m.full_name as member_name, m.email as member_email,
             b.title as book_title, b.author as book_author
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      WHERE l.status = 'borrowed'
      ORDER BY l.due_date ASC
    ''');
  }

  // Method to update loan status to overdue
  Future<void> updateOverdueLoans() async {
    final db = await database;
    final now = DateTime.now().toIso8601String().split('T')[0];

    await db.update(
      'loans',
      {'status': 'overdue', 'updated_at': DateTime.now().toIso8601String()},
      where: 'status = ? AND due_date < ?',
      whereArgs: ['borrowed', now],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
