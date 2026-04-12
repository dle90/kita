-- Tracks which grammar structures a kid has been exposed to.
-- Used by the curriculum DAG to determine which structures are unlocked.
CREATE TABLE IF NOT EXISTS kid_grammar_exposure (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    kid_id UUID NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    grammar_structure_id TEXT NOT NULL REFERENCES grammar_structures(id) ON DELETE CASCADE,
    exposure_count INT NOT NULL DEFAULT 1,
    first_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(kid_id, grammar_structure_id)
);

CREATE INDEX IF NOT EXISTS idx_kid_grammar_exposure_kid_id ON kid_grammar_exposure(kid_id);
