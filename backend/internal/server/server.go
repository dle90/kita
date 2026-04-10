package server

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/kitaenglish/backend/internal/auth"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/debug"
	"github.com/kitaenglish/backend/internal/onboarding"
	"github.com/kitaenglish/backend/internal/progress"
	"github.com/kitaenglish/backend/internal/pronunciation"
	"github.com/kitaenglish/backend/internal/session"
	"github.com/kitaenglish/backend/internal/srs"
)

type Dependencies struct {
	AuthHandler          *auth.AuthHandler
	AuthService          *auth.AuthService
	OnboardingHandler    *onboarding.OnboardingHandler
	SessionHandler       *session.SessionHandler
	PronunciationHandler *pronunciation.PronunciationHandler
	ProgressHandler      *progress.ProgressHandler
	SrsHandler           *srs.SrsHandler
	DebugHandler         *debug.DebugHandler
}

func NewServer(deps Dependencies) *chi.Mux {
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health check
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		common.RespondJSON(w, http.StatusOK, map[string]string{
			"status": "ok",
			"time":   time.Now().Format(time.RFC3339),
		})
	})

	// Public routes
	r.Route("/api/v1", func(r chi.Router) {
		r.Mount("/auth", deps.AuthHandler.Routes())

		// Debug routes (gated by DEBUG_ENABLED env var internally)
		if deps.DebugHandler != nil {
			r.Mount("/debug", deps.DebugHandler.Routes())
		}

		// Protected routes
		r.Group(func(r chi.Router) {
			r.Use(auth.AuthMiddleware(deps.AuthService))

			r.Post("/auth/link", deps.AuthHandler.LinkAccount)

			r.Mount("/kids", deps.OnboardingHandler.Routes())

			r.Route("/kids/{kidId}", func(r chi.Router) {
				r.Mount("/sessions", deps.SessionHandler.Routes())
				r.Mount("/activities", deps.SessionHandler.ActivityRoutes())
				r.Mount("/progress", deps.ProgressHandler.Routes())
				r.Mount("/srs", deps.SrsHandler.Routes())
			})

			r.Mount("/pronunciation", deps.PronunciationHandler.Routes())
		})
	})

	return r
}
