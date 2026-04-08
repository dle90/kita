package srs

import (
	"time"

	"github.com/google/uuid"
)

type SrsCard struct {
	ID             uuid.UUID `json:"id"`
	KidID          uuid.UUID `json:"kid_id"`
	VocabularyID   uuid.UUID `json:"vocabulary_id"`
	Repetitions    int       `json:"repetitions"`
	EaseFactor     float64   `json:"ease_factor"`
	IntervalDays   int       `json:"interval_days"`
	NextReviewDate time.Time `json:"next_review_date"`
	LastReviewDate *time.Time `json:"last_review_date,omitempty"`
	LastQuality    int       `json:"last_quality"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type ReviewRequest struct {
	CardID  uuid.UUID `json:"card_id" validate:"required"`
	Quality int       `json:"quality"` // 0-5
}

// SkillType represents one of the four language skills tracked per word.
type SkillType string

const (
	SkillListening SkillType = "listening"
	SkillSpeaking  SkillType = "speaking"
	SkillReading   SkillType = "reading"
	SkillWriting   SkillType = "writing"
)

// WordSkillMastery tracks per-skill scores for a word-kid pair.
type WordSkillMastery struct {
	ID                uuid.UUID  `json:"id"`
	KidID             uuid.UUID  `json:"kid_id"`
	VocabularyID      uuid.UUID  `json:"vocabulary_id"`
	ListeningScore    float64    `json:"listening_score"`
	ListeningAttempts int        `json:"listening_attempts"`
	SpeakingScore     float64    `json:"speaking_score"`
	SpeakingAttempts  int        `json:"speaking_attempts"`
	ReadingScore      float64    `json:"reading_score"`
	ReadingAttempts   int        `json:"reading_attempts"`
	WritingScore      float64    `json:"writing_score"`
	WritingAttempts   int        `json:"writing_attempts"`
	OverallMastery    float64    `json:"overall_mastery"`
	LastSeen          *time.Time `json:"last_seen,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}
