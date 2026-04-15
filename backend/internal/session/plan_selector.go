package session

import "fmt"

// KidState captures the learner signals the selector reads to pick a plan.
// Keep this narrow — expand only when a new trigger needs a new field.
type KidState struct {
	TotalCompletedSessions int
	SrsBacklog             int
	AvgSkill               float64 // 0-1 range; 0 means "not enough data"
	MasteredPatterns       int
	MasteredWords          int
	CompanionID            string
}

// SelectedPlan is the output of SelectPlan: the chosen plan plus why.
type SelectedPlan struct {
	Name   string
	Kind   string
	Plan   SessionPlan
	Reason string
}

// SelectPlan evaluates the selector triggers in order and returns the chosen plan.
// Resolution order:
//  1. Compute the "planned" cycle pick from TotalCompletedSessions % len(Cycle).
//  2. Evaluate triggers in order; first match wins and its ReplaceWith is used.
//  3. If no trigger matches, use the planned cycle pick.
//  4. Any missing plan reference falls through to DefaultPlan.
func SelectPlan(plans *SessionPlansFile, state KidState) SelectedPlan {
	if plans == nil {
		return SelectedPlan{Name: "default", Reason: "nil plans file"}
	}

	fallback := SelectedPlan{
		Name:   "default",
		Kind:   plans.DefaultPlan.Kind,
		Plan:   plans.DefaultPlan,
		Reason: "default_plan fallback",
	}

	// 1. Compute cycle pick.
	var plannedName, plannedKind string
	var cycleIdx int
	if len(plans.Selector.Cycle) > 0 {
		cycleIdx = state.TotalCompletedSessions % len(plans.Selector.Cycle)
		plannedName = plans.Selector.Cycle[cycleIdx]
		if p, ok := plans.Plans[plannedName]; ok {
			plannedKind = p.Kind
		}
	}

	// 2. Evaluate triggers.
	for _, t := range plans.Selector.Triggers {
		if !triggerMatches(t.When, state, plannedKind) {
			continue
		}
		target := t.ReplaceWith
		if target == "" || target == "default" {
			fb := fallback
			fb.Reason = fmt.Sprintf("trigger '%s' → default", t.Name)
			return fb
		}
		p, ok := plans.Plans[target]
		if !ok {
			fb := fallback
			fb.Reason = fmt.Sprintf("trigger '%s' → unknown plan '%s' → default", t.Name, target)
			return fb
		}
		return SelectedPlan{
			Name:   target,
			Kind:   p.Kind,
			Plan:   p,
			Reason: fmt.Sprintf("trigger '%s' matched", t.Name),
		}
	}

	// 3. Fall through to cycle pick.
	if plannedName == "" {
		fb := fallback
		fb.Reason = "no cycle configured → default"
		return fb
	}
	p, ok := plans.Plans[plannedName]
	if !ok {
		fb := fallback
		fb.Reason = fmt.Sprintf("cycle[%d]='%s' not available → default", cycleIdx, plannedName)
		return fb
	}
	return SelectedPlan{
		Name:   plannedName,
		Kind:   p.Kind,
		Plan:   p,
		Reason: fmt.Sprintf("cycle[%d] → %s", cycleIdx, plannedName),
	}
}

// triggerMatches returns true iff every field set in the condition matches the state.
// An empty condition returns false (an always-fire trigger is almost always a bug).
func triggerMatches(cond TriggerCondition, state KidState, plannedKind string) bool {
	anySet := false

	if cond.TotalSessionsLT != nil {
		anySet = true
		if state.TotalCompletedSessions >= *cond.TotalSessionsLT {
			return false
		}
	}
	if cond.SrsBacklogGT != nil {
		anySet = true
		if state.SrsBacklog <= *cond.SrsBacklogGT {
			return false
		}
	}
	if cond.AvgSkillLT != nil {
		anySet = true
		if state.AvgSkill == 0 || state.AvgSkill >= *cond.AvgSkillLT {
			return false
		}
	}
	if cond.PlannedKindEq != "" {
		anySet = true
		if cond.PlannedKindEq != plannedKind {
			return false
		}
	}

	return anySet
}
