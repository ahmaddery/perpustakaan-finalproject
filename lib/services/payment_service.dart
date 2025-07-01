import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/payment_model.dart';

class PaymentService {
  static const String baseUrl = 'https://above-jay-mature.ngrok-free.app/api';
  
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> authHeaders(String token) {
    return {
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }

  /// Create a new payment for loan fine
  static Future<Map<String, dynamic>> createPayment({
    required int userId,
    required double amount,
    required String payerEmail,
    String? description,
    int? loanId,
    int? bookId,
    String currency = 'IDR',
    String? token,
  }) async {
    try {
      final body = {
        'user_id': userId,
        'amount': amount,
        'payment_category': 'loan',
        'payer_email': payerEmail,
        'description': description ?? 'Pembayaran denda peminjaman buku',
        'currency': currency,
        'quantity': 1,
        'is_high': false,
      };

      if (loanId != null) body['loan_id'] = loanId;
      if (bookId != null) body['book_id'] = bookId;

      final response = await http.post(
        Uri.parse('$baseUrl/payments'),
        headers: token != null ? authHeaders(token) : headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create payment');
      }
    } catch (e) {
      throw Exception('Error creating payment: $e');
    }
  }

  /// Get payment details by ID
  static Future<Map<String, dynamic>> getPaymentDetails(int paymentId, {String? token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/$paymentId'),
        headers: token != null ? authHeaders(token) : headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get payment details');
      }
    } catch (e) {
      throw Exception('Error getting payment details: $e');
    }
  }

  /// Get pending payments for a user
  static Future<List<Map<String, dynamic>>> getPendingPayments({int? userId, String? token}) async {
    try {
      String url = '$baseUrl/payments/status/pending';
      if (userId != null) {
        url += '?user_id=$userId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: token != null ? authHeaders(token) : headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(jsonData['data']['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get pending payments');
      }
    } catch (e) {
      throw Exception('Error getting pending payments: $e');
    }
  }

  /// Update payment status (for webhook or manual update)
  static Future<Map<String, dynamic>> updatePaymentStatus({
    required int paymentId,
    required String status,
    double? paidAmount,
    String? paymentChannel,
    String? paymentDestination,
    String? externalId,
    String? bankCode,
    String? token,
  }) async {
    try {
      final body = {
        'payment_id': paymentId,
        'status': status,
      };

      if (paidAmount != null) body['paid_amount'] = paidAmount;
      if (paymentChannel != null) body['payment_channel'] = paymentChannel;
      if (paymentDestination != null) body['payment_destination'] = paymentDestination;
      if (externalId != null) body['external_id'] = externalId;
      if (bankCode != null) body['bank_code'] = bankCode;

      final response = await http.put(
        Uri.parse('$baseUrl/payments/recurring/update'),
        headers: token != null ? authHeaders(token) : headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update payment');
      }
    } catch (e) {
      throw Exception('Error updating payment: $e');
    }
  }

  /// Get all payments with filters
  static Future<Map<String, dynamic>> getPayments({
    int? userId,
    String? status,
    bool? isHigh,
    int perPage = 15,
    int page = 1,
    String? token,
  }) async {
    try {
      final queryParams = <String, String>{
        'per_page': perPage.toString(),
        'page': page.toString(),
      };
      
      if (userId != null) queryParams['user_id'] = userId.toString();
      if (status != null) queryParams['status'] = status;
      if (isHigh != null) queryParams['is_high'] = isHigh.toString();

      final uri = Uri.parse('$baseUrl/payments')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: token != null ? authHeaders(token) : headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get payments');
      }
    } catch (e) {
      throw Exception('Error getting payments: $e');
    }
  }

  /// Get all payment history
  static Future<List<Payment>> getAllPaymentHistory({String? token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/read/all'),
        headers: token != null ? authHeaders(token) : headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final payments = jsonData['data']['payments'] as List;
          return payments.map((payment) => Payment.fromJson(payment)).toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to get payment history');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get payment history');
      }
    } catch (e) {
      throw Exception('Error getting payment history: $e');
    }
  }
}