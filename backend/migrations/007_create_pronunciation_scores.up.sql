CREATE TABLE IF NOT EXISTS pronunciation_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kid_id UUID NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    vocabulary_id UUID REFERENCES vocabulary(id),
    reference_text TEXT NOT NULL,
    audio_url VARCHAR(500) NOT NULL DEFAULT '',
    accuracy_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    fluency_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    completeness_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    pronunciation_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    phonemes JSONB NOT NULL DEFAULT '[]',
    l1_errors JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pronunciation_scores_kid ON pronunciation_scores(kid_id);
CREATE INDEX IF NOT EXISTS idx_pronunciation_scores_kid_created ON pronunciation_scores(kid_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pronunciation_scores_vocab ON pronunciation_scores(vocabulary_id) WHERE vocabulary_id IS NOT NULL;
