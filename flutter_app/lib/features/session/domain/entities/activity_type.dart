/// Types of activities available in a session.
enum ActivityType {
  listenTap('listen_tap', 'Listen & Tap', 'Nghe và chọn'),
  repeatAfterMe('repeat_after_me', 'Repeat After Me', 'Nói theo mẫu'),
  wordMatch('word_match', 'Word Match', 'Nối từ'),
  sentenceBuilder('sentence_builder', 'Sentence Builder', 'Xếp câu'),
  flashcardIntro('flashcard_intro', 'Flashcard', 'Học từ mới'),
  listenAndRepeat('listen_and_repeat', 'Listen & Repeat', 'Nghe và nhắc lại'),
  listenAndChoose('listen_and_choose', 'Listen & Choose', 'Nghe và chọn'),
  speakWord('speak_word', 'Speak', 'Phát âm'),
  buildSentence('build_sentence', 'Build Sentence', 'Xếp câu'),
  fillBlank('fill_blank', 'Fill in the Blank', 'Điền từ'),
  phonicsListen('phonics_listen', 'Phonics', 'Luyện âm'),
  phonicsMatch('phonics_match', 'Sound Match', 'Nối âm'),
  patternIntro('pattern_intro', 'Grammar', 'Ngữ pháp');

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
