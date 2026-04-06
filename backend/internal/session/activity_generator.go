package session

import (
	"encoding/json"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/content"
	"github.com/kitaenglish/backend/internal/srs"
)

func GenerateSessionActivities(dayNumber int, templates []*content.SessionTemplate, dueCards []*srs.SrsCard, recentAccuracy float64) []Activity {
	var activities []Activity

	// Adjust difficulty based on recent accuracy
	difficultyOffset := 0
	if recentAccuracy > 85 {
		difficultyOffset = 1
	} else if recentAccuracy < 60 && recentAccuracy > 0 {
		difficultyOffset = -1
	}
	_ = difficultyOffset // used in config adjustment below

	// Inject SRS due cards into the warmup phase
	if len(dueCards) > 0 {
		var reviewVocabIDs []uuid.UUID
		for _, card := range dueCards {
			reviewVocabIDs = append(reviewVocabIDs, card.VocabularyID)
			if len(reviewVocabIDs) >= 5 {
				break
			}
		}

		reviewConfig := map[string]interface{}{
			"type":     "srs_review",
			"max_items": len(reviewVocabIDs),
		}
		configJSON, _ := json.Marshal(reviewConfig)

		activities = append(activities, Activity{
			ID:            uuid.New(),
			Phase:         "warmup",
			ActivityType:  "flashcard_review",
			Config:        configJSON,
			VocabularyIDs: reviewVocabIDs,
			SortOrder:     0,
		})
	}

	// Generate activities from templates
	for _, tmpl := range templates {
		config := tmpl.Config

		// Adjust config based on difficulty offset
		if difficultyOffset != 0 {
			var cfgMap map[string]interface{}
			if err := json.Unmarshal(config, &cfgMap); err == nil {
				if difficultyOffset > 0 {
					cfgMap["difficulty_boost"] = true
				} else {
					cfgMap["difficulty_ease"] = true
				}
				if adjusted, err := json.Marshal(cfgMap); err == nil {
					config = adjusted
				}
			}
		}

		sortOrder := tmpl.SortOrder
		if len(dueCards) > 0 && tmpl.Phase == "warmup" {
			sortOrder++ // shift to accommodate SRS review
		}

		activity := Activity{
			ID:            uuid.New(),
			Phase:         tmpl.Phase,
			ActivityType:  tmpl.ActivityType,
			Config:        config,
			VocabularyIDs: tmpl.VocabularyIDs,
			SentenceIDs:   tmpl.SentenceIDs,
			SortOrder:     sortOrder,
		}
		activities = append(activities, activity)
	}

	return activities
}
