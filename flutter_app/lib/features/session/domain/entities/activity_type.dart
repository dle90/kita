/// Types of activities available in a session.
enum ActivityType {
  listenTap('listen_tap', 'Listen & Tap', 'Nghe và chọn'),
  repeatAfterMe('repeat_after_me', 'Repeat After Me', 'Nói theo mẫu'),
  wordMatch('word_match', 'Word Match', 'Nối từ'),
  sentenceBuilder('sentence_builder', 'Sentence Builder', 'Xếp câu');

  final String apiValue;
  final String englishName;
  final String vietnameseName;

  const ActivityType(this.apiValue, this.englishName, this.vietnameseName);

  /// Parse from API string value.
  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => ActivityType.listenTap,
    );
  }
}
