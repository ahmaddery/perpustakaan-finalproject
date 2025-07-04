import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/member_model.dart';
import '../../services/member_firestore_service.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({Key? key}) : super(key: key);

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadLastSyncTime();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final membersData = await _dbHelper.getAllMembers();
      setState(() {
        _members = membersData.map((data) => Member.fromJson(data)).toList();
        _filteredMembers = _members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
    }
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final syncTime = await MemberFirestoreService.getLastSyncTime();
      setState(() {
        _lastSyncTime = syncTime;
      });
    } catch (e) {
      print('Error loading last sync time: $e');
    }
  }

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // Perform smart sync
      await MemberFirestoreService.smartSync();
      
      // Reload local data
      await _loadMembers();
      await _loadLastSyncTime();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil disinkronisasi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sinkronisasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _syncToFirestore() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await MemberFirestoreService.syncMembersToFirestore();
      await _loadLastSyncTime();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil diupload ke Firestore'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error upload: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _syncFromFirestore() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await MemberFirestoreService.syncMembersFromFirestore();
      await _loadMembers();
      await _loadLastSyncTime();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil didownload dari Firestore'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error download: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  String _formatSyncTime(DateTime syncTime) {
    final now = DateTime.now();
    final difference = now.difference(syncTime);
    
    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} jam yang lalu';
    } else {
      return '${difference.inDays} hari yang lalu';
    }
  }

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _members;
      } else {
        _filteredMembers =
            _members
                .where(
                  (member) =>
                      member.fullName.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      member.email.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AddEditMemberDialog(
            onSave: (member) async {
              try {
                await _dbHelper.insertMember(member.toJson());
                _loadMembers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Member added successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding member: $e')),
                );
              }
            },
          ),
    );
  }

  void _showEditMemberDialog(Member member) {
    showDialog(
      context: context,
      builder:
          (context) => AddEditMemberDialog(
            member: member,
            onSave: (updatedMember) async {
              try {
                await _dbHelper.updateMember(
                  member.memberId!,
                  updatedMember.toJson(),
                );
                _loadMembers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Member updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating member: $e')),
                );
              }
            },
          ),
    );
  }

  void _deleteMember(Member member) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Member'),
            content: Text(
              'Are you sure you want to delete ${member.fullName}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _dbHelper.deleteMember(member.memberId!);
                    Navigator.pop(context);
                    _loadMembers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Member deleted successfully'),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting member: $e')),
                    );
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Members',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sync, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'smart_sync':
                  _syncData();
                  break;
                case 'upload':
                  _syncToFirestore();
                  break;
                case 'download':
                  _syncFromFirestore();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'smart_sync',
                child: Row(
                  children: [
                    Icon(Icons.sync_alt, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    const Text('Smart Sync'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    const Text('Upload ke Firestore'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.cloud_download, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    const Text('Download dari Firestore'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Anggota: ${_filteredMembers.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_lastSyncTime != null)
                            Text(
                              'Terakhir sync: ${_formatSyncTime(_lastSyncTime!)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Anggota',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Cari anggota...',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF667eea),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onChanged: _filterMembers,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _syncData,
              color: const Color(0xFF667eea),
              child: Stack(
                children: [
                  _isLoading
                      ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF667eea),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Memuat data anggota...',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                      : _filteredMembers.isEmpty
                      ? ListView(
                        children: const [
                          SizedBox(height: 200),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Tidak ada anggota ditemukan',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tarik ke bawah untuk menyinkronkan data',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [Colors.white, Color(0xFFF8F9FA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF667eea),
                                            Color(0xFF764ba2),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF667eea,
                                            ).withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          member.fullName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            member.fullName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D3748),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.email_outlined,
                                                size: 16,
                                                color: Color(0xFF667eea),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  member.email,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF718096),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (member.phoneNumber != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.phone_outlined,
                                                  size: 16,
                                                  color: Color(0xFF667eea),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  member.phoneNumber!,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF718096),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  member.membershipStatus ==
                                                          'active'
                                                      ? Colors.green
                                                          .withOpacity(0.1)
                                                      : member.membershipStatus ==
                                                          'inactive'
                                                      ? Colors.orange
                                                          .withOpacity(0.1)
                                                      : Colors.red.withOpacity(
                                                        0.1,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color:
                                                    member.membershipStatus ==
                                                            'active'
                                                        ? Colors.green
                                                        : member.membershipStatus ==
                                                            'inactive'
                                                        ? Colors.orange
                                                        : Colors.red,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              member.membershipStatus
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                color:
                                                    member.membershipStatus ==
                                                            'active'
                                                        ? Colors.green
                                                        : member.membershipStatus ==
                                                            'inactive'
                                                        ? Colors.orange
                                                        : Colors.red,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Color(0xFF667eea),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      itemBuilder:
                                          (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit_outlined,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEditMemberDialog(member);
                                        } else if (value == 'delete') {
                                          _deleteMember(member);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (_isSyncing)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF667eea),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Menyinkronkan data...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddMemberDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

class AddEditMemberDialog extends StatefulWidget {
  final Member? member;
  final Function(Member) onSave;

  const AddEditMemberDialog({Key? key, this.member, required this.onSave})
    : super(key: key);

  @override
  State<AddEditMemberDialog> createState() => _AddEditMemberDialogState();
}

class _AddEditMemberDialogState extends State<AddEditMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  DateTime? _dateOfBirth;
  String _membershipStatus = 'active';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.member?.fullName ?? '',
    );
    _emailController = TextEditingController(text: widget.member?.email ?? '');
    _phoneController = TextEditingController(
      text: widget.member?.phoneNumber ?? '',
    );
    _addressController = TextEditingController(
      text: widget.member?.address ?? '',
    );
    _dateOfBirth = widget.member?.dateOfBirth;
    _membershipStatus = widget.member?.membershipStatus ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.member == null ? Icons.person_add : Icons.edit,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.member == null
                        ? 'Tambah Anggota Baru'
                        : 'Edit Anggota',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nama Lengkap',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan nama lengkap';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan email';
                          }
                          if (!value.contains('@')) {
                            return 'Silakan masukkan email yang valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Nomor Telepon',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Alamat',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.calendar_today_outlined,
                            color: Color(0xFF667eea),
                          ),
                          title: Text(
                            _dateOfBirth != null
                                ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                : 'Pilih Tanggal Lahir',
                            style: TextStyle(
                              color:
                                  _dateOfBirth != null
                                      ? Colors.black
                                      : Colors.grey[600],
                            ),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _dateOfBirth ?? DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _dateOfBirth = date;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _membershipStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status Keanggotaan',
                            prefixIcon: Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF667eea),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Aktif'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Tidak Aktif'),
                            ),
                            DropdownMenuItem(
                              value: 'suspended',
                              child: Text('Ditangguhkan'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _membershipStatus = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer with buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667eea).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final member = Member(
                            memberId: widget.member?.memberId,
                            fullName: _nameController.text,
                            email: _emailController.text,
                            phoneNumber:
                                _phoneController.text.isEmpty
                                    ? null
                                    : _phoneController.text,
                            address:
                                _addressController.text.isEmpty
                                    ? null
                                    : _addressController.text,
                            dateOfBirth: _dateOfBirth,
                            membershipStatus: _membershipStatus,
                            registeredAt:
                                widget.member?.registeredAt ?? DateTime.now(),
                            updatedAt: DateTime.now(),
                          );
                          widget.onSave(member);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Simpan Anggota',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
