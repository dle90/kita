package session

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/content"
	"github.com/kitaenglish/backend/internal/onboarding"
	"github.com/kitaenglish/backend/internal/srs"
)

type SessionService struct {
	sessionRepo      SessionRepository
	activityRepo     ActivityResultRepository
	contentRepo      content.ContentRepository
	kidRepo          onboarding.KidRepository
	srsRepo          srs.SrsRepository
	skillMasteryRepo srs.SkillMasteryRepository
}

func NewSessionService(
	sessionRepo SessionRepository,
	activityRepo ActivityResultRepository,
	contentRepo content.ContentRepository,
	kidRepo onboarding.KidRepository,
	srsRepo srs.SrsRepository,
	skillMasteryRepo ...srs.SkillMasteryRepository,
) *SessionService {
	s := &SessionService{
		sessionRepo:  sessionRepo,
		activityRepo: activityRepo,
		contentRepo:  contentRepo,
		kidRepo:      kidRepo,
		srsRepo:      srsRepo,
	}
	if len(skillMasteryRepo) > 0 && skillMasteryRepo[0] != nil {
		s.skillMasteryRepo = skillMasteryRepo[0]
	}
	return s
}

func (s *SessionService) GetOrCreateSessions(ctx context.Context, kidID uuid.UUID) ([]*KidSession, error) {
	kid, err := s.kidRepo.GetKid(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get kid")
	}
	if kid == nil {
		return nil, common.ErrNotFound("kid not found")
	}

	existing, err := s.sessionRepo.GetKidSessions(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get sessions")
	}

	existingDays := make(map[int]bool)
	for _, sess := range existing {
		existingDays[sess.DayNumber] = true
	}

	for day := 1; day <= 7; day++ {
		if existingDays[day] {
			continue
		}
		session := &KidSession{
			ID:        uuid.New(),
			KidID:     kidID,
			DayNumber: day,
			CreatedAt: time.Now(),
		}
		if err := s.sessionRepo.CreateKidSession(ctx, session); err != nil {
			return nil, common.ErrInternal("failed to create session")
		}
	}

	sessions, err := s.sessionRepo.GetKidSessions(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get sessions")
	}
	return sessions, nil
}

func (s *SessionService) GetSession(ctx context.Context, kidID uuid.UUID, dayNumber int) (*SessionWithActivities, error) {
	kid, err := s.kidRepo.GetKid(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get kid")
	}
	if kid == nil {
		return nil, common.ErrNotFound("kid not found")
	}

	session, err := s.sessionRepo.GetKidSession(ctx, kidID, dayNumber)
	if err != nil {
		return nil, common.ErrInternal("failed to get session")
	}
	if session == nil {
		return nil, common.ErrNotFound("session not found")
	}

	templates, err := s.contentRepo.GetSessionTemplates(ctx, dayNumber, kid.EnglishLevel)
	if err != nil {
		return nil, common.ErrInternal("failed to get session templates")
	}

	// If no templates for this level, fall back to beginner
	if len(templates) == 0 && kid.EnglishLevel != "beginner" {
		templates, err = s.contentRepo.GetSessionTemplates(ctx, dayNumber, "beginner")
		if err != nil {
			return nil, common.ErrInternal("failed to get fallback session templates")
		}
	}

	dueCards, err := s.srsRepo.GetDueCards(ctx, kidID, time.Now())
	if err != nil {
		dueCards = nil // non-fatal, just skip SRS cards
	}

	recentAccuracy := s.getRecentAccuracy(ctx, kidID)

	// Collect all vocabulary IDs we need to look up
	vocabIDs := s.collectVocabularyIDs(templates, dueCards)
	vocabByID, _ := GetVocabularyForActivity(ctx, s.contentRepo, vocabIDs)
	if vocabByID == nil {
		vocabByID = make(map[uuid.UUID]*content.Vocabulary)
	}

	activities := GenerateSessionActivities(dayNumber, templates, dueCards, recentAccuracy, vocabByID)

	return &SessionWithActivities{
		KidSession: *session,
		Activities: activities,
	}, nil
}

func (s *SessionService) StartSession(ctx context.Context, kidID uuid.UUID, dayNumber int) (*KidSession, error) {
	session, err := s.sessionRepo.GetKidSession(ctx, kidID, dayNumber)
	if err != nil {
		return nil, common.ErrInternal("failed to get session")
	}
	if session == nil {
		return nil, common.ErrNotFound("session not found")
	}
	if session.StartedAt != nil {
		return session, nil // already started
	}

	if err := s.sessionRepo.StartSession(ctx, session.ID); err != nil {
		return nil, common.ErrInternal("failed to start session")
	}

	now := time.Now()
	session.StartedAt = &now
	return session, nil
}

func (s *SessionService) CompleteSession(ctx context.Context, kidID uuid.UUID, dayNumber int) (*KidSession, error) {
	session, err := s.sessionRepo.GetKidSession(ctx, kidID, dayNumber)
	if err != nil {
		return nil, common.ErrInternal("failed to get session")
	}
	if session == nil {
		return nil, common.ErrNotFound("session not found")
	}
	if session.CompletedAt != nil {
		return session, nil // already completed
	}

	results, err := s.activityRepo.GetResults(ctx, session.ID)
	if err != nil {
		return nil, common.ErrInternal("failed to get activity results")
	}

	totalStars := 0
	correct := 0
	total := len(results)
	for _, r := range results {
		totalStars += r.StarsEarned
		if r.IsCorrect {
			correct++
		}
	}

	var accuracyPct float64
	if total > 0 {
		accuracyPct = float64(correct) / float64(total) * 100
	}

	if err := s.sessionRepo.CompleteSession(ctx, session.ID, totalStars, accuracyPct); err != nil {
		return nil, common.ErrInternal("failed to complete session")
	}

	// Create SRS cards for vocabulary encountered in this session
	vocabSet := make(map[uuid.UUID]bool)
	for _, r := range results {
		if r.VocabularyID != nil {
			vocabSet[*r.VocabularyID] = true
		}
	}
	if len(vocabSet) > 0 {
		vocabIDs := make([]uuid.UUID, 0, len(vocabSet))
		for vid := range vocabSet {
			vocabIDs = append(vocabIDs, vid)
		}
		srsService := srs.NewSrsService(s.srsRepo)
		_ = srsService.CreateCardsForSession(ctx, kidID, vocabIDs)
	}

	// Review SRS cards based on activity results (map attempts to SM-2 quality)
	s.reviewSRSCardsFromResults(ctx, kidID, results)

	// Update per-skill mastery for all activity results in this session
	s.updateSkillMasteryFromResults(ctx, kidID, results)

	// Update kid's current day
	kid, _ := s.kidRepo.GetKid(ctx, kidID)
	if kid != nil && dayNumber >= kid.CurrentDay && dayNumber < 7 {
		kid.CurrentDay = dayNumber + 1
		_ = s.kidRepo.UpdateKid(ctx, kid)
	}

	now := time.Now()
	session.CompletedAt = &now
	session.TotalStars = totalStars
	session.AccuracyPct = accuracyPct
	return session, nil
}

func (s *SessionService) SubmitActivityResult(ctx context.Context, kidID uuid.UUID, sessionID uuid.UUID, req ActivityResultRequest) (*ActivityResult, error) {
	session, err := s.sessionRepo.GetKidSessionByID(ctx, sessionID)
	if err != nil {
		return nil, common.ErrInternal("failed to get session")
	}
	if session == nil {
		return nil, common.ErrNotFound("session not found")
	}
	if session.KidID != kidID {
		return nil, common.ErrForbidden("session does not belong to this kid")
	}

	result := &ActivityResult{
		ID:           uuid.New(),
		SessionID:    sessionID,
		KidID:        kidID,
		ActivityType: req.ActivityType,
		VocabularyID: req.VocabularyID,
		IsCorrect:    req.IsCorrect,
		Attempts:     req.Attempts,
		TimeSpentMs:  req.TimeSpentMs,
		StarsEarned:  req.StarsEarned,
		Metadata:     req.Metadata,
		CreatedAt:    time.Now(),
	}

	if err := s.activityRepo.SaveResult(ctx, result); err != nil {
		return nil, common.ErrInternal("failed to save activity result")
	}

	// Update per-skill mastery tracking
	if s.skillMasteryRepo != nil && result.VocabularyID != nil {
		skill := ActivityTypeToSkill(result.ActivityType)
		score := scoreFromActivityResult(result)
		_ = s.skillMasteryRepo.UpdateSkillScore(ctx, kidID, *result.VocabularyID, skill, score)
	}

	return result, nil
}

// scoreFromActivityResult converts an activity result into a 0-100 score for skill mastery.
func scoreFromActivityResult(result *ActivityResult) float64 {
	if !result.IsCorrect {
		// Wrong answers still give partial credit based on attempts
		if result.Attempts >= 3 {
			return 20
		}
		return 30
	}
	// Correct answers: first attempt = 100, degrading with more attempts
	switch result.Attempts {
	case 0:
		return 50 // skipped/auto
	case 1:
		return 100
	case 2:
		return 80
	case 3:
		return 60
	default:
		return 50
	}
}

func (s *SessionService) getRecentAccuracy(ctx context.Context, kidID uuid.UUID) float64 {
	sessions, err := s.sessionRepo.GetKidSessions(ctx, kidID)
	if err != nil || len(sessions) == 0 {
		return 0
	}

	var totalAccuracy float64
	var count int
	for _, sess := range sessions {
		if sess.CompletedAt != nil {
			totalAccuracy += sess.AccuracyPct
			count++
		}
	}
	if count == 0 {
		return 0
	}
	return totalAccuracy / float64(count)
}

// collectVocabularyIDs gathers all unique vocabulary IDs from templates and SRS due cards
// so they can be fetched in a single batch query.
func (s *SessionService) collectVocabularyIDs(templates []*content.SessionTemplate, dueCards []*srs.SrsCard) []uuid.UUID {
	seen := make(map[uuid.UUID]bool)
	var ids []uuid.UUID

	for _, tmpl := range templates {
		for _, vid := range tmpl.VocabularyIDs {
			if !seen[vid] {
				seen[vid] = true
				ids = append(ids, vid)
			}
		}
	}

	for _, card := range dueCards {
		if !seen[card.VocabularyID] {
			seen[card.VocabularyID] = true
			ids = append(ids, card.VocabularyID)
		}
	}

	return ids
}

// reviewSRSCardsFromResults updates SRS cards based on activity results.
// It maps activity attempts/correctness to SM-2 quality scores.
func (s *SessionService) reviewSRSCardsFromResults(ctx context.Context, kidID uuid.UUID, results []*ActivityResult) {
	// Get all SRS cards for this kid to match vocabulary IDs
	cards, err := s.srsRepo.GetCardsByKid(ctx, kidID)
	if err != nil || len(cards) == 0 {
		return
	}

	// Build vocab -> card mapping
	cardByVocab := make(map[uuid.UUID]*srs.SrsCard, len(cards))
	for _, card := range cards {
		cardByVocab[card.VocabularyID] = card
	}

	srsService := srs.NewSrsService(s.srsRepo)

	for _, result := range results {
		if result.VocabularyID == nil {
			continue
		}
		card, ok := cardByVocab[*result.VocabularyID]
		if !ok {
			continue
		}

		quality := MapAttemptsToSM2Quality(result.Attempts, result.IsCorrect)
		_, _ = srsService.ReviewCard(ctx, card.ID, quality)
	}
}

// updateSkillMasteryFromResults updates per-skill mastery for all vocabulary in the session results.
func (s *SessionService) updateSkillMasteryFromResults(ctx context.Context, kidID uuid.UUID, results []*ActivityResult) {
	if s.skillMasteryRepo == nil {
		return
	}
	for _, result := range results {
		if result.VocabularyID == nil {
			continue
		}
		skill := ActivityTypeToSkill(result.ActivityType)
		score := scoreFromActivityResult(result)
		_ = s.skillMasteryRepo.UpdateSkillScore(ctx, kidID, *result.VocabularyID, skill, score)
	}
}
