import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../database/database_helper.dart';
import '../../models/loan_model.dart';
import '../../models/member_model.dart';
import '../../models/book_model.dart';
import '../../models/payment_model.dart';
import '../../services/book_service.dart';
import '../../services/payment_service.dart';
import 'return_book_dialog.dart';
import 'create_loan_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({Key? key}) : super(key: key);

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TabController _tabController;
  List<Loan> _allLoans = [];
  List<Loan> _activeLoans = [];
  List<Loan> _overdueLoans = [];
  bool _isLoading = true;
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
        amount: fineAmount * 1000, // Convert to Rupiah (assuming $1 = Rp 1000)
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
                  'Jumlah: ${_formatCurrency(fineAmount * 1000)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Silakan lakukan pembayaran melalui link berikut:',
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
                    invoiceUrl,
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
                },
                child: const Text('Tutup'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _checkPaymentStatus(paymentId, loan, fineAmount);
                },
                child: const Text('Cek Status Pembayaran'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (await canLaunchUrl(Uri.parse(invoiceUrl))) {
                    await launchUrl(
                      Uri.parse(invoiceUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Buka Link Pembayaran'),
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
    bool isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Mengecek status pembayaran...'),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    isDialogOpen = false;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
    ).then((_) {
      isDialogOpen = false;
    });

    try {
      // Poll payment status every 3 seconds until paid or cancelled
      while (isDialogOpen) {
        final paymentResponse = await PaymentService.getPaymentDetails(
          paymentId,
        );

        if (paymentResponse['success'] == true) {
          final paymentData = paymentResponse['data'];
          final status = paymentData['status'];

          if (status == 'paid') {
            // Payment completed, close dialog and return the book
            if (isDialogOpen) {
              isDialogOpen = false;
              Navigator.of(context).pop(); // Close loading dialog
            }

            // Show success popup
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 28),
                        SizedBox(width: 8),
                        Text('Pembayaran Berhasil!'),
                      ],
                    ),
                    content: Column(
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Jumlah Dibayar: ${_formatCurrency(double.tryParse(paymentData['paid_amount']?.toString() ?? '0') ?? fineAmount * 1000)}',
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
                              Text(
                                'Mata Uang: ${paymentData['currency'] ?? 'IDR'}',
                              ),
                              if (paymentData['paid_at'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Waktu Pembayaran: ${_formatDateTime(paymentData['paid_at'])}',
                                ),
                              ],
                              if (paymentData['payment_destination'] !=
                                  null) ...[
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
                                Text(
                                  'Progress: ${paymentData['payment_progress']}%',
                                ),
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
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
            );

            await _dbHelper.returnBook(loan.loanId!, fineAmount: fineAmount);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pembayaran berhasil! Buku telah dikembalikan.'),
                backgroundColor: Colors.green,
              ),
            );

            _loadLoans();
            return;
          } else if (status == 'expired' || status == 'failed') {
            // Payment failed or expired
            if (isDialogOpen) {
              isDialogOpen = false;
              Navigator.of(context).pop(); // Close loading dialog
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pembayaran $status. Silakan coba lagi.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          // If status is still 'pending', continue polling
        }

        // Wait 3 seconds before next check
        await Future.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      if (isDialogOpen) {
        isDialogOpen = false;
        Navigator.of(context).pop(); // Close loading dialog
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking payment status: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                                      'Denda: ${_formatCurrency(loan.fineAmount * 1000)}',
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
                    const SizedBox(
                      width: 48,
                    ), // Placeholder to maintain spacing
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
}
