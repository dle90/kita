package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/kitaenglish/backend/internal/auth"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/config"
	"github.com/kitaenglish/backend/internal/content"
	"github.com/kitaenglish/backend/internal/curriculum"
	"github.com/kitaenglish/backend/internal/debug"
	"github.com/kitaenglish/backend/internal/notification"
	"github.com/kitaenglish/backend/internal/onboarding"
	"github.com/kitaenglish/backend/internal/progress"
	"github.com/kitaenglish/backend/internal/pronunciation"
	"github.com/kitaenglish/backend/internal/server"
	"github.com/kitaenglish/backend/internal/session"
	"github.com/kitaenglish/backend/internal/srs"
	"github.com/kitaenglish/backend/internal/tts"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}
	log.Printf("Starting Kita English backend on port %s", cfg.Server.Port)

	// Connect to PostgreSQL
	dbPool, err := common.NewPostgresPool(ctx, cfg.DB)
	if err != nil {
		log.Fatalf("Failed to connect to PostgreSQL: %v", err)
	}
	defer dbPool.Close()

	// Auto-run migrations
	migrationsDir := "migrations"
	if envMigDir := os.Getenv("MIGRATIONS_DIR"); envMigDir != "" {
		migrationsDir = envMigDir
	}
	if err := common.RunMigrations(ctx, dbPool, migrationsDir); err != nil {
		log.Printf("Warning: Migration error: %v", err)
	}

	// Connect to Redis
	redisClient, err := common.NewRedisClient(ctx, cfg.Redis)
	if err != nil {
		log.Printf("Warning: Failed to connect to Redis: %v (continuing without Redis)", err)
	}
	if redisClient != nil {
		defer redisClient.Close()
	}

	// Connect to MinIO
	storage, err := common.NewStorage(ctx, cfg.MinIO)
	if err != nil {
		log.Printf("Warning: Failed to connect to MinIO: %v (continuing without storage)", err)
	}

	// Initialize repositories
	authRepo := auth.NewAuthRepository(dbPool)
	kidRepo := onboarding.NewKidRepository(dbPool)
	contentRepo := content.NewContentRepository(dbPool)
	sessionRepo := session.NewSessionRepository(dbPool)
	activityRepo := session.NewActivityResultRepository(dbPool)
	srsRepo := srs.NewSrsRepository(dbPool)
	skillMasteryRepo := srs.NewSkillMasteryRepository(dbPool)
	phonemeMasteryRepo := srs.NewPhonemeMasteryRepository(dbPool)
	curriculumRepo := curriculum.NewRepository(dbPool)
	progressRepo := progress.NewProgressRepository(dbPool)
	pronRepo := pronunciation.NewPronunciationRepository(dbPool)

	// Initialize services
	authService := auth.NewAuthService(authRepo, cfg.JWT)
	onboardingService := onboarding.NewOnboardingService(kidRepo, contentRepo, skillMasteryRepo, srsRepo)
	srsService := srs.NewSrsService(srsRepo)
	sessionService := session.NewSessionService(sessionRepo, activityRepo, contentRepo, kidRepo, srsRepo, skillMasteryRepo, phonemeMasteryRepo, curriculumRepo)
	azureClient := pronunciation.NewAzureSpeechClient(cfg.Azure)
	pronService := pronunciation.NewPronunciationService(pronRepo, azureClient, storage)

	// TTS (ElevenLabs + R2 cache). Nil-safe: disabled if API key or storage missing.
	var ttsService *tts.Service
	if cfg.ElevenLabs.APIKey != "" && storage != nil {
		elevenClient := tts.NewElevenLabsClient(cfg.ElevenLabs.APIKey, cfg.ElevenLabs.ModelID)
		ttsService = tts.NewService(elevenClient, storage, cfg.ElevenLabs.VoiceID, cfg.ElevenLabs.ModelID)
		log.Printf("TTS enabled (default voice=%s model=%s)", cfg.ElevenLabs.VoiceID, cfg.ElevenLabs.ModelID)
	} else {
		log.Printf("TTS disabled (missing ELEVENLABS_API_KEY or storage)")
	}
	progressService := progress.NewProgressService(progressRepo, sessionRepo, activityRepo, srsRepo, pronRepo, skillMasteryRepo)
	_ = notification.NewNotificationService()

	srsHandler := srs.NewSrsHandler(srsService)

	// Seed content data
	seedDir := "seed"
	if envSeedDir := os.Getenv("SEED_DIR"); envSeedDir != "" {
		seedDir = envSeedDir
	}
	if err := content.SeedContent(ctx, contentRepo, seedDir); err != nil {
		log.Printf("Warning: Failed to seed content: %v", err)
	}

	// Initialize handlers
	authHandler := auth.NewAuthHandler(authService)
	onboardingHandler := onboarding.NewOnboardingHandler(onboardingService)
	sessionHandler := session.NewSessionHandler(sessionService)
	pronHandler := pronunciation.NewPronunciationHandler(pronService, kidRepo)
	progressHandler := progress.NewProgressHandler(progressService)

	// Initialize debug handler (gated by DEBUG_ENABLED env var)
	debugHandler := debug.NewDebugHandler(dbPool, contentRepo)

	// Initialize TTS handler (nil-safe: server.go handles nil)
	var ttsHandler *tts.Handler
	if ttsService != nil {
		ttsHandler = tts.NewHandler(ttsService, contentRepo)
	}

	// Create server
	router := server.NewServer(server.Dependencies{
		AuthHandler:          authHandler,
		AuthService:          authService,
		OnboardingHandler:    onboardingHandler,
		SessionHandler:       sessionHandler,
		PronunciationHandler: pronHandler,
		ProgressHandler:      progressHandler,
		SrsHandler:           srsHandler,
		DebugHandler:         debugHandler,
		TTSHandler:           ttsHandler,
	})

	httpServer := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		log.Println("Shutting down server...")

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()

		if err := httpServer.Shutdown(shutdownCtx); err != nil {
			log.Printf("HTTP server shutdown error: %v", err)
		}
		cancel()
	}()

	log.Printf("Server v2 (Phase3+Phase4) listening on :%s", cfg.Server.Port)
	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("HTTP server error: %v", err)
	}

	log.Println("Server stopped")
}
