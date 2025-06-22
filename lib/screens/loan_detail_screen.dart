import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/loan_model.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class LoanDetailScreen extends StatefulWidget {
  final int loanId;

  const LoanDetailScreen({Key? key, required this.loanId}) : super(key: key);

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  // SettingsService methods are static, no need to instantiate
  
  Loan? _loan;
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _book;
  bool _isLoading = true;
  String _currentLanguage = 'id';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadLoanDetails();
  }

  Future<void> _loadLanguage() async {
    final language = await SettingsService.getLanguage();
    setState(() {
      _currentLanguage = language;
    });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Navigator.of(context).pop();
  }

  Future<void> _returnBook() async {
    if (_loan == null) return;
    
    try {
      final fineAmount = _loan!.isOverdue ? _loan!.daysOverdue * 1.0 : 0.0;
      
      await _dbHelper.returnBook(_loan!.loanId!, fineAmount: fineAmount);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buku berhasil dikembalikan')),
      );
      
      // Reload loan details
      await _loadLoanDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error returning book: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationService.getText('loan_details', _currentLanguage)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
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
                                    color: _loan!.status == 'returned'
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
                                      color: _loan!.status == 'returned'
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
                              _buildInfoRow('Judul', _book?['title'] ?? 'Unknown'),
                              _buildInfoRow('Penulis', _book?['author'] ?? 'Unknown'),
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
                              _buildInfoRow('Nama', _member?['full_name'] ?? 'Unknown'),
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
                              _buildInfoRow('ID Peminjaman', _loan!.loanId.toString()),
                              _buildInfoRow('Tanggal Pinjam', _formatDate(_loan!.loanDate)),
                              _buildInfoRow('Tanggal Jatuh Tempo', _formatDate(_loan!.dueDate)),
                              if (_loan!.returnDate != null)
                                _buildInfoRow('Tanggal Kembali', _formatDate(_loan!.returnDate!)),
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
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}