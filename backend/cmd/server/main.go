package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
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
	// Catch panics before they silently kill the container
	defer func() {
		if r := recover(); r != nil {
			log.Printf("FATAL PANIC: %v", r)
			os.Exit(1)
		}
	}()

	// Log immediately so Railway captures output even if init hangs
	log.Printf("Kita backend starting (pid %d)...", os.Getpid())

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}
	log.Printf("Config loaded, port=%s", cfg.Server.Port)

	// ready is set to 1 once full initialization completes.
	// The /health endpoint returns 503 until then.
	var ready atomic.Int32

	// Build a minimal router immediately so Railway health checks pass
	// while the real initialization runs in the background.
	bootstrapRouter := http.NewServeMux()
	bootstrapRouter.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK) // always 200 — Railway must not see 503 or it kills the container
		if ready.Load() == 1 {
			fmt.Fprintf(w, `{"status":"ok","time":%q}`, time.Now().Format(time.RFC3339))
		} else {
			fmt.Fprintf(w, `{"status":"starting"}`)
		}
	})

	httpServer := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Server.Port),
		Handler:      bootstrapRouter,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// Start HTTP server immediately — Railway health check can now succeed
	serverErrCh := make(chan error, 1)
	go func() {
		log.Printf("HTTP server listening on :%s (initializing...)", cfg.Server.Port)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			serverErrCh <- err
		}
	}()

	// Graceful shutdown listener
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		select {
		case <-sigCh:
			log.Println("Shutting down server...")
		case err := <-serverErrCh:
			log.Printf("HTTP server error: %v", err)
		}

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()
		if err := httpServer.Shutdown(shutdownCtx); err != nil {
			log.Printf("HTTP server shutdown error: %v", err)
		}
		cancel()
	}()

	// --- Full initialization (runs while server already accepts health checks) ---

	log.Println("Connecting to PostgreSQL...")
	dbPool, err := common.NewPostgresPool(ctx, cfg.DB)
	if err != nil {
		log.Fatalf("Failed to connect to PostgreSQL: %v", err)
	}
	defer dbPool.Close()
	log.Println("PostgreSQL connected")

	// Auto-run migrations
	migrationsDir := "migrations"
	if envMigDir := os.Getenv("MIGRATIONS_DIR"); envMigDir != "" {
		migrationsDir = envMigDir
	}
	log.Printf("Running migrations from %s...", migrationsDir)
	if err := common.RunMigrations(ctx, dbPool, migrationsDir); err != nil {
		log.Printf("Warning: Migration error: %v", err)
	} else {
		log.Println("Migrations complete")
	}

	// Connect to Redis
	redisClient, err := common.NewRedisClient(ctx, cfg.Redis)
	if err != nil {
		log.Printf("Warning: Failed to connect to Redis: %v (continuing without Redis)", err)
	}
	if redisClient != nil {
		defer redisClient.Close()
		log.Println("Redis connected")
	}

	// Connect to MinIO/R2
	log.Println("Connecting to object storage...")
	storage, err := common.NewStorage(ctx, cfg.MinIO)
	if err != nil {
		log.Printf("Warning: Failed to connect to storage: %v (continuing without storage)", err)
	} else {
		log.Println("Object storage connected")
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
	log.Printf("Seeding content from %s...", seedDir)
	if err := content.SeedContent(ctx, contentRepo, seedDir); err != nil {
		log.Printf("Warning: Failed to seed content: %v", err)
	}

	// Initialize handlers
	authHandler := auth.NewAuthHandler(authService)
	onboardingHandler := onboarding.NewOnboardingHandler(onboardingService)
	sessionHandler := session.NewSessionHandler(sessionService)
	pronHandler := pronunciation.NewPronunciationHandler(pronService, kidRepo)
	progressHandler := progress.NewProgressHandler(progressService)
	debugHandler := debug.NewDebugHandler(dbPool, contentRepo)

	// Initialize TTS handler (nil-safe: server.go handles nil)
	var ttsHandler *tts.Handler
	if ttsService != nil {
		ttsHandler = tts.NewHandler(ttsService, contentRepo)
	}

	// Swap the handler to the fully-initialized router
	fullRouter := server.NewServer(server.Dependencies{
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
	httpServer.Handler = fullRouter

	// Signal readiness
	ready.Store(1)
	log.Printf("Server fully initialized and ready (Phase3+Phase4) on :%s", cfg.Server.Port)

	// Block until shutdown
	<-ctx.Done()
	log.Println("Server stopped")
}
