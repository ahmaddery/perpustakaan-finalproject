import 'package:sqflite/sqflite.dart';

class MemberQueries {
  /// Insert a new member
  static Future<int> insertMember(
    Database db,
    Map<String, dynamic> member,
  ) async {
    member['registered_at'] = DateTime.now().toIso8601String();
    member['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('members', member);
  }

  /// Get all members
  static Future<List<Map<String, dynamic>>> getAllMembers(Database db) async {
    return await db.query('members', orderBy: 'full_name ASC');
  }

  /// Get member by ID
  static Future<Map<String, dynamic>?> getMemberById(
    Database db,
    int memberId,
  ) async {
    List<Map<String, dynamic>> result = await db.query(
      'members',
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Update member information
  static Future<int> updateMember(
    Database db,
    int memberId,
    Map<String, dynamic> member,
  ) async {
    member['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'members',
      member,
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
  }

  /// Delete a member
  static Future<int> deleteMember(
    Database db,
    int memberId,
  ) async {
    return await db.delete(
      'members',
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
  }

  /// Search members by name or email
  static Future<List<Map<String, dynamic>>> searchMembers(
    Database db,
    String query,
  ) async {
    return await db.query(
      'members',
      where: 'full_name LIKE ? OR email LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'full_name ASC',
    );
  }
}