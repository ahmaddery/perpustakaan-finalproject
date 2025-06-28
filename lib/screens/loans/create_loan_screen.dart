import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/book_model.dart';
import '../../services/book_service.dart';

class CreateLoanScreen extends StatefulWidget {
  final Function(
    int memberId,
    Map<String, dynamic> bookData,
    DateTime dueDate,
    bool isFromApi,
  )
  onSave;

  const CreateLoanScreen({Key? key, required this.onSave}) : super(key: key);

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _localBooks = [];
  List<Book> _apiBooks = [];
  List<dynamic> _filteredBooks = [];
  List<Map<String, dynamic>> _filteredMembers = [];

  int? _selectedMemberId;
  Map<String, dynamic>? _selectedBook;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));

  bool _isLoading = true;
  bool _isSearching = false;
  bool _useApiBooks = false;
  String _searchQuery = '';
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final members = await _dbHelper.getAllMembers();
      final localBooks = await _dbHelper.getAvailableLocalBooks();
      setState(() {
        _members =
            members.where((m) => m['membership_status'] == 'active').toList();
        _filteredMembers = _members;
        _localBooks = localBooks;
        _filteredBooks = _localBooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error memuat data: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
        final filtered =
            _localBooks
                .where(
                  (book) =>
                      book['title'].toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      (book['author'] ?? '').toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
        setState(() {
          _filteredBooks = filtered;
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showErrorSnackbar('Error pencarian: $e');
    }
  }

  void _searchMembers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMembers = _members;
      });
      return;
    }

    final filtered =
        _members
            .where(
              (member) =>
                  member['full_name'].toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  member['email'].toLowerCase().contains(query.toLowerCase()) ||
                  member['member_id'].toString().contains(query),
            )
            .toList();

    setState(() {
      _filteredMembers = filtered;
    });
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
      _showErrorSnackbar('Error memuat data API: $e');
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

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishLoanCreation();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _finishLoanCreation() {
    if (_selectedMemberId != null && _selectedBook != null) {
      widget.onSave(_selectedMemberId!, _selectedBook!, _dueDate, _useApiBooks);
      Navigator.pop(context);
    } else {
      _showErrorSnackbar('Silakan lengkapi semua data peminjaman');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Buat Peminjaman Baru'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Progress Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: Colors.blue,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 4,
                                  color:
                                      _currentStep >= 0
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 4,
                                  color:
                                      _currentStep >= 1
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 4,
                                  color:
                                      _currentStep >= 2
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStepIndicator(
                              0,
                              'Pilih Anggota',
                              _currentStep >= 0,
                            ),
                            _buildStepIndicator(
                              1,
                              'Pilih Buku',
                              _currentStep >= 1,
                            ),
                            _buildStepIndicator(
                              2,
                              'Konfirmasi',
                              _currentStep >= 2,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMemberSelectionStep(),
                        _buildBookSelectionStep(),
                        _buildConfirmationStep(),
                      ],
                    ),
                  ),
                ],
              ),
      bottomNavigationBar:
          _isLoading
              ? null
              : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      TextButton.icon(
                        onPressed: _previousStep,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Kembali'),
                      )
                    else
                      const SizedBox(),
                    ElevatedButton(
                      onPressed:
                          _currentStep == 0 && _selectedMemberId == null
                              ? null
                              : _currentStep == 1 && _selectedBook == null
                              ? null
                              : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _currentStep < 2 ? 'Lanjutkan' : 'Selesai',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              (step + 1).toString(),
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and description
          const Text(
            'Pilih Anggota Perpustakaan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih anggota yang akan meminjam buku',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari anggota...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            onChanged: _searchMembers,
          ),
          const SizedBox(height: 16),

          // Members list
          Expanded(
            child:
                _filteredMembers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada anggota ditemukan',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final isSelected =
                            _selectedMemberId == member['member_id'];

                        return Card(
                          elevation: isSelected ? 4 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color:
                              isSelected ? Colors.blue.shade50 : Colors.white,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedMemberId = member['member_id'];
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? Colors.blue.shade100
                                              : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color:
                                          isSelected
                                              ? Colors.blue
                                              : Colors.grey.shade600,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member['full_name'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color:
                                                isSelected
                                                    ? Colors.blue.shade800
                                                    : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${member['member_id']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          member['email'],
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and description
          const Text(
            'Pilih Buku',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih buku yang akan dipinjam',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Book source toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _toggleBookSource(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_useApiBooks ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Buku Lokal',
                          style: TextStyle(
                            color:
                                !_useApiBooks
                                    ? Colors.white
                                    : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _toggleBookSource(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _useApiBooks ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Buku API',
                          style: TextStyle(
                            color:
                                _useApiBooks
                                    ? Colors.white
                                    : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari buku...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _isSearching
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            onChanged: (value) {
              _searchQuery = value;
              _searchBooks(value);
            },
          ),
          const SizedBox(height: 16),

          // Books list
          Expanded(
            child:
                _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredBooks.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada buku ditemukan',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredBooks.length,
                      itemBuilder: (context, index) {
                        final book = _filteredBooks[index];
                        final isSelected =
                            _selectedBook != null &&
                            ((_useApiBooks &&
                                    _selectedBook!['id'] == book.id) ||
                                (!_useApiBooks &&
                                    _selectedBook!['book_id'] ==
                                        book['book_id']));

                        return Card(
                          elevation: isSelected ? 4 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color:
                              isSelected ? Colors.blue.shade50 : Colors.white,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (_useApiBooks) {
                                  _selectedBook = {
                                    'id': book.id,
                                    'title': book.title,
                                    'author':
                                        book.villains.isNotEmpty
                                            ? book.villains
                                                .map((v) => v.name)
                                                .join(', ')
                                            : 'Unknown',
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
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? Colors.blue.shade100
                                              : _useApiBooks
                                              ? Colors.green.shade100
                                              : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.book,
                                      color:
                                          isSelected
                                              ? Colors.blue
                                              : _useApiBooks
                                              ? Colors.green
                                              : Colors.blue,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _useApiBooks
                                              ? book.title
                                              : book['title'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color:
                                                isSelected
                                                    ? Colors.blue.shade800
                                                    : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (_useApiBooks) ...[
                                          Text(
                                            'Penulis: ${book.villains.isNotEmpty ? book.villains.map((v) => v.name).join(', ') : 'Unknown'}',
                                          ),
                                          Text('Penerbit: ${book.publisher}'),
                                          Text('Tahun: ${book.year}'),
                                          Text('Halaman: ${book.pages}'),
                                        ] else ...[
                                          Text(
                                            'Penulis: ${book['author'] ?? 'Unknown'}',
                                          ),
                                          Text(
                                            'Stok: ${book['stock_quantity']}',
                                          ),
                                          if (book['publisher'] != null)
                                            Text(
                                              'Penerbit: ${book['publisher']}',
                                            ),
                                          if (book['year'] != null)
                                            Text('Tahun: ${book['year']}'),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    final selectedMember =
        _selectedMemberId != null
            ? _members.firstWhere((m) => m['member_id'] == _selectedMemberId)
            : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Konfirmasi Peminjaman',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Periksa detail peminjaman sebelum melanjutkan',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Loan details card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member details
                  const Text(
                    'Detail Anggota',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  if (selectedMember != null) ...[
                    _buildDetailRow('Nama', selectedMember['full_name']),
                    _buildDetailRow(
                      'ID Anggota',
                      selectedMember['member_id'].toString(),
                    ),
                    _buildDetailRow('Email', selectedMember['email']),
                    const SizedBox(height: 16),
                  ],

                  // Book details
                  const Text(
                    'Detail Buku',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  if (_selectedBook != null) ...[
                    _buildDetailRow(
                      'Judul',
                      _useApiBooks
                          ? _selectedBook!['title']
                          : _selectedBook!['title'],
                    ),
                    _buildDetailRow(
                      'Penulis',
                      _useApiBooks
                          ? _selectedBook!['author']
                          : _selectedBook!['author'] ?? 'Unknown',
                    ),
                    if (_useApiBooks) ...[
                      _buildDetailRow('Penerbit', _selectedBook!['publisher']),
                      _buildDetailRow(
                        'Tahun',
                        _selectedBook!['year'].toString(),
                      ),
                      _buildDetailRow(
                        'Halaman',
                        _selectedBook!['pages'].toString(),
                      ),
                    ] else ...[
                      if (_selectedBook!['publisher'] != null)
                        _buildDetailRow(
                          'Penerbit',
                          _selectedBook!['publisher'],
                        ),
                      if (_selectedBook!['year'] != null)
                        _buildDetailRow(
                          'Tahun',
                          _selectedBook!['year'].toString(),
                        ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Loan details
                  const Text(
                    'Detail Peminjaman',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Tanggal Peminjaman',
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  ),
                  _buildDetailRow(
                    'Tanggal Jatuh Tempo',
                    '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                  ),
                  _buildDetailRow(
                    'Durasi',
                    '${_dueDate.difference(DateTime.now()).inDays} hari',
                  ),
                  _buildDetailRow('Status', 'Dipinjam'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Due date selection
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubah Tanggal Jatuh Tempo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Tanggal Jatuh Tempo:'),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setState(() {
                              _dueDate = date;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24), // Add extra bottom padding for scrolling
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
