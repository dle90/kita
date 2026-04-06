package progress

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ProgressRepository interface {
	UpsertDailyProgress(ctx context.Context, progress *DailyProgress) error
	GetDailyProgress(ctx context.Context, kidID uuid.UUID, date time.Time) (*DailyProgress, error)
	GetProgressRange(ctx context.Context, kidID uuid.UUID, from, to time.Time) ([]*DailyProgress, error)
}

type pgProgressRepository struct {
	pool *pgxpool.Pool
}

func NewProgressRepository(pool *pgxpool.Pool) ProgressRepository {
	return &pgProgressRepository{pool: pool}
}

func (r *pgProgressRepository) UpsertDailyProgress(ctx context.Context, progress *DailyProgress) error {
	now := time.Now()
	progress.UpdatedAt = now
	if progress.ID == uuid.Nil {
		progress.ID = uuid.New()
		progress.CreatedAt = now
	}

	_, err := r.pool.Exec(ctx,
		`INSERT INTO daily_progress (id, kid_id, date, words_learned, words_reviewed, avg_pron_score, session_completed, total_time_ms, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		 ON CONFLICT (kid_id, date) DO UPDATE SET
		   words_learned = EXCLUDED.words_learned,
		   words_reviewed = EXCLUDED.words_reviewed,
		   avg_pron_score = EXCLUDED.avg_pron_score,
		   session_completed = EXCLUDED.session_completed,
		   total_time_ms = EXCLUDED.total_time_ms,
		   updated_at = EXCLUDED.updated_at`,
		progress.ID, progress.KidID, progress.Date, progress.WordsLearned, progress.WordsReviewed,
		progress.AvgPronScore, progress.SessionCompleted, progress.TotalTimeMs,
		progress.CreatedAt, progress.UpdatedAt,
	)
	return err
}

func (r *pgProgressRepository) GetDailyProgress(ctx context.Context, kidID uuid.UUID, date time.Time) (*DailyProgress, error) {
	p := &DailyProgress{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, kid_id, date, words_learned, words_reviewed, avg_pron_score, session_completed, total_time_ms, created_at, updated_at
		 FROM daily_progress WHERE kid_id = $1 AND date = $2`, kidID, date,
	).Scan(&p.ID, &p.KidID, &p.Date, &p.WordsLearned, &p.WordsReviewed,
		&p.AvgPronScore, &p.SessionCompleted, &p.TotalTimeMs, &p.CreatedAt, &p.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return p, nil
}

func (r *pgProgressRepository) GetProgressRange(ctx context.Context, kidID uuid.UUID, from, to time.Time) ([]*DailyProgress, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, date, words_learned, words_reviewed, avg_pron_score, session_completed, total_time_ms, created_at, updated_at
		 FROM daily_progress WHERE kid_id = $1 AND date >= $2 AND date <= $3 ORDER BY date`, kidID, from, to,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*DailyProgress
	for rows.Next() {
		p := &DailyProgress{}
		if err := rows.Scan(&p.ID, &p.KidID, &p.Date, &p.WordsLearned, &p.WordsReviewed,
			&p.AvgPronScore, &p.SessionCompleted, &p.TotalTimeMs, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		result = append(result, p)
	}
	return result, nil
}
