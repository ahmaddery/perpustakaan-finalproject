class Member {
  final int? memberId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? address;
  final DateTime? dateOfBirth;
  final String membershipStatus;
  final DateTime registeredAt;
  final DateTime updatedAt;

  Member({
    this.memberId,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.address,
    this.dateOfBirth,
    this.membershipStatus = 'active',
    required this.registeredAt,
    required this.updatedAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      memberId: json['member_id'],
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'],
      address: json['address'],
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.parse(json['date_of_birth'])
          : null,
      membershipStatus: json['membership_status'] ?? 'active',
      registeredAt: DateTime.parse(json['registered_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': memberId,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'address': address,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'membership_status': membershipStatus,
      'registered_at': registeredAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Member copyWith({
    int? memberId,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? address,
    DateTime? dateOfBirth,
    String? membershipStatus,
    DateTime? registeredAt,
    DateTime? updatedAt,
  }) {
    return Member(
      memberId: memberId ?? this.memberId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      registeredAt: registeredAt ?? this.registeredAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}