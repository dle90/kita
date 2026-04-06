package progress

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/session"
	"github.com/kitaenglish/backend/internal/srs"
)

type ProgressService struct {
	progressRepo ProgressRepository
	sessionRepo  session.SessionRepository
	activityRepo session.ActivityResultRepository
	srsRepo      srs.SrsRepository
}

func NewProgressService(
	progressRepo ProgressRepository,
	sessionRepo session.SessionRepository,
	activityRepo session.ActivityResultRepository,
	srsRepo srs.SrsRepository,
) *ProgressService {
	return &ProgressService{
		progressRepo: progressRepo,
		sessionRepo:  sessionRepo,
		activityRepo: activityRepo,
		srsRepo:      srsRepo,
	}
}

func (s *ProgressService) RecordSessionProgress(ctx context.Context, kidID uuid.UUID, sess *session.KidSession) error {
	today := time.Now().Truncate(24 * time.Hour)

	existing, err := s.progressRepo.GetDailyProgress(ctx, kidID, today)
	if err != nil {
		return common.ErrInternal("failed to get daily progress")
	}

	results, err := s.activityRepo.GetResults(ctx, sess.ID)
	if err != nil {
		return common.ErrInternal("failed to get activity results")
	}

	wordsLearned := 0
	wordsReviewed := 0
	totalTimeMs := 0
	vocabSeen := make(map[uuid.UUID]bool)
	for _, r := range results {
		totalTimeMs += r.TimeSpentMs
		if r.VocabularyID != nil {
			if !vocabSeen[*r.VocabularyID] {
				wordsLearned++
				vocabSeen[*r.VocabularyID] = true
			}
			wordsReviewed++
		}
	}

	progress := &DailyProgress{
		KidID:            kidID,
		Date:             today,
		WordsLearned:     wordsLearned,
		WordsReviewed:    wordsReviewed,
		AvgPronScore:     sess.AccuracyPct,
		SessionCompleted: sess.CompletedAt != nil,
		TotalTimeMs:      totalTimeMs,
	}

	if existing != nil {
		progress.ID = existing.ID
		progress.CreatedAt = existing.CreatedAt
		progress.WordsLearned += existing.WordsLearned
		progress.WordsReviewed += existing.WordsReviewed
		progress.TotalTimeMs += existing.TotalTimeMs
		if existing.AvgPronScore > 0 {
			progress.AvgPronScore = (existing.AvgPronScore + sess.AccuracyPct) / 2
		}
	}

	return s.progressRepo.UpsertDailyProgress(ctx, progress)
}

func (s *ProgressService) GetChallengeSummary(ctx context.Context, kidID uuid.UUID) (*ChallengeSummary, error) {
	sessions, err := s.sessionRepo.GetKidSessions(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get sessions")
	}

	summary := &ChallengeSummary{}
	var totalScore float64
	var scoredSessions int

	for _, sess := range sessions {
		if sess.CompletedAt != nil {
			summary.DaysCompleted++
			totalScore += sess.AccuracyPct
			scoredSessions++
		}
	}

	if scoredSessions > 0 {
		summary.AvgScore = totalScore / float64(scoredSessions)
	}

	// Calculate streak
	summary.Streak = calculateStreak(sessions)

	// Get total words from SRS cards
	cards, err := s.srsRepo.GetCardsByKid(ctx, kidID)
	if err == nil {
		summary.TotalWords = len(cards)
	}

	// Get total time
	now := time.Now()
	weekAgo := now.AddDate(0, 0, -7)
	progresses, err := s.progressRepo.GetProgressRange(ctx, kidID, weekAgo, now)
	if err == nil {
		for _, p := range progresses {
			summary.TotalTimeMs += int64(p.TotalTimeMs)
		}
	}

	return summary, nil
}

func (s *ProgressService) GetDailyBreakdown(ctx context.Context, kidID uuid.UUID) ([]*DailyProgress, error) {
	now := time.Now()
	weekAgo := now.AddDate(0, 0, -7)
	progresses, err := s.progressRepo.GetProgressRange(ctx, kidID, weekAgo, now)
	if err != nil {
		return nil, common.ErrInternal("failed to get progress breakdown")
	}
	return progresses, nil
}

func (s *ProgressService) GetVocabularyProgress(ctx context.Context, kidID uuid.UUID) (*VocabularyProgress, error) {
	cards, err := s.srsRepo.GetCardsByKid(ctx, kidID)
	if err != nil {
		return nil, common.ErrInternal("failed to get SRS cards")
	}

	vp := &VocabularyProgress{
		TotalWords: 50, // 7-day challenge total
	}

	for _, card := range cards {
		vp.WordsLearned++
		if card.Repetitions >= 3 && card.EaseFactor >= 2.0 {
			vp.WordsMastered++
		}
		if card.NextReviewDate.Before(time.Now()) {
			vp.WordsDue++
		}
	}

	return vp, nil
}

func (s *ProgressService) GetPronunciationProgress(ctx context.Context, kidID uuid.UUID) (*PronunciationProgress, error) {
	// This would normally query the pronunciation_scores table
	// For now, derive from session data
	return &PronunciationProgress{
		TotalAttempts: 0,
		AvgScore:      0,
		BestScore:     0,
		CommonErrors:  []string{},
	}, nil
}

func calculateStreak(sessions []*session.KidSession) int {
	streak := 0
	for i := len(sessions) - 1; i >= 0; i-- {
		if sessions[i].CompletedAt != nil {
			streak++
		} else {
			break
		}
	}
	return streak
}
