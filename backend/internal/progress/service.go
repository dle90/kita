package progress

import (
	"context"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/pronunciation"
	"github.com/kitaenglish/backend/internal/session"
	"github.com/kitaenglish/backend/internal/srs"
)

type ProgressService struct {
	progressRepo ProgressRepository
	sessionRepo  session.SessionRepository
	activityRepo session.ActivityResultRepository
	srsRepo      srs.SrsRepository
	pronRepo     pronunciation.PronunciationRepository
}

func NewProgressService(
	progressRepo ProgressRepository,
	sessionRepo session.SessionRepository,
	activityRepo session.ActivityResultRepository,
	srsRepo srs.SrsRepository,
	pronRepo pronunciation.PronunciationRepository,
) *ProgressService {
	return &ProgressService{
		progressRepo: progressRepo,
		sessionRepo:  sessionRepo,
		activityRepo: activityRepo,
		srsRepo:      srsRepo,
		pronRepo:     pronRepo,
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

	// Get actual pronunciation score from pronunciation_scores if available
	avgPronScore := sess.AccuracyPct
	if s.pronRepo != nil {
		scores, pronErr := s.pronRepo.GetScoresByKid(ctx, kidID, 10)
		if pronErr == nil && len(scores) > 0 {
			// Use the average of recent pronunciation scores from today
			var todayTotal float64
			var todayCount int
			for _, sc := range scores {
				if sc.CreatedAt.Truncate(24 * time.Hour).Equal(today) {
					todayTotal += sc.PronunciationScore
					todayCount++
				}
			}
			if todayCount > 0 {
				avgPronScore = todayTotal / float64(todayCount)
			}
		}
	}

	progress := &DailyProgress{
		KidID:            kidID,
		Date:             today,
		WordsLearned:     wordsLearned,
		WordsReviewed:    wordsReviewed,
		AvgPronScore:     avgPronScore,
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
			progress.AvgPronScore = (existing.AvgPronScore + avgPronScore) / 2
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
	if s.pronRepo == nil {
		// No pronunciation repo available, return empty progress
		return &PronunciationProgress{
			TotalAttempts: 0,
			AvgScore:      0,
			BestScore:     0,
			CommonErrors:  []L1ErrorCount{},
			Trend:         "flat",
		}, nil
	}

	// Fetch recent pronunciation scores (up to 50 for analysis)
	scores, err := s.pronRepo.GetScoresByKid(ctx, kidID, 50)
	if err != nil {
		return nil, common.ErrInternal("failed to get pronunciation scores")
	}

	pp := &PronunciationProgress{
		TotalAttempts: len(scores),
		CommonErrors:  []L1ErrorCount{},
		Trend:         "flat",
	}

	if len(scores) == 0 {
		return pp, nil
	}

	// Calculate average and best scores
	var totalScore float64
	bestScore := 0.0
	for _, sc := range scores {
		totalScore += sc.PronunciationScore
		if sc.PronunciationScore > bestScore {
			bestScore = sc.PronunciationScore
		}
	}
	pp.AvgScore = totalScore / float64(len(scores))
	pp.BestScore = bestScore

	// Aggregate L1 error types
	errorCounts := make(map[string]int)
	for _, sc := range scores {
		// L1Errors may be populated from the stored JSON
		for _, l1err := range sc.L1Errors {
			errorCounts[string(l1err.Type)]++
		}
	}

	// Convert to sorted slice (most common first)
	for errType, count := range errorCounts {
		pp.CommonErrors = append(pp.CommonErrors, L1ErrorCount{
			ErrorType: errType,
			Count:     count,
		})
	}
	sort.Slice(pp.CommonErrors, func(i, j int) bool {
		return pp.CommonErrors[i].Count > pp.CommonErrors[j].Count
	})

	// Calculate trend based on last 5 vs previous 5 scores
	// Scores are ordered DESC by created_at, so index 0 is most recent
	pp.Trend = calculatePronunciationTrend(scores)

	return pp, nil
}

// calculatePronunciationTrend compares the average of the last 5 scores vs the previous 5.
// Scores are assumed to be ordered most-recent-first (DESC by created_at).
func calculatePronunciationTrend(scores []*pronunciation.PronunciationScore) string {
	if len(scores) < 5 {
		return "flat" // not enough data
	}

	// Recent 5 scores (indices 0..4)
	recentCount := 5
	if recentCount > len(scores) {
		recentCount = len(scores)
	}
	var recentTotal float64
	for i := 0; i < recentCount; i++ {
		recentTotal += scores[i].PronunciationScore
	}
	recentAvg := recentTotal / float64(recentCount)

	// Previous 5 scores (indices 5..9)
	prevStart := recentCount
	prevEnd := prevStart + 5
	if prevEnd > len(scores) {
		prevEnd = len(scores)
	}
	prevCount := prevEnd - prevStart
	if prevCount == 0 {
		return "flat"
	}

	var prevTotal float64
	for i := prevStart; i < prevEnd; i++ {
		prevTotal += scores[i].PronunciationScore
	}
	prevAvg := prevTotal / float64(prevCount)

	// Determine trend with a threshold of 3 points
	diff := recentAvg - prevAvg
	switch {
	case diff > 3:
		return "improving"
	case diff < -3:
		return "declining"
	default:
		return "flat"
	}
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

