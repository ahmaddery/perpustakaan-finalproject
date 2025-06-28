import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Statistik peminjaman harian/bulanan
      final dailyLoans = await db.rawQuery(
        'SELECT DATE(loan_date) as date, COUNT(*) as count FROM loans WHERE loan_date >= date("now", "-30 days") GROUP BY DATE(loan_date) ORDER BY date DESC LIMIT 7',
      );

      final monthlyLoans = await db.rawQuery(
        'SELECT strftime("%Y-%m", loan_date) as month, COUNT(*) as count FROM loans GROUP BY strftime("%Y-%m", loan_date) ORDER BY month DESC LIMIT 6',
      );

      // Buku paling populer
      final popularBooks = await db.rawQuery(
        '''SELECT b.title, b.author, COUNT(l.loan_id) as loan_count 
           FROM books b 
           LEFT JOIN loans l ON b.book_id = l.book_id 
           GROUP BY b.book_id 
           ORDER BY loan_count DESC 
           LIMIT 5''',
      );

      // Member paling aktif
      final activeMembers = await db.rawQuery(
        '''SELECT m.full_name, m.email, COUNT(l.loan_id) as loan_count 
           FROM members m 
           LEFT JOIN loans l ON m.member_id = l.member_id 
           GROUP BY m.member_id 
           ORDER BY loan_count DESC 
           LIMIT 5''',
      );

      // Laporan keterlambatan
      final overdueLoans = await db.rawQuery(
        '''SELECT m.full_name, b.title, l.loan_date, l.due_date, 
           julianday('now') - julianday(l.due_date) as days_overdue
           FROM loans l
           JOIN members m ON l.member_id = m.member_id
           JOIN books b ON l.book_id = b.book_id
           WHERE l.return_date IS NULL AND l.due_date < date('now')
           ORDER BY days_overdue DESC''',
      );

      // Total statistik
      final totalBooks = await db.rawQuery(
        'SELECT COUNT(*) as count FROM books',
      );
      final totalMembers = await db.rawQuery(
        'SELECT COUNT(*) as count FROM members',
      );
      final totalLoans = await db.rawQuery(
        'SELECT COUNT(*) as count FROM loans',
      );
      final activeLoans = await db.rawQuery(
        'SELECT COUNT(*) as count FROM loans WHERE return_date IS NULL',
      );

      setState(() {
        _analyticsData = {
          'dailyLoans': dailyLoans,
          'monthlyLoans': monthlyLoans,
          'popularBooks': popularBooks,
          'activeMembers': activeMembers,
          'overdueLoans': overdueLoans,
          'totalBooks': totalBooks.first['count'],
          'totalMembers': totalMembers.first['count'],
          'totalLoans': totalLoans.first['count'],
          'activeLoans': activeLoans.first['count'],
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Laporan Analytics',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Cards
                    _buildOverviewSection(),
                    const SizedBox(height: 24),

                    // Statistik Peminjaman
                    _buildLoanStatisticsSection(),
                    const SizedBox(height: 24),

                    // Buku Populer
                    _buildPopularBooksSection(),
                    const SizedBox(height: 24),

                    // Member Aktif
                    _buildActiveMembersSection(),
                    const SizedBox(height: 24),

                    // Laporan Keterlambatan
                    _buildOverdueReportsSection(),
                  ],
                ),
              ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildOverviewCard(
              title: 'Total Buku',
              value: _analyticsData['totalBooks']?.toString() ?? '0',
              icon: Icons.library_books,
              color: Colors.blue,
            ),
            _buildOverviewCard(
              title: 'Total Member',
              value: _analyticsData['totalMembers']?.toString() ?? '0',
              icon: Icons.people,
              color: Colors.green,
            ),
            _buildOverviewCard(
              title: 'Total Peminjaman',
              value: _analyticsData['totalLoans']?.toString() ?? '0',
              icon: Icons.assignment,
              color: Colors.orange,
            ),
            _buildOverviewCard(
              title: 'Sedang Dipinjam',
              value: _analyticsData['activeLoans']?.toString() ?? '0',
              icon: Icons.schedule,
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoanStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistik Peminjaman',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Peminjaman 7 Hari Terakhir',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_analyticsData['dailyLoans']?.isNotEmpty == true)
                ..._analyticsData['dailyLoans'].map<Widget>((loan) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDate(loan['date'])),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${loan['count']} peminjaman',
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()
              else
                Text(
                  'Tidak ada data peminjaman',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPopularBooksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buku Paling Populer',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_analyticsData['popularBooks']?.isNotEmpty == true)
                ..._analyticsData['popularBooks'].asMap().entries.map<Widget>((
                  entry,
                ) {
                  final index = entry.key;
                  final book = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _getRankColor(index),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book['title'] ?? 'Unknown Title',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                book['author'] ?? 'Unknown Author',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${book['loan_count']} kali',
                            style: TextStyle(color: Colors.green[700]),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()
              else
                Text(
                  'Tidak ada data buku populer',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Member Paling Aktif',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_analyticsData['activeMembers']?.isNotEmpty == true)
                ..._analyticsData['activeMembers'].asMap().entries.map<Widget>((
                  entry,
                ) {
                  final index = entry.key;
                  final member = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _getRankColor(index),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member['full_name'] ?? 'Unknown Member',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                member['email'] ?? 'No email',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${member['loan_count']} peminjaman',
                            style: TextStyle(color: Colors.teal[700]),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()
              else
                Text(
                  'Tidak ada data member aktif',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverdueReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Laporan Keterlambatan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_analyticsData['overdueLoans']?.isNotEmpty == true)
                ..._analyticsData['overdueLoans'].map<Widget>((loan) {
                  final daysOverdue = (loan['days_overdue'] as double).round();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.red[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loan['full_name'] ?? 'Unknown Member',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$daysOverdue hari',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loan['title'] ?? 'Unknown Book',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Jatuh tempo: ${_formatDate(loan['due_date'])}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList()
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[600]),
                      const SizedBox(width: 12),
                      Text(
                        'Tidak ada keterlambatan saat ini',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber; // Gold
      case 1:
        return Colors.grey; // Silver
      case 2:
        return Colors.brown; // Bronze
      default:
        return Colors.blue;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
