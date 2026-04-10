import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';
import 'package:kita_english/core/network/api_client.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/progress/presentation/providers/progress_provider.dart';
import 'package:kita_english/features/session/domain/entities/activity_result.dart';
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
            child: _DebugContent(
              onCopy: _copyAll,
              onRefresh: _refresh,
            ),
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

class _DebugContent extends ConsumerStatefulWidget {
  final VoidCallback onCopy;
  final VoidCallback onRefresh;

  const _DebugContent({required this.onCopy, required this.onRefresh});

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
  ConsumerState<_DebugContent> createState() => _DebugContentState();
}

class _DebugContentState extends ConsumerState<_DebugContent> {
  // Test profile state
  String? _activeProfile;
  bool _isLoadingProfile = false;

  // Auto-play state
  bool _isAutoPlaying = false;
  int _autoPlayDay = 1;
  final List<String> _autoPlayLog = [];

  // Content browser state
  Map<String, dynamic>? _allContent;
  bool _isLoadingContent = false;
  final Set<String> _expandedContentSections = {};

  Future<String> _getKidId() async {
    final storage = ref.read(secureStorageProvider);
    return await storage.readKidProfileId() ?? '';
  }

  // --- Test Profile Loading ---
  Future<void> _loadProfile(String profileName) async {
    setState(() {
      _isLoadingProfile = true;
      _activeProfile = profileName;
    });

    try {
      final dio = ref.read(dioProvider);
      final kidId = await _getKidId();
      await dio.post(
        ApiEndpoints.debugLoadProfile,
        data: {
          'profile': profileName,
          'kid_id': kidId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile "$profileName" loaded!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green[700],
          ),
        );
        widget.onRefresh();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.message}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  // --- Auto-play ---
  Future<void> _autoPlayLesson(int dayNumber) async {
    setState(() {
      _isAutoPlaying = true;
      _autoPlayDay = dayNumber;
      _autoPlayLog.clear();
    });

    final rng = Random();
    final dio = ref.read(dioProvider);
    final kidId = await _getKidId();

    // Determine accuracy ranges based on active profile
    final double minAcc;
    final double maxAcc;
    final int maxAttempts;
    switch (_activeProfile) {
      case 'beginner':
        minAcc = 40;
        maxAcc = 60;
        maxAttempts = 3;
      case 'day3':
        minAcc = 60;
        maxAcc = 80;
        maxAttempts = 2;
      case 'day5':
        minAcc = 70;
        maxAcc = 85;
        maxAttempts = 2;
      case 'advanced':
        minAcc = 80;
        maxAcc = 95;
        maxAttempts = 1;
      case 'almost_done':
        minAcc = 85;
        maxAcc = 100;
        maxAttempts = 1;
      default:
        minAcc = 60;
        maxAcc = 80;
        maxAttempts = 2;
    }

    try {
      // 1. Start session
      _addLog('\u25B6\uFE0F Auto-play B\u00E0i $dayNumber starting...');
      await dio.post(ApiEndpoints.sessionStart(kidId, dayNumber));

      // 2. Fetch session to get activities
      final sessionResp =
          await dio.get(ApiEndpoints.session(kidId, dayNumber));
      final sessionData = sessionResp.data as Map<String, dynamic>;
      final activities =
          (sessionData['activities'] as List<dynamic>?) ?? [];

      if (activities.isEmpty) {
        _addLog('  No activities found for B\u00E0i $dayNumber');
        setState(() => _isAutoPlaying = false);
        return;
      }

      _addLog(
          '  Found ${activities.length} activities. Simulating results...');

      int totalStars = 0;
      int correctCount = 0;
      int totalCount = activities.length;

      // 3. Iterate activities and submit simulated results
      for (var i = 0; i < activities.length; i++) {
        final activity = activities[i] as Map<String, dynamic>;
        final activityId = activity['id'] as String? ?? '';
        final activityType = activity['activity_type'] as String? ?? 'unknown';
        final phase = activity['phase'] as String? ?? '?';
        final config = activity['config'] as Map<String, dynamic>? ?? {};

        // Determine target word/sentence for display
        String target = '';
        if (config['target_word'] != null) {
          target = config['target_word'] as String;
        } else if (config['target_sentence'] != null) {
          target = config['target_sentence'] as String;
        } else if (config['words'] is List) {
          final words = config['words'] as List;
          target = '${words.length} words';
        }

        // Simulate result
        final score =
            minAcc + rng.nextDouble() * (maxAcc - minAcc);
        final isCorrect = score >= 50;
        final attempts =
            isCorrect ? (1 + rng.nextInt(maxAttempts)) : maxAttempts;
        final starsEarned =
            ActivityResult.calculateStars(isCorrect: isCorrect, attempts: attempts);
        totalStars += starsEarned;
        if (isCorrect) correctCount++;

        // Build result text
        String resultText;
        if (activityType == 'flashcard_intro') {
          resultText = 'PASS (auto)';
        } else if (!isCorrect) {
          resultText = 'WRONG (${attempts}x, score: ${score.toInt()})';
        } else if (attempts > 1) {
          resultText =
              'WRONG \u2192 CORRECT (${attempts}nd attempt, score: ${score.toInt()})';
        } else {
          resultText = 'CORRECT (1st attempt, score: ${score.toInt()})';
        }

        _addLog(
            '  ${i + 1}. [$phase] $activityType \u2192 $target \u2192 $resultText');

        // Submit to backend
        final timeSpentMs =
            2000 + rng.nextInt(8000); // 2-10 seconds simulated
        try {
          await dio.post(
            ApiEndpoints.activityResult(kidId, activityId),
            data: {
              'activity_type': activityType,
              'is_correct': isCorrect,
              'attempts': attempts,
              'time_spent_ms': timeSpentMs,
              'stars_earned': starsEarned,
              'metadata': {
                'simulated': true,
                'profile': _activeProfile,
                'score': score.toInt(),
              },
            },
          );
        } catch (e) {
          _addLog('    (submit error: $e)');
        }
      }

      // 4. Complete session
      final accuracyPct =
          totalCount > 0 ? (correctCount / totalCount) * 100 : 0.0;
      try {
        await dio.post(
          ApiEndpoints.sessionComplete(kidId, dayNumber),
          data: {
            'total_stars': totalStars,
            'accuracy_pct': accuracyPct,
          },
        );
      } catch (e) {
        _addLog('  (complete error: $e)');
      }

      _addLog('');
      _addLog(
          '  \u2B50 Stars: $totalStars/${totalCount * 3} | '
          'Accuracy: ${accuracyPct.toStringAsFixed(0)}% | '
          'Time: ~${totalCount * 5}s (simulated)');

      // 5. Fetch engine recommendation
      try {
        final skillsResp =
            await dio.get(ApiEndpoints.progressSkills(kidId));
        final skillsData = skillsResp.data as Map<String, dynamic>;
        final weakest =
            skillsData['weakest_skill'] as String? ?? 'unknown';
        final nextDay = dayNumber < 7 ? dayNumber + 1 : 7;
        _addLog('');
        _addLog(
            '  \u{1F9E0} Engine suggests next: B\u00E0i $nextDay');
        _addLog(
            '  Reason: B\u00E0i $dayNumber completed with '
            '${accuracyPct.toStringAsFixed(0)}% accuracy.');
        _addLog(
            '  ${weakest[0].toUpperCase()}${weakest.substring(1)} skill weakest '
            '\u2192 next session will add more targeted activities.');
      } catch (_) {
        // Skill data unavailable
      }

      widget.onRefresh();
    } catch (e) {
      _addLog('  ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _isAutoPlaying = false);
      }
    }
  }

  void _addLog(String line) {
    if (mounted) {
      setState(() => _autoPlayLog.add(line));
    }
  }

  // --- Content Browser ---
  Future<void> _fetchAllContent() async {
    setState(() => _isLoadingContent = true);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiEndpoints.debugContentAll);
      if (mounted) {
        setState(() {
          _allContent = response.data as Map<String, dynamic>?;
          _isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContent = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch content: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTestProfilesSection(),
          const SizedBox(height: 16),
          _buildAutoPlaySection(),
          const SizedBox(height: 16),
          _buildContentBrowserSection(),
          const SizedBox(height: 16),
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
            onPressed: widget.onCopy,
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

  // ============================================================
  // TEST PROFILES SECTION
  // ============================================================

  Widget _buildTestProfilesSection() {
    return _buildSectionCard(
      title: '\u{1F9EA} Test Profiles (tap to load)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingProfile)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _profileButton(
                '\u{1F476} Beginner',
                'beginner',
                'Fresh start, no mastery data',
              ),
              _profileButton(
                '\u{1F4D7} Day 3',
                'day3',
                '30% through, L:70% W:20%',
              ),
              _profileButton(
                '\u{1F4D8} Day 5',
                'day5',
                '60% through, balanced 50-60%',
              ),
              _profileButton(
                '\u{1F4D9} Advanced',
                'advanced',
                '90% through, speaking weak',
              ),
              _profileButton(
                '\u{1F393} Almost Done',
                'almost_done',
                'All seen, writing at 60%',
              ),
            ],
          ),
          if (_activeProfile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildMonoText(
                  'Active profile: $_activeProfile'),
            ),
        ],
      ),
    );
  }

  Widget _profileButton(
      String label, String profileName, String tooltip) {
    final isActive = _activeProfile == profileName;
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed:
            _isLoadingProfile ? null : () => _loadProfile(profileName),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isActive ? Colors.deepPurple : Colors.grey[200],
          foregroundColor:
              isActive ? Colors.white : Colors.black87,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Text(label),
      ),
    );
  }

  // ============================================================
  // AUTO-PLAY SECTION
  // ============================================================

  Widget _buildAutoPlaySection() {
    return _buildSectionCard(
      title: '\u25B6\uFE0F Auto-play Lesson',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('B\u00E0i: ',
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 12)),
              DropdownButton<int>(
                value: _autoPlayDay,
                items: List.generate(
                  7,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('${i + 1}'),
                  ),
                ),
                onChanged: _isAutoPlaying
                    ? null
                    : (v) => setState(() => _autoPlayDay = v ?? 1),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isAutoPlaying
                    ? null
                    : () => _autoPlayLesson(_autoPlayDay),
                icon: _isAutoPlaying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(
                    _isAutoPlaying ? 'Running...' : 'Auto-play'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_autoPlayLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Text(
                  _autoPlayLog.join('\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.greenAccent,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT BROWSER SECTION
  // ============================================================

  Widget _buildContentBrowserSection() {
    return _buildSectionCard(
      title: '\u{1F4DA} Content Repository',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_allContent == null)
            ElevatedButton.icon(
              onPressed:
                  _isLoadingContent ? null : _fetchAllContent,
              icon: _isLoadingContent
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 18),
              label: Text(_isLoadingContent
                  ? 'Loading...'
                  : 'Fetch All Content'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            )
          else
            _buildContentBrowser(),
        ],
      ),
    );
  }

  Widget _buildContentBrowser() {
    final content = _allContent;
    if (content == null) return const SizedBox.shrink();

    final vocab = content['vocabulary'] as List<dynamic>? ?? [];
    final grammar =
        content['grammar_structures'] as List<dynamic>? ?? [];
    final patterns = content['patterns'] as List<dynamic>? ?? [];
    final phonemes = content['phonemes'] as List<dynamic>? ?? [];
    final commFns =
        content['communication_functions'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCollapsibleContent(
          'vocabulary',
          'Vocabulary (${vocab.length} words)',
          _buildVocabContent(vocab),
        ),
        _buildCollapsibleContent(
          'grammar',
          'Grammar Structures (${grammar.length})',
          _buildGrammarContent(grammar),
        ),
        _buildCollapsibleContent(
          'patterns',
          'Patterns (${patterns.length})',
          _buildPatternsContent(patterns),
        ),
        _buildCollapsibleContent(
          'phonemes',
          'Phonemes (${phonemes.length})',
          _buildPhonemesContent(phonemes),
        ),
        _buildCollapsibleContent(
          'comm_functions',
          'Communication Functions (${commFns.length})',
          _buildCommFunctionsContent(commFns),
        ),
      ],
    );
  }

  Widget _buildCollapsibleContent(
      String key, String title, Widget content) {
    final isExpanded = _expandedContentSections.contains(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedContentSections.remove(key);
              } else {
                _expandedContentSections.add(key);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.expand_more
                      : Icons.chevron_right,
                  size: 18,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 22, bottom: 8),
            child: content,
          ),
      ],
    );
  }

  Widget _buildVocabContent(List<dynamic> vocab) {
    // Group by day
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final v in vocab) {
      final item = v as Map<String, dynamic>;
      final day = (item['day_number'] as num?)?.toInt() ?? 0;
      byDay.putIfAbsent(day, () => []).add(item);
    }
    final days = byDay.keys.toList()..sort();

    final lines = StringBuffer();
    for (final day in days) {
      final words = byDay[day]!;
      final wordStrs = words
          .map((w) =>
              '${w['word'] ?? '?'} ${w['emoji'] ?? ''}')
          .join(', ');
      lines.writeln(
          'B\u00E0i $day: $wordStrs');
    }
    return _buildMonoText(lines.toString().trimRight());
  }

  Widget _buildGrammarContent(List<dynamic> grammar) {
    final lines = StringBuffer();
    for (var i = 0; i < grammar.length; i++) {
      final gs = grammar[i] as Map<String, dynamic>;
      final name = gs['name'] ?? '?';
      final template = gs['template'] ?? '';
      final cefr = gs['cefr_level'] ?? '';
      final diff = gs['difficulty'] ?? 0;
      final prereqs = gs['prerequisite_ids'] as List<dynamic>? ?? [];
      final prereqStr =
          prereqs.isNotEmpty ? ' \u2190 requires: ${prereqs.join(", ")}' : '';
      lines.writeln(
          '${i + 1}. $name ($template) [$cefr, diff:$diff]$prereqStr');
    }
    return _buildMonoText(lines.toString().trimRight());
  }

  Widget _buildPatternsContent(List<dynamic> patterns) {
    final lines = StringBuffer();
    for (final p in patterns) {
      final item = p as Map<String, dynamic>;
      final template = item['template'] ?? '?';
      final fn = item['communication_function'] ?? '';
      final day = item['day_introduced'] ?? 0;
      lines.writeln(
          '"$template" \u2192 fn: $fn, b\u00E0i: $day');
    }
    return _buildMonoText(lines.toString().trimRight());
  }

  Widget _buildPhonemesContent(List<dynamic> phonemes) {
    final lines = StringBuffer();
    for (final p in phonemes) {
      final item = p as Map<String, dynamic>;
      final symbol = item['symbol'] ?? '?';
      final graphemes = (item['graphemes'] as List<dynamic>?)
              ?.join(', ') ??
          '';
      final example = item['example_word'] ?? '';
      final isNew = item['is_new_for_vietnamese'] == true;
      final diff = item['difficulty'] ?? 0;
      final sub = item['common_substitution'] ?? '';
      final newTag = isNew ? ' [NEW for VN, diff:$diff]' : ' [diff:$diff]';
      final subTag = sub.toString().isNotEmpty ? ' confuse with $sub' : '';
      lines.writeln(
          '/$symbol/ $graphemes \u2014 $example$newTag$subTag');
    }
    return _buildMonoText(lines.toString().trimRight());
  }

  Widget _buildCommFunctionsContent(List<dynamic> commFns) {
    final lines = StringBuffer();
    for (final cf in commFns) {
      final item = cf as Map<String, dynamic>;
      final name = item['name'] ?? '?';
      final nameVi = item['name_vi'] ?? '';
      final patternIds =
          (item['pattern_ids'] as List<dynamic>?)?.join(', ') ?? '';
      lines.writeln(
          '$name ($nameVi) \u2192 patterns: $patternIds');
    }
    return _buildMonoText(lines.toString().trimRight());
  }

  // ============================================================
  // EXISTING SECTIONS (preserved from original)
  // ============================================================

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

  // --- Section: Kid Profile ---
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

  // --- Section: Skill Scores ---
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

  // --- Section: SRS Due Items ---
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

  // --- Section: Current Session Activities ---
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

  // --- Section: Word Mastery ---
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

  // --- Section: Engine Decisions ---
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
