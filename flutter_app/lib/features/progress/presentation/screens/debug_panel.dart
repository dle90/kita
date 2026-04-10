import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/progress/presentation/providers/progress_provider.dart';
import 'package:kita_english/features/session/presentation/providers/session_provider.dart';
import 'package:kita_english/features/srs/presentation/providers/srs_provider.dart';

/// Simple month abbreviation helper (no intl dependency).
String _formatShortDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

/// Debug panel that shows personalization engine state and decisions.
class DebugPanel extends ConsumerStatefulWidget {
  const DebugPanel({super.key});

  @override
  ConsumerState<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends ConsumerState<DebugPanel> {
  int _refreshKey = 0;

  void _refresh() {
    ref.invalidate(skillSummaryProvider);
    ref.invalidate(dueCardsProvider);
    ref.invalidate(allSessionsProvider);
    ref.invalidate(progressOverviewProvider);
    ref.invalidate(vocabularyStatsProvider);
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(_refreshKey),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Debug Panel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 22),
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 22),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          // Content
          Expanded(
            child: _DebugContent(onCopy: _copyAll),
          ),
        ],
      ),
    );
  }

  void _copyAll() {
    _DebugContent.buildTextReport(ref).then((text) {
      Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied debug info to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }
}

class _DebugContent extends ConsumerWidget {
  final VoidCallback onCopy;

  const _DebugContent({required this.onCopy});

  static Future<String> buildTextReport(WidgetRef ref) async {
    final buffer = StringBuffer();
    buffer.writeln('=== Kita Debug Panel ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // Kid profile
    final storage = ref.read(secureStorageProvider);
    final kidId = await storage.readKidProfileId() ?? 'N/A';
    final charId = await storage.readSelectedCharacterId() ?? 'N/A';
    buffer.writeln('--- Kid Profile ---');
    buffer.writeln('Kid ID: $kidId');
    buffer.writeln('Character: $charId');

    // Session state
    final sessionState = ref.read(sessionProvider);
    final session = sessionState.session;
    if (session != null) {
      buffer.writeln('Current lesson: ${session.dayNumber}');
      buffer.writeln('Activities: ${session.activityCount}');
    }
    buffer.writeln();

    // Skills
    final skills = ref.read(skillSummaryProvider);
    skills.whenData((s) {
      buffer.writeln('--- Skill Scores ---');
      buffer.writeln('Listening: ${s.listening.toStringAsFixed(0)}%');
      buffer.writeln('Speaking:  ${s.speaking.toStringAsFixed(0)}%');
      buffer.writeln('Reading:   ${s.reading.toStringAsFixed(0)}%');
      buffer.writeln('Writing:   ${s.writing.toStringAsFixed(0)}%');
      buffer.writeln('Weakest:   ${s.weakestSkill}');
      buffer.writeln();
    });

    // SRS
    final cards = ref.read(dueCardsProvider);
    cards.whenData((c) {
      buffer.writeln('--- SRS Due: ${c.length} words ---');
      for (final card in c.take(10)) {
        buffer.writeln(
          '  ${card.vocabularyId} (ease: ${card.easeFactor.toStringAsFixed(1)}, '
          'interval: ${card.intervalDays}d, '
          'next: ${_formatShortDate(card.nextReviewDate)})',
        );
      }
      buffer.writeln();
    });

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKidProfileSection(ref),
          const SizedBox(height: 16),
          _buildSkillScoresSection(ref),
          const SizedBox(height: 16),
          _buildSrsDueSection(ref),
          const SizedBox(height: 16),
          _buildSessionActivitiesSection(ref),
          const SizedBox(height: 16),
          _buildWordMasterySection(ref),
          const SizedBox(height: 16),
          _buildEngineDecisionsSection(ref),
          const SizedBox(height: 16),
          // Copy button
          ElevatedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy to clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildMonoText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        height: 1.5,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          child,
        ],
      ),
    );
  }

  // --- Section 1: Kid Profile ---
  Widget _buildKidProfileSection(WidgetRef ref) {
    return FutureBuilder<Map<String, String>>(
      future: _loadKidProfile(ref),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final kidId = data?['kidId'] ?? 'Loading...';
        final charId = data?['characterId'] ?? '...';

        final sessionState = ref.watch(sessionProvider);
        final sessions = ref.watch(allSessionsProvider);
        final completedCount = sessions.whenOrNull(
              data: (s) => s.where((sess) => sess.isCompleted).length,
            ) ??
            0;

        final currentDay = sessionState.session?.dayNumber;

        return _buildSectionCard(
          title: '\u{1F464} Kid Profile',
          child: _buildMonoText(
            'Kid ID: ${_truncate(kidId, 20)}\n'
            'Character: $charId\n'
            'Current lesson: ${currentDay ?? "N/A"}\n'
            'Sessions completed: $completedCount/7',
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _loadKidProfile(WidgetRef ref) async {
    final storage = ref.read(secureStorageProvider);
    final kidId = await storage.readKidProfileId() ?? 'N/A';
    final charId = await storage.readSelectedCharacterId() ?? 'N/A';
    return {'kidId': kidId, 'characterId': charId};
  }

  // --- Section 2: Skill Scores ---
  Widget _buildSkillScoresSection(WidgetRef ref) {
    final skillsAsync = ref.watch(skillSummaryProvider);

    return _buildSectionCard(
      title: '\u{1F4CA} Skill Scores',
      child: skillsAsync.when(
        data: (skills) {
          final weakest = skills.weakestSkill;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkillBar(
                '\u{1F3A7} Listening',
                skills.listening,
                weakest == 'listening',
              ),
              _buildSkillBar(
                '\u{1F5E3} Speaking',
                skills.speaking,
                weakest == 'speaking',
              ),
              _buildSkillBar(
                '\u{1F4D6} Reading',
                skills.reading,
                weakest == 'reading',
              ),
              _buildSkillBar(
                '\u{270F}\u{FE0F} Writing',
                skills.writing,
                weakest == 'writing',
              ),
              const SizedBox(height: 4),
              _buildMonoText(
                '\u{26A1} Weakest: ${weakest[0].toUpperCase()}${weakest.substring(1)}\n'
                '\u{2705} Mastered: ${skills.wordsMastered} words\n'
                '\u{1F4DD} In progress: ${skills.wordsInProgress} words',
              ),
            ],
          );
        },
        loading: () => _buildMonoText('Loading skills...'),
        error: (e, _) => _buildMonoText('N/A (error: $e)'),
      ),
    );
  }

  Widget _buildSkillBar(String label, double pct, bool isWeakest) {
    final filled = (pct / 100 * 14).round().clamp(0, 14);
    final empty = 14 - filled;
    final bar = '\u{2588}' * filled + '\u{2591}' * empty;
    final marker = isWeakest ? ' <-- weakest' : '';
    return _buildMonoText(
      '$label: ${pct.toStringAsFixed(0).padLeft(3)}% $bar$marker',
    );
  }

  // --- Section 3: SRS Due Items ---
  Widget _buildSrsDueSection(WidgetRef ref) {
    final cardsAsync = ref.watch(dueCardsProvider);

    return _buildSectionCard(
      title: '\u{1F4DA} SRS Due Items',
      child: cardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) {
            return _buildMonoText('No SRS cards due');
          }
          final lines = StringBuffer();
          lines.writeln('Due: ${cards.length} words');
          for (final card in cards.take(10)) {
            final nextDate = _formatShortDate(card.nextReviewDate);
            lines.writeln(
              '  - ${card.vocabularyId} '
              '(ease: ${card.easeFactor.toStringAsFixed(1)}, '
              'interval: ${card.intervalDays}d, '
              'next: $nextDate)',
            );
          }
          if (cards.length > 10) {
            lines.writeln('  ... and ${cards.length - 10} more');
          }
          return _buildMonoText(lines.toString().trimRight());
        },
        loading: () => _buildMonoText('Loading SRS data...'),
        error: (e, _) => _buildMonoText('N/A (error: $e)'),
      ),
    );
  }

  // --- Section 4: Current Session Activities ---
  Widget _buildSessionActivitiesSection(WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.session;

    return _buildSectionCard(
      title: '\u{1F4CB} Session Activities',
      child: () {
        if (session == null || session.activities.isEmpty) {
          return _buildMonoText(
            'No session loaded.\nStart a lesson to see activities here.',
          );
        }

        final lines = StringBuffer();
        lines.writeln(
          'Lesson ${session.dayNumber} '
          '(${session.activityCount} activities):',
        );
        lines.writeln(
          'Progress: ${sessionState.currentActivityIndex}/${session.activityCount}',
        );
        lines.writeln(
          'Accuracy: ${sessionState.accuracyPct.toStringAsFixed(1)}%',
        );
        lines.writeln('Stars: ${sessionState.totalStarsEarned}');
        lines.writeln('');

        for (var i = 0; i < session.activities.length; i++) {
          final a = session.activities[i];
          final phase = a.config['phase'] as String? ?? '?';
          final target = a.targetWord ?? a.targetSentence ?? '';
          final current = i == sessionState.currentActivityIndex ? ' <<' : '';
          final done =
              i < sessionState.currentActivityIndex ? '\u{2705}' : '  ';

          String detail = target;
          // Add extra detail for activities with options/config
          if (a.type.apiValue == 'word_match') {
            final pairCount = a.options.length ~/ 2;
            detail = '$pairCount pairs';
          } else if (a.type.apiValue == 'flashcard_intro') {
            final words = a.config['words'] as List<dynamic>?;
            if (words != null) {
              detail =
                  '${words.length} words (${words.take(3).join(", ")}...)';
            }
          }

          lines.writeln(
            '$done ${(i + 1).toString().padLeft(2)}. [$phase] '
            '${a.type.apiValue} -> $detail$current',
          );
        }

        return _buildMonoText(lines.toString().trimRight());
      }(),
    );
  }

  // --- Section 5: Word Mastery ---
  Widget _buildWordMasterySection(WidgetRef ref) {
    final vocabAsync = ref.watch(vocabularyStatsProvider);

    return _buildSectionCard(
      title: '\u{1F4CA} Word Mastery',
      child: vocabAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return _buildMonoText('No vocabulary data available');
          }

          final lines = StringBuffer();
          final words = data['words'] as List<dynamic>? ?? [];
          final totalLearned = data['total_learned'] as int? ?? 0;
          final totalAvailable = data['total_available'] as int? ?? 0;

          lines.writeln('Learned: $totalLearned / $totalAvailable');
          lines.writeln('');

          if (words.isEmpty) {
            lines.writeln('No per-word mastery data yet');
          } else {
            lines.writeln(
              '${'Word'.padRight(12)} L    S    R    W    Overall',
            );
            lines.writeln('-' * 52);
            for (final w in words.take(10)) {
              final word = w as Map<String, dynamic>;
              final name = (word['word'] as String? ?? '?').padRight(12);
              final l = _fmtSkill(word['listening']);
              final s = _fmtSkill(word['speaking']);
              final r = _fmtSkill(word['reading']);
              final wr = _fmtSkill(word['writing']);
              final overall = _fmtSkill(word['overall']);
              lines.writeln('$name $l $s $r $wr $overall');
            }
            if (words.length > 10) {
              lines.writeln('... and ${words.length - 10} more');
            }
          }

          return _buildMonoText(lines.toString().trimRight());
        },
        loading: () => _buildMonoText('Loading vocabulary stats...'),
        error: (e, _) => _buildMonoText('N/A (error: $e)'),
      ),
    );
  }

  String _fmtSkill(dynamic value) {
    if (value == null) return ' -- ';
    final pct = (value as num).toInt();
    return '${pct.toString().padLeft(3)}%';
  }

  // --- Section 6: Engine Decisions ---
  Widget _buildEngineDecisionsSection(WidgetRef ref) {
    return FutureBuilder<String>(
      future: _buildEngineDecisions(ref),
      builder: (context, snapshot) {
        return _buildSectionCard(
          title: '\u{1F9E0} Engine Decisions',
          child: _buildMonoText(snapshot.data ?? 'Loading...'),
        );
      },
    );
  }

  Future<String> _buildEngineDecisions(WidgetRef ref) async {
    final lines = StringBuffer();

    // Skill analysis
    final skillsAsync = ref.read(skillSummaryProvider);
    skillsAsync.whenData((skills) {
      final weakest = skills.weakestSkill;
      lines.writeln(
        '- Weakest skill is '
        '${weakest[0].toUpperCase()}${weakest.substring(1)} '
        '-> activities target this skill',
      );
      if (skills.wordsMastered > 0) {
        lines.writeln(
          '- ${skills.wordsMastered} words mastered, '
          '${skills.wordsInProgress} in progress',
        );
      }
    });

    // SRS analysis
    final cardsAsync = ref.read(dueCardsProvider);
    cardsAsync.whenData((cards) {
      if (cards.isNotEmpty) {
        lines.writeln(
          '- ${cards.length} SRS due words -> inserted into warmup',
        );
        final overdue = cards.where((c) => c.isDue).length;
        if (overdue > 0) {
          lines.writeln('- $overdue cards are overdue');
        }
      } else {
        lines.writeln('- No SRS cards due -> focus on new content');
      }
    });

    // Session analysis
    final sessionState = ref.read(sessionProvider);
    final session = sessionState.session;
    if (session != null) {
      final activities = session.activities;
      // Count activity types
      final typeCounts = <String, int>{};
      for (final a in activities) {
        typeCounts[a.type.apiValue] =
            (typeCounts[a.type.apiValue] ?? 0) + 1;
      }
      lines.writeln(
        '- Activity mix: '
        '${typeCounts.entries.map((e) => '${e.key}:${e.value}').join(', ')}',
      );

      // Phase distribution
      final phaseCounts = <String, int>{};
      for (final a in activities) {
        final phase = a.config['phase'] as String? ?? 'unknown';
        phaseCounts[phase] = (phaseCounts[phase] ?? 0) + 1;
      }
      lines.writeln(
        '- Phase distribution: '
        '${phaseCounts.entries.map((e) => '${e.key}:${e.value}').join(', ')}',
      );

      // Difficulty
      final avgDiff = activities.isEmpty
          ? 0.0
          : activities.map((a) => a.difficulty).reduce((a, b) => a + b) /
              activities.length;
      lines.writeln(
        '- Average difficulty: ${avgDiff.toStringAsFixed(1)}',
      );

      if (sessionState.accuracyPct > 0) {
        lines.writeln(
          '- Last accuracy: ${sessionState.accuracyPct.toStringAsFixed(1)}%',
        );
        if (sessionState.accuracyPct > 85) {
          lines.writeln('  -> difficulty_boost may apply');
        } else if (sessionState.accuracyPct < 60) {
          lines.writeln('  -> difficulty_reduce may apply');
        }
      }
    } else {
      lines.writeln('- No session loaded yet');
    }

    // Progress overview
    final progressAsync = ref.read(progressOverviewProvider);
    progressAsync.whenData((progress) {
      lines.writeln(
        '- Challenge progress: ${progress.daysCompleted}/7 days',
      );
      if (progress.avgScore > 0) {
        lines.writeln(
          '- Average score: ${progress.avgScore.toStringAsFixed(1)}%',
        );
      }
    });

    if (lines.isEmpty) {
      return 'No engine data available yet.\nStart a lesson to see decisions.';
    }

    return lines.toString().trimRight();
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }
}

/// Shows the debug panel as a modal bottom sheet.
void showDebugPanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return const DebugPanel();
        },
      );
    },
  );
}
