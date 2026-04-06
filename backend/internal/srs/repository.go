package srs

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type SrsRepository interface {
	CreateCard(ctx context.Context, card *SrsCard) error
	GetDueCards(ctx context.Context, kidID uuid.UUID, date time.Time) ([]*SrsCard, error)
	UpdateCard(ctx context.Context, card *SrsCard) error
	GetCardsByKid(ctx context.Context, kidID uuid.UUID) ([]*SrsCard, error)
	GetCardByID(ctx context.Context, cardID uuid.UUID) (*SrsCard, error)
}

type pgSrsRepository struct {
	pool *pgxpool.Pool
}

func NewSrsRepository(pool *pgxpool.Pool) SrsRepository {
	return &pgSrsRepository{pool: pool}
}

func (r *pgSrsRepository) CreateCard(ctx context.Context, card *SrsCard) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO srs_cards (id, kid_id, vocabulary_id, repetitions, ease_factor, interval_days, next_review_date, last_review_date, last_quality, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		 ON CONFLICT (kid_id, vocabulary_id) DO NOTHING`,
		card.ID, card.KidID, card.VocabularyID, card.Repetitions, card.EaseFactor,
		card.IntervalDays, card.NextReviewDate, card.LastReviewDate, card.LastQuality,
		card.CreatedAt, card.UpdatedAt,
	)
	return err
}

func (r *pgSrsRepository) GetDueCards(ctx context.Context, kidID uuid.UUID, date time.Time) ([]*SrsCard, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, vocabulary_id, repetitions, ease_factor, interval_days, next_review_date, last_review_date, last_quality, created_at, updated_at
		 FROM srs_cards WHERE kid_id = $1 AND next_review_date <= $2 ORDER BY next_review_date`, kidID, date,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanSrsCards(rows)
}

func (r *pgSrsRepository) UpdateCard(ctx context.Context, card *SrsCard) error {
	card.UpdatedAt = time.Now()
	_, err := r.pool.Exec(ctx,
		`UPDATE srs_cards SET repetitions=$1, ease_factor=$2, interval_days=$3, next_review_date=$4, last_review_date=$5, last_quality=$6, updated_at=$7
		 WHERE id=$8`,
		card.Repetitions, card.EaseFactor, card.IntervalDays, card.NextReviewDate,
		card.LastReviewDate, card.LastQuality, card.UpdatedAt, card.ID,
	)
	return err
}

func (r *pgSrsRepository) GetCardsByKid(ctx context.Context, kidID uuid.UUID) ([]*SrsCard, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, kid_id, vocabulary_id, repetitions, ease_factor, interval_days, next_review_date, last_review_date, last_quality, created_at, updated_at
		 FROM srs_cards WHERE kid_id = $1 ORDER BY next_review_date`, kidID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanSrsCards(rows)
}

func (r *pgSrsRepository) GetCardByID(ctx context.Context, cardID uuid.UUID) (*SrsCard, error) {
	card := &SrsCard{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, kid_id, vocabulary_id, repetitions, ease_factor, interval_days, next_review_date, last_review_date, last_quality, created_at, updated_at
		 FROM srs_cards WHERE id = $1`, cardID,
	).Scan(&card.ID, &card.KidID, &card.VocabularyID, &card.Repetitions, &card.EaseFactor,
		&card.IntervalDays, &card.NextReviewDate, &card.LastReviewDate, &card.LastQuality,
		&card.CreatedAt, &card.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return card, nil
}

func scanSrsCards(rows pgx.Rows) ([]*SrsCard, error) {
	var cards []*SrsCard
	for rows.Next() {
		c := &SrsCard{}
		if err := rows.Scan(&c.ID, &c.KidID, &c.VocabularyID, &c.Repetitions, &c.EaseFactor,
			&c.IntervalDays, &c.NextReviewDate, &c.LastReviewDate, &c.LastQuality,
			&c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		cards = append(cards, c)
	}
	return cards, nil
}
