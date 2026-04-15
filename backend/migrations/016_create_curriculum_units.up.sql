CREATE TABLE IF NOT EXISTS curriculum_units (
    unit_number INT PRIMARY KEY,
    theme TEXT NOT NULL DEFAULT '',
    words JSONB NOT NULL DEFAULT '[]',
    patterns JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
