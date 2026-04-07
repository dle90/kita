package auth

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type AuthRepository interface {
	CreateParent(ctx context.Context, email, phone *string, passwordHash string) (*Parent, error)
	FindParentByEmail(ctx context.Context, email string) (*Parent, error)
	FindParentByPhone(ctx context.Context, phone string) (*Parent, error)
	FindParentByID(ctx context.Context, id uuid.UUID) (*Parent, error)
	UpdateParent(ctx context.Context, id uuid.UUID, email *string, phone *string, passwordHash string) error
	StoreRefreshToken(ctx context.Context, parentID uuid.UUID, tokenHash string, expiresAt time.Time) error
	ValidateRefreshToken(ctx context.Context, tokenHash string) (uuid.UUID, error)
	RevokeRefreshToken(ctx context.Context, tokenHash string) error
}

type pgAuthRepository struct {
	pool *pgxpool.Pool
}

func NewAuthRepository(pool *pgxpool.Pool) AuthRepository {
	return &pgAuthRepository{pool: pool}
}

func (r *pgAuthRepository) CreateParent(ctx context.Context, email, phone *string, passwordHash string) (*Parent, error) {
	parent := &Parent{
		ID:           uuid.New(),
		Email:        email,
		Phone:        phone,
		PasswordHash: passwordHash,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	_, err := r.pool.Exec(ctx,
		`INSERT INTO parents (id, email, phone, password_hash, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		parent.ID, parent.Email, parent.Phone, parent.PasswordHash, parent.CreatedAt, parent.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return parent, nil
}

func (r *pgAuthRepository) FindParentByEmail(ctx context.Context, email string) (*Parent, error) {
	parent := &Parent{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, email, phone, password_hash, created_at, updated_at
		 FROM parents WHERE email = $1`, email,
	).Scan(&parent.ID, &parent.Email, &parent.Phone, &parent.PasswordHash, &parent.CreatedAt, &parent.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return parent, nil
}

func (r *pgAuthRepository) FindParentByPhone(ctx context.Context, phone string) (*Parent, error) {
	parent := &Parent{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, email, phone, password_hash, created_at, updated_at
		 FROM parents WHERE phone = $1`, phone,
	).Scan(&parent.ID, &parent.Email, &parent.Phone, &parent.PasswordHash, &parent.CreatedAt, &parent.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return parent, nil
}

func (r *pgAuthRepository) FindParentByID(ctx context.Context, id uuid.UUID) (*Parent, error) {
	parent := &Parent{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, email, phone, password_hash, created_at, updated_at
		 FROM parents WHERE id = $1`, id,
	).Scan(&parent.ID, &parent.Email, &parent.Phone, &parent.PasswordHash, &parent.CreatedAt, &parent.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return parent, nil
}

func (r *pgAuthRepository) UpdateParent(ctx context.Context, id uuid.UUID, email *string, phone *string, passwordHash string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE parents SET email = $2, phone = $3, password_hash = $4, updated_at = $5 WHERE id = $1`,
		id, email, phone, passwordHash, time.Now(),
	)
	return err
}

func (r *pgAuthRepository) StoreRefreshToken(ctx context.Context, parentID uuid.UUID, tokenHash string, expiresAt time.Time) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO refresh_tokens (id, parent_id, token_hash, expires_at, created_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		uuid.New(), parentID, tokenHash, expiresAt, time.Now(),
	)
	return err
}

func (r *pgAuthRepository) ValidateRefreshToken(ctx context.Context, tokenHash string) (uuid.UUID, error) {
	var parentID uuid.UUID
	var expiresAt time.Time
	var revoked bool
	err := r.pool.QueryRow(ctx,
		`SELECT parent_id, expires_at, revoked FROM refresh_tokens WHERE token_hash = $1`, tokenHash,
	).Scan(&parentID, &expiresAt, &revoked)
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, errors.New("refresh token not found")
	}
	if err != nil {
		return uuid.Nil, err
	}
	if revoked {
		return uuid.Nil, errors.New("refresh token has been revoked")
	}
	if time.Now().After(expiresAt) {
		return uuid.Nil, errors.New("refresh token has expired")
	}
	return parentID, nil
}

func (r *pgAuthRepository) RevokeRefreshToken(ctx context.Context, tokenHash string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE refresh_tokens SET revoked = true WHERE token_hash = $1`, tokenHash,
	)
	return err
}
