/// Rol dentro de una banda (enum `member_role` en la base).
enum MemberRole {
  owner,
  member;

  static MemberRole fromDb(String value) {
    return MemberRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => MemberRole.member,
    );
  }

  String get dbValue => name;
}

/// Relación persona ↔ banda (tabla `band_members`).
class BandMember {
  final String bandId;
  final String userId;
  final MemberRole role;
  final DateTime createdAt;

  const BandMember({
    required this.bandId,
    required this.userId,
    this.role = MemberRole.member,
    required this.createdAt,
  });

  bool get isOwner => role == MemberRole.owner;

  factory BandMember.fromJson(Map<String, dynamic> json) {
    return BandMember(
      bandId: json['band_id'] as String,
      userId: json['user_id'] as String,
      role: MemberRole.fromDb((json['role'] as String?) ?? 'member'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'band_id': bandId,
    'user_id': userId,
    'role': role.dbValue,
  };
}
