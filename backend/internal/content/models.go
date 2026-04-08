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
