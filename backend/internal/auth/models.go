package auth

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Parent struct {
	ID           uuid.UUID `json:"id"`
	Email        *string   `json:"email,omitempty"`
	Phone        *string   `json:"phone,omitempty"`
	PasswordHash string    `json:"-"`
	IsGuest      bool      `json:"is_guest"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type RegisterRequest struct {
	Email    string `json:"email" validate:"required,min=3"`
	Phone    string `json:"phone"`
	Password string `json:"password" validate:"required,min=6"`
}

type LoginRequest struct {
	EmailOrPhone string `json:"email_or_phone"`
	Email        string `json:"email"`
	Phone        string `json:"phone"`
	Password     string `json:"password" validate:"required"`
}

type LinkAccountRequest struct {
	Email    string `json:"email" validate:"required,min=3"`
	Phone    string `json:"phone"`
	Password string `json:"password" validate:"required,min=6"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

type AuthTokensResponse struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type TokenClaims struct {
	jwt.RegisteredClaims
	ParentID uuid.UUID  `json:"parent_id"`
	KidID    *uuid.UUID `json:"kid_id,omitempty"`
}
