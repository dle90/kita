package session

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/content"
	"github.com/kitaenglish/backend/internal/curriculum"
	"github.com/kitaenglish/backend/internal/srs"
)

// GenerateDynamicSession builds a list of activities at runtime from content + learner state.
// Returns (activities, decisionLog, error). The decisionLog explains WHY each activity was chosen.
func GenerateDynamicSession(
	ctx context.Context,
	kidID uuid.UUID,
	unitNumber int,
	plan SessionPlan,
	contentRepo content.ContentRepository,
	masteryRepo srs.SkillMasteryRepository,
	srsRepo srs.SrsRepository,
	phonemeMasteryRepo srs.PhonemeMasteryRepository,
	curriculumRepo curriculum.Repository,
	vocabByWord map[string]*content.Vocabulary,
	allVocab []*content.Vocabulary,
	patterns []*content.Pattern,
	allPhonemes []*content.Phoneme,
	allGrammarStructures []*content.GrammarStructure,
	curriculumUnits []*content.CurriculumUnit,
) ([]Activity, []string, error) {
	var activities []Activity
	var decisionLog []string

	// Resolve curriculum unit from DB-backed list. Unit 1 is the fallback when
	// the requested unit is missing.
	unitByNumber := make(map[int]*content.CurriculumUnit, len(curriculumUnits))
	for _, u := range curriculumUnits {
		unitByNumber[u.UnitNumber] = u
	}
	unit, hasUnit := unitByNumber[unitNumber]
	if !hasUnit {
		unit = unitByNumber[1]
		if unit != nil {
			decisionLog = append(decisionLog, fmt.Sprintf("[engine] Unit %d not found, falling back to Unit 1", unitNumber))
		}
	}

	// Resolve unit words to vocabulary objects
	var unitWords []*content.Vocabulary
	var unitTheme string
	if unit != nil {
		unitTheme = unit.Theme
		for _, w := range unit.Words {
			if v, ok := vocabByWord[strings.ToLower(w)]; ok {
				unitWords = append(unitWords, v)
			}
		}
	}
	// If no unit words resolved from DB, use all vocab for this day
	if len(unitWords) == 0 {
		for _, v := range allVocab {
			if v.DayNumber == unitNumber {
				unitWords = append(unitWords, v)
			}
		}
		if len(unitWords) > 0 {
			decisionLog = append(decisionLog, fmt.Sprintf("[engine] Unit words not in DB, using %d words from day %d", len(unitWords), unitNumber))
		}
	}
	// Last resort: use all available vocabulary
	if len(unitWords) == 0 {
		unitWords = allVocab
		decisionLog = append(decisionLog, "[engine] No unit-specific words, using all vocabulary")
	}

	// Query learner state (tolerate errors for fresh users)
	var dueCards []*srs.SrsCard
	if srsRepo != nil {
		cards, err := srsRepo.GetDueCards(ctx, kidID, time.Now())
		if err == nil {
			dueCards = cards
		}
	}

	var weakWords []*srs.WordSkillMastery
	var skillSummary map[srs.SkillType]float64
	if masteryRepo != nil {
		ww, err := masteryRepo.GetWeakestSkillWords(ctx, kidID, 20)
		if err == nil {
			weakWords = ww
		}
		ss, err := masteryRepo.GetSkillSummary(ctx, kidID)
		if err == nil {
			skillSummary = ss
		}
	}
	if skillSummary == nil {
		skillSummary = map[srs.SkillType]float64{
			srs.SkillListening: 0,
			srs.SkillSpeaking:  0,
			srs.SkillReading:   0,
			srs.SkillWriting:   0,
		}
	}

	// Build mastery lookup by vocab ID
	masteryByVocabID := make(map[uuid.UUID]*srs.WordSkillMastery)
	for _, ww := range weakWords {
		masteryByVocabID[ww.VocabularyID] = ww
	}

	// Build due cards vocab ID set
	dueVocabIDs := make(map[uuid.UUID]bool)
	for _, c := range dueCards {
		dueVocabIDs[c.VocabularyID] = true
	}

	// --- Phase 3: Phoneme learner state ---
	var weakPhonemeIDs []string
	if phonemeMasteryRepo != nil {
		weakPhonemes, err := phonemeMasteryRepo.GetWeakestPhonemes(ctx, kidID, 5)
		if err == nil {
			for _, pm := range weakPhonemes {
				weakPhonemeIDs = append(weakPhonemeIDs, pm.PhonemeID)
			}
		}
	}
	// Select up to 2 phonemes for this session
	sessionPhonemes := curriculum.SelectPhonemesForSession(allPhonemes, weakPhonemeIDs, 2)
	phonemeIdx := 0

	// --- Phase 4: Curriculum DAG state ---
	var grammarExposures []*curriculum.KidGrammarExposure
	if curriculumRepo != nil {
		exposures, err := curriculumRepo.GetExposures(ctx, kidID)
		if err == nil {
			grammarExposures = exposures
		}
	}
	nextGrammarStructure := curriculum.GetNextGrammarStructure(allGrammarStructures, grammarExposures)

	// Track skill counts for auto-balancing
	skillCounts := map[string]int{
		"listening": 0,
		"speaking":  0,
		"reading":   0,
		"writing":   0,
	}

	// Track last format to avoid consecutive repeats
	lastFormat := ""
	sortOrder := 0

	for _, slot := range plan.Activities {
		// --- Phase 3: Phonics slots ---
		if slot.Source == "phoneme_weak" {
			for i := 0; i < slot.Count; i++ {
				if phonemeIdx >= len(sessionPhonemes) {
					decisionLog = append(decisionLog, fmt.Sprintf("[%s] no phonemes available, skipping phonics slot", slot.Phase))
					break
				}
				phoneme := sessionPhonemes[phonemeIdx]
				phonemeIdx++

				var cfg map[string]interface{}
				if slot.Format == "phonics_match" {
					cfg = BuildPhonicsMatchConfig(phoneme, allPhonemes)
				} else {
					cfg = BuildPhonicsListenConfig(phoneme)
				}
				if cfg == nil {
					decisionLog = append(decisionLog, fmt.Sprintf("[%s] phoneme /%s/ has no usable minimal pairs, skipping", slot.Phase, phoneme.Symbol))
					continue
				}
				cfg["phase"] = slot.Phase
				cfg["target_skill"] = slot.Skill
				cfg["type"] = slot.Format

				cfgJSON, _ := json.Marshal(cfg)
				act := Activity{
					ID:           uuid.New(),
					Phase:        slot.Phase,
					ActivityType: slot.Format,
					Config:       cfgJSON,
					SortOrder:    sortOrder,
				}
				activities = append(activities, act)
				decisionLog = append(decisionLog, fmt.Sprintf("[%s] %s: phoneme /%s/ (%s)", slot.Phase, slot.Format, phoneme.Symbol, phoneme.ID))
				sortOrder++
			}
			continue
		}

		// --- Phase 4: Grammar DAG slot ---
		if slot.Source == "grammar_next" {
			for i := 0; i < slot.Count; i++ {
				if nextGrammarStructure == nil {
					decisionLog = append(decisionLog, fmt.Sprintf("[%s] no grammar structure available, skipping grammar slot", slot.Phase))
					break
				}

				act, reason := buildPatternIntroActivity(nextGrammarStructure, patterns, vocabByWord, allVocab, sortOrder)
				activities = append(activities, act)
				decisionLog = append(decisionLog, fmt.Sprintf("[%s] pattern_intro: %s", slot.Phase, reason))
				sortOrder++

				// Record this exposure asynchronously — non-fatal if it fails
				if curriculumRepo != nil {
					curriculum.RecordGrammarExposure(ctx, curriculumRepo, kidID, nextGrammarStructure.ID)
				}
			}
			continue
		}

		// --- Standard vocabulary slots ---
		// 1. Select source words
		sourceWords := selectSourceWords(slot.Source, unitWords, allVocab, vocabByWord, dueCards, dueVocabIDs, weakWords, masteryByVocabID)

		if len(sourceWords) == 0 {
			sourceWords = unitWords // fallback
			decisionLog = append(decisionLog, fmt.Sprintf("[%s] source '%s' returned 0 words, falling back to unit_vocab", slot.Phase, slot.Source))
		}

		// 2. Select skill
		skill := resolveSkill(slot.Skill, skillSummary, skillCounts)
		skillCounts[skill]++

		// 3. Select format
		format := resolveFormat(slot.Format, skill, lastFormat)

		// 4. Generate activity config and build activities
		for i := 0; i < slot.Count; i++ {
			act, reason := buildDynamicActivity(
				slot.Phase, format, skill, sourceWords, allVocab, vocabByWord,
				patterns, masteryByVocabID, dueVocabIDs, sortOrder,
			)
			activities = append(activities, act)
			decisionLog = append(decisionLog, fmt.Sprintf("[%s] %s: %s", slot.Phase, format, reason))
			sortOrder++
			lastFormat = format
		}
	}

	decisionLog = append(decisionLog, fmt.Sprintf("[engine] Generated %d activities for unit %d (%s)", len(activities), unitNumber, unitTheme))

	return activities, decisionLog, nil
}

// selectSourceWords picks words based on the source type.
func selectSourceWords(
	source string,
	unitWords []*content.Vocabulary,
	allVocab []*content.Vocabulary,
	vocabByWord map[string]*content.Vocabulary,
	dueCards []*srs.SrsCard,
	dueVocabIDs map[uuid.UUID]bool,
	weakWords []*srs.WordSkillMastery,
	masteryByVocabID map[uuid.UUID]*srs.WordSkillMastery,
) []*content.Vocabulary {
	switch source {
	case "srs_due":
		var words []*content.Vocabulary
		for _, card := range dueCards {
			for _, v := range allVocab {
				if v.ID == card.VocabularyID {
					words = append(words, v)
					break
				}
			}
		}
		return words

	case "unit_vocab":
		// Filter out words already at 80%+ mastery
		var words []*content.Vocabulary
		for _, v := range unitWords {
			m, hasMastery := masteryByVocabID[v.ID]
			if !hasMastery || m.OverallMastery < 80 {
				words = append(words, v)
			}
		}
		if len(words) == 0 {
			return unitWords // all mastered, still show them
		}
		return words

	case "mix":
		seen := make(map[uuid.UUID]bool)
		var words []*content.Vocabulary
		// SRS due first
		for _, card := range dueCards {
			for _, v := range allVocab {
				if v.ID == card.VocabularyID && !seen[v.ID] {
					words = append(words, v)
					seen[v.ID] = true
					break
				}
			}
		}
		// Then unit vocab
		for _, v := range unitWords {
			if !seen[v.ID] {
				words = append(words, v)
				seen[v.ID] = true
			}
		}
		return words

	case "error_focus":
		// Pick words with lowest mastery scores
		var words []*content.Vocabulary
		for _, ww := range weakWords {
			for _, v := range allVocab {
				if v.ID == ww.VocabularyID {
					words = append(words, v)
					break
				}
			}
		}
		return words

	case "all_learned":
		// All words with any mastery > 0
		var words []*content.Vocabulary
		for _, ww := range weakWords {
			if ww.OverallMastery > 0 {
				for _, v := range allVocab {
					if v.ID == ww.VocabularyID {
						words = append(words, v)
						break
					}
				}
			}
		}
		return words

	default:
		return unitWords
	}
}

// canonicalSkillOrder is the fixed iteration order used to break ties in
// resolveSkill. Without it, Go map iteration randomization would make a fresh
// kid see a different "weakest" skill across consecutive sessions.
var canonicalSkillOrder = []srs.SkillType{
	srs.SkillListening,
	srs.SkillSpeaking,
	srs.SkillReading,
	srs.SkillWriting,
}

// resolveSkill determines which skill to target.
func resolveSkill(skillSpec string, skillSummary map[srs.SkillType]float64, skillCounts map[string]int) string {
	switch skillSpec {
	case "weakest":
		weakest := string(srs.SkillListening)
		weakestScore := 101.0
		for _, skill := range canonicalSkillOrder {
			score := skillSummary[skill]
			if score < weakestScore {
				weakestScore = score
				weakest = string(skill)
			}
		}
		return weakest

	case "auto":
		// Pick the skill with fewest activities so far, breaking ties in canonical order.
		minCount := 999
		minSkill := string(srs.SkillListening)
		for _, skill := range canonicalSkillOrder {
			count := skillCounts[string(skill)]
			if count < minCount {
				minCount = count
				minSkill = string(skill)
			}
		}
		return minSkill

	case "listening", "speaking", "reading", "writing":
		return skillSpec

	default:
		return "listening"
	}
}

// resolveFormat picks the activity format, avoiding consecutive repeats.
func resolveFormat(formatSpec, skill, lastFormat string) string {
	if formatSpec != "auto" {
		return formatSpec
	}

	// Pick best format for the skill
	candidates := formatsForSkill(skill)
	if len(candidates) == 0 {
		return "listen_and_choose"
	}

	// Avoid repeating the last format
	for _, c := range candidates {
		if c != lastFormat {
			return c
		}
	}
	return candidates[0]
}

func formatsForSkill(skill string) []string {
	switch skill {
	case "listening":
		return []string{"listen_and_choose", "flashcard_intro"}
	case "speaking":
		return []string{"speak_word", "listen_and_repeat"}
	case "reading":
		return []string{"fill_blank", "word_match"}
	case "writing":
		return []string{"build_sentence"}
	default:
		return []string{"listen_and_choose"}
	}
}

// buildDynamicActivity creates one Activity with real content config.
func buildDynamicActivity(
	phase, format, skill string,
	sourceWords []*content.Vocabulary,
	allVocab []*content.Vocabulary,
	vocabByWord map[string]*content.Vocabulary,
	patterns []*content.Pattern,
	masteryByVocabID map[uuid.UUID]*srs.WordSkillMastery,
	dueVocabIDs map[uuid.UUID]bool,
	sortOrder int,
) (Activity, string) {
	// Shuffle source words for variety
	shuffled := make([]*content.Vocabulary, len(sourceWords))
	copy(shuffled, sourceWords)
	rand.Shuffle(len(shuffled), func(i, j int) { shuffled[i], shuffled[j] = shuffled[j], shuffled[i] })

	var config map[string]interface{}
	var reason string
	var vocabIDs []uuid.UUID

	switch format {
	case "flashcard_intro":
		config, reason, vocabIDs = buildFlashcardIntroConfig(shuffled, masteryByVocabID)

	case "listen_and_choose":
		config, reason, vocabIDs = buildListenAndChooseConfig(shuffled, allVocab, masteryByVocabID, dueVocabIDs)

	case "listen_and_repeat", "speak_word":
		config, reason, vocabIDs = buildSpeakConfig(format, shuffled, masteryByVocabID, dueVocabIDs)

	case "word_match":
		config, reason, vocabIDs = buildWordMatchConfig(shuffled)

	case "fill_blank":
		config, reason, vocabIDs = buildFillBlankConfig(shuffled, allVocab, patterns, vocabByWord)

	case "build_sentence":
		config, reason, vocabIDs = buildBuildSentenceConfig(shuffled, patterns, vocabByWord)

	default:
		config = map[string]interface{}{"type": format}
		reason = fmt.Sprintf("unknown format '%s'", format)
	}

	config["phase"] = phase
	config["target_skill"] = skill

	configJSON, _ := json.Marshal(config)

	return Activity{
		ID:            uuid.New(),
		Phase:         phase,
		ActivityType:  format,
		Config:        configJSON,
		VocabularyIDs: vocabIDs,
		SortOrder:     sortOrder,
	}, reason
}

// --- Config builders for each format ---

func buildFlashcardIntroConfig(words []*content.Vocabulary, masteryByVocabID map[uuid.UUID]*srs.WordSkillMastery) (map[string]interface{}, string, []uuid.UUID) {
	count := 5
	if len(words) < count {
		count = len(words)
	}
	if count == 0 {
		return map[string]interface{}{"type": "flashcard_intro", "words": []interface{}{}}, "no words available", nil
	}

	selected := words[:count]
	var wordList []map[string]interface{}
	var vocabIDs []uuid.UUID
	newCount := 0
	belowCount := 0

	for _, v := range selected {
		wordList = append(wordList, map[string]interface{}{
			"word":           v.Word,
			"emoji":          v.Emoji,
			"translation_vi": v.TranslationVI,
			"phonetic_ipa":   v.PhoneticIPA,
			"image_url":      v.ImageURL,
			"audio_url":      v.AudioURL,
		})
		vocabIDs = append(vocabIDs, v.ID)
		if m, ok := masteryByVocabID[v.ID]; ok {
			if m.OverallMastery < 50 {
				belowCount++
			}
		} else {
			newCount++
		}
	}

	config := map[string]interface{}{
		"type":  "flashcard_intro",
		"words": wordList,
	}

	reason := fmt.Sprintf("%d words — %d new, %d below 50%%", count, newCount, belowCount)
	return config, reason, vocabIDs
}

func buildListenAndChooseConfig(words []*content.Vocabulary, allVocab []*content.Vocabulary, masteryByVocabID map[uuid.UUID]*srs.WordSkillMastery, dueVocabIDs map[uuid.UUID]bool) (map[string]interface{}, string, []uuid.UUID) {
	if len(words) == 0 {
		return map[string]interface{}{"type": "listen_and_choose"}, "no words available", nil
	}

	target := words[0]

	// Distractors come from the word's own DB-backed `distractors` column
	// first. Any shortfall is padded from same-category vocabulary. This
	// replaces the old hardcoded similarSoundingDistractors map.
	distractors := make([]string, 0, 3)
	for _, d := range target.Distractors {
		if d == "" || strings.EqualFold(d, target.Word) {
			continue
		}
		distractors = append(distractors, d)
		if len(distractors) >= 3 {
			break
		}
	}
	if len(distractors) < 3 {
		padding := GenerateDistractorsFromCategory(target, allVocab, 3-len(distractors))
		distractors = append(distractors, padding...)
	}

	// Build options (target + distractors, shuffled)
	options := []map[string]interface{}{
		{"text": target.Word, "translation_vi": target.TranslationVI, "emoji": target.Emoji, "is_correct": true},
	}
	for _, d := range distractors {
		dv, ok := findVocabByWord(allVocab, d)
		opt := map[string]interface{}{"text": d, "is_correct": false}
		if ok {
			opt["translation_vi"] = dv.TranslationVI
			opt["emoji"] = dv.Emoji
		}
		options = append(options, opt)
	}
	rand.Shuffle(len(options), func(i, j int) { options[i], options[j] = options[j], options[i] })

	config := map[string]interface{}{
		"type":           "listen_and_choose",
		"target_word":    target.Word,
		"target_vi":      target.TranslationVI,
		"target_emoji":   target.Emoji,
		"word":           target.Word,
		"translation_vi": target.TranslationVI,
		"phonetic_ipa":   target.PhoneticIPA,
		"image_url":      target.ImageURL,
		"audio_url":      target.AudioURL,
		"options":        options,
		"distractors":    distractors,
	}

	// Build reason
	reasonParts := fmt.Sprintf("target='%s'", target.Word)
	if dueVocabIDs[target.ID] {
		reasonParts += " — SRS due"
	}
	if m, ok := masteryByVocabID[target.ID]; ok {
		reasonParts += fmt.Sprintf(" (listening=%.0f%%)", m.ListeningScore)
	}

	return config, reasonParts, []uuid.UUID{target.ID}
}

func buildSpeakConfig(format string, words []*content.Vocabulary, masteryByVocabID map[uuid.UUID]*srs.WordSkillMastery, dueVocabIDs map[uuid.UUID]bool) (map[string]interface{}, string, []uuid.UUID) {
	if len(words) == 0 {
		return map[string]interface{}{"type": format}, "no words available", nil
	}

	target := words[0]

	config := map[string]interface{}{
		"type":           format,
		"target_word":    target.Word,
		"target_vi":      target.TranslationVI,
		"target_emoji":   target.Emoji,
		"word":           target.Word,
		"translation_vi": target.TranslationVI,
		"phonetic_ipa":   target.PhoneticIPA,
		"image_url":      target.ImageURL,
		"audio_url":      target.AudioURL,
	}

	reason := fmt.Sprintf("target='%s'", target.Word)
	if dueVocabIDs[target.ID] {
		reason += " — SRS due"
	}
	if m, ok := masteryByVocabID[target.ID]; ok {
		reason += fmt.Sprintf(" (speaking=%.0f%%)", m.SpeakingScore)
	}

	return config, reason, []uuid.UUID{target.ID}
}

func buildWordMatchConfig(words []*content.Vocabulary) (map[string]interface{}, string, []uuid.UUID) {
	count := 4
	if len(words) < count {
		count = len(words)
	}
	if count == 0 {
		return map[string]interface{}{"type": "word_match", "pairs": []interface{}{}}, "no words available", nil
	}

	selected := words[:count]
	var pairs []map[string]interface{}
	var vocabIDs []uuid.UUID

	for _, v := range selected {
		pairs = append(pairs, map[string]interface{}{
			"english":    v.Word,
			"vietnamese": v.TranslationVI,
			"emoji":      v.Emoji,
		})
		vocabIDs = append(vocabIDs, v.ID)
	}

	// Build options for the activity (both english and vietnamese lists, shuffled separately)
	englishOptions := make([]map[string]interface{}, len(selected))
	vietnameseOptions := make([]map[string]interface{}, len(selected))
	for i, v := range selected {
		eid := fmt.Sprintf("en_%d", i)
		vid := fmt.Sprintf("vi_%d", i)
		englishOptions[i] = map[string]interface{}{
			"id":       eid,
			"text":     v.Word,
			"match_id": vid,
		}
		vietnameseOptions[i] = map[string]interface{}{
			"id":       vid,
			"text":     v.TranslationVI,
			"match_id": eid,
		}
	}
	rand.Shuffle(len(vietnameseOptions), func(i, j int) { vietnameseOptions[i], vietnameseOptions[j] = vietnameseOptions[j], vietnameseOptions[i] })

	// Build flat options list for the existing Flutter widget
	var flatOptions []map[string]interface{}
	for i, v := range selected {
		flatOptions = append(flatOptions, map[string]interface{}{
			"id":        fmt.Sprintf("en_%d", i),
			"text":      v.Word,
			"isCorrect": true,
		})
		flatOptions = append(flatOptions, map[string]interface{}{
			"id":        fmt.Sprintf("vi_%d", i),
			"text":      v.TranslationVI,
			"isCorrect": true,
		})
	}

	config := map[string]interface{}{
		"type":    "word_match",
		"pairs":   pairs,
		"options": flatOptions,
	}

	wordNames := make([]string, len(selected))
	for i, v := range selected {
		wordNames[i] = v.Word
	}
	reason := fmt.Sprintf("%d pairs: %s", count, strings.Join(wordNames, ", "))

	return config, reason, vocabIDs
}

func buildFillBlankConfig(words []*content.Vocabulary, allVocab []*content.Vocabulary, patterns []*content.Pattern, vocabByWord map[string]*content.Vocabulary) (map[string]interface{}, string, []uuid.UUID) {
	// Try to use a pattern to generate a sentence
	if len(patterns) > 0 {
		// Pick a random pattern
		pattern := patterns[rand.Intn(len(patterns))]
		sentence, sentenceVI, err := GenerateSentenceFromExample(pattern)
		if err == nil && sentence != "" {
			// Find a content word to blank out
			blankWord, displaySentence, correctWord := pickBlankWord(sentence, words)
			if blankWord != "" {
				// Distractors: same category from DB vocabulary. If the
				// blanked word isn't a known vocab item, pick any 3 vocab
				// words from allVocab as filler — better than a hardcoded
				// list that doesn't reflect the kid's word pool.
				options := []string{correctWord}
				if correctVocab, ok := vocabByWord[strings.ToLower(correctWord)]; ok {
					distractors := GenerateDistractorsFromCategory(correctVocab, allVocab, 3)
					options = append(options, distractors...)
				} else {
					for _, v := range allVocab {
						if len(options) >= 4 {
							break
						}
						if !strings.EqualFold(v.Word, correctWord) {
							options = append(options, v.Word)
						}
					}
				}
				rand.Shuffle(len(options), func(i, j int) { options[i], options[j] = options[j], options[i] })

				config := map[string]interface{}{
					"type":             "fill_blank",
					"sentence":         sentence,
					"sentence_vi":      sentenceVI,
					"display_sentence": displaySentence,
					"correct_word":     correctWord,
					"options":          options,
					"pattern_id":       pattern.ID,
				}

				reason := fmt.Sprintf("'%s' — blank='%s', pattern %s", sentence, correctWord, pattern.ID)
				var vocabIDs []uuid.UUID
				if v, ok := vocabByWord[strings.ToLower(correctWord)]; ok {
					vocabIDs = []uuid.UUID{v.ID}
				}
				return config, reason, vocabIDs
			}
		}
	}

	// Word-level fallback: use the vocab row's example_sentence. We will not
	// synthesise "I like X." — applying that template to verbs/adverbs/function
	// words produces ungrammatical output the kid would memorise as wrong.
	for _, target := range words {
		if target.ExampleSentence == "" {
			continue
		}
		sentence := target.ExampleSentence
		sentenceVI := target.ExampleSentenceVI

		displaySentence := strings.Replace(sentence, target.Word, "___", 1)
		options := []string{target.Word}
		distractors := GenerateDistractorsFromCategory(target, allVocab, 3)
		options = append(options, distractors...)
		rand.Shuffle(len(options), func(i, j int) { options[i], options[j] = options[j], options[i] })

		config := map[string]interface{}{
			"type":             "fill_blank",
			"sentence":         sentence,
			"sentence_vi":      sentenceVI,
			"display_sentence": displaySentence,
			"correct_word":     target.Word,
			"options":          options,
		}

		reason := fmt.Sprintf("'%s' — blank='%s' (from vocab example_sentence)", sentence, target.Word)
		return config, reason, []uuid.UUID{target.ID}
	}

	return map[string]interface{}{"type": "fill_blank"}, "no content available", nil
}

func buildBuildSentenceConfig(words []*content.Vocabulary, patterns []*content.Pattern, vocabByWord map[string]*content.Vocabulary) (map[string]interface{}, string, []uuid.UUID) {
	// Try to use a pattern
	if len(patterns) > 0 {
		pattern := patterns[rand.Intn(len(patterns))]
		sentence, sentenceVI, err := GenerateSentenceFromExample(pattern)
		if err == nil && sentence != "" {
			shuffled, correct := ScrambleWords(sentence)

			config := map[string]interface{}{
				"type":            "build_sentence",
				"sentence":        sentence,
				"sentence_vi":     sentenceVI,
				"scrambled_words": shuffled,
				"correct_order":   correct,
				"pattern_id":      pattern.ID,
			}

			// Collect vocab IDs from the sentence
			var vocabIDs []uuid.UUID
			for _, word := range correct {
				if v, ok := vocabByWord[strings.ToLower(word)]; ok {
					vocabIDs = append(vocabIDs, v.ID)
				}
			}

			reason := fmt.Sprintf("'%s' — pattern %s, Writing skill target", sentence, pattern.ID)
			return config, reason, vocabIDs
		}
	}

	// Word-level fallback: only use a vocab row that has a real example
	// sentence. No "I like X" synthesis — see the rationale in buildFillBlankConfig.
	for _, target := range words {
		if target.ExampleSentence == "" {
			continue
		}
		sentence := target.ExampleSentence
		sentenceVI := target.ExampleSentenceVI

		shuffled, correct := ScrambleWords(sentence)

		config := map[string]interface{}{
			"type":            "build_sentence",
			"sentence":        sentence,
			"sentence_vi":     sentenceVI,
			"scrambled_words": shuffled,
			"correct_order":   correct,
		}

		reason := fmt.Sprintf("'%s' — from vocab example_sentence '%s'", sentence, target.Word)
		return config, reason, []uuid.UUID{target.ID}
	}

	return map[string]interface{}{"type": "build_sentence"}, "no content available", nil
}

// --- Helpers ---

func pickBlankWord(sentence string, words []*content.Vocabulary) (blankWord, displaySentence, correctWord string) {
	sentWords := strings.Fields(strings.TrimRight(sentence, ".!?"))
	skip := map[string]bool{"I": true, "a": true, "the": true, "is": true, "am": true, "are": true, "to": true, "in": true, "do": true, "you": true, "my": true}

	// Prefer words that are in the vocabulary pool
	wordSet := make(map[string]bool)
	for _, v := range words {
		wordSet[strings.ToLower(v.Word)] = true
	}

	for _, w := range sentWords {
		if wordSet[strings.ToLower(w)] && !skip[w] {
			display := strings.Replace(sentence, w, "___", 1)
			return w, display, w
		}
	}

	// Fallback: pick any content word
	for _, w := range sentWords {
		if !skip[w] {
			display := strings.Replace(sentence, w, "___", 1)
			return w, display, w
		}
	}

	return "", "", ""
}

// buildPatternIntroActivity creates a pattern_intro activity for a grammar structure.
// It picks the easiest pattern for that structure, shows the template + examples + L1 error tips.
func buildPatternIntroActivity(
	gs *content.GrammarStructure,
	allPatterns []*content.Pattern,
	vocabByWord map[string]*content.Vocabulary,
	allVocab []*content.Vocabulary,
	sortOrder int,
) (Activity, string) {
	// Find patterns for this grammar structure (ordered by difficulty asc)
	var structurePatterns []*content.Pattern
	for _, p := range allPatterns {
		if p.GrammarStructureID == gs.ID {
			structurePatterns = append(structurePatterns, p)
		}
	}

	// Build example sentences — use pattern examples or generate from vocab
	var examples []map[string]interface{}
	if len(structurePatterns) > 0 {
		// Pick up to 3 examples from the easiest pattern
		pattern := structurePatterns[0]
		patternExamples := pattern.GetExamples()
		max := 3
		if len(patternExamples) < max {
			max = len(patternExamples)
		}
		for _, ex := range patternExamples[:max] {
			examples = append(examples, map[string]interface{}{
				"en": ex.En,
				"vi": ex.Vi,
			})
		}
		// If no examples in pattern, try generating one
		if len(examples) == 0 {
			if sentence, sentVI, err := GenerateSentenceFromExample(pattern); err == nil && sentence != "" {
				examples = append(examples, map[string]interface{}{"en": sentence, "vi": sentVI})
			}
		}
	}

	// Parse L1 errors for the tip
	type l1Error struct {
		Error          string `json:"error"`
		ExampleWrong   string `json:"example_wrong"`
		ExampleCorrect string `json:"example_correct"`
		ReasonVI       string `json:"reason_vi"`
	}
	var l1Errors []l1Error
	json.Unmarshal(gs.CommonL1Errors, &l1Errors)

	var l1Tip map[string]interface{}
	if len(l1Errors) > 0 {
		e := l1Errors[0]
		l1Tip = map[string]interface{}{
			"error":           e.Error,
			"example_wrong":   e.ExampleWrong,
			"example_correct": e.ExampleCorrect,
			"reason_vi":       e.ReasonVI,
		}
	}

	cfg := map[string]interface{}{
		"type":                "pattern_intro",
		"grammar_structure_id": gs.ID,
		"grammar_name":        gs.Name,
		"description_vi":      gs.DescriptionVI,
		"template":            gs.Template,
		"cefr_level":          gs.CEFRLevel,
		"examples":            examples,
	}
	if l1Tip != nil {
		cfg["l1_tip"] = l1Tip
	}

	cfgJSON, _ := json.Marshal(cfg)

	reason := fmt.Sprintf("grammar '%s' (%s) — %d examples, prerequisites: %v",
		gs.Name, gs.CEFRLevel, len(examples), gs.PrerequisiteIDs)

	return Activity{
		ID:           uuid.New(),
		Phase:        "grammar",
		ActivityType: "pattern_intro",
		Config:       cfgJSON,
		SortOrder:    sortOrder,
	}, reason
}

func findVocabByWord(allVocab []*content.Vocabulary, word string) (*content.Vocabulary, bool) {
	for _, v := range allVocab {
		if strings.EqualFold(v.Word, word) {
			return v, true
		}
	}
	return nil, false
}
