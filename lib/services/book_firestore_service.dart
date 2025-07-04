import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database_helper.dart';

class BookFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'books';
  static const String _syncCollection = 'sync_metadata';

  /// Get books from Firestore cache
  static Future<List<Map<String, dynamic>>> getBooksFromCache() async {
    try {
      print('Attempting to get books from Firestore cache...');
      
      // First try cache, then fallback to server if cache is empty
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('updated_at', descending: true)
          .get(const GetOptions(source: Source.cache));
      
      if (querySnapshot.docs.isEmpty) {
        print('Cache is empty, trying server...');
        querySnapshot = await _firestore
            .collection(_collection)
            .orderBy('updated_at', descending: true)
            .get(const GetOptions(source: Source.server));
      }
      
      List<Map<String, dynamic>> books = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          // Convert Firestore Timestamps to ISO strings for local storage
          if (data['created_at'] is Timestamp) {
            data['created_at'] = (data['created_at'] as Timestamp).toDate().toIso8601String();
          }
          if (data['updated_at'] is Timestamp) {
            data['updated_at'] = (data['updated_at'] as Timestamp).toDate().toIso8601String();
          }
          
          books.add(data);
        } catch (e) {
          print('Error parsing book document ${doc.id}: $e');
        }
      }
      
      print('Successfully parsed ${books.length} books from Firestore');
      return books;
    } catch (e) {
      print('Error getting books from Firestore: $e');
      return [];
    }
  }

  /// Sync books to Firestore
  static Future<List<Map<String, dynamic>>> syncToFirestore() async {
    try {
      final dbHelper = DatabaseHelper();
      final localBooks = await dbHelper.getLocalBooks();
      
      if (localBooks.isEmpty) {
        print('No local books to sync');
        return [];
      }
      
      print('Syncing ${localBooks.length} books to Firestore...');
      
      final batch = _firestore.batch();
      
      for (var book in localBooks) {
        final docRef = _firestore.collection(_collection).doc();
        Map<String, dynamic> bookData = Map<String, dynamic>.from(book);
        
        // Remove book_id as Firestore will generate its own ID
        bookData.remove('book_id');
        
        // Convert DateTime strings to Firestore Timestamps
        if (bookData['created_at'] is String) {
          bookData['created_at'] = Timestamp.fromDate(DateTime.parse(bookData['created_at']));
        }
        if (bookData['updated_at'] is String) {
          bookData['updated_at'] = Timestamp.fromDate(DateTime.parse(bookData['updated_at']));
        }
        
        batch.set(docRef, bookData);
      }
      
      await batch.commit();
      print('Successfully saved ${localBooks.length} books to Firestore');
      
      // Update sync timestamp
      await _updateSyncTimestamp();
      
      return localBooks;
    } catch (e) {
      print('Error syncing books to Firestore: $e');
      throw Exception('Error syncing books to Firestore: $e');
    }
  }

  /// Sync books from Firestore to local database
  static Future<List<Map<String, dynamic>>> syncFromFirestore() async {
    try {
      final firestoreBooks = await getBooksFromCache();
      
      if (firestoreBooks.isEmpty) {
        print('No books found in Firestore');
        return [];
      }
      
      print('Syncing ${firestoreBooks.length} books from Firestore to local database...');
      
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      
      // Clear existing books
      await db.delete('books');
      
      // Insert books from Firestore
      for (var book in firestoreBooks) {
        Map<String, dynamic> bookData = Map<String, dynamic>.from(book);
        bookData.remove('book_id'); // Let SQLite auto-generate ID
        await db.insert('books', bookData);
      }
      
      print('Successfully synced ${firestoreBooks.length} books to SQLite');
      
      // Update sync timestamp
      await _updateSyncTimestamp();
      
      return firestoreBooks;
    } catch (e) {
      print('Error syncing books from Firestore: $e');
      throw Exception('Error syncing books from Firestore: $e');
    }
  }

  /// Clear all books from Firestore
  static Future<void> clearFirestoreData() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      final batch = _firestore.batch();
      
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Successfully cleared all books from Firestore');
    } catch (e) {
      print('Error clearing Firestore data: $e');
      throw Exception('Error clearing Firestore data: $e');
    }
  }

  /// Get last sync timestamp
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final doc = await _firestore
          .collection(_syncCollection)
          .doc('books_sync')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['last_sync'] is Timestamp) {
          return (data['last_sync'] as Timestamp).toDate();
        }
      }
      return null;
    } catch (e) {
      print('Error getting last sync time: $e');
      return null;
    }
  }

  /// Update sync timestamp
  static Future<void> _updateSyncTimestamp() async {
    try {
      await _firestore.collection(_syncCollection).doc('books_sync').set({
        'last_sync': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating sync timestamp: $e');
    }
  }
  
  /// Smart sync - determines sync direction based on latest updates
  static Future<List<Map<String, dynamic>>> smartSync() async {
    try {
      print('Starting smart sync for books...');
      
      // Get latest book from SQLite
      final dbHelper = DatabaseHelper();
      final localBooks = await dbHelper.getLocalBooks();
      DateTime? latestSqliteUpdate;
      if (localBooks.isNotEmpty) {
        latestSqliteUpdate = localBooks
            .map((b) => DateTime.parse(b['updated_at']))
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      
      // Get latest book from Firestore
      final firestoreBooks = await getBooksFromCache();
      DateTime? latestFirestoreUpdate;
      if (firestoreBooks.isNotEmpty) {
        latestFirestoreUpdate = firestoreBooks
            .map((b) => DateTime.parse(b['updated_at']))
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      
      // Determine sync direction
      if (latestSqliteUpdate != null && latestFirestoreUpdate != null) {
        if (latestSqliteUpdate.isAfter(latestFirestoreUpdate)) {
          print('SQLite data is newer, syncing to Firestore');
          return await syncToFirestore();
        } else {
          print('Firestore data is newer, syncing from Firestore');
          return await syncFromFirestore();
        }
      } else if (latestSqliteUpdate != null && latestFirestoreUpdate == null) {
        print('Only SQLite has data, syncing to Firestore');
        return await syncToFirestore();
      } else if (latestSqliteUpdate == null && latestFirestoreUpdate != null) {
        print('Only Firestore has data, syncing from Firestore');
        return await syncFromFirestore();
      } else {
        print('No data found in either location');
        return [];
      }
    } catch (e) {
      print('Error in smart sync: $e');
      throw Exception('Error in smart sync: $e');
    }
  }
}