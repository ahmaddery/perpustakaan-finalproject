import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationService {
  static Future<bool> isRegistrationEnabled() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('registration')
          .get();
      
      return doc.exists ? (doc.data()?['enabled'] ?? true) : true;
    } catch (e) {
      return true; // Default enabled jika error
    }
  }
}