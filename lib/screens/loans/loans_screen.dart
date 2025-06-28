import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../database/database_helper.dart';
import '../../models/loan_model.dart';
import '../../models/member_model.dart';
import '../../models/book_model.dart';
import '../../models/payment_model.dart';
import '../../services/book_service.dart';
import '../../services/payment_service.dart';

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
        _activeLoans = activeLoansData.map((data) => Loan.fromJson(data)).toList();
        _overdueLoans = overdueLoansData.map((data) => Loan.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading loans: $e')),
      );
    }
  }

  void _showAddLoanDialog() {
    showDialog(
      context: context,
      builder: (context) => EnhancedAddLoanDialog(
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
              final existingBook = existingBooks.where((book) => 
                book['api_book_id'] == bookData['id']).toList();
              
              if (existingBook.isNotEmpty) {
                bookId = existingBook.first['book_id'];
              } else {
                bookId = await _dbHelper.insertBook(tempBookData);
              }
            } else {
              bookId = bookData['book_id'];
              final canBorrow = await _dbHelper.canBorrowBook(memberId, bookId);
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
    );
  }

  void _returnBook(Loan loan) {
    showDialog(
      context: context,
      builder: (context) => ReturnBookDialog(
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
        builder: (context) => const AlertDialog(
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
          _showPaymentUrlDialog(invoiceUrl, paymentData['id'], loan, fineAmount);
        } else {
          throw Exception('Invoice URL tidak tersedia');
        }
      } else {
        throw Exception(paymentResponse['message'] ?? 'Gagal membuat pembayaran');
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

  void _showPaymentUrlDialog(String invoiceUrl, int paymentId, Loan loan, double fineAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pembayaran Denda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.payment,
              size: 64,
              color: Colors.blue,
            ),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
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

  Future<void> _checkPaymentStatus(int paymentId, Loan loan, double fineAmount) async {
    bool isDialogOpen = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
        final paymentResponse = await PaymentService.getPaymentDetails(paymentId);
        
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
              builder: (context) => AlertDialog(
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
                    Text('Pembayaran denda untuk buku "${loan.bookTitle}" telah berhasil diproses.'),
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
                              const Icon(Icons.payment, size: 16, color: Colors.blue),
                              const SizedBox(width: 6),
                              const Text('Detail Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Jumlah Dibayar: ${_formatCurrency(double.tryParse(paymentData['paid_amount']?.toString() ?? '0') ?? fineAmount * 1000)}'),
                          const SizedBox(height: 4),
                          Text('Metode Pembayaran: ${paymentData['payment_channel'] ?? 'Online Payment'}'),
                          const SizedBox(height: 4),
                          Text('ID Transaksi: ${paymentData['external_id'] ?? paymentData['id']}'),
                          const SizedBox(height: 4),
                          Text('Mata Uang: ${paymentData['currency'] ?? 'IDR'}'),
                          if (paymentData['paid_at'] != null) ...[
                            const SizedBox(height: 4),
                            Text('Waktu Pembayaran: ${_formatDateTime(paymentData['paid_at'])}'),
                          ],
                          if (paymentData['payment_destination'] != null) ...[
                            const SizedBox(height: 4),
                            Text('Tujuan Pembayaran: ${paymentData['payment_destination']}'),
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
                            Text('Deskripsi: ${paymentData['description']}', 
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Buku telah dikembalikan ke perpustakaan.',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
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
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
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
      return const Center(
        child: Text(
          'No loans found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final isOverdue = loan.isOverdue;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOverdue ? Colors.red : Colors.blue,
              child: Icon(
                Icons.book,
                color: Colors.white,
              ),
            ),
            title: Text(loan.bookTitle ?? 'Unknown Book'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member: ${loan.memberName ?? 'Unknown'}'),
                Text('Due: ${_formatDate(loan.dueDate)}'),
                if (loan.returnDate != null)
                  Text('Returned: ${_formatDate(loan.returnDate!)}'),
                if (loan.fineAmount > 0)
                  Text(
                    'Denda: ${_formatCurrency(loan.fineAmount * 1000)}', // Convert to Rupiah
                    style: const TextStyle(color: Colors.red),
                  ),
                Text(
                  'Status: ${loan.status}',
                  style: TextStyle(
                    color: loan.status == 'returned'
                        ? Colors.green
                        : isOverdue
                            ? Colors.red
                            : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isOverdue && loan.status == 'borrowed')
                  Text(
                    'Overdue by ${loan.daysOverdue} days',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: loan.status == 'borrowed'
                ? ElevatedButton(
                    onPressed: () => _returnBook(loan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Return'),
                  )
                : null,
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
      appBar: AppBar(
        title: const Text('Peminjaman'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Semua (${_allLoans.length})'),
            Tab(text: 'Aktif (${_activeLoans.length})'),
            Tab(text: 'Terlambat (${_overdueLoans.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLoansList(_allLoans),
                _buildLoansList(_activeLoans),
                _buildLoansList(_overdueLoans),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLoanDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class EnhancedAddLoanDialog extends StatefulWidget {
  final Function(int memberId, Map<String, dynamic> bookData, DateTime dueDate, bool isFromApi) onSave;

  const EnhancedAddLoanDialog({Key? key, required this.onSave}) : super(key: key);

  @override
  State<EnhancedAddLoanDialog> createState() => _EnhancedAddLoanDialogState();
}

class _EnhancedAddLoanDialogState extends State<EnhancedAddLoanDialog> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _localBooks = [];
  List<Book> _apiBooks = [];
  List<dynamic> _filteredBooks = [];
  int? _selectedMemberId;
  Map<String, dynamic>? _selectedBook;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  bool _isLoading = true;
  bool _isSearching = false;
  bool _useApiBooks = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final members = await _dbHelper.getAllMembers();
      final localBooks = await _dbHelper.getAvailableLocalBooks();
      setState(() {
        _members = members.where((m) => m['membership_status'] == 'active').toList();
        _localBooks = localBooks;
        _filteredBooks = _localBooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchBooks(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredBooks = _useApiBooks ? _apiBooks : _localBooks;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      if (_useApiBooks) {
        final apiBooks = await BookService.searchBooks(query);
        setState(() {
          _apiBooks = apiBooks;
          _filteredBooks = apiBooks;
          _isSearching = false;
        });
      } else {
        final filtered = _localBooks.where((book) =>
          book['title'].toLowerCase().contains(query.toLowerCase()) ||
          (book['author'] ?? '').toLowerCase().contains(query.toLowerCase())
        ).toList();
        setState(() {
          _filteredBooks = filtered;
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error pencarian: $e')),
      );
    }
  }

  Future<void> _loadApiBooks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiBooks = await BookService.getAllBooks();
      setState(() {
        _apiBooks = apiBooks;
        _filteredBooks = apiBooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error memuat data API: $e')),
      );
    }
  }

  void _toggleBookSource(bool useApi) {
    setState(() {
      _useApiBooks = useApi;
      _selectedBook = null;
      _searchController.clear();
      _searchQuery = '';
    });

    if (useApi && _apiBooks.isEmpty) {
      _loadApiBooks();
    } else {
      setState(() {
        _filteredBooks = useApi ? _apiBooks : _localBooks;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buat Peminjaman Baru'),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Member Selection
                  DropdownButtonFormField<int>(
                    value: _selectedMemberId,
                    decoration: InputDecoration(
                      labelText: 'Pilih Anggota',
                      border: const OutlineInputBorder(),
                    ),
                    items: _members.map((member) {
                      return DropdownMenuItem<int>(
                        value: member['member_id'],
                        child: Text(member['full_name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMemberId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Book Source Toggle
                  Row(
                    children: [
                      const Text('Sumber Buku'),
                      const SizedBox(width: 16),
                      ChoiceChip(
                        label: const Text('Buku Lokal'),
                        selected: !_useApiBooks,
                        onSelected: (selected) => _toggleBookSource(!selected),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Buku Online'),
                        selected: _useApiBooks,
                        onSelected: (selected) => _toggleBookSource(selected),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Cari Buku',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchBooks('');
                                  },
                                )
                              : null,
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _searchBooks(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Books List
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _filteredBooks.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ada buku ditemukan',
                                style: const TextStyle(fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredBooks.length,
                              itemBuilder: (context, index) {
                                final book = _filteredBooks[index];
                                final isSelected = _selectedBook != null &&
                                    ((_useApiBooks && _selectedBook!['id'] == book.id) ||
                                     (!_useApiBooks && _selectedBook!['book_id'] == book['book_id']));
                                
                                return ListTile(
                                  selected: isSelected,
                                  leading: CircleAvatar(
                                    backgroundColor: _useApiBooks ? Colors.green : Colors.blue,
                                    child: Icon(
                                      Icons.book,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    _useApiBooks ? book.title : book['title'],
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_useApiBooks) ...[
                                        Text('Penerbit: ${book.publisher}'),
                                        Text('Tahun: ${book.year}'),
                                        Text('Halaman: ${book.pages}'),
                                      ] else ...[
                                        Text('Penulis: ${book['author'] ?? 'Unknown'}'),
                                        Text('Stok: ${book['stock_quantity']}'),
                                      ]
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (_useApiBooks) {
                                        _selectedBook = {
                                          'id': book.id,
                                          'title': book.title,
                                          'author': 'Stephen King', // API is Stephen King books
                                          'publisher': book.publisher,
                                          'year': book.year,
                                          'pages': book.pages,
                                          'isbn': book.isbn,
                                        };
                                      } else {
                                        _selectedBook = book;
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Due Date Selection
                  Row(
                    children: [
                      const Text('Tanggal Jatuh Tempo: '),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime(2020), // Allow past dates for development
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _dueDate = date;
                            });
                          }
                        },
                        child: Text(
                          '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _selectedMemberId != null && _selectedBook != null
              ? () {
                  widget.onSave(_selectedMemberId!, _selectedBook!, _dueDate, _useApiBooks);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Buat Peminjaman'),
        ),
      ],
    );
  }
}

class ReturnBookDialog extends StatefulWidget {
  final Loan loan;
  final Function(double? fineAmount) onReturn;

  const ReturnBookDialog({
    Key? key,
    required this.loan,
    required this.onReturn,
  }) : super(key: key);

  @override
  State<ReturnBookDialog> createState() => _ReturnBookDialogState();
}

class _ReturnBookDialogState extends State<ReturnBookDialog> {
  final TextEditingController _fineController = TextEditingController();
  double _calculatedFine = 0.0;
  bool _isManualInput = false;

  @override
  void initState() {
    super.initState();
    _calculateFine();
  }

  void _calculateFine() {
    if (widget.loan.isOverdue) {
      // Calculate fine: Rp 1000 per day overdue
      _calculatedFine = widget.loan.daysOverdue * 1000.0; // Direct Rupiah calculation
      _fineController.text = _formatRupiah(_calculatedFine);
    }
  }

  String _formatRupiah(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  double _parseRupiah(String text) {
    // Remove 'Rp' and dots, then parse
    String cleanText = text.replaceAll('Rp', '').replaceAll('.', '').trim();
    return double.tryParse(cleanText) ?? 0.0;
  }

  @override
  void dispose() {
    _fineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Return Book'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book: ${widget.loan.bookTitle}'),
          Text('Member: ${widget.loan.memberName}'),
          Text('Due Date: ${widget.loan.dueDate.day}/${widget.loan.dueDate.month}/${widget.loan.dueDate.year}'),
          if (widget.loan.isOverdue) ...
            [
              const SizedBox(height: 16),
              Text(
                'This book is overdue by ${widget.loan.daysOverdue} days',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _isManualInput,
                    onChanged: (value) {
                      setState(() {
                        _isManualInput = value ?? false;
                        if (!_isManualInput) {
                          _calculateFine(); // Reset to calculated fine
                        }
                      });
                    },
                  ),
                  const Text('Input manual'),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _fineController,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Denda',
                  border: OutlineInputBorder(),
                  helperText: 'Pembayaran akan diproses melalui Xendit',
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                readOnly: !_isManualInput,
                onChanged: (value) {
                  if (_isManualInput) {
                    // Format input as user types
                    String cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (cleanValue.isNotEmpty) {
                      double amount = double.parse(cleanValue);
                      String formatted = _formatRupiah(amount);
                      _fineController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pembayaran denda akan menggunakan sistem Xendit untuk keamanan transaksi.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            double? fineAmount;
            if (_fineController.text.isNotEmpty) {
              if (_isManualInput) {
                fineAmount = _parseRupiah(_fineController.text) / 1000; // Convert back to USD for payment processing
              } else {
                fineAmount = _calculatedFine / 1000; // Convert back to USD for payment processing
              }
            }
            widget.onReturn(fineAmount);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Return Book'),
        ),
      ],
    );
  }
}