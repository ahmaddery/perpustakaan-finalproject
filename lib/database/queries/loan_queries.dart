import 'package:sqflite/sqflite.dart';
import 'book_queries.dart';

class LoanQueries {
  /// Insert a new loan
  static Future<int> insertLoan(
    Database db,
    Map<String, dynamic> loan,
  ) async {
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
      if (book['api_book_id'] == null) {
        await BookQueries.decreaseStock(db, loan['book_id']);
      }
    }
    
    return await db.insert('loans', loan);
  }

  /// Get all loans with member and book information
  static Future<List<Map<String, dynamic>>> getAllLoans(Database db) async {
    return await db.rawQuery('''
      SELECT l.*, m.full_name as member_name, b.title as book_title
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      ORDER BY l.loan_date DESC
    ''');
  }

  /// Get active loans (borrowed status)
  static Future<List<Map<String, dynamic>>> getActiveLoans(Database db) async {
    return await db.rawQuery('''
      SELECT l.*, m.full_name as member_name, b.title as book_title
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      WHERE l.status = 'borrowed'
      ORDER BY l.due_date ASC
    ''');
  }

  /// Get overdue loans
  static Future<List<Map<String, dynamic>>> getOverdueLoans(Database db) async {
    String currentDate = DateTime.now().toIso8601String();
    return await db.rawQuery('''
      SELECT l.*, m.full_name as member_name, b.title as book_title
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      WHERE l.status = 'borrowed' AND l.due_date < ?
      ORDER BY l.due_date ASC
    ''', [currentDate]);
  }

  /// Get loans by member ID
  static Future<List<Map<String, dynamic>>> getLoansByMember(
    Database db,
    int memberId,
  ) async {
    return await db.rawQuery('''
      SELECT l.*, b.title as book_title
      FROM loans l
      JOIN books b ON l.book_id = b.book_id
      WHERE l.member_id = ?
      ORDER BY l.loan_date DESC
    ''', [memberId]);
  }

  /// Get loan by ID
  static Future<Map<String, dynamic>?> getLoanById(
    Database db,
    int loanId,
  ) async {
    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT l.*, m.full_name as member_name, m.email as member_email, 
             b.title as book_title, b.author as book_author
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      WHERE l.loan_id = ?
    ''', [loanId]);
    return result.isNotEmpty ? result.first : null;
  }

  /// Get loan with fine calculation
  static Future<Map<String, dynamic>?> getLoanWithFine(
    Database db,
    int loanId,
  ) async {
    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT l.*, m.full_name as member_name, m.email as member_email, 
             b.title as book_title, b.author as book_author
      FROM loans l
      JOIN members m ON l.member_id = m.member_id
      JOIN books b ON l.book_id = b.book_id
      WHERE l.loan_id = ?
    ''', [loanId]);
    
    if (result.isEmpty) return null;
    
    Map<String, dynamic> loan = Map<String, dynamic>.from(result.first);
    
    // Calculate fine if loan is still active and overdue
    if (loan['status'] == 'borrowed') {
      double calculatedFine = calculateFine(loan['due_date']);
      loan['calculated_fine'] = calculatedFine;
    } else {
      // For returned loans, use the stored fine amount
      loan['calculated_fine'] = loan['fine_amount'] ?? 0.0;
    }
    
    return loan;
  }

  /// Return a book
  static Future<int> returnBook(
    Database db,
    int loanId, {
    double? fineAmount,
  }) async {
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
    
    // Compare dates only (without time)
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    
    if (today.isAfter(dueDateOnly)) {
      int overdueDays = today.difference(dueDateOnly).inDays;
      if (overdueDays > 0) {
        calculatedFine = overdueDays * 5000.0; // Rp 5,000 per hari keterlambatan
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
      if (book['api_book_id'] == null) {
        await BookQueries.increaseStock(db, loan['book_id']);
      }
    }
    
    return await db.update(
      'loans',
      updateData,
      where: 'loan_id = ?',
      whereArgs: [loanId],
    );
  }

  /// Update loan status
  static Future<int> updateLoanStatus(
    Database db,
    int loanId,
    String status,
  ) async {
    return await db.update(
      'loans',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'loan_id = ?',
      whereArgs: [loanId],
    );
  }

  /// Check if member can borrow a book
  static Future<bool> canBorrowBook(
    Database db,
    int memberId,
    int bookId,
  ) async {
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
    
    // For local books, check stock quantity
    if (book['api_book_id'] == null) {
      return book['stock_quantity'] > 0;
    }
    
    // For API books, always available (unlimited stock)
    return true;
  }

  /// Check if member can borrow API book (no quantity limit)
  static Future<bool> canBorrowApiBook(
    Database db,
    int memberId,
    int apiBookId,
  ) async {
    // For API books, check if member already has this book borrowed
    List<Map<String, dynamic>> activeLoans = await db.rawQuery('''
      SELECT l.* FROM loans l
      JOIN books b ON l.book_id = b.book_id
      WHERE l.member_id = ? AND b.api_book_id = ? AND l.status = "borrowed"
    ''', [memberId, apiBookId]);
    
    return activeLoans.isEmpty;
  }

  /// Calculate fine for overdue loan
  static double calculateFine(String dueDateStr) {
    DateTime now = DateTime.now().add(Duration(hours: 7)); // WIB timezone
    DateTime dueDate = DateTime.parse(dueDateStr);
    
    // Compare dates only (without time)
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    
    if (today.isAfter(dueDateOnly)) {
      int overdueDays = today.difference(dueDateOnly).inDays;
      if (overdueDays > 0) {
        return overdueDays * 5000.0; // Rp 5,000 per hari keterlambatan
      }
    }
    
    return 0.0;
  }

  /// Format currency to Indonesian Rupiah
  static String formatRupiah(double amount) {
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
}