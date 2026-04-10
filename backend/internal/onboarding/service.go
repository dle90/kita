package onboarding

import (
	"context"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/content"
	"github.com/kitaenglish/backend/internal/srs"
)

type OnboardingService struct {
	kidRepo          KidRepository
	contentRepo      content.ContentRepository
	skillMasteryRepo srs.SkillMasteryRepository
	srsRepo          srs.SrsRepository
}

func NewOnboardingService(
	kidRepo KidRepository,
	contentRepo content.ContentRepository,
	skillMasteryRepo srs.SkillMasteryRepository,
	srsRepo srs.SrsRepository,
) *OnboardingService {
	return &OnboardingService{
		kidRepo:          kidRepo,
		contentRepo:      contentRepo,
		skillMasteryRepo: skillMasteryRepo,
		srsRepo:          srsRepo,
	}
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

func (s *OnboardingService) SubmitPlacement(ctx context.Context, kidID uuid.UUID, req PlacementResultRequest) (*PlacementResponse, error) {
	kid, err := s.kidRepo.GetKid(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get kid")
	}
	if kid == nil {
		return nil, common.ErrNotFound("kid not found")
	}

	// Calculate skill baselines from placement answers
	baseline := computeSkillBaseline(req.Answers)

	// Calculate overall level from baselines
	level := calculateLevelFromBaseline(baseline)

	if err := s.kidRepo.UpdatePlacement(ctx, kidID, level); err != nil {
		return nil, common.ErrInternal("failed to update placement")
	}

	// Calculate overall score for backward compat
	score := int((baseline["listening"] + baseline["speaking"] + baseline["reading"]) / 3)

	resp := &PlacementResponse{
		Score:         score,
		SkillBaseline: baseline,
	}

	// Initialize Day 1 vocabulary mastery and SRS cards (only if not already done)
	wordsInit, cardsCreated := s.initializeDay1Mastery(ctx, kidID, baseline)
	resp.WordsInitialized = wordsInit
	resp.SRSCardsCreated = cardsCreated

	return resp, nil
}

// computeSkillBaseline maps placement round results to skill baselines (0-100).
func computeSkillBaseline(answers []PlacementAnswer) map[string]float64 {
	baseline := map[string]float64{
		"listening": 30, // default low if not tested
		"speaking":  30,
		"reading":   30,
		"writing":   0, // writing is not tested in placement
	}

	for _, ans := range answers {
		switch ans.Type {
		case "listen_tap":
			if ans.Correct {
				baseline["listening"] = 60
			} else {
				baseline["listening"] = 30
			}
		case "say_hello":
			// Mic test: always correct means baseline 50
			if ans.Correct {
				baseline["speaking"] = 50
			} else {
				baseline["speaking"] = 30
			}
		case "read_match":
			if ans.Correct {
				baseline["reading"] = 60
			} else {
				baseline["reading"] = 30
			}
		case "phonics":
			if ans.Correct {
				baseline["reading"] += 10 // boost reading
				// Phoneme perception contributes to listening too
				baseline["listening"] += 20
			}
		}
	}

	// Clamp all values to 0-100
	for k, v := range baseline {
		if v > 100 {
			baseline[k] = 100
		}
		if v < 0 {
			baseline[k] = 0
		}
	}

	return baseline
}

// calculateLevelFromBaseline determines an overall English level from skill baselines.
func calculateLevelFromBaseline(baseline map[string]float64) string {
	total := 0.0
	count := 0
	for _, v := range baseline {
		total += v
		count++
	}
	if count == 0 {
		return "beginner"
	}
	avg := total / float64(count)
	switch {
	case avg >= 60:
		return "intermediate"
	case avg >= 40:
		return "elementary"
	default:
		return "beginner"
	}
}

// calculateLevel is kept for backward compat with old score-based requests.
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

// initializeDay1Mastery creates initial skill mastery records and SRS cards for Day 1 vocabulary.
// It is idempotent: if records already exist for this kid, they are not duplicated.
func (s *OnboardingService) initializeDay1Mastery(ctx context.Context, kidID uuid.UUID, baseline map[string]float64) (wordsInit int, cardsCreated int) {
	if s.contentRepo == nil || s.skillMasteryRepo == nil || s.srsRepo == nil {
		log.Printf("Placement init: skipping mastery initialization (missing dependencies)")
		return 0, 0
	}

	// Get Day 1 vocabulary
	vocab, err := s.contentRepo.GetVocabulary(ctx, 1, "")
	if err != nil {
		log.Printf("Placement init: failed to get Day 1 vocabulary: %v", err)
		return 0, 0
	}
	if len(vocab) == 0 {
		log.Printf("Placement init: no Day 1 vocabulary found")
		return 0, 0
	}

	// Check if mastery records already exist for this kid
	vocabIDs := make([]uuid.UUID, len(vocab))
	for i, v := range vocab {
		vocabIDs[i] = v.ID
	}
	existing, err := s.skillMasteryRepo.GetMasteryForWords(ctx, kidID, vocabIDs)
	if err != nil {
		log.Printf("Placement init: failed to check existing mastery: %v", err)
		return 0, 0
	}
	if len(existing) > 0 {
		// Already initialized -- skip to avoid overwriting progress
		log.Printf("Placement init: mastery already exists for kid %s (%d records), skipping", kidID, len(existing))
		return 0, 0
	}

	now := time.Now()

	for _, v := range vocab {
		// Create skill mastery record with baseline scores
		// Use GetOrCreateMastery to create the record, then set baseline scores
		_, err := s.skillMasteryRepo.GetOrCreateMastery(ctx, kidID, v.ID)
		if err != nil {
			log.Printf("Placement init: failed to create mastery for word %s: %v", v.Word, err)
			continue
		}

		// Set baseline scores for each skill
		for _, skillInfo := range []struct {
			skill srs.SkillType
			key   string
		}{
			{srs.SkillListening, "listening"},
			{srs.SkillSpeaking, "speaking"},
			{srs.SkillReading, "reading"},
			{srs.SkillWriting, "writing"},
		} {
			score := baseline[skillInfo.key]
			if score > 0 {
				if err := s.skillMasteryRepo.UpdateSkillScore(ctx, kidID, v.ID, skillInfo.skill, score); err != nil {
					log.Printf("Placement init: failed to set %s score for word %s: %v", skillInfo.key, v.Word, err)
				}
			}
		}
		wordsInit++

		// Create SRS card with interval based on placement score
		avgScore := (baseline["listening"] + baseline["speaking"] + baseline["reading"] + baseline["writing"]) / 4.0
		var intervalDays int
		switch {
		case avgScore > 70:
			intervalDays = 2 // high placement: probably knows these
		case avgScore >= 40:
			intervalDays = 1 // medium: needs practice tomorrow
		default:
			intervalDays = 0 // low: review today
		}

		card := &srs.SrsCard{
			ID:             uuid.New(),
			KidID:          kidID,
			VocabularyID:   v.ID,
			Repetitions:    0,
			EaseFactor:     2.5,
			IntervalDays:   intervalDays,
			NextReviewDate: now.AddDate(0, 0, intervalDays),
			LastQuality:    0,
			CreatedAt:      now,
			UpdatedAt:      now,
		}

		if err := s.srsRepo.CreateCard(ctx, card); err != nil {
			log.Printf("Placement init: failed to create SRS card for word %s: %v", v.Word, err)
			continue
		}
		cardsCreated++
	}

	log.Printf("Placement init: initialized %d words and %d SRS cards for kid %s", wordsInit, cardsCreated, kidID)
	return wordsInit, cardsCreated
}
