package onboarding

import (
	"time"

	"github.com/google/uuid"
)

type Kid struct {
	ID               uuid.UUID  `json:"id"`
	ParentID         uuid.UUID  `json:"parent_id"`
	DisplayName      string     `json:"display_name"`
	CharacterID      string     `json:"character_id"`
	Age              int        `json:"age"`
	Dialect          string     `json:"dialect"`
	EnglishLevel     string     `json:"english_level"`
	NotificationTime *string    `json:"notification_time,omitempty"`
	PlacementDone    bool       `json:"placement_done"`
	CurrentDay       int        `json:"current_day"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

type CreateKidRequest struct {
	DisplayName      string  `json:"display_name" validate:"required,min=1,max=50"`
	CharacterID      string  `json:"character_id" validate:"required"`
	Age              int     `json:"age" validate:"required"`
	Dialect          string  `json:"dialect" validate:"required"`
	EnglishLevel     string  `json:"english_level"`
	NotificationTime *string `json:"notification_time,omitempty"`
}

type UpdateKidRequest struct {
	DisplayName      *string `json:"display_name,omitempty"`
	CharacterID      *string `json:"character_id,omitempty"`
	Dialect          *string `json:"dialect,omitempty"`
	EnglishLevel     *string `json:"english_level,omitempty"`
	NotificationTime *string `json:"notification_time,omitempty"`
}

type PlacementResultRequest struct {
	Scores map[string]int `json:"scores" validate:"required"`
}

type KidResponse struct {
	Kid
}
