package notification

import (
	"context"
	"log"
)

type NotificationService struct {
	// FCM client will be added when FCM integration is implemented
}

func NewNotificationService() *NotificationService {
	return &NotificationService{}
}

func (s *NotificationService) SendPushNotification(ctx context.Context, payload NotificationPayload) error {
	// Placeholder: FCM integration will be added in a future iteration
	log.Printf("Push notification (placeholder): title=%q body=%q device=%q",
		payload.Title, payload.Body, payload.DeviceID)
	return nil
}

func (s *NotificationService) SendSessionReminder(ctx context.Context, deviceToken string, kidName string) error {
	return s.SendPushNotification(ctx, NotificationPayload{
		Title:    "Time to learn English!",
		Body:     kidName + ", it's time for today's English lesson! Let's go!",
		DeviceID: deviceToken,
		Data: map[string]string{
			"type": "session_reminder",
		},
	})
}

func (s *NotificationService) SendStreakReminder(ctx context.Context, deviceToken string, kidName string, streak int) error {
	return s.SendPushNotification(ctx, NotificationPayload{
		Title:    "Keep your streak going!",
		Body:     kidName + ", don't break your streak! You're doing great!",
		DeviceID: deviceToken,
		Data: map[string]string{
			"type": "streak_reminder",
		},
	})
}
