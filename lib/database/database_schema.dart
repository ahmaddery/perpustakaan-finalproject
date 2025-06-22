import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  static const String dbName = 'perpustakaan.db';
  static const int dbVersion = 4;

  // Table creation queries
  static const String createUsersTable = '''
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
  ''';

  static const String createBooksTable = '''
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
  ''';

  static const String createMembersTable = '''
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
  ''';

  static const String createLoansTable = '''
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
  ''';

  // Migration queries
  static const String addApiBookIdColumn = 'ALTER TABLE books ADD COLUMN api_book_id INTEGER';

  static const String createBooksNewTable = '''
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
  ''';

  static const String copyBooksData = '''
    INSERT INTO books_new (book_id, title, author, isbn, publisher, year, pages, category, stock_quantity, api_book_id, created_at, updated_at)
    SELECT book_id, title, author, isbn, publisher, year, pages, category, stock_quantity, api_book_id, created_at, updated_at
    FROM books
  ''';

  static const String dropOldBooksTable = 'DROP TABLE books';
  static const String renameBooksTable = 'ALTER TABLE books_new RENAME TO books';

  /// Execute database creation
  static Future<void> onCreate(Database db, int version) async {
    await db.execute(createUsersTable);
    await db.execute(createBooksTable);
    await db.execute(createMembersTable);
    await db.execute(createLoansTable);
  }

  /// Execute database upgrades
  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(createBooksTable);
      await db.execute(createMembersTable);
      await db.execute(createLoansTable);
    }
    
    if (oldVersion < 3) {
      await db.execute(addApiBookIdColumn);
    }
    
    if (oldVersion < 4) {
      // Remove available_quantity column as we only use stock_quantity now
      // SQLite doesn't support DROP COLUMN, so we need to recreate the table
      await db.execute(createBooksNewTable);
      await db.execute(copyBooksData);
      await db.execute(dropOldBooksTable);
      await db.execute(renameBooksTable);
    }
  }
}