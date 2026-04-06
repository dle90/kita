package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/config"
	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	repo   AuthRepository
	jwtCfg config.JWTConfig
}

func NewAuthService(repo AuthRepository, jwtCfg config.JWTConfig) *AuthService {
	return &AuthService{repo: repo, jwtCfg: jwtCfg}
}

func (s *AuthService) Register(ctx context.Context, req RegisterRequest) (*AuthTokensResponse, error) {
	email := strings.TrimSpace(strings.ToLower(req.Email))
	phone := strings.TrimSpace(req.Phone)

	if email != "" {
		existing, err := s.repo.FindParentByEmail(ctx, email)
		if err != nil {
			return nil, common.ErrInternal("failed to check existing email")
		}
		if existing != nil {
			return nil, common.ErrConflict("email already registered")
		}
	}

	if phone != "" {
		existing, err := s.repo.FindParentByPhone(ctx, phone)
		if err != nil {
			return nil, common.ErrInternal("failed to check existing phone")
		}
		if existing != nil {
			return nil, common.ErrConflict("phone number already registered")
		}
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, common.ErrInternal("failed to hash password")
	}

	var emailPtr, phonePtr *string
	if email != "" {
		emailPtr = &email
	}
	if phone != "" {
		phonePtr = &phone
	}

	parent, err := s.repo.CreateParent(ctx, emailPtr, phonePtr, string(hash))
	if err != nil {
		return nil, common.ErrInternal("failed to create account")
	}

	return s.generateTokens(ctx, parent.ID)
}

func (s *AuthService) Login(ctx context.Context, req LoginRequest) (*AuthTokensResponse, error) {
	// Accept email_or_phone, email, or phone fields
	identifier := strings.TrimSpace(req.EmailOrPhone)
	if identifier == "" {
		identifier = strings.TrimSpace(req.Email)
	}
	if identifier == "" {
		identifier = strings.TrimSpace(req.Phone)
	}
	if identifier == "" {
		return nil, common.ErrBadRequest("email or phone is required")
	}

	var parent *Parent
	var err error

	if strings.Contains(identifier, "@") {
		parent, err = s.repo.FindParentByEmail(ctx, strings.ToLower(identifier))
	} else {
		parent, err = s.repo.FindParentByPhone(ctx, identifier)
	}
	if err != nil {
		return nil, common.ErrInternal("failed to find account")
	}
	if parent == nil {
		return nil, common.ErrUnauthorized("invalid credentials")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(parent.PasswordHash), []byte(req.Password)); err != nil {
		return nil, common.ErrUnauthorized("invalid credentials")
	}

	return s.generateTokens(ctx, parent.ID)
}

func (s *AuthService) RefreshTokens(ctx context.Context, refreshToken string) (*AuthTokensResponse, error) {
	tokenHash := hashToken(refreshToken)
	parentID, err := s.repo.ValidateRefreshToken(ctx, tokenHash)
	if err != nil {
		return nil, common.ErrUnauthorized("invalid refresh token")
	}

	if err := s.repo.RevokeRefreshToken(ctx, tokenHash); err != nil {
		return nil, common.ErrInternal("failed to revoke old token")
	}

	return s.generateTokens(ctx, parentID)
}

func (s *AuthService) ValidateToken(tokenString string) (*TokenClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &TokenClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.jwtCfg.Secret), nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*TokenClaims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}
	return claims, nil
}

func (s *AuthService) generateTokens(ctx context.Context, parentID uuid.UUID) (*AuthTokensResponse, error) {
	now := time.Now()
	accessExpiry := now.Add(s.jwtCfg.AccessExpiresIn)

	accessClaims := TokenClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   parentID.String(),
			ExpiresAt: jwt.NewNumericDate(accessExpiry),
			IssuedAt:  jwt.NewNumericDate(now),
			Issuer:    "kita-english",
		},
		ParentID: parentID,
	}

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString([]byte(s.jwtCfg.Secret))
	if err != nil {
		return nil, common.ErrInternal("failed to generate access token")
	}

	refreshTokenID := uuid.New().String()
	refreshTokenHash := hashToken(refreshTokenID)
	refreshExpiry := now.Add(s.jwtCfg.RefreshExpiresIn)

	if err := s.repo.StoreRefreshToken(ctx, parentID, refreshTokenHash, refreshExpiry); err != nil {
		return nil, common.ErrInternal("failed to store refresh token")
	}

	return &AuthTokensResponse{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenID,
		ExpiresAt:    accessExpiry,
	}, nil
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}
