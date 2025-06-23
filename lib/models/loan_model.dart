class Loan {
  final int? loanId;
  final int memberId;
  final int bookId;
  final DateTime loanDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final double fineAmount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional fields for display purposes
  final String? memberName;
  final String? bookTitle;

  Loan({
    this.loanId,
    required this.memberId,
    required this.bookId,
    required this.loanDate,
    required this.dueDate,
    this.returnDate,
    this.fineAmount = 0.0,
    this.status = 'borrowed',
    required this.createdAt,
    required this.updatedAt,
    this.memberName,
    this.bookTitle,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      loanId: json['loan_id'],
      memberId: json['member_id'],
      bookId: json['book_id'],
      loanDate: DateTime.parse(json['loan_date']),
      dueDate: DateTime.parse(json['due_date']),
      returnDate: json['return_date'] != null 
          ? DateTime.parse(json['return_date'])
          : null,
      fineAmount: (json['fine_amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'borrowed',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      memberName: json['member_name'],
      bookTitle: json['book_title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loan_id': loanId,
      'member_id': memberId,
      'book_id': bookId,
      'loan_date': loanDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'return_date': returnDate?.toIso8601String(),
      'fine_amount': fineAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Loan copyWith({
    int? loanId,
    int? memberId,
    int? bookId,
    DateTime? loanDate,
    DateTime? dueDate,
    DateTime? returnDate,
    double? fineAmount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? memberName,
    String? bookTitle,
  }) {
    return Loan(
      loanId: loanId ?? this.loanId,
      memberId: memberId ?? this.memberId,
      bookId: bookId ?? this.bookId,
      loanDate: loanDate ?? this.loanDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      fineAmount: fineAmount ?? this.fineAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberName: memberName ?? this.memberName,
      bookTitle: bookTitle ?? this.bookTitle,
    );
  }

  bool get isOverdue {
    if (returnDate != null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.isAfter(dueDateOnly);
  }

  int get daysOverdue {
    if (!isOverdue) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.difference(dueDateOnly).inDays;
  }
}