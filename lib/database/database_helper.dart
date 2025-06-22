import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'database_schema.dart';
import 'queries/user_queries.dart';
import 'queries/member_queries.dart';
import 'queries/book_queries.dart';
import 'queries/loan_queries.dart';

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
    String path = join(await getDatabasesPath(), DatabaseSchema.dbName);
    return await openDatabase(
      path,
      version: DatabaseSchema.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await DatabaseSchema.onCreate(db, version);
    // Insert default admin user
    await UserQueries.insertDefaultAdmin(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await DatabaseSchema.onUpgrade(db, oldVersion, newVersion);
  }

  // ==================== USER METHODS ====================
  
  Future<Map<String, dynamic>?> authenticateUser(String email, String password) async {
    final db = await database;
    return await UserQueries.authenticateUser(db, email, password);
  }

  Future<bool> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await database;
    return await UserQueries.registerUser(
      db,
      fullName: fullName,
      email: email,
      password: password,
      role: role,
    );
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await database;
    return await UserQueries.getUserById(db, userId);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await UserQueries.getAllUsers(db);
  }

  // ==================== MEMBER METHODS ====================
  
  Future<int> insertMember(Map<String, dynamic> member) async {
    final db = await database;
    return await MemberQueries.insertMember(db, member);
  }

  Future<List<Map<String, dynamic>>> getAllMembers() async {
    final db = await database;
    return await MemberQueries.getAllMembers(db);
  }

  Future<Map<String, dynamic>?> getMemberById(int memberId) async {
    final db = await database;
    return await MemberQueries.getMemberById(db, memberId);
  }

  Future<int> updateMember(int memberId, Map<String, dynamic> member) async {
    final db = await database;
    return await MemberQueries.updateMember(db, memberId, member);
  }

  Future<int> deleteMember(int memberId) async {
    final db = await database;
    return await MemberQueries.deleteMember(db, memberId);
  }

  Future<List<Map<String, dynamic>>> searchMembers(String query) async {
    final db = await database;
    return await MemberQueries.searchMembers(db, query);
  }

  // ==================== BOOK METHODS ====================
  
  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await database;
    return await BookQueries.insertBook(db, book);
  }

  Future<List<Map<String, dynamic>>> getAllBooks() async {
    final db = await database;
    return await BookQueries.getAllBooks(db);
  }

  Future<Map<String, dynamic>?> getBookById(int bookId) async {
    final db = await database;
    return await BookQueries.getBookById(db, bookId);
  }

  Future<int> updateBook(int bookId, Map<String, dynamic> book) async {
    final db = await database;
    return await BookQueries.updateBook(db, bookId, book);
  }

  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    final db = await database;
    return await BookQueries.searchBooks(db, query);
  }

  Future<Map<String, dynamic>?> getBookByApiId(int apiBookId) async {
    final db = await database;
    return await BookQueries.getBookByApiId(db, apiBookId);
  }

  Future<int> insertApiBook(Map<String, dynamic> apiBook) async {
    final db = await database;
    return await BookQueries.insertApiBook(db, apiBook);
  }

  Future<List<Map<String, dynamic>>> getLocalBooks() async {
    final db = await database;
    return await BookQueries.getLocalBooks(db);
  }

  Future<List<Map<String, dynamic>>> getApiBooks() async {
    final db = await database;
    return await BookQueries.getApiBooks(db);
  }

  Future<List<Map<String, dynamic>>> getAvailableLocalBooks() async {
    final db = await database;
    return await BookQueries.getAvailableLocalBooks(db);
  }

  Future<List<Map<String, dynamic>>> getAvailableBooks() async {
    final db = await database;
    return await BookQueries.getAvailableBooks(db);
  }

  // ==================== LOAN METHODS ====================
  
  Future<int> insertLoan(Map<String, dynamic> loan) async {
    final db = await database;
    return await LoanQueries.insertLoan(db, loan);
  }

  Future<List<Map<String, dynamic>>> getAllLoans() async {
    final db = await database;
    return await LoanQueries.getAllLoans(db);
  }

  Future<List<Map<String, dynamic>>> getActiveLoans() async {
    final db = await database;
    return await LoanQueries.getActiveLoans(db);
  }

  Future<List<Map<String, dynamic>>> getOverdueLoans() async {
    final db = await database;
    return await LoanQueries.getOverdueLoans(db);
  }

  Future<List<Map<String, dynamic>>> getLoansByMember(int memberId) async {
    final db = await database;
    return await LoanQueries.getLoansByMember(db, memberId);
  }

  Future<Map<String, dynamic>?> getLoanById(int loanId) async {
    final db = await database;
    return await LoanQueries.getLoanById(db, loanId);
  }

  Future<Map<String, dynamic>?> getLoanWithFine(int loanId) async {
    final db = await database;
    return await LoanQueries.getLoanWithFine(db, loanId);
  }

  Future<int> returnBook(int loanId, {double? fineAmount}) async {
    final db = await database;
    return await LoanQueries.returnBook(db, loanId, fineAmount: fineAmount);
  }

  Future<int> updateLoanStatus(int loanId, String status) async {
    final db = await database;
    return await LoanQueries.updateLoanStatus(db, loanId, status);
  }

  Future<bool> canBorrowBook(int memberId, int bookId) async {
    final db = await database;
    return await LoanQueries.canBorrowBook(db, memberId, bookId);
  }

  Future<bool> canBorrowApiBook(int memberId, int apiBookId) async {
    final db = await database;
    return await LoanQueries.canBorrowApiBook(db, memberId, apiBookId);
  }

  // ==================== UTILITY METHODS ====================
  
  String formatRupiah(double amount) {
    return LoanQueries.formatRupiah(amount);
  }
  
  double calculateFine(String dueDateStr) {
    return LoanQueries.calculateFine(dueDateStr);
  }
}