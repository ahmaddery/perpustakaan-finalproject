import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';
import '../database/database_helper.dart';

class MemberFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'members';
  static const String _syncCollection = 'sync_metadata';

  /// Get members from Firestore cache
  static Future<List<Member>> getMembersFromCache() async {
    try {
      print('Attempting to get members from Firestore cache...');
      
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

      List<Member> members = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['member_id'] = doc.id; // Use Firestore document ID
          
          // Convert Firestore Timestamp to DateTime string
          if (data['registered_at'] is Timestamp) {
            data['registered_at'] = (data['registered_at'] as Timestamp).toDate().toIso8601String();
          }
          if (data['updated_at'] is Timestamp) {
            data['updated_at'] = (data['updated_at'] as Timestamp).toDate().toIso8601String();
          }
          
          members.add(Member.fromJson(data));
        } catch (e) {
          print('Error parsing member document ${doc.id}: $e');
        }
      }
      
      print('Successfully parsed ${members.length} members from Firestore');
      return members;
    } catch (e) {
      print('Error getting members from Firestore: $e');
      return [];
    }
  }

  /// Sync members from SQLite to Firestore
  static Future<List<Member>> syncMembersToFirestore() async {
    try {
      print('Starting member sync to Firestore...');
      
      // Get all members from SQLite
      final dbHelper = DatabaseHelper();
      final membersData = await dbHelper.getAllMembers();
      final backendMembers = membersData.map((data) => Member.fromJson(data)).toList();
      
      print('Found ${backendMembers.length} members in SQLite');
      
      // Clear existing Firestore data
      await _clearAllMembers();
      
      // Batch write to Firestore
      final batch = _firestore.batch();
      
      for (var member in backendMembers) {
        final docRef = _firestore.collection(_collection).doc();
        Map<String, dynamic> memberData = member.toJson();
        
        // Remove member_id as Firestore will generate its own ID
        memberData.remove('member_id');
        
        // Convert DateTime strings to Firestore Timestamps
        memberData['registered_at'] = Timestamp.fromDate(member.registeredAt);
        memberData['updated_at'] = Timestamp.fromDate(member.updatedAt);
        
        batch.set(docRef, memberData);
      }
      
      await batch.commit();
      print('Successfully saved ${backendMembers.length} members to Firestore');
      
      // Update sync timestamp
      await _updateSyncTimestamp();
      
      return backendMembers;
    } catch (e) {
      print('Error syncing members: $e');
      throw Exception('Error syncing members: $e');
    }
  }

  /// Sync members from Firestore to SQLite
  static Future<List<Member>> syncMembersFromFirestore() async {
    try {
      print('Starting member sync from Firestore...');
      
      // Get members from Firestore
      final firestoreMembers = await getMembersFromCache();
      
      if (firestoreMembers.isEmpty) {
        print('No members found in Firestore');
        return [];
      }
      
      print('Found ${firestoreMembers.length} members in Firestore');
      
      // Clear SQLite and insert Firestore data
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      
      // Clear existing SQLite data
      await db.delete('members');
      
      // Insert Firestore data to SQLite
      for (var member in firestoreMembers) {
        Map<String, dynamic> memberData = member.toJson();
        memberData.remove('member_id'); // Let SQLite auto-generate ID
        await db.insert('members', memberData);
      }
      
      print('Successfully synced ${firestoreMembers.length} members to SQLite');
      
      // Update sync timestamp
      await _updateSyncTimestamp();
      
      return firestoreMembers;
    } catch (e) {
      print('Error syncing members from Firestore: $e');
      throw Exception('Error syncing members from Firestore: $e');
    }
  }

  /// Clear all members from Firestore
  static Future<void> _clearAllMembers() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Cleared all members from Firestore');
    } catch (e) {
      print('Error clearing members from Firestore: $e');
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
          .doc('members_sync')
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
          .doc('members_sync')
          .set({
        'last_sync': FieldValue.serverTimestamp(),
        'collection': 'members',
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating sync timestamp: $e');
    }
  }

  /// Smart sync - determines sync direction based on last modification
  static Future<List<Member>> smartSync() async {
    try {
      // Get last sync time
      final lastSyncTime = await getLastSyncTime();
      
      // Get latest member from SQLite
      final dbHelper = DatabaseHelper();
      final sqliteMembers = await dbHelper.getAllMembers();
      
      DateTime? latestSqliteUpdate;
      if (sqliteMembers.isNotEmpty) {
        latestSqliteUpdate = sqliteMembers
            .map((m) => DateTime.parse(m['updated_at']))
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      
      // Get latest member from Firestore
      final firestoreMembers = await getMembersFromCache();
      DateTime? latestFirestoreUpdate;
      if (firestoreMembers.isNotEmpty) {
        latestFirestoreUpdate = firestoreMembers
            .map((m) => m.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      
      // Determine sync direction
      if (latestSqliteUpdate != null && latestFirestoreUpdate != null) {
        if (latestSqliteUpdate.isAfter(latestFirestoreUpdate)) {
          print('SQLite data is newer, syncing to Firestore');
          return await syncMembersToFirestore();
        } else {
          print('Firestore data is newer, syncing from Firestore');
          return await syncMembersFromFirestore();
        }
      } else if (latestSqliteUpdate != null) {
        print('Only SQLite has data, syncing to Firestore');
        return await syncMembersToFirestore();
      } else if (latestFirestoreUpdate != null) {
        print('Only Firestore has data, syncing from Firestore');
        return await syncMembersFromFirestore();
      } else {
        print('No data found in either source');
        return [];
      }
    } catch (e) {
      print('Error in smart sync: $e');
      throw Exception('Error in smart sync: $e');
    }
  }
}