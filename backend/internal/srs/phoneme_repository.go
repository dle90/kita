package srs

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// KidPhonemeMastery tracks a kid's mastery of a specific phoneme.
type KidPhonemeMastery struct {
	ID                uuid.UUID  `json:"id"`
	KidID             uuid.UUID  `json:"kid_id"`
	PhonemeID         string     `json:"phoneme_id"`
	PerceptionScore   float64    `json:"perception_score"`
	PerceptionAttempts int       `json:"perception_attempts"`
	ProductionScore   float64    `json:"production_score"`
	ProductionAttempts int       `json:"production_attempts"`
	LastSeen          *time.Time `json:"last_seen,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

// PhonemeMasteryRepository manages kid phoneme mastery records.
type PhonemeMasteryRepository interface {
	UpdatePhonemeMastery(ctx context.Context, kidID uuid.UUID, phonemeID string, isPerception bool, score float64) error
	GetWeakestPhonemes(ctx context.Context, kidID uuid.UUID, limit int) ([]*KidPhonemeMastery, error)
	GetPhonemeMastery(ctx context.Context, kidID uuid.UUID) ([]*KidPhonemeMastery, error)
}

type pgPhonemeMasteryRepository struct {
	pool *pgxpool.Pool
}

// NewPhonemeMasteryRepository creates a new phoneme mastery repository.
func NewPhonemeMasteryRepository(pool *pgxpool.Pool) PhonemeMasteryRepository {
	return &pgPhonemeMasteryRepository{pool: pool}
}

func (r *pgPhonemeMasteryRepository) UpdatePhonemeMastery(ctx context.Context, kidID uuid.UUID, phonemeID string, isPerception bool, score float64) error {
	now := time.Now()
	if isPerception {
		_, err := r.pool.Exec(ctx,
			`INSERT INTO kid_phoneme_mastery (kid_id, phoneme_id, perception_score, perception_attempts, last_seen, updated_at)
			 VALUES ($1, $2, $3, 1, $4, $4)
			 ON CONFLICT (kid_id, phoneme_id) DO UPDATE SET
			   perception_score = (kid_phoneme_mastery.perception_score * kid_phoneme_mastery.perception_attempts + $3) / (kid_phoneme_mastery.perception_attempts + 1),
			   perception_attempts = kid_phoneme_mastery.perception_attempts + 1,
			   last_seen = $4,
			   updated_at = $4`,
			kidID, phonemeID, score, now,
		)
		return err
	}

	_, err := r.pool.Exec(ctx,
		`INSERT INTO kid_phoneme_mastery (kid_id, phoneme_id, production_score, production_attempts, last_seen, updated_at)
		 VALUES ($1, $2, $3, 1, $4, $4)
		 ON CONFLICT (kid_id, phoneme_id) DO UPDATE SET
		   production_score = (kid_phoneme_mastery.production_score * kid_phoneme_mastery.production_attempts + $3) / (kid_phoneme_mastery.production_attempts + 1),
		   production_attempts = kid_phoneme_mastery.production_attempts + 1,
		   last_seen = $4,
		   updated_at = $4`,
		kidID, phonemeID, score, now,
	)
	return err
}

func (r *pgPhonemeMasteryRepository) GetWeakestPhonemes(ctx context.Context, kidID uuid.UUID, limit int) ([]*KidPhonemeMastery, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, phoneme_id, perception_score, perception_attempts, production_score, production_attempts, last_seen, created_at, updated_at
		 FROM kid_phoneme_mastery
		 WHERE kid_id = $1
		 ORDER BY (perception_score + production_score) / 2.0 ASC, updated_at ASC
		 LIMIT $2`, kidID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanPhonemeMastery(rows)
}

func (r *pgPhonemeMasteryRepository) GetPhonemeMastery(ctx context.Context, kidID uuid.UUID) ([]*KidPhonemeMastery, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, phoneme_id, perception_score, perception_attempts, production_score, production_attempts, last_seen, created_at, updated_at
		 FROM kid_phoneme_mastery
		 WHERE kid_id = $1
		 ORDER BY phoneme_id`, kidID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanPhonemeMastery(rows)
}

func scanPhonemeMastery(rows interface {
	Next() bool
	Scan(dest ...interface{}) error
}) ([]*KidPhonemeMastery, error) {
	var result []*KidPhonemeMastery
	for rows.Next() {
		m := &KidPhonemeMastery{}
		if err := rows.Scan(&m.ID, &m.KidID, &m.PhonemeID, &m.PerceptionScore, &m.PerceptionAttempts, &m.ProductionScore, &m.ProductionAttempts, &m.LastSeen, &m.CreatedAt, &m.UpdatedAt); err != nil {
			return nil, err
		}
		result = append(result, m)
	}
	return result, nil
}
