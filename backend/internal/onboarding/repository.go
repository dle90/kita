package onboarding

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type KidRepository interface {
	CreateKid(ctx context.Context, kid *Kid) error
	GetKid(ctx context.Context, kidID uuid.UUID) (*Kid, error)
	UpdateKid(ctx context.Context, kid *Kid) error
	GetKidsByParent(ctx context.Context, parentID uuid.UUID) ([]*Kid, error)
	UpdatePlacement(ctx context.Context, kidID uuid.UUID, level string) error
}

type pgKidRepository struct {
	pool *pgxpool.Pool
}

func NewKidRepository(pool *pgxpool.Pool) KidRepository {
	return &pgKidRepository{pool: pool}
}

func (r *pgKidRepository) CreateKid(ctx context.Context, kid *Kid) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO kids (id, parent_id, display_name, character_id, age, dialect, english_level, notification_time, placement_done, current_day, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		kid.ID, kid.ParentID, kid.DisplayName, kid.CharacterID, kid.Age,
		kid.Dialect, kid.EnglishLevel, kid.NotificationTime, kid.PlacementDone,
		kid.CurrentDay, kid.CreatedAt, kid.UpdatedAt,
	)
	return err
}

func (r *pgKidRepository) GetKid(ctx context.Context, kidID uuid.UUID) (*Kid, error) {
	kid := &Kid{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, parent_id, display_name, character_id, age, dialect, english_level, notification_time, placement_done, current_day, created_at, updated_at
		 FROM kids WHERE id = $1`, kidID,
	).Scan(&kid.ID, &kid.ParentID, &kid.DisplayName, &kid.CharacterID, &kid.Age,
		&kid.Dialect, &kid.EnglishLevel, &kid.NotificationTime, &kid.PlacementDone,
		&kid.CurrentDay, &kid.CreatedAt, &kid.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return kid, nil
}

func (r *pgKidRepository) UpdateKid(ctx context.Context, kid *Kid) error {
	kid.UpdatedAt = time.Now()
	_, err := r.pool.Exec(ctx,
		`UPDATE kids SET display_name=$1, character_id=$2, dialect=$3, english_level=$4, notification_time=$5, updated_at=$6
		 WHERE id=$7`,
		kid.DisplayName, kid.CharacterID, kid.Dialect, kid.EnglishLevel,
		kid.NotificationTime, kid.UpdatedAt, kid.ID,
	)
	return err
}

func (r *pgKidRepository) GetKidsByParent(ctx context.Context, parentID uuid.UUID) ([]*Kid, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, parent_id, display_name, character_id, age, dialect, english_level, notification_time, placement_done, current_day, created_at, updated_at
		 FROM kids WHERE parent_id = $1 ORDER BY created_at`, parentID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var kids []*Kid
	for rows.Next() {
		kid := &Kid{}
		if err := rows.Scan(&kid.ID, &kid.ParentID, &kid.DisplayName, &kid.CharacterID, &kid.Age,
			&kid.Dialect, &kid.EnglishLevel, &kid.NotificationTime, &kid.PlacementDone,
			&kid.CurrentDay, &kid.CreatedAt, &kid.UpdatedAt); err != nil {
			return nil, err
		}
		kids = append(kids, kid)
	}
	return kids, nil
}

func (r *pgKidRepository) UpdatePlacement(ctx context.Context, kidID uuid.UUID, level string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE kids SET placement_done = true, english_level = $1, updated_at = $2 WHERE id = $3`,
		level, time.Now(), kidID,
	)
	return err
}
