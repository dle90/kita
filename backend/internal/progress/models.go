package progress

import (
	"time"

	"github.com/google/uuid"
)

type DailyProgress struct {
	ID               uuid.UUID `json:"id"`
	KidID            uuid.UUID `json:"kid_id"`
	Date             time.Time `json:"date"`
	WordsLearned     int       `json:"words_learned"`
	WordsReviewed    int       `json:"words_reviewed"`
	AvgPronScore     float64   `json:"avg_pron_score"`
	SessionCompleted bool      `json:"session_completed"`
	TotalTimeMs      int       `json:"total_time_ms"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type ChallengeSummary struct {
	DaysCompleted int     `json:"days_completed"`
	TotalWords    int     `json:"total_words"`
	AvgScore      float64 `json:"avg_score"`
	Streak        int     `json:"streak"`
	TotalTimeMs   int64   `json:"total_time_ms"`
}

type VocabularyProgress struct {
	TotalWords    int `json:"total_words"`
	WordsLearned  int `json:"words_learned"`
	WordsMastered int `json:"words_mastered"`
	WordsDue      int `json:"words_due"`
}

type PronunciationProgress struct {
	TotalAttempts int     `json:"total_attempts"`
	AvgScore      float64 `json:"avg_score"`
	BestScore     float64 `json:"best_score"`
	CommonErrors  []string `json:"common_errors"`
}
