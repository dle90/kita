CREATE TABLE kids (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
    display_name VARCHAR(50) NOT NULL,
    character_id VARCHAR(50) NOT NULL,
    age INTEGER NOT NULL CHECK (age >= 3 AND age <= 12),
    dialect VARCHAR(20) NOT NULL CHECK (dialect IN ('northern', 'central', 'southern')),
    english_level VARCHAR(20) NOT NULL DEFAULT 'beginner' CHECK (english_level IN ('beginner', 'elementary', 'intermediate')),
    notification_time TIME,
    placement_done BOOLEAN NOT NULL DEFAULT FALSE,
    current_day INTEGER NOT NULL DEFAULT 1 CHECK (current_day >= 1 AND current_day <= 7),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_kids_parent ON kids(parent_id);
