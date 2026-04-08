CREATE TABLE IF NOT EXISTS phonemes (
    id VARCHAR(20) PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    example_word VARCHAR(50) NOT NULL,
    example_word_vi VARCHAR(100),
    graphemes TEXT[] NOT NULL,
    is_new_for_vietnamese BOOLEAN NOT NULL DEFAULT FALSE,
    common_substitution VARCHAR(10),
    substitution_vi TEXT,
    mouth_position_vi TEXT,
    difficulty SMALLINT NOT NULL DEFAULT 5,
    priority_northern SMALLINT NOT NULL DEFAULT 5,
    priority_central SMALLINT NOT NULL DEFAULT 5,
    priority_southern SMALLINT NOT NULL DEFAULT 5,
    minimal_pairs JSONB,
    practice_words TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS kid_phoneme_mastery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kid_id UUID NOT NULL REFERENCES kids(id),
    phoneme_id VARCHAR(20) NOT NULL REFERENCES phonemes(id),
    perception_score REAL NOT NULL DEFAULT 0,
    perception_attempts INT NOT NULL DEFAULT 0,
    production_score REAL NOT NULL DEFAULT 0,
    production_attempts INT NOT NULL DEFAULT 0,
    last_seen TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(kid_id, phoneme_id)
);

CREATE INDEX IF NOT EXISTS idx_kid_phoneme_mastery_kid ON kid_phoneme_mastery(kid_id);
CREATE INDEX IF NOT EXISTS idx_kid_phoneme_mastery_score ON kid_phoneme_mastery(kid_id, perception_score, production_score);
