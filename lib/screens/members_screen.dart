import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/member_model.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMembers();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading members: $e')),
      );
    }
  }

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _members;
      } else {
        _filteredMembers = _members
            .where((member) =>
                member.fullName.toLowerCase().contains(query.toLowerCase()) ||
                member.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEditMemberDialog(
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
      builder: (context) => AddEditMemberDialog(
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member.fullName}?'),
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
                  const SnackBar(content: Text('Member deleted successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting member: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search members',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterMembers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                    ? const Center(
                        child: Text(
                          'No members found',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  member.fullName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(member.fullName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(member.email),
                                  if (member.phoneNumber != null)
                                    Text(member.phoneNumber!),
                                  Text(
                                    'Status: ${member.membershipStatus}',
                                    style: TextStyle(
                                      color: member.membershipStatus == 'active'
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
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
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemberDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class AddEditMemberDialog extends StatefulWidget {
  final Member? member;
  final Function(Member) onSave;

  const AddEditMemberDialog({
    Key? key,
    this.member,
    required this.onSave,
  }) : super(key: key);

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
    _nameController = TextEditingController(text: widget.member?.fullName ?? '');
    _emailController = TextEditingController(text: widget.member?.email ?? '');
    _phoneController = TextEditingController(text: widget.member?.phoneNumber ?? '');
    _addressController = TextEditingController(text: widget.member?.address ?? '');
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
    return AlertDialog(
      title: Text(widget.member == null ? 'Add Member' : 'Edit Member'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Date of Birth: '),
                  TextButton(
                    onPressed: () async {
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
                    child: Text(
                      _dateOfBirth != null
                          ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                          : 'Select Date',
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _membershipStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (value) {
                  setState(() {
                    _membershipStatus = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final member = Member(
                memberId: widget.member?.memberId,
                fullName: _nameController.text,
                email: _emailController.text,
                phoneNumber: _phoneController.text.isEmpty ? null : _phoneController.text,
                address: _addressController.text.isEmpty ? null : _addressController.text,
                dateOfBirth: _dateOfBirth,
                membershipStatus: _membershipStatus,
                registeredAt: widget.member?.registeredAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );
              widget.onSave(member);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}