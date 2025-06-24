# Payment API Documentation
## For Flutter Frontend Integration

### Base URL
```
https://above-jay-mature.ngrok-free.app/api
```

### Authentication
Most endpoints require Bearer token authentication using Laravel Sanctum.

**Headers Required:**
```
Authorization: Bearer {your_token}
Content-Type: application/json
Accept: application/json
```

---

## 📋 **API Endpoints Overview**

### Public Endpoints (No Authentication Required)
- `POST /payments/webhook/xendit` - Xendit webhook handler

### Protected Endpoints (Authentication Required)
- `GET /payments` - List all payments with filters
- `POST /payments` - Create new payment
- `GET /payments/{id}` - Get payment details
- `GET /payments/status/completed` - Get completed payments
- `GET /payments/status/expired-or-nearly` - Get expired/nearly expired payments
- `GET /payments/status/successful` - Get successful payments
- `GET /payments/status/pending` - Get pending payments
- `GET /payments/status/failed` - Get failed payments
- `PUT /payments/recurring/update` - Update recurring payment

---

## 🔐 **Authentication**

### Get User Token
```http
GET /user
Authorization: Bearer {token}
```

**Response:**
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com",
  "email_verified_at": "2025-06-24T10:00:00.000000Z",
  "created_at": "2025-06-24T10:00:00.000000Z",
  "updated_at": "2025-06-24T10:00:00.000000Z"
}
```

---

## 💰 **Payment Endpoints**

### 1. List All Payments
```http
GET /payments
```

**Query Parameters:**
- `user_id` (optional) - Filter by user ID
- `status` (optional) - Filter by status (pending, paid, failed)
- `is_high` (optional) - Filter by priority (true/false)
- `per_page` (optional) - Items per page (default: 15)
- `page` (optional) - Page number

**Example Request:**
```http
GET /payments?user_id=1&status=pending&per_page=10&page=1
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "message": "Payments retrieved successfully",
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 1,
        "user_id": 1,
        "payment_category": "loan",
        "reference_id": "REF001",
        "loan_id": null,
        "book_id": null,
        "days_late": 0,
        "external_id": "payment_1719235200",
        "merchant_name": "Your App",
        "merchant_profile_picture_url": null,
        "amount": "100000.00",
        "payer_email": "user@example.com",
        "description": "Monthly payment",
        "expiry_date": "2025-07-01T23:59:59.000000Z",
        "invoice_url": "https://checkout.xendit.co/web/invoice_id",
        "status": "pending",
        "currency": "IDR",
        "quantity": 1,
        "paid_amount": "0.00",
        "bank_code": null,
        "paid_at": null,
        "payment_channel": null,
        "payment_destination": null,
        "payment_id": null,
        "is_high": false,
        "created_at": "2025-06-24T10:00:00.000000Z",
        "updated_at": "2025-06-24T10:00:00.000000Z"
      }
    ],
    "first_page_url": "http://localhost/api/payments?page=1",
    "from": 1,
    "last_page": 1,
    "last_page_url": "http://localhost/api/payments?page=1",
    "links": [],
    "next_page_url": null,
    "path": "http://localhost/api/payments",
    "per_page": 15,
    "prev_page_url": null,
    "to": 1,
    "total": 1
  }
}
```

### 2. Create New Payment
```http
POST /payments
```

**Request Body:**
```json
{
  "user_id": 1,
  "amount": 100000,
  "payment_category": "loan",
  "payer_email": "user@example.com",
  "description": "Monthly loan payment",
  "currency": "IDR",
  "quantity": 1,
  "expiry_date": "2025-07-01 23:59:59",
  "is_high": false
}
```

**Required Fields:**
- `user_id` (integer)
- `amount` (numeric, min: 0)

**Optional Fields:**
- `payment_category` (string)
- `payer_email` (email)
- `description` (string)
- `currency` (string, max: 3, default: "IDR")
- `quantity` (integer, min: 1, default: 1)
- `expiry_date` (date, after: now)
- `is_high` (boolean, default: false)

**Response:**
```json
{
  "success": true,
  "message": "Payment created successfully",
  "data": {
    "id": 1,
    "user_id": 1,
    "amount": "100000.00",
    "status": "pending",
    "currency": "IDR",
    "created_at": "2025-06-24T10:00:00.000000Z",
    "updated_at": "2025-06-24T10:00:00.000000Z"
  }
}
```

### 3. Get Payment Details
```http
GET /payments/{id}
```

**Response:**
```json
{
  "success": true,
  "message": "Payment details retrieved successfully",
  "data": {
    "id": 1,
    "user_id": 1,
    "amount": "100000.00",
    "paid_amount": "50000.00",
    "status": "pending",
    "remaining_amount": 50000,
    "payment_progress": 50.0,
    "is_expired": false,
    "created_at": "2025-06-24T10:00:00.000000Z",
    "updated_at": "2025-06-24T10:00:00.000000Z"
  }
}
```

### 4. Get Completed Payments
```http
GET /payments/status/completed
```

**Query Parameters:**
- `user_id` (optional)
- `per_page` (optional)

**Response:**
```json
{
  "success": true,
  "message": "Completed payments retrieved successfully",
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 1,
        "status": "paid",
        "paid_at": "2025-06-24T10:00:00.000000Z",
        "paid_amount": "100000.00"
      }
    ]
  }
}
```

### 5. Get Expired or Nearly Expired Payments
```http
GET /payments/status/expired-or-nearly
```

**Response:**
```json
{
  "success": true,
  "message": "Expired or nearly expired payments retrieved successfully",
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 1,
        "expiry_date": "2025-06-25T23:59:59.000000Z",
        "is_expired": false,
        "days_until_expiry": 1,
        "status": "pending"
      }
    ]
  }
}
```

### 6. Get Successful Payments
```http
GET /payments/status/successful
```

**Query Parameters:**
- `user_id` (optional)
- `start_date` (optional) - Format: YYYY-MM-DD
- `end_date` (optional) - Format: YYYY-MM-DD
- `per_page` (optional)

**Response:**
```json
{
  "success": true,
  "message": "Successful payments retrieved successfully",
  "data": {
    "current_page": 1,
    "data": [...]
  },
  "summary": {
    "total_amount": 500000,
    "total_count": 5
  }
}
```

### 7. Get Pending Payments
```http
GET /payments/status/pending
```

**Response:**
```json
{
  "success": true,
  "message": "Pending payments retrieved successfully",
  "data": {
    "current_page": 1,
    "data": [...]
  }
}
```

### 8. Get Failed Payments
```http
GET /payments/status/failed
```

**Response:**
```json
{
  "success": true,
  "message": "Failed payments retrieved successfully",
  "data": {
    "current_page": 1,
    "data": [...]
  }
}
```

### 9. Update Recurring Payment
```http
PUT /payments/recurring/update
```

**Request Body:**
```json
{
  "payment_id": 1,
  "status": "paid",
  "paid_amount": 100000,
  "payment_channel": "BANK_TRANSFER",
  "payment_destination": "1234567890",
  "external_id": "xendit_payment_123",
  "bank_code": "BCA"
}
```

**Required Fields:**
- `payment_id` (integer, exists in payments table)
- `status` (string: pending, paid, failed, cancelled)

**Optional Fields:**
- `paid_amount` (numeric, min: 0)
- `payment_channel` (string)
- `payment_destination` (string)
- `external_id` (string)
- `bank_code` (string)

**Response:**
```json
{
  "success": true,
  "message": "Recurring payment updated successfully",
  "data": {
    "id": 1,
    "status": "paid",
    "paid_amount": "100000.00",
    "paid_at": "2025-06-24T10:00:00.000000Z",
    "updated_at": "2025-06-24T10:00:00.000000Z"
  }
}
```

---

## 🎯 **Payment Status Values**

| Status | Description |
|--------|-------------|
| `pending` | Payment is waiting for completion |
| `paid` | Payment has been successfully completed |
| `failed` | Payment has failed |
| `cancelled` | Payment has been cancelled |

---

## 📱 **Flutter Integration Examples**

### 1. HTTP Client Setup
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentApiService {
  static const String baseUrl = 'https://your-domain.com/api';
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
}
```

### 2. Get Payments List
```dart
Future<List<Payment>> getPayments({
  int? userId,
  String? status,
  bool? isHigh,
  int perPage = 15,
  int page = 1,
}) async {
  final queryParams = <String, String>{
    'per_page': perPage.toString(),
    'page': page.toString(),
  };
  
  if (userId != null) queryParams['user_id'] = userId.toString();
  if (status != null) queryParams['status'] = status;
  if (isHigh != null) queryParams['is_high'] = isHigh.toString();

  final uri = Uri.parse('${PaymentApiService.baseUrl}/payments')
      .replace(queryParameters: queryParams);

  final response = await http.get(
    uri,
    headers: PaymentApiService.authHeaders(token),
  );

  if (response.statusCode == 200) {
    final jsonData = json.decode(response.body);
    final List<dynamic> paymentsJson = jsonData['data']['data'];
    return paymentsJson.map((json) => Payment.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load payments');
  }
}
```

### 3. Create Payment
```dart
Future<Payment> createPayment({
  required int userId,
  required double amount,
  String? category,
  String? payerEmail,
  String? description,
  String currency = 'IDR',
  int quantity = 1,
  DateTime? expiryDate,
  bool isHigh = false,
}) async {
  final body = {
    'user_id': userId,
    'amount': amount,
    'currency': currency,
    'quantity': quantity,
    'is_high': isHigh,
  };

  if (category != null) body['payment_category'] = category;
  if (payerEmail != null) body['payer_email'] = payerEmail;
  if (description != null) body['description'] = description;
  if (expiryDate != null) {
    body['expiry_date'] = expiryDate.toIso8601String();
  }

  final response = await http.post(
    Uri.parse('${PaymentApiService.baseUrl}/payments'),
    headers: PaymentApiService.authHeaders(token),
    body: json.encode(body),
  );

  if (response.statusCode == 201) {
    final jsonData = json.decode(response.body);
    return Payment.fromJson(jsonData['data']);
  } else {
    throw Exception('Failed to create payment');
  }
}
```

### 4. Payment Model
```dart
class Payment {
  final int id;
  final int userId;
  final String? paymentCategory;
  final String? referenceId;
  final int? loanId;
  final int? bookId;
  final int daysLate;
  final String? externalId;
  final String? merchantName;
  final String? merchantProfilePictureUrl;
  final double amount;
  final String? payerEmail;
  final String? description;
  final DateTime? expiryDate;
  final String? invoiceUrl;
  final String status;
  final String currency;
  final int quantity;
  final double paidAmount;
  final String? bankCode;
  final DateTime? paidAt;
  final String? paymentChannel;
  final String? paymentDestination;
  final String? paymentId;
  final bool isHigh;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.userId,
    this.paymentCategory,
    this.referenceId,
    this.loanId,
    this.bookId,
    required this.daysLate,
    this.externalId,
    this.merchantName,
    this.merchantProfilePictureUrl,
    required this.amount,
    this.payerEmail,
    this.description,
    this.expiryDate,
    this.invoiceUrl,
    required this.status,
    required this.currency,
    required this.quantity,
    required this.paidAmount,
    this.bankCode,
    this.paidAt,
    this.paymentChannel,
    this.paymentDestination,
    this.paymentId,
    required this.isHigh,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      userId: json['user_id'],
      paymentCategory: json['payment_category'],
      referenceId: json['reference_id'],
      loanId: json['loan_id'],
      bookId: json['book_id'],
      daysLate: json['days_late'] ?? 0,
      externalId: json['external_id'],
      merchantName: json['merchant_name'],
      merchantProfilePictureUrl: json['merchant_profile_picture_url'],
      amount: double.parse(json['amount'].toString()),
      payerEmail: json['payer_email'],
      description: json['description'],
      expiryDate: json['expiry_date'] != null 
          ? DateTime.parse(json['expiry_date']) 
          : null,
      invoiceUrl: json['invoice_url'],
      status: json['status'],
      currency: json['currency'],
      quantity: json['quantity'] ?? 1,
      paidAmount: double.parse(json['paid_amount'].toString()),
      bankCode: json['bank_code'],
      paidAt: json['paid_at'] != null 
          ? DateTime.parse(json['paid_at']) 
          : null,
      paymentChannel: json['payment_channel'],
      paymentDestination: json['payment_destination'],
      paymentId: json['payment_id'],
      isHigh: json['is_high'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'payment_category': paymentCategory,
      'reference_id': referenceId,
      'loan_id': loanId,
      'book_id': bookId,
      'days_late': daysLate,
      'external_id': externalId,
      'merchant_name': merchantName,
      'merchant_profile_picture_url': merchantProfilePictureUrl,
      'amount': amount,
      'payer_email': payerEmail,
      'description': description,
      'expiry_date': expiryDate?.toIso8601String(),
      'invoice_url': invoiceUrl,
      'status': status,
      'currency': currency,
      'quantity': quantity,
      'paid_amount': paidAmount,
      'bank_code': bankCode,
      'paid_at': paidAt?.toIso8601String(),
      'payment_channel': paymentChannel,
      'payment_destination': paymentDestination,
      'payment_id': paymentId,
      'is_high': isHigh,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  double get remainingAmount => amount - paidAmount;
  double get paymentProgress => amount > 0 ? (paidAmount / amount) * 100 : 0;
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
}
```

---

## ⚠️ **Error Handling**

### Error Response Format
```json
{
  "success": false,
  "message": "Error message",
  "error": "Detailed error information",
  "errors": {
    "field_name": ["Validation error message"]
  }
}
```

### Common HTTP Status Codes
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `422` - Validation Error
- `500` - Server Error

### Flutter Error Handling Example
```dart
try {
  final payments = await getPayments();
  return payments;
} catch (e) {
  if (e is http.ClientException) {
    throw Exception('Network error: Check your internet connection');
  } else if (e.toString().contains('401')) {
    throw Exception('Authentication failed: Please login again');
  } else if (e.toString().contains('422')) {
    throw Exception('Invalid data: Please check your input');
  } else {
    throw Exception('Something went wrong: ${e.toString()}');
  }
}
```

---

## 🔔 **WebSocket/Real-time Updates (Optional)**

For real-time payment status updates, you can implement WebSocket connection or periodic polling:

```dart
// Polling example
Timer.periodic(Duration(seconds: 30), (timer) async {
  try {
    final updatedPayment = await getPaymentDetails(paymentId);
    if (updatedPayment.status != currentStatus) {
      // Update UI
      updatePaymentStatus(updatedPayment);
    }
  } catch (e) {
    print('Error polling payment status: $e');
  }
});
```

---

## 📝 **Notes for Frontend Team**

1. **Authentication**: Always include Bearer token in headers for protected endpoints
2. **Error Handling**: Implement proper error handling for network issues and API errors
3. **Loading States**: Show loading indicators during API calls
4. **Caching**: Consider caching payment data to improve user experience
5. **Offline Support**: Handle offline scenarios gracefully
6. **Validation**: Validate input data before sending to API
7. **Security**: Never store sensitive payment information locally
8. **Testing**: Test with different payment scenarios and edge cases

---

## 🚀 **Getting Started Checklist**

- [ ] Set up HTTP client with base URL and headers
- [ ] Implement authentication token management
- [ ] Create Payment model class
- [ ] Implement API service methods
- [ ] Add error handling and validation
- [ ] Test all endpoints with sample data
- [ ] Implement UI for payment status display
- [ ] Add loading and error states
- [ ] Test with real payment scenarios
