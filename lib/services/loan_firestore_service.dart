import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan_model.dart';
import '../database/database_helper.dart';

class LoanFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'loans';
  static const String _syncCollection = 'sync_metadata';
  
  /// Get loans from Firestore cache
  static Future<List<Loan>> getLoansFromCache() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('updated_at', descending: true)
          .get(const GetOptions(source: Source.cache));
      
      List<Loan> loans = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data();
          
          // Convert Firestore Timestamps to ISO strings
          if (data['loan_date'] is Timestamp) {
            data['loan_date'] = (data['loan_date'] as Timestamp).toDate().toIso8601String();
          }
          if (data['due_date'] is Timestamp) {
            data['due_date'] = (data['due_date'] as Timestamp).toDate().toIso8601String();
          }
          if (data['return_date'] is Timestamp) {
            data['return_date'] = (data['return_date'] as Timestamp).toDate().toIso8601String();
          }
          if (data['created_at'] is Timestamp) {
            data['created_at'] = (data['created_at'] as Timestamp).toDate().toIso8601String();
          }
          if (data['updated_at'] is Timestamp) {
            data['updated_at'] = (data['updated_at'] as Timestamp).toDate().toIso8601String();
          }
          
          loans.add(Loan.fromJson(data));
        } catch (e) {
          print('Error parsing loan document ${doc.id}: $e');
        }
      }
      
      return loans;
    } catch (e) {
      print('Error getting loans from cache: $e');
      return [];
    }
  }
  
  /// Sync loans from SQLite to Firestore
  static Future<List<Loan>> syncToFirestore() async {
    try {
      final dbHelper = DatabaseHelper();
      final loansData = await dbHelper.getAllLoans();
      final loans = loansData.map((data) => Loan.fromJson(data)).toList();
      
      if (loans.isEmpty) {
        print('No loans to sync to Firestore');
        return [];
      }
      
      final batch = _firestore.batch();
      
      for (var loan in loans) {
        final docRef = _firestore.collection(_collection).doc(loan.loanId.toString());
        Map<String, dynamic> loanData = loan.toJson();
        
        // Convert ISO strings to Firestore Timestamps
        loanData['loan_date'] = Timestamp.fromDate(loan.loanDate);
        loanData['due_date'] = Timestamp.fromDate(loan.dueDate);
        if (loan.returnDate != null) {
          loanData['return_date'] = Timestamp.fromDate(loan.returnDate!);
        }
        loanData['created_at'] = Timestamp.fromDate(loan.createdAt);
        loanData['updated_at'] = Timestamp.fromDate(loan.updatedAt);
        
        batch.set(docRef, loanData, SetOptions(merge: true));
      }
      
      await batch.commit();
      print('Successfully saved ${loans.length} loans to Firestore');
      
      // Update sync timestamp
      await _updateSyncTimestamp();
      
      return loans;
    } catch (e) {
      print('Error syncing loans to Firestore: $e');
      throw Exception('Error syncing loans to Firestore: $e');
    }
  }
  
  /// Sync loans from Firestore to SQLite
  static Future<List<Loan>> syncFromFirestore() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('updated_at', descending: true)
          .get();
      
      List<Loan> firestoreLoans = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data();
          
          // Convert Firestore Timestamps to ISO strings
          if (data['loan_date'] is Timestamp) {
            data['loan_date'] = (data['loan_date'] as Timestamp).toDate().toIso8601String();
          }
          if (data['due_date'] is Timestamp) {
            data['due_date'] = (data['due_date'] as Timestamp).toDate().toIso8601String();
          }
          if (data['return_date'] is Timestamp) {
            data['return_date'] = (data['return_date'] as Timestamp).toDate().toIso8601String();
          }
          if (data['created_at'] is Timestamp) {
            data['created_at'] = (data['created_at'] as Timestamp).toDate().toIso8601String();
          }
          if (data['updated_at'] is Timestamp) {
            data['updated_at'] = (data['updated_at'] as Timestamp).toDate().toIso8601String();
          }
          
          firestoreLoans.add(Loan.fromJson(data));
        } catch (e) {
          print('Error parsing loan document ${doc.id}: $e');
        }
      }
      
      if (firestoreLoans.isEmpty) {
        print('No loans found in Firestore');
        return [];
      }
      
      // Clear existing loans and insert new ones
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      
      await db.delete('loans');
      
      for (var loan in firestoreLoans) {
        Map<String, dynamic> loanData = loan.toJson();
        loanData.remove('loan_id'); // Let SQLite auto-generate ID
        await db.insert('loans', loanData);
      }
      
      print('Successfully synced ${firestoreLoans.length} loans to SQLite');
      
      // Update sync timestamp
      await _updateSyncTimestamp();
      
      return firestoreLoans;
    } catch (e) {
      print('Error syncing loans from Firestore: $e');
      throw Exception('Error syncing loans from Firestore: $e');
    }
  }
  
  /// Clear all loans from Firestore
  static Future<void> clearFirestoreData() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      final batch = _firestore.batch();
      
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Successfully cleared all loans from Firestore');
    } catch (e) {
      print('Error clearing Firestore data: $e');
      throw Exception('Error clearing Firestore data: $e');
    }
  }
  
  /// Check if Firestore has cached data
  static Future<bool> hasFirestoreCache() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .limit(1)
          .get(const GetOptions(source: Source.cache));

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Get last sync timestamp
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final doc = await _firestore
          .collection(_syncCollection)
          .doc('loans_sync')
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
      await _firestore
          .collection(_syncCollection)
          .doc('loans_sync')
          .set({
        'last_sync': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating sync timestamp: $e');
    }
  }
  
  /// Smart sync - determines sync direction based on latest updates
  static Future<List<Loan>> smartSync() async {
    try {
      // Get latest loan from SQLite
      final dbHelper = DatabaseHelper();
      final sqliteLoans = await dbHelper.getAllLoans();
      DateTime? latestSQLiteUpdate;
      if (sqliteLoans.isNotEmpty) {
        latestSQLiteUpdate = sqliteLoans
            .map((l) => DateTime.parse(l['updated_at']))
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      
      // Get latest loan from Firestore
      final firestoreLoans = await getLoansFromCache();
      DateTime? latestFirestoreUpdate;
      if (firestoreLoans.isNotEmpty) {
        latestFirestoreUpdate = firestoreLoans
            .map((l) => l.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      
      // Determine sync direction
      if (latestSQLiteUpdate == null && latestFirestoreUpdate == null) {
        print('No data found in either database');
        return [];
      } else if (latestSQLiteUpdate == null) {
        print('SQLite is empty, syncing from Firestore');
        return await syncFromFirestore();
      } else if (latestFirestoreUpdate == null) {
        print('Firestore is empty, syncing to Firestore');
        return await syncToFirestore();
      } else if (latestSQLiteUpdate.isAfter(latestFirestoreUpdate)) {
        print('SQLite is newer, syncing to Firestore');
        return await syncToFirestore();
      } else {
        print('Firestore is newer, syncing from Firestore');
        return await syncFromFirestore();
      }
    } catch (e) {
      print('Error in smart sync: $e');
      throw Exception('Error in smart sync: $e');
    }
  }
}