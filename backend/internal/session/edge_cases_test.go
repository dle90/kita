package session

import (
	"encoding/json"
	"testing"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/content"
	"github.com/kitaenglish/backend/internal/curriculum"
	"github.com/kitaenglish/backend/internal/srs"
)

// edge_cases_test.go is a deeper sweep targeting:
//   1. Sentence helpers (ScrambleWords, GenerateSentenceFromExample, GenerateDistractorsFromCategory)
//   2. Personalization decision logic (resolveSkill, resolveFormat, selectSourceWords)
//   3. Curriculum DAG state transitions (GetNextGrammarStructure, SelectPhonemesForSession)
//   4. Full GenerateDynamicSession with mock repositories for fresh + experienced kids

// --- Sentence helpers -----------------------------------------------------

func TestScrambleWords_SingleWord(t *testing.T) {
	shuffled, correct := ScrambleWords("Apple.")
	if len(correct) != 1 || correct[0] != "Apple" {
		t.Errorf("correct=%v, want [Apple]", correct)
	}
	// BUG CHECK: single-word sentence is "scrambled" to itself.
	// build_sentence with a 1-word answer is a tap-the-only-tile activity.
	if len(shuffled) == 1 && shuffled[0] == correct[0] {
		t.Logf("KNOWN: single-word sentences produce trivial scramble (shuffled == correct)")
	}
}

func TestScrambleWords_TwoWords(t *testing.T) {
	// With only 2 words, there are only 2 permutations; the loop tries 10
	// shuffles, so it should find the swapped one. Verify it doesn't return
	// the original order.
	for trial := 0; trial < 50; trial++ {
		shuffled, correct := ScrambleWords("Hello world.")
		if len(shuffled) != 2 {
			t.Fatalf("trial %d: shuffled has %d words", trial, len(shuffled))
		}
		if shuffled[0] == correct[0] && shuffled[1] == correct[1] {
			t.Errorf("trial %d: 2-word sentence returned in original order", trial)
		}
	}
}

func TestScrambleWords_Empty(t *testing.T) {
	shuffled, correct := ScrambleWords("")
	if len(shuffled) != 0 || len(correct) != 0 {
		t.Errorf("empty sentence: got shuffled=%v, correct=%v", shuffled, correct)
	}
}

func TestGenerateSentenceFromExample_NoExamplesReturnsError(t *testing.T) {
	// A pattern with no examples must NOT leak its raw template (which
	// contains slot placeholders like {animal}) into the activity config.
	// The function must return an error so the caller falls back to the
	// word-level fill_blank/build_sentence path.
	pattern := &content.Pattern{
		ID:               "p_leaky",
		Template:         "I like {animal}.",
		TemplateVI:       "Tôi thích {animal}.",
		ExampleSentences: json.RawMessage(`[]`),
	}
	en, vi, err := GenerateSentenceFromExample(pattern)
	if err == nil {
		t.Errorf("expected error for empty examples; got en=%q vi=%q", en, vi)
	}
	if en != "" || vi != "" {
		t.Errorf("expected empty strings on error; got en=%q vi=%q", en, vi)
	}
}

func TestGenerateSentenceFromExample_PlaceholderInExample(t *testing.T) {
	// Even if examples list is non-empty, a single example containing
	// placeholders should be rejected.
	pattern := &content.Pattern{
		ID:               "p_bad_example",
		ExampleSentences: json.RawMessage(`[{"en":"I like {animal}.","vi":"Tôi thích {animal}."}]`),
	}
	_, _, err := GenerateSentenceFromExample(pattern)
	if err == nil {
		t.Error("expected error for example with placeholder; got nil")
	}
}

func TestGenerateSentenceFromExample_NormalPattern(t *testing.T) {
	pattern := &content.Pattern{
		ExampleSentences: json.RawMessage(`[{"en":"I like cat.","vi":"Tôi thích con mèo."}]`),
	}
	en, vi, err := GenerateSentenceFromExample(pattern)
	if err != nil || en != "I like cat." || vi != "Tôi thích con mèo." {
		t.Errorf("unexpected: en=%q vi=%q err=%v", en, vi, err)
	}
}

func TestGenerateDistractorsFromCategory_NoSameCategory(t *testing.T) {
	correct := &content.Vocabulary{Word: "cat", Category: "animal"}
	pool := []*content.Vocabulary{
		{Word: "rice", Category: "food"},
		{Word: "milk", Category: "food"},
		{Word: "bread", Category: "food"},
	}
	distractors := GenerateDistractorsFromCategory(correct, pool, 3)
	if len(distractors) != 3 {
		t.Errorf("expected 3 distractors from cross-category pool, got %d: %v", len(distractors), distractors)
	}
}

func TestGenerateDistractorsFromCategory_PoolTooSmall(t *testing.T) {
	correct := &content.Vocabulary{Word: "cat", Category: "animal"}
	pool := []*content.Vocabulary{{Word: "dog", Category: "animal"}}
	distractors := GenerateDistractorsFromCategory(correct, pool, 3)
	if len(distractors) != 1 {
		t.Errorf("expected 1 distractor, got %d: %v", len(distractors), distractors)
	}
}

// --- resolveSkill / resolveFormat -----------------------------------------

func TestResolveSkill_WeakestDeterministic(t *testing.T) {
	// All four scores tied at zero. The function MUST pick the same skill
	// every call, otherwise a fresh kid sees inconsistent activity selection
	// across consecutive sessions.
	summary := map[srs.SkillType]float64{
		srs.SkillListening: 0,
		srs.SkillSpeaking:  0,
		srs.SkillReading:   0,
		srs.SkillWriting:   0,
	}
	first := resolveSkill("weakest", summary, map[string]int{"listening": 0, "speaking": 0, "reading": 0, "writing": 0})
	for i := 0; i < 100; i++ {
		got := resolveSkill("weakest", summary, map[string]int{"listening": 0, "speaking": 0, "reading": 0, "writing": 0})
		if got != first {
			t.Errorf("BUG: resolveSkill('weakest') is non-deterministic on ties — got %q then %q", first, got)
			return
		}
	}
}

func TestResolveSkill_AutoDeterministic(t *testing.T) {
	// All counts tied at zero. Same determinism requirement.
	first := resolveSkill("auto", nil, map[string]int{"listening": 0, "speaking": 0, "reading": 0, "writing": 0})
	for i := 0; i < 100; i++ {
		got := resolveSkill("auto", nil, map[string]int{"listening": 0, "speaking": 0, "reading": 0, "writing": 0})
		if got != first {
			t.Errorf("BUG: resolveSkill('auto') is non-deterministic on ties — got %q then %q", first, got)
			return
		}
	}
}

func TestResolveSkill_PicksTrueWeakest(t *testing.T) {
	summary := map[srs.SkillType]float64{
		srs.SkillListening: 80,
		srs.SkillSpeaking:  90,
		srs.SkillReading:   30, // weakest
		srs.SkillWriting:   60,
	}
	got := resolveSkill("weakest", summary, nil)
	if got != "reading" {
		t.Errorf("resolveSkill('weakest') = %q, want reading", got)
	}
}

func TestResolveFormat_AvoidsRepeat(t *testing.T) {
	// listening has two formats: listen_and_choose, flashcard_intro.
	// If lastFormat is one, it should pick the other.
	got := resolveFormat("auto", "listening", "listen_and_choose")
	if got != "flashcard_intro" {
		t.Errorf("resolveFormat: with lastFormat=listen_and_choose got %q, want flashcard_intro", got)
	}
}

func TestResolveFormat_OnlyOneCandidate(t *testing.T) {
	// writing only has build_sentence as a candidate. If the last format
	// was also build_sentence, it has no choice but to repeat.
	got := resolveFormat("auto", "writing", "build_sentence")
	if got != "build_sentence" {
		t.Errorf("resolveFormat: writing with one candidate got %q, want build_sentence", got)
	}
}

// --- selectSourceWords ----------------------------------------------------

func TestSelectSourceWords_SrsDueEmpty(t *testing.T) {
	allVocab, _ := mockVocabulary()
	got := selectSourceWords("srs_due", allVocab[:2], allVocab, nil, nil, nil, nil, nil)
	if got != nil {
		t.Errorf("srs_due with no due cards should return nil/empty, got %d words", len(got))
	}
}

func TestSelectSourceWords_UnitVocabFiltersMastered(t *testing.T) {
	allVocab, _ := mockVocabulary()
	unit := allVocab[:3] // cat, dog, fish
	mastery := map[uuid.UUID]*srs.WordSkillMastery{
		unit[0].ID: {OverallMastery: 90}, // cat: mastered, should be filtered
		unit[1].ID: {OverallMastery: 50}, // dog: not yet
	}
	got := selectSourceWords("unit_vocab", unit, allVocab, nil, nil, nil, nil, mastery)
	if len(got) != 2 {
		t.Errorf("unit_vocab should filter mastered words: got %d, want 2", len(got))
	}
	for _, v := range got {
		if v.Word == "cat" {
			t.Error("unit_vocab returned mastered word 'cat'")
		}
	}
}

// --- DB-driven distractors --------------------------------------------------

func TestBuildListenAndChoose_PrefersDBDistractors(t *testing.T) {
	allVocab, _ := mockVocabulary()
	target := allVocab[0] // cat
	target.Distractors = []string{"cap", "cut", "car"}

	cfg, _, _ := buildListenAndChooseConfig([]*content.Vocabulary{target}, allVocab, nil, nil)
	opts := cfg["distractors"].([]string)
	want := map[string]bool{"cap": true, "cut": true, "car": true}
	for _, o := range opts {
		if !want[o] {
			t.Errorf("distractor %q not from DB column", o)
		}
	}
	if len(opts) != 3 {
		t.Errorf("expected 3 distractors from DB, got %d", len(opts))
	}
	target.Distractors = nil
}

func TestBuildListenAndChoose_FallsBackToCategoryWhenDBEmpty(t *testing.T) {
	allVocab, _ := mockVocabulary()
	target := allVocab[0] // cat, category=animal
	target.Distractors = nil

	cfg, _, _ := buildListenAndChooseConfig([]*content.Vocabulary{target}, allVocab, nil, nil)
	opts := cfg["distractors"].([]string)
	if len(opts) == 0 {
		t.Error("expected category fallback to produce distractors, got none")
	}
	for _, o := range opts {
		if o == target.Word {
			t.Errorf("fallback distractor must not equal target: %q", o)
		}
	}
}

func TestBuildFillBlank_SkipsWordWithoutExampleSentence(t *testing.T) {
	// A vocab row with no example sentence and no patterns must not
	// produce a config with synthesised "I like X." text.
	target := &content.Vocabulary{
		ID: uuid.New(), Word: "go", TranslationVI: "đi", Category: "verb",
		ExampleSentence: "", ExampleSentenceVI: "",
	}
	cfg, reason, _ := buildFillBlankConfig([]*content.Vocabulary{target}, nil, nil, nil)
	if sentence, ok := cfg["sentence"].(string); ok && sentence != "" {
		t.Errorf("expected empty/no sentence, got %q", sentence)
	}
	if reason != "no content available" {
		t.Errorf("expected 'no content available', got %q", reason)
	}
}

func TestBuildBuildSentence_SkipsWordWithoutExampleSentence(t *testing.T) {
	target := &content.Vocabulary{
		ID: uuid.New(), Word: "run", TranslationVI: "chạy", Category: "verb",
		ExampleSentence: "",
	}
	cfg, reason, _ := buildBuildSentenceConfig([]*content.Vocabulary{target}, nil, nil)
	if sentence, ok := cfg["sentence"].(string); ok && sentence != "" {
		t.Errorf("expected empty/no sentence, got %q", sentence)
	}
	if reason != "no content available" {
		t.Errorf("expected 'no content available', got %q", reason)
	}
}

func TestSelectSourceWords_UnknownSourceFallsBackToUnit(t *testing.T) {
	allVocab, _ := mockVocabulary()
	unit := allVocab[:2]
	got := selectSourceWords("nonsense_source", unit, allVocab, nil, nil, nil, nil, nil)
	if len(got) != 2 {
		t.Errorf("unknown source should fall back to unitWords (2), got %d", len(got))
	}
}

// --- Curriculum DAG -------------------------------------------------------

func TestGetNextGrammarStructure_FreshUser(t *testing.T) {
	structures := []*content.GrammarStructure{
		{ID: "gs1", Difficulty: 1, PrerequisiteIDs: []string{}},
		{ID: "gs2", Difficulty: 2, PrerequisiteIDs: []string{"gs1"}},
		{ID: "gs3", Difficulty: 3, PrerequisiteIDs: []string{"gs2"}},
	}
	next := curriculum.GetNextGrammarStructure(structures, nil)
	if next == nil || next.ID != "gs1" {
		t.Errorf("fresh user: expected gs1, got %v", next)
	}
}

func TestGetNextGrammarStructure_PrerequisiteMet(t *testing.T) {
	structures := []*content.GrammarStructure{
		{ID: "gs1", Difficulty: 1, PrerequisiteIDs: []string{}},
		{ID: "gs2", Difficulty: 2, PrerequisiteIDs: []string{"gs1"}},
	}
	exposures := []*curriculum.KidGrammarExposure{
		{GrammarStructureID: "gs1", ExposureCount: 2}, // hits the threshold
	}
	next := curriculum.GetNextGrammarStructure(structures, exposures)
	if next == nil || next.ID != "gs2" {
		t.Errorf("after gs1 met: expected gs2, got %v", next)
	}
}

func TestGetNextGrammarStructure_PrerequisiteNotMet(t *testing.T) {
	structures := []*content.GrammarStructure{
		{ID: "gs1", Difficulty: 1, PrerequisiteIDs: []string{}},
		{ID: "gs2", Difficulty: 2, PrerequisiteIDs: []string{"gs1"}},
	}
	exposures := []*curriculum.KidGrammarExposure{
		{GrammarStructureID: "gs1", ExposureCount: 1}, // below threshold (=2)
	}
	next := curriculum.GetNextGrammarStructure(structures, exposures)
	// gs2 is locked, gs1 is partially seen → gs1 should be reinforced.
	if next == nil || next.ID != "gs1" {
		t.Errorf("partial gs1: expected gs1 reinforce, got %v", next)
	}
}

func TestGetNextGrammarStructure_AllMaxed(t *testing.T) {
	structures := []*content.GrammarStructure{
		{ID: "gs1", Difficulty: 1, PrerequisiteIDs: []string{}},
		{ID: "gs2", Difficulty: 2, PrerequisiteIDs: []string{"gs1"}},
	}
	exposures := []*curriculum.KidGrammarExposure{
		{GrammarStructureID: "gs1", ExposureCount: 6},
		{GrammarStructureID: "gs2", ExposureCount: 6},
	}
	next := curriculum.GetNextGrammarStructure(structures, exposures)
	// Pass 3 fallback: returns first structure regardless.
	if next == nil {
		t.Error("all-maxed: expected fallback structure, got nil")
	}
}

func TestGetNextGrammarStructure_OrphanedPrereq(t *testing.T) {
	// A structure references a prerequisite that doesn't exist in the
	// allStructures slice. prerequisitesMet treats missing prereqs as
	// having exposure count 0 (zero-value of int from map miss), so it's
	// permanently locked. Confirm the fallback kicks in.
	structures := []*content.GrammarStructure{
		{ID: "gs2", Difficulty: 2, PrerequisiteIDs: []string{"gs_missing"}},
	}
	next := curriculum.GetNextGrammarStructure(structures, nil)
	if next == nil {
		t.Error("orphaned prereq: expected fallback, got nil")
	}
}

// --- SelectPhonemesForSession ---------------------------------------------

func TestSelectPhonemesForSession_FreshUser(t *testing.T) {
	phonemes := []*content.Phoneme{
		{ID: "θ", Symbol: "θ", IsNewForVietnamese: true},
		{ID: "p", Symbol: "p", IsNewForVietnamese: false},
		{ID: "b", Symbol: "b", IsNewForVietnamese: false},
	}
	selected := curriculum.SelectPhonemesForSession(phonemes, nil, 2)
	if len(selected) != 2 {
		t.Errorf("expected 2 phonemes, got %d", len(selected))
	}
	if selected[0].ID != "θ" {
		t.Errorf("expected new-for-VN phoneme first, got %q", selected[0].ID)
	}
}

func TestSelectPhonemesForSession_WeakFirst(t *testing.T) {
	phonemes := []*content.Phoneme{
		{ID: "θ", Symbol: "θ", IsNewForVietnamese: true},
		{ID: "ð", Symbol: "ð", IsNewForVietnamese: true},
	}
	weak := []string{"ð"} // explicitly weakest
	selected := curriculum.SelectPhonemesForSession(phonemes, weak, 1)
	if len(selected) != 1 || selected[0].ID != "ð" {
		t.Errorf("expected weak phoneme first, got %v", selected)
	}
}

func TestSelectPhonemesForSession_ZeroCount(t *testing.T) {
	phonemes := []*content.Phoneme{{ID: "θ"}}
	selected := curriculum.SelectPhonemesForSession(phonemes, nil, 0)
	if selected != nil {
		t.Errorf("zero count should return nil, got %v", selected)
	}
}

