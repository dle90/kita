package pronunciation

import (
	"time"

	"github.com/google/uuid"
)

type L1ErrorType string

const (
	FinalConsonantDrop    L1ErrorType = "final_consonant_drop"
	ThSubstitution        L1ErrorType = "th_substitution"
	RLConfusion           L1ErrorType = "rl_confusion"
	VowelLength           L1ErrorType = "vowel_length"
	ClusterSimplification L1ErrorType = "cluster_simplification"
	WVConfusion           L1ErrorType = "wv_confusion"
)

type ScoreRequest struct {
	KidID         uuid.UUID `json:"kid_id"`
	ReferenceText string    `json:"reference_text"`
	VocabularyID  *uuid.UUID `json:"vocabulary_id,omitempty"`
}

type PronunciationScore struct {
	ID                 uuid.UUID      `json:"id"`
	KidID              uuid.UUID      `json:"kid_id"`
	VocabularyID       *uuid.UUID     `json:"vocabulary_id,omitempty"`
	ReferenceText      string         `json:"reference_text"`
	AudioURL           string         `json:"audio_url"`
	AccuracyScore      float64        `json:"accuracy_score"`
	FluencyScore       float64        `json:"fluency_score"`
	CompletenessScore  float64        `json:"completeness_score"`
	PronunciationScore float64        `json:"pronunciation_score"`
	Phonemes           []PhonemeResult `json:"phonemes"`
	L1Errors           []L1Error      `json:"l1_errors"`
	CreatedAt          time.Time      `json:"created_at"`
}

type PhonemeResult struct {
	Phoneme   string  `json:"phoneme"`
	Score     float64 `json:"score"`
	IsCorrect bool    `json:"is_correct"`
	Expected  string  `json:"expected"`
	Actual    string  `json:"actual"`
}

type L1Error struct {
	Type            L1ErrorType `json:"type"`
	ExpectedPhoneme string      `json:"expected_phoneme"`
	ActualPhoneme   string      `json:"actual_phoneme"`
	Severity        string      `json:"severity"`
	SuggestionVI    string      `json:"suggestion_vi"`
}

// Azure API response structures
type AzureResponse struct {
	RecognitionStatus string         `json:"RecognitionStatus"`
	NBest             []AzureNBest   `json:"NBest"`
}

type AzureNBest struct {
	Confidence         float64        `json:"Confidence"`
	PronunciationAssessment AzurePronAssessment `json:"PronunciationAssessment"`
	Words              []AzureWord    `json:"Words"`
}

type AzurePronAssessment struct {
	AccuracyScore     float64 `json:"AccuracyScore"`
	FluencyScore      float64 `json:"FluencyScore"`
	CompletenessScore float64 `json:"CompletenessScore"`
	PronScore         float64 `json:"PronScore"`
}

type AzureWord struct {
	Word                    string              `json:"Word"`
	PronunciationAssessment AzureWordAssessment `json:"PronunciationAssessment"`
	Phonemes                []AzurePhoneme      `json:"Phonemes"`
}

type AzureWordAssessment struct {
	AccuracyScore float64 `json:"AccuracyScore"`
	ErrorType     string  `json:"ErrorType"`
}

type AzurePhoneme struct {
	Phoneme                 string              `json:"Phoneme"`
	PronunciationAssessment AzurePhonemeAssessment `json:"PronunciationAssessment"`
}

type AzurePhonemeAssessment struct {
	AccuracyScore float64 `json:"AccuracyScore"`
}
