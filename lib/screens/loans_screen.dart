import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/loan_model.dart';
import '../models/member_model.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

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
  String _currentLanguage = 'id';

  Future<void> _loadLanguage() async {
    final language = await SettingsService.getLanguage();
    setState(() {
      _currentLanguage = language;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLanguage();
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
        currentLanguage: _currentLanguage,
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
                    content: Text(LocalizationService.getText('book_not_available', _currentLanguage)),
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
              SnackBar(content: Text(LocalizationService.getText('loan_created_success', _currentLanguage))),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${LocalizationService.getText('error_creating_loan', _currentLanguage)}: $e')),
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
            await _dbHelper.returnBook(loan.loanId!, fineAmount: fineAmount);
            _loadLoans();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book returned successfully')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error returning book: $e')),
            );
          }
        },
      ),
    );
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
                    'Fine: \$${loan.fineAmount.toStringAsFixed(2)}',
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
        title: Text(LocalizationService.getText('loans', _currentLanguage)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: '${LocalizationService.getText('all', _currentLanguage)} (${_allLoans.length})'),
            Tab(text: '${LocalizationService.getText('active', _currentLanguage)} (${_activeLoans.length})'),
            Tab(text: '${LocalizationService.getText('overdue', _currentLanguage)} (${_overdueLoans.length})'),
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
  final String currentLanguage;

  const EnhancedAddLoanDialog({Key? key, required this.onSave, required this.currentLanguage}) : super(key: key);

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
        SnackBar(content: Text('${LocalizationService.getText('search_error', widget.currentLanguage)}: $e')),
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
        SnackBar(content: Text('${LocalizationService.getText('api_load_error', widget.currentLanguage)}: $e')),
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
      title: Text(LocalizationService.getText('create_new_loan', widget.currentLanguage)),
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
                      labelText: LocalizationService.getText('select_member', widget.currentLanguage),
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
                      Text(LocalizationService.getText('book_source', widget.currentLanguage)),
                      const SizedBox(width: 16),
                      ChoiceChip(
                        label: Text(LocalizationService.getText('local_books', widget.currentLanguage)),
                        selected: !_useApiBooks,
                        onSelected: (selected) => _toggleBookSource(!selected),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(LocalizationService.getText('online_books', widget.currentLanguage)),
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
                      labelText: LocalizationService.getText('search_books', widget.currentLanguage),
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
                                LocalizationService.getText('no_books_found', widget.currentLanguage),
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
                                        Text('${LocalizationService.getText('publisher', widget.currentLanguage)}: ${book.publisher}'),
                                        Text('${LocalizationService.getText('year', widget.currentLanguage)}: ${book.year}'),
                                        Text('${LocalizationService.getText('pages', widget.currentLanguage)}: ${book.pages}'),
                                      ] else ...[
                                        Text(LocalizationService.getText('author', widget.currentLanguage) + ': ' + (book['author'] ?? 'Unknown')),
                                        Text(LocalizationService.getText('stock', widget.currentLanguage) + ': ' + book['stock_quantity'].toString()),
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
                      Text('${LocalizationService.getText('due_date', widget.currentLanguage)}: '),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime.now(),
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
          child: Text(LocalizationService.getText('cancel', widget.currentLanguage)),
        ),
        ElevatedButton(
          onPressed: _selectedMemberId != null && _selectedBook != null
              ? () {
                  widget.onSave(_selectedMemberId!, _selectedBook!, _dueDate, _useApiBooks);
                  Navigator.pop(context);
                }
              : null,
          child: Text(LocalizationService.getText('create_loan', widget.currentLanguage)),
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

  @override
  void initState() {
    super.initState();
    _calculateFine();
  }

  void _calculateFine() {
    if (widget.loan.isOverdue) {
      // Calculate fine: $1 per day overdue
      _calculatedFine = widget.loan.daysOverdue * 1.0;
      _fineController.text = _calculatedFine.toStringAsFixed(2);
    }
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
              TextField(
                controller: _fineController,
                decoration: const InputDecoration(
                  labelText: 'Fine Amount (\$)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
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
              fineAmount = double.tryParse(_fineController.text);
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