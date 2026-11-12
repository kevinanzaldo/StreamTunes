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
