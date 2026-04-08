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

	// Seed phonemes
	phCount, err := seedPhonemes(ctx, repo, seedDir+"/phonemes.json")
	if err != nil {
		log.Printf("Warning: could not seed phonemes: %v", err)
	} else {
		log.Printf("Seeded %d phonemes", phCount)
	}

	// Seed grammar structures
	gsCount, err := seedGrammarStructures(ctx, repo, seedDir+"/grammar_structures.json")
	if err != nil {
		log.Printf("Warning: could not seed grammar structures: %v", err)
	} else {
		log.Printf("Seeded %d grammar structures", gsCount)
	}

	// Seed patterns
	pCount, err := seedPatterns(ctx, repo, seedDir+"/patterns.json")
	if err != nil {
		log.Printf("Warning: could not seed patterns: %v", err)
	} else {
		log.Printf("Seeded %d patterns", pCount)
	}

	// Seed communication functions
	cfCount, err := seedCommunicationFunctions(ctx, repo, seedDir+"/communication_functions.json")
	if err != nil {
		log.Printf("Warning: could not seed communication functions: %v", err)
	} else {
		log.Printf("Seeded %d communication functions", cfCount)
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
