package content

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/google/uuid"
)

func SeedContent(ctx context.Context, repo ContentRepository, seedDir string) error {
	vocabCount, err := repo.CountVocabulary(ctx)
	if err != nil {
		log.Printf("Warning: could not count vocabulary (table may not exist): %v", err)
		return nil
	}

	if vocabCount > 0 {
		log.Println("Content already seeded, skipping")
		return nil
	}

	// Seed vocabulary
	wordIDMap, err := seedVocabulary(ctx, repo, seedDir+"/vocabulary.json")
	if err != nil {
		return fmt.Errorf("seeding vocabulary: %w", err)
	}
	log.Printf("Seeded %d vocabulary words", len(wordIDMap))

	// Seed session templates
	count, err := seedSessionTemplates(ctx, repo, seedDir+"/session_templates.json", wordIDMap)
	if err != nil {
		return fmt.Errorf("seeding session templates: %w", err)
	}
	log.Printf("Seeded %d session templates", count)

	return nil
}

func seedVocabulary(ctx context.Context, repo ContentRepository, filePath string) (map[string]uuid.UUID, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("reading vocabulary file: %w", err)
	}

	var seeds []VocabularySeed
	if err := json.Unmarshal(data, &seeds); err != nil {
		return nil, fmt.Errorf("parsing vocabulary JSON: %w", err)
	}

	wordIDMap := make(map[string]uuid.UUID)
	for _, s := range seeds {
		vocab := &Vocabulary{
			ID:             uuid.New(),
			Word:           s.Word,
			TranslationVI:  s.TranslationVI,
			PhoneticIPA:    s.PhoneticIPA,
			Category:       s.Category,
			DayNumber:      s.DayNumber,
			Difficulty:     s.Difficulty,
			TargetPhonemes: s.TargetPhonemes,
			CommonL1Errors: s.CommonL1Errors,
		}
		if err := repo.InsertVocabulary(ctx, vocab); err != nil {
			return nil, fmt.Errorf("inserting vocabulary %q: %w", s.Word, err)
		}
		wordIDMap[s.Word] = vocab.ID
	}
	return wordIDMap, nil
}

func seedSessionTemplates(ctx context.Context, repo ContentRepository, filePath string, wordIDMap map[string]uuid.UUID) (int, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("reading session templates file: %w", err)
	}

	var seeds []SessionTemplateSeed
	if err := json.Unmarshal(data, &seeds); err != nil {
		return 0, fmt.Errorf("parsing session templates JSON: %w", err)
	}

	count := 0
	for _, s := range seeds {
		var vocabIDs []uuid.UUID
		for _, ref := range s.WordRefs {
			if id, ok := wordIDMap[ref]; ok {
				vocabIDs = append(vocabIDs, id)
			}
		}

		tmpl := &SessionTemplate{
			ID:            uuid.New(),
			DayNumber:     s.DayNumber,
			Level:         s.Level,
			Phase:         s.Phase,
			ActivityType:  s.ActivityType,
			Config:        s.Config,
			SortOrder:     s.SortOrder,
			VocabularyIDs: vocabIDs,
		}
		if err := repo.InsertSessionTemplate(ctx, tmpl); err != nil {
			return 0, fmt.Errorf("inserting session template: %w", err)
		}
		count++
	}
	return count, nil
}
