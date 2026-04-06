package common

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// RunMigrations reads and executes all *.up.sql files in the given directory.
func RunMigrations(ctx context.Context, pool *pgxpool.Pool, dir string) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return fmt.Errorf("reading migrations dir %q: %w", dir, err)
	}

	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".up.sql") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)

	for _, f := range files {
		sql, err := os.ReadFile(filepath.Join(dir, f))
		if err != nil {
			return fmt.Errorf("reading %s: %w", f, err)
		}
		if _, err := pool.Exec(ctx, string(sql)); err != nil {
			// Skip "already exists" errors so migrations are idempotent
			if strings.Contains(err.Error(), "already exists") ||
				strings.Contains(err.Error(), "duplicate key") {
				log.Printf("Migration %s: already applied, skipping", f)
				continue
			}
			return fmt.Errorf("executing %s: %w", f, err)
		}
		log.Printf("Migration applied: %s", f)
	}

	return nil
}
