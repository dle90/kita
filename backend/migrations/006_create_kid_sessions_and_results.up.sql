CREATE TABLE IF NOT EXISTS kid_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kid_id UUID NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL CHECK (day_number >= 1 AND day_number <= 7),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    total_stars INTEGER NOT NULL DEFAULT 0,
    accuracy_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(kid_id, day_number)
);

CREATE INDEX IF NOT EXISTS idx_kid_sessions_kid ON kid_sessions(kid_id);
CREATE INDEX IF NOT EXISTS idx_kid_sessions_kid_day ON kid_sessions(kid_id, day_number);

CREATE TABLE IF NOT EXISTS activity_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES kid_sessions(id) ON DELETE CASCADE,
    kid_id UUID NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL,
    vocabulary_id UUID REFERENCES vocabulary(id),
    is_correct BOOLEAN NOT NULL DEFAULT FALSE,
    attempts INTEGER NOT NULL DEFAULT 1,
    time_spent_ms INTEGER NOT NULL DEFAULT 0,
    stars_earned INTEGER NOT NULL DEFAULT 0 CHECK (stars_earned >= 0 AND stars_earned <= 3),
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_results_session ON activity_results(session_id);
CREATE INDEX IF NOT EXISTS idx_activity_results_kid ON activity_results(kid_id);
CREATE INDEX IF NOT EXISTS idx_activity_results_type ON activity_results(activity_type);
