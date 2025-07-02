import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/loan_model.dart';
import '../../services/payment_service.dart';
import '../../services/notification_service.dart';
import 'return_book_dialog.dart';
import 'create_loan_screen.dart';
import 'payment_webview_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({Key? key}) : super(key: key);

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();
  late TabController _tabController;
  List<Loan> _allLoans = [];
  List<Loan> _activeLoans = [];
  List<Loan> _overdueLoans = [];
  bool _isLoading = true;

  // Add flags to prevent multiple payment status checks and track current payment
  bool _isCheckingPaymentStatus = false;
  int? _currentPaymentId; // Track which payment is being checked

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLoans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLoans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allLoansData = await _dbHelper.getAllLoans();
      final activeLoansData = await _dbHelper.getActiveLoans();
      final overdueLoansData = await _dbHelper.getOverdueLoans();

      setState(() {
        _allLoans = allLoansData.map((data) => Loan.fromJson(data)).toList();
        _activeLoans =
            activeLoansData.map((data) => Loan.fromJson(data)).toList();
        _overdueLoans =
            overdueLoansData.map((data) => Loan.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading loans: $e')));
    }
  }

  void _showAddLoanDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => CreateLoanScreen(
              onSave: (memberId, bookData, dueDate, isFromApi) async {
                try {
                  int bookId;

                  if (isFromApi) {
                    // Create a temporary book entry for API books
                    // We'll store it with a special identifier
                    final tempBookData = {
                      'title': bookData['title'],
                      'author': bookData['author'] ?? 'Unknown',
                      'isbn': bookData['isbn'] ?? '',
                      'publisher': bookData['publisher'] ?? '',
                      'year': bookData['year'] ?? 0,
                      'pages': bookData['pages'] ?? 0,
                      'category': 'API Book',
                      'stock_quantity': 999, // Unlimited for API books
                      'api_book_id': bookData['id'], // Store original API ID
                    };

                    // Check if this API book already exists in our database
                    final existingBooks = await _dbHelper.getAllBooks();
                    final existingBook =
                        existingBooks
                            .where(
                              (book) => book['api_book_id'] == bookData['id'],
                            )
                            .toList();

                    if (existingBook.isNotEmpty) {
                      bookId = existingBook.first['book_id'];
                    } else {
                      bookId = await _dbHelper.insertBook(tempBookData);
                    }
                  } else {
                    bookId = bookData['book_id'];
                    final canBorrow = await _dbHelper.canBorrowBook(
                      memberId,
                      bookId,
                    );
                    if (!canBorrow) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Buku tidak tersedia untuk dipinjam'),
                        ),
                      );
                      return;
                    }
                  }

                  await _dbHelper.insertLoan({
                    'member_id': memberId,
                    'book_id': bookId,
                    'due_date': dueDate.toIso8601String(),
                    'status': 'borrowed',
                  });

                  // Stock quantity is already updated in insertLoan method

                  _loadLoans();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Peminjaman berhasil dibuat')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error membuat peminjaman: $e')),
                  );
                }
              },
            ),
      ),
    );
  }

  void _returnBook(Loan loan) {
    showDialog(
      context: context,
      builder:
          (context) => ReturnBookDialog(
            loan: loan,
            onReturn: (fineAmount) async {
              try {
                if (fineAmount != null && fineAmount > 0) {
                  // Process payment for fine
                  await _processPaymentForFine(loan, fineAmount);
                } else {
                  // Return book directly if no fine
                  await _dbHelper.returnBook(loan.loanId!, fineAmount: 0.0);
                  _loadLoans();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Book returned successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error returning book: $e')),
                );
              }
            },
          ),
    );
  }

  Future<void> _processPaymentForFine(Loan loan, double fineAmount) async {
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
        amount: fineAmount, // fineAmount already in Rupiah (daysOverdue * 1000)
        payerEmail: loan.memberEmail ?? 'member@example.com',
        description: 'Pembayaran denda keterlambatan buku: ${loan.bookTitle}',
        loanId: loan.loanId,
        bookId: loan.bookId,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (paymentResponse['success'] == true) {
        final paymentData = paymentResponse['data'];
        final invoiceUrl = paymentData['invoice_url'];

        if (invoiceUrl != null) {
          // Show payment success dialog with invoice URL
          _showPaymentUrlDialog(
            invoiceUrl,
            paymentData['id'],
            loan,
            fineAmount,
          );
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

  void _showPaymentUrlDialog(
    String invoiceUrl,
    int paymentId,
    Loan loan,
    double fineAmount,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Pembayaran Denda'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payment, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  'Denda untuk buku: ${loan.bookTitle}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Jumlah: ${_formatCurrency(fineAmount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Silakan lakukan pembayaran melalui halaman yang akan dibuka:',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Buka WebView dan mulai monitoring pembayaran secara otomatis
                  _openPaymentPageAndMonitor(
                    invoiceUrl,
                    paymentId,
                    loan,
                    fineAmount,
                  );
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

  Future<void> _checkPaymentStatus(
    int paymentId,
    Loan loan,
    double fineAmount,
  ) async {
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
                  'Sistem sedang mengecek status pembayaran untuk buku: ${loan.bookTitle}',
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
              await _dbHelper.returnBook(loan.loanId!, fineAmount: fineAmount);

              // Clear notifications for this loan since payment is completed
              await _notificationService.clearNotificationsForLoan(
                loan.loanId!,
              );

              // Show success dialog
              await _showPaymentSuccessDialog(loan, paymentData, fineAmount);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pembayaran berhasil! Buku telah dikembalikan.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadLoans();
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

  Future<void> _openPaymentPageAndMonitor(
    String invoiceUrl,
    int paymentId,
    Loan loan,
    double fineAmount,
  ) async {
    // Buka WebView screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => PaymentWebViewScreen(
              paymentUrl: invoiceUrl,
              bookTitle: loan.bookTitle ?? 'Unknown Book',
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
        _checkPaymentStatus(paymentId, loan, fineAmount);
      }
    } else if (result == 'check_payment') {
      // User menekan tombol "Saya Sudah Bayar, Cek Status"
      if (mounted && !_isCheckingPaymentStatus) {
        _showAutoCheckPaymentDialog(paymentId, loan, fineAmount);
      }
    } else {
      // User kembali tanpa indikasi pembayaran, tawarkan cek manual
      if (mounted) {
        _showPaymentReturnDialog(paymentId, loan, fineAmount);
      }
    }
  }

  void _showPaymentReturnDialog(int paymentId, Loan loan, double fineAmount) {
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
                  'Apakah Anda sudah menyelesaikan pembayaran untuk buku: ${loan.bookTitle}?',
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
                  _showAutoCheckPaymentDialog(paymentId, loan, fineAmount);
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

  void _showAutoCheckPaymentDialog(
    int paymentId,
    Loan loan,
    double fineAmount,
  ) {
    // Langsung mulai checking tanpa dialog tambahan
    // karena _checkPaymentStatus sudah menampilkan dialog sendiri
    // Only start if not already checking this payment
    if (!_isCheckingPaymentStatus || _currentPaymentId != paymentId) {
      _checkPaymentStatus(paymentId, loan, fineAmount);
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
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

  Widget _buildLoansList(List<Loan> loans) {
    if (loans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data peminjaman',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan peminjaman baru dengan menekan tombol + di bawah',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final bool isOverdue = loan.isOverdue;
        final bool isReturned = loan.status != 'borrowed';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // You can implement detailed view navigation here if needed
            },
            child: Column(
              children: [
                // Header with status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isReturned
                            ? Colors.green.shade50
                            : (isOverdue
                                ? Colors.red.shade50
                                : Colors.blue.shade50),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isReturned
                            ? Icons.check_circle
                            : (isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.book),
                        color:
                            isReturned
                                ? Colors.green
                                : (isOverdue ? Colors.red : Colors.blue),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isReturned
                            ? 'Dikembalikan'
                            : (isOverdue
                                ? 'Terlambat ${loan.daysOverdue} hari'
                                : 'Dipinjam'),
                        style: TextStyle(
                          color:
                              isReturned
                                  ? Colors.green
                                  : (isOverdue ? Colors.red : Colors.blue),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(loan.dueDate),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Book icon or image
                      Container(
                        width: 60,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.book,
                          size: 30,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Book and member info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loan.bookTitle ?? 'Unknown Book',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    loan.memberName ?? 'Unknown',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Jatuh Tempo: ${_formatDate(loan.dueDate)}',
                                  style: TextStyle(
                                    color:
                                        isOverdue
                                            ? Colors.red
                                            : Colors.grey.shade700,
                                    fontSize: 14,
                                    fontWeight:
                                        isOverdue
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            if (loan.fineAmount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.attach_money,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Denda: ${_formatCurrency(loan.fineAmount)}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer with action button
                if (!isReturned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.assignment_return, size: 18),
                          label: const Text('Kembalikan'),
                          onPressed: () => _returnBook(loan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with gradient background
          Container(
            padding: const EdgeInsets.only(
              top: 48,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade700, Colors.blue.shade500],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade200.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    const Text(
                      'Peminjaman',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadLoans,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Statistics cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Semua',
                        _allLoans.length.toString(),
                        Icons.book,
                        Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Aktif',
                        _activeLoans.length.toString(),
                        Icons.book_online,
                        Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Terlambat',
                        _overdueLoans.length.toString(),
                        Icons.warning_amber_rounded,
                        Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Semua (${_allLoans.length})'),
                Tab(text: 'Aktif (${_activeLoans.length})'),
                Tab(text: 'Terlambat (${_overdueLoans.length})'),
              ],
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey,
              indicatorSize: TabBarIndicatorSize.label,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(width: 3, color: Colors.blue.shade700),
                insets: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Tab content
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoansList(_allLoans),
                        _buildLoansList(_activeLoans),
                        _buildLoansList(_overdueLoans),
                      ],
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLoanDialog,
        backgroundColor: Colors.blue.shade700,
        heroTag: "add_loan_fab", // Unique hero tag
        icon: const Icon(Icons.add),
        label: const Text('Buat Peminjaman'),
        elevation: 4,
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentSuccessDialog(
    Loan loan,
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
                    'Pembayaran denda untuk buku "${loan.bookTitle}" telah berhasil diproses.',
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
                        if (paymentData['payment_destination'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tujuan Pembayaran: ${paymentData['payment_destination']}',
                          ),
                        ],
                        if (paymentData['bank_code'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Kode Bank: ${paymentData['bank_code']}'),
                        ],
                        if (paymentData['payment_progress'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Progress: ${paymentData['payment_progress']}%'),
                        ],
                        if (paymentData['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Deskripsi: ${paymentData['description']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
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
}
