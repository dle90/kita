/// Vietnamese dialect options.
enum Dialect {
  bac('Bắc', 'Northern'),
  trung('Trung', 'Central'),
  nam('Nam', 'Southern');

  final String vietnameseName;
  final String englishName;
  const Dialect(this.vietnameseName, this.englishName);
}

/// English proficiency level.
enum EnglishLevel {
  none('Chưa biết gì', 'No knowledge', 0),
  beginner('Biết một chút', 'Knows a little', 1),
  school('Đã học ở trường', 'Learned at school', 2);

  final String vietnameseName;
  final String englishName;
  final int value;
  const EnglishLevel(this.vietnameseName, this.englishName, this.value);
}

/// Represents a child's profile in the Kita English system.
class KidProfile {
  final String id;
  final String parentId;
  final String displayName;
  final String characterId;
  final int age;
  final Dialect dialect;
  final EnglishLevel englishLevel;
  final int? placementScore;
  final DateTime createdAt;

  const KidProfile({
    required this.id,
    required this.parentId,
    required this.displayName,
    required this.characterId,
    required this.age,
    required this.dialect,
    required this.englishLevel,
    this.placementScore,
    required this.createdAt,
  });

  KidProfile copyWith({
    String? id,
    String? parentId,
    String? displayName,
    String? characterId,
    int? age,
    Dialect? dialect,
    EnglishLevel? englishLevel,
    int? placementScore,
    DateTime? createdAt,
  }) {
    return KidProfile(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      displayName: displayName ?? this.displayName,
      characterId: characterId ?? this.characterId,
      age: age ?? this.age,
      dialect: dialect ?? this.dialect,
      englishLevel: englishLevel ?? this.englishLevel,
      placementScore: placementScore ?? this.placementScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory KidProfile.fromJson(Map<String, dynamic> json) {
    return KidProfile(
      id: json['id'] as String? ?? '',
      parentId: json['parent_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      characterId: json['character_id'] as String? ?? 'mochi',
      age: json['age'] as int? ?? 7,
      dialect: Dialect.values.firstWhere(
        (d) => d.name == (json['dialect'] as String? ?? 'bac'),
        orElse: () => Dialect.bac,
      ),
      englishLevel: EnglishLevel.values.firstWhere(
        (l) => l.name == (json['english_level'] as String? ?? 'none'),
        orElse: () => EnglishLevel.none,
      ),
      placementScore: json['placement_score'] as int?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'display_name': displayName,
      'character_id': characterId,
      'age': age,
      'dialect': dialect.name,
      'english_level': englishLevel.name,
      if (placementScore != null) 'placement_score': placementScore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KidProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
