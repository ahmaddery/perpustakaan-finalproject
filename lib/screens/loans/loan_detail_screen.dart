import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/loan_model.dart';
import '../../services/payment_service.dart';
import '../../services/notification_service.dart';
import 'payment_webview_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final int loanId;

  const LoanDetailScreen({Key? key, required this.loanId}) : super(key: key);

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();

  Loan? _loan;
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _book;
  bool _isLoading = true;

  // Add flags to prevent multiple payment status checks and track current payment
  bool _isCheckingPaymentStatus = false;
  int? _currentPaymentId; // Track which payment is being checked

  @override
  void initState() {
    super.initState();
    _loadLoanDetails();
  }

  Future<void> _loadLoanDetails() async {
    try {
      // Get loan details with member and book info
      final loanData = await _dbHelper.getLoanWithFine(widget.loanId);

      if (loanData != null) {
        final loan = Loan.fromJson(loanData);
        final member = await _dbHelper.getMemberById(loan.memberId);
        final book = await _dbHelper.getBookById(loan.bookId);

        setState(() {
          _loan = loan;
          _member = member;
          _book = book;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorAndGoBack('Peminjaman tidak ditemukan');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorAndGoBack('Error loading loan details: $e');
    }
  }

  void _showErrorAndGoBack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  Future<void> _returnBook() async {
    if (_loan == null) return;

    try {
      final fineAmount =
          _loan!.isOverdue
              ? _loan!.daysOverdue * 1000.0
              : 0.0; // Rp 1000 per hari

      if (fineAmount > 0) {
        // Show payment dialog if there's a fine
        _showPaymentDialog(fineAmount);
      } else {
        // Return book directly if no fine
        await _dbHelper.returnBook(_loan!.loanId!, fineAmount: 0.0);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buku berhasil dikembalikan')),
        );

        // Reload loan details
        await _loadLoanDetails();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error returning book: $e')));
    }
  }

  void _showPaymentDialog(double fineAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Pembayaran Denda'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buku ini terlambat ${_loan!.daysOverdue} hari.'),
                const SizedBox(height: 8),
                Text(
                  'Total denda: ${_formatCurrency(fineAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Silakan lakukan pembayaran untuk melanjutkan pengembalian buku.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _processPayment(fineAmount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Bayar Sekarang'),
              ),
            ],
          ),
    );
  }

  Future<void> _processPayment(double fineAmount) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Membuat pembayaran...'),
                ],
              ),
            ),
      );

      // Create payment via Xendit API
      final paymentResponse = await PaymentService.createPayment(
        userId: 1, // You should get this from session/auth
        amount: fineAmount,
        payerEmail: _member?['email'] ?? 'user@example.com',
        description: 'Pembayaran denda keterlambatan buku: ${_book?['title']}',
        loanId: _loan!.loanId,
        bookId: _loan!.bookId,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (paymentResponse['success'] == true) {
        final paymentData = paymentResponse['data'];
        final invoiceUrl = paymentData['invoice_url'];

        if (invoiceUrl != null) {
          // Show payment success dialog with invoice URL
          _showPaymentUrlDialog(invoiceUrl, paymentData['id']);
        } else {
          throw Exception('Invoice URL tidak tersedia');
        }
      } else {
        throw Exception(
          paymentResponse['message'] ?? 'Gagal membuat pembayaran',
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPaymentUrlDialog(String invoiceUrl, int paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Pembayaran Dibuat'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payment, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Pembayaran berhasil dibuat. Silakan lakukan pembayaran melalui halaman pembayaran.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    'Payment ID: $paymentId',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showAutoCheckPaymentDialog(paymentId);
                },
                child: const Text('Cek Status Pembayaran'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openPaymentPageAndMonitor(invoiceUrl, paymentId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Buka Halaman Pembayaran'),
              ),
            ],
          ),
    );
  }

  Future<void> _openPaymentPageAndMonitor(
    String invoiceUrl,
    int paymentId,
  ) async {
    // Calculate fine amount
    final fineAmount = _loan!.isOverdue ? _loan!.daysOverdue * 1000.0 : 0.0;

    // Open WebView screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => PaymentWebViewScreen(
              paymentUrl: invoiceUrl,
              bookTitle: _book?['title'] ?? 'Unknown Book',
              fineAmount: fineAmount,
              onPaymentCompleted: () {
                // Callback ini akan dipanggil jika pembayaran berhasil terdeteksi di WebView
                Navigator.of(context).pop('payment_completed');
              },
            ),
      ),
    );

    // Handle berbagai hasil dari WebView
    if (result == 'payment_completed') {
      // Pembayaran terdeteksi sukses di WebView, langsung cek status
      // Add delay to prevent immediate multiple calls
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && !_isCheckingPaymentStatus) {
        _checkPaymentStatus(paymentId, fineAmount);
      }
    } else if (result == 'check_payment') {
      // User menekan tombol "Saya Sudah Bayar, Cek Status"
      if (mounted && !_isCheckingPaymentStatus) {
        _showAutoCheckPaymentDialog(paymentId);
      }
    } else {
      // User kembali tanpa indikasi pembayaran, tawarkan cek manual
      if (mounted) {
        _showPaymentReturnDialog(paymentId, fineAmount);
      }
    }
  }

  void _showPaymentReturnDialog(int paymentId, double fineAmount) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pembayaran'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.help_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Apakah Anda sudah menyelesaikan pembayaran untuk buku: ${_book?['title']}?',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Belum'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showAutoCheckPaymentDialog(paymentId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sudah, Cek Status'),
              ),
            ],
          ),
    );
  }

  void _showAutoCheckPaymentDialog(int paymentId) {
    // Calculate fine amount
    final fineAmount = _loan!.isOverdue ? _loan!.daysOverdue * 1000.0 : 0.0;

    // Langsung mulai checking tanpa dialog tambahan
    // karena _checkPaymentStatus sudah menampilkan dialog sendiri
    // Only start if not already checking this payment
    if (!_isCheckingPaymentStatus || _currentPaymentId != paymentId) {
      _checkPaymentStatus(paymentId, fineAmount);
    }
  }

  Future<void> _checkPaymentStatus(int paymentId, double fineAmount) async {
    // Prevent multiple instances and check if already checking this specific payment
    if (_isCheckingPaymentStatus && _currentPaymentId == paymentId) {
      return; // Already checking this payment, skip
    }

    _isCheckingPaymentStatus = true;
    _currentPaymentId = paymentId;
    bool isDialogOpen = true;
    bool isSuccessDialogShown = false;
    bool isPollingActive = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.payment, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('Mengecek Pembayaran')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Sistem sedang mengecek status pembayaran untuk buku: ${_book?['title'] ?? 'Unknown'}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Status akan diperbarui otomatis',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Jika Anda telah menyelesaikan pembayaran, silakan tunggu beberapa saat untuk konfirmasi.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    isDialogOpen = false;
                    isPollingActive = false;
                    _isCheckingPaymentStatus = false; // Reset flag
                    _currentPaymentId = null; // Clear current payment
                    Navigator.of(context).pop();
                  },
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
    ).then((_) {
      isDialogOpen = false;
      isPollingActive = false;
      _isCheckingPaymentStatus = false; // Reset flag when dialog closes
      _currentPaymentId = null; // Clear current payment
    });

    try {
      // Poll payment status every 3 seconds until paid or cancelled
      while (isPollingActive && mounted) {
        final paymentResponse = await PaymentService.getPaymentDetails(
          paymentId,
        );

        if (paymentResponse['success'] == true) {
          final paymentData = paymentResponse['data'];
          final status = paymentData['status'];

          if (status == 'paid' && !isSuccessDialogShown && isPollingActive) {
            isSuccessDialogShown = true;
            isPollingActive = false; // Stop polling immediately

            // Payment completed, close loading dialog first
            if (isDialogOpen) {
              isDialogOpen = false;
              Navigator.of(context).pop(); // Close loading dialog
            }

            // Wait for dialog to close properly
            await Future.delayed(const Duration(milliseconds: 800));

            if (mounted) {
              // Process return book first
              await _dbHelper.returnBook(
                _loan!.loanId!,
                fineAmount: fineAmount,
              );

              // Clear notifications for this loan since payment is completed
              await _notificationService.clearNotificationsForLoan(
                _loan!.loanId!,
              );

              // Show success dialog
              await _showPaymentSuccessDialog(paymentData, fineAmount);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pembayaran berhasil! Buku telah dikembalikan.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadLoanDetails();
              }
            }
            _isCheckingPaymentStatus = false; // Reset flag
            _currentPaymentId = null; // Clear current payment
            return; // Exit function completely
          } else if (status == 'expired' || status == 'failed') {
            // Payment failed or expired
            isPollingActive = false;
            _isCheckingPaymentStatus = false; // Reset flag
            _currentPaymentId = null; // Clear current payment
            if (isDialogOpen) {
              isDialogOpen = false;
              Navigator.of(context).pop(); // Close loading dialog
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pembayaran $status. Silakan coba lagi.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return; // Exit function completely
          }
          // If status is still 'pending', continue polling only if still active
        }

        // Wait 3 seconds before next check, but only if still active
        if (isPollingActive) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      isPollingActive = false;
      _isCheckingPaymentStatus = false; // Reset flag
      _currentPaymentId = null; // Clear current payment
      if (isDialogOpen && mounted) {
        isDialogOpen = false;
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking payment status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Reset flag at the end
    _isCheckingPaymentStatus = false;
    _currentPaymentId = null;
  }

  Future<void> _showPaymentSuccessDialog(
    Map<String, dynamic> paymentData,
    double fineAmount,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('Pembayaran Berhasil!')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pembayaran denda untuk buku "${_book?['title']}" telah berhasil diproses.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.payment,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Detail Pembayaran:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Jumlah Dibayar: ${_formatCurrency(double.tryParse(paymentData['paid_amount']?.toString() ?? '0') ?? fineAmount)}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Metode Pembayaran: ${paymentData['payment_channel'] ?? 'Online Payment'}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID Transaksi: ${paymentData['external_id'] ?? paymentData['id']}',
                        ),
                        const SizedBox(height: 4),
                        Text('Mata Uang: ${paymentData['currency'] ?? 'IDR'}'),
                        if (paymentData['paid_at'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Waktu Pembayaran: ${_formatDateTime(paymentData['paid_at'])}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Buku telah dikembalikan ke perpustakaan.',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  // Ensure flags are reset when dialog is dismissed
                  _isCheckingPaymentStatus = false;
                  _currentPaymentId = null;
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );

    // Also reset flags after dialog is complete
    _isCheckingPaymentStatus = false;
    _currentPaymentId = null;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Peminjaman'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loan == null
              ? const Center(
                child: Text(
                  'Peminjaman tidak ditemukan',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loan Status Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _loan!.status == 'returned'
                                      ? Icons.check_circle
                                      : _loan!.isOverdue
                                      ? Icons.warning
                                      : Icons.schedule,
                                  color:
                                      _loan!.status == 'returned'
                                          ? Colors.green
                                          : _loan!.isOverdue
                                          ? Colors.red
                                          : Colors.orange,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Status: ${_loan!.status.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _loan!.status == 'returned'
                                            ? Colors.green
                                            : _loan!.isOverdue
                                            ? Colors.red
                                            : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            if (_loan!.isOverdue && _loan!.status == 'borrowed')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Terlambat ${_loan!.daysOverdue} hari',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Book Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Buku',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Judul',
                              _book?['title'] ?? 'Unknown',
                            ),
                            _buildInfoRow(
                              'Penulis',
                              _book?['author'] ?? 'Unknown',
                            ),
                            _buildInfoRow('ISBN', _book?['isbn'] ?? '-'),
                            if (_book?['year'] != null)
                              _buildInfoRow('Tahun', _book!['year'].toString()),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Member Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Peminjam',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Nama',
                              _member?['full_name'] ?? 'Unknown',
                            ),
                            _buildInfoRow('Email', _member?['email'] ?? '-'),
                            _buildInfoRow('Telepon', _member?['phone'] ?? '-'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Loan Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Peminjaman',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'ID Peminjaman',
                              _loan!.loanId.toString(),
                            ),
                            _buildInfoRow(
                              'Tanggal Pinjam',
                              _formatDate(_loan!.loanDate),
                            ),
                            _buildInfoRow(
                              'Tanggal Jatuh Tempo',
                              _formatDate(_loan!.dueDate),
                            ),
                            if (_loan!.returnDate != null)
                              _buildInfoRow(
                                'Tanggal Kembali',
                                _formatDate(_loan!.returnDate!),
                              ),
                            if (_loan!.fineAmount > 0)
                              _buildInfoRow(
                                'Denda',
                                _formatCurrency(_loan!.fineAmount),
                                valueColor: Colors.red,
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    if (_loan!.status == 'borrowed')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _returnBook,
                          icon: const Icon(Icons.assignment_return),
                          label: const Text(
                            'Kembalikan Buku',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
