CREATE TABLE session_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    day_number INTEGER NOT NULL CHECK (day_number >= 1 AND day_number <= 7),
    level VARCHAR(20) NOT NULL CHECK (level IN ('beginner', 'elementary', 'intermediate')),
    phase VARCHAR(20) NOT NULL CHECK (phase IN ('warmup', 'new_content', 'practice', 'fun_finish')),
    activity_type VARCHAR(50) NOT NULL,
    config JSONB NOT NULL DEFAULT '{}',
    sort_order INTEGER NOT NULL DEFAULT 0,
    vocabulary_ids JSONB NOT NULL DEFAULT '[]',
    sentence_ids JSONB NOT NULL DEFAULT '[]'
);

CREATE INDEX idx_session_templates_day_level ON session_templates(day_number, level);
CREATE INDEX idx_session_templates_sort ON session_templates(sort_order);
