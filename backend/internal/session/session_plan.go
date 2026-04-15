package session

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"sync"
)

// SessionPlan defines the template for dynamically generating a session.
// Kind classifies the plan (story|review|discovery|performance|play) so the
// selector and downstream engine can reason about lesson type.
type SessionPlan struct {
	Kind       string     `json:"kind,omitempty"`
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

// PlanSelector picks which named plan fires for a given session.
// Strategy "fixed_cycle_with_triggers" rotates through Cycle by session index,
// with Triggers evaluated first — first matching trigger wins.
type PlanSelector struct {
	Strategy string            `json:"strategy,omitempty"`
	Cycle    []string          `json:"cycle,omitempty"`
	Triggers []SelectorTrigger `json:"triggers,omitempty"`
}

// SelectorTrigger is a conditional plan override.
// ReplaceWith is a plan name in Plans, or "default" to force DefaultPlan.
type SelectorTrigger struct {
	Name        string           `json:"name"`
	When        TriggerCondition `json:"when"`
	ReplaceWith string           `json:"replace_with"`
}

// TriggerCondition is an AND of the fields that are set. Unset fields are ignored.
// For OR semantics, author multiple triggers — first match wins.
type TriggerCondition struct {
	TotalSessionsLT *int     `json:"total_sessions_lt,omitempty"`
	SrsBacklogGT    *int     `json:"srs_backlog_gt,omitempty"`
	AvgSkillLT      *float64 `json:"avg_skill_lt,omitempty"`
	PlannedKindEq   string   `json:"planned_kind_eq,omitempty"`
}

// SessionPlansFile is the top-level structure of session_plans.json.
// Plans is a map of named lesson-type plans (quiz, story, discovery, etc.)
// and Selector picks which one fires per session. DefaultPlan is the
// back-compat fallback used whenever a named plan lookup fails.
type SessionPlansFile struct {
	Plans       map[string]SessionPlan `json:"plans,omitempty"`
	Selector    PlanSelector           `json:"selector,omitempty"`
	DefaultPlan SessionPlan            `json:"default_plan"`
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
	}
}
