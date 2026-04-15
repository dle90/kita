package content

import (
	"encoding/json"

	"github.com/google/uuid"
)

type Vocabulary struct {
	ID                uuid.UUID `json:"id"`
	Word              string    `json:"word"`
	TranslationVI     string    `json:"translation_vi"`
	PhoneticIPA       string    `json:"phonetic_ipa"`
	AudioURL          string    `json:"audio_url"`
	ImageURL          string    `json:"image_url"`
	Category          string    `json:"category"`
	DayNumber         int       `json:"day_number"`
	Difficulty        int       `json:"difficulty"`
	Emoji             string    `json:"emoji"`
	ExampleSentence   string    `json:"example_sentence"`
	ExampleSentenceVI string    `json:"example_sentence_vi"`
	TargetPhonemes    []string  `json:"target_phonemes"`
	CommonL1Errors    []string  `json:"common_l1_errors"`
	Distractors       []string  `json:"distractors"`
}

// CurriculumUnit groups vocabulary words and patterns into a thematic unit
// (e.g. unit 1 = "Greetings"). Used by the dynamic session generator to
// decide which words to teach for a given session day.
type CurriculumUnit struct {
	UnitNumber int      `json:"unit_number"`
	Theme      string   `json:"theme"`
	Words      []string `json:"words"`
	Patterns   []string `json:"patterns"`
}

type Sentence struct {
	ID            uuid.UUID   `json:"id"`
	Text          string      `json:"text"`
	TranslationVI string      `json:"translation_vi"`
	AudioURL      string      `json:"audio_url"`
	Difficulty    int         `json:"difficulty"`
	DayNumber     int         `json:"day_number"`
	VocabularyIDs []uuid.UUID `json:"vocabulary_ids"`
}

type SessionTemplate struct {
	ID            uuid.UUID       `json:"id"`
	DayNumber     int             `json:"day_number"`
	Level         string          `json:"level"`
	Phase         string          `json:"phase"`
	ActivityType  string          `json:"activity_type"`
	Config        json.RawMessage `json:"config"`
	SortOrder     int             `json:"sort_order"`
	VocabularyIDs []uuid.UUID     `json:"vocabulary_ids"`
	SentenceIDs   []uuid.UUID     `json:"sentence_ids"`
}

// GrammarStructure represents a grammar pattern structure for sentence generation.
type GrammarStructure struct {
	ID              string          `json:"id"`
	Name            string          `json:"name"`
	DescriptionVI   string          `json:"description_vi"`
	Template        string          `json:"template"`
	CEFRLevel       string          `json:"cefr_level"`
	Difficulty      int             `json:"difficulty"`
	PrerequisiteIDs []string        `json:"prerequisite_ids"`
	CommonL1Errors  json.RawMessage `json:"common_l1_errors"`
}

// PatternSlot describes a fillable slot in a pattern template.
type PatternSlot struct {
	Name         string `json:"name"`
	Category     string `json:"category"`
	PartOfSpeech string `json:"part_of_speech"`
}

// PatternExample is an example sentence for a pattern.
type PatternExample struct {
	En string `json:"en"`
	Vi string `json:"vi"`
}

// Pattern represents a sentence pattern template that can be filled with vocabulary.
type Pattern struct {
	ID                    string          `json:"id"`
	GrammarStructureID    string          `json:"grammar_structure_id"`
	Template              string          `json:"template"`
	TemplateVI            string          `json:"template_vi"`
	CommunicationFunction string          `json:"communication_function"`
	Slots                 json.RawMessage `json:"slots"`
	Difficulty            int             `json:"difficulty"`
	DayIntroduced         int             `json:"day_introduced"`
	ExampleSentences      json.RawMessage `json:"example_sentences"`
}

// GetSlots parses the Slots JSON into a slice of PatternSlot.
func (p *Pattern) GetSlots() []PatternSlot {
	var slots []PatternSlot
	json.Unmarshal(p.Slots, &slots)
	return slots
}

// GetExamples parses the ExampleSentences JSON into a slice of PatternExample.
func (p *Pattern) GetExamples() []PatternExample {
	var examples []PatternExample
	json.Unmarshal(p.ExampleSentences, &examples)
	return examples
}

// CommunicationFunction represents a communicative purpose grouping patterns.
type CommunicationFunction struct {
	ID            string          `json:"id"`
	Name          string          `json:"name"`
	NameVI        string          `json:"name_vi"`
	DescriptionVI string          `json:"description_vi"`
	CEFRLevel     string          `json:"cefr_level"`
	Situations    json.RawMessage `json:"situations"`
	PatternIDs    []string        `json:"pattern_ids"`
}

// Seed data structures for JSON import — grammar
type GrammarStructureSeed struct {
	ID              string          `json:"id"`
	Name            string          `json:"name"`
	DescriptionVI   string          `json:"description_vi"`
	Template        string          `json:"template"`
	CEFRLevel       string          `json:"cefr_level"`
	Difficulty      int             `json:"difficulty"`
	PrerequisiteIDs []string        `json:"prerequisite_ids"`
	CommonL1Errors  json.RawMessage `json:"common_l1_errors"`
}

type PatternSeed struct {
	ID                    string          `json:"id"`
	GrammarStructureID    string          `json:"grammar_structure_id"`
	Template              string          `json:"template"`
	TemplateVI            string          `json:"template_vi"`
	CommunicationFunction string          `json:"communication_function"`
	Slots                 json.RawMessage `json:"slots"`
	Difficulty            int             `json:"difficulty"`
	DayIntroduced         int             `json:"day_introduced"`
	ExampleSentences      json.RawMessage `json:"example_sentences"`
}

type CommunicationFunctionSeed struct {
	ID            string          `json:"id"`
	Name          string          `json:"name"`
	NameVI        string          `json:"name_vi"`
	DescriptionVI string          `json:"description_vi"`
	CEFRLevel     string          `json:"cefr_level"`
	Situations    json.RawMessage `json:"situations"`
	PatternIDs    []string        `json:"pattern_ids"`
}

// Seed data structures for JSON import
type VocabularySeed struct {
	Word              string   `json:"word"`
	TranslationVI     string   `json:"translation_vi"`
	PhoneticIPA       string   `json:"phonetic_ipa"`
	Category          string   `json:"category"`
	DayNumber         int      `json:"day_number"`
	Difficulty        int      `json:"difficulty"`
	Emoji             string   `json:"emoji"`
	ExampleSentence   string   `json:"example_sentence"`
	ExampleSentenceVI string   `json:"example_sentence_vi"`
	TargetPhonemes    []string `json:"target_phonemes"`
	CommonL1Errors    []string `json:"common_l1_errors"`
	Distractors       []string `json:"distractors"`
}

type SessionTemplateSeed struct {
	DayNumber    int             `json:"day_number"`
	Level        string          `json:"level"`
	Phase        string          `json:"phase"`
	ActivityType string          `json:"activity_type"`
	Config       json.RawMessage `json:"config"`
	SortOrder    int             `json:"sort_order"`
	WordRefs     []string        `json:"word_refs"`
}

// Phoneme represents an English phoneme with Vietnamese L1 learning data.
type Phoneme struct {
	ID                 string          `json:"id"`
	Symbol             string          `json:"symbol"`
	ExampleWord        string          `json:"example_word"`
	ExampleWordVI      string          `json:"example_word_vi"`
	Graphemes          []string        `json:"graphemes"`
	IsNewForVietnamese bool            `json:"is_new_for_vietnamese"`
	CommonSubstitution string          `json:"common_substitution"`
	SubstitutionVI     string          `json:"substitution_vi"`
	MouthPositionVI    string          `json:"mouth_position_vi"`
	Difficulty         int             `json:"difficulty"`
	PriorityNorthern   int             `json:"priority_northern"`
	PriorityCentral    int             `json:"priority_central"`
	PrioritySouthern   int             `json:"priority_southern"`
	MinimalPairs       json.RawMessage `json:"minimal_pairs"`
	PracticeWords      []string        `json:"practice_words"`
}

// PhonemeSeed is the JSON import structure for phonemes.
type PhonemeSeed struct {
	ID                 string          `json:"id"`
	Symbol             string          `json:"symbol"`
	ExampleWord        string          `json:"example_word"`
	ExampleWordVI      string          `json:"example_word_vi"`
	Graphemes          []string        `json:"graphemes"`
	IsNewForVietnamese bool            `json:"is_new_for_vietnamese"`
	CommonSubstitution string          `json:"common_substitution"`
	SubstitutionVI     string          `json:"substitution_vi"`
	MouthPositionVI    string          `json:"mouth_position_vi"`
	Difficulty         int             `json:"difficulty"`
	PriorityNorthern   int             `json:"priority_northern"`
	PriorityCentral    int             `json:"priority_central"`
	PrioritySouthern   int             `json:"priority_southern"`
	MinimalPairs       json.RawMessage `json:"minimal_pairs"`
	PracticeWords      []string        `json:"practice_words"`
}
