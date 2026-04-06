CREATE TABLE vocabulary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    word VARCHAR(100) NOT NULL UNIQUE,
    translation_vi VARCHAR(255) NOT NULL,
    phonetic_ipa VARCHAR(100) NOT NULL DEFAULT '',
    audio_url VARCHAR(500) NOT NULL DEFAULT '',
    image_url VARCHAR(500) NOT NULL DEFAULT '',
    category VARCHAR(50) NOT NULL,
    day_number INTEGER NOT NULL CHECK (day_number >= 1 AND day_number <= 7),
    difficulty INTEGER NOT NULL DEFAULT 1 CHECK (difficulty >= 1 AND difficulty <= 3),
    target_phonemes JSONB NOT NULL DEFAULT '[]',
    common_l1_errors JSONB NOT NULL DEFAULT '[]'
);

CREATE INDEX idx_vocabulary_day ON vocabulary(day_number);
CREATE INDEX idx_vocabulary_category ON vocabulary(category);
CREATE INDEX idx_vocabulary_difficulty ON vocabulary(difficulty);
