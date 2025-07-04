import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';

class PaymentFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'payments';

  /// Get payments from Firestore cache
  static Future<List<Payment>> getPaymentsFromCache() async {
    try {
      print('Attempting to get payments from Firestore cache...');
      
      // First try cache, then fallback to server if cache is empty
      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await _firestore
            .collection(_collection)
            .get(const GetOptions(source: Source.cache));
        print('Cache query returned ${querySnapshot.docs.length} documents');
      } catch (cacheError) {
        print('Cache query failed: $cacheError, trying server...');
        querySnapshot = await _firestore
            .collection(_collection)
            .get(const GetOptions(source: Source.server));
        print('Server query returned ${querySnapshot.docs.length} documents');
      }

      final payments = querySnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Don't overwrite the id field - use the one from the stored data
            print('Processing document ${doc.id} with data: ${data.keys}');
            return Payment.fromJson(data);
          })
          .toList();
      
      print('Successfully parsed ${payments.length} payments from Firestore');
      
      // Sort by created_at in memory since we can't guarantee the field exists for ordering
      payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return payments;
    } catch (e) {
      print('Error getting payments from Firestore: $e');
      // If cache is empty or error, return empty list
      return [];
    }
  }

  /// Sync payments from backend to Firestore
  static Future<List<Payment>> syncPaymentsFromBackend() async {
    try {
      print('Starting sync from backend...');
      // Get payments from backend without authentication
      final backendPayments = await PaymentService.getAllPaymentHistory();
      print('Got ${backendPayments.length} payments from backend');
      
      if (backendPayments.isEmpty) {
        print('No payments received from backend, skipping Firestore sync');
        return backendPayments;
      }
      
      // Clear existing cache
      await _clearAllPayments();
      print('Cleared existing payments from Firestore');
      
      // Save to Firestore
      final batch = _firestore.batch();
      
      for (final payment in backendPayments) {
        final docRef = _firestore.collection(_collection).doc('payment_${payment.id}');
        final paymentData = payment.toJson();
        print('Saving payment ${payment.id} to Firestore: ${paymentData['description']}');
        batch.set(docRef, paymentData);
      }
      
      await batch.commit();
      print('Successfully saved ${backendPayments.length} payments to Firestore');
      
      return backendPayments;
    } catch (e) {
      print('Error syncing payments: $e');
      throw Exception('Error syncing payments: $e');
    }
  }

  /// Clear all payments
  static Future<void> _clearAllPayments() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      // Ignore errors when clearing cache
    }
  }

  /// Get payments with cache-first strategy
  static Future<List<Payment>> getPaymentsWithCacheFirst() async {
    try {
      // First, try to get from cache
      final cachedPayments = await getPaymentsFromCache();
      
      if (cachedPayments.isNotEmpty) {
        return cachedPayments;
      }
      
      // If cache is empty, sync from backend
      return await syncPaymentsFromBackend();
    } catch (e) {
      throw Exception('Error getting payments: $e');
    }
  }

  /// Force refresh from backend
  static Future<List<Payment>> forceRefreshFromBackend() async {
    return await syncPaymentsFromBackend();
  }

  /// Check if cache exists
  static Future<bool> hasCachedData() async {
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
          .collection('sync_metadata')
          .doc('payments_sync')
          .get();

      if (doc.exists) {
        final timestamp = doc.data()?['last_sync'] as Timestamp?;
        return timestamp?.toDate();
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update last sync timestamp
  static Future<void> updateLastSyncTime() async {
    try {
      await _firestore
          .collection('sync_metadata')
          .doc('payments_sync')
          .set({
        'last_sync': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore errors when updating sync time
    }
  }
}