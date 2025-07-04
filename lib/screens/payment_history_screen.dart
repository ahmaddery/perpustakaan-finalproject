import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import '../services/payment_firestore_service.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Payment> payments = [];
  bool isLoading = true;
  bool isSyncing = false;
  String? errorMessage;
  DateTime? lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistoryFromCache();
    _syncFromBackendSilently();
  }

  Future<void> _loadPaymentHistoryFromCache() async {
    try {
      print('Loading payments from cache...');
      // Load from cache immediately without loading state
      final cachedPayments = await PaymentFirestoreService.getPaymentsFromCache();
      print('Loaded ${cachedPayments.length} payments from cache');
      
      setState(() {
        payments = cachedPayments;
        isLoading = false;
        errorMessage = null;
      });
      
      // Update last sync time display
      _updateLastSyncTime();
    } catch (e) {
      print('Error loading from cache: $e');
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> _syncFromBackendSilently() async {
    try {
      setState(() {
        isSyncing = true;
      });

      final paymentHistory = await PaymentFirestoreService.syncPaymentsFromBackend();
      await PaymentFirestoreService.updateLastSyncTime();
      
      setState(() {
        payments = paymentHistory;
        isSyncing = false;
      });
      
      _updateLastSyncTime();
    } catch (e) {
      // Silent fail for background sync
      setState(() {
        isSyncing = false;
      });
    }
  }

  Future<void> _syncFromBackend() async {
    try {
      setState(() {
        isSyncing = true;
      });

      final paymentHistory = await PaymentFirestoreService.syncPaymentsFromBackend();
      await PaymentFirestoreService.updateLastSyncTime();
      
      setState(() {
        payments = paymentHistory;
        isLoading = false;
        isSyncing = false;
      });
      
      _updateLastSyncTime();
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
        isSyncing = false;
      });
    }
  }

  Future<void> _syncInBackground() async {
    try {
      setState(() {
        isSyncing = true;
      });

      final paymentHistory = await PaymentFirestoreService.syncPaymentsFromBackend();
      await PaymentFirestoreService.updateLastSyncTime();
      
      setState(() {
        payments = paymentHistory;
        isSyncing = false;
      });
      
      _updateLastSyncTime();
    } catch (e) {
      // Silent fail for background sync
      setState(() {
        isSyncing = false;
      });
    }
  }

  Future<void> _updateLastSyncTime() async {
    final syncTime = await PaymentFirestoreService.getLastSyncTime();
    setState(() {
      lastSyncTime = syncTime;
    });
  }

  Future<void> _onRefresh() async {
    await _syncFromBackend();
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Lunas';
      case 'pending':
        return 'Menunggu';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pembayaran'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
               icon: const Icon(Icons.refresh),
               onPressed: () async {
                 await _syncFromBackend();
               },
             ),
        ],
      ),
      body: errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Terjadi Kesalahan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _loadPaymentHistoryFromCache();
                      _syncFromBackendSilently();
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : payments.isEmpty && !isSyncing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Belum Ada Riwayat Pembayaran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      payment.description ?? 'Pembayaran #${payment.id}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(payment.status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getStatusColor(payment.status),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _getStatusText(payment.status),
                                      style: TextStyle(
                                        color: _getStatusColor(payment.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Jumlah:',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(payment.amount),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                              if (payment.isPaid && payment.paidAmount > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Dibayar:',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(payment.paidAmount),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tanggal:',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(payment.createdAt),
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              if (payment.paidAt != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Dibayar pada:',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(payment.paidAt!),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (payment.paymentChannel != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Metode:',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      payment.paymentChannel!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (payment.externalId != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'ID Eksternal: ${payment.externalId}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(
            top: BorderSide(
              color: Colors.grey[300]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSyncing) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Menyinkronkan...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else if (lastSyncTime != null) ...[
              Icon(
                Icons.sync,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                'Terakhir disinkronkan: ${_formatDate(lastSyncTime!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ] else ...[
              Icon(
                Icons.sync_disabled,
                size: 14,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 6),
              Text(
                'Belum pernah disinkronkan',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}