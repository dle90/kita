package session

import "testing"

func intPtr(i int) *int         { return &i }
func floatPtr(f float64) *float64 { return &f }

func makePlansFixture() *SessionPlansFile {
	return &SessionPlansFile{
		Plans: map[string]SessionPlan{
			"quiz": {
				Kind:       "review",
				Activities: []PlanSlot{{Phase: "warmup", Format: "auto", Count: 3}},
			},
			"story": {
				Kind:       "story",
				Activities: []PlanSlot{{Phase: "hook", Format: "listen_story", Count: 1}},
			},
		},
		Selector: PlanSelector{
			Strategy: "fixed_cycle_with_triggers",
			Cycle:    []string{"discovery", "story", "quiz", "story", "quiz", "performance", "play"},
			Triggers: []SelectorTrigger{
				{Name: "cold_start", When: TriggerCondition{TotalSessionsLT: intPtr(2)}, ReplaceWith: "default"},
				{Name: "srs_backlog", When: TriggerCondition{SrsBacklogGT: intPtr(20)}, ReplaceWith: "quiz"},
				{Name: "skill_weakness", When: TriggerCondition{AvgSkillLT: floatPtr(0.6)}, ReplaceWith: "quiz"},
			},
		},
		DefaultPlan: SessionPlan{
			Activities: []PlanSlot{{Phase: "default", Format: "auto", Count: 1}},
		},
	}
}

func TestSelectPlan_NilPlans(t *testing.T) {
	sel := SelectPlan(nil, KidState{})
	if sel.Name != "default" {
		t.Fatalf("expected default, got %q", sel.Name)
	}
}

func TestSelectPlan_ColdStart_FreshKidGetsDefault(t *testing.T) {
	plans := makePlansFixture()
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 0})
	if sel.Name != "default" {
		t.Fatalf("fresh kid should get default, got %q (reason: %s)", sel.Name, sel.Reason)
	}
	if sel.Reason == "" {
		t.Errorf("selector should always set a reason")
	}
}

func TestSelectPlan_ColdStart_Session1StillDefault(t *testing.T) {
	plans := makePlansFixture()
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 1})
	if sel.Name != "default" {
		t.Fatalf("session 1 should still get default via cold_start, got %q", sel.Name)
	}
}

func TestSelectPlan_ColdStart_Session2ExitsColdStart(t *testing.T) {
	plans := makePlansFixture()
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 2})
	// Cycle index 2 = "quiz" — which IS available, so selector should pick it.
	if sel.Name != "quiz" {
		t.Fatalf("session 2 should fall out of cold_start and hit cycle[2]=quiz, got %q (reason: %s)", sel.Name, sel.Reason)
	}
}

func TestSelectPlan_SrsBacklogOverride(t *testing.T) {
	plans := makePlansFixture()
	// Session 10 → cycle[10 % 7 = 3] = "story" normally, but SRS backlog overrides.
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 10, SrsBacklog: 25})
	if sel.Name != "quiz" {
		t.Fatalf("high srs backlog should force quiz, got %q", sel.Name)
	}
	if sel.Reason != "trigger 'srs_backlog' matched" {
		t.Errorf("unexpected reason: %s", sel.Reason)
	}
}

func TestSelectPlan_SrsBacklogAtThresholdDoesNotTrigger(t *testing.T) {
	plans := makePlansFixture()
	// backlog == 20 is NOT > 20, so trigger should not fire.
	// Session 10 → cycle[3] = "story" which is available.
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 10, SrsBacklog: 20})
	if sel.Name != "story" {
		t.Fatalf("backlog at threshold should fall through to cycle[3]=story, got %q", sel.Name)
	}
}

func TestSelectPlan_SkillWeaknessOverride(t *testing.T) {
	plans := makePlansFixture()
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 5, AvgSkill: 0.4})
	if sel.Name != "quiz" {
		t.Fatalf("low avg skill should force quiz, got %q", sel.Name)
	}
}

func TestSelectPlan_SkillWeaknessZeroDoesNotTrigger(t *testing.T) {
	plans := makePlansFixture()
	// AvgSkill == 0 means "no data yet", must not fire weakness trigger.
	// Session 5 → cycle[5] = "performance" (missing) → default.
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 5, AvgSkill: 0})
	if sel.Name != "default" {
		t.Fatalf("zero avg skill + missing cycle plan should fall to default, got %q", sel.Name)
	}
}

func TestSelectPlan_CycleFallthrough_MissingPlansGoToDefault(t *testing.T) {
	plans := makePlansFixture()
	// Session 7 → cycle[0] = "discovery" (missing) → default fallback.
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 7})
	if sel.Name != "default" {
		t.Fatalf("missing plan in cycle should fall to default, got %q (reason: %s)", sel.Name, sel.Reason)
	}
}

func TestSelectPlan_CycleFallthrough_AvailablePlanWins(t *testing.T) {
	plans := makePlansFixture()
	// Session 4 → cycle[4] = "quiz" which IS available.
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 4})
	if sel.Name != "quiz" {
		t.Fatalf("available cycle plan should win, got %q (reason: %s)", sel.Name, sel.Reason)
	}
}

func TestSelectPlan_NoCycleConfigured(t *testing.T) {
	plans := &SessionPlansFile{
		Plans:       map[string]SessionPlan{"quiz": {Kind: "review"}},
		DefaultPlan: SessionPlan{Activities: []PlanSlot{{Phase: "d"}}},
	}
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 5})
	if sel.Name != "default" {
		t.Fatalf("no cycle configured should give default, got %q", sel.Name)
	}
}

func TestSelectPlan_EmptyConditionDoesNotMatch(t *testing.T) {
	plans := &SessionPlansFile{
		Plans: map[string]SessionPlan{"quiz": {Kind: "review"}},
		Selector: PlanSelector{
			Cycle: []string{"quiz"},
			Triggers: []SelectorTrigger{
				{Name: "broken", When: TriggerCondition{}, ReplaceWith: "default"},
			},
		},
		DefaultPlan: SessionPlan{Activities: []PlanSlot{{Phase: "d"}}},
	}
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 5})
	// Empty condition must not fire the trigger — should hit the cycle normally.
	if sel.Name != "quiz" {
		t.Fatalf("empty condition must not match, expected cycle pick quiz, got %q", sel.Name)
	}
}

func TestSelectPlan_TriggerPrecedesCycle(t *testing.T) {
	plans := makePlansFixture()
	// With a high session count AND high SRS backlog, trigger should win over cycle.
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 4, SrsBacklog: 50})
	if sel.Name != "quiz" {
		t.Fatalf("trigger should win even when cycle pick is available, got %q", sel.Name)
	}
	if sel.Reason != "trigger 'srs_backlog' matched" {
		t.Errorf("unexpected reason: %s", sel.Reason)
	}
}

func TestSelectPlan_FirstTriggerWins(t *testing.T) {
	plans := makePlansFixture()
	// Fresh kid with high SRS backlog → cold_start fires FIRST (fresh kid shouldn't
	// get drilled on review before they have anything to review).
	sel := SelectPlan(plans, KidState{TotalCompletedSessions: 0, SrsBacklog: 50})
	if sel.Name != "default" {
		t.Fatalf("cold_start should win over srs_backlog for fresh kid, got %q", sel.Name)
	}
}
