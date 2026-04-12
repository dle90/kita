package curriculum

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// KidGrammarExposure tracks how many times a kid has encountered a grammar structure.
type KidGrammarExposure struct {
	ID                 uuid.UUID `json:"id"`
	KidID              uuid.UUID `json:"kid_id"`
	GrammarStructureID string    `json:"grammar_structure_id"`
	ExposureCount      int       `json:"exposure_count"`
	FirstSeen          time.Time `json:"first_seen"`
	LastSeen           time.Time `json:"last_seen"`
}

// Repository manages kid grammar exposure records.
type Repository interface {
	GetExposures(ctx context.Context, kidID uuid.UUID) ([]*KidGrammarExposure, error)
	RecordExposure(ctx context.Context, kidID uuid.UUID, grammarStructureID string) error
}

type pgRepository struct {
	pool *pgxpool.Pool
}

// NewRepository creates a new curriculum repository backed by Postgres.
func NewRepository(pool *pgxpool.Pool) Repository {
	return &pgRepository{pool: pool}
}

func (r *pgRepository) GetExposures(ctx context.Context, kidID uuid.UUID) ([]*KidGrammarExposure, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, grammar_structure_id, exposure_count, first_seen, last_seen
		 FROM kid_grammar_exposure
		 WHERE kid_id = $1
		 ORDER BY last_seen DESC`, kidID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*KidGrammarExposure
	for rows.Next() {
		e := &KidGrammarExposure{}
		if err := rows.Scan(&e.ID, &e.KidID, &e.GrammarStructureID, &e.ExposureCount, &e.FirstSeen, &e.LastSeen); err != nil {
			return nil, err
		}
		result = append(result, e)
	}
	return result, nil
}

func (r *pgRepository) RecordExposure(ctx context.Context, kidID uuid.UUID, grammarStructureID string) error {
	now := time.Now()
	_, err := r.pool.Exec(ctx,
		`INSERT INTO kid_grammar_exposure (kid_id, grammar_structure_id, exposure_count, first_seen, last_seen)
		 VALUES ($1, $2, 1, $3, $3)
		 ON CONFLICT (kid_id, grammar_structure_id) DO UPDATE SET
		   exposure_count = kid_grammar_exposure.exposure_count + 1,
		   last_seen = $3`,
		kidID, grammarStructureID, now,
	)
	return err
}
