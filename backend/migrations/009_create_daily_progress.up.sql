CREATE TABLE daily_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kid_id UUID NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    words_learned INTEGER NOT NULL DEFAULT 0,
    words_reviewed INTEGER NOT NULL DEFAULT 0,
    avg_pron_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    session_completed BOOLEAN NOT NULL DEFAULT FALSE,
    total_time_ms INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(kid_id, date)
);

CREATE INDEX idx_daily_progress_kid ON daily_progress(kid_id);
CREATE INDEX idx_daily_progress_kid_date ON daily_progress(kid_id, date);
