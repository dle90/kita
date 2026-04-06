/// Represents a parent account in the Kita English system.
class ParentAccount {
  final String id;
  final String email;
  final String? phone;
  final DateTime createdAt;

  const ParentAccount({
    required this.id,
    required this.email,
    this.phone,
    required this.createdAt,
  });

  ParentAccount copyWith({
    String? id,
    String? email,
    String? phone,
    DateTime? createdAt,
  }) {
    return ParentAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParentAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ParentAccount(id: $id, email: $email)';
}
