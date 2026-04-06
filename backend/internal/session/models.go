package session

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type KidSession struct {
	ID          uuid.UUID  `json:"id"`
	KidID       uuid.UUID  `json:"kid_id"`
	DayNumber   int        `json:"day_number"`
	StartedAt   *time.Time `json:"started_at,omitempty"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	TotalStars  int        `json:"total_stars"`
	AccuracyPct float64    `json:"accuracy_pct"`
	CreatedAt   time.Time  `json:"created_at"`
}

type ActivityResult struct {
	ID           uuid.UUID       `json:"id"`
	SessionID    uuid.UUID       `json:"session_id"`
	KidID        uuid.UUID       `json:"kid_id"`
	ActivityType string          `json:"activity_type"`
	VocabularyID *uuid.UUID      `json:"vocabulary_id,omitempty"`
	IsCorrect    bool            `json:"is_correct"`
	Attempts     int             `json:"attempts"`
	TimeSpentMs  int             `json:"time_spent_ms"`
	StarsEarned  int             `json:"stars_earned"`
	Metadata     json.RawMessage `json:"metadata,omitempty"`
	CreatedAt    time.Time       `json:"created_at"`
}

type ActivityResultRequest struct {
	ActivityType string          `json:"activity_type" validate:"required"`
	VocabularyID *uuid.UUID      `json:"vocabulary_id,omitempty"`
	IsCorrect    bool            `json:"is_correct"`
	Attempts     int             `json:"attempts"`
	TimeSpentMs  int             `json:"time_spent_ms"`
	StarsEarned  int             `json:"stars_earned"`
	Metadata     json.RawMessage `json:"metadata,omitempty"`
}

type Activity struct {
	ID            uuid.UUID       `json:"id"`
	Phase         string          `json:"phase"`
	ActivityType  string          `json:"activity_type"`
	Config        json.RawMessage `json:"config"`
	VocabularyIDs []uuid.UUID     `json:"vocabulary_ids"`
	SentenceIDs   []uuid.UUID     `json:"sentence_ids"`
	SortOrder     int             `json:"sort_order"`
}

type SessionWithActivities struct {
	KidSession
	Activities []Activity `json:"activities"`
}
