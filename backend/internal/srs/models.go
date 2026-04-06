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
