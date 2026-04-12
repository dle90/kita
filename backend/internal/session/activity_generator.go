package session

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/content"
	"github.com/kitaenglish/backend/internal/srs"
)

// ActivityTypeToSkill maps an activity type string to the language skill it exercises.
func ActivityTypeToSkill(activityType string) srs.SkillType {
	switch activityType {
	case "listen_and_choose", "listen_and_repeat", "flashcard_intro":
		return srs.SkillListening
	case "speak_word", "speak_sentence":
		return srs.SkillSpeaking
	case "read_word", "read_sentence", "word_match", "pattern_intro":
		return srs.SkillReading
	case "spell_word", "build_sentence", "fill_blank", "grammar_drill":
		return srs.SkillWriting
	// Phonics activities don't map to word-level skill mastery — they update phoneme mastery separately.
	case "phonics_listen", "phonics_match":
		return srs.SkillListening
	default:
		return srs.SkillListening
	}
}

// IsPhonicsActivity returns true for activity types that target phoneme mastery.
func IsPhonicsActivity(activityType string) bool {
	return activityType == "phonics_listen" || activityType == "phonics_match"
}

// IsPerceptionPhonics returns true for phonics_listen (perception/discrimination).
func IsPerceptionPhonics(activityType string) bool {
	return activityType == "phonics_listen"
}

// VocabData holds the minimal vocabulary info embedded into activity configs.
type VocabData struct {
	ID            uuid.UUID `json:"id"`
	Word          string    `json:"word"`
	TranslationVI string   `json:"translation_vi"`
	PhoneticIPA   string    `json:"phonetic_ipa,omitempty"`
	ImageURL      string    `json:"image_url,omitempty"`
	AudioURL      string    `json:"audio_url,omitempty"`
}

// vocabDataFromModel converts a content.Vocabulary to the lightweight VocabData.
func vocabDataFromModel(v *content.Vocabulary) VocabData {
	return VocabData{
		ID:            v.ID,
		Word:          v.Word,
		TranslationVI: v.TranslationVI,
		PhoneticIPA:   v.PhoneticIPA,
		ImageURL:      v.ImageURL,
		AudioURL:      v.AudioURL,
	}
}

// similarSoundingDistractors provides hard-coded groups of similar-sounding English
// words suitable for listen_and_choose activities aimed at Vietnamese kids.
var similarSoundingDistractors = map[string][]string{
	"cat":    {"cap", "cut", "car", "can"},
	"dog":    {"dock", "dot", "dug", "log"},
	"red":    {"led", "bed", "rid", "read"},
	"blue":   {"blew", "glue", "clue", "brew"},
	"fish":   {"dish", "wish", "fist", "fit"},
	"bird":   {"word", "burn", "burst", "bored"},
	"tree":   {"three", "free", "tea", "tray"},
	"book":   {"look", "cook", "hook", "boot"},
	"hand":   {"band", "sand", "had", "hang"},
	"ball":   {"wall", "tall", "bell", "bull"},
	"house":  {"mouse", "horse", "hose", "how"},
	"water":  {"winter", "weather", "wander", "waiter"},
	"apple":  {"able", "ankle", "ample", "maple"},
	"happy":  {"hippy", "handy", "hobby", "hungry"},
	"school": {"cool", "stool", "skull", "scoop"},
}

// getDistractors returns distractor words for a given target word.
// Returns up to maxCount distractors from the similar-sounding map,
// padding with generic common words if needed.
func getDistractors(word string, maxCount int) []string {
	generic := []string{"yes", "no", "big", "small", "run", "go", "stop", "up", "down", "sit"}
	distractors, ok := similarSoundingDistractors[word]
	if !ok {
		distractors = generic
	}
	if len(distractors) > maxCount {
		return distractors[:maxCount]
	}
	return distractors
}

// GenerateSessionActivities builds the list of activities for a session day,
// incorporating SRS due cards as review activities and adjusting difficulty.
// vocabByID is an optional map of vocabulary data for enriching activity configs.
func GenerateSessionActivities(
	dayNumber int,
	templates []*content.SessionTemplate,
	dueCards []*srs.SrsCard,
	recentAccuracy float64,
	vocabByID map[uuid.UUID]*content.Vocabulary,
) []Activity {
	var activities []Activity

	// Determine difficulty direction based on recent accuracy
	difficultyOffset := 0
	if recentAccuracy > 85 {
		difficultyOffset = 1 // boost
	} else if recentAccuracy < 60 && recentAccuracy > 0 {
		difficultyOffset = -1 // ease
	}

	// Inject SRS due cards as individual listen_and_choose review activities
	if len(dueCards) > 0 {
		reviewCount := len(dueCards)
		if reviewCount > 5 {
			reviewCount = 5
		}

		for i := 0; i < reviewCount; i++ {
			card := dueCards[i]
			reviewConfig := buildReviewConfig(card, difficultyOffset, vocabByID)
			configJSON, _ := json.Marshal(reviewConfig)

			activities = append(activities, Activity{
				ID:            uuid.New(),
				Phase:         "warmup",
				ActivityType:  "listen_and_choose",
				Config:        configJSON,
				VocabularyIDs: []uuid.UUID{card.VocabularyID},
				SortOrder:     i,
			})
		}
	}

	// Collect all vocab into a flat pool for sentence generation
	var vocabPool []*content.Vocabulary
	for _, v := range vocabByID {
		vocabPool = append(vocabPool, v)
	}

	// Generate activities from templates
	for _, tmpl := range templates {
		config := tmpl.Config

		// Adjust config based on difficulty offset
		if difficultyOffset != 0 {
			config = adjustDifficulty(config, difficultyOffset)
		}

		// For build_sentence and fill_blank, generate sentence-based configs
		if tmpl.ActivityType == "build_sentence" || tmpl.ActivityType == "fill_blank" {
			config = enrichSentenceActivity(config, tmpl.ActivityType, vocabPool)
		}

		// Enrich template config with vocabulary data if available
		config = enrichConfigWithVocab(config, tmpl.VocabularyIDs, vocabByID)

		sortOrder := tmpl.SortOrder
		if len(dueCards) > 0 && tmpl.Phase == "warmup" {
			reviewCount := len(dueCards)
			if reviewCount > 5 {
				reviewCount = 5
			}
			sortOrder += reviewCount // shift to accommodate SRS review activities
		}

		activity := Activity{
			ID:            uuid.New(),
			Phase:         tmpl.Phase,
			ActivityType:  tmpl.ActivityType,
			Config:        config,
			VocabularyIDs: tmpl.VocabularyIDs,
			SentenceIDs:   tmpl.SentenceIDs,
			SortOrder:     sortOrder,
		}
		activities = append(activities, activity)
	}

	return activities
}

// buildReviewConfig creates the config for an SRS review listen_and_choose activity.
func buildReviewConfig(card *srs.SrsCard, difficultyOffset int, vocabByID map[uuid.UUID]*content.Vocabulary) map[string]interface{} {
	cfg := map[string]interface{}{
		"type":          "srs_review",
		"card_id":       card.ID.String(),
		"vocabulary_id": card.VocabularyID.String(),
	}

	// Set distractor count based on difficulty
	distractorCount := 3
	timeLimitMs := 15000

	if difficultyOffset > 0 {
		// Harder: more distractors, less time
		distractorCount = 5
		timeLimitMs = 10000
	} else if difficultyOffset < 0 {
		// Easier: fewer distractors, more time, add hint
		distractorCount = 2
		timeLimitMs = 20000
		cfg["show_hint"] = true
	}

	cfg["time_limit_ms"] = timeLimitMs

	// Embed vocabulary data if available
	if vocab, ok := vocabByID[card.VocabularyID]; ok {
		cfg["word"] = vocab.Word
		cfg["translation_vi"] = vocab.TranslationVI
		cfg["phonetic_ipa"] = vocab.PhoneticIPA
		cfg["image_url"] = vocab.ImageURL
		cfg["audio_url"] = vocab.AudioURL

		distractors := getDistractors(vocab.Word, distractorCount)
		cfg["distractors"] = distractors

		if difficultyOffset < 0 {
			cfg["hint_vi"] = vocab.TranslationVI
		}
	}

	return cfg
}

// adjustDifficulty modifies an activity config JSON based on the difficulty offset.
func adjustDifficulty(config json.RawMessage, difficultyOffset int) json.RawMessage {
	var cfgMap map[string]interface{}
	if err := json.Unmarshal(config, &cfgMap); err != nil {
		return config
	}

	if difficultyOffset > 0 {
		// Difficulty boost
		cfgMap["difficulty_boost"] = true

		// Add more options if options_count exists
		if optCount, ok := cfgMap["options_count"].(float64); ok {
			cfgMap["options_count"] = optCount + 2
		}

		// Reduce time limit if present
		if timeLimit, ok := cfgMap["time_limit_ms"].(float64); ok {
			reduced := timeLimit * 0.7
			if reduced < 5000 {
				reduced = 5000
			}
			cfgMap["time_limit_ms"] = reduced
		}
	} else {
		// Difficulty ease
		cfgMap["difficulty_ease"] = true

		// Fewer options if options_count exists
		if optCount, ok := cfgMap["options_count"].(float64); ok {
			eased := optCount - 1
			if eased < 2 {
				eased = 2
			}
			cfgMap["options_count"] = eased
		}

		// Increase time limit if present
		if timeLimit, ok := cfgMap["time_limit_ms"].(float64); ok {
			cfgMap["time_limit_ms"] = timeLimit * 1.5
		}

		// Add Vietnamese hint flag
		cfgMap["show_hint"] = true
	}

	adjusted, err := json.Marshal(cfgMap)
	if err != nil {
		return config
	}
	return adjusted
}

// enrichConfigWithVocab adds vocabulary data into an activity config when vocab IDs and data are available.
func enrichConfigWithVocab(config json.RawMessage, vocabIDs []uuid.UUID, vocabByID map[uuid.UUID]*content.Vocabulary) json.RawMessage {
	if len(vocabIDs) == 0 || len(vocabByID) == 0 {
		return config
	}

	var cfgMap map[string]interface{}
	if err := json.Unmarshal(config, &cfgMap); err != nil {
		return config
	}

	var vocabList []VocabData
	for _, vid := range vocabIDs {
		if v, ok := vocabByID[vid]; ok {
			vocabList = append(vocabList, vocabDataFromModel(v))
		}
	}

	if len(vocabList) > 0 {
		cfgMap["vocabulary"] = vocabList
	}

	enriched, err := json.Marshal(cfgMap)
	if err != nil {
		return config
	}
	return enriched
}

// enrichSentenceActivity builds the config for build_sentence or fill_blank activities.
// It reads "sentence" and "sentence_vi" from the template config,
// then produces scrambled tiles or blank/options as appropriate.
func enrichSentenceActivity(config json.RawMessage, activityType string, vocabPool []*content.Vocabulary) json.RawMessage {
	var cfgMap map[string]interface{}
	if err := json.Unmarshal(config, &cfgMap); err != nil {
		return config
	}

	sentence, _ := cfgMap["sentence"].(string)
	sentenceVI, _ := cfgMap["sentence_vi"].(string)

	if sentence == "" {
		return config
	}

	if activityType == "build_sentence" {
		shuffled, correct := ScrambleWords(sentence)
		cfgMap["scrambled_words"] = shuffled
		cfgMap["correct_order"] = correct
		cfgMap["sentence"] = sentence
		cfgMap["sentence_vi"] = sentenceVI
	} else if activityType == "fill_blank" {
		// Determine which word to blank out
		blankWord, _ := cfgMap["blank_word"].(string)
		if blankWord == "" {
			// Pick a content word from the sentence (skip small function words)
			words := strings.Fields(strings.TrimRight(sentence, ".!?"))
			skip := map[string]bool{"I": true, "a": true, "the": true, "is": true, "am": true, "are": true, "to": true, "in": true, "do": true, "you": true, "my": true}
			for _, w := range words {
				if !skip[w] {
					blankWord = w
					break
				}
			}
			if blankWord == "" && len(words) > 0 {
				blankWord = words[len(words)-1]
			}
		}

		// Build display sentence with blank
		displaySentence := strings.Replace(sentence, blankWord, "___", 1)
		cfgMap["display_sentence"] = displaySentence
		cfgMap["correct_word"] = blankWord
		cfgMap["sentence"] = sentence
		cfgMap["sentence_vi"] = sentenceVI

		// Generate distractors from same category
		var correctVocab *content.Vocabulary
		for _, v := range vocabPool {
			if strings.EqualFold(v.Word, blankWord) {
				correctVocab = v
				break
			}
		}

		options := []string{blankWord}
		if correctVocab != nil {
			distractors := GenerateDistractorsFromCategory(correctVocab, vocabPool, 3)
			options = append(options, distractors...)
		} else {
			// Fallback distractors
			fallback := []string{"happy", "sad", "big", "run", "eat", "go", "mom", "rice"}
			count := 0
			for _, f := range fallback {
				if f != blankWord && count < 3 {
					options = append(options, f)
					count++
				}
			}
		}
		cfgMap["options"] = options
	}

	enriched, err := json.Marshal(cfgMap)
	if err != nil {
		return config
	}
	return enriched
}

// GetVocabularyForActivity looks up vocabulary details from the content repository
// and returns them as a map keyed by ID for easy embedding into activity configs.
func GetVocabularyForActivity(ctx context.Context, contentRepo content.ContentRepository, vocabIDs []uuid.UUID) (map[uuid.UUID]*content.Vocabulary, error) {
	if len(vocabIDs) == 0 {
		return nil, nil
	}

	vocabs, err := contentRepo.GetVocabularyByIDs(ctx, vocabIDs)
	if err != nil {
		return nil, err
	}

	result := make(map[uuid.UUID]*content.Vocabulary, len(vocabs))
	for _, v := range vocabs {
		result[v.ID] = v
	}
	return result, nil
}

// BuildPhonicsListenConfig creates the config for a phonics_listen (minimal pair discrimination) activity.
func BuildPhonicsListenConfig(phoneme *content.Phoneme) map[string]interface{} {
	cfg := map[string]interface{}{
		"phoneme_id":        phoneme.ID,
		"symbol":            phoneme.Symbol,
		"mouth_position_vi": phoneme.MouthPositionVI,
		"substitution_vi":   phoneme.SubstitutionVI,
	}

	// Parse minimal pairs
	var pairs []map[string]interface{}
	if err := json.Unmarshal(phoneme.MinimalPairs, &pairs); err == nil && len(pairs) > 0 {
		// Pick first pair for the activity
		pair := pairs[0]
		cfg["word1"] = pair["word1"]
		cfg["word2"] = pair["word2"]
		cfg["word1_meaning"] = pair["word1_meaning"]
		cfg["word2_meaning"] = pair["word2_meaning"]
		cfg["are_different"] = true
	}

	return cfg
}

// BuildPhonicsMatchConfig creates the config for a phonics_match (sound-letter matching) activity.
func BuildPhonicsMatchConfig(phoneme *content.Phoneme, allPhonemes []*content.Phoneme) map[string]interface{} {
	// Pick a practice word
	targetWord := phoneme.ExampleWord
	if len(phoneme.PracticeWords) > 0 {
		targetWord = phoneme.PracticeWords[0]
	}

	// Build options: correct grapheme + distractors from other phonemes
	correctGrapheme := ""
	if len(phoneme.Graphemes) > 0 {
		correctGrapheme = phoneme.Graphemes[0]
	}

	options := []map[string]interface{}{
		{"grapheme": correctGrapheme, "correct": true},
	}

	// Add distractor graphemes from other phonemes
	used := map[string]bool{correctGrapheme: true}
	for _, other := range allPhonemes {
		if other.ID == phoneme.ID {
			continue
		}
		for _, g := range other.Graphemes {
			if !used[g] {
				options = append(options, map[string]interface{}{
					"grapheme": g,
					"correct":  false,
				})
				used[g] = true
				break
			}
		}
		if len(options) >= 4 {
			break
		}
	}

	cfg := map[string]interface{}{
		"phoneme_id":        phoneme.ID,
		"symbol":            phoneme.Symbol,
		"target_word":       targetWord,
		"correct_grapheme":  correctGrapheme,
		"options":           options,
		"mouth_position_vi": phoneme.MouthPositionVI,
		"substitution_vi":   phoneme.SubstitutionVI,
		"example_word":      phoneme.ExampleWord,
	}

	return cfg
}

// MapAttemptsToSM2Quality converts activity attempt count and correctness
// to an SM-2 quality score (0-5).
//
//	First attempt correct  -> 5
//	Second attempt correct -> 4
//	Third attempt correct  -> 3
//	Failed after 3+        -> 2
//	Skipped (0 attempts)   -> 1
func MapAttemptsToSM2Quality(attempts int, isCorrect bool) int {
	if attempts == 0 {
		return 1 // skipped
	}
	if isCorrect {
		switch {
		case attempts == 1:
			return 5
		case attempts == 2:
			return 4
		case attempts == 3:
			return 3
		default:
			return 3 // correct after many attempts still at least 3
		}
	}
	// Failed
	return 2
}
