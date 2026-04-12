package session

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"sync"
)

// SessionPlan defines the template for dynamically generating a session.
type SessionPlan struct {
	Activities []PlanSlot `json:"activities"`
}

// PlanSlot is one slot in a session plan that the engine fills with real content.
type PlanSlot struct {
	Phase  string `json:"phase"`
	Source string `json:"source"`
	Skill  string `json:"skill"`
	Format string `json:"format"`
	Count  int    `json:"count"`
}

// UnitVocab holds the word list and patterns for a curriculum unit.
type UnitVocab struct {
	Words    []string `json:"words"`
	Theme    string   `json:"theme"`
	Patterns []string `json:"patterns"`
}

// SessionPlansFile is the top-level structure of session_plans.json.
type SessionPlansFile struct {
	DefaultPlan    SessionPlan          `json:"default_plan"`
	UnitVocabulary map[string]UnitVocab `json:"unit_vocabulary"`
}

var (
	cachedPlans     *SessionPlansFile
	cachedPlansOnce sync.Once
)

// LoadSessionPlans loads and caches the session plans from the seed directory.
func LoadSessionPlans() *SessionPlansFile {
	cachedPlansOnce.Do(func() {
		cachedPlans = loadSessionPlansFromDisk()
	})
	return cachedPlans
}

func loadSessionPlansFromDisk() *SessionPlansFile {
	// Try multiple paths to find the seed file
	paths := []string{
		"seed/session_plans.json",
		"backend/seed/session_plans.json",
		"../seed/session_plans.json",
	}

	// Also try relative to the source file
	_, thisFile, _, ok := runtime.Caller(0)
	if ok {
		dir := filepath.Dir(thisFile)
		paths = append(paths, filepath.Join(dir, "..", "..", "seed", "session_plans.json"))
	}

	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		var plans SessionPlansFile
		if err := json.Unmarshal(data, &plans); err != nil {
			continue
		}
		return &plans
	}

	// Return a sensible default if file not found
	return defaultSessionPlans()
}

func defaultSessionPlans() *SessionPlansFile {
	return &SessionPlansFile{
		DefaultPlan: SessionPlan{
			Activities: []PlanSlot{
				// Warmup: SRS review
				{Phase: "warmup", Source: "srs_due", Skill: "weakest", Format: "auto", Count: 2},
				{Phase: "warmup", Source: "srs_due", Skill: "listening", Format: "listen_and_choose", Count: 1},
				// Phase 3 — Phonics: one perception drill, one production drill
				{Phase: "phonics", Source: "phoneme_weak", Skill: "perception", Format: "phonics_listen", Count: 1},
				{Phase: "phonics", Source: "phoneme_weak", Skill: "production", Format: "phonics_match", Count: 1},
				// Phase 4 — Curriculum DAG: introduce next unlocked grammar structure
				{Phase: "grammar", Source: "grammar_next", Skill: "reading", Format: "pattern_intro", Count: 1},
				// New content
				{Phase: "new_content", Source: "unit_vocab", Skill: "listening", Format: "flashcard_intro", Count: 1},
				{Phase: "new_content", Source: "unit_vocab", Skill: "speaking", Format: "listen_and_repeat", Count: 1},
				// Practice
				{Phase: "practice", Source: "mix", Skill: "reading", Format: "fill_blank", Count: 1},
				{Phase: "practice", Source: "mix", Skill: "writing", Format: "build_sentence", Count: 1},
				{Phase: "practice", Source: "error_focus", Skill: "speaking", Format: "speak_word", Count: 1},
				{Phase: "practice", Source: "mix", Skill: "listening", Format: "word_match", Count: 1},
				// Fun finish
				{Phase: "fun_finish", Source: "all_learned", Skill: "auto", Format: "word_match", Count: 1},
			},
		},
		UnitVocabulary: map[string]UnitVocab{
			"1": {Words: []string{"hello", "goodbye", "name", "boy", "girl", "happy", "sad", "hungry", "tired", "excited"}, Theme: "Chào hỏi", Patterns: []string{"p_i_am_feeling", "p_my_name_is"}},
			"2": {Words: []string{"mom", "dad", "brother", "sister", "baby", "grandma", "grandpa", "family", "love", "this"}, Theme: "Gia đình", Patterns: []string{"p_this_is_my"}},
			"3": {Words: []string{"rice", "milk", "water", "ice cream", "chicken", "fish", "bread", "fruit", "like", "don't"}, Theme: "Đồ ăn", Patterns: []string{"p_i_like_food", "p_i_dont_like"}},
			"4": {Words: []string{"run", "jump", "swim", "sing", "dance", "draw", "fly", "play", "can", "can't"}, Theme: "Hành động", Patterns: []string{"p_i_can_action"}},
			"5": {Words: []string{"morning", "afternoon", "night", "wake up", "eat", "school", "sleep", "go"}, Theme: "Thời gian", Patterns: []string{"p_i_verb_in_morning"}},
			"6": {Words: []string{"color", "big", "small", "hot", "cold", "thank you"}, Theme: "Ôn tập", Patterns: []string{"p_it_is_adj"}},
			"7": {Words: []string{"my", "your", "friend", "English", "learn", "star"}, Theme: "Trình diễn", Patterns: []string{"p_all_combined"}},
		},
	}
}
