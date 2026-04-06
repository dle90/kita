package auth

import (
	"context"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
)

type contextKey string

const (
	parentIDKey contextKey = "parentID"
	kidIDKey    contextKey = "kidID"
)

func AuthMiddleware(authService *AuthService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				common.RespondError(w, http.StatusUnauthorized, "missing authorization header")
				return
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
				common.RespondError(w, http.StatusUnauthorized, "invalid authorization header format")
				return
			}

			claims, err := authService.ValidateToken(parts[1])
			if err != nil {
				common.RespondError(w, http.StatusUnauthorized, "invalid or expired token")
				return
			}

			ctx := context.WithValue(r.Context(), parentIDKey, claims.ParentID)
			if claims.KidID != nil {
				ctx = context.WithValue(ctx, kidIDKey, *claims.KidID)
			}

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func ParentIDFromContext(ctx context.Context) uuid.UUID {
	if id, ok := ctx.Value(parentIDKey).(uuid.UUID); ok {
		return id
	}
	return uuid.Nil
}

func KidIDFromContext(ctx context.Context) *uuid.UUID {
	if id, ok := ctx.Value(kidIDKey).(uuid.UUID); ok {
		return &id
	}
	return nil
}
