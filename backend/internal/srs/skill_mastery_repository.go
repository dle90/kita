package srs

import (
	"context"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SkillMasteryRepository manages per-skill mastery tracking for words.
type SkillMasteryRepository interface {
	GetOrCreateMastery(ctx context.Context, kidID, vocabID uuid.UUID) (*WordSkillMastery, error)
	UpdateSkillScore(ctx context.Context, kidID, vocabID uuid.UUID, skill SkillType, score float64) error
	GetWeakestSkillWords(ctx context.Context, kidID uuid.UUID, limit int) ([]*WordSkillMastery, error)
	GetMasteryForWords(ctx context.Context, kidID uuid.UUID, vocabIDs []uuid.UUID) ([]*WordSkillMastery, error)
	GetSkillSummary(ctx context.Context, kidID uuid.UUID) (map[SkillType]float64, error)
	GetMasteredCount(ctx context.Context, kidID uuid.UUID) (mastered int, inProgress int, err error)
}

type pgSkillMasteryRepository struct {
	pool *pgxpool.Pool
}

// NewSkillMasteryRepository creates a new skill mastery repository backed by Postgres.
func NewSkillMasteryRepository(pool *pgxpool.Pool) SkillMasteryRepository {
	return &pgSkillMasteryRepository{pool: pool}
}

func (r *pgSkillMasteryRepository) GetOrCreateMastery(ctx context.Context, kidID, vocabID uuid.UUID) (*WordSkillMastery, error) {
	now := time.Now()
	m := &WordSkillMastery{}
	err := r.pool.QueryRow(ctx,
		`INSERT INTO word_skill_mastery (id, kid_id, vocabulary_id, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5)
		 ON CONFLICT (kid_id, vocabulary_id) DO UPDATE SET updated_at = word_skill_mastery.updated_at
		 RETURNING id, kid_id, vocabulary_id,
		   listening_score, listening_attempts,
		   speaking_score, speaking_attempts,
		   reading_score, reading_attempts,
		   writing_score, writing_attempts,
		   overall_mastery, last_seen, created_at, updated_at`,
		uuid.New(), kidID, vocabID, now, now,
	).Scan(
		&m.ID, &m.KidID, &m.VocabularyID,
		&m.ListeningScore, &m.ListeningAttempts,
		&m.SpeakingScore, &m.SpeakingAttempts,
		&m.ReadingScore, &m.ReadingAttempts,
		&m.WritingScore, &m.WritingAttempts,
		&m.OverallMastery, &m.LastSeen, &m.CreatedAt, &m.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return m, nil
}

func (r *pgSkillMasteryRepository) UpdateSkillScore(ctx context.Context, kidID, vocabID uuid.UUID, skill SkillType, score float64) error {
	now := time.Now()

	// Clamp score to 0-100
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}

	// Determine the column names based on skill
	var scoreCol, attemptsCol string
	switch skill {
	case SkillListening:
		scoreCol = "listening_score"
		attemptsCol = "listening_attempts"
	case SkillSpeaking:
		scoreCol = "speaking_score"
		attemptsCol = "speaking_attempts"
	case SkillReading:
		scoreCol = "reading_score"
		attemptsCol = "reading_attempts"
	case SkillWriting:
		scoreCol = "writing_score"
		attemptsCol = "writing_attempts"
	default:
		scoreCol = "listening_score"
		attemptsCol = "listening_attempts"
	}

	// Use a single upsert that calculates the running average in SQL.
	// new_score = (old_score * attempts + $score) / (attempts + 1)
	// Then recalculate overall_mastery = LEAST(listening, speaking, reading, writing)
	query := `
		INSERT INTO word_skill_mastery (id, kid_id, vocabulary_id, ` + scoreCol + `, ` + attemptsCol + `, last_seen, created_at, updated_at)
		VALUES ($1, $2, $3, $4, 1, $5, $5, $5)
		ON CONFLICT (kid_id, vocabulary_id) DO UPDATE SET
			` + scoreCol + ` = (word_skill_mastery.` + scoreCol + ` * word_skill_mastery.` + attemptsCol + ` + $4) / (word_skill_mastery.` + attemptsCol + ` + 1),
			` + attemptsCol + ` = word_skill_mastery.` + attemptsCol + ` + 1,
			last_seen = $5,
			updated_at = $5,
			overall_mastery = LEAST(
				CASE WHEN '` + string(skill) + `' = 'listening' THEN (word_skill_mastery.listening_score * word_skill_mastery.listening_attempts + $4) / (word_skill_mastery.listening_attempts + 1) ELSE word_skill_mastery.listening_score END,
				CASE WHEN '` + string(skill) + `' = 'speaking' THEN (word_skill_mastery.speaking_score * word_skill_mastery.speaking_attempts + $4) / (word_skill_mastery.speaking_attempts + 1) ELSE word_skill_mastery.speaking_score END,
				CASE WHEN '` + string(skill) + `' = 'reading' THEN (word_skill_mastery.reading_score * word_skill_mastery.reading_attempts + $4) / (word_skill_mastery.reading_attempts + 1) ELSE word_skill_mastery.reading_score END,
				CASE WHEN '` + string(skill) + `' = 'writing' THEN (word_skill_mastery.writing_score * word_skill_mastery.writing_attempts + $4) / (word_skill_mastery.writing_attempts + 1) ELSE word_skill_mastery.writing_score END
			)`

	_, err := r.pool.Exec(ctx, query, uuid.New(), kidID, vocabID, score, now)
	return err
}

func (r *pgSkillMasteryRepository) GetWeakestSkillWords(ctx context.Context, kidID uuid.UUID, limit int) ([]*WordSkillMastery, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, vocabulary_id,
			listening_score, listening_attempts,
			speaking_score, speaking_attempts,
			reading_score, reading_attempts,
			writing_score, writing_attempts,
			overall_mastery, last_seen, created_at, updated_at
		 FROM word_skill_mastery
		 WHERE kid_id = $1 AND (listening_attempts + speaking_attempts + reading_attempts + writing_attempts) > 0
		 ORDER BY overall_mastery ASC
		 LIMIT $2`, kidID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanSkillMasteries(rows)
}

func (r *pgSkillMasteryRepository) GetMasteryForWords(ctx context.Context, kidID uuid.UUID, vocabIDs []uuid.UUID) ([]*WordSkillMastery, error) {
	if len(vocabIDs) == 0 {
		return nil, nil
	}

	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, vocabulary_id,
			listening_score, listening_attempts,
			speaking_score, speaking_attempts,
			reading_score, reading_attempts,
			writing_score, writing_attempts,
			overall_mastery, last_seen, created_at, updated_at
		 FROM word_skill_mastery
		 WHERE kid_id = $1 AND vocabulary_id = ANY($2)`, kidID, vocabIDs,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanSkillMasteries(rows)
}

func (r *pgSkillMasteryRepository) GetSkillSummary(ctx context.Context, kidID uuid.UUID) (map[SkillType]float64, error) {
	summary := map[SkillType]float64{
		SkillListening: 0,
		SkillSpeaking:  0,
		SkillReading:   0,
		SkillWriting:   0,
	}

	row := r.pool.QueryRow(ctx,
		`SELECT
			COALESCE(AVG(CASE WHEN listening_attempts > 0 THEN listening_score END), 0),
			COALESCE(AVG(CASE WHEN speaking_attempts > 0 THEN speaking_score END), 0),
			COALESCE(AVG(CASE WHEN reading_attempts > 0 THEN reading_score END), 0),
			COALESCE(AVG(CASE WHEN writing_attempts > 0 THEN writing_score END), 0)
		 FROM word_skill_mastery
		 WHERE kid_id = $1`, kidID,
	)

	var listening, speaking, reading, writing float64
	if err := row.Scan(&listening, &speaking, &reading, &writing); err != nil {
		return summary, nil // return zeros on error
	}

	summary[SkillListening] = math.Round(listening*10) / 10
	summary[SkillSpeaking] = math.Round(speaking*10) / 10
	summary[SkillReading] = math.Round(reading*10) / 10
	summary[SkillWriting] = math.Round(writing*10) / 10

	return summary, nil
}

func (r *pgSkillMasteryRepository) GetMasteredCount(ctx context.Context, kidID uuid.UUID) (mastered int, inProgress int, err error) {
	row := r.pool.QueryRow(ctx,
		`SELECT
			COUNT(*) FILTER (WHERE overall_mastery >= 80),
			COUNT(*) FILTER (WHERE overall_mastery < 80 AND (listening_attempts + speaking_attempts + reading_attempts + writing_attempts) > 0)
		 FROM word_skill_mastery
		 WHERE kid_id = $1`, kidID,
	)
	if err := row.Scan(&mastered, &inProgress); err != nil {
		return 0, 0, err
	}
	return mastered, inProgress, nil
}

func scanSkillMasteries(rows pgx.Rows) ([]*WordSkillMastery, error) {
	var result []*WordSkillMastery
	for rows.Next() {
		m := &WordSkillMastery{}
		if err := rows.Scan(
			&m.ID, &m.KidID, &m.VocabularyID,
			&m.ListeningScore, &m.ListeningAttempts,
			&m.SpeakingScore, &m.SpeakingAttempts,
			&m.ReadingScore, &m.ReadingAttempts,
			&m.WritingScore, &m.WritingAttempts,
			&m.OverallMastery, &m.LastSeen, &m.CreatedAt, &m.UpdatedAt,
		); err != nil {
			return nil, err
		}
		result = append(result, m)
	}
	return result, nil
}
