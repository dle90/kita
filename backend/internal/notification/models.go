package notification

import "github.com/google/uuid"

type NotificationPayload struct {
	Title    string            `json:"title"`
	Body     string            `json:"body"`
	Data     map[string]string `json:"data,omitempty"`
	DeviceID string            `json:"device_id"`
}

type UpdateTokenRequest struct {
	KidID       uuid.UUID `json:"kid_id" validate:"required"`
	DeviceToken string    `json:"device_token" validate:"required"`
	Platform    string    `json:"platform" validate:"required"` // "ios" or "android"
}
