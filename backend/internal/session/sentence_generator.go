package session

import (
	"fmt"
	"math/rand"
	"strings"

	"github.com/kitaenglish/backend/internal/content"
)

// GenerateSentence takes a pattern template and available vocabulary,
// fills slots by matching word category to slot category,
// and returns (englishSentence, vietnameseSentence, error).
func GenerateSentence(pattern *content.Pattern, vocabPool []*content.Vocabulary) (string, string, error) {
	slots := pattern.GetSlots()

	// If no slots, return the template directly (it's a fixed phrase)
	if len(slots) == 0 {
		return pattern.Template, pattern.TemplateVI, nil
	}

	enResult := pattern.Template
	viResult := pattern.TemplateVI

	for _, slot := range slots {
		// Find vocabulary matching the slot category
		var candidates []*content.Vocabulary
		for _, v := range vocabPool {
			if strings.EqualFold(v.Category, slot.Category) {
				candidates = append(candidates, v)
			}
		}

		if len(candidates) == 0 {
			// Fallback: use any word from pool
			if len(vocabPool) > 0 {
				candidates = vocabPool
			} else {
				return "", "", fmt.Errorf("no vocabulary available for slot %q (category %q)", slot.Name, slot.Category)
			}
		}

		// Pick a random candidate
		chosen := candidates[rand.Intn(len(candidates))]

		// Replace the slot placeholder in English template
		enPlaceholder := "{" + slot.Name + "}"
		enResult = strings.Replace(enResult, enPlaceholder, chosen.Word, 1)

		// Replace the corresponding Vietnamese placeholder
		// The VI template may use a Vietnamese slot name, so try both
		viReplaced := false
		// Try all possible placeholders in the Vietnamese template
		viTemplate := pattern.TemplateVI
		// Find the Vietnamese placeholder by looking for {xxx} patterns
		for _, candidate := range findPlaceholders(viResult) {
			if !viReplaced {
				viResult = strings.Replace(viResult, candidate, chosen.TranslationVI, 1)
				viReplaced = true
			}
		}
		// If no placeholder found in Vietnamese, just keep it
		if !viReplaced {
			_ = viTemplate
		}
	}

	return enResult, viResult, nil
}

// GenerateSentenceFromExample picks a random example sentence from the pattern.
// Returns an error when the pattern has no examples — falling back to the raw
// template would leak unfilled placeholders like "{animal}" into build_sentence
// and fill_blank activities, which the kid would see as literal tiles.
func GenerateSentenceFromExample(pattern *content.Pattern) (string, string, error) {
	examples := pattern.GetExamples()
	if len(examples) == 0 {
		return "", "", fmt.Errorf("pattern %q has no example sentences", pattern.ID)
	}
	picked := examples[rand.Intn(len(examples))]
	if strings.Contains(picked.En, "{") || strings.Contains(picked.En, "}") {
		return "", "", fmt.Errorf("pattern %q example contains unfilled placeholder: %q", pattern.ID, picked.En)
	}
	return picked.En, picked.Vi, nil
}

// findPlaceholders returns all {xxx} placeholders in a string.
func findPlaceholders(s string) []string {
	var result []string
	for {
		start := strings.Index(s, "{")
		if start == -1 {
			break
		}
		end := strings.Index(s[start:], "}")
		if end == -1 {
			break
		}
		placeholder := s[start : start+end+1]
		result = append(result, placeholder)
		s = s[start+end+1:]
	}
	return result
}

// ScrambleWords splits a sentence into words and shuffles them.
// Returns the shuffled words and the correct word order.
func ScrambleWords(sentence string) (shuffled []string, correct []string) {
	// Remove trailing punctuation for the word list
	cleaned := strings.TrimRight(sentence, ".!?")
	correct = strings.Fields(cleaned)

	shuffled = make([]string, len(correct))
	copy(shuffled, correct)

	// Shuffle until different from correct (if more than 1 word)
	if len(shuffled) > 1 {
		for i := 0; i < 10; i++ {
			rand.Shuffle(len(shuffled), func(i, j int) {
				shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
			})
			// Check if different
			different := false
			for idx := range shuffled {
				if shuffled[idx] != correct[idx] {
					different = true
					break
				}
			}
			if different {
				break
			}
		}
	}

	return shuffled, correct
}

// GenerateDistractorsFromCategory returns distractor words from the same category,
// excluding the correct word.
func GenerateDistractorsFromCategory(correct *content.Vocabulary, vocabPool []*content.Vocabulary, count int) []string {
	var distractors []string
	var sameCat []*content.Vocabulary
	var otherCat []*content.Vocabulary

	for _, v := range vocabPool {
		if v.Word == correct.Word {
			continue
		}
		if strings.EqualFold(v.Category, correct.Category) {
			sameCat = append(sameCat, v)
		} else {
			otherCat = append(otherCat, v)
		}
	}

	// Shuffle same category first
	rand.Shuffle(len(sameCat), func(i, j int) { sameCat[i], sameCat[j] = sameCat[j], sameCat[i] })
	for _, v := range sameCat {
		if len(distractors) >= count {
			break
		}
		distractors = append(distractors, v.Word)
	}

	// Pad with other categories if needed
	rand.Shuffle(len(otherCat), func(i, j int) { otherCat[i], otherCat[j] = otherCat[j], otherCat[i] })
	for _, v := range otherCat {
		if len(distractors) >= count {
			break
		}
		distractors = append(distractors, v.Word)
	}

	return distractors
}
