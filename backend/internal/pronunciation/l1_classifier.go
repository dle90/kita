package pronunciation

import "strings"

var finalConsonants = map[string]bool{
	"k": true, "t": true, "p": true, "d": true, "g": true,
	"f": true, "s": true, "z": true, "v": true,
}

var thPhonemes = map[string]bool{
	"θ": true, "ð": true,
}

func ClassifyL1Errors(words []AzureWord, dialect string) []L1Error {
	var errors []L1Error

	for _, word := range words {
		phonemes := word.Phonemes
		numPhonemes := len(phonemes)

		for i, ph := range phonemes {
			score := ph.PronunciationAssessment.AccuracyScore
			phoneme := strings.ToLower(ph.Phoneme)

			// 1. Final consonant dropping
			if i == numPhonemes-1 && finalConsonants[phoneme] && score < 50 {
				errors = append(errors, L1Error{
					Type:            FinalConsonantDrop,
					ExpectedPhoneme: phoneme,
					ActualPhoneme:   "(dropped)",
					Severity:        severityFromScore(score),
					SuggestionVI:    finalConsonantSuggestion(phoneme),
				})
			}

			// 2. /θ/ → /t/ or /ð/ → /d/ substitution
			if thPhonemes[phoneme] && score < 60 {
				var expected, actual, suggestion string
				if phoneme == "θ" {
					expected = "θ"
					actual = "t"
					suggestion = "Đặt lưỡi giữa hai hàm răng và thổi hơi ra. Không phải âm /t/."
				} else {
					expected = "ð"
					actual = "d"
					suggestion = "Đặt lưỡi giữa hai hàm răng và rung dây thanh. Không phải âm /d/."
				}
				errors = append(errors, L1Error{
					Type:            ThSubstitution,
					ExpectedPhoneme: expected,
					ActualPhoneme:   actual,
					Severity:        severityFromScore(score),
					SuggestionVI:    suggestion,
				})
			}

			// 3. /r/ → /l/ confusion
			if (phoneme == "r" || phoneme == "ɹ") && score < 60 {
				severity := severityFromScore(score)
				if dialect == "southern" {
					// Higher severity for Southern dialect speakers
					if severity == "low" {
						severity = "medium"
					} else if severity == "medium" {
						severity = "high"
					}
				}
				errors = append(errors, L1Error{
					Type:            RLConfusion,
					ExpectedPhoneme: "r",
					ActualPhoneme:   "l",
					Severity:        severity,
					SuggestionVI:    "Cong lưỡi lên và không chạm vào vòm miệng. Âm /r/ khác âm /l/.",
				})
			}

			// 4. Vowel length confusion: /ɪ/ vs /iː/, /ʊ/ vs /uː/
			if (phoneme == "ɪ" || phoneme == "iː" || phoneme == "i") && score < 55 {
				errors = append(errors, L1Error{
					Type:            VowelLength,
					ExpectedPhoneme: phoneme,
					ActualPhoneme:   vowelCounterpart(phoneme),
					Severity:        severityFromScore(score),
					SuggestionVI:    "Chú ý độ dài nguyên âm. /iː/ dài hơn /ɪ/.",
				})
			}
			if (phoneme == "ʊ" || phoneme == "uː" || phoneme == "u") && score < 55 {
				errors = append(errors, L1Error{
					Type:            VowelLength,
					ExpectedPhoneme: phoneme,
					ActualPhoneme:   vowelCounterpart(phoneme),
					Severity:        severityFromScore(score),
					SuggestionVI:    "Chú ý độ dài nguyên âm. /uː/ dài hơn /ʊ/.",
				})
			}

			// 5. Cluster simplification
			if i < numPhonemes-1 && isConsonant(phoneme) && isConsonant(strings.ToLower(phonemes[i+1].Phoneme)) {
				nextScore := phonemes[i+1].PronunciationAssessment.AccuracyScore
				if score > 70 && nextScore < 40 {
					errors = append(errors, L1Error{
						Type:            ClusterSimplification,
						ExpectedPhoneme: phoneme + strings.ToLower(phonemes[i+1].Phoneme),
						ActualPhoneme:   phoneme,
						Severity:        severityFromScore(nextScore),
						SuggestionVI:    "Phát âm cả cụm phụ âm, không bỏ âm cuối trong cụm.",
					})
				}
			}

			// 6. /w/ → /v/ confusion
			if phoneme == "w" && score < 60 {
				severity := severityFromScore(score)
				if dialect == "northern" {
					if severity == "low" {
						severity = "medium"
					} else if severity == "medium" {
						severity = "high"
					}
				}
				errors = append(errors, L1Error{
					Type:            WVConfusion,
					ExpectedPhoneme: "w",
					ActualPhoneme:   "v",
					Severity:        severity,
					SuggestionVI:    "Tròn môi và không chạm răng vào môi. Âm /w/ khác âm /v/.",
				})
			}
		}
	}

	return errors
}

func severityFromScore(score float64) string {
	switch {
	case score < 30:
		return "high"
	case score < 50:
		return "medium"
	default:
		return "low"
	}
}

func finalConsonantSuggestion(phoneme string) string {
	suggestions := map[string]string{
		"k": "Nhớ phát âm rõ âm /k/ ở cuối từ. Đóng cuống họng nhanh.",
		"t": "Nhớ phát âm rõ âm /t/ ở cuối từ. Chạm lưỡi vào chân răng trên.",
		"p": "Nhớ phát âm rõ âm /p/ ở cuối từ. Ngậm môi rồi bật ra.",
		"d": "Nhớ phát âm rõ âm /d/ ở cuối từ.",
		"g": "Nhớ phát âm rõ âm /g/ ở cuối từ.",
		"f": "Nhớ phát âm rõ âm /f/ ở cuối từ. Răng trên chạm môi dưới.",
		"s": "Nhớ phát âm rõ âm /s/ ở cuối từ.",
		"z": "Nhớ phát âm rõ âm /z/ ở cuối từ.",
		"v": "Nhớ phát âm rõ âm /v/ ở cuối từ.",
	}
	if s, ok := suggestions[phoneme]; ok {
		return s
	}
	return "Nhớ phát âm rõ phụ âm cuối."
}

func vowelCounterpart(phoneme string) string {
	switch phoneme {
	case "ɪ":
		return "iː"
	case "iː", "i":
		return "ɪ"
	case "ʊ":
		return "uː"
	case "uː", "u":
		return "ʊ"
	default:
		return phoneme
	}
}

var consonants = map[string]bool{
	"b": true, "d": true, "f": true, "g": true, "h": true, "k": true,
	"l": true, "m": true, "n": true, "p": true, "r": true, "s": true,
	"t": true, "v": true, "w": true, "z": true, "ʃ": true, "ʒ": true,
	"tʃ": true, "dʒ": true, "θ": true, "ð": true, "ŋ": true, "j": true,
	"ɹ": true,
}

func isConsonant(phoneme string) bool {
	return consonants[phoneme]
}
