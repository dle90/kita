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
	// Seed each content type independently — check count before seeding

	// Vocabulary
	vocabCount, _ := repo.CountVocabulary(ctx)
	if vocabCount == 0 {
		wordIDMap, err := seedVocabulary(ctx, repo, seedDir+"/vocabulary.json")
		if err != nil {
			log.Printf("Warning: could not seed vocabulary: %v", err)
		} else {
			log.Printf("Seeded %d vocabulary words", len(wordIDMap))
			// Seed session templates (depends on vocabulary)
			count, err := seedSessionTemplates(ctx, repo, seedDir+"/session_templates.json", wordIDMap)
			if err != nil {
				log.Printf("Warning: could not seed session templates: %v", err)
			} else {
				log.Printf("Seeded %d session templates", count)
			}
		}
	} else {
		log.Printf("Vocabulary already seeded (%d words)", vocabCount)
		// Backfill distractors for existing rows (idempotent — only updates
		// rows whose distractors column is still empty).
		if n, err := backfillVocabularyDistractors(ctx, repo, seedDir+"/vocabulary.json"); err != nil {
			log.Printf("Warning: could not backfill vocabulary distractors: %v", err)
		} else if n > 0 {
			log.Printf("Backfilled distractors for %d existing words", n)
		}
	}

	// Curriculum units
	unitCount, _ := repo.CountCurriculumUnits(ctx)
	if unitCount == 0 {
		n, err := seedCurriculumUnits(ctx, repo, seedDir+"/curriculum_units.json")
		if err != nil {
			log.Printf("Warning: could not seed curriculum units: %v", err)
		} else {
			log.Printf("Seeded %d curriculum units", n)
		}
	} else {
		log.Printf("Curriculum units already seeded (%d)", unitCount)
	}

	// Phonemes
	phCount, _ := repo.CountPhonemes(ctx)
	if phCount == 0 {
		n, err := seedPhonemes(ctx, repo, seedDir+"/phonemes.json")
		if err != nil {
			log.Printf("Warning: could not seed phonemes: %v", err)
		} else {
			log.Printf("Seeded %d phonemes", n)
		}
	} else {
		log.Printf("Phonemes already seeded (%d)", phCount)
	}

	// Grammar structures
	gsCount, _ := repo.CountGrammarStructures(ctx)
	if gsCount == 0 {
		n, err := seedGrammarStructures(ctx, repo, seedDir+"/grammar_structures.json")
		if err != nil {
			log.Printf("Warning: could not seed grammar structures: %v", err)
		} else {
			log.Printf("Seeded %d grammar structures", n)
		}
	} else {
		log.Printf("Grammar structures already seeded (%d)", gsCount)
	}

	// Patterns
	pCount, _ := repo.CountPatterns(ctx)
	if pCount == 0 {
		n, err := seedPatterns(ctx, repo, seedDir+"/patterns.json")
		if err != nil {
			log.Printf("Warning: could not seed patterns: %v", err)
		} else {
			log.Printf("Seeded %d patterns", n)
		}
	} else {
		log.Printf("Patterns already seeded (%d)", pCount)
	}

	// Communication functions
	cfCount, _ := repo.CountCommunicationFunctions(ctx)
	if cfCount == 0 {
		n, err := seedCommunicationFunctions(ctx, repo, seedDir+"/communication_functions.json")
		if err != nil {
			log.Printf("Warning: could not seed communication functions: %v", err)
		} else {
			log.Printf("Seeded %d communication functions", n)
		}
	} else {
		log.Printf("Communication functions already seeded (%d)", cfCount)
	}

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
			ID:                uuid.New(),
			Word:              s.Word,
			TranslationVI:     s.TranslationVI,
			PhoneticIPA:       s.PhoneticIPA,
			Category:          s.Category,
			DayNumber:         s.DayNumber,
			Difficulty:        s.Difficulty,
			Emoji:             s.Emoji,
			ExampleSentence:   s.ExampleSentence,
			ExampleSentenceVI: s.ExampleSentenceVI,
			TargetPhonemes:    s.TargetPhonemes,
			CommonL1Errors:    s.CommonL1Errors,
			Distractors:       s.Distractors,
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

func seedGrammarStructures(ctx context.Context, repo ContentRepository, filePath string) (int, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("reading grammar structures file: %w", err)
	}

	var seeds []GrammarStructureSeed
	if err := json.Unmarshal(data, &seeds); err != nil {
		return 0, fmt.Errorf("parsing grammar structures JSON: %w", err)
	}

	count := 0
	for _, s := range seeds {
		gs := &GrammarStructure{
			ID:              s.ID,
			Name:            s.Name,
			DescriptionVI:   s.DescriptionVI,
			Template:        s.Template,
			CEFRLevel:       s.CEFRLevel,
			Difficulty:      s.Difficulty,
			PrerequisiteIDs: s.PrerequisiteIDs,
			CommonL1Errors:  s.CommonL1Errors,
		}
		if gs.PrerequisiteIDs == nil {
			gs.PrerequisiteIDs = []string{}
		}
		if err := repo.InsertGrammarStructure(ctx, gs); err != nil {
			return 0, fmt.Errorf("inserting grammar structure %q: %w", s.ID, err)
		}
		count++
	}
	return count, nil
}

func seedPatterns(ctx context.Context, repo ContentRepository, filePath string) (int, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("reading patterns file: %w", err)
	}

	var seeds []PatternSeed
	if err := json.Unmarshal(data, &seeds); err != nil {
		return 0, fmt.Errorf("parsing patterns JSON: %w", err)
	}

	count := 0
	for _, s := range seeds {
		p := &Pattern{
			ID:                    s.ID,
			GrammarStructureID:    s.GrammarStructureID,
			Template:              s.Template,
			TemplateVI:            s.TemplateVI,
			CommunicationFunction: s.CommunicationFunction,
			Slots:                 s.Slots,
			Difficulty:            s.Difficulty,
			DayIntroduced:         s.DayIntroduced,
			ExampleSentences:      s.ExampleSentences,
		}
		if err := repo.InsertPattern(ctx, p); err != nil {
			return 0, fmt.Errorf("inserting pattern %q: %w", s.ID, err)
		}
		count++
	}
	return count, nil
}

func seedPhonemes(ctx context.Context, repo ContentRepository, filePath string) (int, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("reading phonemes file: %w", err)
	}

	var seeds []PhonemeSeed
	if err := json.Unmarshal(data, &seeds); err != nil {
		return 0, fmt.Errorf("parsing phonemes JSON: %w", err)
	}

	count := 0
	for _, s := range seeds {
		p := &Phoneme{
			ID:                 s.ID,
			Symbol:             s.Symbol,
			ExampleWord:        s.ExampleWord,
			ExampleWordVI:      s.ExampleWordVI,
			Graphemes:          s.Graphemes,
			IsNewForVietnamese: s.IsNewForVietnamese,
			CommonSubstitution: s.CommonSubstitution,
			SubstitutionVI:     s.SubstitutionVI,
			MouthPositionVI:    s.MouthPositionVI,
			Difficulty:         s.Difficulty,
			PriorityNorthern:   s.PriorityNorthern,
			PriorityCentral:    s.PriorityCentral,
			PrioritySouthern:   s.PrioritySouthern,
			MinimalPairs:       s.MinimalPairs,
			PracticeWords:      s.PracticeWords,
		}
		if err := repo.InsertPhoneme(ctx, p); err != nil {
			return 0, fmt.Errorf("inserting phoneme %q: %w", s.ID, err)
		}
		count++
	}
	return count, nil
}

func seedCurriculumUnits(ctx context.Context, repo ContentRepository, filePath string) (int, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("reading curriculum units file: %w", err)
	}

	var units []CurriculumUnit
	if err := json.Unmarshal(data, &units); err != nil {
		return 0, fmt.Errorf("parsing curriculum units JSON: %w", err)
	}

	for _, u := range units {
		unit := u
		if err := repo.UpsertCurriculumUnit(ctx, &unit); err != nil {
			return 0, fmt.Errorf("inserting curriculum unit %d: %w", u.UnitNumber, err)
		}
	}
	return len(units), nil
}

func backfillVocabularyDistractors(ctx context.Context, repo ContentRepository, filePath string) (int, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("reading vocabulary file: %w", err)
	}
	var seeds []VocabularySeed
	if err := json.Unmarshal(data, &seeds); err != nil {
		return 0, fmt.Errorf("parsing vocabulary JSON: %w", err)
	}
	updated := 0
	for _, s := range seeds {
		if len(s.Distractors) == 0 {
			continue
		}
		if err := repo.BackfillVocabularyDistractors(ctx, s.Word, s.Distractors); err != nil {
			return updated, fmt.Errorf("backfilling %q: %w", s.Word, err)
		}
		updated++
	}
	return updated, nil
}

func seedCommunicationFunctions(ctx context.Context, repo ContentRepository, filePath string) (int, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("reading communication functions file: %w", err)
	}

	var seeds []CommunicationFunctionSeed
	if err := json.Unmarshal(data, &seeds); err != nil {
		return 0, fmt.Errorf("parsing communication functions JSON: %w", err)
	}

	count := 0
	for _, s := range seeds {
		cf := &CommunicationFunction{
			ID:            s.ID,
			Name:          s.Name,
			NameVI:        s.NameVI,
			DescriptionVI: s.DescriptionVI,
			CEFRLevel:     s.CEFRLevel,
			Situations:    s.Situations,
			PatternIDs:    s.PatternIDs,
		}
		if cf.PatternIDs == nil {
			cf.PatternIDs = []string{}
		}
		if err := repo.InsertCommunicationFunction(ctx, cf); err != nil {
			return 0, fmt.Errorf("inserting communication function %q: %w", s.ID, err)
		}
		count++
	}
	return count, nil
}
