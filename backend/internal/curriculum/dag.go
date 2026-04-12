package curriculum

import (
	"context"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/content"
)

// minExposuresForPrerequisite is how many times a kid must see a grammar structure
// before its dependent structures are unlocked.
const minExposuresForPrerequisite = 2

// maxExposuresPerStructure is the ceiling after which we consider the kid has seen
// enough of a structure and move on.
const maxExposuresPerStructure = 6

// GetNextGrammarStructure selects the next grammar structure to introduce to a kid
// based on the DAG of prerequisites and existing exposures.
//
// Priority:
//  1. A never-seen structure whose prerequisites are all met (introduce it)
//  2. A least-exposed structure that is still below maxExposures (reinforce it)
//  3. Fallback: the lowest-difficulty structure (for fresh users with no exposure)
func GetNextGrammarStructure(
	allStructures []*content.GrammarStructure,
	exposures []*KidGrammarExposure,
) *content.GrammarStructure {
	// Build exposure map: structureID → exposure count
	exposureCount := make(map[string]int, len(exposures))
	for _, e := range exposures {
		exposureCount[e.GrammarStructureID] = e.ExposureCount
	}

	// allStructures is already ordered by difficulty ASC from the DB query.

	// Pass 1: find the first never-seen structure with all prerequisites met.
	for _, gs := range allStructures {
		if exposureCount[gs.ID] > 0 {
			continue // already seen
		}
		if prerequisitesMet(gs, exposureCount) {
			return gs
		}
	}

	// Pass 2: find the least-exposed unlocked structure below the ceiling.
	var best *content.GrammarStructure
	bestCount := maxExposuresPerStructure + 1
	for _, gs := range allStructures {
		count := exposureCount[gs.ID]
		if count >= maxExposuresPerStructure {
			continue // seen enough
		}
		if !prerequisitesMet(gs, exposureCount) {
			continue // locked
		}
		if count < bestCount {
			bestCount = count
			best = gs
		}
	}
	if best != nil {
		return best
	}

	// Pass 3: everything is locked or maxed — return the first structure regardless.
	if len(allStructures) > 0 {
		return allStructures[0]
	}
	return nil
}

// prerequisitesMet returns true when all prerequisite structures have been seen
// at least minExposuresForPrerequisite times.
func prerequisitesMet(gs *content.GrammarStructure, exposureCount map[string]int) bool {
	for _, prereqID := range gs.PrerequisiteIDs {
		if exposureCount[prereqID] < minExposuresForPrerequisite {
			return false
		}
	}
	return true
}

// RecordGrammarExposure persists that a kid encountered a grammar structure this session.
// Errors are non-fatal — the session continues regardless.
func RecordGrammarExposure(ctx context.Context, repo Repository, kidID uuid.UUID, grammarStructureID string) {
	_ = repo.RecordExposure(ctx, kidID, grammarStructureID)
}

// SelectPhonemesForSession picks the best phonemes to practise this session.
// For fresh users (no mastery data) it returns high-priority phonemes ordered by
// difficulty. For returning users it merges weak mastered phonemes with unseen ones.
func SelectPhonemesForSession(
	allPhonemes []*content.Phoneme,
	weakPhonemeIDs []string,
	count int,
) []*content.Phoneme {
	if count <= 0 || len(allPhonemes) == 0 {
		return nil
	}

	seen := make(map[string]bool)
	var selected []*content.Phoneme

	// First: add weak phonemes that exist in allPhonemes
	weakSet := make(map[string]bool, len(weakPhonemeIDs))
	for _, id := range weakPhonemeIDs {
		weakSet[id] = true
	}
	for _, p := range allPhonemes {
		if weakSet[p.ID] && !seen[p.ID] {
			selected = append(selected, p)
			seen[p.ID] = true
			if len(selected) >= count {
				return selected
			}
		}
	}

	// Then: fill with unseen high-priority (IsNewForVietnamese) phonemes
	for _, p := range allPhonemes {
		if !seen[p.ID] && p.IsNewForVietnamese {
			selected = append(selected, p)
			seen[p.ID] = true
			if len(selected) >= count {
				return selected
			}
		}
	}

	// Finally: any remaining phoneme ordered by difficulty (allPhonemes is ordered DESC)
	for _, p := range allPhonemes {
		if !seen[p.ID] {
			selected = append(selected, p)
			seen[p.ID] = true
			if len(selected) >= count {
				return selected
			}
		}
	}

	return selected
}
