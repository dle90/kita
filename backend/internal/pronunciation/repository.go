package pronunciation

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PronunciationRepository interface {
	SaveScore(ctx context.Context, score *PronunciationScore) error
	GetScoresByKid(ctx context.Context, kidID uuid.UUID, limit int) ([]*PronunciationScore, error)
}

type pgPronunciationRepository struct {
	pool *pgxpool.Pool
}

func NewPronunciationRepository(pool *pgxpool.Pool) PronunciationRepository {
	return &pgPronunciationRepository{pool: pool}
}

func (r *pgPronunciationRepository) SaveScore(ctx context.Context, score *PronunciationScore) error {
	phonemesJSON, _ := json.Marshal(score.Phonemes)
	l1ErrorsJSON, _ := json.Marshal(score.L1Errors)

	_, err := r.pool.Exec(ctx,
		`INSERT INTO pronunciation_scores (id, kid_id, vocabulary_id, reference_text, audio_url, accuracy_score, fluency_score, completeness_score, pronunciation_score, phonemes, l1_errors, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		score.ID, score.KidID, score.VocabularyID, score.ReferenceText, score.AudioURL,
		score.AccuracyScore, score.FluencyScore, score.CompletenessScore, score.PronunciationScore,
		phonemesJSON, l1ErrorsJSON, score.CreatedAt,
	)
	return err
}

func (r *pgPronunciationRepository) GetScoresByKid(ctx context.Context, kidID uuid.UUID, limit int) ([]*PronunciationScore, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, vocabulary_id, reference_text, audio_url, accuracy_score, fluency_score, completeness_score, pronunciation_score, phonemes, l1_errors, created_at
		 FROM pronunciation_scores WHERE kid_id = $1 ORDER BY created_at DESC LIMIT $2`, kidID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var scores []*PronunciationScore
	for rows.Next() {
		s := &PronunciationScore{}
		var phonemesJSON, l1ErrorsJSON []byte
		if err := rows.Scan(&s.ID, &s.KidID, &s.VocabularyID, &s.ReferenceText, &s.AudioURL,
			&s.AccuracyScore, &s.FluencyScore, &s.CompletenessScore, &s.PronunciationScore,
			&phonemesJSON, &l1ErrorsJSON, &s.CreatedAt); err != nil {
			return nil, err
		}
		json.Unmarshal(phonemesJSON, &s.Phonemes)
		json.Unmarshal(l1ErrorsJSON, &s.L1Errors)
		scores = append(scores, s)
	}
	return scores, nil
}

// Helper to get average pronunciation score for a kid (for progress tracking)
func (r *pgPronunciationRepository) GetAverageScore(ctx context.Context, kidID uuid.UUID, since time.Time) (float64, error) {
	var avg float64
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(AVG(pronunciation_score), 0) FROM pronunciation_scores WHERE kid_id = $1 AND created_at >= $2`,
		kidID, since,
	).Scan(&avg)
	return avg, err
}
