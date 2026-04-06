package srs

import (
	"context"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
)

type SrsService struct {
	repo SrsRepository
}

func NewSrsService(repo SrsRepository) *SrsService {
	return &SrsService{repo: repo}
}

// CreateCardsForSession creates SRS cards for vocabulary introduced in a session.
func (s *SrsService) CreateCardsForSession(ctx context.Context, kidID uuid.UUID, vocabularyIDs []uuid.UUID) error {
	now := time.Now()
	for _, vocabID := range vocabularyIDs {
		card := &SrsCard{
			ID:             uuid.New(),
			KidID:          kidID,
			VocabularyID:   vocabID,
			Repetitions:    0,
			EaseFactor:     2.5,
			IntervalDays:   1,
			NextReviewDate: now.AddDate(0, 0, 1), // review tomorrow
			LastQuality:    0,
			CreatedAt:      now,
			UpdatedAt:      now,
		}
		if err := s.repo.CreateCard(ctx, card); err != nil {
			return common.ErrInternal("failed to create SRS card")
		}
	}
	return nil
}

// ReviewCard applies the SM-2 algorithm to update a card after review.
func (s *SrsService) ReviewCard(ctx context.Context, cardID uuid.UUID, quality int) (*SrsCard, error) {
	if quality < 0 || quality > 5 {
		return nil, common.ErrBadRequest("quality must be between 0 and 5")
	}

	card, err := s.repo.GetCardByID(ctx, cardID)
	if err != nil {
		return nil, common.ErrInternal("failed to get card")
	}
	if card == nil {
		return nil, common.ErrNotFound("card not found")
	}

	card = applySM2(card, quality)

	if err := s.repo.UpdateCard(ctx, card); err != nil {
		return nil, common.ErrInternal("failed to update card")
	}

	return card, nil
}

// applySM2 implements the SuperMemo 2 (SM-2) algorithm.
func applySM2(card *SrsCard, quality int) *SrsCard {
	now := time.Now()
	card.LastQuality = quality
	card.LastReviewDate = &now

	if quality >= 3 {
		// Correct response
		card.Repetitions++
		switch card.Repetitions {
		case 1:
			card.IntervalDays = 1
		case 2:
			card.IntervalDays = 6
		default:
			card.IntervalDays = int(math.Round(float64(card.IntervalDays) * card.EaseFactor))
		}
	} else {
		// Incorrect response — reset
		card.Repetitions = 0
		card.IntervalDays = 1
	}

	// Update ease factor: EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
	q := float64(quality)
	card.EaseFactor = card.EaseFactor + (0.1 - (5-q)*(0.08+(5-q)*0.02))
	if card.EaseFactor < 1.3 {
		card.EaseFactor = 1.3
	}

	// Calculate next review date
	card.NextReviewDate = now.AddDate(0, 0, card.IntervalDays)

	return card
}
