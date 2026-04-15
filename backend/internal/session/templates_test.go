package session

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/content"
)

// templates_test.go exercises every activity template the dynamic generator
// can emit, with mock content. It then validates that the produced config map
// contains the exact keys the Flutter widgets read. Any mismatch is a bug.
//
// Run:  go test ./internal/session/ -run TestAllActivityTemplates -v

// --- Mock fixtures --------------------------------------------------------

func mockVocabulary() ([]*content.Vocabulary, map[string]*content.Vocabulary) {
	all := []*content.Vocabulary{
		{ID: uuid.New(), Word: "cat", TranslationVI: "con mèo", PhoneticIPA: "kæt", Emoji: "🐱", Category: "animal", DayNumber: 1, ExampleSentence: "I like cat.", ExampleSentenceVI: "Tôi thích con mèo."},
		{ID: uuid.New(), Word: "dog", TranslationVI: "con chó", PhoneticIPA: "dɔːg", Emoji: "🐶", Category: "animal", DayNumber: 1, ExampleSentence: "I like dog.", ExampleSentenceVI: "Tôi thích con chó."},
		{ID: uuid.New(), Word: "fish", TranslationVI: "con cá", PhoneticIPA: "fɪʃ", Emoji: "🐟", Category: "animal", DayNumber: 1},
		{ID: uuid.New(), Word: "bird", TranslationVI: "con chim", PhoneticIPA: "bɜːrd", Emoji: "🐦", Category: "animal", DayNumber: 1},
		{ID: uuid.New(), Word: "milk", TranslationVI: "sữa", PhoneticIPA: "mɪlk", Emoji: "🥛", Category: "food", DayNumber: 2},
		{ID: uuid.New(), Word: "rice", TranslationVI: "cơm", PhoneticIPA: "raɪs", Emoji: "🍚", Category: "food", DayNumber: 2},
		{ID: uuid.New(), Word: "happy", TranslationVI: "vui", PhoneticIPA: "ˈhæpi", Emoji: "😊", Category: "feeling", DayNumber: 3},
	}
	byWord := map[string]*content.Vocabulary{}
	for _, v := range all {
		byWord[strings.ToLower(v.Word)] = v
	}
	return all, byWord
}

func mockPatterns() []*content.Pattern {
	examples := json.RawMessage(`[{"en":"I like cat.","vi":"Tôi thích con mèo."},{"en":"I like dog.","vi":"Tôi thích con chó."}]`)
	slots := json.RawMessage(`[]`)
	return []*content.Pattern{
		{
			ID:                    "p_i_like",
			GrammarStructureID:    "gs_i_like",
			Template:              "I like {animal}.",
			TemplateVI:            "Tôi thích {animal}.",
			CommunicationFunction: "expressing_preference",
			Slots:                 slots,
			Difficulty:            1,
			DayIntroduced:         1,
			ExampleSentences:      examples,
		},
	}
}

func mockGrammarStructures() []*content.GrammarStructure {
	l1 := json.RawMessage(`[{"error":"missing article","example_wrong":"I like cat","example_correct":"I like the cat","reason_vi":"Cần thêm 'the'"}]`)
	return []*content.GrammarStructure{
		{
			ID:              "gs_i_like",
			Name:            "I like ___",
			DescriptionVI:   "Cấu trúc thể hiện sở thích",
			Template:        "I like ___.",
			CEFRLevel:       "pre_a1",
			Difficulty:      1,
			PrerequisiteIDs: []string{},
			CommonL1Errors:  l1,
		},
	}
}

func mockPhonemes() []*content.Phoneme {
	pairs := json.RawMessage(`[{"word1":"think","word2":"sink","word1_meaning":"nghĩ","word2_meaning":"chìm"}]`)
	return []*content.Phoneme{
		{
			ID:                 "th_voiceless",
			Symbol:             "θ",
			ExampleWord:        "think",
			Graphemes:          []string{"th"},
			IsNewForVietnamese: true,
			SubstitutionVI:     "Người Việt thường thay /θ/ bằng /t/",
			MouthPositionVI:    "Đặt lưỡi giữa hai răng",
			Difficulty:         5,
			MinimalPairs:       pairs,
			PracticeWords:      []string{"think", "thank", "three"},
		},
		{
			ID:                 "p_p",
			Symbol:             "p",
			ExampleWord:        "pen",
			Graphemes:          []string{"p"},
			IsNewForVietnamese: false,
			Difficulty:         1,
			MinimalPairs:       json.RawMessage(`[]`),
			PracticeWords:      []string{"pen", "pig"},
		},
	}
}

// --- Validators -----------------------------------------------------------

// requireKeys fails the test if any expected key is missing from cfg.
func requireKeys(t *testing.T, label string, cfg map[string]interface{}, keys ...string) {
	t.Helper()
	for _, k := range keys {
		if _, ok := cfg[k]; !ok {
			t.Errorf("[%s] missing required key %q", label, k)
		}
	}
}

// requireListOfStrings asserts cfg[key] is a []string-compatible slice.
// Flutter does `.cast<String>()` which crashes on non-string elements.
func requireListOfStrings(t *testing.T, label string, cfg map[string]interface{}, key string) {
	t.Helper()
	raw, ok := cfg[key]
	if !ok {
		t.Errorf("[%s] missing key %q (expected []string)", label, key)
		return
	}
	// After JSON round-trip Flutter sees List<dynamic>; we mirror that.
	slice, ok := raw.([]string)
	if ok {
		if len(slice) == 0 {
			t.Errorf("[%s] %q is empty []string", label, key)
		}
		return
	}
	// In some builders, options are []interface{} containing strings.
	if anySlice, ok := raw.([]interface{}); ok {
		if len(anySlice) == 0 {
			t.Errorf("[%s] %q is empty []interface{}", label, key)
			return
		}
		for i, item := range anySlice {
			if _, isStr := item.(string); !isStr {
				t.Errorf("[%s] %q[%d] is %T, not string — Flutter .cast<String>() will crash", label, key, i, item)
			}
		}
		return
	}
	t.Errorf("[%s] %q is %T, expected []string or []interface{}", label, key, raw)
}

// requireListOfMaps asserts cfg[key] is a slice of maps.
func requireListOfMaps(t *testing.T, label string, cfg map[string]interface{}, key string) {
	t.Helper()
	raw, ok := cfg[key]
	if !ok {
		t.Errorf("[%s] missing key %q (expected list of maps)", label, key)
		return
	}
	switch v := raw.(type) {
	case []map[string]interface{}:
		if len(v) == 0 {
			t.Errorf("[%s] %q is empty list", label, key)
		}
	case []interface{}:
		if len(v) == 0 {
			t.Errorf("[%s] %q is empty list", label, key)
			return
		}
		for i, item := range v {
			if _, ok := item.(map[string]interface{}); !ok {
				t.Errorf("[%s] %q[%d] is %T, not a map", label, key, i, item)
			}
		}
	default:
		t.Errorf("[%s] %q is %T, expected list of maps", label, key, raw)
	}
}

// roundTripJSON marshals + unmarshals the config to simulate what crosses the
// wire to Flutter. This catches non-JSON-serializable values and surfaces the
// same dynamic-typed map the Dart side will see.
func roundTripJSON(t *testing.T, label string, cfg map[string]interface{}) map[string]interface{} {
	t.Helper()
	raw, err := json.Marshal(cfg)
	if err != nil {
		t.Fatalf("[%s] json.Marshal failed: %v", label, err)
	}
	var out map[string]interface{}
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatalf("[%s] json.Unmarshal failed: %v", label, err)
	}
	return out
}

// --- Tests ----------------------------------------------------------------

func TestAllActivityTemplates(t *testing.T) {
	allVocab, vocabByWord := mockVocabulary()
	patterns := mockPatterns()
	grammarStructures := mockGrammarStructures()
	phonemes := mockPhonemes()

	t.Run("flashcard_intro", func(t *testing.T) {
		cfg, _, vocabIDs := buildFlashcardIntroConfig(allVocab, nil)
		cfg["type"] = "flashcard_intro"
		cfg = roundTripJSON(t, "flashcard_intro", cfg)
		requireKeys(t, "flashcard_intro", cfg, "type", "words")
		requireListOfMaps(t, "flashcard_intro", cfg, "words")
		// Each word should have all keys the text-mode Flutter view reads.
		words := cfg["words"].([]interface{})
		for i, w := range words {
			wm := w.(map[string]interface{})
			for _, k := range []string{"word", "emoji", "translation_vi", "phonetic_ipa", "image_url", "audio_url"} {
				if _, ok := wm[k]; !ok {
					t.Errorf("flashcard_intro words[%d] missing %q", i, k)
				}
			}
		}
		if len(vocabIDs) == 0 {
			t.Error("flashcard_intro returned no vocab IDs")
		}
	})

	t.Run("listen_and_choose", func(t *testing.T) {
		cfg, _, vocabIDs := buildListenAndChooseConfig(allVocab, allVocab, nil, nil)
		cfg["type"] = "listen_and_choose"
		cfg = roundTripJSON(t, "listen_and_choose", cfg)
		requireKeys(t, "listen_and_choose", cfg,
			"type", "target_word", "target_vi", "target_emoji",
			"word", "translation_vi", "options", "distractors")
		requireListOfMaps(t, "listen_and_choose", cfg, "options")
		// Verify exactly one option has correct=true. Option keys match
		// what the Flutter listen_and_choose widget expects: word/vi/
		// emoji/correct (see commit 822fdc8).
		opts := cfg["options"].([]interface{})
		correctCount := 0
		for _, o := range opts {
			om := o.(map[string]interface{})
			if c, ok := om["correct"].(bool); ok && c {
				correctCount++
			}
			if _, ok := om["word"]; !ok {
				t.Error("listen_and_choose option missing 'word'")
			}
		}
		if correctCount != 1 {
			t.Errorf("listen_and_choose: expected 1 correct option, got %d", correctCount)
		}
		if len(vocabIDs) != 1 {
			t.Errorf("listen_and_choose: expected 1 vocab ID, got %d", len(vocabIDs))
		}
	})

	t.Run("listen_and_repeat", func(t *testing.T) {
		cfg, _, _ := buildSpeakConfig("listen_and_repeat", allVocab, nil, nil)
		cfg = roundTripJSON(t, "listen_and_repeat", cfg)
		requireKeys(t, "listen_and_repeat", cfg,
			"type", "target_word", "target_vi", "target_emoji",
			"word", "translation_vi", "phonetic_ipa")
	})

	t.Run("speak_word", func(t *testing.T) {
		cfg, _, _ := buildSpeakConfig("speak_word", allVocab, nil, nil)
		cfg = roundTripJSON(t, "speak_word", cfg)
		requireKeys(t, "speak_word", cfg,
			"type", "target_word", "target_vi", "target_emoji",
			"word", "translation_vi", "phonetic_ipa")
	})

	t.Run("word_match", func(t *testing.T) {
		cfg, _, vocabIDs := buildWordMatchConfig(allVocab)
		cfg["type"] = "word_match"
		cfg = roundTripJSON(t, "word_match", cfg)
		requireKeys(t, "word_match", cfg, "type", "pairs", "options")
		requireListOfMaps(t, "word_match", cfg, "pairs")
		pairs := cfg["pairs"].([]interface{})
		for i, p := range pairs {
			pm := p.(map[string]interface{})
			for _, k := range []string{"english", "vietnamese", "emoji"} {
				if _, ok := pm[k]; !ok {
					t.Errorf("word_match pairs[%d] missing %q", i, k)
				}
			}
		}
		if len(vocabIDs) == 0 {
			t.Error("word_match returned no vocab IDs")
		}
	})

	t.Run("fill_blank", func(t *testing.T) {
		cfg, _, _ := buildFillBlankConfig(allVocab, allVocab, patterns, vocabByWord)
		cfg = roundTripJSON(t, "fill_blank", cfg)
		requireKeys(t, "fill_blank", cfg,
			"type", "sentence", "sentence_vi", "display_sentence",
			"correct_word", "options")
		requireListOfStrings(t, "fill_blank", cfg, "options")
		// display_sentence MUST contain the blank marker
		if ds, ok := cfg["display_sentence"].(string); ok {
			if !strings.Contains(ds, "___") {
				t.Errorf("fill_blank display_sentence has no blank marker: %q", ds)
			}
		}
		// correct_word MUST appear in options
		correct := cfg["correct_word"].(string)
		opts := cfg["options"].([]interface{})
		found := false
		for _, o := range opts {
			if s, ok := o.(string); ok && s == correct {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("fill_blank: correct_word %q not in options", correct)
		}
	})

	t.Run("build_sentence", func(t *testing.T) {
		cfg, _, _ := buildBuildSentenceConfig(allVocab, patterns, vocabByWord)
		cfg = roundTripJSON(t, "build_sentence", cfg)
		requireKeys(t, "build_sentence", cfg,
			"type", "sentence", "sentence_vi", "scrambled_words", "correct_order")
		requireListOfStrings(t, "build_sentence", cfg, "scrambled_words")
		requireListOfStrings(t, "build_sentence", cfg, "correct_order")
		// scrambled and correct must be the same length and contain the same words
		scrambled := cfg["scrambled_words"].([]interface{})
		correct := cfg["correct_order"].([]interface{})
		if len(scrambled) != len(correct) {
			t.Errorf("build_sentence: scrambled has %d words, correct has %d", len(scrambled), len(correct))
		}
	})

	t.Run("phonics_listen", func(t *testing.T) {
		cfg := BuildPhonicsListenConfig(phonemes[0])
		cfg["type"] = "phonics_listen"
		cfg = roundTripJSON(t, "phonics_listen", cfg)
		requireKeys(t, "phonics_listen", cfg,
			"type", "phoneme_id", "symbol", "word1", "word2",
			"word1_meaning", "word2_meaning", "are_different",
			"mouth_position_vi", "substitution_vi")
	})

	t.Run("phonics_listen_no_pairs", func(t *testing.T) {
		// Phoneme with empty minimal pairs — builder must return nil so the
		// caller skips the slot rather than ship an unanswerable activity.
		cfg := BuildPhonicsListenConfig(phonemes[1])
		if cfg != nil {
			t.Errorf("phonics_listen_no_pairs: expected nil config, got %v", cfg)
		}
	})

	t.Run("phonics_match", func(t *testing.T) {
		cfg := BuildPhonicsMatchConfig(phonemes[0], phonemes)
		cfg["type"] = "phonics_match"
		cfg = roundTripJSON(t, "phonics_match", cfg)
		requireKeys(t, "phonics_match", cfg,
			"type", "phoneme_id", "symbol", "target_word",
			"correct_grapheme", "options")
		requireListOfMaps(t, "phonics_match", cfg, "options")
		// Verify exactly one option has correct=true
		opts := cfg["options"].([]interface{})
		correctCount := 0
		for _, o := range opts {
			om := o.(map[string]interface{})
			if c, ok := om["correct"].(bool); ok && c {
				correctCount++
			}
			if _, ok := om["grapheme"]; !ok {
				t.Error("phonics_match option missing 'grapheme'")
			}
		}
		if correctCount != 1 {
			t.Errorf("phonics_match: expected 1 correct option, got %d", correctCount)
		}
	})

	t.Run("pattern_intro", func(t *testing.T) {
		act, _ := buildPatternIntroActivity(grammarStructures[0], patterns, vocabByWord, allVocab, 0)
		if act.ActivityType != "pattern_intro" {
			t.Errorf("pattern_intro: ActivityType=%q, want pattern_intro", act.ActivityType)
		}
		var cfg map[string]interface{}
		if err := json.Unmarshal(act.Config, &cfg); err != nil {
			t.Fatalf("pattern_intro: failed to unmarshal config: %v", err)
		}
		requireKeys(t, "pattern_intro", cfg,
			"type", "grammar_structure_id", "grammar_name",
			"description_vi", "template", "cefr_level", "examples")
		requireListOfMaps(t, "pattern_intro", cfg, "examples")
		// examples should each have en+vi
		exs := cfg["examples"].([]interface{})
		for i, e := range exs {
			em := e.(map[string]interface{})
			if _, ok := em["en"]; !ok {
				t.Errorf("pattern_intro examples[%d] missing 'en'", i)
			}
			if _, ok := em["vi"]; !ok {
				t.Errorf("pattern_intro examples[%d] missing 'vi'", i)
			}
		}
		// l1_tip is optional but if present must have all keys Flutter reads
		if l1, ok := cfg["l1_tip"].(map[string]interface{}); ok {
			for _, k := range []string{"error", "example_wrong", "example_correct", "reason_vi"} {
				if _, ok := l1[k]; !ok {
					t.Errorf("pattern_intro l1_tip missing %q", k)
				}
			}
		}
	})
}

// TestSimulateFullLessonRunThrough builds a full session containing one of
// every activity template, then walks the sequence to ensure no panics and
// that each activity's config survives JSON round-trip.
func TestSimulateFullLessonRunThrough(t *testing.T) {
	allVocab, vocabByWord := mockVocabulary()
	patterns := mockPatterns()
	grammarStructures := mockGrammarStructures()
	phonemes := mockPhonemes()

	type tmpl struct {
		name  string
		build func() (map[string]interface{}, string)
	}
	templates := []tmpl{
		{"flashcard_intro", func() (map[string]interface{}, string) {
			c, r, _ := buildFlashcardIntroConfig(allVocab, nil)
			c["type"] = "flashcard_intro"
			return c, r
		}},
		{"listen_and_choose", func() (map[string]interface{}, string) {
			c, r, _ := buildListenAndChooseConfig(allVocab, allVocab, nil, nil)
			c["type"] = "listen_and_choose"
			return c, r
		}},
		{"listen_and_repeat", func() (map[string]interface{}, string) {
			c, r, _ := buildSpeakConfig("listen_and_repeat", allVocab, nil, nil)
			return c, r
		}},
		{"speak_word", func() (map[string]interface{}, string) {
			c, r, _ := buildSpeakConfig("speak_word", allVocab, nil, nil)
			return c, r
		}},
		{"word_match", func() (map[string]interface{}, string) {
			c, r, _ := buildWordMatchConfig(allVocab)
			c["type"] = "word_match"
			return c, r
		}},
		{"fill_blank", func() (map[string]interface{}, string) {
			c, r, _ := buildFillBlankConfig(allVocab, allVocab, patterns, vocabByWord)
			return c, r
		}},
		{"build_sentence", func() (map[string]interface{}, string) {
			c, r, _ := buildBuildSentenceConfig(allVocab, patterns, vocabByWord)
			return c, r
		}},
		{"phonics_listen", func() (map[string]interface{}, string) {
			c := BuildPhonicsListenConfig(phonemes[0])
			c["type"] = "phonics_listen"
			return c, "mock phonics listen"
		}},
		{"phonics_match", func() (map[string]interface{}, string) {
			c := BuildPhonicsMatchConfig(phonemes[0], phonemes)
			c["type"] = "phonics_match"
			return c, "mock phonics match"
		}},
		{"pattern_intro", func() (map[string]interface{}, string) {
			act, r := buildPatternIntroActivity(grammarStructures[0], patterns, vocabByWord, allVocab, 0)
			var c map[string]interface{}
			json.Unmarshal(act.Config, &c)
			return c, r
		}},
	}

	t.Logf("=== Simulating full lesson run-through (%d activities) ===", len(templates))
	for i, tt := range templates {
		t.Run(fmt.Sprintf("step_%02d_%s", i+1, tt.name), func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("PANIC during %s: %v", tt.name, r)
				}
			}()
			cfg, reason := tt.build()
			if cfg == nil {
				t.Fatalf("%s: builder returned nil config", tt.name)
			}
			// Ensure JSON-serializable
			raw, err := json.Marshal(cfg)
			if err != nil {
				t.Fatalf("%s: not JSON-serializable: %v", tt.name, err)
			}
			t.Logf("✓ %02d. %-20s | reason=%s | %d bytes", i+1, tt.name, reason, len(raw))
		})
	}
}
