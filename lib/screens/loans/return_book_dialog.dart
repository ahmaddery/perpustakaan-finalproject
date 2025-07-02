import 'package:flutter/material.dart';
import '../../models/loan_model.dart';

class ReturnBookDialog extends StatefulWidget {
  final Loan loan;
  final Function(double? fineAmount) onReturn;

  const ReturnBookDialog({Key? key, required this.loan, required this.onReturn})
    : super(key: key);

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
      _calculatedFine =
          widget.loan.daysOverdue * 1000.0; // Direct Rupiah calculation
      _fineController.text = _formatRupiah(_calculatedFine);
    }
  }

  String _formatRupiah(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
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
      title: const Text('Pengembalian Buku'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.book, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.loan.bookTitle ?? 'Unknown Book',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Peminjam: ${widget.loan.memberName}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Jatuh Tempo: ${widget.loan.dueDate.day}/${widget.loan.dueDate.month}/${widget.loan.dueDate.year}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (widget.loan.isOverdue) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Buku terlambat ${widget.loan.daysOverdue} hari',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isManualInput,
                    activeColor: Colors.blue.shade700,
                    onChanged: (value) {
                      setState(() {
                        _isManualInput = value ?? false;
                        if (!_isManualInput) {
                          _calculateFine(); // Reset to calculated fine
                        }
                      });
                    },
                  ),
                  const Text('Input manual denda'),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _fineController,
                decoration: InputDecoration(
                  labelText: 'Jumlah Denda',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Pembayaran akan diproses melalui Xendit',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor:
                      _isManualInput ? Colors.white : Colors.grey.shade100,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.blue.shade500,
                      width: 2,
                    ),
                  ),
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
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pembayaran denda akan menggunakan sistem Xendit untuk keamanan transaksi.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.assignment_return, size: 18),
          label: const Text('Kembalikan Buku'),
          onPressed: () {
            double? fineAmount;
            if (_fineController.text.isNotEmpty) {
              if (_isManualInput) {
                fineAmount = _parseRupiah(
                  _fineController.text,
                ); // Keep in Rupiah format
              } else {
                fineAmount = _calculatedFine; // Keep in Rupiah format
              }
            }
            widget.onReturn(fineAmount);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
