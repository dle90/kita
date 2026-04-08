CREATE TABLE IF NOT EXISTS word_skill_mastery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kid_id UUID NOT NULL REFERENCES kids(id),
    vocabulary_id UUID NOT NULL REFERENCES vocabulary(id),
    listening_score REAL NOT NULL DEFAULT 0,
    listening_attempts INT NOT NULL DEFAULT 0,
    speaking_score REAL NOT NULL DEFAULT 0,
    speaking_attempts INT NOT NULL DEFAULT 0,
    reading_score REAL NOT NULL DEFAULT 0,
    reading_attempts INT NOT NULL DEFAULT 0,
    writing_score REAL NOT NULL DEFAULT 0,
    writing_attempts INT NOT NULL DEFAULT 0,
    overall_mastery REAL NOT NULL DEFAULT 0,
    last_seen TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(kid_id, vocabulary_id)
);

CREATE INDEX IF NOT EXISTS idx_word_skill_mastery_kid ON word_skill_mastery(kid_id);
CREATE INDEX IF NOT EXISTS idx_word_skill_mastery_weakest ON word_skill_mastery(kid_id, overall_mastery);
