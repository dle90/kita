package session

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type SessionRepository interface {
	CreateKidSession(ctx context.Context, session *KidSession) error
	GetKidSessions(ctx context.Context, kidID uuid.UUID) ([]*KidSession, error)
	GetKidSession(ctx context.Context, kidID uuid.UUID, dayNumber int) (*KidSession, error)
	GetKidSessionByID(ctx context.Context, sessionID uuid.UUID) (*KidSession, error)
	StartSession(ctx context.Context, sessionID uuid.UUID) error
	CompleteSession(ctx context.Context, sessionID uuid.UUID, totalStars int, accuracyPct float64) error
}

type ActivityResultRepository interface {
	SaveResult(ctx context.Context, result *ActivityResult) error
	GetResults(ctx context.Context, sessionID uuid.UUID) ([]*ActivityResult, error)
}

type pgSessionRepository struct {
	pool *pgxpool.Pool
}

func NewSessionRepository(pool *pgxpool.Pool) SessionRepository {
	return &pgSessionRepository{pool: pool}
}

func (r *pgSessionRepository) CreateKidSession(ctx context.Context, session *KidSession) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO kid_sessions (id, kid_id, day_number, total_stars, accuracy_pct, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (kid_id, day_number) DO NOTHING`,
		session.ID, session.KidID, session.DayNumber, session.TotalStars, session.AccuracyPct, session.CreatedAt,
	)
	return err
}

func (r *pgSessionRepository) GetKidSessions(ctx context.Context, kidID uuid.UUID) ([]*KidSession, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, day_number, started_at, completed_at, total_stars, accuracy_pct, created_at
		 FROM kid_sessions WHERE kid_id = $1 ORDER BY day_number`, kidID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []*KidSession
	for rows.Next() {
		s := &KidSession{}
		if err := rows.Scan(&s.ID, &s.KidID, &s.DayNumber, &s.StartedAt, &s.CompletedAt, &s.TotalStars, &s.AccuracyPct, &s.CreatedAt); err != nil {
			return nil, err
		}
		sessions = append(sessions, s)
	}
	return sessions, nil
}

func (r *pgSessionRepository) GetKidSession(ctx context.Context, kidID uuid.UUID, dayNumber int) (*KidSession, error) {
	s := &KidSession{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, kid_id, day_number, started_at, completed_at, total_stars, accuracy_pct, created_at
		 FROM kid_sessions WHERE kid_id = $1 AND day_number = $2`, kidID, dayNumber,
	).Scan(&s.ID, &s.KidID, &s.DayNumber, &s.StartedAt, &s.CompletedAt, &s.TotalStars, &s.AccuracyPct, &s.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return s, nil
}

func (r *pgSessionRepository) GetKidSessionByID(ctx context.Context, sessionID uuid.UUID) (*KidSession, error) {
	s := &KidSession{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, kid_id, day_number, started_at, completed_at, total_stars, accuracy_pct, created_at
		 FROM kid_sessions WHERE id = $1`, sessionID,
	).Scan(&s.ID, &s.KidID, &s.DayNumber, &s.StartedAt, &s.CompletedAt, &s.TotalStars, &s.AccuracyPct, &s.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return s, nil
}

func (r *pgSessionRepository) StartSession(ctx context.Context, sessionID uuid.UUID) error {
	now := time.Now()
	_, err := r.pool.Exec(ctx,
		`UPDATE kid_sessions SET started_at = $1 WHERE id = $2 AND started_at IS NULL`,
		now, sessionID,
	)
	return err
}

func (r *pgSessionRepository) CompleteSession(ctx context.Context, sessionID uuid.UUID, totalStars int, accuracyPct float64) error {
	now := time.Now()
	_, err := r.pool.Exec(ctx,
		`UPDATE kid_sessions SET completed_at = $1, total_stars = $2, accuracy_pct = $3 WHERE id = $4`,
		now, totalStars, accuracyPct, sessionID,
	)
	return err
}

// Activity result repository

type pgActivityResultRepository struct {
	pool *pgxpool.Pool
}

func NewActivityResultRepository(pool *pgxpool.Pool) ActivityResultRepository {
	return &pgActivityResultRepository{pool: pool}
}

func (r *pgActivityResultRepository) SaveResult(ctx context.Context, result *ActivityResult) error {
	metadataJSON, _ := json.Marshal(result.Metadata)
	if result.Metadata == nil {
		metadataJSON = []byte("{}")
	}
	_, err := r.pool.Exec(ctx,
		`INSERT INTO activity_results (id, session_id, kid_id, activity_type, vocabulary_id, is_correct, attempts, time_spent_ms, stars_earned, metadata, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
		result.ID, result.SessionID, result.KidID, result.ActivityType, result.VocabularyID,
		result.IsCorrect, result.Attempts, result.TimeSpentMs, result.StarsEarned,
		metadataJSON, result.CreatedAt,
	)
	return err
}

func (r *pgActivityResultRepository) GetResults(ctx context.Context, sessionID uuid.UUID) ([]*ActivityResult, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, session_id, kid_id, activity_type, vocabulary_id, is_correct, attempts, time_spent_ms, stars_earned, metadata, created_at
		 FROM activity_results WHERE session_id = $1 ORDER BY created_at`, sessionID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []*ActivityResult
	for rows.Next() {
		ar := &ActivityResult{}
		if err := rows.Scan(&ar.ID, &ar.SessionID, &ar.KidID, &ar.ActivityType, &ar.VocabularyID,
			&ar.IsCorrect, &ar.Attempts, &ar.TimeSpentMs, &ar.StarsEarned, &ar.Metadata, &ar.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, ar)
	}
	return results, nil
}
