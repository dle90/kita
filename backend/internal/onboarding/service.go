package onboarding

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
)

type OnboardingService struct {
	kidRepo KidRepository
}

func NewOnboardingService(kidRepo KidRepository) *OnboardingService {
	return &OnboardingService{kidRepo: kidRepo}
}

func (s *OnboardingService) CreateKid(ctx context.Context, parentID uuid.UUID, req CreateKidRequest) (*Kid, error) {
	if req.Dialect != "northern" && req.Dialect != "central" && req.Dialect != "southern" {
		return nil, common.ErrBadRequest("dialect must be 'northern', 'central', or 'southern'")
	}
	if req.Age < 3 || req.Age > 12 {
		return nil, common.ErrBadRequest("age must be between 3 and 12")
	}

	level := req.EnglishLevel
	if level == "" {
		level = "beginner"
	}

	kid := &Kid{
		ID:               uuid.New(),
		ParentID:         parentID,
		DisplayName:      req.DisplayName,
		CharacterID:      req.CharacterID,
		Age:              req.Age,
		Dialect:          req.Dialect,
		EnglishLevel:     level,
		NotificationTime: req.NotificationTime,
		PlacementDone:    false,
		CurrentDay:       1,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}

	if err := s.kidRepo.CreateKid(ctx, kid); err != nil {
		return nil, common.ErrInternal("failed to create kid profile")
	}

	return kid, nil
}

func (s *OnboardingService) GetKid(ctx context.Context, kidID uuid.UUID) (*Kid, error) {
	kid, err := s.kidRepo.GetKid(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get kid")
	}
	if kid == nil {
		return nil, common.ErrNotFound("kid not found")
	}
	return kid, nil
}

func (s *OnboardingService) GetKidsByParent(ctx context.Context, parentID uuid.UUID) ([]*Kid, error) {
	kids, err := s.kidRepo.GetKidsByParent(ctx, parentID)
	if err != nil {
		return nil, common.ErrInternal("failed to get kids")
	}
	return kids, nil
}

func (s *OnboardingService) UpdateKid(ctx context.Context, kidID uuid.UUID, req UpdateKidRequest) (*Kid, error) {
	kid, err := s.kidRepo.GetKid(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get kid")
	}
	if kid == nil {
		return nil, common.ErrNotFound("kid not found")
	}

	if req.DisplayName != nil {
		kid.DisplayName = *req.DisplayName
	}
	if req.CharacterID != nil {
		kid.CharacterID = *req.CharacterID
	}
	if req.Dialect != nil {
		if *req.Dialect != "northern" && *req.Dialect != "central" && *req.Dialect != "southern" {
			return nil, common.ErrBadRequest("dialect must be 'northern', 'central', or 'southern'")
		}
		kid.Dialect = *req.Dialect
	}
	if req.EnglishLevel != nil {
		kid.EnglishLevel = *req.EnglishLevel
	}
	if req.NotificationTime != nil {
		kid.NotificationTime = req.NotificationTime
	}

	if err := s.kidRepo.UpdateKid(ctx, kid); err != nil {
		return nil, common.ErrInternal("failed to update kid")
	}
	return kid, nil
}

func (s *OnboardingService) SubmitPlacement(ctx context.Context, kidID uuid.UUID, req PlacementResultRequest) (*Kid, error) {
	kid, err := s.kidRepo.GetKid(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get kid")
	}
	if kid == nil {
		return nil, common.ErrNotFound("kid not found")
	}

	level := calculateLevel(req.Scores)

	if err := s.kidRepo.UpdatePlacement(ctx, kidID, level); err != nil {
		return nil, common.ErrInternal("failed to update placement")
	}

	kid.PlacementDone = true
	kid.EnglishLevel = level
	return kid, nil
}

func calculateLevel(scores map[string]int) string {
	total := 0
	count := 0
	for _, score := range scores {
		total += score
		count++
	}
	if count == 0 {
		return "beginner"
	}
	avg := total / count
	switch {
	case avg >= 80:
		return "intermediate"
	case avg >= 50:
		return "elementary"
	default:
		return "beginner"
	}
}
